import express from 'express';

import { requireAuth } from '../lib/requireAuth.js';
import { uniqueCode } from '../lib/codes.js';
import { isObjectionable } from '../lib/moderation.js';
import { cleanName, cleanNickname } from './leagues.js';

const CODE = /^[A-HJ-KM-NP-Z2-9]{6}$/;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const SLUG = /^[a-z0-9][a-z0-9-]{0,80}$/;
const MAX_TEAMS_PER_COACH = 10;
const MAX_MEMBERS = 80;
const MAX_STAFF = 5;
const DAY_MS = 86_400_000;
const HEALTH_KINDS = new Set(['pain', 'painGone', 'paused', 'cleared']);
const PAIN_AREAS = new Set(['head', 'neck', 'shoulder', 'chest', 'arm', 'back', 'core', 'hip', 'leg', 'knee', 'ankle', 'other']);
const PAIN_LEVELS = new Set(['little', 'some', 'lot']);

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

function announcementJSON(a, teamName) {
  return { id: a.id, teamId: a.teamId, teamName, text: a.text, createdAt: a.createdAt.toISOString() };
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
 *   DELETE /teams/:id/membership          leave the team as an athlete (a coach too)
 *   GET    /teams/:id/readiness?today=YYYY-MM-DD&weekStart=YYYY-MM-DD   coach only
 *   GET    /teams/:id/assignments?from=YYYY-MM-DD                       coach only
 *   POST   /teams/:id/assignments         { date, title, note?, items: [{ itemSlug, sets, reps?, seconds? }] }
 *   DELETE /teams/:id/assignments/:assignmentId
 *   GET    /teams/assignments?from=YYYY-MM-DD   workouts assigned to me, from every team I'm on
 *
 * Health (only with the athlete's consent, per team; off by default):
 *   PATCH  /teams/:id/membership          { shareHealth } — share pain reports and training pauses
 *   POST   /teams/health                  { day, kind, areas?, level? } — kept only while shared with a team
 *   GET    /teams/:id/health              coach or athletic trainer: notes of members who share them
 *   POST   /teams/:id/trainer-code        coach: make (or replace) the athletic trainer's code
 *   DELETE /teams/:id/trainer-code        coach: switch it off and remove the trainers
 *   POST   /teams/join-staff              { code } — join as the team's athletic trainer
 *   POST   /teams/:id/rtp                 trainer: { memberId, step 1–6, note? } — a return-to-play step
 *   GET    /teams/rtp/mine                my return-to-play steps, as recorded
 *   GET    /teams/:id/rtp?memberId=       coach or trainer: one athlete's steps
 *   DELETE /teams/:id/members/:memberId   coach: remove an athlete from the team
 *
 * Announcements (one-way, no replies):
 *   GET    /teams/:id/announcements       coach: the last 14 days'
 *   POST   /teams/:id/announcements       coach: { text }
 *   DELETE /teams/:id/announcements/:announcementId
 *   GET    /teams/announcements           the last 14 days', from every team I'm on
 *
 * Shout-outs (private coach notes):
 *   POST   /teams/:id/shoutouts           coach: { memberId, text }
 *   GET    /teams/shoutouts               mine, the last 14 days
 */
export function teamsRouter({ prisma, sessionSecret, notifier = null, now = () => new Date() }) {
  const router = express.Router();
  router.use(requireAuth({ sessionSecret }));

  const notify = (ids, message) => notifier?.notify(ids, message);

  async function memberIds(teamId) {
    const rows = await prisma.teamMember.findMany({ where: { teamId } });
    return rows.map((m) => m.athleteId);
  }

  async function staffIds(team) {
    const rows = await prisma.teamStaff.findMany({ where: { teamId: team.id } });
    return [team.coachId, ...rows.map((s) => s.athleteId)];
  }

  async function coachedTeam(req, res) {
    const team = await prisma.team.findUnique({ where: { id: req.params.id } });
    if (!team || team.coachId !== req.athleteId) {
      res.status(404).json({ error: 'not_your_team' });
      return null;
    }
    return team;
  }

  /**
   * Per member who shares health with this team: pain in the last 14 days
   * (latest first) and whether training is paused after a head injury.
   */
  async function healthBoard(teamId) {
    const members = await prisma.teamMember.findMany({ where: { teamId, shareHealth: true } });
    if (members.length === 0) return [];
    const since = new Date(now().getTime() - 14 * DAY_MS);
    const notes = await prisma.healthNote.findMany({ where: { athleteId: { in: members.map((m) => m.athleteId) }, day: { gte: since } } });
    const rtpEntries = await prisma.rtpEntry.findMany({ where: { teamId, athleteId: { in: members.map((m) => m.athleteId) } } });
    return members
      .map((m) => {
        const mine = notes.filter((n) => n.athleteId === m.athleteId).sort((a, b) => b.day - a.day || b.createdAt - a.createdAt);
        const lastPause = mine.find((n) => n.kind === 'paused' || n.kind === 'cleared');
        const latestPain = mine.find((n) => n.kind === 'pain' || n.kind === 'painGone');
        const rtp = rtpEntries.filter((r) => r.athleteId === m.athleteId).sort((a, b) => b.createdAt - a.createdAt)[0];
        return {
          memberId: m.athleteId,
          nickname: m.nickname,
          rtpStep: rtp?.step ?? null,
          rtpRecordedAt: rtp ? rtp.createdAt.toISOString() : null,
          paused: lastPause?.kind === 'paused',
          pausedSince: lastPause?.kind === 'paused' ? lastPause.day.toISOString().slice(0, 10) : null,
          pain: latestPain?.kind === 'pain'
            ? { day: latestPain.day.toISOString().slice(0, 10), areas: latestPain.areas, level: latestPain.level }
            : null,
          painDays: new Set(mine.filter((n) => n.kind === 'pain').map((n) => n.day.toISOString().slice(0, 10))).size,
        };
      })
      .sort((a, b) => a.nickname.localeCompare(b.nickname));
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
    const staffing = await prisma.teamStaff.findMany({ where: { athleteId: req.athleteId }, include: { team: true } });
    res.json({
      coaching: coaching.map((t) => ({ id: t.id, name: t.name, code: t.code, trainerCode: t.trainerCode ?? null, memberCount: t._count.members })),
      member: memberships.map((m) => ({ id: m.team.id, name: m.team.name, nickname: m.nickname, shareHealth: Boolean(m.shareHealth) })),
      trainer: staffing.map((s) => ({ id: s.team.id, name: s.team.name })),
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
    const team = await prisma.team.create({ data: { name, code: await uniqueCode(prisma), coachId: req.athleteId } });
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
    // A coach may also be on their own team as an athlete (a player-coach,
    // or trying it out with one account).
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

  // ---- Health sharing -----------------------------------------------------

  router.post('/health', async (req, res) => {
    const date = day(req.body?.day);
    const kind = req.body?.kind;
    if (!date || !HEALTH_KINDS.has(kind)) {
      res.status(400).json({ error: !date ? 'invalid_day' : 'invalid_kind' });
      return;
    }
    // Kept only while the athlete shares health with at least one team.
    const sharing = await prisma.teamMember.count({ where: { athleteId: req.athleteId, shareHealth: true } });
    if (sharing === 0) {
      res.status(204).end();
      return;
    }
    const areas = Array.isArray(req.body?.areas) ? req.body.areas.filter((a) => PAIN_AREAS.has(a)).slice(0, 12) : [];
    const level = PAIN_LEVELS.has(req.body?.level) ? req.body.level : null;
    const already = await prisma.healthNote.count({ where: { athleteId: req.athleteId, day: date, kind } });
    await prisma.healthNote.create({ data: { athleteId: req.athleteId, day: date, kind, areas, level } });
    res.status(201).json({ ok: true });
    // Staff hear about the first note of a kind each day, without a name or body part on the lock screen.
    if (!already && (kind === 'pain' || kind === 'paused')) {
      const teams = await prisma.teamMember.findMany({ where: { athleteId: req.athleteId, shareHealth: true }, include: { team: true } });
      for (const m of teams) {
        notify(await staffIds(m.team), {
          kind: 'health',
          teamId: m.team.id,
          title: m.team.name,
          body: kind === 'paused' ? 'An athlete has paused training. Open the health board.' : 'A new pain report is on the health board.',
        });
      }
    }
  });

  router.post('/join-staff', async (req, res) => {
    const code = typeof req.body?.code === 'string' ? req.body.code.trim().toUpperCase() : '';
    if (!CODE.test(code)) {
      res.status(400).json({ error: 'invalid_code' });
      return;
    }
    const team = await prisma.team.findUnique({ where: { trainerCode: code } });
    if (!team) {
      res.status(404).json({ error: 'no_such_team' });
      return;
    }
    const where = { teamId_athleteId: { teamId: team.id, athleteId: req.athleteId } };
    if (!(await prisma.teamStaff.findUnique({ where }))) {
      const count = await prisma.teamStaff.count({ where: { teamId: team.id } });
      if (count >= MAX_STAFF) {
        res.status(409).json({ error: 'team_full' });
        return;
      }
      await prisma.teamStaff.create({ data: { teamId: team.id, athleteId: req.athleteId, role: 'trainer' } });
    }
    res.status(201).json({ team: { id: team.id, name: team.name } });
  });

  // ---- Announcements ---------------------------------------------------------

  router.get('/shoutouts', async (req, res) => {
    const since = new Date(now().getTime() - 14 * DAY_MS);
    const rows = await prisma.shoutout.findMany({ where: { athleteId: req.athleteId, createdAt: { gte: since } }, include: { team: true } });
    rows.sort((a, b) => b.createdAt - a.createdAt);
    res.json({ shoutouts: rows.map((r) => ({ id: r.id, teamName: r.team?.name ?? null, text: r.text, createdAt: r.createdAt.toISOString() })) });
  });

  // My return-to-play steps, as my teams' athletic trainers recorded them.
  router.get('/rtp/mine', async (req, res) => {
    const rows = await prisma.rtpEntry.findMany({ where: { athleteId: req.athleteId }, include: { team: true } });
    rows.sort((a, b) => b.createdAt - a.createdAt);
    res.json({ entries: rows.slice(0, 20).map((r) => ({ step: r.step, note: r.note, teamName: r.team?.name ?? null, recordedAt: r.createdAt.toISOString() })) });
  });

  router.get('/announcements', async (req, res) => {
    const memberships = await prisma.teamMember.findMany({ where: { athleteId: req.athleteId }, include: { team: true } });
    if (memberships.length === 0) {
      res.json({ announcements: [] });
      return;
    }
    const names = new Map(memberships.map((m) => [m.teamId, m.team.name]));
    const since = new Date(now().getTime() - 14 * DAY_MS);
    const rows = await prisma.announcement.findMany({
      where: { teamId: { in: [...names.keys()] }, createdAt: { gte: since } },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    res.json({ announcements: rows.map((a) => announcementJSON(a, names.get(a.teamId))) });
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

  // Leave a team as an athlete (never deletes it, even for its coach).
  router.delete('/:id/membership', async (req, res) => {
    const where = { teamId_athleteId: { teamId: req.params.id, athleteId: req.athleteId } };
    if (!(await prisma.teamMember.findUnique({ where }))) {
      res.status(404).json({ error: 'not_a_member' });
      return;
    }
    await prisma.teamMember.delete({ where });
    res.status(204).end();
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

  router.patch('/:id/membership', async (req, res) => {
    const where = { teamId_athleteId: { teamId: req.params.id, athleteId: req.athleteId } };
    const member = await prisma.teamMember.findUnique({ where });
    if (!member || typeof req.body?.shareHealth !== 'boolean') {
      res.status(member ? 400 : 404).json({ error: member ? 'invalid_share' : 'not_a_member' });
      return;
    }
    await prisma.teamMember.update({ where, data: { shareHealth: req.body.shareHealth } });
    // Stopping sharing everywhere deletes what the server kept.
    if (!req.body.shareHealth) {
      const stillSharing = await prisma.teamMember.count({ where: { athleteId: req.athleteId, shareHealth: true } });
      if (stillSharing === 0) await prisma.healthNote.deleteMany({ where: { athleteId: req.athleteId } });
    }
    res.json({ shareHealth: req.body.shareHealth });
  });

  router.get('/:id/health', async (req, res) => {
    const team = await prisma.team.findUnique({ where: { id: req.params.id } });
    const isCoach = team?.coachId === req.athleteId;
    const isTrainer = team && !isCoach
      ? Boolean(await prisma.teamStaff.findUnique({ where: { teamId_athleteId: { teamId: team.id, athleteId: req.athleteId } } }))
      : false;
    if (!team || (!isCoach && !isTrainer)) {
      res.status(404).json({ error: 'not_your_team' });
      return;
    }
    res.json({ team: { id: team.id, name: team.name }, role: isCoach ? 'coach' : 'trainer', members: await healthBoard(team.id) });
  });

  // The athletic trainer records a return-to-play step (only for members who share health).
  router.post('/:id/rtp', async (req, res) => {
    const team = await prisma.team.findUnique({ where: { id: req.params.id } });
    const isTrainer = team ? Boolean(await prisma.teamStaff.findUnique({ where: { teamId_athleteId: { teamId: team.id, athleteId: req.athleteId } } })) : false;
    if (!team || !isTrainer) {
      res.status(404).json({ error: 'not_your_team' });
      return;
    }
    const memberId = typeof req.body?.memberId === 'string' ? req.body.memberId : '';
    const step = Number.isInteger(req.body?.step) && req.body.step >= 1 && req.body.step <= 6 ? req.body.step : null;
    const note = typeof req.body?.note === 'string' && req.body.note.trim() ? req.body.note.trim().slice(0, 200) : null;
    const member = await prisma.teamMember.findUnique({ where: { teamId_athleteId: { teamId: team.id, athleteId: memberId } } });
    if (!member || !member.shareHealth || !step) {
      res.status(!member || !member.shareHealth ? 404 : 400).json({ error: !step ? 'invalid_step' : 'not_shared' });
      return;
    }
    if (note && isObjectionable(note)) {
      res.status(400).json({ error: 'inappropriate' });
      return;
    }
    await prisma.rtpEntry.create({ data: { teamId: team.id, athleteId: memberId, step, note, recordedBy: req.athleteId } });
    res.status(201).json({ ok: true });
    notify([memberId], { kind: 'rtp', teamId: team.id, title: team.name, body: 'Your return-to-play step was updated.' });
  });

  // Coach or athletic trainer: one athlete's return-to-play steps, newest first.
  router.get('/:id/rtp', async (req, res) => {
    const team = await prisma.team.findUnique({ where: { id: req.params.id } });
    const isCoach = team?.coachId === req.athleteId;
    const isTrainer = team && !isCoach
      ? Boolean(await prisma.teamStaff.findUnique({ where: { teamId_athleteId: { teamId: team.id, athleteId: req.athleteId } } }))
      : false;
    const memberId = typeof req.query.memberId === 'string' ? req.query.memberId : '';
    const member = team && (isCoach || isTrainer)
      ? await prisma.teamMember.findUnique({ where: { teamId_athleteId: { teamId: team.id, athleteId: memberId } } })
      : null;
    if (!member || !member.shareHealth) {
      res.status(404).json({ error: 'not_your_team' });
      return;
    }
    const rows = await prisma.rtpEntry.findMany({ where: { teamId: team.id, athleteId: memberId } });
    rows.sort((a, b) => b.createdAt - a.createdAt);
    res.json({ entries: rows.slice(0, 50).map((r) => ({ step: r.step, note: r.note, recordedAt: r.createdAt.toISOString() })) });
  });

  // Coach: remove an athlete from the team (their own data stays theirs).
  router.delete('/:id/members/:memberId', async (req, res) => {
    const team = await coachedTeam(req, res);
    if (!team) return;
    const where = { teamId_athleteId: { teamId: team.id, athleteId: String(req.params.memberId) } };
    if (!(await prisma.teamMember.findUnique({ where }))) {
      res.status(404).json({ error: 'not_a_member' });
      return;
    }
    await prisma.teamMember.delete({ where });
    res.status(204).end();
  });

  router.post('/:id/trainer-code', async (req, res) => {
    const team = await coachedTeam(req, res);
    if (!team) return;
    const trainerCode = await uniqueCode(prisma);
    await prisma.team.update({ where: { id: team.id }, data: { trainerCode } });
    res.status(201).json({ trainerCode });
  });

  router.delete('/:id/trainer-code', async (req, res) => {
    const team = await coachedTeam(req, res);
    if (!team) return;
    await prisma.team.update({ where: { id: team.id }, data: { trainerCode: null } });
    await prisma.teamStaff.deleteMany({ where: { teamId: team.id } });
    res.status(204).end();
  });

  // A private positive note to one athlete (no public praise, no ranking).
  router.post('/:id/shoutouts', async (req, res) => {
    const team = await coachedTeam(req, res);
    if (!team) return;
    const text = typeof req.body?.text === 'string' ? req.body.text.trim().replace(/\s+/g, ' ') : '';
    const memberId = typeof req.body?.memberId === 'string' ? req.body.memberId : '';
    if (!text || text.length > 200) {
      res.status(400).json({ error: 'invalid_text' });
      return;
    }
    if (isObjectionable(text)) {
      res.status(400).json({ error: 'inappropriate' });
      return;
    }
    const member = await prisma.teamMember.findUnique({ where: { teamId_athleteId: { teamId: team.id, athleteId: memberId } } });
    if (!member) {
      res.status(404).json({ error: 'not_a_member' });
      return;
    }
    await prisma.shoutout.create({ data: { teamId: team.id, athleteId: memberId, text } });
    res.status(201).json({ ok: true });
    notify([memberId], { kind: 'shoutout', teamId: team.id, title: team.name, body: 'Your coach left you a note.' });
  });

  router.get('/:id/announcements', async (req, res) => {
    const team = await coachedTeam(req, res);
    if (!team) return;
    const since = new Date(now().getTime() - 14 * DAY_MS);
    const rows = await prisma.announcement.findMany({ where: { teamId: team.id, createdAt: { gte: since } }, orderBy: { createdAt: 'desc' }, take: 20 });
    res.json({ announcements: rows.map((a) => announcementJSON(a, team.name)) });
  });

  router.post('/:id/announcements', async (req, res) => {
    const team = await coachedTeam(req, res);
    if (!team) return;
    const text = typeof req.body?.text === 'string' ? req.body.text.trim().replace(/\s+/g, ' ') : '';
    if (!text || text.length > 300) {
      res.status(400).json({ error: 'invalid_text' });
      return;
    }
    if (isObjectionable(text)) {
      res.status(400).json({ error: 'inappropriate' });
      return;
    }
    const created = await prisma.announcement.create({ data: { teamId: team.id, text } });
    res.status(201).json({ announcement: announcementJSON(created, team.name) });
    notify(await memberIds(team.id), { kind: 'announcement', teamId: team.id, title: team.name, body: text.length > 110 ? `${text.slice(0, 107)}…` : text });
  });

  router.delete('/:id/announcements/:announcementId', async (req, res) => {
    const team = await coachedTeam(req, res);
    if (!team) return;
    const row = await prisma.announcement.findUnique({ where: { id: req.params.announcementId } });
    if (!row || row.teamId !== team.id) {
      res.status(404).json({ error: 'no_such_announcement' });
      return;
    }
    await prisma.announcement.delete({ where: { id: row.id } });
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
    // Two weeks back for the trend (at least the week).
    const trendStart = new Date(Math.min(weekStart.getTime(), today.getTime() - 13 * DAY_MS));
    const checkIns = ids.length
      ? await prisma.checkIn.findMany({ where: { athleteId: { in: ids }, date: { gte: trendStart } } })
      : [];
    const health = new Map((await healthBoard(team.id)).map((h) => [h.nickname, h]));
    const trendDays = Array.from({ length: 14 }, (_, i) => new Date(today.getTime() - (13 - i) * DAY_MS).toISOString().slice(0, 10));
    const daysSoFar = Math.max(1, Math.round((today - weekStart) / DAY_MS) + 1);
    const sessions = ids.length
      ? await prisma.session.findMany({ where: { athleteId: { in: ids }, startedAt: { gte: weekStart } } })
      : [];
    const todayKey = today.toISOString().slice(0, 10);
    res.json({
      team: { id: team.id, name: team.name, code: team.code },
      members: members.map((m) => {
        const all = checkIns.filter((c) => c.athleteId === m.athleteId);
        const mine = all.filter((c) => c.date >= weekStart);
        const todays = mine.find((c) => c.date.toISOString().slice(0, 10) === todayKey);
        const trained = sessions.filter((s) => s.athleteId === m.athleteId);
        const byDay = new Map(all.map((c) => [c.date.toISOString().slice(0, 10), c.readinessBand ?? 'NONE']));
        return {
          memberId: m.athleteId,
          nickname: m.nickname,
          checkedInToday: Boolean(todays),
          readiness: todays?.readinessBand ?? null,
          // The last 14 days, oldest first: GREEN / AMBER / RED, NONE (checked in, no band yet) or null (no check-in).
          trend: trendDays.map((d) => byDay.get(d) ?? null),
          missedThisWeek: Math.max(0, Math.min(7, daysSoFar) - mine.length),
          sharesHealth: Boolean(m.shareHealth),
          health: m.shareHealth ? health.get(m.nickname) ?? null : null,
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
    if (note && isObjectionable(note)) {
      res.status(400).json({ error: 'inappropriate' });
      return;
    }
    const items = cleanItems(req.body?.items);
    if (!date || !title || !items) {
      res.status(400).json({ error: !date ? 'invalid_date' : !title ? 'invalid_title' : 'invalid_items' });
      return;
    }
    const created = await prisma.assignment.create({ data: { teamId: team.id, date, title, note, items } });
    res.status(201).json({ assignment: assignmentJSON(created, team.name) });
    notify(await memberIds(team.id), { kind: 'assignment', teamId: team.id, title: team.name, body: `New workout from your coach: ${title}` });
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
