#!/usr/bin/env node
/**
 * App Store Connect API client — no SDK, per §19.
 *
 * Three details here are the whole reason this file exists rather than a
 * dependency. Each one cost a day on a previous app:
 *
 *  1. The ES256 JWT must be signed with `dsaEncoding: 'ieee-p1363'`. Node's
 *     default is DER, which every App Store Connect endpoint rejects as an
 *     invalid token without ever saying why.
 *
 *  2. `filter[identifier]` on /v1/bundleIds is a PREFIX match, and `included`
 *     pools capabilities across every match. Asking for
 *     `com.lejacobdev.studentathlete` also returns the watch app, the
 *     complication and the widget, so capabilities must be read through the
 *     exact bundle's own relationship ids rather than off the top-level
 *     `included` array.
 *
 *  3. `GET /v1/builds/{id}/buildBundles` is forbidden for API keys, while
 *     `GET /v1/builds/{id}?include=buildBundles` returns the same records.
 *
 * Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY (the .p8 contents).
 *
 * Usage:
 *   node tools/asc.mjs capabilities <bundle-id>
 *   node tools/asc.mjs apps
 *   node tools/asc.mjs versions <bundle-id>
 *   node tools/asc.mjs builds <bundle-id> [limit]
 *   node tools/asc.mjs build-bundles <build-id>
 */

import crypto from 'node:crypto';

const BASE = 'https://api.appstoreconnect.apple.com';

function required(name) {
  const value = process.env[name];
  if (!value) {
    console.error(`missing ${name}`);
    process.exit(2);
  }
  return value;
}

const b64url = (input) => Buffer.from(input).toString('base64url');

/** An ES256 App Store Connect token, valid for 15 minutes. */
export function mintToken() {
  const keyId = required('ASC_KEY_ID');
  const issuerId = required('ASC_ISSUER_ID');
  const privateKey = crypto.createPrivateKey(required('ASC_PRIVATE_KEY'));

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'ES256', kid: keyId, typ: 'JWT' };
  const payload = {
    iss: issuerId,
    iat: now,
    exp: now + 15 * 60, // Apple rejects anything beyond 20 minutes.
    aud: 'appstoreconnect-v1',
  };

  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const signature = crypto.sign('sha256', Buffer.from(signingInput), {
    key: privateKey,
    // (1) Without this the signature is DER-encoded and every call 401s.
    dsaEncoding: 'ieee-p1363',
  });

  return `${signingInput}.${signature.toString('base64url')}`;
}

let cachedToken;
async function api(path) {
  cachedToken ??= mintToken();
  const res = await fetch(`${BASE}${path}`, {
    headers: { authorization: `Bearer ${cachedToken}`, accept: 'application/json' },
  });
  const text = await res.text();
  let body;
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { raw: text };
  }
  if (!res.ok) {
    const detail = body?.errors?.map((e) => `${e.title}: ${e.detail}`).join('; ') ?? text;
    throw new Error(`${res.status} ${path} — ${detail}`);
  }
  return body;
}

/**
 * Resolve one bundle id record by its *exact* identifier.
 * (2) The filter is a prefix match, so the result is narrowed here.
 */
async function exactBundle(identifier) {
  const body = await api(
    `/v1/bundleIds?filter[identifier]=${encodeURIComponent(identifier)}&limit=200`,
  );
  const hit = body.data.find((b) => b.attributes.identifier === identifier);
  if (!hit) {
    const seen = body.data.map((b) => b.attributes.identifier).join(', ') || '(none)';
    throw new Error(`no bundle id exactly "${identifier}". Prefix matches: ${seen}`);
  }
  return hit;
}

