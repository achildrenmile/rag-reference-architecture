#!/bin/bash
# RAG Reference Architecture - Automated Backup Script
# Runs weekly, keeps 2 weeks of backups, skips Ollama models

set -e

# Configuration
BACKUP_DIR="/tmp"
REMOTE_HOST="straliadmin@192.168.1.206"
REMOTE_PATH="/volume1/docker/rag-node-01-backup"
RETENTION_COUNT=2
BACKUP_NAME="rag-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$HOME/rag-reference-architecture/backup.log"
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Logging function
log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

log "=========================================="
log "Starting backup: $BACKUP_NAME"
log "=========================================="

cd ~/rag-reference-architecture

# 1. Backup configuration files
log "Backing up configuration files..."
tar -czf ${BACKUP_DIR}/${BACKUP_NAME}-config.tar.gz \
    docker-compose.yml .env mcpo/ static/ .gitignore README.md SECURITY.md 2>/dev/null || true

# 2. Backup OpenWebUI data (database, uploads, embeddings)
log "Backing up OpenWebUI data..."
docker run --rm \
    -v rag-reference-architecture_openwebui-data:/data \
    -v ${BACKUP_DIR}:/backup \
    alpine sh -c "tar -czf /backup/${BACKUP_NAME}-openwebui.tar.gz -C /data . && chown ${USER_ID}:${GROUP_ID} /backup/${BACKUP_NAME}-openwebui.tar.gz"

# 3. Backup Elasticsearch data
log "Backing up Elasticsearch data..."
docker run --rm \
    -v rag-reference-architecture_esdata:/data \
    -v ${BACKUP_DIR}:/backup \
    alpine sh -c "tar -czf /backup/${BACKUP_NAME}-esdata.tar.gz -C /data . && chown ${USER_ID}:${GROUP_ID} /backup/${BACKUP_NAME}-esdata.tar.gz"

# Note: Ollama models skipped (rarely change, ~11GB)

# 4. Show local backup sizes
log "Local backup files created:"
ls -lh ${BACKUP_DIR}/${BACKUP_NAME}*.tar.gz

# 5. Transfer to Synology NAS
log "Transferring to Synology NAS..."
ssh ${REMOTE_HOST} "mkdir -p ${REMOTE_PATH}" 2>/dev/null || true

for file in ${BACKUP_DIR}/${BACKUP_NAME}*.tar.gz; do
    filename=$(basename "$file")
    log "  Transferring $filename..."
    ssh ${REMOTE_HOST} "cat > ${REMOTE_PATH}/${filename}" < "$file"
done

# 6. Clean up local backup files
log "Cleaning up local backup files..."
rm -f ${BACKUP_DIR}/${BACKUP_NAME}*.tar.gz

# 7. Remove old backups on Synology (keep last N)
log "Removing old backups (keeping last ${RETENTION_COUNT})..."
ssh ${REMOTE_HOST} "cd ${REMOTE_PATH} && ls -t rag-backup-*-config.tar.gz 2>/dev/null | tail -n +$((RETENTION_COUNT + 1)) | while read f; do
    prefix=\${f%-config.tar.gz}
    rm -f \${prefix}-config.tar.gz \${prefix}-openwebui.tar.gz \${prefix}-esdata.tar.gz
    echo \"Removed: \${prefix}\"
done"

# 8. Show remaining backups
log "Current backups on Synology:"
ssh ${REMOTE_HOST} "ls -lh ${REMOTE_PATH}/"

log "=========================================="
log "Backup completed successfully: $BACKUP_NAME"
log "=========================================="
