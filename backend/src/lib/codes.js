import crypto from 'node:crypto';

/**
 * Codes for teams, leagues and shared workouts: 6 characters without
 * look-alikes (no 0/O, 1/I/L). All three share one code space, so a bare
 * code (aos://ABC234, GET /codes/:code) always means exactly one thing.
 */
export const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
export const CODE = /^[A-HJ-KM-NP-Z2-9]{6}$/;

export function makeCode() {
  const bytes = crypto.randomBytes(6);
  return Array.from(bytes, (b) => CODE_ALPHABET[b % CODE_ALPHABET.length]).join('');
}

/** A new code that no team, league or shared workout uses yet. */
export async function uniqueCode(prisma) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const code = makeCode();
    const [workout, team, league] = await Promise.all([
      prisma.sharedWorkout.findUnique({ where: { code } }),
      prisma.team.findUnique({ where: { code } }),
      prisma.league.findUnique({ where: { code } }),
    ]);
    if (!workout && !team && !league) return code;
  }
  throw new Error('could not find a free code');
}
