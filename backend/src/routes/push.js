import express from 'express';

import { requireAuth } from '../lib/requireAuth.js';
import { PUSH_KINDS } from '../lib/notifier.js';

const TOKEN = /^[0-9a-fA-F]{32,200}$/;
const MAX_DEVICES = 5;

/**
 *   PUT    /push/device   { token, muted?: [kind] } — this phone can get pushes
 *                          (called again whenever the setting changes)
 *   DELETE /push/device   { token } — stop (sign-out)
 */
export function pushRouter({ prisma, sessionSecret }) {
  const router = express.Router();
  router.use(requireAuth({ sessionSecret }));

  router.put('/device', async (req, res) => {
    const token = typeof req.body?.token === 'string' ? req.body.token.toLowerCase() : '';
    if (!TOKEN.test(token)) {
      res.status(400).json({ error: 'invalid_token' });
      return;
    }
    const muted = Array.isArray(req.body?.muted) ? [...new Set(req.body.muted.filter((k) => PUSH_KINDS.includes(k)))] : [];
    // A token belongs to whoever is signed in on that phone now.
    await prisma.pushDevice.upsert({
      where: { token },
      create: { token, athleteId: req.athleteId, muted },
      update: { athleteId: req.athleteId, muted },
    });
    const mine = await prisma.pushDevice.findMany({ where: { athleteId: req.athleteId }, orderBy: { updatedAt: 'desc' } });
    for (const old of mine.slice(MAX_DEVICES)) await prisma.pushDevice.deleteMany({ where: { token: old.token } });
    res.status(204).end();
  });

  router.delete('/device', async (req, res) => {
    const token = typeof req.body?.token === 'string' ? req.body.token.toLowerCase() : '';
    if (TOKEN.test(token)) await prisma.pushDevice.deleteMany({ where: { token, athleteId: req.athleteId } });
    res.status(204).end();
  });

  return router;
}
