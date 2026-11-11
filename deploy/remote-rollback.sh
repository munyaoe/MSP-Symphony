#!/usr/bin/env bash
# Runs ON the server. Rolls back to the previous release: flips the
# frontend symlink back and redeploys the previous backend deployment
# (both recorded by remote-deploy.sh before it made any change). Invoked
# either automatically by deploy.yml on smoke-test failure, or manually.
set -euo pipefail

JBOSS_CLI=/opt/wildfly/wildfly-26.1.1.Final/bin/jboss-cli.sh
FRONTEND_LINK=/app/webapp/symphony-fe
DEPLOY_NAME=symphony-ws.war

log() { echo "[remote-rollback] $*"; }

TARGET_RELEASE="${1:-}"
if [ -z "$TARGET_RELEASE" ]; then
  [ -f /app/releases/.previous-release ] || { log "No previous release recorded - this looks like it was the first deploy, so there's nothing to roll back to. Check deployment-info manually."; exit 1; }
  TARGET_RELEASE=$(cat /app/releases/.previous-release)
fi
[ -d "$TARGET_RELEASE" ] || { log "Recorded previous release '$TARGET_RELEASE' does not exist"; exit 1; }

PREVIOUS_DEPLOYMENT_NAME=""
[ -f /app/releases/.previous-deployment-name ] && PREVIOUS_DEPLOYMENT_NAME=$(cat /app/releases/.previous-deployment-name)

log "Rolling back frontend to $TARGET_RELEASE/frontend"
ln -sfn "$TARGET_RELEASE/frontend" "${FRONTEND_LINK}.new"
mv -T "${FRONTEND_LINK}.new" "$FRONTEND_LINK"

if [ -z "$PREVIOUS_DEPLOYMENT_NAME" ]; then
  log "No previous backend deployment name recorded - leaving the current backend deployment as-is (it may already be fine if only the frontend regressed)"
  exit 0
fi

if [ "$PREVIOUS_DEPLOYMENT_NAME" = "$DEPLOY_NAME" ]; then
  log "Previous deployment already used the name $DEPLOY_NAME and was replaced in place - nothing further to redeploy for the backend. Manual intervention needed if the backend itself is broken."
  exit 0
fi

WAR_FILE=$(find "$TARGET_RELEASE/backend" -maxdepth 1 -iname "*.war" | head -1)
[ -n "${WAR_FILE:-}" ] || { log "No WAR found in $TARGET_RELEASE/backend to redeploy as $PREVIOUS_DEPLOYMENT_NAME"; exit 1; }

log "Undeploying $DEPLOY_NAME and redeploying $WAR_FILE as $PREVIOUS_DEPLOYMENT_NAME"
"$JBOSS_CLI" --connect --command="undeploy $DEPLOY_NAME" || true
"$JBOSS_CLI" --connect --command="deploy \"$WAR_FILE\" --name=$PREVIOUS_DEPLOYMENT_NAME --force"

STATUS=$("$JBOSS_CLI" --connect --command="deployment-info" 2>/dev/null | awk -v n="$PREVIOUS_DEPLOYMENT_NAME" '$1==n {print $NF}')
[ "$STATUS" = "OK" ] || { log "Rollback deployment status is '$STATUS', expected OK - manual intervention required"; exit 1; }
log "Rollback complete: $PREVIOUS_DEPLOYMENT_NAME ($STATUS)"
