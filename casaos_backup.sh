#!/bin/bash

# Exit immediately if any command fails
set -e

# Check if running as root/sudo
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] This script must be run with sudo:"
  echo "sudo ./casaos_backup.sh"
  exit 1
fi

# ==========================================
# LOAD CONFIGURATION VARIABLES
# ==========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  echo "[ERROR] Configuration file '$CONFIG_FILE' not found!"
  exit 1
fi

EXCLUDE_FILE="$SCRIPT_DIR/exclude.txt"

CURRENT_DATE_TIME=$(date +'%Y-%m-%d_%H-%M')
LOCAL_SQL_DIR="/tmp/backup_sql_$CURRENT_DATE_TIME"

# ==========================================
# LOCAL LOG FILE CONFIGURATION
# ==========================================
mkdir -p "$SCRIPT_DIR/logs/"
LOG_FILE="$SCRIPT_DIR/logs/backup_${CURRENT_DATE_TIME}.log"

echo "=== Starting CasaOS Backup via SSH/SFTP: $CURRENT_DATE_TIME ==="
echo "Detailed logs are being written to: $LOG_FILE"
echo "To follow the execution in real time, run: tail -f \"$LOG_FILE\""

# Redirect output (stdout and stderr) DIRECTLY to the log file, omitting terminal output from this point forward
exec > "$LOG_FILE" 2>&1

# 1. Ensure the directory structure exists on the destination machine
ssh -i "$SSH_KEY" "${DEST_USER}@${DEST_IP}" "mkdir -p '${DEST_DIR}/backups_sql' '${DEST_DIR}/DATA'"

# ==========================================
# 1. SQL DUMP
# ==========================================
echo "[1/2] Generating SQL dump..."
mkdir -p "$LOCAL_SQL_DIR"
SQL_FILE="$LOCAL_SQL_DIR/all_databases_$CURRENT_DATE_TIME.sql.gz"

# Execute local dump into the /tmp directory
docker exec -i "$SQL_CONTAINER" mariadb-dump -u root -p"$SQL_ROOT_PASSWD" --all-databases | gzip > "$SQL_FILE"

# Upload compressed dump via rsync/SSH to the destination machine
echo " Sending database dump to destination machine..."
rsync -avz -e "ssh -i $SSH_KEY" "$SQL_FILE" "${DEST_USER}@${DEST_IP}:${DEST_DIR}/backups_sql/"

# Clean up temporary local file
rm -rf "$LOCAL_SQL_DIR"

# ==========================================
# 2. RSYNC /DATA
# ==========================================
echo "[2/2] Synchronizing /DATA..."
rsync -avz --progress --delete \
  --exclude-from="$EXCLUDE_FILE" \
  -e "ssh -i $SSH_KEY" /DATA/ "${DEST_USER}@${DEST_IP}:${DEST_DIR}/DATA/"

echo "=== Backup completed successfully at $CURRENT_DATE_TIME! ==="