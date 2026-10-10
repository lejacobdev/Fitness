import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { signSessionToken } from '../src/lib/sessionToken.js';

const SESSION_SECRET = 'test-session-secret';

/** A tiny in-memory stand-in for the Prisma calls these routes make. */
function fakePrisma() {
  const db = { league: [], leagueMember: [], weeklyXP: [], team: [], teamMember: [], teamStaff: [], assignment: [], announcement: [], shoutout: [], healthNote: [], partnerSession: [], partnerProgress: [], rtpEntry: [], parentLink: [], parentEmail: [], checkIn: [], session: [], syncedState: [], sharedWorkout: [], pushDevice: [] };

  const matches = (row, where = {}) => Object.entries(where).every(([field, cond]) => {
    if (cond && typeof cond === 'object' && !(cond instanceof Date)) {
      if ('in' in cond) return cond.in.includes(row[field]);
      if ('gte' in cond || 'lt' in cond) {
        return (cond.gte === undefined || row[field] >= cond.gte) && (cond.lt === undefined || row[field] < cond.lt);
      }
      // A compound key: { leagueId_athleteId: { leagueId, athleteId } }.
      return Object.entries(cond).every(([k, v]) => row[k] === v);
    }
    if (cond instanceof Date) return row[field] instanceof Date && row[field].getTime() === cond.getTime();
    return row[field] === cond;
  });

  const relations = {
    league: { members: ['leagueMember', 'leagueId'] },
    team: { members: ['teamMember', 'teamId'] },
    leagueMember: { league: ['league', 'leagueId', true] },
    teamMember: { team: ['team', 'teamId', true] },
    teamStaff: { team: ['team', 'teamId', true] },
    shoutout: { team: ['team', 'teamId', true] },
    partnerSession: { people: ['partnerProgress', 'code', false, 'code'] },
    rtpEntry: { team: ['team', 'teamId', true] },
  };

  function withIncludes(model, row, include) {
    if (!row || !include) return row;
    const out = { ...row };
    for (const [name, spec] of Object.entries(include)) {
      if (name === '_count') {
        out._count = Object.fromEntries(Object.keys(spec.select).map((rel) => {
          const [target, fk] = relations[model][rel];
          return [rel, db[target].filter((r) => r[fk] === row.id).length];
        }));
        continue;
      }
      const [target, fk, toOne, key = 'id'] = relations[model][name];
      out[name] = toOne
        ? withIncludes(target, db[target].find((r) => r.id === row[fk]), spec === true ? undefined : spec.include)
        : db[target].filter((r) => r[fk] === row[key]).map((r) => withIncludes(target, r, spec === true ? undefined : spec.include));
    }
    return out;
  }

  const client = {};
  for (const model of Object.keys(db)) {
    client[model] = {
      async findUnique({ where, include }) { return withIncludes(model, db[model].find((r) => matches(r, where)) ?? null, include); },
      async findMany({ where, include, take } = {}) {
        const rows = db[model].filter((r) => matches(r, where)).map((r) => withIncludes(model, r, include));
        return take ? rows.slice(0, take) : rows;
      },
      async count({ where } = {}) { return db[model].filter((r) => matches(r, where)).length; },
      async create({ data }) {
        const { members, ...rest } = data;
        const row = { id: crypto.randomUUID(), createdAt: new Date(), ...rest };
        db[model].push(row);
        if (members?.create) db.leagueMember.push({ leagueId: row.id, ...members.create });
        return row;
      },
      async update({ where, data }) {
        const row = db[model].find((r) => matches(r, where));
        if (!row) throw new Error(`no ${model} row`);
        Object.assign(row, data);
        return row;
      },
      async upsert({ where, create, update }) {
        const existing = db[model].find((r) => matches(r, where));
        if (existing) { Object.assign(existing, update); return existing; }
        db[model].push({ ...create });
        return create;
      },
      async delete({ where }) {
        const index = db[model].findIndex((r) => matches(r, where));
        const [row] = db[model].splice(index, 1);
        // Cascades the routes rely on.
        if (model === 'league') db.leagueMember = db.leagueMember.filter((m) => m.leagueId !== row.id);
        if (model === 'team') {
          db.teamMember = db.teamMember.filter((m) => m.teamId !== row.id);
          db.assignment = db.assignment.filter((a) => a.teamId !== row.id);
          db.teamStaff = db.teamStaff.filter((a) => a.teamId !== row.id);
          db.announcement = db.announcement.filter((a) => a.teamId !== row.id);
        }
        return row;
      },
      async deleteMany({ where }) { db[model] = db[model].filter((r) => !matches(r, where)); return {}; },
    };
  }
  client._db = db;
  return client;
}

