#!/bin/bash

set -Eeuo pipefail

echo "===== DMS Folder Automation (Manual Mode) ====="

# ===== ERROR HANDLER =====
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

# ===== LOG FUNCTION =====
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ===== INPUT PARAMETERS =====
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <BUCKET_NAME> <PROJECT_ID> <REGION>"
    echo "Example:"
    echo "./create_dms_bucket.sh test-dms-dxc gb75613 us-central1"
    exit 1
fi

BUCKET_NAME="$1"
PROJECT_ID="$2"
REGION="$3"

BUCKET="gs://$BUCKET_NAME"

# ===== VALIDATE GCLOUD LOGIN =====
log "Checking gcloud authentication..."

ACTIVE_ACCOUNT=$(gcloud auth list \
    --filter=status:ACTIVE \
    --format="value(account)")

if [ -z "$ACTIVE_ACCOUNT" ]; then
    log "ERROR: No active gcloud account found."
    exit 1
fi

log "Authenticated as: $ACTIVE_ACCOUNT"

# ===== VALIDATE PROJECT ACCESS =====
log "Checking access to project: $PROJECT_ID"

if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
    log "ERROR: Cannot access project: $PROJECT_ID"
    log "Possible reasons:"
    log "- Project does not exist"
    log "- Missing IAM permissions"
    log "- Wrong project ID"
    exit 1
fi

log "Project access verified."

# ===== CHECK / CREATE BUCKET =====
log "Checking bucket: $BUCKET"

if ! gcloud storage buckets describe "$BUCKET" >/dev/null 2>&1; then

    log "Bucket does not exist. Creating..."

    gcloud storage buckets create "$BUCKET" \
        --project="$PROJECT_ID" \
        --location="$REGION"

    log "Bucket created successfully."

else
    log "Bucket already exists."
fi

# ===== INPUT DATABASE NAMES =====
log "Enter database names (space-separated):"

read -r -a DB_ARRAY

if [ ${#DB_ARRAY[@]} -eq 0 ]; then
    log "ERROR: No database names provided"
    exit 1
fi

log "Databases detected: ${DB_ARRAY[*]}"

# ===== CREATE STRUCTURE =====
for DB in "${DB_ARRAY[@]}"; do

    DB=$(echo "$DB" | xargs)

    if [[ -z "$DB" ]]; then
        log "Skipping empty database name"
        continue
    fi

    if [[ "$DB" =~ [[:space:]] ]]; then
        log "Skipping invalid DB name (contains spaces): $DB"
        continue
    fi

    log "Processing database: $DB"

    META_PATH="$BUCKET/metadata/Staging"

    log "Checking path: $META_PATH"

    if ! gcloud storage ls "$META_PATH" >/dev/null 2>&1; then

        log "Creating folder structure "

        echo "" | gcloud storage cp - "$META_PATH/.keep"

        log "Created: $META_PATH"

    else
        log "Already exists: $META_PATH"
    fi

done

log "===== Folder creation completed successfully ====="