import crypto from 'node:crypto';

/**
 * Sign in with Apple identity-token verification (§3). No SDK.
 *
 * The only claim this project keeps is `sub` — the stable, opaque Apple user id.
 * No email, no name, no other Apple data is read, stored or logged, which is what
 * makes §20's privacy policy true by construction rather than by promise.
 *
 * Every check here is load-bearing and has a negative test in
 * test/appleIdentity.test.js (§21):
 *   - `alg` is pinned to RS256, so an `alg: "none"` or HS256-with-the-public-key
 *     token is rejected before any signature work happens.
 *   - `kid` must match a key Apple currently publishes.
 *   - `iss`, `aud`, `exp` and `nonce` are all checked.
 */

export const APPLE_ISSUER = 'https://appleid.apple.com';
export const APPLE_KEYS_URL = 'https://appleid.apple.com/auth/keys';

/** Apple's keys rotate, but not per-request. */
const KEY_CACHE_TTL_MS = 60 * 60 * 1000;
/** Tolerance for a device clock that is slightly ahead of ours. */
const CLOCK_SKEW_S = 60;

export class AppleIdentityError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'AppleIdentityError';
    this.code = code;
  }
}

function base64UrlDecode(part) {
  return Buffer.from(part, 'base64url');
}

function decodeSegment(part, what) {
  let parsed;
  try {
    parsed = JSON.parse(base64UrlDecode(part).toString('utf8'));
  } catch {
    throw new AppleIdentityError('malformed', `identity token ${what} is not JSON`);
  }
  if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new AppleIdentityError('malformed', `identity token ${what} is not an object`);
  }
  return parsed;
}

export function sha256Hex(value) {
  return crypto.createHash('sha256').update(value, 'utf8').digest('hex');
}

/** Fetches and caches Apple's published JWKS. */
export function createAppleKeyStore({ fetchImpl = fetch, now = Date.now } = {}) {
  let cache = null;

  async function load() {
    const res = await fetchImpl(APPLE_KEYS_URL, {
      headers: { accept: 'application/json' },
    });
    if (!res.ok) {
      throw new AppleIdentityError('keys_unavailable',
        `Apple key endpoint returned ${res.status}`);
    }
    const body = await res.json();
    if (!body || !Array.isArray(body.keys)) {
      throw new AppleIdentityError('keys_unavailable', 'Apple key endpoint returned no keys');
    }
    cache = { keys: body.keys, loadedAt: now() };
    return cache.keys;
  }

  return {
    async get(kid, { allowRefresh = true } = {}) {
      if (!cache || now() - cache.loadedAt > KEY_CACHE_TTL_MS) await load();
      let jwk = cache.keys.find((k) => k.kid === kid);
      // A kid we do not know may simply mean Apple rotated since we cached.
      if (!jwk && allowRefresh) {
        await load();
        jwk = cache.keys.find((k) => k.kid === kid);
      }
      if (!jwk) {
        throw new AppleIdentityError('unknown_key',
          'identity token was signed with a key Apple does not publish');
      }
      return jwk;
    },
  };
}

/**
 * @param {string} identityToken   the raw JWT from ASAuthorizationAppleIDCredential
 * @param {object} options
 * @param {string} options.audience         the app's bundle identifier
 * @param {string} [options.rawNonce]       the pre-hash nonce the client generated
 * @param {object} options.keyStore         from createAppleKeyStore()
 * @returns {Promise<{sub: string}>}        the Apple user id, and nothing else
 */
export async function verifyAppleIdentityToken(identityToken, {
  audience,
  rawNonce,
  keyStore,
  now = () => Math.floor(Date.now() / 1000),
} = {}) {
  if (typeof identityToken !== 'string' || identityToken.length === 0) {
    throw new AppleIdentityError('malformed', 'identity token is missing');
  }
  if (!audience) throw new AppleIdentityError('misconfigured', 'audience is required');
  if (!keyStore) throw new AppleIdentityError('misconfigured', 'keyStore is required');

  const parts = identityToken.split('.');
  if (parts.length !== 3) {
    throw new AppleIdentityError('malformed', 'identity token is not a three-part JWT');
  }
  const [headerPart, payloadPart, signaturePart] = parts;

  const header = decodeSegment(headerPart, 'header');

  // RS256 is pinned before anything else. This is what rejects `alg: "none"`
  // (which arrives with an empty signature) and any attempt to have us verify an
  // HMAC token using a public key as the shared secret.
  if (header.alg !== 'RS256') {
    throw new AppleIdentityError('bad_algorithm',
      `identity token algorithm ${JSON.stringify(header.alg)} is not RS256`);
  }
  if (typeof header.kid !== 'string' || header.kid.length === 0) {
    throw new AppleIdentityError('malformed', 'identity token header has no kid');
  }
  if (signaturePart.length === 0) {
    throw new AppleIdentityError('bad_signature', 'identity token has no signature');
  }

  const jwk = await keyStore.get(header.kid);
  let publicKey;
  try {
    publicKey = crypto.createPublicKey({ key: jwk, format: 'jwk' });
  } catch {
    throw new AppleIdentityError('unknown_key', 'Apple key could not be parsed');
  }

  const signatureValid = crypto.verify(
    'sha256',
    Buffer.from(`${headerPart}.${payloadPart}`, 'utf8'),
    { key: publicKey, padding: crypto.constants.RSA_PKCS1_PADDING },
    base64UrlDecode(signaturePart),
  );
  if (!signatureValid) {
    throw new AppleIdentityError('bad_signature', 'identity token signature does not verify');
  }

  const claims = decodeSegment(payloadPart, 'payload');

  if (claims.iss !== APPLE_ISSUER) {
    throw new AppleIdentityError('bad_issuer',
      `identity token issuer ${JSON.stringify(claims.iss)} is not Apple`);
  }

  // `aud` may be a string or an array; either must contain exactly our bundle id.
  const audiences = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!audiences.includes(audience)) {
    throw new AppleIdentityError('bad_audience',
      'identity token was issued for a different application');
  }

  if (typeof claims.exp !== 'number') {
    throw new AppleIdentityError('malformed', 'identity token has no exp');
  }
  if (claims.exp + CLOCK_SKEW_S <= now()) {
    throw new AppleIdentityError('expired', 'identity token has expired');
  }
  if (typeof claims.iat === 'number' && claims.iat - CLOCK_SKEW_S > now()) {
    throw new AppleIdentityError('not_yet_valid', 'identity token is issued in the future');
  }

  // The client sets `request.nonce` to sha256Hex(rawNonce) and sends us the raw
  // value, so a token replayed from another session cannot match.
  if (rawNonce !== undefined) {
    const expected = sha256Hex(rawNonce);
    if (typeof claims.nonce !== 'string' || claims.nonce.length === 0) {
      throw new AppleIdentityError('nonce_missing',
        'identity token carries no nonce but one was expected');
    }
    const a = Buffer.from(claims.nonce, 'utf8');
    const b = Buffer.from(expected, 'utf8');
    if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
      throw new AppleIdentityError('nonce_mismatch', 'identity token nonce does not match');
    }
  }

  if (typeof claims.sub !== 'string' || claims.sub.length === 0) {
    throw new AppleIdentityError('malformed', 'identity token has no sub');
  }

  // Deliberately the only field returned. Everything else Apple sends is dropped
  // here so it cannot reach a database, a log or a crash report (§3, §20).
  return { sub: claims.sub };
}
