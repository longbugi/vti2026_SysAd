#!/bin/bash

set +e
set -o pipefail

DB_NAME="demo10"
BACKUP_DIR="/backup/postgresql"
LOG_FILE="/var/log/postgresql_backup.log"
EMAIL="yen.nguyenhoacat@gmail.com"

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${DATE}.sql.gz"
ERROR_FILE="/tmp/postgresql_backup_error.log"


#Check packages mailutils and gzip, if not installed, install them
PACKAGES_TO_INSTALL=()

if ! dpkg -s mailutils >/dev/null 2>&1; then
    PACKAGES_TO_INSTALL+=("mailutils")
fi

if ! dpkg -s gzip >/dev/null 2>&1; then
    PACKAGES_TO_INSTALL+=("gzip")
fi

if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
    echo "Missing packages detected: ${PACKAGES_TO_INSTALL[*]}"
    apt update
    apt install -y "${PACKAGES_TO_INSTALL[@]}"
else
    echo "mailutils and gzip already installed."
fi

mkdir -p "$BACKUP_DIR"
chown postgres:postgres "$BACKUP_DIR"


echo "[$(date)] Starting backup for database: $DB_NAME" >> "$LOG_FILE"

sudo -u postgres pg_dump "$DB_NAME" 2> "$ERROR_FILE" | gzip > "$BACKUP_FILE"
BACKUP_STATUS=$?

if [ $BACKUP_STATUS -eq 0 ]; then
    echo "[$(date)] Backup successful: $BACKUP_FILE" >> "$LOG_FILE"
else
    echo "[$(date)] Backup FAILED for database: $DB_NAME" >> "$LOG_FILE"
    cat "$ERROR_FILE" >> "$LOG_FILE"

    {
    echo "Subject: PostgreSQL Backup FAILED on $(hostname)"
    echo "To: $EMAIL"
    echo
    echo "PostgreSQL backup failed."
    echo
    echo "Server: $(hostname)"
    echo "Database: $DB_NAME"
    echo "Time: $(date)"
    echo
    echo "Error:"
    cat "$ERROR_FILE"
    } | sendmail "$EMAIL"

    rm -f "$BACKUP_FILE"
    exit 1
fi

find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +7 -delete
rm -f "$ERROR_FILE"