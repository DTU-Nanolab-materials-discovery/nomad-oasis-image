#!/bin/bash

# Configuration
BACKUP_DIR="/docker/nomad-oasis/.volumes/mongo"
CONTAINER_NAME="nomad_oasis_mongo"
DATABASE_NAME="nomad_oasis_v1"

# Run mongodump
docker exec "$CONTAINER_NAME" mongodump -d "$DATABASE_NAME" -o "/backup"

# Log completion
echo "$(date): Backup completed for $DATABASE_NAME" >> "$BACKUP_DIR/backup.log"