async function serve(prisma, extra = {}) {
  const app = createApp({ prisma, sessionSecret: SESSION_SECRET, ...extra });
  const server = await new Promise((resolve) => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
  const url = `http://127.0.0.1:${server.address().port}`;
  const call = (athleteId, method, path, body) => fetch(`${url}${path}`, {
    method,
    headers: { authorization: `Bearer ${signSessionToken(athleteId, { secret: SESSION_SECRET })}`, 'content-type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { url, call, close: () => new Promise((r) => server.close(r)) };
}

test('leagues: create, join by code, weekly XP table, leave', async () => {
  const prisma = fakePrisma();
  const { call, close } = await serve(prisma);
  try {
    const created = await (await call('a1', 'POST', '/leagues', { name: 'U17 Girls', nickname: 'Mia' })).json();
    assert.match(created.league.code, /^[A-HJ-KM-NP-Z2-9]{6}$/);
    assert.equal((await call('a2', 'POST', '/leagues/join', { code: created.league.code.toLowerCase(), nickname: 'Jo' })).status, 201);
    assert.equal((await call('a3', 'POST', '/leagues/join', { code: 'ZZZZZZ', nickname: 'X9' })).status, 404);
    assert.equal((await call('a3', 'POST', '/leagues/join', { code: created.league.code, nickname: '<script>' })).status, 400);

    const week = '2026-09-21';
    await call('a1', 'PUT', '/leagues/xp', { week, xp: 40 });
    await call('a2', 'PUT', '/leagues/xp', { week, xp: 65 });
    await call('a2', 'PUT', '/leagues/xp', { week, xp: 10 }); // never goes down
    const table = await (await call('a1', 'GET', `/leagues?week=${week}`)).json();
    assert.deepEqual(table.leagues[0].members.map((m) => [m.nickname, m.xp, m.isMe]), [['Jo', 65, false], ['Mia', 40, true]]);

    assert.equal((await call('a1', 'DELETE', `/leagues/${created.league.id}`)).status, 204);
    assert.equal((await call('a2', 'DELETE', `/leagues/${created.league.id}`)).status, 204);
    assert.equal(prisma._db.league.length, 0, 'the last one out deletes the league');
  } finally {
    await close();
  }
});

test('teams: the coach sees readiness and training, never more; members get assignments', async () => {
  const prisma = fakePrisma();
  const { call, close } = await serve(prisma);
  try {
    const { team } = await (await call('coach', 'POST', '/teams', { name: 'Varsity Soccer' })).json();
    assert.equal((await call('coach', 'POST', '/teams/join', { code: team.code, nickname: 'Coach' })).status, 201, 'a player-coach can join their own team');
    assert.equal((await call('coach', 'DELETE', `/teams/${team.id}/membership`)).status, 204, 'the coach leaves as an athlete');
    assert.equal(prisma._db.team.length, 1, 'leaving never deletes the team');
    assert.equal((await call('coach', 'DELETE', `/teams/${team.id}`)).status, 204, 'as coach, deleting removes the team');
    const again = await (await call('coach', 'POST', '/teams', { name: 'Varsity Soccer' })).json();
    team.id = again.team.id;
    team.code = again.team.code;
    assert.equal((await call('ath1', 'POST', '/teams/join', { code: team.code, nickname: 'Sam' })).status, 201);

    prisma._db.checkIn.push({ athleteId: 'ath1', date: new Date('2026-09-25T00:00:00Z'), readinessBand: 'AMBER', energy: 2, sleepHours: 7 });
    prisma._db.session.push({ athleteId: 'ath1', startedAt: new Date('2026-09-23T16:00:00Z'), minutes: 45 });
    const board = await (await call('coach', 'GET', `/teams/${team.id}/readiness?today=2026-09-25&weekStart=2026-09-21`)).json();
    assert.deepEqual(board.members[0], {
      nickname: 'Sam', checkedInToday: true, readiness: 'AMBER', checkInsThisWeek: 1, sessionsThisWeek: 1, minutesThisWeek: 45,
      memberId: 'ath1', trend: [...Array(13).fill(null), 'AMBER'], missedThisWeek: 4, sharesHealth: false, health: null,
    });
    assert.equal((await call('ath1', 'GET', `/teams/${team.id}/readiness?today=2026-09-25&weekStart=2026-09-21`)).status, 404, 'only the coach');

    const assigned = await call('coach', 'POST', `/teams/${team.id}/assignments`, {
      date: '2026-09-26', title: 'Recovery day', note: 'Easy!', items: [{ itemSlug: 'worlds-greatest-stretch', sets: 2, seconds: 45 }],
    });
    assert.equal(assigned.status, 201);
    assert.equal((await call('coach', 'POST', `/teams/${team.id}/assignments`, { date: '2026-09-26', title: 'Bad', items: [{ itemSlug: 'x', sets: 99 }] })).status, 400);
    const mine = await (await call('ath1', 'GET', '/teams/assignments?from=2026-09-25')).json();
    assert.equal(mine.assignments[0].title, 'Recovery day');
    assert.equal(mine.assignments[0].teamName, 'Varsity Soccer');

    assert.equal((await call('ath1', 'DELETE', `/teams/${team.id}`)).status, 204, 'a member leaves');
    assert.equal((await (await call('ath1', 'GET', '/teams/assignments?from=2026-09-25')).json()).assignments.length, 0);
  } finally {
    await close();
  }
});

test('parent link: a private weekly summary page that can be switched off', async () => {
  const prisma = fakePrisma();
  const { url, call, close } = await serve(prisma);
  try {
    const today = new Date();
    prisma._db.checkIn.push({ athleteId: 'kid', date: today, readinessBand: 'GREEN', energy: 4, sleepHours: 8.5 });
    prisma._db.session.push({ athleteId: 'kid', startedAt: today, minutes: 50 });
    prisma._db.syncedState.push({ athleteId: 'kid', key: 'competitions', value: [{ date: today.getTime() / 1000 + 3 * 86400, kind: 'GAME', isHome: false, notes: 'Game at <Lions>' }] });

    const { url: link } = await (await call('kid', 'POST', '/parent-link')).json();
    const token = link.split('/').pop();
    const pageRes = await fetch(`${url}/parent/${token}`);
    assert.equal(pageRes.status, 200);
    assert.equal(pageRes.headers.get('cache-control'), 'no-store');
    const html = await pageRes.text();
    assert.match(html, /50<\/b><span>minutes/);
    assert.match(html, /8 h 30 m/);
    assert.match(html, /Game at &lt;Lions&gt;/, 'escaped');

    assert.equal((await call('kid', 'DELETE', '/parent-link')).status, 204);
    assert.equal((await fetch(`${url}/parent/${token}`)).status, 404, 'switched off');
  } finally {
    await close();
  }
});

test('teams: health is shared only with consent, with the coach and the athletic trainer', async () => {
  const prisma = fakePrisma();
  const { call, close } = await serve(prisma);
  try {
    const { team } = await (await call('coach', 'POST', '/teams', { name: 'Varsity Soccer' })).json();
    await call('ath1', 'POST', '/teams/join', { code: team.code, nickname: 'Sam' });
    await call('ath2', 'POST', '/teams/join', { code: team.code, nickname: 'Ali' });

    // Not shared yet: the note is dropped.
    assert.equal((await call('ath1', 'POST', '/teams/health', { day: '2026-09-30', kind: 'pain', areas: ['knee'], level: 'some' })).status, 204);
    assert.equal(prisma._db.healthNote.length, 0, 'nothing kept without consent');

    assert.equal((await call('ath1', 'PATCH', `/teams/${team.id}/membership`, { shareHealth: true })).status, 200);
    assert.equal((await call('ath1', 'POST', '/teams/health', { day: '2026-09-30', kind: 'pain', areas: ['knee', 'nonsense'], level: 'some' })).status, 201);
    assert.equal((await call('ath1', 'POST', '/teams/health', { day: '2026-09-30', kind: 'diagnosis' })).status, 400);
    assert.deepEqual(prisma._db.healthNote[0].areas, ['knee'], 'only known areas');

    const coachView = await (await call('coach', 'GET', `/teams/${team.id}/health`)).json();
    assert.equal(coachView.role, 'coach');
    assert.deepEqual(coachView.members.map((m) => m.nickname), ['Sam'], 'only members who share');
    assert.deepEqual(coachView.members[0].pain, { day: '2026-09-30', areas: ['knee'], level: 'some' });
    assert.equal((await call('ath2', 'GET', `/teams/${team.id}/health`)).status, 404, 'teammates never see it');

    // The athletic trainer joins with the coach's trainer code.
    const { trainerCode } = await (await call('coach', 'POST', `/teams/${team.id}/trainer-code`)).json();
    assert.match(trainerCode, /^[A-HJ-KM-NP-Z2-9]{6}$/);
    assert.equal((await call('trainer', 'POST', '/teams/join-staff', { code: trainerCode })).status, 201);
    const list = await (await call('trainer', 'GET', '/teams')).json();
    assert.deepEqual(list.trainer.map((t) => t.name), ['Varsity Soccer']);
    const trainerView = await (await call('trainer', 'GET', `/teams/${team.id}/health`)).json();
    assert.equal(trainerView.role, 'trainer');
    assert.equal((await call('trainer', 'GET', `/teams/${team.id}/readiness?today=2026-09-30&weekStart=2026-09-28`)).status, 404, 'the trainer sees health, not the coach board');

    // The trainer records a return-to-play step; the athlete sees it.
    assert.equal((await call('trainer', 'POST', `/teams/${team.id}/rtp`, { memberId: 'ath1', step: 7 })).status, 400);
    assert.equal((await call('trainer', 'POST', `/teams/${team.id}/rtp`, { memberId: 'ath2', step: 2 })).status, 404, 'only members who share');
    assert.equal((await call('coach', 'POST', `/teams/${team.id}/rtp`, { memberId: 'ath1', step: 2 })).status, 404, 'the trainer records it');
    assert.equal((await call('trainer', 'POST', `/teams/${team.id}/rtp`, { memberId: 'ath1', step: 2, note: 'Bike 15 min, no symptoms' })).status, 201);
    const rtp = await (await call('ath1', 'GET', '/teams/rtp/mine')).json();
    assert.deepEqual(rtp.entries.map((e) => [e.step, e.note]), [[2, 'Bike 15 min, no symptoms']]);
    assert.equal((await (await call('trainer', 'GET', `/teams/${team.id}/health`)).json()).members[0].rtpStep, 2);

    // Head injury: paused, then cleared.
    await call('ath1', 'POST', '/teams/health', { day: '2026-09-30', kind: 'paused' });
    assert.equal((await (await call('trainer', 'GET', `/teams/${team.id}/health`)).json()).members[0].paused, true);

    // The coach board: trend, missed check-ins, health for sharers only.
    const board = await (await call('coach', 'GET', `/teams/${team.id}/readiness?today=2026-09-30&weekStart=2026-09-28`)).json();
    const sam = board.members.find((m) => m.nickname === 'Sam');
    const ali = board.members.find((m) => m.nickname === 'Ali');
    assert.equal(sam.trend.length, 14);
    assert.equal(sam.missedThisWeek, 3, 'Mon–Wed without a check-in');
    assert.equal(sam.health.paused, true);
    assert.equal(ali.health, null, 'no consent, no health');

    // Turning sharing off everywhere deletes what was kept.
    await call('ath1', 'PATCH', `/teams/${team.id}/membership`, { shareHealth: false });
    assert.equal(prisma._db.healthNote.length, 0);

    // Switching the trainer code off removes the trainer.
    assert.equal((await call('coach', 'DELETE', `/teams/${team.id}/trainer-code`)).status, 204);
    assert.equal((await call('trainer', 'GET', `/teams/${team.id}/health`)).status, 404);
  } finally {
    await close();
  }
});

test('teams: announcements are one-way, moderated and only for members', async () => {
  const prisma = fakePrisma();
  const { call, close } = await serve(prisma);
  try {
    const { team } = await (await call('coach', 'POST', '/teams', { name: 'JV Volleyball' })).json();
    await call('ath1', 'POST', '/teams/join', { code: team.code, nickname: 'Kim' });
    assert.equal((await call('ath1', 'POST', `/teams/${team.id}/announcements`, { text: 'hi' })).status, 404, 'only the coach posts');
    assert.equal((await call('coach', 'POST', `/teams/${team.id}/announcements`, { text: 'x'.repeat(301) })).status, 400);
    assert.equal((await call('coach', 'POST', `/teams/${team.id}/announcements`, { text: 'you are all retarded' })).status, 400, 'filtered');
    const posted = await (await call('coach', 'POST', `/teams/${team.id}/announcements`, { text: 'Practice moved to 5 pm  tomorrow' })).json();
    assert.equal(posted.announcement.text, 'Practice moved to 5 pm tomorrow');
    const mine = await (await call('ath1', 'GET', '/teams/announcements')).json();
    assert.deepEqual(mine.announcements.map((a) => [a.teamName, a.text]), [['JV Volleyball', 'Practice moved to 5 pm tomorrow']]);
    assert.deepEqual((await (await call('stranger', 'GET', '/teams/announcements')).json()).announcements, []);
    assert.equal((await (await call('coach', 'GET', `/teams/${team.id}/announcements`)).json()).announcements.length, 1);
    assert.equal((await call('ath1', 'GET', `/teams/${team.id}/announcements`)).status, 404);
    assert.equal((await call('coach', 'DELETE', `/teams/${team.id}/announcements/${posted.announcement.id}`)).status, 204);
    assert.equal(prisma._db.announcement.length, 0);
  } finally {
    await close();
  }
});

test('parent email: confirmed by the parent first, stopped with one link', async () => {
  const prisma = fakePrisma();
  const { url, call, close } = await serve(prisma);
  try {
    assert.equal((await call('ath1', 'POST', '/parent-email', { email: 'not an email' })).status, 400);
    assert.deepEqual(await (await call('ath1', 'POST', '/parent-email', { email: 'Parent@Example.com ' })).json(), { email: 'parent@example.com', confirmed: false });
    assert.equal((await call('ath1', 'POST', '/parent-email', { email: 'other@example.com' })).status, 429, 'no rapid address changes');

    const { dueParentEmails, markParentEmailSent } = await import('../src/lib/parentMail.js');
    const wednesday = new Date('2026-09-30T18:00:00Z');
    const due = await dueParentEmails(prisma, wednesday);
    assert.deepEqual(due.map((m) => [m.kind, m.to]), [['confirm', 'parent@example.com']], 'only the confirmation before confirming');
    await markParentEmailSent(prisma, 'confirm', 'ath1', wednesday);
    assert.equal((await dueParentEmails(prisma, wednesday)).length, 0, 'asked once');

    const token = prisma._db.parentEmail[0].token;
    assert.equal((await fetch(`${url}/parent-email/confirm/${token}`)).status, 200);
    assert.deepEqual(await (await call('ath1', 'GET', '/parent-email')).json(), { email: 'parent@example.com', confirmed: true });

    const sunday = new Date('2026-10-04T17:00:00Z');
    const weekly = await dueParentEmails(prisma, sunday);
    assert.equal(weekly.length, 1);
    assert.equal(weekly[0].kind, 'weekly');
    assert.match(weekly[0].text, /Stop these emails: .*\/parent-email\/stop\//);
    await markParentEmailSent(prisma, 'weekly', 'ath1', sunday);
    assert.equal((await dueParentEmails(prisma, new Date('2026-10-04T20:00:00Z'))).length, 0, 'once a week');

    assert.equal((await fetch(`${url}/parent-email/stop/${token}`)).status, 200);
    assert.equal(prisma._db.parentEmail.length, 0, 'stopped means deleted');
  } finally {
    await close();
  }
});

test('teams: coach notes are private and a coach can send several', async () => {
  const prisma = fakePrisma();
  const { call, close } = await serve(prisma);
  try {
    const { team } = await (await call('coach', 'POST', '/teams', { name: 'Golf' })).json();
    await call('ath1', 'POST', '/teams/join', { code: team.code, nickname: 'Lee' });
    assert.equal((await call('ath1', 'POST', `/teams/${team.id}/shoutouts`, { memberId: 'ath1', text: 'Nice' })).status, 404, 'coach only');
    assert.equal((await call('coach', 'POST', `/teams/${team.id}/shoutouts`, { memberId: 'ath1', text: 'Great focus on the range today' })).status, 201);
    assert.equal((await call('coach', 'POST', `/teams/${team.id}/shoutouts`, { memberId: 'ath1', text: 'Strong finish in the last drill' })).status, 201, 'no weekly limit');
    assert.equal((await call('coach', 'POST', `/teams/${team.id}/shoutouts`, { memberId: 'stranger', text: 'Hi' })).status, 404);
    const mine = await (await call('ath1', 'GET', '/teams/shoutouts')).json();
    assert.deepEqual(mine.shoutouts.map((s) => s.text).sort(), ['Great focus on the range today', 'Strong finish in the last drill']);
    assert.deepEqual((await (await call('ath2', 'GET', '/teams/shoutouts')).json()).shoutouts, [], 'nobody else sees it');
  } finally {
    await close();
  }
});

test('training together: code, join, progress, nicknames only', async () => {
  const prisma = fakePrisma();
  const { call, close } = await serve(prisma);
  try {
    const items = [{ itemSlug: 'goblet-squat', sets: 3, reps: 8 }, { itemSlug: 'plank', sets: 2, seconds: 30 }];
    assert.equal((await call('a1', 'POST', '/partner', { title: 'Leg day', items: [], nickname: 'Sam' })).status, 400);
    const { code } = await (await call('a1', 'POST', '/partner', { title: 'Leg day', items, nickname: 'Sam' })).json();
    assert.match(code, /^[A-HJ-KM-NP-Z2-9]{6}$/);
    assert.equal((await call('a2', 'GET', `/partner/${code}`)).status, 404, 'join first');
    const joined = await (await call('a2', 'POST', `/partner/${code}/join`, { nickname: 'Ali' })).json();
    assert.equal(joined.title, 'Leg day');
    assert.equal(joined.items.length, 2);
    assert.equal((await call('a2', 'PUT', `/partner/${code}/progress`, { done: 1, total: 2, finished: false })).status, 204);
    const seen = await (await call('a1', 'GET', `/partner/${code}`)).json();
    assert.deepEqual(seen.people.map((p) => [p.nickname, p.done, p.isMe]).sort(), [['Ali', 1, false], ['Sam', 0, true]]);
    assert.equal((await call('a3', 'POST', '/partner/ZZZZZZ/join', { nickname: 'X1' })).status, 404);
  } finally {
    await close();
  }
});

const TOKEN_A = 'a'.repeat(64);
const TOKEN_B = 'b'.repeat(64);

async function until(check) {
  for (let i = 0; i < 100 && !check(); i += 1) await new Promise((r) => setTimeout(r, 10));
}

test('push: devices register per athlete; team events reach the right people, never with names', async () => {
  const prisma = fakePrisma();
  const sent = [];
  const apns = { async send(token, payload) { sent.push({ token, payload }); return { ok: true, status: 200 }; } };
  const { call, close } = await serve(prisma, { apns });
  try {
    assert.equal((await call('ath1', 'PUT', '/push/device', { token: 'nope' })).status, 400);
    assert.equal((await call('ath1', 'PUT', '/push/device', { token: TOKEN_A })).status, 204);
    assert.equal((await call('ath2', 'PUT', '/push/device', { token: TOKEN_B, muted: ['announcement', 'bogus'] })).status, 204);
    assert.deepEqual(prisma._db.pushDevice.find((d) => d.token === TOKEN_B).muted, ['announcement']);
    assert.equal((await call('coach', 'PUT', '/push/device', { token: 'c'.repeat(64) })).status, 204);
    assert.equal((await call('trainer', 'PUT', '/push/device', { token: 'd'.repeat(64) })).status, 204);

    const { team } = await (await call('coach', 'POST', '/teams', { name: 'Varsity Soccer' })).json();
    await call('ath1', 'POST', '/teams/join', { code: team.code, nickname: 'Sam' });
    await call('ath2', 'POST', '/teams/join', { code: team.code, nickname: 'Jo' });
    const { trainerCode } = await (await call('coach', 'POST', `/teams/${team.id}/trainer-code`)).json();
    await call('trainer', 'POST', '/teams/join-staff', { code: trainerCode });

    await call('coach', 'POST', `/teams/${team.id}/assignments`, { date: '2026-09-26', title: 'Recovery day', items: [{ itemSlug: 'worlds-greatest-stretch', sets: 2, seconds: 45 }] });
    await until(() => sent.length >= 2);
    assert.deepEqual(sent.map((s) => s.token).sort(), [TOKEN_A, TOKEN_B]);
    assert.equal(sent[0].payload.kind, 'assignment');
    assert.match(sent[0].payload.aps.alert.body, /Recovery day/);
    assert.equal(sent[0].payload.teamId, team.id);

    sent.length = 0;
    await call('coach', 'POST', `/teams/${team.id}/announcements`, { text: 'Bus leaves at 7' });
    await until(() => sent.length >= 1);
    await new Promise((r) => setTimeout(r, 30));
    assert.deepEqual(sent.map((s) => s.token), [TOKEN_A], 'ath2 muted announcements');

    sent.length = 0;
    await call('coach', 'POST', `/teams/${team.id}/shoutouts`, { memberId: 'ath1', text: 'Great effort' });
    await until(() => sent.length >= 1);
    assert.deepEqual(sent.map((s) => [s.token, s.payload.kind]), [[TOKEN_A, 'shoutout']]);
    assert.doesNotMatch(JSON.stringify(sent[0].payload), /Great effort/, 'a private note stays out of the lock screen');

    sent.length = 0;
    await call('ath1', 'PATCH', `/teams/${team.id}/membership`, { shareHealth: true });
    await call('ath1', 'POST', '/teams/health', { day: '2026-09-30', kind: 'pain', areas: ['knee'], level: 'some' });
    await until(() => sent.length >= 2);
    assert.deepEqual(sent.map((s) => s.token).sort(), ['c'.repeat(64), 'd'.repeat(64)]);
    assert.doesNotMatch(JSON.stringify(sent[0].payload), /Sam|knee/, 'no name or body part');
    await call('ath1', 'POST', '/teams/health', { day: '2026-09-30', kind: 'pain', areas: ['ankle'], level: 'some' });
    await new Promise((r) => setTimeout(r, 40));
    assert.equal(sent.length, 2, 'only the first pain note of the day pings staff');

    sent.length = 0;
    await call('trainer', 'POST', `/teams/${team.id}/rtp`, { memberId: 'ath1', step: 2 });
    await until(() => sent.length >= 1);
    assert.deepEqual(sent.map((s) => [s.token, s.payload.kind]), [[TOKEN_A, 'rtp']]);

    // A dead token is forgotten; signing out removes the phone.
    apns.send = async () => ({ ok: false, status: 410, reason: 'Unregistered' });
    await call('coach', 'POST', `/teams/${team.id}/announcements`, { text: 'Practice moved' });
    await until(() => !prisma._db.pushDevice.some((d) => d.token === TOKEN_A));
    assert.equal(prisma._db.pushDevice.some((d) => d.token === TOKEN_A), false);
    assert.equal((await call('ath2', 'DELETE', '/push/device', { token: TOKEN_B })).status, 204);
    assert.equal(prisma._db.pushDevice.some((d) => d.token === TOKEN_B), false);
  } finally {
    await close();
  }
});
