import express from 'express';

import { requireAuth } from '../lib/requireAuth.js';

const SOURCES = new Set(['PHONE', 'WATCH']);

/**
 * §3's sync responsibility: logged sessions with their sets, and daily
 * check-ins.
 * §14: "clientId on every writable row is the idempotency key that makes the
 * offline queue safe to retry — without it a flaky reconnect duplicates a
 * whole session." Every write here is an upsert keyed on clientId, so
 * draining the same queued session twice produces one row, not two (§21's
 * sync idempotency test), and re-syncing a session that finished offline
 * after an earlier partial sync (e.g. RPE/endedAt added later) naturally
 * updates the same row — "last-write-wins," per §3.
 */
export function syncRouter({ prisma, sessionSecret }) {
  const router = express.Router();
  router.use(requireAuth({ sessionSecret }));

  router.post('/sessions', async (req, res) => {
    const { session, sets } = req.body ?? {};
    const sessionError = validateSession(session);
    if (sessionError) {
      res.status(400).json({ error: sessionError });
      return;
    }
    const setList = Array.isArray(sets) ? sets : [];
    for (const set of setList) {
      const setError = validateSet(set);
      if (setError) {
        res.status(400).json({ error: setError });
        return;
      }
    }

    // clientId is a client-generated UUID, not scoped per-athlete in the
    // schema — astronomically unlikely to collide, but a malicious or buggy
    // client replaying someone else's clientId must never be allowed to
    // overwrite their session, so ownership is checked before every upsert
    // rather than trusting the unique constraint alone.
    const existingSession = await prisma.session.findUnique({ where: { clientId: session.clientId } });
    if (existingSession && existingSession.athleteId !== req.athleteId) {
      res.status(409).json({ error: 'client_id_conflict' });
      return;
    }
    if (session.plannedSessionId) {
      const plannedSession = await prisma.plannedSession.findUnique({
        where: { id: session.plannedSessionId },
        include: { plan: true },
      });
      if (!plannedSession || plannedSession.plan.athleteId !== req.athleteId) {
        res.status(400).json({ error: 'unknown_planned_session' });
        return;
      }
    }

    const sessionFields = {
      startedAt: new Date(session.startedAt),
      endedAt: session.endedAt ? new Date(session.endedAt) : null,
      sessionRPE: session.sessionRPE ?? null,
      minutes: session.minutes ?? 0,
      source: session.source,
      healthKitWorkoutId: session.healthKitWorkoutId ?? null,
      notes: session.notes ?? null,
      plannedSessionId: session.plannedSessionId ?? null,
    };
    const savedSession = await prisma.session.upsert({
      where: { clientId: session.clientId },
      create: { ...sessionFields, clientId: session.clientId, athleteId: req.athleteId },
      update: sessionFields,
    });

    const savedSets = [];
    for (const set of setList) {
      const existingSet = await prisma.setLog.findUnique({ where: { clientId: set.clientId } });
      if (existingSet && existingSet.sessionId !== savedSession.id) {
        res.status(409).json({ error: 'client_id_conflict' });
        return;
      }
      const setFields = {
        itemSlug: set.itemSlug,
        setIndex: set.setIndex,
        reps: set.reps ?? null,
        weightKg: set.weightKg ?? null,
        seconds: set.seconds ?? null,
        distanceM: set.distanceM ?? null,
        contacts: set.contacts ?? null,
        side: set.side ?? null,
      };
      const savedSet = await prisma.setLog.upsert({
        where: { clientId: set.clientId },
        create: { ...setFields, clientId: set.clientId, sessionId: savedSession.id },
        update: setFields,
      });
      savedSets.push(savedSet);
    }

    res.json({
      session: { id: savedSession.id, clientId: savedSession.clientId },
      sets: savedSets.map((s) => ({ id: s.id, clientId: s.clientId })),
    });
  });

  router.post('/checkins', async (req, res) => {
    const checkIn = req.body?.checkIn;
    const error = validateCheckIn(checkIn);
    if (error) {
      res.status(400).json({ error });
      return;
    }

    const existingByClientId = await prisma.checkIn.findUnique({ where: { clientId: checkIn.clientId } });
    if (existingByClientId && existingByClientId.athleteId !== req.athleteId) {
      res.status(409).json({ error: 'client_id_conflict' });
      return;
    }

    // §14: unique per athlete per DAY — a second check-in the same day
    // (edited, or made on a second device) updates that day's row rather
    // than creating a duplicate that would corrupt every rolling baseline.
    const date = new Date(`${checkIn.date}T00:00:00.000Z`);
    const fields = {
      sleepQuality: checkIn.sleepQuality,
      sleepHours: checkIn.sleepHours ?? null,
      soreness: checkIn.soreness,
      sorenessAreas: Array.isArray(checkIn.sorenessAreas) ? checkIn.sorenessAreas.filter((a) => typeof a === 'string') : [],
      energy: checkIn.energy,
      stress: checkIn.stress,
      readinessBand: checkIn.readinessBand ?? null,
      readinessZ: typeof checkIn.readinessZ === 'number' ? checkIn.readinessZ : null,
    };
    const saved = await prisma.checkIn.upsert({
      where: { athleteId_date: { athleteId: req.athleteId, date } },
      create: { ...fields, date, clientId: checkIn.clientId, athleteId: req.athleteId },
      update: fields,
    });
    res.json({ checkIn: { id: saved.id, clientId: saved.clientId } });
  });

  return router;
}

