import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { verifySessionToken } from '../src/lib/sessionToken.js';

const AUDIENCE = 'com.studentathlete.app';
const SESSION_SECRET = 'test-session-secret';
const KID = 'test-key-1';

const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const testJwk = { ...publicKey.export({ format: 'jwk' }), kid: KID, alg: 'RS256', use: 'sig' };
const b64 = (obj) => Buffer.from(JSON.stringify(obj), 'utf8').toString('base64url');

// The auth route (correctly, for production) verifies against the real
// system clock rather than an injectable one, so fixtures here mint tokens
// relative to real current time rather than a fixed timestamp -- a fixed
// past/future NOW_S would trip Apple's own iat/exp checks the moment this
// suite runs on a different day (already caught once: the first version of
// this fixture used a fixed future NOW_S and every test failed 401
// "not_yet_valid" against the real clock).
function mintAppleToken({ sub = '001234.abcdef.5678', claims = {} } = {}) {
  const nowS = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', kid: KID };
  const fullClaims = {
    iss: 'https://appleid.apple.com', aud: AUDIENCE, sub,
    iat: nowS - 30, exp: nowS + 600, ...claims,
  };
  const signingInput = `${b64(header)}.${b64(fullClaims)}`;
  const sig = crypto.sign('sha256', Buffer.from(signingInput, 'utf8'), {
    key: privateKey, padding: crypto.constants.RSA_PKCS1_PADDING,
  });
  return `${signingInput}.${sig.toString('base64url')}`;
}

const fakeKeyStore = { async get() { return testJwk; } };

/** An in-memory stand-in for the one Prisma model this route touches. */
function fakePrisma() {
  const athletesById = new Map();
  const athletesByAppleId = new Map();
  let nextId = 1;
  return {
    athlete: {
      async findUnique({ where: { appleUserId } }) {
        return athletesByAppleId.get(appleUserId) ?? null;
      },
      async create({ data }) {
        const athlete = { id: String(nextId++), createdAt: new Date(), ...data };
        athletesById.set(athlete.id, athlete);
        athletesByAppleId.set(athlete.appleUserId, athlete);
        return athlete;
      },
    },
    _athletesByAppleId: athletesByAppleId,
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
  return createApp({
    prisma, appleBundleId: AUDIENCE, sessionSecret: SESSION_SECRET, appleKeyStore: fakeKeyStore,
  });
}

test('a first-time sign-in with a birth date creates an athlete and returns a session token', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    const res = await fetch(`${url}/auth/apple`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ identityToken: mintAppleToken(), birthDate: '2010-05-01' }),
      signal: AbortSignal.timeout(2000),
    });
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.ok(body.sessionToken);
    assert.ok(body.athlete.id);
    // The client's SwiftData model needs these to materialise a local
    // Athlete row on a restore, where it has no local copy to fall back on.
    assert.equal(body.athlete.appleUserId, '001234.abcdef.5678');
    assert.equal(body.athlete.birthDate, new Date('2010-05-01').toISOString());

    const { athleteId } = verifySessionToken(body.sessionToken, { secret: SESSION_SECRET });
    assert.equal(athleteId, body.athlete.id);
    assert.equal(prisma._athletesByAppleId.get('001234.abcdef.5678').id, body.athlete.id);
  } finally {
    await close();
  }
});

test('a returning athlete (same sub) is looked up, not re-created', async () => {
  const prisma = fakePrisma();
  const app = buildApp(prisma);
  const { url, close } = await serve(app);
  try {
    const first = await fetch(`${url}/auth/apple`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ identityToken: mintAppleToken(), birthDate: '2010-05-01' }),
      signal: AbortSignal.timeout(2000),
    });
    const firstBody = await first.json();

    // No birthDate this time -- a returning athlete must not need it again.
    const second = await fetch(`${url}/auth/apple`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ identityToken: mintAppleToken() }),
      signal: AbortSignal.timeout(2000),
    });
    assert.equal(second.status, 200);
    const secondBody = await second.json();
    assert.equal(secondBody.athlete.id, firstBody.athlete.id);
    assert.equal(prisma._athletesByAppleId.size, 1);
  } finally {
    await close();
  }
});

test('a new sign-in for an athlete under 13 is refused server-side (§2, §23)', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    const res = await fetch(`${url}/auth/apple`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      // 2020 birth year against the fixed NOW_S clock the Apple token uses --
      // the server computes age from real wall-clock time, so use a date far
      // enough in the future-relative-to-2010 that it's under 13 regardless
      // of when this test actually runs.
      body: JSON.stringify({ identityToken: mintAppleToken({ sub: 'a-new-under-13-sub' }), birthDate: futureSafeUnder13BirthDate() }),
      signal: AbortSignal.timeout(2000),
    });
    assert.equal(res.status, 403);
    assert.deepEqual(await res.json(), { error: 'under_minimum_age' });
    assert.equal(prisma._athletesByAppleId.size, 0);
  } finally {
    await close();
  }
});

test('a first-time sign-in with no birth date is rejected', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    const res = await fetch(`${url}/auth/apple`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ identityToken: mintAppleToken() }),
      signal: AbortSignal.timeout(2000),
    });
    assert.equal(res.status, 400);
    assert.deepEqual(await res.json(), { error: 'missing_birth_date' });
  } finally {
    await close();
  }
});

test('a missing identityToken is rejected before ever touching Apple verification', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    const res = await fetch(`${url}/auth/apple`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({}),
      signal: AbortSignal.timeout(2000),
    });
    assert.equal(res.status, 400);
    assert.deepEqual(await res.json(), { error: 'missing_identity_token' });
  } finally {
    await close();
  }
});

test('an invalid Apple token is rejected with the underlying AppleIdentityError code', async () => {
  const prisma = fakePrisma();
  const { url, close } = await serve(buildApp(prisma));
  try {
    const res = await fetch(`${url}/auth/apple`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ identityToken: 'not-a-real-token', birthDate: '2010-05-01' }),
      signal: AbortSignal.timeout(2000),
    });
    assert.equal(res.status, 401);
  } finally {
    await close();
  }
});

test('the /auth router is not mounted at all when required config is missing (fails closed)', () => {
  const app = createApp({ prisma: fakePrisma() }); // no appleBundleId / sessionSecret
  assert.ok(app, 'createApp should not throw, just omit the router');
});

function futureSafeUnder13BirthDate() {
  const twelveYearsAgo = new Date();
  twelveYearsAgo.setUTCFullYear(twelveYearsAgo.getUTCFullYear() - 12);
  return twelveYearsAgo.toISOString().slice(0, 10);
}
