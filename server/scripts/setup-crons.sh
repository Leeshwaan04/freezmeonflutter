#!/usr/bin/env bash
# setup-crons.sh — Install certbot renewal + daily DB backup cron on EC2.
# Run once after initial deploy: sudo ./scripts/setup-crons.sh
set -euo pipefail

APP_DIR="/home/ubuntu/freezme-server"
LOG_DIR="/var/log/freezme"
BACKUP_SCRIPT="${APP_DIR}/scripts/backup-db.sh"

echo "=== Setting up Freezme cron jobs ==="

# ── 1. Certbot auto-renewal ────────────────────────────────────────────────
# certbot installs a systemd timer by default; check and install if missing.
if systemctl is-active --quiet certbot.timer 2>/dev/null; then
  echo "[cron] certbot.timer already active — skipping"
else
  echo "[cron] Installing certbot renewal via cron"
  # Fallback: add cron entry that runs twice daily (standard recommendation)
  CERTBOT_CRON="0 0,12 * * * root certbot renew --quiet --deploy-hook 'systemctl reload nginx' >> /var/log/letsencrypt/renew.log 2>&1"
  if ! grep -qF "certbot renew" /etc/crontab 2>/dev/null; then
    echo "$CERTBOT_CRON" | sudo tee -a /etc/crontab > /dev/null
    echo "[cron] certbot renewal added to /etc/crontab"
  else
    echo "[cron] certbot renew already in /etc/crontab"
  fi
fi

# Verify current cert expiry
if command -v certbot &>/dev/null; then
  echo ""
  echo "[cron] Current certificate status:"
  sudo certbot certificates 2>/dev/null | grep -E "Domains|Expiry|VALID" || echo "(no certs found)"
fi

# ── 2. Daily PostgreSQL backup ─────────────────────────────────────────────
sudo mkdir -p "$LOG_DIR"
sudo chown ubuntu:ubuntu "$LOG_DIR"

if [ ! -f "$BACKUP_SCRIPT" ]; then
  echo "[cron] ERROR: backup script not found at $BACKUP_SCRIPT"
  exit 1
fi

chmod +x "$BACKUP_SCRIPT"

BACKUP_CRON="0 2 * * * ubuntu ${BACKUP_SCRIPT} >> ${LOG_DIR}/backup.log 2>&1"

# Check ubuntu's crontab
if crontab -l 2>/dev/null | grep -qF "backup-db.sh"; then
  echo "[cron] Backup cron already exists in ubuntu crontab"
else
  # Add to ubuntu's crontab
  (crontab -l 2>/dev/null || true; echo "0 2 * * * ${BACKUP_SCRIPT} >> ${LOG_DIR}/backup.log 2>&1") | crontab -
  echo "[cron] Daily backup cron added (runs at 02:00 UTC)"
fi

echo ""
echo "=== Cron setup complete ==="
echo "Verify with: crontab -l"
echo "Backup logs: tail -f ${LOG_DIR}/backup.log"
echo "Certbot logs: tail -f /var/log/letsencrypt/renew.log"
