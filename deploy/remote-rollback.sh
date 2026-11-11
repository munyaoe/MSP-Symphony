#!/usr/bin/env bash
# Runs ON the server. Rolls back to the previous release: flips the
# frontend symlink back and redeploys the previous WAR. Invoked either
# automatically by deploy.yml on smoke-test failure, or manually.
set -euo pipefail

WILDFLY_DEPLOYMENTS=/opt/wildfly/wildfly-26.1.1.Final/standalone/deployments
FRONTEND_LINK=/app/webapp/symphony-fe
WAR_RUNTIME_NAME=symphony-ws.war

log() { echo "[remote-rollback] $*"; }

TARGET_RELEASE="${1:-$(cat /app/releases/.previous-release 2>/dev/null || true)}"
[ -n "$TARGET_RELEASE" ] && [ -d "$TARGET_RELEASE" ] || { log "No valid previous release recorded ($TARGET_RELEASE); cannot roll back automatically"; exit 1; }

WAR_FILE=$(find "$TARGET_RELEASE/backend" -maxdepth 1 -iname "*.war" | head -1)
[ -n "${WAR_FILE:-}" ] || { log "No WAR found in $TARGET_RELEASE/backend"; exit 1; }

log "Rolling back frontend to $TARGET_RELEASE/frontend"
ln -sfn "$TARGET_RELEASE/frontend" "${FRONTEND_LINK}.new"
mv -T "${FRONTEND_LINK}.new" "$FRONTEND_LINK"

log "Rolling back backend to $WAR_FILE"
cp "$WAR_FILE" "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.tmp"
mv "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.tmp" "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME"
rm -f "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.failed" "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.deployed"
touch "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.dodeploy"

for i in $(seq 1 60); do
  [ -f "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.deployed" ] && { log "Rollback backend redeployed."; exit 0; }
  [ -f "$WILDFLY_DEPLOYMENTS/$WAR_RUNTIME_NAME.failed" ] && { log "Rollback deployment FAILED too - manual intervention required"; exit 1; }
  sleep 2
done
log "Timed out waiting for rollback deployment - manual intervention required"
exit 1
