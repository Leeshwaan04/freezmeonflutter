// Temporary: extends Prisma client with models added after last `prisma generate`.
// Remove once `prisma generate` is run locally and .prisma/client is updated.
import '@prisma/client';

declare module '@prisma/client' {
  interface Block {
    id: string;
    blockerUid: string;
    blockedUid: string;
    createdAt: Date;
  }
}
