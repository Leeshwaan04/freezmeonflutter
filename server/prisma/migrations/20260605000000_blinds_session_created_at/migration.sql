-- Add createdAt to BlindsSession for daily rate limiting
ALTER TABLE "BlindsSession" ADD COLUMN IF NOT EXISTS "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- Index for daily count queries
CREATE INDEX IF NOT EXISTS "BlindsSession_createdAt_idx" ON "BlindsSession"("createdAt");
