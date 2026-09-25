import express from 'express';

import { requireAuth } from '../lib/requireAuth.js';
import { cleanName, cleanNickname, makeCode } from './leagues.js';

const CODE = /^[A-HJ-KM-NP-Z2-9]{6}$/;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const SLUG = /^[a-z0-9][a-z0-9-]{0,80}$/;
const MAX_TEAMS_PER_COACH = 10;
const MAX_MEMBERS = 80;

function day(value) {
  return typeof value === 'string' && DAY.test(value) && !Number.isNaN(Date.parse(`${value}T00:00:00Z`))
    ? new Date(`${value}T00:00:00Z`)
    : null;
}

function cleanItems(items) {
  if (!Array.isArray(items) || items.length === 0 || items.length > 20) return null;
  const out = [];
  for (const item of items) {
    if (!item || typeof item !== 'object' || typeof item.itemSlug !== 'string' || !SLUG.test(item.itemSlug)) return null;
    const sets = Number.isInteger(item.sets) && item.sets >= 1 && item.sets <= 10 ? item.sets : null;
    const reps = item.reps == null ? null : (Number.isInteger(item.reps) && item.reps >= 1 && item.reps <= 100 ? item.reps : undefined);
    const seconds = item.seconds == null ? null : (Number.isInteger(item.seconds) && item.seconds >= 1 && item.seconds <= 3600 ? item.seconds : undefined);
    if (!sets || reps === undefined || seconds === undefined) return null;
    out.push({ itemSlug: item.itemSlug, sets, reps, seconds });
  }
  return out;
}

function assignmentJSON(a, teamName) {
  return {
    id: a.id,
    teamId: a.teamId,
    teamName,
    date: a.date.toISOString().slice(0, 10),
    title: a.title,
    note: a.note,
    items: a.items,
  };
}

/**
 * Coach and team. A coach (any signed-in account) creates a team and shares
 * its code; athletes join with a nickname. The coach sees, per athlete,
 * only what they agreed to share by joining: today's readiness band from
 * the check-in, whether they checked in, and how much they trained this
 * week — never notes, reflections or anything they wrote. The coach can
 * assign workouts for a day; team members see them in the app.
 *
 *   GET    /teams                         teams I coach and teams I'm on
 *   POST   /teams                         { name } → create (I'm the coach)
 *   POST   /teams/join                    { code, nickname }
 *   DELETE /teams/:id                     coach: delete the team; member: leave
 *   GET    /teams/:id/readiness?today=YYYY-MM-DD&weekStart=YYYY-MM-DD   coach only
 *   GET    /teams/:id/assignments?from=YYYY-MM-DD                       coach only
 *   POST   /teams/:id/assignments         { date, title, note?, items: [{ itemSlug, sets, reps?, seconds? }] }
 *   DELETE /teams/:id/assignments/:assignmentId
 *   GET    /teams/assignments?from=YYYY-MM-DD   workouts assigned to me, from every team I'm on
 */