const READINESS_BANDS = new Set(['GREEN', 'AMBER', 'RED']);

function isScale(value) {
  return Number.isInteger(value) && value >= 1 && value <= 5;
}

function validateCheckIn(checkIn) {
  if (!checkIn || typeof checkIn !== 'object') return 'missing_check_in';
  if (typeof checkIn.clientId !== 'string' || checkIn.clientId.length === 0) return 'missing_client_id';
  if (typeof checkIn.date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(checkIn.date)
    || Number.isNaN(Date.parse(`${checkIn.date}T00:00:00.000Z`))) return 'invalid_date';
  for (const field of ['sleepQuality', 'soreness', 'energy', 'stress']) {
    if (!isScale(checkIn[field])) return `invalid_${field}`;
  }
  if (checkIn.sleepHours !== undefined && checkIn.sleepHours !== null) {
    if (typeof checkIn.sleepHours !== 'number' || checkIn.sleepHours < 0 || checkIn.sleepHours > 24) return 'invalid_sleep_hours';
  }
  if (checkIn.readinessBand !== undefined && checkIn.readinessBand !== null && !READINESS_BANDS.has(checkIn.readinessBand)) {
    return 'invalid_readiness_band';
  }
  return null;
}

function validateSession(session) {
  if (!session || typeof session !== 'object') return 'missing_session';
  if (typeof session.clientId !== 'string' || session.clientId.length === 0) return 'missing_client_id';
  if (typeof session.startedAt !== 'string' || Number.isNaN(Date.parse(session.startedAt))) return 'invalid_started_at';
  if (session.endedAt !== undefined && session.endedAt !== null) {
    if (typeof session.endedAt !== 'string' || Number.isNaN(Date.parse(session.endedAt))) return 'invalid_ended_at';
  }
  if (session.sessionRPE !== undefined && session.sessionRPE !== null) {
    if (!Number.isInteger(session.sessionRPE) || session.sessionRPE < 1 || session.sessionRPE > 10) {
      return 'invalid_session_rpe';
    }
  }
  if (session.minutes !== undefined && (!Number.isInteger(session.minutes) || session.minutes < 0)) {
    return 'invalid_minutes';
  }
  if (!SOURCES.has(session.source)) return 'invalid_source';
  return null;
}

function validateSet(set) {
  if (!set || typeof set !== 'object') return 'missing_set';
  if (typeof set.clientId !== 'string' || set.clientId.length === 0) return 'missing_set_client_id';
  if (typeof set.itemSlug !== 'string' || set.itemSlug.length === 0) return 'missing_item_slug';
  if (!Number.isInteger(set.setIndex) || set.setIndex < 0) return 'invalid_set_index';
  return null;
}
