#!/bin/bash

set -Eeuo pipefail

# =========================================================
# CONFIG
# =========================================================
PROJECT_ID="project-ae821a0f-e5f5-42e7-b15"
SOURCE_INSTANCE_NAME="prod2019"
BUCKET_NAME="test-dms-dxc"
DESTINATION_NAME="prod2022"

# =========================================================
# LOG FILE
# =========================================================
LOG_FILE="cloudsql_bucket_iam_$(date +%Y%m%d_%H%M%S).log"

exec > >(tee -a "$LOG_FILE") 2>&1

# =========================================================
# LOG FUNCTION
# =========================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# =========================================================
# ERROR HANDLER
# =========================================================
error_handler() {
    local exit_code=$?
    local line_no=$1

    echo "--------------------------------------------------"
    echo "[ERROR] Script failed"
    echo "[ERROR] Exit Code : $exit_code"
    echo "[ERROR] Line No   : $line_no"
    echo "[ERROR] Time      : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "--------------------------------------------------"

    exit $exit_code
}

trap 'error_handler $LINENO' ERR

# =========================================================
# START
# =========================================================
log "===== IAM Setup Started ====="

# =========================================================
# SOURCE INSTANCE
# =========================================================
log "Fetching Source Cloud SQL service account..."

SA=$(gcloud sql instances describe "$SOURCE_INSTANCE_NAME" \
    --project="$PROJECT_ID" \
    --format="value(serviceAccountEmailAddress)")

if [ -z "$SA" ]; then
    log "ERROR: Could not fetch source service account"
    exit 1
fi

log "Source Service Account: $SA"

log "Checking if bucket exists..."

if ! gsutil ls -b "gs://$BUCKET_NAME" >/dev/null 2>&1; then
    log "ERROR: Bucket does not exist"
    exit 1
fi

log "Bucket exists."

log "Checking existing IAM permissions for source instance..."

EXISTS=$(gsutil iam get "gs://$BUCKET_NAME" | \
grep -A 5 "roles/storage.objectAdmin" | grep "$SA" || true)

if [ -z "$EXISTS" ]; then

    log "Granting object-level permissions to source service account..."

    gsutil iam ch \
    "serviceAccount:$SA:roles/storage.objectAdmin" \
    "gs://$BUCKET_NAME"

    gsutil iam ch \
    "serviceAccount:$SA:roles/storage.legacyBucketWriter" \
    "gs://$BUCKET_NAME"

    log "Permissions granted successfully to source instance."

else
    log "Source service account already has required permissions."
fi

# =========================================================
# DESTINATION INSTANCE
# =========================================================
log "Fetching Destination Cloud SQL service account..."

SA=$(gcloud sql instances describe "$DESTINATION_NAME" \
    --project="$PROJECT_ID" \
    --format="value(serviceAccountEmailAddress)")

if [ -z "$SA" ]; then
    log "ERROR: Could not fetch destination service account"
    exit 1
fi

log "Destination Service Account: $SA"

log "Checking if bucket exists..."

if ! gsutil ls -b "gs://$BUCKET_NAME" >/dev/null 2>&1; then
    log "ERROR: Bucket does not exist"
    exit 1
fi

log "Bucket exists."

log "Checking existing IAM permissions for destination instance..."

EXISTS=$(gsutil iam get "gs://$BUCKET_NAME" | \
grep -A 5 "roles/storage.objectAdmin" | grep "$SA" || true)

if [ -z "$EXISTS" ]; then

    log "Granting object-level permissions to destination service account..."

    gsutil iam ch \
    "serviceAccount:$SA:roles/storage.objectAdmin" \
    "gs://$BUCKET_NAME"

    log "Permissions granted successfully to destination instance."

else
    log "Destination service account already has required permissions."
fi

# =========================================================
# COMPLETED
# =========================================================
log "IAM setup completed successfully."
log "Log file generated: $LOG_FILE"