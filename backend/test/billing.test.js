import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { AppStoreJwsError, createAppStoreVerifier } from '../src/lib/appStoreJws.js';
import { nextProUntil } from '../src/routes/billing.js';
import { signSessionToken } from '../src/lib/sessionToken.js';

const BUNDLE_ID = 'com.studentathlete.app';
const SESSION_SECRET = 'test-session-secret';

// ── nextProUntil (pure) ───────────────────────────────────────────────────

const t = (iso) => new Date(iso);

test('SUBSCRIBED / DID_RENEW grant access until expiresDate', () => {
  const tx = { expiresDate: Date.parse('2026-11-01T00:00:00Z') };
  assert.deepEqual(nextProUntil({ notificationType: 'SUBSCRIBED' }, tx, null, null), t('2026-11-01T00:00:00Z'));
  assert.deepEqual(nextProUntil({ notificationType: 'DID_RENEW' }, tx, null, t('2026-10-01T00:00:00Z')), t('2026-11-01T00:00:00Z'));
});

test('an out-of-order older renewal never pulls entitlement backwards', () => {
  const tx = { expiresDate: Date.parse('2026-10-01T00:00:00Z') };
  assert.equal(nextProUntil({ notificationType: 'DID_RENEW' }, tx, null, t('2026-11-01T00:00:00Z')), undefined);
});

test('REFUND and REVOKE end access at the revocation date', () => {
  const tx = { expiresDate: Date.parse('2026-11-01T00:00:00Z'), revocationDate: Date.parse('2026-10-05T00:00:00Z') };
  assert.deepEqual(nextProUntil({ notificationType: 'REFUND' }, tx, null, t('2026-11-01T00:00:00Z')), t('2026-10-05T00:00:00Z'));
  assert.deepEqual(nextProUntil({ notificationType: 'REVOKE' }, tx, null, t('2026-11-01T00:00:00Z')), t('2026-10-05T00:00:00Z'));
});

test('EXPIRED sets proUntil to the real expiry even if it was later before', () => {
  const tx = { expiresDate: Date.parse('2026-10-01T00:00:00Z') };
  assert.deepEqual(nextProUntil({ notificationType: 'EXPIRED' }, tx, null, t('2026-12-01T00:00:00Z')), t('2026-10-01T00:00:00Z'));
});

test('billing-retry grace period keeps Pro active until the grace period ends (§18)', () => {
  const tx = { expiresDate: Date.parse('2026-10-01T00:00:00Z') };
  const renewal = { gracePeriodExpiresDate: Date.parse('2026-10-17T00:00:00Z') };
  assert.deepEqual(
    nextProUntil({ notificationType: 'DID_FAIL_TO_RENEW', subtype: 'GRACE_PERIOD' }, tx, renewal, t('2026-10-01T00:00:00Z')),
    t('2026-10-17T00:00:00Z'),
  );
});

test('a notification with no transaction changes nothing', () => {
  assert.equal(nextProUntil({ notificationType: 'TEST' }, null, null, null), undefined);
});

// ── The route, with a fake verifier ───────────────────────────────────────

const fakeSign = (payload) => `fake.${Buffer.from(JSON.stringify(payload)).toString('base64url')}.sig`;
const fakeVerifier = {
  verify(jws) {
    const [head, body] = jws.split('.');
    if (head !== 'fake') throw new AppStoreJwsError('bad_signature', 'not signed by the fake signer');
    return JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  },
};

function fakePrisma(athletes) {
  return {
    athlete: {
      async findUnique({ where }) {
        if (where.id) return athletes.find((a) => a.id === where.id) ?? null;
        if (where.originalTransactionId) return athletes.find((a) => a.originalTransactionId === where.originalTransactionId) ?? null;
        return null;
      },
      async update({ where, data }) {
        const athlete = athletes.find((a) => a.id === where.id);
        Object.assign(athlete, data);
        return athlete;
      },
    },
  };
}

async function serve(app) {
  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });
  return { url: `http://127.0.0.1:${server.address().port}`, close: () => new Promise((r) => server.close(r)) };
}

