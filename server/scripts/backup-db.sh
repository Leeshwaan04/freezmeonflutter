#!/usr/bin/env bash
# backup-db.sh — pg_dump → gzip → S3
# Install cron: 0 2 * * * /home/ubuntu/freezme-server/scripts/backup-db.sh >> /var/log/freezme/backup.log 2>&1
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/tmp/freezme_backup_${TIMESTAMP}.sql.gz"
S3_BUCKET="${BACKUP_S3_BUCKET:-freezme-backups}"
S3_PREFIX="${BACKUP_S3_PREFIX:-db}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

# Load env if running as cron (no shell profile)
if [[ -f /home/ubuntu/freezme-server/.env ]]; then
  set -a
  # shellcheck source=/dev/null
  source /home/ubuntu/freezme-server/.env
  set +a
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "[backup] ERROR: DATABASE_URL not set" >&2
  exit 1
fi

echo "[backup] Starting backup at $(date)"

# pg_dump using DATABASE_URL directly
pg_dump "$DATABASE_URL" | gzip > "$BACKUP_FILE"

echo "[backup] Backup written to $BACKUP_FILE ($(du -sh "$BACKUP_FILE" | cut -f1))"

# Upload to S3
aws s3 cp "$BACKUP_FILE" "s3://${S3_BUCKET}/${S3_PREFIX}/freezme_${TIMESTAMP}.sql.gz" \
  --storage-class STANDARD_IA

echo "[backup] Uploaded to s3://${S3_BUCKET}/${S3_PREFIX}/freezme_${TIMESTAMP}.sql.gz"

# Remove local temp file
rm -f "$BACKUP_FILE"

# Prune old backups from S3 (older than RETENTION_DAYS)
CUTOFF=$(date -d "-${RETENTION_DAYS} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
  || date -v"-${RETENTION_DAYS}d" +%Y-%m-%dT%H:%M:%SZ)

aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" \
  | awk '{print $4}' \
  | while read -r key; do
      file_date=$(echo "$key" | grep -oP '\d{8}' | head -1)
      if [[ -n "$file_date" ]] && [[ "$file_date" < "$(date -d "$CUTOFF" +%Y%m%d 2>/dev/null || date -v"${RETENTION_DAYS}d" +%Y%m%d)" ]]; then
        echo "[backup] Deleting old backup: $key"
        aws s3 rm "s3://${S3_BUCKET}/${S3_PREFIX}/$key"
      fi
    done

echo "[backup] Done at $(date)"
