import express from 'express';

import { CODE, uniqueCode } from '../lib/codes.js';
import { requireAuth } from '../lib/requireAuth.js';

export { makeCode } from '../lib/codes.js';
const WEEK = /^\d{4}-\d{2}-\d{2}$/;
const MAX_LEAGUES_PER_ATHLETE = 5;
const MAX_MEMBERS = 50;
const MAX_WEEKLY_XP = 5000;

/** A nickname: 2–20 letters, digits, spaces, dots, dashes or underscores. */
export function cleanNickname(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim().replace(/\s+/g, ' ');
  return /^[\p{L}\p{N} ._-]{2,20}$/u.test(trimmed) ? trimmed : null;
}

export function cleanName(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim().replace(/\s+/g, ' ');
  return trimmed.length >= 2 && trimmed.length <= 40 ? trimmed : null;
}

/**
 * Campus leagues with teammates. Private groups joined by a 6-character
 * code; each week members are ranked by the Campus XP they earned.
 *
 *   GET    /leagues?week=YYYY-MM-DD   my leagues with this week's table
 *   POST   /leagues                   { name, nickname } → create and join
 *   POST   /leagues/join              { code, nickname }
 *   DELETE /leagues/:id               leave (the last one out deletes it)
 *   PUT    /leagues/xp                { week, xp } — my XP for a week (only ever goes up)
 */
export function leaguesRouter({ prisma, sessionSecret }) {
  const router = express.Router();
  router.use(requireAuth({ sessionSecret }));

  router.get('/', async (req, res) => {
    const week = typeof req.query.week === 'string' && WEEK.test(req.query.week) ? req.query.week : null;
    if (!week) {
      res.status(400).json({ error: 'invalid_week' });
      return;
    }
    const memberships = await prisma.leagueMember.findMany({
      where: { athleteId: req.athleteId },
      include: { league: { include: { members: true } } },
    });
    const athleteIds = [...new Set(memberships.flatMap((m) => m.league.members.map((x) => x.athleteId)))];
    const xpRows = athleteIds.length
      ? await prisma.weeklyXP.findMany({ where: { week, athleteId: { in: athleteIds } } })
      : [];
    const xpBy = new Map(xpRows.map((r) => [r.athleteId, r.xp]));
    res.json({
      week,
      leagues: memberships.map(({ league }) => ({
        id: league.id,
        name: league.name,
        code: league.code,
        members: league.members
          .map((m) => ({ nickname: m.nickname, xp: xpBy.get(m.athleteId) ?? 0, isMe: m.athleteId === req.athleteId }))
          .sort((a, b) => b.xp - a.xp || a.nickname.localeCompare(b.nickname)),
      })),
    });
  });

  router.post('/', async (req, res) => {
    const name = cleanName(req.body?.name);
    const nickname = cleanNickname(req.body?.nickname);
    if (!name || !nickname) {
      res.status(400).json({ error: !name ? 'invalid_name' : 'invalid_nickname' });
      return;
    }
    const count = await prisma.leagueMember.count({ where: { athleteId: req.athleteId } });
    if (count >= MAX_LEAGUES_PER_ATHLETE) {
      res.status(409).json({ error: 'too_many_leagues' });
      return;
    }
    const league = await prisma.league.create({
      data: { name, code: await uniqueCode(prisma), members: { create: { athleteId: req.athleteId, nickname } } },
    });
    res.status(201).json({ league: { id: league.id, name: league.name, code: league.code } });
  });

  router.post('/join', async (req, res) => {
    const code = typeof req.body?.code === 'string' ? req.body.code.trim().toUpperCase() : '';
    const nickname = cleanNickname(req.body?.nickname);
    if (!CODE.test(code) || !nickname) {
      res.status(400).json({ error: !CODE.test(code) ? 'invalid_code' : 'invalid_nickname' });
      return;
    }
    const league = await prisma.league.findUnique({ where: { code }, include: { members: true } });
    if (!league) {
      res.status(404).json({ error: 'no_such_league' });
      return;
    }
    if (league.members.some((m) => m.athleteId === req.athleteId)) {
      res.json({ league: { id: league.id, name: league.name, code: league.code } });
      return;
    }
    if (league.members.length >= MAX_MEMBERS) {
      res.status(409).json({ error: 'league_full' });
      return;
    }
    const count = await prisma.leagueMember.count({ where: { athleteId: req.athleteId } });
    if (count >= MAX_LEAGUES_PER_ATHLETE) {
      res.status(409).json({ error: 'too_many_leagues' });
      return;
    }
    await prisma.leagueMember.create({ data: { leagueId: league.id, athleteId: req.athleteId, nickname } });
    res.status(201).json({ league: { id: league.id, name: league.name, code: league.code } });
  });

  router.delete('/:id', async (req, res) => {
    const where = { leagueId_athleteId: { leagueId: req.params.id, athleteId: req.athleteId } };
    const membership = await prisma.leagueMember.findUnique({ where });
    if (!membership) {
      res.status(404).json({ error: 'not_a_member' });
      return;
    }
    await prisma.leagueMember.delete({ where });
    const left = await prisma.leagueMember.count({ where: { leagueId: req.params.id } });
    if (left === 0) await prisma.league.delete({ where: { id: req.params.id } });
    res.status(204).end();
  });

  router.put('/xp', async (req, res) => {
    const week = req.body?.week;
    const xp = req.body?.xp;
    if (typeof week !== 'string' || !WEEK.test(week) || !Number.isInteger(xp) || xp < 0) {
      res.status(400).json({ error: 'invalid_xp' });
      return;
    }
    const capped = Math.min(xp, MAX_WEEKLY_XP);
    const where = { athleteId_week: { athleteId: req.athleteId, week } };
    const existing = await prisma.weeklyXP.findUnique({ where });
    if (!existing || existing.xp < capped) {
      await prisma.weeklyXP.upsert({
        where,
        create: { athleteId: req.athleteId, week, xp: capped },
        update: { xp: capped },
      });
    }
    res.json({ week, xp: Math.max(existing?.xp ?? 0, capped) });
  });

  return router;
}
