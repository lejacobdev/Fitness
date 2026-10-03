import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import http2 from 'node:http2';
import test from 'node:test';

import { createApns } from '../src/lib/apns.js';

test('apns: not configured means no client', () => {
  assert.equal(createApns({ keyId: '', teamId: '', privateKey: '', topic: '' }), null);
});

test('apns: signs an ES256 provider token and posts the payload to the device path', async () => {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const seen = [];
  const server = http2.createServer();
  server.on('stream', (stream, headers) => {
    let body = '';
    stream.on('data', (c) => { body += c; });
    stream.on('end', () => {
      seen.push({ headers, body });
      const bad = headers[':path'].endsWith('dead');
      stream.respond({ ':status': bad ? 410 : 200 });
      stream.end(bad ? JSON.stringify({ reason: 'Unregistered' }) : '');
    });
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const apns = createApns({
    keyId: 'KEY1234567', teamId: 'TEAM123456', topic: 'com.example.app',
    privateKey: privateKey.export({ type: 'pkcs8', format: 'pem' }),
    host: `http://127.0.0.1:${server.address().port}`,
  });
  try {
    const ok = await apns.send('abc123', { aps: { alert: { title: 't', body: 'b' } }, kind: 'assignment' });
    assert.deepEqual(ok, { ok: true, status: 200, reason: null });
    const { headers, body } = seen[0];
    assert.equal(headers[':path'], '/3/device/abc123');
    assert.equal(headers['apns-topic'], 'com.example.app');
    assert.equal(headers['apns-push-type'], 'alert');
    assert.equal(JSON.parse(body).kind, 'assignment');

    const [h, p, sig] = headers.authorization.replace('bearer ', '').split('.');
    assert.deepEqual(JSON.parse(Buffer.from(h, 'base64url')), { alg: 'ES256', kid: 'KEY1234567' });
    assert.equal(JSON.parse(Buffer.from(p, 'base64url')).iss, 'TEAM123456');
    assert.ok(crypto.verify('sha256', Buffer.from(`${h}.${p}`), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(sig, 'base64url')));

    const dead = await apns.send('dead', {});
    assert.deepEqual(dead, { ok: false, status: 410, reason: 'Unregistered' });
  } finally {
    apns.close();
    await new Promise((r) => server.close(r));
  }
});
