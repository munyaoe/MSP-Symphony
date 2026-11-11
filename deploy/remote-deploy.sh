#!/usr/bin/env bash
# Runs ON the symphony.nairobiconvention.org server (invoked over SSH by
# .github/workflows/deploy.yml). Deploys a release that has already been
# rsynced to $RELEASE_DIR, using WildFly's filesystem deployment-scanner
# (marker-file based), and atomically swaps the Apache frontend docroot
# symlink. Exits non-zero on any failure so the caller can roll back.
set -euo pipefail

RELEASE_DIR="${1:?Usage: remote-deploy.sh <release-dir-absolute-path>}"
WILDFLY_DEPLOYMENTS=/opt/wildfly/wildfly-26.1.1.Final/standalone/deployments
FRONTEND_LINK=/app/webapp/symphony-fe
WAR_RUNTIME_NAME=symphony-ws.war

log() { echo "[remote-deploy] $*"; }

[ -d "$RELEASE_DIR/frontend" ] || { log "Missing $RELEASE_DIR/frontend"; exit 1; }
WAR_FILE=$(find "$RELEASE_DIR/backend" -maxdepth 1 -iname "*.war" | head -1)
[ -n "${WAR_FILE:-}" ] || { log "No WAR found in $RELEASE_DIR/backend"; exit 1; }

# --- Record current state for rollback ---
PREVIOUS_RELEASE=$(readlink -f "$FRONTEND_LINK" | xargs dirname || true)
echo "$PREVIOUS_RELEASE" > /app/releases/.previous-release

# --- Deploy backend via filesystem scanner marker protocol ---
log "Copying $WAR_FILE -> $WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME"
cp "$WAR_FILE" "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.tmp"
mv "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.tmp" "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME"
rm -f "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.failed" "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.deployed"
touch "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.dodeploy"

log "Waiting for WildFly to pick up the deployment..."
for i in $(seq 1 60); do
  if [ -f "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.deployed" ]; then
    log "Backend deployed."
    break
  fi
  if [ -f "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.failed" ]; then
    log "WildFly reported deployment FAILED:"
    cat "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.failed" || true
    exit 1
  fi
  sleep 2
done
[ -f "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.deployed" ] || { log "Timed out waiting for deployment"; exit 1; }

# --- Flip frontend docroot symlink atomically ---
log "Flipping $FRONTEND_LINK -> $RELEASE_DIR/frontend"
ln -sfn "$RELEASE_DIR/frontend" "${FRONTEND_LINK}.new"
mv -T "${FRONTEND_LINK}.new" "$FRONTEND_LINK"

log "Deploy complete: $RELEASE_DIR"
