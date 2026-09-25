import assert from 'node:assert/strict';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { signSessionToken } from '../src/lib/sessionToken.js';

const SESSION_SECRET = 'test-session-secret';

function fakePrisma() {
  const states = new Map(); // `${athleteId}|${key}` → row
  const athletes = new Map([['athlete-1', { id: 'athlete-1', appleRefreshToken: 'refresh-1' }]]);
  return {
    syncedState: {
      async findMany({ where: { athleteId } }) {
        return [...states.values()].filter((r) => r.athleteId === athleteId);
      },
      async findUnique({ where: { athleteId_key: { athleteId, key } } }) {
        return states.get(`${athleteId}|${key}`) ?? null;
      },
      async upsert({ where: { athleteId_key: { athleteId, key } }, create, update }) {
        const id = `${athleteId}|${key}`;
        const row = states.has(id) ? { ...states.get(id), ...update } : { ...create };
        states.set(id, row);
        return row;
      },
    },
    checkIn: {
      async findMany({ where: { athleteId, date } }) {
        if (date?.gte && date.gte > new Date('2026-09-20T00:00:00Z')) return [];
        return athleteId === 'athlete-1'
          ? [{ clientId: 'c1', date: new Date('2026-09-20T00:00:00Z'), sleepQuality: 4, sleepHours: 8.5, soreness: 2, sorenessAreas: [], energy: 4, stress: 2, readinessBand: 'GREEN', readinessZ: 0.4 }]
          : [];
      },
    },
    session: {
      async findMany({ where: { athleteId } }) {
        return athleteId === 'athlete-1'
          ? [{ clientId: 's1', startedAt: new Date('2026-09-20T16:00:00Z'), endedAt: null, sessionRPE: 7, minutes: 45, source: 'PHONE', healthKitWorkoutId: null, notes: null,
            sets: [{ clientId: 'x1', itemSlug: 'split-squat', setIndex: 0, reps: 8, weightKg: null, seconds: null, distanceM: null, contacts: null, side: null }] }]
          : [];
      },
    },
    athlete: {
      async findUnique({ where: { id } }) { return athletes.get(id) ?? null; },
      async delete({ where: { id } }) {
        if (!athletes.has(id)) { const e = new Error('gone'); e.code = 'P2025'; throw e; }
        athletes.delete(id);
        return { id };
      },
    },
    _states: states,
    _athletes: athletes,
  };
}

async function serve(app) {
  const server = await new Promise((resolve) => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
  const { port } = server.address();
  return { url: `http://127.0.0.1:${port}`, close: () => new Promise((r) => server.close(r)) };
}

const auth = (id) => ({ authorization: `Bearer ${signSessionToken(id, { secret: SESSION_SECRET })}`, 'content-type': 'application/json' });

test('state: newer writes win, older ones get the server copy back', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(createApp({ prisma, sessionSecret: SESSION_SECRET }));
  try {
    const put = (body) => fetch(`${url}/sync/state`, { method: 'PUT', headers: auth('athlete-1'), body: JSON.stringify(body) }).then((r) => r.json());
    let res = await put({ states: { campus: { value: { xp: 30 }, updatedAt: '2026-09-25T10:00:00.000Z' } } });
    assert.deepEqual(res.states.campus.value, { xp: 30 });
    // An older copy from another phone does not overwrite it…
    res = await put({ states: { campus: { value: { xp: 5 }, updatedAt: '2026-09-24T10:00:00.000Z' } } });
    assert.deepEqual(res.states.campus.value, { xp: 30 }, 'the stale write lost and got the winner back');
    // …a newer one does.
    res = await put({ states: { campus: { value: { xp: 45 }, updatedAt: '2026-09-25T11:00:00.000Z' } } });
    assert.deepEqual(res.states.campus.value, { xp: 45 });
    const all = await fetch(`${url}/sync/state`, { headers: auth('athlete-1') }).then((r) => r.json());
    assert.deepEqual(all.states.campus.value, { xp: 45 });
    // Another athlete sees nothing of it.
    const other = await fetch(`${url}/sync/state`, { headers: auth('athlete-2') }).then((r) => r.json());
    assert.deepEqual(other.states, {});
  } finally {
    await close();
  }
});

test('state: bad keys, missing timestamps and anonymous requests are refused', async () => {
  const { url, close } = await serve(createApp({ prisma: fakePrisma(), sessionSecret: SESSION_SECRET }));
  try {
    const put = (body, headers = auth('athlete-1')) => fetch(`${url}/sync/state`, { method: 'PUT', headers, body: JSON.stringify(body) });
    assert.equal((await put({ states: { 'Bad Key!': { value: 1, updatedAt: '2026-09-25T10:00:00Z' } } })).status, 400);
    assert.equal((await put({ states: { campus: { value: 1 } } })).status, 400);
    assert.equal((await put({})).status, 400);
    assert.equal((await put({ states: { campus: { value: 1, updatedAt: '2026-09-25T10:00:00Z' } } }, { 'content-type': 'application/json' })).status, 401);
  } finally {
    await close();
  }
});

test('restore: check-ins and sessions with their sets come back for the owner', async () => {
  const { url, close } = await serve(createApp({ prisma: fakePrisma(), sessionSecret: SESSION_SECRET }));
  try {
    const checkIns = await fetch(`${url}/sync/checkins`, { headers: auth('athlete-1') }).then((r) => r.json());
    assert.equal(checkIns.checkIns[0].date, '2026-09-20');
    assert.equal(checkIns.checkIns[0].sleepHours, 8.5);
    const sessions = await fetch(`${url}/sync/sessions`, { headers: auth('athlete-1') }).then((r) => r.json());
    assert.equal(sessions.sessions[0].sets[0].itemSlug, 'split-squat');
    const recent = await fetch(`${url}/sync/checkins?since=2026-09-22`, { headers: auth('athlete-1') }).then((r) => r.json());
    assert.deepEqual(recent.checkIns, [], 'only check-ins on or after ?since=');
  } finally {
    await close();
  }
});

test('account deletion revokes Sign in with Apple first, then deletes', async () => {
  const prisma = fakePrisma();
  const revoked = [];
  const appleRevoker = { async revoke(token) { revoked.push(token); return true; }, async refreshTokenFor() { return null; } };
  const { url, close } = await serve(createApp({ prisma, sessionSecret: SESSION_SECRET, appleRevoker }));
  try {
    const res = await fetch(`${url}/athlete/me`, { method: 'DELETE', headers: auth('athlete-1') });
    assert.equal(res.status, 204);
    assert.deepEqual(revoked, ['refresh-1']);
    assert.equal(prisma._athletes.has('athlete-1'), false);
  } finally {
    await close();
  }
});
