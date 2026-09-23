/**
 * §18: "A demo account with proUntil set far in the future server-side" for
 * App Review. Operator-only; run inside the API container:
 *
 *   docker compose exec api node src/scripts/grantPro.js <athleteId> [YYYY-MM-DD]
 *
 * Also the one sanctioned way to grant Pro outside App Store notifications —
 * it is a shell command on the server, never an HTTP route.
 */
import { disconnectPrisma, prisma } from '../lib/prisma.js';

const [athleteId, until = '2099-12-31'] = process.argv.slice(2);
if (!athleteId) {
  console.error('usage: node src/scripts/grantPro.js <athleteId> [YYYY-MM-DD]');
  process.exit(2);
}
const proUntil = new Date(`${until}T00:00:00.000Z`);
if (Number.isNaN(proUntil.getTime())) {
  console.error(`not a date: ${until}`);
  process.exit(2);
}
try {
  const athlete = await prisma.athlete.update({ where: { id: athleteId }, data: { proUntil } });
  console.log(`athlete ${athlete.id} has Pro until ${athlete.proUntil.toISOString()}`);
} catch (err) {
  console.error(err.code === 'P2025' ? `no athlete ${athleteId}` : err.message);
  process.exitCode = 1;
} finally {
  await disconnectPrisma();
}
