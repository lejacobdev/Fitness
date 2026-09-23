import assert from 'node:assert/strict';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { signSessionToken } from '../src/lib/sessionToken.js';

const SESSION_SECRET = 'test-session-secret';

/** In-memory CheckIn table honouring both unique constraints §14 declares. */
function fakePrisma() {
  const rows = [];
  let nextId = 1;
  const key = (athleteId, date) => `${athleteId}|${date.toISOString()}`;
  return {
    checkIn: {
      async findUnique({ where }) {
        if (where.clientId) return rows.find((r) => r.clientId === where.clientId) ?? null;
        const { athleteId, date } = where.athleteId_date;
        return rows.find((r) => key(r.athleteId, r.date) === key(athleteId, date)) ?? null;
      },
      async upsert({ where, create, update }) {
        const { athleteId, date } = where.athleteId_date;
        const existing = rows.find((r) => key(r.athleteId, r.date) === key(athleteId, date));
        if (existing) {
          Object.assign(existing, update);
          return existing;
        }
        if (rows.some((r) => r.clientId === create.clientId)) throw new Error('unique violation on clientId');
        const row = { id: String(nextId++), ...create };
        rows.push(row);
        return row;
      },
    },
    _rows: rows,
  };
}

async function serve(app) {
  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });
  const { port } = server.address();
  return { url: `http://127.0.0.1:${port}`, close: () => new Promise((r) => server.close(r)) };
}

function auth(athleteId) {
  return { authorization: `Bearer ${signSessionToken(athleteId, { secret: SESSION_SECRET })}` };
}

function post(url, body, headers) {
  return fetch(`${url}/sync/checkins`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(2000),
  });
}

const valid = {
  clientId: 'ci-1', date: '2026-09-23', sleepQuality: 4, soreness: 2, energy: 4, stress: 2,
  sorenessAreas: ['legs'], readinessBand: 'GREEN', readinessZ: 0.4,
};

test('a check-in is stored for the day', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(createApp({ prisma, sessionSecret: SESSION_SECRET }));
  try {
    const res = await post(url, { checkIn: valid }, auth('athlete-1'));
    assert.equal(res.status, 200);
    assert.equal(prisma._rows.length, 1);
    assert.equal(prisma._rows[0].athleteId, 'athlete-1');
    assert.equal(prisma._rows[0].date.toISOString(), '2026-09-23T00:00:00.000Z');
    assert.deepEqual(prisma._rows[0].sorenessAreas, ['legs']);
  } finally {
    await close();
  }
});

test('re-sending (retry) and editing the same day update one row, never two (§14)', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(createApp({ prisma, sessionSecret: SESSION_SECRET }));
  try {
    await post(url, { checkIn: valid }, auth('athlete-1'));
    await post(url, { checkIn: valid }, auth('athlete-1'));
    const edited = await post(url, { checkIn: { ...valid, sleepQuality: 1 } }, auth('athlete-1'));
    assert.equal(edited.status, 200);
    assert.equal(prisma._rows.length, 1);
    assert.equal(prisma._rows[0].sleepQuality, 1);
  } finally {
    await close();
  }
});

test('different days are different rows', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(createApp({ prisma, sessionSecret: SESSION_SECRET }));
  try {
    await post(url, { checkIn: valid }, auth('athlete-1'));
    await post(url, { checkIn: { ...valid, clientId: 'ci-2', date: '2026-09-24' } }, auth('athlete-1'));
    assert.equal(prisma._rows.length, 2);
  } finally {
    await close();
  }
});

test("another athlete's clientId is rejected 409", async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(createApp({ prisma, sessionSecret: SESSION_SECRET }));
  try {
    await post(url, { checkIn: valid }, auth('athlete-1'));
    const res = await post(url, { checkIn: valid }, auth('athlete-2'));
    assert.equal(res.status, 409);
    assert.deepEqual(await res.json(), { error: 'client_id_conflict' });
  } finally {
    await close();
  }
});

test('invalid check-ins are rejected 400', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(createApp({ prisma, sessionSecret: SESSION_SECRET }));
  try {
    const cases = [
      [{ ...valid, clientId: '' }, 'missing_client_id'],
      [{ ...valid, date: '23/09/2026' }, 'invalid_date'],
      [{ ...valid, sleepQuality: 6 }, 'invalid_sleepQuality'],
      [{ ...valid, stress: 0 }, 'invalid_stress'],
      [{ ...valid, sleepHours: 30 }, 'invalid_sleep_hours'],
      [{ ...valid, readinessBand: 'BLUE' }, 'invalid_readiness_band'],
    ];
    for (const [checkIn, expected] of cases) {
      const res = await post(url, { checkIn }, auth('athlete-1'));
      assert.equal(res.status, 400, expected);
      assert.deepEqual(await res.json(), { error: expected });
    }
    assert.equal(prisma._rows.length, 0);
  } finally {
    await close();
  }
});

test('unauthenticated check-ins are rejected', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(createApp({ prisma, sessionSecret: SESSION_SECRET }));
  try {
    const res = await post(url, { checkIn: valid }, {});
    assert.equal(res.status, 401);
  } finally {
    await close();
  }
});
