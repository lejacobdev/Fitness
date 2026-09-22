import { PrismaClient } from '@prisma/client';

/**
 * One client per process. Wellness data belonging to minors passes through here,
 * so queries are never logged — a log line is a copy of the data outside the
 * database, which §20 forbids. Errors and warnings carry no row contents.
 */
export const prisma = new PrismaClient({
  log: ['error', 'warn'],
});

export async function disconnectPrisma() {
  await prisma.$disconnect();
}
