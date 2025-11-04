#!/bin/bash
# ===============================================================
# Automated Backup System
# Author: Shashank
# Description: Creates, verifies, and rotates backups automatically
# ===============================================================

set -euo pipefail

# --- Global Variables ---
CONFIG_FILE="./backup.config"
LOG_FILE="./backup.log"
LOCK_FILE="/tmp/backup.lock"
TIMESTAMP=$(date +%Y-%m-%d-%H%M)

# --- Logging Function ---
log() {
    local LEVEL="$1"
    local MESSAGE="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $LEVEL: $MESSAGE" | tee -a "$LOG_FILE"
}

# --- Load Configuration ---
if [[ ! -f "$CONFIG_FILE" ]]; then
    log "ERROR" "Configuration file not found: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

mkdir -p "$BACKUP_DESTINATION"

# --- Prevent Multiple Runs ---
if [[ -f "$LOCK_FILE" ]]; then
    log "ERROR" "Another backup is already running. Exiting."
    exit 1
fi
trap 'rm -f "$LOCK_FILE"' EXIT
touch "$LOCK_FILE"

# --- Helper Functions ---
check_space() {
    local SOURCE="$1"
    local REQUIRED AVAILABLE
    REQUIRED=$(du -s "$SOURCE" | cut -f1)
    AVAILABLE=$(df "$BACKUP_DESTINATION" | awk 'NR==2 {print $4}')
    if (( AVAILABLE < REQUIRED )); then
        log "ERROR" "Not enough disk space for backup."
        exit 1
    fi
}

create_backup() {
    local SOURCE_DIR="$1"
    local BACKUP_FILE="backup-$TIMESTAMP.tar.gz"
    local DEST_FILE="$BACKUP_DESTINATION/$BACKUP_FILE"
    local CHECKSUM_FILE="$DEST_FILE.md5"

    # Build exclude list
    local EXCLUDE_ARGS=()
    IFS=',' read -ra EXCLUDES <<< "$EXCLUDE_PATTERNS"
    for pattern in "${EXCLUDES[@]}"; do
        EXCLUDE_ARGS+=(--exclude="$pattern")
    done

    log "INFO" "Creating backup for $SOURCE_DIR"
    tar -czf "$DEST_FILE" "${EXCLUDE_ARGS[@]}" "$SOURCE_DIR" || {
        log "ERROR" "Failed to create backup archive."
        exit 1
    }

    md5sum "$DEST_FILE" > "$CHECKSUM_FILE"
    log "SUCCESS" "Backup created: $DEST_FILE"
}

verify_backup() {
    local BACKUP_FILE="$1"
    local CHECKSUM_FILE="$BACKUP_FILE.md5"

    log "INFO" "Verifying backup integrity..."
    if ! md5sum -c "$CHECKSUM_FILE" &>/dev/null; then
        log "ERROR" "Checksum verification failed for $BACKUP_FILE"
        return 1
    fi
    if ! tar -tzf "$BACKUP_FILE" &>/dev/null; then
        log "ERROR" "Archive verification failed for $BACKUP_FILE"
        return 1
    fi
    log "SUCCESS" "Backup verified successfully"
}

cleanup_old_backups() {
    log "INFO" "Applying retention policy..."
    cd "$BACKUP_DESTINATION" || exit 1

    # Get all backups sorted by date
    BACKUPS=($(ls -1 backup-*.tar.gz 2>/dev/null | sort))
    TOTAL=${#BACKUPS[@]}
    if (( TOTAL == 0 )); then
        log "INFO" "No backups to clean."
        return
    fi

    # Keep last N backups
    KEEP=$((DAILY_KEEP + WEEKLY_KEEP + MONTHLY_KEEP))
    if (( TOTAL > KEEP )); then
        DELETE_COUNT=$((TOTAL - KEEP))
        for ((i=0; i<DELETE_COUNT; i++)); do
            log "INFO" "Deleting old backup: ${BACKUPS[$i]}"
            rm -f "${BACKUPS[$i]}" "${BACKUPS[$i]}.md5"
        done
    fi
}

restore_backup() {
    local BACKUP_FILE="$1"
    local DEST_DIR="$2"

    if [[ ! -f "$BACKUP_FILE" ]]; then
        log "ERROR" "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
    mkdir -p "$DEST_DIR"
    tar -xzf "$BACKUP_FILE" -C "$DEST_DIR"
    log "SUCCESS" "Backup restored to $DEST_DIR"
}

list_backups() {
    log "INFO" "Listing available backups:"
    ls -lh "$BACKUP_DESTINATION"/backup-*.tar.gz 2>/dev/null || echo "No backups found."
}

dry_run() {
    local SOURCE_DIR="$1"
    echo "[DRY-RUN] Would create backup from: $SOURCE_DIR"
    echo "[DRY-RUN] Would exclude: $EXCLUDE_PATTERNS"
    echo "[DRY-RUN] Would save to: $BACKUP_DESTINATION/backup-$TIMESTAMP.tar.gz"
}

# --- Argument Parsing ---
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <source_folder> | --dry-run <folder> | --restore <backup_file> --to <folder> | --list"
    exit 1
fi

if [[ "$1" == "--dry-run" ]]; then
    MODE="dry-run"
    SOURCE_DIR="$2"
elif [[ "$1" == "--restore" ]]; then
    MODE="restore"
    BACKUP_FILE="$2"
    if [[ "$3" != "--to" || -z "${4:-}" ]]; then
        echo "Usage: $0 --restore <backup_file> --to <destination_folder>"
        exit 1
    fi
    DEST_DIR="$4"
elif [[ "$1" == "--list" ]]; then
    MODE="list"
else
    MODE="backup"
    SOURCE_DIR="$1"
fi

# --- Main Execution ---
case "$MODE" in
    dry-run)
        dry_run "$SOURCE_DIR"
        ;;
    restore)
        restore_backup "$BACKUP_FILE" "$DEST_DIR"
        ;;
    list)
        list_backups
        ;;
    backup)
        if [[ ! -d "$SOURCE_DIR" ]]; then
            log "ERROR" "Source folder not found: $SOURCE_DIR"
            exit 1
        fi
        check_space "$SOURCE_DIR"
        create_backup "$SOURCE_DIR"
        verify_backup "$BACKUP_DESTINATION/backup-$TIMESTAMP.tar.gz"
        cleanup_old_backups
        ;;
esac
