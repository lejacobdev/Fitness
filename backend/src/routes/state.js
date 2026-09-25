import express from 'express';

import { requireAuth } from '../lib/requireAuth.js';

/** A state key: short, lower-camel or dotted (e.g. "sports", "campus", "mindset.goals"). */
const KEY = /^[a-z][a-zA-Z0-9.-]{0,63}$/;
const MAX_KEYS_PER_WRITE = 50;
const MAX_VALUE_BYTES = 512 * 1024;

/**
 * Everything the athlete builds up in the app, backed up and shared across
 * their devices, so a new phone (or a reinstall) restores it all.
 *
 *   GET  /sync/state     every stored document, { states: { key: { value, updatedAt } } }
 *   PUT  /sync/state     { states: { key: { value, updatedAt } } } — each one is stored only
 *                        if it is newer than what the server has (last write wins); the
 *                        reply is the server's current copy of every key sent, so a device
 *                        that lost the race gets the winning version straight back.
 *   GET  /sync/checkins  the athlete's check-ins (restore; ?since=YYYY-MM-DD for just the recent ones)
 *   GET  /sync/sessions  the athlete's logged sessions with their sets (same ?since=)
 */
export function stateRouter({ prisma, sessionSecret }) {
  const router = express.Router();
  router.use(requireAuth({ sessionSecret }));

  router.get('/state', async (req, res) => {
    const rows = await prisma.syncedState.findMany({ where: { athleteId: req.athleteId } });
    res.json({ states: Object.fromEntries(rows.map((r) => [r.key, { value: r.value, updatedAt: r.updatedAt.toISOString() }])) });
  });

  router.put('/state', async (req, res) => {
    const states = req.body?.states;
    if (!states || typeof states !== 'object' || Array.isArray(states)) {
      res.status(400).json({ error: 'missing_states' });
      return;
    }
    const entries = Object.entries(states);
    if (entries.length > MAX_KEYS_PER_WRITE) {
      res.status(400).json({ error: 'too_many_keys' });
      return;
    }
    for (const [key, doc] of entries) {
      const error = validateDoc(key, doc);
      if (error) {
        res.status(400).json({ error, key });
        return;
      }
    }

    const result = {};
    for (const [key, doc] of entries) {
      const updatedAt = new Date(doc.updatedAt);
      const where = { athleteId_key: { athleteId: req.athleteId, key } };
      const existing = await prisma.syncedState.findUnique({ where });
      if (!existing || existing.updatedAt < updatedAt) {
        const saved = await prisma.syncedState.upsert({
          where,
          create: { athleteId: req.athleteId, key, value: doc.value, updatedAt },
          update: { value: doc.value, updatedAt },
        });
        result[key] = { value: saved.value, updatedAt: saved.updatedAt.toISOString() };
      } else {
        result[key] = { value: existing.value, updatedAt: existing.updatedAt.toISOString() };
      }
    }
    res.json({ states: result });
  });

  router.get('/checkins', async (req, res) => {
    const since = sinceDate(req.query.since);
    const where = since ? { athleteId: req.athleteId, date: { gte: since } } : { athleteId: req.athleteId };
    const rows = await prisma.checkIn.findMany({ where, orderBy: { date: 'asc' } });
    res.json({
      checkIns: rows.map((c) => ({
        clientId: c.clientId,
        date: c.date.toISOString().slice(0, 10),
        sleepQuality: c.sleepQuality,
        sleepHours: c.sleepHours,
        soreness: c.soreness,
        sorenessAreas: c.sorenessAreas,
        energy: c.energy,
        stress: c.stress,
        readinessBand: c.readinessBand,
        readinessZ: c.readinessZ,
      })),
    });
  });

  router.get('/sessions', async (req, res) => {
    const since = sinceDate(req.query.since);
    const rows = await prisma.session.findMany({
      where: since ? { athleteId: req.athleteId, startedAt: { gte: since } } : { athleteId: req.athleteId },
      include: { sets: true },
      orderBy: { startedAt: 'asc' },
    });
    res.json({
      sessions: rows.map((s) => ({
        clientId: s.clientId,
        startedAt: s.startedAt.toISOString(),
        endedAt: s.endedAt ? s.endedAt.toISOString() : null,
        sessionRPE: s.sessionRPE,
        minutes: s.minutes,
        source: s.source,
        healthKitWorkoutId: s.healthKitWorkoutId,
        notes: s.notes,
        sets: s.sets.map((x) => ({
          clientId: x.clientId,
          itemSlug: x.itemSlug,
          setIndex: x.setIndex,
          reps: x.reps,
          weightKg: x.weightKg,
          seconds: x.seconds,
          distanceM: x.distanceM,
          contacts: x.contacts,
          side: x.side,
        })),
      })),
    });
  });

  return router;
}

/** `?since=YYYY-MM-DD` → that day at 00:00 UTC; anything else → no filter. */
function sinceDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isNaN(date.getTime()) ? null : date;
}

function validateDoc(key, doc) {
  if (!KEY.test(key)) return 'invalid_key';
  if (!doc || typeof doc !== 'object') return 'invalid_document';
  if (typeof doc.updatedAt !== 'string' || Number.isNaN(Date.parse(doc.updatedAt))) return 'invalid_updated_at';
  if (!('value' in doc)) return 'missing_value';
  if (Buffer.byteLength(JSON.stringify(doc.value) ?? 'null', 'utf8') > MAX_VALUE_BYTES) return 'value_too_large';
  return null;
}
