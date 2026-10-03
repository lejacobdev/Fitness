import crypto from 'node:crypto';
import fs from 'node:fs';
import http2 from 'node:http2';

/**
 * Apple Push Notification service over HTTP/2 with a provider token (an APNs
 * auth key, .p8). Needs APNS_KEY_ID, APNS_TEAM_ID and the key itself
 * (APNS_PRIVATE_KEY, or APNS_PRIVATE_KEY_PATH); the topic is the bundle id.
 * Without them `createApns` returns null and the server simply sends no pushes.
 */
export function createApns({
  keyId = process.env.APNS_KEY_ID,
  teamId = process.env.APNS_TEAM_ID,
  privateKey = process.env.APNS_PRIVATE_KEY
    ?? (process.env.APNS_PRIVATE_KEY_PATH && fs.existsSync(process.env.APNS_PRIVATE_KEY_PATH)
      ? fs.readFileSync(process.env.APNS_PRIVATE_KEY_PATH, 'utf8')
      : undefined),
  topic = process.env.APPLE_BUNDLE_ID,
  host = process.env.APNS_HOST ?? 'https://api.push.apple.com',
  connect = http2.connect,
  now = () => Date.now(),
} = {}) {
  if (!keyId || !teamId || !privateKey || !topic) return null;

  let jwt = null;
  let jwtAt = 0;
  function providerToken() {
    // Apple wants a fresh token every 20–60 minutes, not one per request.
    if (jwt && now() - jwtAt < 40 * 60_000) return jwt;
    const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
    const input = `${b64({ alg: 'ES256', kid: keyId })}.${b64({ iss: teamId, iat: Math.floor(now() / 1000) })}`;
    const signature = crypto.sign('sha256', Buffer.from(input), { key: privateKey, dsaEncoding: 'ieee-p1363' });
    jwt = `${input}.${signature.toString('base64url')}`;
    jwtAt = now();
    return jwt;
  }

  let session = null;
  function getSession() {
    if (session && !session.closed && !session.destroyed) return session;
    const created = connect(host);
    created.on('error', () => { if (session === created) session = null; });
    created.on('close', () => { if (session === created) session = null; });
    created.unref?.();
    session = created;
    return created;
  }

  /** Resolves { ok, status, reason } — never rejects. */
  function send(deviceToken, payload, { pushType = 'alert', priority = 10, expirationSeconds = 24 * 3600, collapseId } = {}) {
    return new Promise((resolve) => {
      let settled = false;
      const finish = (result) => { if (!settled) { settled = true; resolve(result); } };
      try {
        const req = getSession().request({
          ':method': 'POST',
          ':path': `/3/device/${deviceToken}`,
          authorization: `bearer ${providerToken()}`,
          'apns-topic': topic,
          'apns-push-type': pushType,
          'apns-priority': String(priority),
          'apns-expiration': String(Math.floor(now() / 1000) + expirationSeconds),
          ...(collapseId ? { 'apns-collapse-id': collapseId } : {}),
        });
        let status = 0;
        let body = '';
        req.setTimeout(10_000, () => { req.close(); finish({ ok: false, status: 0, reason: 'timeout' }); });
        req.on('response', (headers) => { status = Number(headers[':status']); });
        req.on('data', (chunk) => { body += chunk; });
        req.on('end', () => {
          let reason = null;
          try { reason = body ? JSON.parse(body).reason ?? null : null; } catch { /* not JSON */ }
          finish({ ok: status === 200, status, reason });
        });
        req.on('error', (err) => finish({ ok: false, status: 0, reason: err.code ?? 'error' }));
        req.end(JSON.stringify(payload));
      } catch (err) {
        finish({ ok: false, status: 0, reason: err.code ?? 'error' });
      }
    });
  }

  function close() { session?.destroy(); session = null; }

  return { send, close };
}
