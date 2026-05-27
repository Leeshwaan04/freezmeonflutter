import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

// Build DATABASE_URL with pool tuning parameters if not already set by env.
// connection_limit: 10 per PM2 worker (max=CPU cores) keeps total connections bounded.
// connect_timeout: fail fast on DB unavailability (seconds).
function buildDatabaseUrl(): string {
  const url = new URL(process.env.DATABASE_URL!);
  if (!url.searchParams.has('connection_limit')) url.searchParams.set('connection_limit', '10');
  if (!url.searchParams.has('connect_timeout')) url.searchParams.set('connect_timeout', '10');
  if (!url.searchParams.has('pool_timeout')) url.searchParams.set('pool_timeout', '15');
  return url.toString();
}

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
    datasources: { db: { url: buildDatabaseUrl() } },
  });

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
