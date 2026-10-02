import express from 'express';

import { requireAuth } from '../lib/requireAuth.js';
import { uniqueCode, CODE } from '../lib/codes.js';
import { isObjectionable } from '../lib/moderation.js';
import { cleanName, cleanNickname } from './leagues.js';

const SLUG = /^[a-z0-9][a-z0-9-]{0,80}$/;
const MAX_PEOPLE = 8;
const DAY_MS = 86_400_000;

function cleanItems(items) {
  if (!Array.isArray(items) || items.length === 0 || items.length > 20) return null;
  const out = [];
  for (const item of items) {
    if (!item || typeof item.itemSlug !== 'string' || !SLUG.test(item.itemSlug)) return null;
    const sets = Number.isInteger(item.sets) && item.sets >= 1 && item.sets <= 10 ? item.sets : null;
    if (!sets) return null;
    const reps = Number.isInteger(item.reps) && item.reps >= 1 && item.reps <= 100 ? item.reps : null;
    const seconds = Number.isInteger(item.seconds) && item.seconds >= 1 && item.seconds <= 3600 ? item.seconds : null;
    out.push({ itemSlug: item.itemSlug, sets, reps, seconds });
  }
  return out;
}

/**
 * Partner and team workouts: one athlete starts a workout "together" and
 * shares the code; others join on their own phones and everyone sees how
 * far the others are (exercises done of total, finished). Nicknames only;
 * the session and its progress disappear after a day.
 *
 *   POST /partner                 { title, items, nickname } → { code }
 *   POST /partner/:code/join      { nickname } → the session
 *   PUT  /partner/:code/progress  { done, total, finished }
 *   GET  /partner/:code           the session and everyone's progress
 */
export function partnerRouter({ prisma, sessionSecret, now = () => new Date() }) {
  const router = express.Router();
  router.use(requireAuth({ sessionSecret }));

  async function live(code) {
    if (!CODE.test(code)) return null;
    const session = await prisma.partnerSession.findUnique({ where: { code }, include: { people: true } });
    return session && session.expiresAt > now() ? session : null;
  }

  const json = (session, me) => ({
    code: session.code,
    title: session.title,
    items: session.items,
    people: (session.people ?? []).map((p) => ({ nickname: p.nickname, done: p.done, total: p.total, finished: p.finished, isMe: p.athleteId === me })),
  });

  router.post('/', async (req, res) => {
    const title = cleanName(req.body?.title);
    const nickname = cleanNickname(req.body?.nickname);
    const items = cleanItems(req.body?.items);
    if (!title || !nickname || !items) {
      res.status(400).json({ error: !title ? 'invalid_title' : !nickname ? 'invalid_nickname' : 'invalid_items' });
      return;
    }
    const code = await uniqueCode(prisma);
    await prisma.partnerSession.create({ data: { code, title, items, createdBy: req.athleteId, expiresAt: new Date(now().getTime() + DAY_MS) } });
    await prisma.partnerProgress.create({ data: { code, athleteId: req.athleteId, nickname, done: 0, total: items.length, finished: false } });
    res.status(201).json({ code });
  });

  router.post('/:code/join', async (req, res) => {
    const code = String(req.params.code).toUpperCase();
    const nickname = cleanNickname(req.body?.nickname);
    const session = await live(code);
    if (!session) {
      res.status(404).json({ error: 'no_such_workout' });
      return;
    }
    if (!nickname) {
      res.status(400).json({ error: 'invalid_nickname' });
      return;
    }
    const mine = session.people.find((p) => p.athleteId === req.athleteId);
    if (!mine) {
      if (session.people.length >= MAX_PEOPLE) {
        res.status(409).json({ error: 'full' });
        return;
      }
      await prisma.partnerProgress.create({ data: { code, athleteId: req.athleteId, nickname, done: 0, total: session.items.length, finished: false } });
    }
    res.json(json(await live(code), req.athleteId));
  });

  router.put('/:code/progress', async (req, res) => {
    const code = String(req.params.code).toUpperCase();
    const session = await live(code);
    const where = { code_athleteId: { code, athleteId: req.athleteId } };
    if (!session || !session.people.some((p) => p.athleteId === req.athleteId)) {
      res.status(404).json({ error: 'not_joined' });
      return;
    }
    const done = Number.isInteger(req.body?.done) ? Math.max(0, Math.min(100, req.body.done)) : 0;
    const total = Number.isInteger(req.body?.total) ? Math.max(0, Math.min(100, req.body.total)) : 0;
    await prisma.partnerProgress.update({ where, data: { done, total, finished: req.body?.finished === true, updatedAt: now() } });
    res.status(204).end();
  });

  router.get('/:code', async (req, res) => {
    const session = await live(String(req.params.code).toUpperCase());
    if (!session || !session.people.some((p) => p.athleteId === req.athleteId)) {
      res.status(404).json({ error: 'not_joined' });
      return;
    }
    res.json(json(session, req.athleteId));
  });

  return router;
}

export { isObjectionable };
