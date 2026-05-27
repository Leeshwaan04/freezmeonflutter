-- Migration: perf_indexes
-- Adds indexes for common query patterns identified in optimization audit.

-- Chat.matchId — for fetching chats by matchId (matching.ts mutual match creation)
CREATE INDEX IF NOT EXISTS "Chat_matchId_idx" ON "Chat"("matchId");

-- BlindsQueue.availableUntil — for cron cleanup query (WHERE availableUntil < now())
CREATE INDEX IF NOT EXISTS "BlindsQueue_availableUntil_idx" ON "BlindsQueue"("availableUntil");
