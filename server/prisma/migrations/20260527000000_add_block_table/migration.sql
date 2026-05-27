-- CreateTable
CREATE TABLE "Block" (
    "id" TEXT NOT NULL,
    "blockerUid" TEXT NOT NULL,
    "blockedUid" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Block_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Block_blockerUid_blockedUid_key" ON "Block"("blockerUid", "blockedUid");

-- CreateIndex
CREATE INDEX "Block_blockerUid_idx" ON "Block"("blockerUid");

-- CreateIndex
CREATE INDEX "Block_blockedUid_idx" ON "Block"("blockedUid");
