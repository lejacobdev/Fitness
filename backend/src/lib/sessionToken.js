import crypto from 'node:crypto';

/**
 * Our own session tokens — not Apple's. §18: "Rotate by replacing
 * [SESSION_SECRET]; every client then signs in again, which is the intended
 * effect." That only works cleanly for a stateless, self-verifying token
 * (rotating a secret can't invalidate opaque tokens sitting in a database),
 * so this is a minimal HMAC-signed payload: base64url(payload).base64url(hmac),
 * no external JWT library — the whole format is three lines to verify.
 */

const DEFAULT_TTL_S = 60 * 60 * 24 * 90; // 90 days; the athlete re-signs in via Sign in with Apple, not a password, so a long-lived token is the right tradeoff for a mobile app that should not nag a 15-year-old to log in weekly.

function hmac(secret, data) {
  return crypto.createHmac('sha256', secret).update(data, 'utf8').digest('base64url');
}

export function signSessionToken(athleteId, { secret, now = () => Math.floor(Date.now() / 1000), ttlSeconds = DEFAULT_TTL_S } = {}) {
  if (!secret) throw new Error('signSessionToken requires a secret');
  const payload = { sub: athleteId, iat: now(), exp: now() + ttlSeconds };
  const payloadB64 = Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
  const signature = hmac(secret, payloadB64);
  return `${payloadB64}.${signature}`;
}

export class SessionTokenError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'SessionTokenError';
    this.code = code;
  }
}

export function verifySessionToken(token, { secret, now = () => Math.floor(Date.now() / 1000) } = {}) {
  if (!secret) throw new Error('verifySessionToken requires a secret');
  if (typeof token !== 'string' || !token.includes('.')) {
    throw new SessionTokenError('malformed', 'session token is malformed');
  }
  const [payloadB64, signature] = token.split('.');
  const expected = hmac(secret, payloadB64);

  const a = Buffer.from(signature ?? '', 'utf8');
  const b = Buffer.from(expected, 'utf8');
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    throw new SessionTokenError('bad_signature', 'session token signature does not verify');
  }

  let payload;
  try {
    payload = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf8'));
  } catch {
    throw new SessionTokenError('malformed', 'session token payload is not valid JSON');
  }
  if (typeof payload.sub !== 'string' || payload.sub.length === 0) {
    throw new SessionTokenError('malformed', 'session token has no sub');
  }
  if (typeof payload.exp !== 'number' || payload.exp <= now()) {
    throw new SessionTokenError('expired', 'session token has expired');
  }
  return { athleteId: payload.sub };
}
