#!/bin/bash

# Exit immediately if any command fails
set -e

# Check if running as root/sudo
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] This script must be run with sudo:"
  echo "sudo ./casaos_restore.sh"
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

TEMP_RESTORE_DIR="/tmp/casaos_restore_temp"

echo "======================================================"
echo "    INTERACTIVE CASAOS / DATA / SQL RESTORE"
echo "======================================================"
echo "Backup Server: ${DEST_USER}@${DEST_IP}:${DEST_DIR}"

# ==========================================
# STEP 1: RESTORE /DATA
# ==========================================
echo ""
echo "[1/3] Restoring /DATA directory..."
read -p "Do you want to sync and restore the /DATA folder now? (y/N): " CONFIRM_DATA
if [[ "$CONFIRM_DATA" == "y" || "$CONFIRM_DATA" == "Y" ]]; then
  mkdir -p /DATA
  rsync -avz --progress \
    -e "ssh -i $SSH_KEY" \
    "${DEST_USER}@${DEST_IP}:${DEST_DIR}/DATA/" /DATA/
  echo " /DATA restored successfully!"
else
  echo "Skipping /DATA restoration."
fi

# ==========================================
# STEP 2: NEXTCLOUD PERMISSIONS FIX (If exists)
# ==========================================

echo ""
echo "[2/3] Adjusting Nextcloud permissions in $NEXTCLOUD_DATA_DIR..."
read -p "Do you want to adjust Nextcloud permissions now? (y/N): " CONFIRM_PERMS
if [[ "$CONFIRM_PERMS" == "y" || "$CONFIRM_PERMS" == "Y" ]]; then
  if [ -d "$NEXTCLOUD_DATA_DIR" ]; then
    chown -R 33:33 "$NEXTCLOUD_DATA_DIR"
    chmod -R 770 "$NEXTCLOUD_DATA_DIR"
    echo " Nextcloud permissions adjusted successfully!"
  else
    echo " Nextcloud directory not found. Skipping permissions adjustment."
  fi
else
  echo "Skipping Nextcloud permissions adjustment."
fi

# ==========================================
# STEP 3: RESTORE SQL
# ==========================================
echo ""
echo "[3/3] Restoring MariaDB Database..."
read -p "Do you want to restore the MariaDB dump? (y/N): " CONFIRM_DB
if [[ "$CONFIRM_DB" == "y" || "$CONFIRM_DB" == "Y" ]]; then
  # 1. Ensure MariaDB container is running
  if ! docker ps | grep -q "$SQL_CONTAINER"; then
    echo "Starting $SQL_CONTAINER container..."
    docker start "$SQL_CONTAINER" || true
    sleep 5
  fi

  # 2. List available SQL backups from the remote server
  echo ""
  echo "Fetching available SQL backups from server..."
  BACKUPS_SQL=$(ssh -i "$SSH_KEY" "${DEST_USER}@${DEST_IP}" "ls -1 '${DEST_DIR}/backups_sql/'*.sql.gz 2>/dev/null" | xargs -n1 basename)

  if [ -z "$BACKUPS_SQL" ]; then
    echo "[ERROR] No .sql.gz files found on the remote server!"
  else
    echo "Available backups:"
    select SQL_FILE_CHOICE in $BACKUPS_SQL "Cancel"; do
      if [ "$SQL_FILE_CHOICE" == "Cancel" ]; then
        echo "Database restoration canceled."
        break
      elif [ -n "$SQL_FILE_CHOICE" ]; then
        echo "Selected file: $SQL_FILE_CHOICE"
        
        mkdir -p "$TEMP_RESTORE_DIR"
        
        echo "Downloading $SQL_FILE_CHOICE..."
        rsync -avz -e "ssh -i $SSH_KEY" \
          "${DEST_USER}@${DEST_IP}:${DEST_DIR}/backups_sql/$SQL_FILE_CHOICE" "$TEMP_RESTORE_DIR/"

        echo "Importing database into $SQL_CONTAINER (please wait)..."
        zcat "$TEMP_RESTORE_DIR/$SQL_FILE_CHOICE" | docker exec -i "$SQL_CONTAINER" mariadb -u root -p"$SQL_ROOT_PASSWD"

        rm -rf "$TEMP_RESTORE_DIR"
        echo " MariaDB database restored successfully!"
        break
      else
        echo "Invalid option, please try again."
      fi
    done
  fi
else
  echo "Skipping MariaDB restoration."
fi

# ==========================================
# COMPLETION
# ==========================================
echo ""
echo "======================================================"
echo "    RESTORE PROCESS COMPLETED!"
echo "======================================================"
echo "It is recommended to restart all containers to apply changes:"
echo "docker restart \$(docker ps -q)"