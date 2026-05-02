-- Production Hardening Migration
-- Adds: token blacklist, password reset tokens, email verification tokens,
--       emailVerified on User, originalTransactionId on Membership

-- Add emailVerified to User
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "emailVerified" BOOLEAN NOT NULL DEFAULT false;

-- Add originalTransactionId to Membership (unique to prevent receipt replay)
ALTER TABLE "Membership" ADD COLUMN IF NOT EXISTS "originalTransactionId" TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS "Membership_originalTransactionId_key" ON "Membership"("originalTransactionId") WHERE "originalTransactionId" IS NOT NULL;

-- Token blacklist for revoked access tokens
CREATE TABLE IF NOT EXISTS "TokenBlacklist" (
    "id"        TEXT NOT NULL,
    "jti"       TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "TokenBlacklist_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "TokenBlacklist_jti_key" ON "TokenBlacklist"("jti");
CREATE INDEX IF NOT EXISTS "TokenBlacklist_expiresAt_idx" ON "TokenBlacklist"("expiresAt");

-- Password reset tokens
CREATE TABLE IF NOT EXISTS "PasswordResetToken" (
    "id"        TEXT NOT NULL,
    "userId"    TEXT NOT NULL,
    "token"     TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "used"      BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "PasswordResetToken_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "PasswordResetToken_token_key" ON "PasswordResetToken"("token");
CREATE INDEX IF NOT EXISTS "PasswordResetToken_userId_idx" ON "PasswordResetToken"("userId");

-- Email verification tokens
CREATE TABLE IF NOT EXISTS "EmailVerificationToken" (
    "id"        TEXT NOT NULL,
    "userId"    TEXT NOT NULL,
    "token"     TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "EmailVerificationToken_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "EmailVerificationToken_token_key" ON "EmailVerificationToken"("token");
CREATE INDEX IF NOT EXISTS "EmailVerificationToken_userId_idx" ON "EmailVerificationToken"("userId");
