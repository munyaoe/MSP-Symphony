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

The server now runs **WildFly 33.0.2.Final** (upgraded from 26.1.1.Final
on 2026-11-12 to support Jakarta EE10, which the backend has required
since commit `eb337c6`). See "WildFly 26 → 33 upgrade" below for what
changed and why.

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

## Confirmed from the first (failed, but harmless) deploy attempt

- **The live app is a managed deployment, not scanner-based.** The
  first real run tried the filesystem marker protocol (drop a `.war`,
  touch `.dodeploy`) and WildFly rejected it: `Host and context path
  are occupied` — the live app is registered under the name
  `symphony-ws-1.22.0.war` via the management interface (CLI or admin
  console), and a scanner-dropped file with a different name can't
  replace it. `jboss-cli.sh --connect --command="deployment-info"`
  confirmed this works with no authentication prompt. `remote-deploy.sh`
  now undeploys whatever is currently registered as `symphony-ws*.war`
  via `jboss-cli` first, then deploys the new WAR under the fixed name
  `symphony-ws.war`, also via `jboss-cli`. `remote-rollback.sh` matches:
  it records the previous deployment's name and redeploys it by name on
  rollback.
- **Nothing was affected by that failed attempt.** The script exits
  before touching the frontend symlink or the live deployment if the
  WildFly pickup check fails, so the site kept serving
  `symphony-ws-1.22.0.war` throughout. A stray `symphony-ws.war` entry
  was left registered in a `FAILED` state (harmless, not serving
  anything) — clean it up once before the next deploy attempt:
  `jboss-cli.sh --connect --command="undeploy symphony-ws.war"`

## WildFly 26 → 33 upgrade (2026-11-12)

The backend moved to Jakarta EE10 (commit `eb337c6`, bundling Hibernate
6.6.7) but the server was still on WildFly 26.1.1, which only supports
Hibernate 5.3 — deploys failed with `NoSuchMethodError` on
`TypeContributions.contributeType`. Fix was a full WildFly upgrade, done
side-by-side with zero risk to the running instance until actual cutover:

- Installed WildFly 33.0.2.Final to `/opt/wildfly/wildfly-33.0.2.Final`
  (Jakarta EE10, last version before mainline moved to EE11). The old
  `wildfly-26.1.1.Final` install is left completely untouched for
  instant rollback — just flip `ExecStart` in
  `/usr/lib/systemd/system/wildfly.service` back to it and restart.
- `/opt/wildfly/wildfly-26.1.1.Final/bin/launch.sh` is a **custom
  wrapper**, not part of stock WildFly — it hardcodes `WILDFLY_HOME`
  and binds the management interface to `0.0.0.0`. Any future install
  needs this copied over and its path updated, or `systemd` fails with
  `203/EXEC`.
- `bin/standalone.conf`'s `JBOSS_JAVA_SIZING` defaults to `-Xmx512m` —
  must be set to `-Xms64m -Xmx13G -XX:MetaspaceSize=96M
  -XX:MaxMetaspaceSize=768m` to match production sizing, or the app
  will be heap-starved under real load.
- The PostgreSQL JDBC driver is a **managed deployment**, not a static
  module (`postgresql-42.7.5.jar`, matching the bumped `pom.xml`
  version) — deployed via `jboss-cli`, same mechanism as the app WAR.
- **Login requires manually recreating the `WIO-SymphonyIdentity`
  filesystem-realm.** The actual identity data lives in
  `standalone/configuration/symphony-localid/` and must be copied
  byte-for-byte from the old install — it's real user accounts, not
  regeneratable config. The realm, decoder, and domain wiring were
  added via `jboss-cli` (`simple-role-decoder`, `filesystem-realm`,
  and critically: despite `jboss-web.xml` declaring
  `<security-domain>other</security-domain>`, the login servlet
  mechanism that's *actually* resolved at runtime is
  **`ApplicationDomain`** — confirmed via `TRACE`-level
  `org.wildfly.security` logging showing `realm name: [ApplicationRealm]`
  during a failed login. The fix was repointing `ApplicationDomain`'s
  `default-realm` to `WIO-SymphonyIdentity`, not configuring `other`
  (which was a dead end — don't repeat that path).
- **One DB migration was required**: `BaselineVersion` gained a
  `bver_title` column (commit `2515018`, SYM-700) with no accompanying
  migration script (this app does not use Hibernate's `hbm2ddl.auto` —
  schema changes are always manual). Applied:
  `ALTER TABLE symphony.baselineversion ADD COLUMN bver_title text;`
  (nullable, matching the sibling `bver_desc` column's type). If future
  entity changes are made upstream, diff
  `symphony-ws/src/main/java/se/havochvatten/symphony/entity/` against
  what's live and check for new `@Column`s before deploying.
- `deploy/remote-deploy.sh` and `deploy/remote-rollback.sh`'s
  `JBOSS_CLI` constant now point at `wildfly-33.0.2.Final`.

## Open questions to verify before the first real deploy

These are assumptions the scripts make, based on what discovery found;
please confirm or correct before actually running `deploy.yml`:

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
