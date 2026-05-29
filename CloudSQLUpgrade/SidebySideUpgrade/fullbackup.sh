#!/bin/bash

set -Eeuo pipefail

# --- Config ---
PROJECT_ID="project-ae821a0f-e5f5-42e7-b15"
INSTANCE="prod2019"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <DB_NAME>"
  exit 1
fi

DB=$1

BUCKET_BASE_PATH="test-dms-dxc/${DB}/full"

EPOCH=$(date +%s)
URI="gs://${BUCKET_BASE_PATH}/${EPOCH}"

# =========================================================
# LOGGING
# =========================================================
LOG_FILE="${DB}_FULLbackupexport_$(date +%Y%m%d_%H%M%S).log"
LOCAL_LOG="/tmp/${LOG_FILE}"

exec > >(tee -a "$LOCAL_LOG") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error_handler() {
    local exit_code=$?
    local line_no=$1

    echo "--------------------------------------------------"
    echo "[ERROR] Script failed"
    echo "[ERROR] Exit Code : $exit_code"
    echo "[ERROR] Line No   : $line_no"
    echo "[ERROR] Time      : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "--------------------------------------------------"

    # Upload log even if script fails
    gcloud storage cp "$LOCAL_LOG" \
    "gs://test-dms-dxc/metadata/${LOG_FILE}" >/dev/null 2>&1 || true

    exit $exit_code
}

trap 'error_handler $LINENO' ERR

# =========================================================
# START
# =========================================================
log "Starting striped backup for DB: ${DB}"
log "Destination: ${URI}"

# --- Capture TRUE anchor time (BEFORE backup starts) ---
START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "$START_TIME" | gcloud storage cp - \
"gs://test-dms-dxc/metadata/${DB}_anchor.txt"

log "Anchor time saved: $START_TIME"

# --- Get token ---
log "Fetching access token..."

ACCESS_TOKEN=$(gcloud auth print-access-token)

log "Access token fetched successfully."

# --- Trigger export ---
log "Triggering Cloud SQL export API..."

RESPONSE=$(curl -s -X POST \
-H "Authorization: Bearer ${ACCESS_TOKEN}" \
-H "Content-Type: application/json" \
-d "{
  \"exportContext\": {
    \"fileType\": \"BAK\",
    \"uri\": \"${URI}\",
    \"databases\": [\"${DB}\"],
    \"bakExportOptions\": {
      \"stripeCount\": 5
    }
  }
}" \
"https://sqladmin.googleapis.com/v1/projects/${PROJECT_ID}/instances/${INSTANCE}/export")

log "API Response: $RESPONSE"

# Extract operation name
OPERATION=$(echo "$RESPONSE" | grep -o '"name": *"[^"]*"' | awk -F\" '{print $4}')

if [ -z "$OPERATION" ]; then
  log "ERROR: Failed to get operation ID"
  exit 1
fi

log "Operation ID: $OPERATION"

# --- Wait for completion ---
log "Waiting for export to complete..."

while true; do

  STATUS=$(curl -s \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://sqladmin.googleapis.com/v1/projects/${PROJECT_ID}/operations/${OPERATION}" \
  | grep -o '"status": *"[^"]*"' | awk -F\" '{print $4}')

  log "Current status: $STATUS"

  if [ "$STATUS" == "DONE" ]; then
    break
  fi

  sleep 10

done

log "Export completed successfully"

# --- Capture TRUE anchor end time ---
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "$END_TIME" | gcloud storage cp - \
"gs://test-dms-dxc/metadata/${DB}_anchorend.txt"

log "Anchor end time saved: $END_TIME"

# =========================================================
# UPLOAD LOG FILE
# =========================================================
log "Uploading log file to bucket metadata folder..."

gcloud storage cp "$LOCAL_LOG" \
"gs://test-dms-dxc/metadata/${LOG_FILE}"

log "Log file uploaded successfully."

log "Script completed successfully."