export function teamsRouter({ prisma, sessionSecret }) {
  const router = express.Router();
  router.use(requireAuth({ sessionSecret }));

  async function coachedTeam(req, res) {
    const team = await prisma.team.findUnique({ where: { id: req.params.id } });
    if (!team || team.coachId !== req.athleteId) {
      res.status(404).json({ error: 'not_your_team' });
      return null;
    }
    return team;
  }

  router.get('/', async (req, res) => {
    const coaching = await prisma.team.findMany({
      where: { coachId: req.athleteId },
      include: { _count: { select: { members: true } } },
      orderBy: { createdAt: 'asc' },
    });
    const memberships = await prisma.teamMember.findMany({
      where: { athleteId: req.athleteId },
      include: { team: true },
      orderBy: { joinedAt: 'asc' },
    });
    res.json({
      coaching: coaching.map((t) => ({ id: t.id, name: t.name, code: t.code, memberCount: t._count.members })),
      member: memberships.map((m) => ({ id: m.team.id, name: m.team.name, nickname: m.nickname })),
    });
  });

  router.post('/', async (req, res) => {
    const name = cleanName(req.body?.name);
    if (!name) {
      res.status(400).json({ error: 'invalid_name' });
      return;
    }
    const count = await prisma.team.count({ where: { coachId: req.athleteId } });
    if (count >= MAX_TEAMS_PER_COACH) {
      res.status(409).json({ error: 'too_many_teams' });
      return;
    }
    const team = await prisma.team.create({ data: { name, code: makeCode(), coachId: req.athleteId } });
    res.status(201).json({ team: { id: team.id, name: team.name, code: team.code, memberCount: 0 } });
  });

  router.post('/join', async (req, res) => {
    const code = typeof req.body?.code === 'string' ? req.body.code.trim().toUpperCase() : '';
    const nickname = cleanNickname(req.body?.nickname);
    if (!CODE.test(code) || !nickname) {
      res.status(400).json({ error: !CODE.test(code) ? 'invalid_code' : 'invalid_nickname' });
      return;
    }
    const team = await prisma.team.findUnique({ where: { code }, include: { _count: { select: { members: true } } } });
    if (!team) {
      res.status(404).json({ error: 'no_such_team' });
      return;
    }
    if (team.coachId === req.athleteId) {
      res.status(409).json({ error: 'you_coach_this_team' });
      return;
    }
    const where = { teamId_athleteId: { teamId: team.id, athleteId: req.athleteId } };
    if (await prisma.teamMember.findUnique({ where })) {
      res.json({ team: { id: team.id, name: team.name, nickname } });
      return;
    }
    if (team._count.members >= MAX_MEMBERS) {
      res.status(409).json({ error: 'team_full' });
      return;
    }
    await prisma.teamMember.create({ data: { teamId: team.id, athleteId: req.athleteId, nickname } });
    res.status(201).json({ team: { id: team.id, name: team.name, nickname } });
  });

  router.get('/assignments', async (req, res) => {
    const from = day(req.query.from);
    if (!from) {
      res.status(400).json({ error: 'invalid_from' });
      return;
    }
    const memberships = await prisma.teamMember.findMany({ where: { athleteId: req.athleteId }, include: { team: true } });
    if (memberships.length === 0) {
      res.json({ assignments: [] });
      return;
    }
    const names = new Map(memberships.map((m) => [m.teamId, m.team.name]));
    const rows = await prisma.assignment.findMany({
      where: { teamId: { in: [...names.keys()] }, date: { gte: from } },
      orderBy: { date: 'asc' },
      take: 100,
    });
    res.json({ assignments: rows.map((a) => assignmentJSON(a, names.get(a.teamId))) });
  });

  router.delete('/:id', async (req, res) => {
    const team = await prisma.team.findUnique({ where: { id: req.params.id } });
    if (!team) {
      res.status(404).json({ error: 'no_such_team' });
      return;
    }
    if (team.coachId === req.athleteId) {
      await prisma.team.delete({ where: { id: team.id } });
      res.status(204).end();
      return;
    }
    const where = { teamId_athleteId: { teamId: team.id, athleteId: req.athleteId } };
    if (!(await prisma.teamMember.findUnique({ where }))) {
      res.status(404).json({ error: 'not_a_member' });
      return;
    }
    await prisma.teamMember.delete({ where });
    res.status(204).end();
  });

  router.get('/:id/readiness', async (req, res) => {
    const team = await coachedTeam(req, res);
    if (!team) return;
    const today = day(req.query.today);
    const weekStart = day(req.query.weekStart);
    if (!today || !weekStart) {
      res.status(400).json({ error: 'invalid_dates' });
      return;
    }
    const members = await prisma.teamMember.findMany({ where: { teamId: team.id }, orderBy: { nickname: 'asc' } });
    const ids = members.map((m) => m.athleteId);
    const checkIns = ids.length
      ? await prisma.checkIn.findMany({ where: { athleteId: { in: ids }, date: { gte: weekStart } } })
      : [];
    const sessions = ids.length
      ? await prisma.session.findMany({ where: { athleteId: { in: ids }, startedAt: { gte: weekStart } } })
      : [];
    const todayKey = today.toISOString().slice(0, 10);
    res.json({
      team: { id: team.id, name: team.name, code: team.code },
      members: members.map((m) => {
        const mine = checkIns.filter((c) => c.athleteId === m.athleteId);
        const todays = mine.find((c) => c.date.toISOString().slice(0, 10) === todayKey);
        const trained = sessions.filter((s) => s.athleteId === m.athleteId);
        return {
          nickname: m.nickname,
          checkedInToday: Boolean(todays),
          readiness: todays?.readinessBand ?? null,
          checkInsThisWeek: mine.length,
          sessionsThisWeek: trained.length,
          minutesThisWeek: trained.reduce((sum, s) => sum + (s.minutes ?? 0), 0),
        };
      }),
    });
  });

  router.get('/:id/assignments', async (req, res) => {
    const team = await coachedTeam(req, res);
    if (!team) return;
    const from = day(req.query.from);
    if (!from) {
      res.status(400).json({ error: 'invalid_from' });
      return;
    }
    const rows = await prisma.assignment.findMany({ where: { teamId: team.id, date: { gte: from } }, orderBy: { date: 'asc' }, take: 100 });
    res.json({ assignments: rows.map((a) => assignmentJSON(a, team.name)) });
  });

  router.post('/:id/assignments', async (req, res) => {
    const team = await coachedTeam(req, res);
    if (!team) return;
    const date = day(req.body?.date);
    const title = cleanName(req.body?.title);
    const note = typeof req.body?.note === 'string' && req.body.note.trim() ? req.body.note.trim().slice(0, 300) : null;
    const items = cleanItems(req.body?.items);
    if (!date || !title || !items) {
      res.status(400).json({ error: !date ? 'invalid_date' : !title ? 'invalid_title' : 'invalid_items' });
      return;
    }
    const created = await prisma.assignment.create({ data: { teamId: team.id, date, title, note, items } });
    res.status(201).json({ assignment: assignmentJSON(created, team.name) });
  });

  router.delete('/:id/assignments/:assignmentId', async (req, res) => {
    const team = await coachedTeam(req, res);
    if (!team) return;
    const assignment = await prisma.assignment.findUnique({ where: { id: req.params.assignmentId } });
    if (!assignment || assignment.teamId !== team.id) {
      res.status(404).json({ error: 'no_such_assignment' });
      return;
    }
    await prisma.assignment.delete({ where: { id: assignment.id } });
    res.status(204).end();
  });

  return router;
}
