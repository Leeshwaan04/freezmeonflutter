#!/bin/bash
# Freezme EC2 deployment script
# Run on the EC2 instance after cloning the repo

set -e

echo "=== Freezme EC2 Deploy ==="

# 1. Install Node.js 20 (if not already installed)
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

# 2. Install PM2 globally
if ! command -v pm2 &>/dev/null; then
  sudo npm install -g pm2
fi

# 3. Install PostgreSQL 15 (if not already installed)
if ! command -v psql &>/dev/null; then
  sudo apt-get update
  sudo apt-get install -y postgresql-15
  sudo systemctl enable postgresql
  sudo systemctl start postgresql
fi

# 4. Install dependencies and build
cd "$(dirname "$0")/.."
npm ci
npm run db:generate
npm run build

# 5. Run database migrations
npm run db:migrate

# 6. Start/reload with PM2
pm2 startOrReload ecosystem.config.js --env production
pm2 save
pm2 startup systemd -u ubuntu --hp /home/ubuntu

echo ""
echo "=== Deployment complete ==="
echo "API running via PM2. Check status with: pm2 status"
echo ""
echo "First-time setup remaining:"
echo "  1. Copy nginx.conf to /etc/nginx/sites-available/freezme-api"
echo "  2. sudo ln -s /etc/nginx/sites-available/freezme-api /etc/nginx/sites-enabled/"
echo "  3. sudo certbot --nginx -d api.freezme.app"
echo "  4. Copy .env to the server directory (DO NOT commit .env)"
echo "  5. Copy firebase-service-account.json to /etc/freezme/"
echo "  6. Copy apple_auth_key.p8 to /etc/freezme/"
