#!/usr/bin/env bash
# Runs ON the server. Rolls back to the previous release: flips the
# frontend symlink back and redeploys the previous backend deployment
# (both recorded by remote-deploy.sh before it made any change). Invoked
# either automatically by deploy.yml on smoke-test failure, or manually.
set -euo pipefail

JBOSS_CLI=/opt/wildfly/wildfly-33.0.2.Final/bin/jboss-cli.sh
FRONTEND_LINK=/app/webapp/symphony-fe
DEPLOY_NAME=symphony-ws.war

log() { echo "[remote-rollback] $*"; }

TARGET_RELEASE="${1:-}"
FRONTEND_ROLLED_BACK=0
if [ -z "$TARGET_RELEASE" ] && [ -f /app/releases/.previous-release ]; then
  TARGET_RELEASE=$(cat /app/releases/.previous-release)
fi

if [ -n "$TARGET_RELEASE" ]; then
  [ -d "$TARGET_RELEASE" ] || { log "Recorded previous release '$TARGET_RELEASE' does not exist"; exit 1; }
  log "Rolling back frontend to $TARGET_RELEASE/frontend"
  ln -sfn "$TARGET_RELEASE/frontend" "${FRONTEND_LINK}.new"
  mv -T "${FRONTEND_LINK}.new" "$FRONTEND_LINK"
  FRONTEND_ROLLED_BACK=1
else
  log "No previous frontend release recorded - leaving the frontend symlink as-is"
fi

PREVIOUS_DEPLOYMENT_NAME=""
[ -f /app/releases/.previous-deployment-name ] && PREVIOUS_DEPLOYMENT_NAME=$(cat /app/releases/.previous-deployment-name)

if [ -z "$PREVIOUS_DEPLOYMENT_NAME" ]; then
  log "No previous backend deployment name recorded - leaving the current backend deployment as-is"
  [ "$FRONTEND_ROLLED_BACK" = 1 ] && exit 0
  log "Nothing was recorded to roll back - check deployment-info manually"
  exit 1
fi

if [ "$PREVIOUS_DEPLOYMENT_NAME" = "$DEPLOY_NAME" ]; then
  log "Previous deployment already used the name $DEPLOY_NAME and was replaced in place - nothing further to redeploy for the backend. Manual intervention needed if the backend itself is broken."
  exit 0
fi

CURRENT_STATUS=$("$JBOSS_CLI" --connect --command="deployment-info" 2>/dev/null | awk -v n="$PREVIOUS_DEPLOYMENT_NAME" '$1==n {print $NF}')
if [ "$CURRENT_STATUS" = "OK" ]; then
  log "$PREVIOUS_DEPLOYMENT_NAME is already deployed and OK - nothing to do for the backend"
  exit 0
fi

WAR_FILE=$(find "${TARGET_RELEASE:-/nonexistent}/backend" -maxdepth 1 -iname "*.war" 2>/dev/null | head -1)
if [ -z "${WAR_FILE:-}" ]; then
  log "No WAR found for $PREVIOUS_DEPLOYMENT_NAME under ${TARGET_RELEASE:-<none>} - cannot auto-redeploy. The original WAR must be located manually and redeployed via jboss-cli."
  exit 1
fi

log "Undeploying $DEPLOY_NAME (if present) and redeploying $WAR_FILE as $PREVIOUS_DEPLOYMENT_NAME"
"$JBOSS_CLI" --connect --command="undeploy $DEPLOY_NAME" || true
"$JBOSS_CLI" --connect --command="deploy \"$WAR_FILE\" --name=$PREVIOUS_DEPLOYMENT_NAME --force"

STATUS=$("$JBOSS_CLI" --connect --command="deployment-info" 2>/dev/null | awk -v n="$PREVIOUS_DEPLOYMENT_NAME" '$1==n {print $NF}')
[ "$STATUS" = "OK" ] || { log "Rollback deployment status is '$STATUS', expected OK - manual intervention required"; exit 1; }
log "Rollback complete: $PREVIOUS_DEPLOYMENT_NAME ($STATUS)"
