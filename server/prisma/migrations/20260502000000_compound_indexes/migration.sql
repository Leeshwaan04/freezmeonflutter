-- Migration: compound_indexes
-- Replaces single geohash index on PathsPresence with compound (geohash, visibleUntil)
-- so the nearby-paths query (WHERE geohash BETWEEN x AND y AND visibleUntil > now) uses one index scan.
-- Adds (chatId, senderUid) index on Message for efficient per-sender queries within a chat.

DROP INDEX IF EXISTS "PathsPresence_geohash_idx";
CREATE INDEX "PathsPresence_geohash_visibleUntil_idx" ON "PathsPresence"("geohash", "visibleUntil");

CREATE INDEX IF NOT EXISTS "Message_chatId_senderUid_idx" ON "Message"("chatId", "senderUid");
