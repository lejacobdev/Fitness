#!/usr/bin/env node
/**
 * Re-hashes every pack in a built dist/ directory and checks it against
 * manifest.json — what `packs.yml` runs before publishing, and what the
 * client should do after downloading a pack before trusting its contents.
 *
 *   node scripts/verify-packs.mjs [dist-dir]
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const distDir = path.resolve(process.argv[2] ?? 'dist');

function sha256(content) {
  return crypto.createHash('sha256').update(content, 'utf8').digest('hex');
}

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exitCode = 1;
}

const manifestPath = path.join(distDir, 'manifest.json');
if (!fs.existsSync(manifestPath)) {
  console.error(`no manifest.json in ${distDir} — run \`npm run build\` first`);
  process.exit(1);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
if (!Array.isArray(manifest.packs) || manifest.packs.length === 0) {
  fail('manifest.packs is empty');
}

const seenSlugs = new Set();
for (const entry of manifest.packs) {
  for (const field of ['slug', 'version', 'file', 'sizeBytes', 'checksum']) {
    if (entry[field] === undefined) fail(`${entry.slug ?? '<unknown>'}: manifest entry missing ${field}`);
  }
  if (seenSlugs.has(entry.slug)) fail(`duplicate manifest entry for ${entry.slug}`);
  seenSlugs.add(entry.slug);

  const filePath = path.join(distDir, entry.file);
  if (!fs.existsSync(filePath)) {
    fail(`${entry.slug}: ${entry.file} listed in manifest but not present in ${distDir}`);
    continue;
  }
  const content = fs.readFileSync(filePath, 'utf8');

  const actualSize = Buffer.byteLength(content, 'utf8');
  if (actualSize !== entry.sizeBytes) {
    fail(`${entry.slug}: size ${actualSize} does not match manifest's ${entry.sizeBytes}`);
  }

  const actualChecksum = sha256(content);
  if (actualChecksum !== entry.checksum) {
    fail(`${entry.slug}: checksum ${actualChecksum} does not match manifest's ${entry.checksum}`);
  }

  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (err) {
    fail(`${entry.slug}: ${entry.file} is not valid JSON (${err.message})`);
    continue;
  }
  if (parsed.slug !== entry.slug) {
    fail(`${entry.slug}: pack body's own slug ${JSON.stringify(parsed.slug)} does not match its manifest entry`);
  }
}

// Every file in dist/ other than manifest.json should be listed — an orphan
// file is either stale (a renamed pack) or a build that forgot to register it.
const manifestFiles = new Set(manifest.packs.map((p) => p.file));
for (const file of fs.readdirSync(distDir)) {
  if (file === 'manifest.json') continue;
  if (!manifestFiles.has(file)) fail(`${file} exists in ${distDir} but is not listed in manifest.json`);
}

if (process.exitCode === 1) {
  console.error(`\nverification failed for ${distDir}`);
} else {
  console.log(`OK: ${manifest.packs.length} packs verified in ${path.relative(process.cwd(), distDir) || '.'}`);
}
