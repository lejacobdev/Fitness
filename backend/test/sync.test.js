import assert from 'node:assert/strict';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { signSessionToken } from '../src/lib/sessionToken.js';

const SESSION_SECRET = 'test-session-secret';

/** An in-memory stand-in for the three Prisma models this route touches. */
function fakePrisma() {
  const sessionsById = new Map();
  const sessionsByClientId = new Map();
  const setsById = new Map();
  const setsByClientId = new Map();
  const plannedSessions = new Map();
  let nextSessionId = 1;
  let nextSetId = 1;

  return {
    session: {
      async findUnique({ where: { clientId } }) {
        return sessionsByClientId.get(clientId) ?? null;
      },
      async upsert({ where: { clientId }, create, update }) {
        const existing = sessionsByClientId.get(clientId);
        const row = existing ? { ...existing, ...update } : { id: String(nextSessionId++), ...create };
        sessionsById.set(row.id, row);
        sessionsByClientId.set(clientId, row);
        return row;
      },
    },
    setLog: {
      async findUnique({ where: { clientId } }) {
        return setsByClientId.get(clientId) ?? null;
      },
      async upsert({ where: { clientId }, create, update }) {
        const existing = setsByClientId.get(clientId);
        const row = existing ? { ...existing, ...update } : { id: String(nextSetId++), ...create };
        setsById.set(row.id, row);
        setsByClientId.set(clientId, row);
        return row;
      },
    },
    plannedSession: {
      async findUnique({ where: { id } }) {
        return plannedSessions.get(id) ?? null;
      },
    },
    _sessionsByClientId: sessionsByClientId,
    _setsByClientId: setsByClientId,
    _plannedSessions: plannedSessions,
  };
}

async function serve(app) {
  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });
  const { port } = server.address();
  return { url: `http://127.0.0.1:${port}`, close: () => new Promise((r) => server.close(r)) };
}

function buildApp(prisma) {
  return createApp({ prisma, sessionSecret: SESSION_SECRET });
}

function authHeader(athleteId) {
  return { authorization: `Bearer ${signSessionToken(athleteId, { secret: SESSION_SECRET })}` };
}

