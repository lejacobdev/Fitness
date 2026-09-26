import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { signSessionToken } from '../src/lib/sessionToken.js';

const SESSION_SECRET = 'test-session-secret';

/** A tiny in-memory stand-in for the Prisma calls these routes make. */
function fakePrisma() {
  const db = { league: [], leagueMember: [], weeklyXP: [], team: [], teamMember: [], assignment: [], parentLink: [], checkIn: [], session: [], syncedState: [], sharedWorkout: [] };

  const matches = (row, where = {}) => Object.entries(where).every(([field, cond]) => {
    if (cond && typeof cond === 'object' && !(cond instanceof Date)) {
      if ('in' in cond) return cond.in.includes(row[field]);
      if ('gte' in cond || 'lt' in cond) {
        return (cond.gte === undefined || row[field] >= cond.gte) && (cond.lt === undefined || row[field] < cond.lt);
      }
      // A compound key: { leagueId_athleteId: { leagueId, athleteId } }.
      return Object.entries(cond).every(([k, v]) => row[k] === v);
    }
    return row[field] === cond;
  });

  const relations = {
    league: { members: ['leagueMember', 'leagueId'] },
    team: { members: ['teamMember', 'teamId'] },
    leagueMember: { league: ['league', 'leagueId', true] },
    teamMember: { team: ['team', 'teamId', true] },
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
      const [target, fk, toOne] = relations[model][name];
      out[name] = toOne
        ? withIncludes(target, db[target].find((r) => r.id === row[fk]), spec === true ? undefined : spec.include)
        : db[target].filter((r) => r[fk] === row.id).map((r) => withIncludes(target, r, spec === true ? undefined : spec.include));
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
        }
        return row;
      },
      async deleteMany({ where }) { db[model] = db[model].filter((r) => !matches(r, where)); return {}; },
    };
  }
  client._db = db;
  return client;
}

async function serve(prisma) {
  const app = createApp({ prisma, sessionSecret: SESSION_SECRET });
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
