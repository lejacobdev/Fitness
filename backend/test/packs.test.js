import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { createApp } from '../src/app.js';

function tmpPacksDir() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'packs-test-'));
  fs.writeFileSync(path.join(dir, 'core.json'), JSON.stringify({ slug: 'core', version: 1, items: [] }));
  fs.writeFileSync(path.join(dir, 'manifest.json'), JSON.stringify({ packs: [{ slug: 'core', file: 'core.json' }] }));
  return dir;
}

async function serve(app) {
  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });
  const { port } = server.address();
  return { url: `http://127.0.0.1:${port}`, close: () => new Promise((r) => server.close(r)) };
}

test('a pack file is served with the right content and an ETag (§3)', async () => {
  const { url, close } = await serve(createApp({ packsDir: tmpPacksDir() }));
  try {
    const res = await fetch(`${url}/packs/core.json`, { signal: AbortSignal.timeout(2000) });
    assert.equal(res.status, 200);
    assert.ok(res.headers.get('etag'), 'response should carry an ETag');
    const body = await res.json();
    assert.equal(body.slug, 'core');
  } finally {
    await close();
  }
});

test('a conditional GET with a matching If-None-Match returns 304 with no body', async () => {
  // Deliberately node:http, not fetch(): Node's built-in fetch() (undici)
  // sends `Cache-Control: no-cache` on every request by default, and the
  // `fresh` package Express uses correctly (RFC 2616 §14.9.4 "end-to-end
  // reload") treats that as "always revalidate, ignore ETag" — so a
  // fetch()-based version of this test always saw 200, not because the
  // route was wrong (curl against the same server got a real 304), but
  // because fetch() itself opts out of conditional-GET semantics by default.
  // node:http sends no such header, so it actually exercises the ETag path.
  const { url, close } = await serve(createApp({ packsDir: tmpPacksDir() }));
  try {
    const first = await httpGet(`${url}/packs/manifest.json`);
    assert.equal(first.statusCode, 200);
    const etag = first.headers.etag;
    assert.ok(etag);

    const second = await httpGet(`${url}/packs/manifest.json`, { 'if-none-match': etag });
    assert.equal(second.statusCode, 304);
  } finally {
    await close();
  }
});

function httpGet(url, headers = {}) {
  return new Promise((resolve, reject) => {
    http.get(url, { headers, timeout: 2000 }, (res) => {
      res.resume(); // drain, but 304/body content isn't what this test checks
      res.on('end', () => resolve(res));
    }).on('error', reject);
  });
}

test('a pack that does not exist 404s rather than serving a directory listing', async () => {
  const { url, close } = await serve(createApp({ packsDir: tmpPacksDir() }));
  try {
    const res = await fetch(`${url}/packs/nonexistent-sport.json`, { signal: AbortSignal.timeout(2000) });
    assert.equal(res.status, 404);
    const res2 = await fetch(`${url}/packs/`, { signal: AbortSignal.timeout(2000) });
    assert.notEqual(res2.status, 200, 'directory listing should not be served (index: false)');
  } finally {
    await close();
  }
});

test('the /packs route is simply absent (404, not a crash) when packsDir does not exist', async () => {
  const { url, close } = await serve(createApp({ packsDir: '/nonexistent/path/for/real' }));
  try {
    const res = await fetch(`${url}/packs/core.json`, { signal: AbortSignal.timeout(2000) });
    assert.equal(res.status, 404);
  } finally {
    await close();
  }
});

test('the /packs route is absent when packsDir is not configured at all', async () => {
  const { url, close } = await serve(createApp({}));
  try {
    const res = await fetch(`${url}/packs/core.json`, { signal: AbortSignal.timeout(2000) });
    assert.equal(res.status, 404);
  } finally {
    await close();
  }
});

test('a real build\'s content/dist output (when present) is served correctly end to end', async () => {
  const distDir = path.join(import.meta.dirname, '../../content/dist');
  if (!fs.existsSync(path.join(distDir, 'manifest.json'))) {
    return; // `npm run build` has not been run in content/ in this environment
  }
  const { url, close } = await serve(createApp({ packsDir: distDir }));
  try {
    const res = await fetch(`${url}/packs/manifest.json`, { signal: AbortSignal.timeout(2000) });
    assert.equal(res.status, 200);
    const manifest = await res.json();
    assert.ok(manifest.packs.length > 0);

    const corePack = await fetch(`${url}/packs/core.json`, { signal: AbortSignal.timeout(2000) });
    assert.equal(corePack.status, 200);
  } finally {
    await close();
  }
});
