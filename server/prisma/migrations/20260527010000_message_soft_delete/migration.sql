-- Add soft-delete support to Message
ALTER TABLE "Message" ADD COLUMN "deletedAt" TIMESTAMP(3);