function notify(url, body, pathName = '/billing/appstore/notify') {
  return fetch(`${url}${pathName}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(2000),
  });
}

function notification(type, transaction, extra = {}) {
  return {
    signedPayload: fakeSign({
      notificationType: type,
      notificationUUID: crypto.randomUUID(),
      data: { bundleId: BUNDLE_ID, environment: 'Sandbox', signedTransactionInfo: fakeSign(transaction), ...extra },
    }),
  };
}

test('a SUBSCRIBED notification grants Pro to the athlete named by appAccountToken, at both paths', async () => {
  const athletes = [{ id: 'a0b1c2d3-0000-4000-8000-000000000001', proUntil: null, originalTransactionId: null }];
  const app = createApp({ prisma: fakePrisma(athletes), appleBundleId: BUNDLE_ID, appStoreVerifier: fakeVerifier });
  const { url, close } = await serve(app);
  try {
    const expires = Date.parse('2027-01-01T00:00:00Z');
    const res = await notify(url, notification('SUBSCRIBED', {
      appAccountToken: 'A0B1C2D3-0000-4000-8000-000000000001', originalTransactionId: '2000000001', expiresDate: expires,
    }));
    assert.equal(res.status, 200);
    assert.equal(athletes[0].proUntil.getTime(), expires);
    assert.equal(athletes[0].originalTransactionId, '2000000001');

    // A renewal from another device (no appAccountToken) finds the athlete by originalTransactionId.
    const later = Date.parse('2027-02-01T00:00:00Z');
    const renew = await notify(url, notification('DID_RENEW', { originalTransactionId: '2000000001', expiresDate: later }), '/appstore/notifications');
    assert.equal(renew.status, 200);
    assert.equal(athletes[0].proUntil.getTime(), later);
  } finally {
    await close();
  }
});

test('a payload that fails verification is rejected 400 and writes nothing', async () => {
  const athletes = [{ id: 'athlete-1', proUntil: null }];
  const app = createApp({ prisma: fakePrisma(athletes), appleBundleId: BUNDLE_ID, appStoreVerifier: fakeVerifier });
  const { url, close } = await serve(app);
  try {
    const forged = { signedPayload: `forged.${Buffer.from('{}').toString('base64url')}.x` };
    const res = await notify(url, forged);
    assert.equal(res.status, 400);
    assert.equal(athletes[0].proUntil, null);
    assert.equal((await notify(url, {})).status, 400);
  } finally {
    await close();
  }
});

test("another app's notification and an unknown athlete are acknowledged (no Apple retries) but change nothing", async () => {
  const athletes = [{ id: 'athlete-1', proUntil: null }];
  const app = createApp({ prisma: fakePrisma(athletes), appleBundleId: BUNDLE_ID, appStoreVerifier: fakeVerifier });
  const { url, close } = await serve(app);
  try {
    const other = notification('SUBSCRIBED', { appAccountToken: 'athlete-1', expiresDate: Date.now() + 1e9 }, { bundleId: 'com.someone.else' });
    assert.equal((await notify(url, other)).status, 200);
    const unknown = notification('SUBSCRIBED', { appAccountToken: 'nobody', expiresDate: Date.now() + 1e9 });
    assert.equal((await notify(url, unknown)).status, 200);
    assert.equal(athletes[0].proUntil, null);
  } finally {
    await close();
  }
});

test('GET /athlete/me returns the server-side entitlement', async () => {
  const future = new Date(Date.now() + 86_400_000);
  const athletes = [{ id: 'athlete-1', proUntil: future }];
  const app = createApp({ prisma: fakePrisma(athletes), sessionSecret: SESSION_SECRET, appStoreVerifier: fakeVerifier });
  const { url, close } = await serve(app);
  try {
    const res = await fetch(`${url}/athlete/me`, {
      headers: { authorization: `Bearer ${signSessionToken('athlete-1', { secret: SESSION_SECRET })}` },
    });
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.athlete.isPro, true);
    assert.equal(body.athlete.proUntil, future.toISOString());
    assert.equal((await fetch(`${url}/athlete/me`)).status, 401);
  } finally {
    await close();
  }
});

// ── The real chain verifier, against a locally generated CA ───────────────

function hasOpenssl() {
  try {
    execFileSync('openssl', ['version'], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

function makeChain({ appleOids }) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'asn-chain-'));
  const run = (...args) => execFileSync('openssl', args, { cwd: dir, stdio: 'pipe' });
  const ext = (name, lines) => fs.writeFileSync(path.join(dir, name), lines.join('\n'));
  for (const name of ['root', 'int', 'leaf']) run('ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', `${name}.key`);
  ext('ca.ext', ['basicConstraints=critical,CA:TRUE', 'keyUsage=critical,keyCertSign,cRLSign', ...(appleOids ? ['1.2.840.113635.100.6.2.1=ASN1:NULL'] : [])]);
  ext('leaf.ext', ['basicConstraints=critical,CA:FALSE', 'keyUsage=critical,digitalSignature', ...(appleOids ? ['1.2.840.113635.100.6.11.1=ASN1:NULL'] : [])]);
  run('req', '-x509', '-new', '-key', 'root.key', '-subj', '/CN=Test Root', '-days', '3650', '-out', 'root.pem');
  run('req', '-new', '-key', 'int.key', '-subj', '/CN=Test Intermediate', '-out', 'int.csr');
  run('x509', '-req', '-in', 'int.csr', '-CA', 'root.pem', '-CAkey', 'root.key', '-CAcreateserial', '-days', '3650', '-extfile', 'ca.ext', '-out', 'int.pem');
  run('req', '-new', '-key', 'leaf.key', '-subj', '/CN=Test Leaf', '-out', 'leaf.csr');
  run('x509', '-req', '-in', 'leaf.csr', '-CA', 'int.pem', '-CAkey', 'int.key', '-CAcreateserial', '-days', '3650', '-extfile', 'leaf.ext', '-out', 'leaf.pem');
  const read = (f) => fs.readFileSync(path.join(dir, f), 'utf8');
  const der = (f) => new crypto.X509Certificate(read(f)).raw.toString('base64');
  return { rootPem: read('root.pem'), leafKey: read('leaf.key'), x5c: [der('leaf.pem'), der('int.pem'), der('root.pem')] };
}

function signJws(payload, { x5c, leafKey, alg = 'ES256' }) {
  const header = Buffer.from(JSON.stringify({ alg, x5c })).toString('base64url');
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signature = crypto.sign('sha256', Buffer.from(`${header}.${body}`), { key: leafKey, dsaEncoding: 'ieee-p1363' });
  return `${header}.${body}.${signature.toString('base64url')}`;
}

test('the chain verifier accepts a correctly signed payload and rejects every tampering', { skip: !hasOpenssl() }, () => {
  const chain = makeChain({ appleOids: true });
  const verifier = createAppStoreVerifier({ rootCertificates: [chain.rootPem] });
  const jws = signJws({ notificationType: 'SUBSCRIBED' }, chain);
  assert.deepEqual(verifier.verify(jws), { notificationType: 'SUBSCRIBED' });

  const [head, , sig] = jws.split('.');
  const tampered = `${head}.${Buffer.from(JSON.stringify({ notificationType: 'REFUND' })).toString('base64url')}.${sig}`;
  assert.throws(() => verifier.verify(tampered), (e) => e.code === 'bad_signature');

  const noneAlg = signJws({ notificationType: 'SUBSCRIBED' }, { ...chain, alg: 'none' });
  assert.throws(() => verifier.verify(noneAlg), (e) => e.code === 'bad_alg');

  // The production verifier trusts only Apple's root, so a self-made chain fails.
  assert.throws(() => createAppStoreVerifier().verify(jws), (e) => e.code === 'untrusted_root');
});

test('without Apple\'s marker OIDs a chain is rejected even from a trusted root', { skip: !hasOpenssl() }, () => {
  const chain = makeChain({ appleOids: false });
  const jws = signJws({ notificationType: 'SUBSCRIBED' }, chain);
  assert.throws(() => createAppStoreVerifier({ rootCertificates: [chain.rootPem] }).verify(jws), (e) => e.code === 'bad_chain');
  assert.ok(createAppStoreVerifier({ rootCertificates: [chain.rootPem], requireAppleOids: false }).verify(jws));
});
