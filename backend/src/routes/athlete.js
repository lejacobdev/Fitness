import express from 'express';

import { requireAuth } from '../lib/requireAuth.js';

/**
 * §20/§4: "Account deletion must never sit behind the paywall" and must be
 * real, not cosmetic. A single authenticated delete of the athlete's own
 * row — every child table (AthleteSport, Competition, CheckIn, Plan,
 * Session, SkillBlock, CoachReport) is `onDelete: Cascade` in schema.prisma,
 * so this one query is a genuine, complete account deletion server-side,
 * not a partial one that leaves rows behind.
 */
export function athleteRouter({ prisma, sessionSecret }) {
  const router = express.Router();
  router.use(requireAuth({ sessionSecret }));

  // §18: the app pulls its entitlement from here — the server is the
  // authority; the client never reports or writes its own proUntil.
  router.get('/me', async (req, res) => {
    const athlete = await prisma.athlete.findUnique({ where: { id: req.athleteId } });
    if (!athlete) {
      res.status(404).json({ error: 'not_found' });
      return;
    }
    res.json({
      athlete: {
        id: athlete.id,
        proUntil: athlete.proUntil ? athlete.proUntil.toISOString() : null,
        isPro: Boolean(athlete.proUntil && athlete.proUntil > new Date()),
      },
    });
  });

  router.delete('/me', async (req, res) => {
    await prisma.athlete.delete({ where: { id: req.athleteId } }).catch((err) => {
      // Already gone (e.g. a retried request after the first succeeded) is
      // not an error from the client's point of view -- the athlete is
      // deleted either way, which is the only thing this endpoint promises.
      if (err.code === 'P2025') return;
      throw err;
    });
    res.status(204).end();
  });

  return router;
}
