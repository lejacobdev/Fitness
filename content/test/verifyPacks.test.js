import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SCRIPT = path.join(HERE, '../scripts/verify-packs.mjs');

function sha256(content) {
  return crypto.createHash('sha256').update(content, 'utf8').digest('hex');
}

/** A minimal, internally-consistent one-pack dist/ directory for fixtures. */
function makeValidDist(dir) {
  const content = JSON.stringify({ slug: 'core', version: 1, items: [] });
  const checksum = sha256(content);
  fs.writeFileSync(path.join(dir, 'core.json'), content);
  fs.writeFileSync(path.join(dir, 'manifest.json'), JSON.stringify({
    generatedAt: new Date().toISOString(),
    packs: [{ slug: 'core', version: 1, file: 'core.json', sizeBytes: Buffer.byteLength(content), checksum }],
  }));
}

function tmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'packs-test-'));
}

function run(dir) {
  try {
    const stdout = execFileSync('node', [SCRIPT, dir], { encoding: 'utf8' });
    return { code: 0, stdout };
  } catch (err) {
    return { code: err.status, stdout: err.stdout, stderr: err.stderr };
  }
}

test('a valid, untampered dist directory passes', () => {
  const dir = tmpDir();
  makeValidDist(dir);
  const result = run(dir);
  assert.equal(result.code, 0, result.stderr);
  assert.match(result.stdout, /OK: 1 packs verified/);
});

test('a tampered pack body (checksum no longer matches) fails', () => {
  const dir = tmpDir();
  makeValidDist(dir);
  fs.writeFileSync(path.join(dir, 'core.json'), JSON.stringify({ slug: 'core', version: 1, items: [{ injected: true }] }));
  const result = run(dir);
  assert.equal(result.code, 1);
  assert.match(result.stderr, /checksum .* does not match/);
});

test('a pack file listed in the manifest but missing on disk fails', () => {
  const dir = tmpDir();
  makeValidDist(dir);
  fs.rmSync(path.join(dir, 'core.json'));
  const result = run(dir);
  assert.equal(result.code, 1);
  assert.match(result.stderr, /listed in manifest but not present/);
});

test('an orphan file not listed in the manifest fails', () => {
  const dir = tmpDir();
  makeValidDist(dir);
  fs.writeFileSync(path.join(dir, 'stray.json'), '{}');
  const result = run(dir);
  assert.equal(result.code, 1);
  assert.match(result.stderr, /stray\.json .* not listed in manifest/);
});

test('a pack body whose own slug disagrees with its manifest entry fails', () => {
  const dir = tmpDir();
  makeValidDist(dir);
  const content = JSON.stringify({ slug: 'not-core', version: 1, items: [] });
  // Overwrite with content whose OWN checksum matches (so that check passes)
  // but whose internal slug field is wrong — a distinct failure mode from
  // simple tampering, e.g. two packs accidentally built from the same source.
  const checksum = sha256(content);
  fs.writeFileSync(path.join(dir, 'core.json'), content);
  const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));
  manifest.packs[0].checksum = checksum;
  manifest.packs[0].sizeBytes = Buffer.byteLength(content);
  fs.writeFileSync(path.join(dir, 'manifest.json'), JSON.stringify(manifest));

  const result = run(dir);
  assert.equal(result.code, 1);
  assert.match(result.stderr, /own slug .* does not match/);
});

test('a real build\'s output (the actual dist/ this repo produces) verifies clean', () => {
  const distDir = path.join(HERE, '../dist');
  if (!fs.existsSync(path.join(distDir, 'manifest.json'))) {
    // `npm run build` has not been run in this environment yet — not this
    // test's job to build it, just to check it when present.
    return;
  }
  const result = run(distDir);
  assert.equal(result.code, 0, result.stderr);
});
