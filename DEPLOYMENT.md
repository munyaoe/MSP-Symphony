# Deployment runbook — symphony.nairobiconvention.org

## What this is

A GitHub Actions pipeline (`.github/workflows/release.yml` +
`.github/workflows/deploy.yml`) plus two server-side scripts
(`deploy/remote-deploy.sh`, `deploy/remote-rollback.sh`) that build and
ship the `nairobi-convention` branch to the live server without
overwriting anything in place: each deploy lands in a new timestamped
directory under `/app/releases/`, and going live is an atomic symlink
flip (frontend) plus a WildFly marker-file deploy (backend). The
previous release is never deleted until 5 newer ones exist, so rollback
is just restoring the previous symlink target and redeploying the
previous WAR.

**Nothing in this pipeline has been run yet.** It is here for review.

## One-time setup required before the first real run

1. **GitHub Environment protection.** In the repo's Settings →
   Environments, create an environment named `production` and add at
   least one required reviewer (yourself, or whoever else should sign
   off). This is what makes `deploy.yml` need a second click before it
   can touch the live site, even though only you can trigger it.

2. **Secrets** (Settings → Secrets and variables → Actions):
   - `DEPLOY_SSH_HOST` = `78.128.81.16`
   - `DEPLOY_SSH_PORT` = `6543`
   - `DEPLOY_SSH_USER` = `root` (or a less-privileged deploy user — see
     "Open questions" below)
   - `DEPLOY_SSH_KEY` = a **dedicated** private key for this pipeline
     (don't reuse your personal key), with the matching public key
     added to `~/.ssh/authorized_keys` on the server.
   - `DEPLOY_SSH_KNOWN_HOSTS` = output of
     `ssh-keyscan -p 6543 78.128.81.16`, captured once and trusted by
     you out of band (not fetched automatically, to avoid trusting
     whatever answers on first contact).

3. **Server-side directories.** `/app/releases/` needs to exist and be
   writable by `DEPLOY_SSH_USER`.

## Open questions to verify before the first real deploy

These are assumptions the scripts make, based on what discovery found;
please confirm or correct before actually running `deploy.yml`:

- **WildFly deployment-scanner.** `remote-deploy.sh` deploys via the
  filesystem marker protocol (drop a `.war`, touch `.dodeploy`, wait
  for `.deployed`). This requires the deployment-scanner subsystem to
  be enabled in `standalone.xml` (it is by default, but we haven't
  confirmed it wasn't disabled on this box). If it's disabled, we'd
  switch to `jboss-cli.sh` with the management interface instead —
  tell me and I'll adjust.
- **Current deploy mechanism mismatch.** The live WAR we found was
  stored under WildFly's content-addressed store
  (`standalone/data/content/`), which is what both the scanner *and*
  the management CLI produce — so this doesn't rule out either, but it
  also doesn't confirm the scanner path hasn't been disabled in favour
  of CLI-only deploys. Worth a quick check:
  `grep -A3 deployment-scanner /opt/wildfly/wildfly-26.1.1.Final/standalone/configuration/standalone.xml`
- **Apache symlink following.** The vhost's `DocumentRoot` is
  `/app/webapp/symphony-fe`, which the scripts assume is (or will
  become) a symlink. Confirm Apache's `Options` for that path allow
  `FollowSymLinks` (it almost certainly does, given this is already
  how cPanel/WHM structures most docroots, but worth a one-line check).
- **Root as deploy user.** Using `root` over SSH for CI is simple but
  broad. If you'd rather scope this down, we can create a dedicated
  `deploy` user with sudo rights limited to exactly the directories and
  the WildFly deployments folder this needs.
- **Database migrations.** This pipeline does not touch the database.
  If a future release needs a schema change, that should stay a
  separate, manually-run, backed-up step — not something this
  pipeline auto-applies.

## Normal operation

1. Open a PR into `nairobi-convention` (or push directly, for solo
   work) — `release.yml` builds both artifacts on every push, so you
   always have a tested, downloadable build before deploying anything.
2. When ready to ship: Actions tab → "Deploy to production" →
   "Run workflow" → type `DEPLOY` in the confirmation field → the
   `production` environment's required reviewer approves it.
3. The workflow builds fresh, ships to a new `/app/releases/<timestamp>/`,
   deploys, and smoke-tests (`/` returns 200, `/symphony-ws/service/areas`
   returns 401 rather than an error, the index page references a
   `main.*.js`). If any of that fails, it automatically rolls back and
   the job is marked failed — check the Actions log for which step hit.

## Manual rollback

If something looks wrong after a deploy that technically "succeeded"
(the smoke test is intentionally minimal), SSH in and run:

```bash
bash /app/releases/.deploy-scripts/remote-rollback.sh
```

with no argument, it rolls back to whatever release was active
immediately before the last deploy (recorded in
`/app/releases/.previous-release`). To roll back further, pass an
explicit release directory as the argument.

## Before the very first deploy of anything via this pipeline

Re-run the same backup procedure we already did manually
(`pg_dump` + the config/frontend/WAR tarballs) one more time, right
before the first real `deploy.yml` run, so the backup is current to
the minute rather than from discovery day.
