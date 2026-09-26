import assert from 'node:assert/strict';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { isObjectionable } from '../src/lib/moderation.js';
import { signSessionToken } from '../src/lib/sessionToken.js';

const SESSION_SECRET = 'test-session-secret';

function fakePrisma() {
  const db = { report: [], supportMessage: [], sharedWorkout: [], team: [], league: [] };
  const matches = (row, where = {}) => Object.entries(where).every(([k, v]) => row[k] === v);
  const client = { _db: db };
  for (const model of Object.keys(db)) {
    client[model] = {
      async findUnique({ where }) { return db[model].find((r) => matches(r, where)) ?? null; },
      async findMany({ where } = {}) { return db[model].filter((r) => matches(r, where)); },
      async count({ where } = {}) { return db[model].filter((r) => matches(r, where)).length; },
      async create({ data }) { const row = { createdAt: new Date(), ...data }; db[model].push(row); return row; },
      async deleteMany({ where }) {
        const before = db[model].length;
        db[model] = db[model].filter((r) => !matches(r, where));
        return { count: before - db[model].length };
      },
    };
  }
  return client;
}

async function serve(prisma) {
  const app = createApp({ prisma, sessionSecret: SESSION_SECRET });
  const server = await new Promise((resolve) => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
  const url = `http://127.0.0.1:${server.address().port}`;
  const call = (athleteId, method, path, body) => fetch(`${url}${path}`, {
    method,
    headers: {
      ...(athleteId ? { authorization: `Bearer ${signSessionToken(athleteId, { secret: SESSION_SECRET })}` } : {}),
      'content-type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { url, call, close: () => new Promise((r) => server.close(r)) };
}

test('the name filter blocks insults, even disguised, and lets ordinary names through', () => {
  for (const bad of ['fuck', 'F.U.C.K', 'Sh1t happens', 'xXfuckXx', 'n a z i', 'Hurensohn FC', 'shiiiit']) {
    assert.equal(isObjectionable(bad), true, bad);
  }
  for (const ok of ['Varsity Soccer', 'Scunthorpe United', 'Dickson', 'Marsch 5x', 'Suicide sprints x6', 'Essex Eagles', 'Class of 2026', 'Mia']) {
    assert.equal(isObjectionable(ok), false, ok);
  }
});

test('objectionable names are refused where other people would see them', async () => {
  const prisma = fakePrisma();
  const { call, close } = await serve(prisma);
  try {
    const workout = await call('a1', 'POST', '/workouts/shared', {
      title: 'Sh1t day', items: [{ itemSlug: 'push-up', dose: { kind: 'reps', sets: 3, reps: 10 }, restSec: 60 }],
    });
    assert.equal(workout.status, 400);
    assert.equal(prisma._db.sharedWorkout.length, 0);
  } finally {
    await close();
  }
});

test('reports are stored; a workout three people report stops being shared', async () => {
  const prisma = fakePrisma();
  prisma._db.sharedWorkout.push({ code: 'ABC234', ownerId: 'x', title: 'Leg day', items: [] });
  const { call, close } = await serve(prisma);
  try {
    assert.equal((await call(null, 'POST', '/reports', { kind: 'workout', target: 'ABC234' })).status, 201, 'guests can report too');
    await call(null, 'POST', '/reports', { kind: 'workout', target: 'ABC234' });
    await call(null, 'POST', '/reports', { kind: 'workout', target: 'ABC234' });
    assert.equal(prisma._db.sharedWorkout.length, 1, "anonymous reports don't take a workout down on their own");
    assert.equal((await call('a1', 'POST', '/reports', { kind: 'nonsense', target: 'ABC234' })).status, 400);
    assert.equal((await call('a1', 'POST', '/reports', { kind: 'workout', target: 'ABC234', reason: 'rude' })).status, 201);
    assert.equal((await call('a1', 'POST', '/reports', { kind: 'workout', target: 'ABC234' })).status, 201);
    assert.equal(prisma._db.sharedWorkout.length, 1, 'one person reporting twice is still one person');
    await call('a2', 'POST', '/reports', { kind: 'workout', target: 'ABC234' });
    await call('a3', 'POST', '/reports', { kind: 'workout', target: 'ABC234' });
    assert.equal(prisma._db.sharedWorkout.length, 0, 'three people: no longer shared');
    assert.equal((await call('a1', 'POST', '/reports', { kind: 'leagueMember', target: 'league-1:Mia' })).status, 201);
    assert.equal(prisma._db.report.length, 8);
  } finally {
    await close();
  }
});

test('the support page form stores the message and says thanks', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(prisma);
  try {
    const res = await fetch(`${url}/support/messages`, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ email: 'coach@example.com', message: 'How do I add my team calendar?' }),
    });
    assert.equal(res.status, 201);
    assert.match(await res.text(), /Thanks/);
    assert.deepEqual(prisma._db.supportMessage.map((m) => [m.email, m.message]), [['coach@example.com', 'How do I add my team calendar?']]);
    const empty = await fetch(`${url}/support/messages`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{"message":""}' });
    assert.equal(empty.status, 400);
  } finally {
    await close();
  }
});
