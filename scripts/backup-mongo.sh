#!/bin/bash

# Configuration
BACKUP_DIR="/docker/nomad-oasis/.volumes/mongo"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CONTAINER_NAME="nomad_oasis_mongo"
DATABASE_NAME="nomad_oasis_v1"

# Run mongodump
docker exec "$CONTAINER_NAME" mongodump -d "$DATABASE_NAME" -o "/backup/$TIMESTAMP"

# Optional: Keep only last 7 days of backups
find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" -mtime +7 -exec rm -rf {} \;

# Log completion
echo "$(date): Backup completed for $DATABASE_NAME" >> "$BACKUP_DIR/backup.log"