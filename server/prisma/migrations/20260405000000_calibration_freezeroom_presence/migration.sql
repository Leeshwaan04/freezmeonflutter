-- AlterTable: add calibration + presence fields to Profile
ALTER TABLE "Profile"
  ADD COLUMN IF NOT EXISTS "intent"            TEXT,
  ADD COLUMN IF NOT EXISTS "personalityTraits" TEXT[]   NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS "lifestyleFactors"  TEXT[]   NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS "archetype"         TEXT,
  ADD COLUMN IF NOT EXISTS "promptAnswer"      JSONB,
  ADD COLUMN IF NOT EXISTS "energyType"        TEXT,
  ADD COLUMN IF NOT EXISTS "paceSignal"        TEXT,
  ADD COLUMN IF NOT EXISTS "presenceWindows"   JSONB,
  ADD COLUMN IF NOT EXISTS "presenceScore"     INTEGER  NOT NULL DEFAULT 50,
  ADD COLUMN IF NOT EXISTS "presenceLabel"     TEXT     NOT NULL DEFAULT 'in_the_flow';

-- CreateIndex
CREATE INDEX IF NOT EXISTS "Profile_intent_idx"        ON "Profile"("intent");
CREATE INDEX IF NOT EXISTS "Profile_energyType_idx"     ON "Profile"("energyType");
CREATE INDEX IF NOT EXISTS "Profile_presenceScore_idx"  ON "Profile"("presenceScore");

-- CreateTable: FreezeRoom
CREATE TABLE IF NOT EXISTS "FreezeRoom" (
  "id"         TEXT         NOT NULL,
  "openedAt"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "closesAt"   TIMESTAMP(3) NOT NULL,
  "promptType" TEXT         NOT NULL,
  "prompt"     TEXT         NOT NULL,
  "status"     TEXT         NOT NULL DEFAULT 'open',
  CONSTRAINT "FreezeRoom_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "FreezeRoom_status_closesAt_idx" ON "FreezeRoom"("status", "closesAt");

-- CreateTable: FreezeRoomParticipant
CREATE TABLE IF NOT EXISTS "FreezeRoomParticipant" (
  "id"       TEXT         NOT NULL,
  "roomId"   TEXT         NOT NULL,
  "uid"      TEXT         NOT NULL,
  "answer"   TEXT,
  "reveals"  TEXT[]       NOT NULL DEFAULT ARRAY[]::TEXT[],
  "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "FreezeRoomParticipant_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "FreezeRoomParticipant_roomId_uid_key" ON "FreezeRoomParticipant"("roomId", "uid");
CREATE INDEX IF NOT EXISTS "FreezeRoomParticipant_uid_idx" ON "FreezeRoomParticipant"("uid");
ALTER TABLE "FreezeRoomParticipant"
  ADD CONSTRAINT "FreezeRoomParticipant_roomId_fkey"
  FOREIGN KEY ("roomId") REFERENCES "FreezeRoom"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateTable: FreezeMatch
CREATE TABLE IF NOT EXISTS "FreezeMatch" (
  "id"        TEXT         NOT NULL,
  "roomId"    TEXT         NOT NULL,
  "userA"     TEXT         NOT NULL,
  "userB"     TEXT         NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "FreezeMatch_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "FreezeMatch_userA_userB_key" ON "FreezeMatch"("userA", "userB");
CREATE INDEX IF NOT EXISTS "FreezeMatch_userA_idx" ON "FreezeMatch"("userA");
CREATE INDEX IF NOT EXISTS "FreezeMatch_userB_idx" ON "FreezeMatch"("userB");

-- CreateTable: PresenceEvent
CREATE TABLE IF NOT EXISTS "PresenceEvent" (
  "id"        TEXT         NOT NULL,
  "uid"       TEXT         NOT NULL,
  "eventType" TEXT         NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "PresenceEvent_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "PresenceEvent_uid_createdAt_idx" ON "PresenceEvent"("uid", "createdAt");
