import crypto from 'node:crypto';
import fs from 'node:fs';

/**
 * Sign in with Apple token revocation (App Store guideline 5.1.1(v): an app
 * that offers account deletion and Sign in with Apple must revoke the user's
 * Apple tokens when the account is deleted).
 *
 * At sign-in the app sends Apple's one-time authorization code; this module
 * exchanges it for a refresh token, which is stored on the athlete. On
 * account deletion the refresh token is revoked, which removes the app from
 * the user's Apple ID "Sign in with Apple" list.
 *
 * Needs a Sign in with Apple private key from the Apple Developer portal
 * (Keys → + → Sign in with Apple): APPLE_SIWA_KEY_ID, APPLE_SIWA_TEAM_ID and
 * APPLE_SIWA_PRIVATE_KEY (the .p8 contents) or APPLE_SIWA_PRIVATE_KEY_PATH.
 * Without them, `createAppleRevoker` returns null and sign-in/deletion work
 * exactly as before (no revocation).
 */
export function createAppleRevoker({
  clientId = process.env.APPLE_BUNDLE_ID,
  teamId = process.env.APPLE_SIWA_TEAM_ID,
  keyId = process.env.APPLE_SIWA_KEY_ID,
  privateKey = process.env.APPLE_SIWA_PRIVATE_KEY
    ?? (process.env.APPLE_SIWA_PRIVATE_KEY_PATH ? fs.readFileSync(process.env.APPLE_SIWA_PRIVATE_KEY_PATH, 'utf8') : undefined),
  fetchImpl = globalThis.fetch,
} = {}) {
  if (!clientId || !teamId || !keyId || !privateKey) return null;

  function clientSecret() {
    const now = Math.floor(Date.now() / 1000);
    const header = { alg: 'ES256', kid: keyId };
    const claims = { iss: teamId, iat: now, exp: now + 300, aud: 'https://appleid.apple.com', sub: clientId };
    const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
    const input = `${b64(header)}.${b64(claims)}`;
    const signature = crypto.sign('sha256', Buffer.from(input), { key: privateKey, dsaEncoding: 'ieee-p1363' });
    return `${input}.${signature.toString('base64url')}`;
  }

  async function post(path, fields) {
    const body = new URLSearchParams({ client_id: clientId, client_secret: clientSecret(), ...fields });
    const res = await fetchImpl(`https://appleid.apple.com${path}`, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body,
    });
    return res;
  }

  return {
    /** Exchanges a sign-in authorization code for Apple's refresh token (null on failure). */
    async refreshTokenFor(authorizationCode) {
      const res = await post('/auth/token', { code: authorizationCode, grant_type: 'authorization_code' });
      if (!res.ok) return null;
      const json = await res.json();
      return typeof json.refresh_token === 'string' ? json.refresh_token : null;
    },
    /** Revokes the refresh token; true when Apple accepted it. */
    async revoke(refreshToken) {
      const res = await post('/auth/revoke', { token: refreshToken, token_type_hint: 'refresh_token' });
      return res.ok;
    },
  };
}
