#!/usr/bin/env bash

# This script is designed to take a backup of the Satisfactory world save
# and save it in a separate backup directory. The script will automatically
# run before starting the satisfactory.service systemd service ensures that
# the game server does not accidentally corrupt any of the game saves.
# This script also sets a retention period to keep the directory size manageable.

set -euo pipefail
IFS=$'\n\t'

# Configuration
SOURCE_DIR="/home/steam/.config/Epic/FactoryGame/Saved/SaveGames"
BACKUP_DIR="/opt/satisfactory_backups"
MIN_BACKUPS=30
CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="${BACKUP_DIR}/satisfactory_backup_${CURRENT_DATE}.tar.gz"

# Logging function for standardized output messages and system log
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
    logger --tag satisfactory_backup "$1"
}

# Function to send email notifications using system aliases
send_email() {
    local subject="$1"
    local message="$2"
    local backup_size=$(du --human-readable --summarize "${BACKUP_FILE}" | cut --fields=1)
    local backup_count=$(find "${BACKUP_DIR}" -type f -name 'satisfactory_backup_*.tar.gz' | wc --lines)

    local detailed_message="Backup Details:
- Backup File: ${BACKUP_FILE}
- Backup Size: ${backup_size}
- Total Backups Stored: ${backup_count}

${message}"

    # Sending email to root, which will utilize /etc/aliases for actual delivery
    echo "$detailed_message" | mail --subject "$subject" root

    log "Sending email notification to root: $subject"
}

# Cleanup function to be called on script failure
error_cleanup() {
    local exit_status=$?
    local error_message="Backup script failed with status $exit_status at $(date +'%Y-%m-%d %H:%M:%S')"
    log "$error_message"
    send_email "Backup Script Failure" "$error_message"
    exit $exit_status
}

# Trap errors
trap error_cleanup ERR

create_backup() {
    log "Starting backup..."
    tar --create --gzip --file="${BACKUP_FILE}" "${SOURCE_DIR}"
    log "Backup saved to ${BACKUP_FILE}"
}

verify_backup() {
    log "Verifying backup integrity..."
    if tar --list --gzip --file="${BACKUP_FILE}" > /dev/null; then
        log "Backup integrity check passed."
    else
        log "Backup integrity check failed."
        exit 1
    fi
}

# Ensure source directory exists
if [[ ! -d "${SOURCE_DIR}" ]]; then
    log "Source directory ${SOURCE_DIR} does not exist. Backup aborted."
    exit 1
fi

# Ensure backup directory exists
if [[ ! -d "${BACKUP_DIR}" ]]; then
    log "Creating backup directory ${BACKUP_DIR}."
    mkdir --parents "${BACKUP_DIR}"
fi

# Create and verify backup
create_backup
verify_backup

# Function to remove old backups beyond the retention limit
cleanup_old_backups() {
    local backups=($(find "${BACKUP_DIR}" -type f -name 'satisfactory_backup_*.tar.gz' -printf '%T+ %p\n' | sort | cut --delimiter=' ' --fields=2-))
    local count=${#backups[@]}

    if (( count > MIN_BACKUPS )); then
        for (( i=0; i<count-MIN_BACKUPS; i++ )); do
            # Optionally verify the tarball structure or content
            if tar --list --gzip --file "${backups[$i]}" > /dev/null 2>&1; then
                log "Removing old backup: ${backups[$i]}"
                rm --force "${backups[$i]}"
            else
                log "Skipping removal of suspected non-backup file: ${backups[$i]}"
            fi
        done
    else
        log "No old backups to remove. Minimum backups count maintained."
    fi
}

# Retention policy implementation
log "Checking for old backups to remove..."
cleanup_old_backups

log "Backup process completed."
