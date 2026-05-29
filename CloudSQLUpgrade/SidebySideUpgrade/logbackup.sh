#!/bin/bash

set -Eeuo pipefail

# =========================================================
# INPUT
# =========================================================
DB="${1:-}"

if [ -z "$DB" ]; then
  echo "Usage: $0 <DB_NAME>"
  exit 1
fi

# =========================================================
# CONFIG
# =========================================================
INSTANCE="prod2019"
BUCKET="gs://test-dms-dxc"

MAIN_PATH="${BUCKET}/${DB}/log"
BASE_PATH="${BUCKET}/metadata/staging/${DB}"
ANCHOR_PATH="${BUCKET}/metadata/${DB}_anchor.txt"

RUN_EPOCH=$(date +%s)

# =========================================================
# LOGGING
# =========================================================
LOG_FILE="${DB}_TLOGexport_$(date +%Y%m%d_%H%M%S).log"
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

    # Upload log file even if script fails
    gcloud storage cp "$LOCAL_LOG" \
    "${BUCKET}/metadata/${LOG_FILE}" >/dev/null 2>&1 || true

    exit $exit_code
}

trap 'error_handler $LINENO' ERR

# =========================================================
# START
# =========================================================
log "===== TLOG Export Started ====="
log "Database: $DB"

# =========================================================
# CHECK ANCHOR FILE
# =========================================================
log "Checking anchor file..."

if ! gcloud storage ls "$ANCHOR_PATH" >/dev/null 2>&1; then
    log "ERROR: Anchor file missing: $ANCHOR_PATH"
    exit 1
fi

START_TIME=$(gcloud storage cat "$ANCHOR_PATH" | tr -d '\n')

log "Start Time: $START_TIME"

END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

log "End Time: $END_TIME"

EXPORT_PREFIX="${BASE_PATH}/tmp_${RUN_EPOCH}"

log "Export Prefix: $EXPORT_PREFIX"

# =========================================================
# EXPORT TLOG
# =========================================================
log "Starting TLOG export..."

gcloud sql export bak "$INSTANCE" \
"$EXPORT_PREFIX" \
--database=$DB \
--bak-type=TLOG \
--export-log-start-time="$START_TIME" \
--export-log-end-time="$END_TIME"

log "TLOG export command submitted successfully."

# =========================================================
# WAIT FOR FILES
# =========================================================
log "Waiting for export files..."

FILES_FOUND=false

for i in {1..10}; do

    if gcloud storage ls -r "$EXPORT_PREFIX" | grep -E '\.log$' >/dev/null 2>&1; then
        log "Files detected."
        FILES_FOUND=true
        break
    fi

    log "Retry $i..."
    sleep 5

done

if [ "$FILES_FOUND" = false ]; then
    log "ERROR: No log files found after waiting."
    exit 1
fi

# =========================================================
# NORMALIZATION
# =========================================================
log "Starting normalization..."

LOG_FILES=$(gcloud storage ls -r "$EXPORT_PREFIX" 2>/dev/null | grep -E '\.log$')

if [ -z "$LOG_FILES" ]; then
    log "ERROR: No log files found for normalization."
    exit 1
fi

PROCESSED_COUNT=0

for file_uri in $LOG_FILES; do

    filename=$(basename "$file_uri")

    ts_raw=$(echo "$filename" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}' || true)

    part_num=$(echo "$filename" | grep -oE '_[0-9]+_dba[s]?' | cut -d'_' -f2)

    [ -z "$part_num" ] && part_num=1

    if [ -z "$ts_raw" ]; then
        log "Skipping file (timestamp not found): $filename"
        continue
    fi

    formatted_ts=$(echo "$ts_raw" | sed 's/-\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)$/ \1:\2:\3/')

    epoch=$(date -u -d "$formatted_ts" +%s 2>/dev/null || \
            date -j -f "%Y-%m-%d %H:%M:%S" "$formatted_ts" +%s)

    new_name="${DB}.${epoch}.${part_num}.trn"

    log "Processing: $filename -> $new_name"

    gcloud storage mv "$file_uri" "${MAIN_PATH}/${new_name}"

    PROCESSED_COUNT=$((PROCESSED_COUNT + 1))

done

if [ "$PROCESSED_COUNT" -eq 0 ]; then
    log "ERROR: No files were normalized."
    exit 1
fi

log "Total files processed: $PROCESSED_COUNT"

# =========================================================
# CLEANUP
# =========================================================
log "Cleaning up temp export folder..."

gcloud storage rm -r "$EXPORT_PREFIX" >/dev/null 2>&1 || true

log "Cleanup completed."

# =========================================================
# UPLOAD LOG FILE
# =========================================================
log "Uploading log file to metadata folder..."

gcloud storage cp "$LOCAL_LOG" \
"${BUCKET}/metadata/${LOG_FILE}"

log "Log file uploaded successfully."

log "===== TLOG Export Completed Successfully ====="