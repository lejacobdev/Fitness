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
 *   node tools/asc.mjs subscriptions <bundle-id>          (read-only: groups, products, prices)
 *   node tools/asc.mjs setup-subscriptions <bundle-id>    (§18: idempotent group + monthly/yearly Pro)
 *   node tools/asc.mjs set-notification-url <bundle-id> <url>   (App Store Server Notifications V2, prod + sandbox)
 *   node tools/asc.mjs upload-screenshots <bundle-id> <dir>   (replaces the editable version's en-US screenshots)
 *   node tools/asc.mjs upload-review-screenshot <bundle-id> <png>   (the paywall, as every Pro product's review screenshot)
 *   node tools/asc.mjs app-store-profiles <cert-serial> <out-dir> <bundle-id>...
 *       (fresh "SA AppStore <bundle>" IOS_APP_STORE profiles for manual signing)
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

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
  /**
   * Manual-signing profiles for CI. Deletes and recreates one App Store
   * profile per bundle id every run — cheap, and it guarantees the profile
   * carries the bundle's CURRENT capabilities (HealthKit, App Groups...) and
   * the distribution certificate CI actually signs with. This is what stops
   * automatic signing from minting a new development certificate per run.
   */
  async 'app-store-profiles'(serial, outDir, ...identifiers) {
    if (!serial || !outDir || identifiers.length === 0) {
      throw new Error('usage: app-store-profiles <cert-serial> <out-dir> <bundle-id>...');
    }
    const fs = await import('node:fs');
    const path = await import('node:path');
    const normalise = (v) => String(v).toUpperCase().replace(/^0+/, '');
    const certs = await api('/v1/certificates?limit=200&fields[certificates]=serialNumber,certificateType,displayName');
    const cert = certs.data.find((c) => normalise(c.attributes.serialNumber) === normalise(serial));
    if (!cert) throw new Error(`no certificate with serial ${serial} in this team`);
    console.log(`certificate ${cert.id} (${cert.attributes.certificateType} ${cert.attributes.displayName})`);
    fs.mkdirSync(outDir, { recursive: true });

    for (const identifier of identifiers) {
      const bundle = await exactBundle(identifier);
      const name = `SA AppStore ${identifier}`;
      const existing = await api(`/v1/profiles?filter[name]=${encodeURIComponent(name)}&limit=200`);
      for (const old of existing.data) {
        await api(`/v1/profiles/${old.id}`, { method: 'DELETE' });
      }
      const created = await api('/v1/profiles', {
        method: 'POST',
        body: {
          data: {
            type: 'profiles',
            attributes: { name, profileType: 'IOS_APP_STORE' },
            relationships: {
              bundleId: { data: { type: 'bundleIds', id: bundle.id } },
              certificates: { data: [{ type: 'certificates', id: cert.id }] },
            },
          },
        },
      });
      const { uuid, profileContent } = created.data.attributes;
      fs.writeFileSync(path.join(outDir, `${uuid}.mobileprovision`), Buffer.from(profileContent, 'base64'));
      console.log(`${name}  uuid ${uuid}`);
    }
  },

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
      + '&fields[builds]=version,uploadedDate,processingState,expired,minOsVersion,usesNonExemptEncryption,preReleaseVersion,buildBetaDetail'
      + '&include=preReleaseVersion,buildBetaDetail'
      + '&fields[preReleaseVersions]=version,platform'
      + '&fields[buildBetaDetails]=internalBuildState,externalBuildState,autoNotifyEnabled',
    );
    if (!body.data.length) {
      console.log('no builds uploaded yet');
      return;
    }
    const included = new Map((body.included ?? []).map((r) => [`${r.type}/${r.id}`, r.attributes ?? {}]));
    const related = (b, name) => {
      const ref = b.relationships?.[name]?.data;
      return ref ? included.get(`${ref.type}/${ref.id}`) ?? {} : {};
    };
    for (const b of body.data) {
      const a = b.attributes;
      const pre = related(b, 'preReleaseVersion');
      const beta = related(b, 'buildBetaDetail');
      console.log(
        `${b.id}  version ${pre.version ?? '?'} (${a.version})  ${a.processingState}  `
        + `internal=${beta.internalBuildState ?? '?'} external=${beta.externalBuildState ?? '?'}  `
        + `encryption=${a.usesNonExemptEncryption ?? 'unanswered'}  ${a.uploadedDate}${a.expired ? '  EXPIRED' : ''}`,
      );
    }
    // Which tester groups exist, and whether they get new builds on their own.
    const groups = await api(`/v1/betaGroups?filter[app]=${app.id}&fields[betaGroups]=name,isInternalGroup,hasAccessToAllBuilds`);
    for (const g of groups.data ?? []) {
      const a = g.attributes;
      console.log(`group "${a.name}"  ${a.isInternalGroup ? 'internal' : 'external'}  allBuilds=${a.hasAccessToAllBuilds ?? '?'}`);
    }
  },

  /**
   * Every upload Apple received, including the ones that never became a
   * build because processing rejected them — with Apple's error messages
   * (the same ones it emails). An upload can say "UPLOAD SUCCEEDED" and
   * still be rejected here minutes later.
   */
  async uploads(identifier, limit = '10') {
    if (!identifier) throw new Error('usage: uploads <bundle-id> [limit]');
    const apps = await api(`/v1/apps?filter[bundleId]=${encodeURIComponent(identifier)}`);
    const app = apps.data.find((a) => a.attributes.bundleId === identifier);
    if (!app) throw new Error(`no app with bundleId exactly "${identifier}"`);
    const body = await api(`/v1/apps/${app.id}/buildUploads?limit=${encodeURIComponent(limit)}&sort=-uploadedDate`);
    if (!body.data?.length) {
      console.log('no uploads recorded');
      return;
    }
    for (const u of body.data) {
      const a = u.attributes ?? {};
      const state = a.state ?? {};
      console.log(`${u.id}  ${a.cfBundleShortVersionString ?? '?'} (${a.cfBundleVersion ?? '?'})  ${state.state ?? JSON.stringify(state)}  ${a.uploadedDate ?? a.createdDate ?? ''}`);
      for (const kind of ['errors', 'warnings', 'infos']) {
        for (const m of state[kind] ?? []) console.log(`    ${kind.slice(0, -1)}: ${m.code ?? ''} ${m.description ?? m.message ?? JSON.stringify(m)}`);
      }
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

  // ── §18 subscriptions ────────────────────────────────────────────────────

  async subscriptions(identifier) {
    if (!identifier) throw new Error('usage: subscriptions <bundle-id>');
    const app = await appFor(identifier);
    const groups = await api(`/v1/apps/${app.id}/subscriptionGroups?include=subscriptions&limit=50`);
    if (groups.data.length === 0) console.log('no subscription groups');
    for (const group of groups.data) {
      console.log(`group ${group.attributes.referenceName} (${group.id})`);
      const subs = await api(`/v1/subscriptionGroups/${group.id}/subscriptions?limit=50`);
      for (const sub of subs.data) {
        const a = sub.attributes;
        console.log(`  ${a.productId}  ${a.subscriptionPeriod}  state=${a.state}  familySharable=${a.familySharable}  (${sub.id})`);
      }
    }
    const attrs = app.attributes;
    console.log(`notification url (prod):    ${attrs.subscriptionStatusUrl ?? '(none)'} ${attrs.subscriptionStatusUrlVersion ?? ''}`);
    console.log(`notification url (sandbox): ${attrs.subscriptionStatusUrlForSandbox ?? '(none)'} ${attrs.subscriptionStatusUrlVersionForSandbox ?? ''}`);
  },

  /**
   * §18: "one subscription group, two products — monthly and annual, annual
   * at roughly 60% of twelve months"; §23: "roughly €5–7/month". Idempotent:
   * anything that already exists is left alone. Prices are set for the USA
   * base territory and then equalized to every other territory Apple offers.
   */
  /**
   * What each subscription really costs in a few territories — the price
   * StoreKit shows there (customer price, local currency).
   */
  async 'subscription-prices'(identifier, territories = 'USA,DEU,FRA,ITA,ESP,NLD,AUT,CHE,GBR,CAN,AUS') {
    const app = await appFor(identifier);
    const wanted = new Set(territories.split(','));
    const groups = await api(`/v1/apps/${app.id}/subscriptionGroups?limit=50`);
    for (const group of groups.data) {
      const subs = await api(`/v1/subscriptionGroups/${group.id}/subscriptions?limit=50`);
      for (const sub of subs.data) {
        console.log(`${sub.attributes.productId}`);
        const prices = await api(`/v1/subscriptions/${sub.id}/prices?include=subscriptionPricePoint,territory&limit=200`);
        const points = new Map((prices.included ?? []).filter((r) => r.type === 'subscriptionPricePoints').map((r) => [r.id, r.attributes]));
        const territoryCurrency = new Map((prices.included ?? []).filter((r) => r.type === 'territories').map((r) => [r.id, r.attributes.currency]));
        for (const price of prices.data) {
          const territory = price.relationships?.territory?.data?.id;
          if (!wanted.has(territory)) continue;
          const point = points.get(price.relationships?.subscriptionPricePoint?.data?.id) ?? {};
          console.log(`  ${territory}  ${point.customerPrice ?? '?'} ${territoryCurrency.get(territory) ?? ''}  (proceeds ${point.proceeds ?? '?'})`);
        }
        const offers = await api(`/v1/subscriptions/${sub.id}/introductoryOffers?include=territory,subscriptionPricePoint&limit=200`);
        const offerPoints = new Map((offers.included ?? []).filter((r) => r.type === 'subscriptionPricePoints').map((r) => [r.id, r.attributes]));
        const shown = offers.data.filter((o) => wanted.has(o.relationships?.territory?.data?.id));
        console.log(`  introductory offers: ${offers.data.length} territories`);
        for (const o of shown) {
          const a = o.attributes;
          const point = offerPoints.get(o.relationships?.subscriptionPricePoint?.data?.id) ?? {};
          console.log(`    ${o.relationships.territory.data.id}  ${a.offerMode} ${a.numberOfPeriods}× ${a.duration}  ${point.customerPrice ?? 'free'}`);
        }
      }
    }
  },

  /**
   * A real introductory offer for new subscribers: `months` months at the
   * USD price `usd` (pay as you go), in every territory at Apple's equalized
   * local price. Replaces any introductory offer the subscription had.
   */
  /**
   * Sets a subscription's regular price: `usd` in the USA and Apple's
   * equalized price everywhere else, effective now (only safe before anyone
   * subscribes — later changes should go through App Store Connect's price
   * change flow so existing subscribers are notified).
   */
  async 'set-price'(identifier, productId, usd) {
    if (!identifier || !productId || !usd) throw new Error('usage: set-price <bundle-id> <product-id> <usd>');
    const app = await appFor(identifier);
    const groups = await api(`/v1/apps/${app.id}/subscriptionGroups?limit=50`);
    let sub;
    for (const group of groups.data) {
      const subs = await api(`/v1/subscriptionGroups/${group.id}/subscriptions?limit=50`);
      sub = sub ?? subs.data.find((x) => x.attributes.productId === productId);
    }
    if (!sub) throw new Error(`no subscription ${productId}`);
    const points = await api(`/v1/subscriptions/${sub.id}/pricePoints?filter[territory]=USA&limit=800`);
    const point = points.data.find((p) => p.attributes.customerPrice === usd);
    if (!point) throw new Error(`no USA price point at ${usd}`);
    const equal = await api(`/v1/subscriptionPricePoints/${point.id}/equalizations?limit=200&include=territory`);
    const targets = [{ id: point.id, territory: 'USA' }, ...equal.data.map((eq) => ({ id: eq.id, territory: eq.relationships?.territory?.data?.id }))];
    let ok = 0;
    const failed = [];
    for (const target of targets) {
      try {
        await api('/v1/subscriptionPrices', {
          method: 'POST',
          body: { data: { type: 'subscriptionPrices', attributes: { preserveCurrentPrice: false },
            relationships: {
              subscription: { data: { type: 'subscriptions', id: sub.id } },
              subscriptionPricePoint: { data: { type: 'subscriptionPricePoints', id: target.id } },
              territory: { data: { type: 'territories', id: target.territory } },
            } } },
        });
        ok += 1;
      } catch (err) {
        failed.push(`${target.territory}: ${err.message.slice(0, 160)}`);
      }
    }
    console.log(`${productId} → ${usd} USD: ${ok} territories${failed.length ? `, ${failed.length} failed` : ''}`);
    for (const f of failed.slice(0, 10)) console.log(`  ${f}`);
    if (!ok) throw new Error('no price was set');
  },

  async 'set-intro-offer'(identifier, productId, usd, months = '3') {
    if (!identifier || !productId || !usd) throw new Error('usage: set-intro-offer <bundle-id> <product-id> <usd> [months]');
    const app = await appFor(identifier);
    const groups = await api(`/v1/apps/${app.id}/subscriptionGroups?limit=50`);
    let sub;
    for (const group of groups.data) {
      const subs = await api(`/v1/subscriptionGroups/${group.id}/subscriptions?limit=50`);
      sub = sub ?? subs.data.find((x) => x.attributes.productId === productId);
    }
    if (!sub) throw new Error(`no subscription ${productId}`);

    const old = await api(`/v1/subscriptions/${sub.id}/introductoryOffers?limit=200`);
    for (const offer of old.data) await api(`/v1/subscriptionIntroductoryOffers/${offer.id}`, { method: 'DELETE' });
    console.log(`removed ${old.data.length} old introductory offers`);

    const points = await api(`/v1/subscriptions/${sub.id}/pricePoints?filter[territory]=USA&limit=800`);
    const point = points.data.find((p) => p.attributes.customerPrice === usd);
    if (!point) throw new Error(`no USA price point at ${usd}`);
    const equal = await api(`/v1/subscriptionPricePoints/${point.id}/equalizations?limit=200&include=territory`);
    const targets = [{ id: point.id, territory: 'USA' }, ...equal.data.map((eq) => ({ id: eq.id, territory: eq.relationships?.territory?.data?.id }))];
    let ok = 0;
    const failed = [];
    for (const target of targets) {
      try {
        await api('/v1/subscriptionIntroductoryOffers', {
          method: 'POST',
          body: {
            data: {
              type: 'subscriptionIntroductoryOffers',
              attributes: { duration: 'ONE_MONTH', offerMode: 'PAY_AS_YOU_GO', numberOfPeriods: Number(months) },
              relationships: {
                subscription: { data: { type: 'subscriptions', id: sub.id } },
                territory: { data: { type: 'territories', id: target.territory } },
                subscriptionPricePoint: { data: { type: 'subscriptionPricePoints', id: target.id } },
              },
            },
          },
        });
        ok += 1;
      } catch (err) {
        failed.push(`${target.territory}: ${err.message.slice(0, 120)}`);
      }
    }
    console.log(`introductory offer ${usd} USD × ${months} months: ${ok} territories${failed.length ? `, ${failed.length} failed` : ''}`);
    for (const f of failed.slice(0, 10)) console.log(`  ${f}`);
    if (!ok) throw new Error('no introductory offer was created');
  },

  async 'setup-subscriptions'(identifier) {
    if (!identifier) throw new Error('usage: setup-subscriptions <bundle-id>');
    const app = await appFor(identifier);
    const PLANS = [
      { productId: 'com.studentathlete.app.pro.yearly', name: 'Pro Yearly', period: 'ONE_YEAR', level: 1, usd: '39.99',
        description: 'A full year of Athlete OS Pro.' },
      { productId: 'com.studentathlete.app.pro.monthly', name: 'Pro Monthly', period: 'ONE_MONTH', level: 2, usd: '5.99',
        description: 'One month of Athlete OS Pro.' },
    ];

    const groups = await api(`/v1/apps/${app.id}/subscriptionGroups?limit=50`);
    let group = groups.data.find((g) => g.attributes.referenceName === 'Student Athlete Pro');
    if (group) {
      console.log(`group exists (${group.id})`);
    } else {
      group = (await api('/v1/subscriptionGroups', {
        method: 'POST',
        body: { data: { type: 'subscriptionGroups', attributes: { referenceName: 'Student Athlete Pro' },
          relationships: { app: { data: { type: 'apps', id: app.id } } } } },
      })).data;
      console.log(`created group (${group.id})`);
    }
    await tryStep('group localization', async () => {
      const locs = (await api(`/v1/subscriptionGroups/${group.id}/subscriptionGroupLocalizations?limit=50`)).data;
      const en = locs.find((l) => l.attributes.locale === 'en-US');
      if (en) {
        return api(`/v1/subscriptionGroupLocalizations/${en.id}`, { method: 'PATCH',
          body: { data: { type: 'subscriptionGroupLocalizations', id: en.id, attributes: { name: 'Athlete OS Pro' } } } });
      }
      return api('/v1/subscriptionGroupLocalizations', {
        method: 'POST',
        body: { data: { type: 'subscriptionGroupLocalizations', attributes: { name: 'Athlete OS Pro', locale: 'en-US' },
          relationships: { subscriptionGroup: { data: { type: 'subscriptionGroups', id: group.id } } } } },
      });
    });

    const existing = (await api(`/v1/subscriptionGroups/${group.id}/subscriptions?limit=50`)).data;
    for (const plan of PLANS) {
      let sub = existing.find((s) => s.attributes.productId === plan.productId);
      if (sub) {
        console.log(`${plan.productId} exists (${sub.id}, ${sub.attributes.state})`);
      } else {
        sub = (await api('/v1/subscriptions', {
          method: 'POST',
          body: { data: { type: 'subscriptions',
            attributes: { name: plan.name, productId: plan.productId, subscriptionPeriod: plan.period, familySharable: true,
              groupLevel: plan.level, reviewNote: 'No purchase is needed to review Pro: the demo account in the review notes already has Pro granted server-side.' },
            relationships: { group: { data: { type: 'subscriptionGroups', id: group.id } } } } },
        })).data;
        console.log(`created ${plan.productId} (${sub.id})`);
      }

      await tryStep(`${plan.productId} localization`, async () => {
        const locs = (await api(`/v1/subscriptions/${sub.id}/subscriptionLocalizations?limit=50`)).data;
        const en = locs.find((l) => l.attributes.locale === 'en-US');
        if (en) {
          return api(`/v1/subscriptionLocalizations/${en.id}`, { method: 'PATCH',
            body: { data: { type: 'subscriptionLocalizations', id: en.id, attributes: { name: plan.name, description: plan.description } } } });
        }
        return api('/v1/subscriptionLocalizations', {
          method: 'POST',
          body: { data: { type: 'subscriptionLocalizations', attributes: { name: plan.name, locale: 'en-US', description: plan.description },
            relationships: { subscription: { data: { type: 'subscriptions', id: sub.id } } } } },
        });
      });

      await tryStep(`${plan.productId} availability`, async () => {
        const territories = await api('/v1/territories?limit=200');
        return api('/v1/subscriptionAvailabilities', {
          method: 'POST',
          body: { data: { type: 'subscriptionAvailabilities', attributes: { availableInNewTerritories: true },
            relationships: {
              subscription: { data: { type: 'subscriptions', id: sub.id } },
              availableTerritories: { data: territories.data.map((t) => ({ type: 'territories', id: t.id })) },
            } } },
        });
      });

      await tryStep(`${plan.productId} price ${plan.usd} USD + equalized territories`, async () => {
        const points = await api(`/v1/subscriptions/${sub.id}/pricePoints?filter[territory]=USA&limit=800`);
        const point = points.data.find((p) => p.attributes.customerPrice === plan.usd);
        if (!point) throw new Error(`no USA price point at ${plan.usd}`);
        const setPrice = (pricePointId, territory) => api('/v1/subscriptionPrices', {
          method: 'POST',
          body: { data: { type: 'subscriptionPrices', attributes: { preserveCurrentPrice: false },
            relationships: {
              subscription: { data: { type: 'subscriptions', id: sub.id } },
              subscriptionPricePoint: { data: { type: 'subscriptionPricePoints', id: pricePointId } },
              ...(territory ? { territory: { data: { type: 'territories', id: territory } } } : {}),
            } } },
        });
        await setPrice(point.id, 'USA');
        const equal = await api(`/v1/subscriptionPricePoints/${point.id}/equalizations?limit=200&include=territory`);
        let ok = 0;
        let failed = 0;
        for (const eq of equal.data) {
          try {
            await setPrice(eq.id, eq.relationships?.territory?.data?.id);
            ok += 1;
          } catch {
            failed += 1;
          }
        }
        return `USA + ${ok} equalized territories${failed ? `, ${failed} failed` : ''}`;
      });
    }
    console.log('');
    await commands.subscriptions(identifier);
  },

  /**
   * Uploads every PNG in <dir> (sorted by name) to the editable App Store
   * version's en-US screenshots, replacing what's there. The display type
   * comes from the pixel size: 6.9"/6.7" iPhone, 13"/12.9" iPad and Apple Watch.
   */
  async 'upload-screenshots'(identifier, dir) {
    if (!identifier || !dir) throw new Error('usage: upload-screenshots <bundle-id> <dir>');
    const app = await appFor(identifier);
    const versions = await api(`/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS`);
    const version = versions.data.find((v) => ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED'].includes(v.attributes.appStoreState));
    if (!version) throw new Error('no editable App Store version');
    const locs = await api(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`);
    const loc = locs.data.find((l) => l.attributes.locale === 'en-US');
    if (!loc) throw new Error('no en-US localization');

    const typeFor = (width, height) => {
      const key = `${Math.min(width, height)}x${Math.max(width, height)}`;
      if (['1320x2868', '1290x2796'].includes(key)) return 'APP_IPHONE_67';
      if (['2064x2752', '2048x2732'].includes(key)) return 'APP_IPAD_PRO_3GEN_129';
      if (['416x496', '374x446'].includes(key)) return 'APP_WATCH_SERIES_10';
      if (['410x502', '422x514'].includes(key)) return 'APP_WATCH_ULTRA';
      if (['396x484', '352x430'].includes(key)) return 'APP_WATCH_SERIES_7';
      return null;
    };
    const pngSize = (buffer) => ({ width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) });

    const files = fs.readdirSync(dir).filter((f) => f.endsWith('.png')).sort();
    const byType = new Map();
    for (const file of files) {
      const buffer = fs.readFileSync(path.join(dir, file));
      const { width, height } = pngSize(buffer);
      const type = typeFor(width, height);
      if (!type) { console.log(`  skip ${file} (${width}x${height})`); continue; }
      if (!byType.has(type)) byType.set(type, []);
      if (byType.get(type).length < 10) byType.get(type).push({ file, buffer });
    }

    const sets = await api(`/v1/appStoreVersionLocalizations/${loc.id}/appScreenshotSets?limit=50`);
    for (const [type, shots] of byType) {
      let set = sets.data.find((s) => s.attributes.screenshotDisplayType === type);
      if (!set) {
        set = (await api('/v1/appScreenshotSets', { method: 'POST', body: { data: { type: 'appScreenshotSets',
          attributes: { screenshotDisplayType: type },
          relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: loc.id } } } } } })).data;
      }
      const old = await api(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`);
      for (const shot of old.data) await api(`/v1/appScreenshots/${shot.id}`, { method: 'DELETE' });
      for (const { file, buffer } of shots) {
        const reserved = (await api('/v1/appScreenshots', { method: 'POST', body: { data: { type: 'appScreenshots',
          attributes: { fileName: file, fileSize: buffer.length },
          relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: set.id } } } } } })).data;
        for (const op of reserved.attributes.uploadOperations) {
          const headers = Object.fromEntries((op.requestHeaders ?? []).map((h) => [h.name, h.value]));
          const res = await fetch(op.url, { method: op.method, headers, body: buffer.subarray(op.offset, op.offset + op.length) });
          if (!res.ok) throw new Error(`upload ${file}: ${res.status}`);
        }
        await api(`/v1/appScreenshots/${reserved.id}`, { method: 'PATCH', body: { data: { type: 'appScreenshots', id: reserved.id,
          attributes: { uploaded: true, sourceFileChecksum: crypto.createHash('md5').update(buffer).digest('hex') } } } });
        console.log(`  ok: ${type} ${file}`);
      }
    }
  },

  /** The paywall screenshot App Review needs for each subscription (else "Missing Metadata"). */
  async 'upload-review-screenshot'(identifier, file) {
    if (!identifier || !file) throw new Error('usage: upload-review-screenshot <bundle-id> <png>');
    const app = await appFor(identifier);
    const buffer = fs.readFileSync(file);
    const groups = await api(`/v1/apps/${app.id}/subscriptionGroups?limit=50`);
    for (const group of groups.data) {
      const subs = await api(`/v1/subscriptionGroups/${group.id}/subscriptions?limit=50`);
      for (const sub of subs.data) {
        await tryStep(`${sub.attributes.productId} review screenshot`, async () => {
          const existing = await api(`/v1/subscriptions/${sub.id}/appStoreReviewScreenshot`).catch(() => ({ data: null }));
          if (existing.data) await api(`/v1/subscriptionAppStoreReviewScreenshots/${existing.data.id}`, { method: 'DELETE' });
          const reserved = (await api('/v1/subscriptionAppStoreReviewScreenshots', { method: 'POST', body: { data: {
            type: 'subscriptionAppStoreReviewScreenshots',
            attributes: { fileName: path.basename(file), fileSize: buffer.length },
            relationships: { subscription: { data: { type: 'subscriptions', id: sub.id } } } } } })).data;
          for (const op of reserved.attributes.uploadOperations) {
            const headers = Object.fromEntries((op.requestHeaders ?? []).map((h) => [h.name, h.value]));
            const res = await fetch(op.url, { method: op.method, headers, body: buffer.subarray(op.offset, op.offset + op.length) });
            if (!res.ok) throw new Error(`upload: ${res.status}`);
          }
          await api(`/v1/subscriptionAppStoreReviewScreenshots/${reserved.id}`, { method: 'PATCH', body: { data: {
            type: 'subscriptionAppStoreReviewScreenshots', id: reserved.id,
            attributes: { uploaded: true, sourceFileChecksum: crypto.createHash('md5').update(buffer).digest('hex') } } } });
          return 'uploaded';
        });
      }
    }
    await commands.subscriptions(identifier);
  },

  /** §18: App Store Server Notifications V2 for production and sandbox. */
  async 'set-notification-url'(identifier, url) {
    if (!identifier || !url) throw new Error('usage: set-notification-url <bundle-id> <url>');
    const app = await appFor(identifier);
    await api(`/v1/apps/${app.id}`, {
      method: 'PATCH',
      body: { data: { type: 'apps', id: app.id, attributes: {
        subscriptionStatusUrl: url, subscriptionStatusUrlVersion: 'V2',
        subscriptionStatusUrlForSandbox: url, subscriptionStatusUrlVersionForSandbox: 'V2',
      } } },
    });
    console.log(`notification url set to ${url} (V2, production + sandbox)`);
  },
};

async function appFor(identifier) {
  const apps = await api(`/v1/apps?filter[bundleId]=${encodeURIComponent(identifier)}`);
  const app = apps.data.find((a) => a.attributes.bundleId === identifier);
  if (!app) throw new Error(`no App Store Connect app for ${identifier} — create it in the web UI first`);
  return app;
}

/** One idempotent step: an "already exists"-style 409 is fine, anything else is reported, never fatal. */
async function tryStep(label, fn) {
  try {
    const result = await fn();
    console.log(`  ok: ${label}${typeof result === 'string' ? ` — ${result}` : ''}`);
  } catch (err) {
    const benign = /409|already|duplicate/i.test(err.message);
    console.log(`  ${benign ? 'exists' : 'FAILED'}: ${label} — ${err.message}`);
  }
}

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
