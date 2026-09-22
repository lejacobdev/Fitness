import assert from 'node:assert/strict';
import test from 'node:test';

import { SessionTokenError, signSessionToken, verifySessionToken } from '../src/lib/sessionToken.js';

const SECRET = 'test-secret-do-not-use-in-prod';
const NOW_S = 1_800_000_000;

test('a token signed and verified with the same secret round-trips the athlete id', () => {
  const token = signSessionToken('athlete-123', { secret: SECRET, now: () => NOW_S });
  const { athleteId } = verifySessionToken(token, { secret: SECRET, now: () => NOW_S });
  assert.equal(athleteId, 'athlete-123');
});

test('a token verified with a different secret is rejected', () => {
  const token = signSessionToken('athlete-123', { secret: SECRET, now: () => NOW_S });
  assert.throws(
    () => verifySessionToken(token, { secret: 'wrong-secret', now: () => NOW_S }),
    (err) => err instanceof SessionTokenError && err.code === 'bad_signature',
  );
});

test('an expired token is rejected', () => {
  const token = signSessionToken('athlete-123', { secret: SECRET, now: () => NOW_S, ttlSeconds: 10 });
  assert.throws(
    () => verifySessionToken(token, { secret: SECRET, now: () => NOW_S + 11 }),
    (err) => err instanceof SessionTokenError && err.code === 'expired',
  );
});

test('a token still within its ttl is accepted right up to the boundary', () => {
  const token = signSessionToken('athlete-123', { secret: SECRET, now: () => NOW_S, ttlSeconds: 10 });
  const { athleteId } = verifySessionToken(token, { secret: SECRET, now: () => NOW_S + 9 });
  assert.equal(athleteId, 'athlete-123');
});

test('rotating SESSION_SECRET invalidates every previously issued token', () => {
  // §18's stated intent: rotating the secret should sign everyone out.
  const token = signSessionToken('athlete-123', { secret: 'old-secret', now: () => NOW_S });
  assert.throws(() => verifySessionToken(token, { secret: 'new-secret', now: () => NOW_S }));
});

test('a tampered payload is rejected even if the signature format still parses', () => {
  const token = signSessionToken('athlete-123', { secret: SECRET, now: () => NOW_S });
  const [, signature] = token.split('.');
  const forgedPayload = Buffer.from(JSON.stringify({ sub: 'someone-elses-id', iat: NOW_S, exp: NOW_S + 999 }), 'utf8').toString('base64url');
  const forged = `${forgedPayload}.${signature}`;
  assert.throws(
    () => verifySessionToken(forged, { secret: SECRET, now: () => NOW_S }),
    (err) => err instanceof SessionTokenError && err.code === 'bad_signature',
  );
});

test('malformed input is rejected rather than throwing something unhandled', () => {
  for (const bad of ['', 'no-dot-here', '...', 'a.b.c']) {
    assert.throws(() => verifySessionToken(bad, { secret: SECRET, now: () => NOW_S }));
  }
});

test('signSessionToken and verifySessionToken both require a secret', () => {
  assert.throws(() => signSessionToken('athlete-123', { now: () => NOW_S }));
  const token = signSessionToken('athlete-123', { secret: SECRET, now: () => NOW_S });
  assert.throws(() => verifySessionToken(token, { now: () => NOW_S }));
});
