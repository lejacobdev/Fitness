import express from 'express';

import { CODE, uniqueCode } from '../lib/codes.js';
import { isObjectionable } from '../lib/moderation.js';
import { requireAuth } from '../lib/requireAuth.js';

const SLUG = /^[a-z0-9][a-z0-9-]{0,80}$/;
const KINDS = new Set(['reps', 'time', 'distance', 'contacts']);
const MAX_ITEMS = 40;
const MAX_SHARED_PER_ATHLETE = 100;

const int = (value, min, max) => Number.isInteger(value) && value >= min && value <= max;

/** A workout's exercises, checked field by field; null if anything is off. */
export function cleanItems(value) {
  if (!Array.isArray(value) || value.length === 0 || value.length > MAX_ITEMS) return null;
  const items = [];
  for (const raw of value) {
    const dose = raw?.dose;
    if (!raw || typeof raw.itemSlug !== 'string' || !SLUG.test(raw.itemSlug)) return null;
    if (!int(raw.restSec, 0, 1200) || !dose || !KINDS.has(dose.kind) || !int(dose.sets, 1, 20)) return null;
    const clean = { kind: dose.kind, sets: dose.sets };
    for (const [field, min, max] of [['reps', 1, 500], ['seconds', 1, 7200], ['contacts', 1, 1000]]) {
      if (dose[field] === undefined || dose[field] === null) continue;
      if (!int(dose[field], min, max)) return null;
      clean[field] = dose[field];
    }
    if (dose.metres !== undefined && dose.metres !== null) {
      if (typeof dose.metres !== 'number' || !(dose.metres > 0 && dose.metres <= 100000)) return null;
      clean.metres = dose.metres;
    }
    for (const [field, max] of [['load', 40], ['tempo', 20]]) {
      if (dose[field] === undefined || dose[field] === null) continue;
      if (typeof dose[field] !== 'string' || dose[field].length > max) return null;
      clean[field] = dose[field];
    }
    if (dose.perSide === true) clean.perSide = true;
    items.push({ itemSlug: raw.itemSlug, dose: clean, restSec: raw.restSec });
  }
  return items;
}

/** A title: 1–60 characters, whitespace tidied. */
export function cleanTitle(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim().replace(/\s+/g, ' ');
  return trimmed.length >= 1 && trimmed.length <= 60 && !isObjectionable(trimmed) ? trimmed : null;
}

/**
 * Workouts shared under a code. Sharing is a Pro feature in the app;
 * opening one is free and needs no account (the code is the key).
 *
 *   POST   /workouts/shared          { title, items, sportSlug? } → { code, url }
 *   GET    /workouts/shared          my shared workouts
 *   GET    /workouts/shared/:code    the workout (public)
 *   DELETE /workouts/shared/:code    stop sharing it (owner only)
 */
export function workoutsRouter({ prisma, sessionSecret, publicBaseURL = process.env.PUBLIC_BASE_URL ?? 'https://api.lejacob.dev/fitness' }) {
  const router = express.Router();
  const auth = requireAuth({ sessionSecret });
  const urlFor = (code) => `${publicBaseURL.replace(/\/$/, '')}/workout/${code}`;

  router.post('/shared', auth, async (req, res) => {
    const title = cleanTitle(req.body?.title);
    const items = cleanItems(req.body?.items);
    const sportSlug = typeof req.body?.sportSlug === 'string' && SLUG.test(req.body.sportSlug) ? req.body.sportSlug : null;
    if (!title || !items) {
      res.status(400).json({ error: !title ? 'invalid_title' : 'invalid_items' });
      return;
    }
    if (await prisma.sharedWorkout.count({ where: { ownerId: req.athleteId } }) >= MAX_SHARED_PER_ATHLETE) {
      res.status(409).json({ error: 'too_many_shared' });
      return;
    }
    const code = await uniqueCode(prisma);
    await prisma.sharedWorkout.create({ data: { code, ownerId: req.athleteId, title, items, sportSlug } });
    res.status(201).json({ code, url: urlFor(code) });
  });

  router.get('/shared', auth, async (req, res) => {
    const mine = await prisma.sharedWorkout.findMany({ where: { ownerId: req.athleteId } });
    res.json({
      workouts: mine
        .sort((a, b) => b.createdAt - a.createdAt)
        .map((w) => ({ code: w.code, title: w.title, itemCount: w.items.length, url: urlFor(w.code) })),
    });
  });

  router.get('/shared/:code', async (req, res) => {
    const code = String(req.params.code).toUpperCase();
    const workout = CODE.test(code) ? await prisma.sharedWorkout.findUnique({ where: { code } }) : null;
    if (!workout) {
      res.status(404).json({ error: 'not_found' });
      return;
    }
    res.json({ code: workout.code, title: workout.title, items: workout.items, sportSlug: workout.sportSlug ?? null });
  });

  router.delete('/shared/:code', auth, async (req, res) => {
    const code = String(req.params.code).toUpperCase();
    const { count } = await prisma.sharedWorkout.deleteMany({ where: { code, ownerId: req.athleteId } });
    res.status(count ? 204 : 404).end();
  });

  return router;
}
