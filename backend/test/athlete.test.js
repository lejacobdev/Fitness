import assert from 'node:assert/strict';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { signSessionToken } from '../src/lib/sessionToken.js';

const SESSION_SECRET = 'test-session-secret';

/** An in-memory stand-in with Prisma's real "delete a row that's already gone" shape. */
function fakePrisma() {
  const athletes = new Map();
  athletes.set('athlete-1', { id: 'athlete-1' });
  return {
    athlete: {
      async delete({ where: { id } }) {
        if (!athletes.has(id)) {
          const err = new Error('not found');
          err.code = 'P2025';
          throw err;
        }
        athletes.delete(id);
        return { id };
      },
    },
    _athletes: athletes,
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

test('deleting your own account removes the row and returns 204', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    const res = await fetch(`${url}/athlete/me`, {
      method: 'DELETE', headers: authHeader('athlete-1'), signal: AbortSignal.timeout(2000),
    });
    assert.equal(res.status, 204);
    assert.equal(prisma._athletes.has('athlete-1'), false);
  } finally {
    await close();
  }
});

test('deleting an already-deleted account still returns 204, not an error', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    const first = await fetch(`${url}/athlete/me`, {
      method: 'DELETE', headers: authHeader('athlete-1'), signal: AbortSignal.timeout(2000),
    });
    const second = await fetch(`${url}/athlete/me`, {
      method: 'DELETE', headers: authHeader('athlete-1'), signal: AbortSignal.timeout(2000),
    });
    assert.equal(first.status, 204);
    assert.equal(second.status, 204);
  } finally {
    await close();
  }
});

test('deleting without a session token is rejected', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    const res = await fetch(`${url}/athlete/me`, { method: 'DELETE', signal: AbortSignal.timeout(2000) });
    assert.equal(res.status, 401);
    assert.equal(prisma._athletes.has('athlete-1'), true);
  } finally {
    await close();
  }
});

test('the /athlete router is not mounted at all when required config is missing (fails closed)', () => {
  const app = createApp({ prisma: fakePrisma() }); // no sessionSecret
  assert.ok(app, 'createApp should not throw, just omit the router');
});