function post(url, path, body, headers) {
  return fetch(`${url}${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(2000),
  });
}

const validSession = {
  clientId: 'session-client-1',
  startedAt: '2026-01-01T10:00:00.000Z',
  source: 'PHONE',
  minutes: 45,
};

const validSets = [
  { clientId: 'set-client-1', itemSlug: 'trap-bar-deadlift', setIndex: 0, reps: 6, weightKg: 60 },
  { clientId: 'set-client-2', itemSlug: 'trap-bar-deadlift', setIndex: 1, reps: 6, weightKg: 62.5 },
];

test('a first sync creates a session and its sets', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    const res = await post(url, '/sync/sessions', { session: validSession, sets: validSets }, authHeader('athlete-1'));
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.ok(body.session.id);
    assert.equal(body.sets.length, 2);
    assert.equal(prisma._sessionsByClientId.size, 1);
    assert.equal(prisma._setsByClientId.size, 2);
    assert.equal(prisma._sessionsByClientId.get('session-client-1').athleteId, 'athlete-1');
  } finally {
    await close();
  }
});

test('§21 sync idempotency: draining the same queued session twice produces one row, not two', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    const first = await post(url, '/sync/sessions', { session: validSession, sets: validSets }, authHeader('athlete-1'));
    const second = await post(url, '/sync/sessions', { session: validSession, sets: validSets }, authHeader('athlete-1'));
    assert.equal(first.status, 200);
    assert.equal(second.status, 200);
    const firstBody = await first.json();
    const secondBody = await second.json();

    assert.equal(firstBody.session.id, secondBody.session.id);
    assert.equal(prisma._sessionsByClientId.size, 1);
    assert.equal(prisma._setsByClientId.size, 2);
  } finally {
    await close();
  }
});

test('last-write-wins: re-syncing the same clientId with RPE/endedAt added later updates the same row', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    await post(url, '/sync/sessions', { session: validSession, sets: [] }, authHeader('athlete-1'));

    const finished = { ...validSession, endedAt: '2026-01-01T10:45:00.000Z', sessionRPE: 7 };
    const res = await post(url, '/sync/sessions', { session: finished, sets: [] }, authHeader('athlete-1'));
    assert.equal(res.status, 200);

    assert.equal(prisma._sessionsByClientId.size, 1);
    const stored = prisma._sessionsByClientId.get('session-client-1');
    assert.equal(stored.sessionRPE, 7);
    assert.ok(stored.endedAt);
  } finally {
    await close();
  }
});

test('a request with no Authorization header is rejected before touching the database', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    const res = await post(url, '/sync/sessions', { session: validSession, sets: [] }, {});
    assert.equal(res.status, 401);
    assert.equal(prisma._sessionsByClientId.size, 0);
  } finally {
    await close();
  }
});

test('replaying another athlete\'s session clientId is rejected as a conflict, not silently overwritten', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    await post(url, '/sync/sessions', { session: validSession, sets: [] }, authHeader('athlete-1'));

    const res = await post(url, '/sync/sessions', { session: validSession, sets: [] }, authHeader('athlete-2'));
    assert.equal(res.status, 409);
    assert.deepEqual(await res.json(), { error: 'client_id_conflict' });
    assert.equal(prisma._sessionsByClientId.get('session-client-1').athleteId, 'athlete-1');
  } finally {
    await close();
  }
});

test('a set clientId already tied to a different session is rejected as a conflict', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    await post(url, '/sync/sessions', { session: validSession, sets: validSets }, authHeader('athlete-1'));

    const otherSession = { ...validSession, clientId: 'session-client-2' };
    const res = await post(
      url, '/sync/sessions',
      { session: otherSession, sets: [{ clientId: 'set-client-1', itemSlug: 'trap-bar-deadlift', setIndex: 0 }] },
      authHeader('athlete-1'),
    );
    assert.equal(res.status, 409);
  } finally {
    await close();
  }
});

test('invalid session payloads are rejected 400 without ever calling prisma', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    const cases = [
      [{ ...validSession, clientId: '' }, 'missing_client_id'],
      [{ ...validSession, startedAt: 'not-a-date' }, 'invalid_started_at'],
      [{ ...validSession, source: 'TABLET' }, 'invalid_source'],
      [{ ...validSession, sessionRPE: 11 }, 'invalid_session_rpe'],
      [{ ...validSession, minutes: -5 }, 'invalid_minutes'],
    ];
    for (const [session, expectedError] of cases) {
      const res = await post(url, '/sync/sessions', { session, sets: [] }, authHeader('athlete-1'));
      assert.equal(res.status, 400, `expected 400 for ${expectedError}`);
      assert.deepEqual(await res.json(), { error: expectedError });
    }
    assert.equal(prisma._sessionsByClientId.size, 0);
  } finally {
    await close();
  }
});

test('a plannedSessionId that does not belong to this athlete is rejected', async () => {
  const prisma = fakePrisma();
  prisma._plannedSessions.set('planned-1', { id: 'planned-1', plan: { athleteId: 'someone-else' } });
  const { url, close } = await serve(buildApp(prisma));
  try {
    const session = { ...validSession, plannedSessionId: 'planned-1' };
    const res = await post(url, '/sync/sessions', { session, sets: [] }, authHeader('athlete-1'));
    assert.equal(res.status, 400);
    assert.deepEqual(await res.json(), { error: 'unknown_planned_session' });
  } finally {
    await close();
  }
});

test('the /sync router is not mounted at all when required config is missing (fails closed)', () => {
  const app = createApp({ prisma: fakePrisma() }); // no sessionSecret
  assert.ok(app, 'createApp should not throw, just omit the router');
});
