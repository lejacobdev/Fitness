import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import test from 'node:test';

import {
  AppleIdentityError,
  createAppleKeyStore,
  sha256Hex,
  verifyAppleIdentityToken,
} from '../src/lib/appleIdentity.js';

const AUDIENCE = 'com.lejacobdev.studentathlete';
const KID = 'test-key-1';
const NOW_S = 1_800_000_000;

const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
});

/** A key store serving our test key, with no network involved. */
function keyStoreWith(keys) {
  return {
    async get(kid) {
      const jwk = keys.find((k) => k.kid === kid);
      if (!jwk) {
        throw new AppleIdentityError('unknown_key',
          'identity token was signed with a key Apple does not publish');
      }
      return jwk;
    },
  };
}

const testJwk = { ...publicKey.export({ format: 'jwk' }), kid: KID, alg: 'RS256', use: 'sig' };
const keyStore = keyStoreWith([testJwk]);

const b64 = (obj) => Buffer.from(JSON.stringify(obj), 'utf8').toString('base64url');

function mint({ header = {}, claims = {}, signWith = privateKey, tamper = false } = {}) {
  const fullHeader = { alg: 'RS256', kid: KID, ...header };
  const fullClaims = {
    iss: 'https://appleid.apple.com',
    aud: AUDIENCE,
    sub: '001234.abcdef.5678',
    iat: NOW_S - 30,
    exp: NOW_S + 600,
    ...claims,
  };
  const signingInput = `${b64(fullHeader)}.${b64(fullClaims)}`;
  if (fullHeader.alg === 'none') return `${signingInput}.`;
  let sig = crypto.sign('sha256', Buffer.from(signingInput, 'utf8'), {
    key: signWith,
    padding: crypto.constants.RSA_PKCS1_PADDING,
  });
  if (tamper) sig = Buffer.concat([sig.subarray(0, sig.length - 1), Buffer.from([sig.at(-1) ^ 0xff])]);
  return `${signingInput}.${sig.toString('base64url')}`;
}

const verify = (token, extra = {}) => verifyAppleIdentityToken(token, {
  audience: AUDIENCE,
  keyStore,
  now: () => NOW_S,
  ...extra,
});

async function rejectsWithCode(promise, code) {
  await assert.rejects(promise, (err) => {
    assert.ok(err instanceof AppleIdentityError, `expected AppleIdentityError, got ${err}`);
    assert.equal(err.code, code);
    return true;
  });
}

test('a well-formed Apple token yields the sub and nothing else', async () => {
  const result = await verify(mint());
  assert.deepEqual(result, { sub: '001234.abcdef.5678' });
  // Guard against a future change leaking email/name into the return value (§3).
  assert.deepEqual(Object.keys(result), ['sub']);
});

test('email and name claims are dropped even when Apple sends them', async () => {
  const token = mint({
    claims: { email: 'teen@example.com', email_verified: 'true', is_private_email: 'false' },
  });
  assert.deepEqual(await verify(token), { sub: '001234.abcdef.5678' });
});

test('alg:none is rejected', async () => {
  await rejectsWithCode(verify(mint({ header: { alg: 'none' } })), 'bad_algorithm');
});

test('a non-RS256 algorithm is rejected before any signature work', async () => {
  // The classic confusion attack: HS256 with the RSA public key as the secret.
  const header = { alg: 'HS256', kid: KID };
  const claims = {
    iss: 'https://appleid.apple.com', aud: AUDIENCE, sub: 'x', exp: NOW_S + 600,
  };
  const signingInput = `${b64(header)}.${b64(claims)}`;
  const pem = publicKey.export({ type: 'spki', format: 'pem' });
  const mac = crypto.createHmac('sha256', pem).update(signingInput).digest('base64url');
  await rejectsWithCode(verify(`${signingInput}.${mac}`), 'bad_algorithm');
});

test('a token for a different audience is rejected', async () => {
  await rejectsWithCode(verify(mint({ claims: { aud: 'com.someone.else' } })), 'bad_audience');
});

test('an array aud containing our bundle id is accepted', async () => {
  const token = mint({ claims: { aud: ['com.someone.else', AUDIENCE] } });
  assert.deepEqual(await verify(token), { sub: '001234.abcdef.5678' });
});

test('an expired token is rejected', async () => {
  await rejectsWithCode(verify(mint({ claims: { exp: NOW_S - 120 } })), 'expired');
});

test('a token signed with an unpublished key is rejected', async () => {
  const stranger = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
  const token = mint({ header: { kid: 'not-apples-key' }, signWith: stranger.privateKey });
  await rejectsWithCode(verify(token), 'unknown_key');
});

test('a token signed by the wrong key for a known kid is rejected', async () => {
  const stranger = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
  await rejectsWithCode(verify(mint({ signWith: stranger.privateKey })), 'bad_signature');
});

test('a tampered signature is rejected', async () => {
  await rejectsWithCode(verify(mint({ tamper: true })), 'bad_signature');
});

test('a non-Apple issuer is rejected', async () => {
  await rejectsWithCode(
    verify(mint({ claims: { iss: 'https://accounts.google.com' } })),
    'bad_issuer',
  );
});

test('a nonce that does not match the raw value is rejected', async () => {
  const token = mint({ claims: { nonce: sha256Hex('some-other-session') } });
  await rejectsWithCode(verify(token, { rawNonce: 'this-session' }), 'nonce_mismatch');
});

test('a matching hashed nonce is accepted', async () => {
  const token = mint({ claims: { nonce: sha256Hex('this-session') } });
  assert.deepEqual(await verify(token, { rawNonce: 'this-session' }), {
    sub: '001234.abcdef.5678',
  });
});

test('a missing nonce is rejected when one was expected', async () => {
  await rejectsWithCode(verify(mint(), { rawNonce: 'this-session' }), 'nonce_missing');
});

test('a token with no sub is rejected', async () => {
  await rejectsWithCode(verify(mint({ claims: { sub: undefined } })), 'malformed');
});

test('garbage input is rejected rather than throwing something unhandled', async () => {
  for (const bad of ['', 'not-a-jwt', 'a.b', 'a.b.c.d']) {
    await assert.rejects(verify(bad), AppleIdentityError);
  }
  await rejectsWithCode(verify('!!!.!!!.x'), 'malformed');
});

test('the key store refreshes once for an unseen kid before giving up', async () => {
  let calls = 0;
  const store = createAppleKeyStore({
    now: () => 0,
    fetchImpl: async () => {
      calls += 1;
      // First load has an old key set; the rotated key only appears on reload.
      return {
        ok: true,
        json: async () => ({ keys: calls === 1 ? [] : [testJwk] }),
      };
    },
  });
  const jwk = await store.get(KID);
  assert.equal(jwk.kid, KID);
  assert.equal(calls, 2, 'should have reloaded exactly once for the unknown kid');
});

test('the key store surfaces an Apple outage as keys_unavailable', async () => {
  const store = createAppleKeyStore({
    fetchImpl: async () => ({ ok: false, status: 503 }),
  });
  await rejectsWithCode(store.get(KID), 'keys_unavailable');
});
