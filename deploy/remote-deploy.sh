#!/usr/bin/env bash
# Runs ON the symphony.nairobiconvention.org server (invoked over SSH by
# .github/workflows/deploy.yml). Deploys a release that has already been
# rsynced to $RELEASE_DIR, via WildFly's management CLI (jboss-cli), and
# atomically swaps the Apache frontend docroot symlink. Exits non-zero on
# any failure so the caller can roll back.
#
# The live app was found to be a managed deployment (added via the CLI or
# admin console, not the filesystem deployment-scanner), registered under
# a version-specific runtime name (e.g. symphony-ws-1.22.0.war). The
# scanner's marker-file protocol can't replace a managed deployment with
# the same name - WildFly reports "Host and context path are occupied".
# So this undeploys whatever is currently registered as symphony-ws*.war
# first, then deploys the new WAR under a fixed name, both via jboss-cli.
set -euo pipefail

RELEASE_DIR="${1:?Usage: remote-deploy.sh <release-dir-absolute-path>}"
JBOSS_CLI=/opt/wildfly/wildfly-33.0.2.Final/bin/jboss-cli.sh
FRONTEND_LINK=/app/webapp/symphony-fe
DEPLOY_NAME=symphony-ws.war

log() { echo "[remote-deploy] $*"; }

[ -d "$RELEASE_DIR/frontend" ] || { log "Missing $RELEASE_DIR/frontend"; exit 1; }
WAR_FILE=$(find "$RELEASE_DIR/backend" -maxdepth 1 -iname "*.war" | head -1)
[ -n "${WAR_FILE:-}" ] || { log "No WAR found in $RELEASE_DIR/backend"; exit 1; }

# --- Record current state for rollback (both the frontend release dir and the backend deployment name) ---
if [ -L "$FRONTEND_LINK" ]; then
  readlink -f "$FRONTEND_LINK" > /app/releases/.previous-release
else
  log "WARNING: $FRONTEND_LINK is not yet a symlink (first managed deploy) - no previous frontend release to record"
  rm -f /app/releases/.previous-release
fi

EXISTING_DEPLOYMENTS=$("$JBOSS_CLI" --connect --command="deployment-info" 2>/dev/null \
  | awk 'NR>1 {print $1}' | grep -i '^symphony-ws' || true)
if [ -n "$EXISTING_DEPLOYMENTS" ]; then
  echo "$EXISTING_DEPLOYMENTS" | head -1 > /app/releases/.previous-deployment-name
else
  rm -f /app/releases/.previous-deployment-name
fi

# --- Undeploy whatever is currently registered under this app's name(s) ---
for d in $EXISTING_DEPLOYMENTS; do
  log "Undeploying existing managed deployment: $d"
  "$JBOSS_CLI" --connect --command="undeploy $d"
done

# --- Deploy the new WAR under a fixed name via the management CLI ---
log "Deploying $WAR_FILE as $DEPLOY_NAME via jboss-cli"
"$JBOSS_CLI" --connect --command="deploy \"$WAR_FILE\" --name=$DEPLOY_NAME --force"

STATUS=$("$JBOSS_CLI" --connect --command="deployment-info" 2>/dev/null | awk -v n="$DEPLOY_NAME" '$1==n {print $NF}')
[ "$STATUS" = "OK" ] || { log "Deployment status is '$STATUS', expected OK"; exit 1; }
log "Backend deployed: $DEPLOY_NAME ($STATUS)"

# --- Flip frontend docroot symlink atomically ---
log "Flipping $FRONTEND_LINK -> $RELEASE_DIR/frontend"
ln -sfn "$RELEASE_DIR/frontend" "${FRONTEND_LINK}.new"
mv -T "${FRONTEND_LINK}.new" "$FRONTEND_LINK"

log "Deploy complete: $RELEASE_DIR"
