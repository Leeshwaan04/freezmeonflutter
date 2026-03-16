#!/bin/bash

# Freezme E2E Master Runner
set -e

echo "🧹 Cleaning up ports..."
lsof -ti:9099,5001,8085,9199,4000,4400 | xargs kill -9 || true

echo "🚀 Starting Firebase Emulators in background..."
cd backend
firebase emulators:start --project freezme-844cc &
EMULATOR_PID=$!

# Wait for emulators to be ready
echo "⏳ Waiting for emulators to initialize..."
until curl -s localhost:4400 > /dev/null; do
  sleep 2
done

# Seed Data
echo "🌱 Seeding test data..."
node scripts/seed_data.js

echo "🐹 Running Go Backend API Tests..."
cd ../freezme-backend
go test ./...

echo "📱 Running Flutter E2E Integration Tests on macOS..."
cd ../freezme
flutter test integration_test/e2e_test.dart -d macos

echo "✅ E2E Tests Completed!"

# Cleanup
echo "🛑 Shutting down emulators..."
kill $EMULATOR_PID || true
lsof -ti:9099,5001,8085,9199,4000,4400 | xargs kill -9 || true

exit 0