const commands = {
  async apps() {
    const body = await api('/v1/apps?limit=200');
    for (const app of body.data) {
      console.log(`${app.id}  ${app.attributes.bundleId}  ${app.attributes.name}`);
    }
  },

  async capabilities(identifier) {
    if (!identifier) throw new Error('usage: capabilities <bundle-id>');
    const bundle = await exactBundle(identifier);
    console.log(`bundle ${bundle.attributes.identifier} (${bundle.id})`);
    console.log(`  name: ${bundle.attributes.name}`);
    console.log(`  platform: ${bundle.attributes.platform}`);

    // (2) Read capabilities through this bundle's own relationship, never the
    // pooled `included` array of a prefix-matched list response.
    const caps = await api(`/v1/bundleIds/${bundle.id}/bundleIdCapabilities?limit=200`);
    const enabled = caps.data.map((c) => c.attributes.capabilityType).sort();
    console.log(`  capabilities (${enabled.length}):`);
    for (const c of enabled) console.log(`    - ${c}`);

    // §19: these five must all be present before the first archive, because
    // automatic signing builds the profile from the entitlements file and a
    // missing capability fails the *build*.
    const wanted = [
      'HEALTHKIT',
      'APPLE_ID_AUTH',
      'IN_APP_PURCHASE',
      'APP_GROUPS',
      'PUSH_NOTIFICATIONS',
    ];
    const missing = wanted.filter((w) => !enabled.includes(w));
    if (missing.length) {
      console.log(`  MISSING: ${missing.join(', ')}`);
      if (missing.includes('APP_GROUPS')) {
        console.log('    note: enabling APP_GROUPS is an API call, but ATTACHING the');
        console.log('    group to the App ID is a manual portal step — an API key cannot');
        console.log('    do it, and the archive fails with a bearer-token error (§19).');
      }
      process.exitCode = 1;
    } else {
      console.log('  all five required capabilities present');
    }
  },

  async versions(identifier) {
    if (!identifier) throw new Error('usage: versions <bundle-id>');
    const apps = await api(`/v1/apps?filter[bundleId]=${encodeURIComponent(identifier)}`);
    const app = apps.data.find((a) => a.attributes.bundleId === identifier);
    if (!app) throw new Error(`no app with bundleId exactly "${identifier}"`);
    const body = await api(
      `/v1/apps/${app.id}/appStoreVersions?limit=20`
      + '&fields[appStoreVersions]=versionString,appStoreState,platform,createdDate',
    );
    for (const v of body.data) {
      const a = v.attributes;
      console.log(`${a.versionString}  ${a.appStoreState}  ${a.platform}  ${a.createdDate}`);
    }
  },

  async builds(identifier, limit = '10') {
    if (!identifier) throw new Error('usage: builds <bundle-id> [limit]');
    const apps = await api(`/v1/apps?filter[bundleId]=${encodeURIComponent(identifier)}`);
    const app = apps.data.find((a) => a.attributes.bundleId === identifier);
    if (!app) throw new Error(`no app with bundleId exactly "${identifier}"`);
    const body = await api(
      `/v1/builds?filter[app]=${app.id}&limit=${encodeURIComponent(limit)}`
      + '&sort=-uploadedDate'
      + '&fields[builds]=version,uploadedDate,processingState,expired,minOsVersion',
    );
    if (!body.data.length) {
      console.log('no builds uploaded yet');
      return;
    }
    for (const b of body.data) {
      const a = b.attributes;
      console.log(
        `${b.id}  build ${a.version}  ${a.processingState}  `
        + `minOS ${a.minOsVersion ?? '?'}  ${a.uploadedDate}${a.expired ? '  EXPIRED' : ''}`,
      );
    }
  },

  async 'build-bundles'(buildId) {
    if (!buildId) throw new Error('usage: build-bundles <build-id>');
    // (3) The sub-resource path is forbidden for API keys; the include is not.
    const body = await api(`/v1/builds/${buildId}?include=buildBundles`);
    for (const bundle of body.included ?? []) {
      const a = bundle.attributes ?? {};
      console.log(`${a.bundleId ?? '?'}  type=${a.bundleType ?? '?'}`);
      console.log(`  platformBuild: ${a.platformBuild ?? '—'}`);
      console.log(`  sdkBuild: ${a.sdkBuild ?? '—'}`);
      console.log(`  usesNonExemptEncryption: ${a.usesNonExemptEncryption ?? '—'}`);
      console.log(`  includesSymbols: ${a.includesSymbols ?? '—'}`);
      if (a.entitlements) {
        console.log('  entitlements as recorded by App Store Connect:');
        for (const [k, v] of Object.entries(a.entitlements)) {
          console.log(`    ${k} = ${JSON.stringify(v)}`);
        }
      }
    }
  },
};

// Only dispatch when run as a script, so the module stays importable by tests.
if (process.argv[1] && import.meta.url === `file://${process.argv[1]}`) {
  const [command, ...args] = process.argv.slice(2);
  const handler = commands[command];
  if (!handler) {
    console.error(`unknown command ${JSON.stringify(command)}`);
    console.error(`available: ${Object.keys(commands).join(', ')}`);
    process.exit(2);
  }
  handler(...args).catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
}
