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
 *     `com.studentathlete.app` also returns the watch app, the
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
 *   node tools/asc.mjs certificates
 *   node tools/asc.mjs versions <bundle-id>
 *   node tools/asc.mjs builds <bundle-id> [limit]
 *   node tools/asc.mjs build-bundles <build-id>
 *   node tools/asc.mjs create-bundle-id <bundle-id> <name>
 *   node tools/asc.mjs enable-capability <bundle-id> <CAPABILITY_TYPE>
 *   node tools/asc.mjs provision <bundle-id> <name>   (create-bundle-id + every capability §19 needs)
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
async function api(path, { method = 'GET', body: requestBody } = {}) {
  cachedToken ??= mintToken();
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      authorization: `Bearer ${cachedToken}`,
      accept: 'application/json',
      ...(requestBody ? { 'content-type': 'application/json' } : {}),
    },
    body: requestBody ? JSON.stringify(requestBody) : undefined,
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
    // pooled `included` array of a prefix-matched list response. Unlike most
    // list endpoints this one rejects `limit` outright (400: "This
    // relationship does not support this parameter") — a bundle only ever
    // has a handful of capabilities, so there is nothing to paginate anyway.
    const caps = await api(`/v1/bundleIds/${bundle.id}/bundleIdCapabilities`);
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

  /**
   * §19/testflight.yml: every archive with -allowProvisioningUpdates can
   * mint a NEW certificate rather than reuse the one already imported from
   * APPLE_DIST_CERT_P12_BASE64, if Xcode's automatic-signing heuristics
   * don't recognise it as reusable — which is exactly how an account hits
   * "maximum number of certificates" over many CI runs. Read-only: lists
   * what exists so a human can pick which to revoke in the portal, never
   * revokes anything itself (§19: this file does provisioning, not
   * destructive account changes).
   */
  async certificates() {
    const body = await api(
      '/v1/certificates?limit=200'
      + '&fields[certificates]=name,certificateType,displayName,serialNumber,platform,expirationDate',
    );
    for (const c of body.data) {
      const a = c.attributes;
      console.log(`${c.id}  ${a.certificateType}  ${a.displayName ?? a.name}  expires ${a.expirationDate}  serial ${a.serialNumber}`);
    }
    console.log(`\n${body.data.length} certificate(s) total`);
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

  /** Registers a new App ID. Idempotent: if it already exists, returns it. */
  async 'create-bundle-id'(identifier, name) {
    if (!identifier || !name) throw new Error('usage: create-bundle-id <bundle-id> <name>');
    try {
      const existing = await exactBundle(identifier);
      console.log(`already exists: ${existing.attributes.identifier} (${existing.id})`);
      return existing;
    } catch {
      // fall through to create
    }
    const body = await api('/v1/bundleIds', {
      method: 'POST',
      body: {
        data: {
          type: 'bundleIds',
          attributes: { identifier, name, platform: 'IOS' },
        },
      },
    });
    console.log(`created: ${body.data.attributes.identifier} (${body.data.id})`);
    return body.data;
  },

  /**
   * §19: enabling most capabilities is an ordinary POST. Two exceptions this
   * command knows about — Sign in with Apple is rejected as a bare
   * capability (409, "select at least one configuration") without the
   * APPLE_ID_AUTH_APP_CONSENT/PRIMARY_APP_CONSENT setting; App Groups can be
   * *enabled* this way but the actual group container still has to be
   * created and attached in the portal by a human — an API key cannot do
   * that part, and skipping it fails the archive with a bearer-token error.
   */
  async 'enable-capability'(identifier, capabilityType) {
    if (!identifier || !capabilityType) throw new Error('usage: enable-capability <bundle-id> <CAPABILITY_TYPE>');
    const bundle = await exactBundle(identifier);

    const settings = capabilityType === 'APPLE_ID_AUTH'
      ? [{ key: 'APPLE_ID_AUTH_APP_CONSENT', options: [{ key: 'PRIMARY_APP_CONSENT' }] }]
      : [];

    try {
      const body = await api('/v1/bundleIdCapabilities', {
        method: 'POST',
        body: {
          data: {
            type: 'bundleIdCapabilities',
            attributes: { capabilityType, settings },
            relationships: { bundleId: { data: { type: 'bundleIds', id: bundle.id } } },
          },
        },
      });
      console.log(`enabled ${capabilityType} (${body.data.id})`);
    } catch (err) {
      if (/already exists|already enabled/i.test(err.message)) {
        console.log(`${capabilityType} already enabled`);
        return;
      }
      throw err;
    }
    if (capabilityType === 'APP_GROUPS') {
      console.log('  note: the capability flag is on, but the App Group container itself');
      console.log('  (group.com.studentathlete.app) still needs to be created and');
      console.log('  attached in the portal — Certificates, Identifiers & Profiles >');
      console.log('  Identifiers > App Groups tab. An API key cannot do this step (§19).');
    }
  },

  /**
   * Attempts the App Store Connect app record — the thing a TestFlight build
   * actually uploads into. CONFIRMED (not a permission issue with this key,
   * a hard API restriction): `POST /v1/apps` returns 403 "The resource
   * 'apps' does not allow 'CREATE'. Allowed operations are: GET_COLLECTION,
   * GET_INSTANCE, UPDATE" for every key role. Creating a new app has always
   * required the App Store Connect web UI (My Apps > +) — kept here so the
   * error is self-documenting rather than a silent gap, and so `provision`
   * can still report the exact next manual step.
   */
  async 'create-app'(identifier, name, sku) {
    if (!identifier || !name || !sku) throw new Error('usage: create-app <bundle-id> <name> <sku>');
    const apps = await api(`/v1/apps?filter[bundleId]=${encodeURIComponent(identifier)}`);
    const existing = apps.data.find((a) => a.attributes.bundleId === identifier);
    if (existing) {
      console.log(`already exists: ${existing.attributes.name} (${existing.id})`);
      return existing;
    }
    const body = await api('/v1/apps', {
      method: 'POST',
      body: {
        data: {
          type: 'apps',
          attributes: { bundleId: identifier, name, sku, primaryLocale: 'en-US' },
        },
      },
    });
    console.log(`created app: ${body.data.attributes.name} (${body.data.id})`);
    return body.data;
  },

  /** create-bundle-id, then every §19-required capability, in one call. */
  async provision(identifier, name) {
    if (!identifier || !name) throw new Error('usage: provision <bundle-id> <name>');
    await commands['create-bundle-id'](identifier, name);
    const required = ['HEALTHKIT', 'APPLE_ID_AUTH', 'IN_APP_PURCHASE', 'APP_GROUPS', 'PUSH_NOTIFICATIONS'];
    for (const cap of required) {
      try {
        await commands['enable-capability'](identifier, cap);
      } catch (err) {
        console.error(`  FAILED to enable ${cap}: ${err.message}`);
      }
    }
    console.log('');
    await commands.capabilities(identifier);
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
