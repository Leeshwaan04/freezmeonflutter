-- CreateTable
CREATE TABLE "PoolSession" (
    "id" TEXT NOT NULL,
    "opensAt" TIMESTAMP(3) NOT NULL,
    "closesAt" TIMESTAMP(3) NOT NULL,
    "isOpen" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PoolSession_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "PoolSession_opensAt_idx" ON "PoolSession"("opensAt");

-- CreateIndex
CREATE INDEX "PoolSession_closesAt_idx" ON "PoolSession"("closesAt");
