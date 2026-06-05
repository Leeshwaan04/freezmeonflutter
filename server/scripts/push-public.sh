#!/usr/bin/env bash
# push-public.sh — rsync public/ folder to EC2 when the full deploy isn't needed.
# Usage: ./scripts/push-public.sh [ec2-host] [ssh-key]
#   ec2-host defaults to 16.170.31.58
#   ssh-key  defaults to ~/.ssh/freezme-cli-key.pem
set -euo pipefail

HOST="${1:-16.170.31.58}"
KEY="${2:-$HOME/.ssh/freezme-cli-key.pem}"
REMOTE_DIR="/home/ubuntu/freezme-server"

echo "[push-public] Syncing public/ → ${HOST}:${REMOTE_DIR}/public/"

rsync -avz --delete \
  -e "ssh -i ${KEY} -o StrictHostKeyChecking=no" \
  "$(dirname "$0")/../public/" \
  "ubuntu@${HOST}:${REMOTE_DIR}/public/"

# Also sync into dist/public so the running process picks it up without restart
rsync -avz --delete \
  -e "ssh -i ${KEY} -o StrictHostKeyChecking=no" \
  "$(dirname "$0")/../public/" \
  "ubuntu@${HOST}:${REMOTE_DIR}/dist/public/"

echo "[push-public] Done. Terms and Privacy pages are live."
