#!/bin/bash

# Exit on error
set -e

echo "🚀 Initializing Firebase Emulator Suite..."

# Install functions dependencies
cd backend/functions
npm install
cd ../..

# Start emulators, seed data, and then shut down (demo run)
echo "📦 Starting emulators and seeding data..."
cd backend
firebase emulators:exec "node scripts/seed_data.js" --project freezme-844cc
