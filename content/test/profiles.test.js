import assert from 'node:assert/strict';
import test from 'node:test';

import { CATALOGUE } from '../src/catalogue.js';
import { HAND_PROFILES, PATTERNS, ROLES, profileFor } from '../src/profiles.js';

test('every base exercise in the core library is tagged by hand', () => {
  const base = CATALOGUE.filter((i) => i.kind === 'exercise' && !i.baseSlug);
  const missing = base.filter((i) => !HAND_PROFILES.has(i.slug)).map((i) => i.slug);
  assert.deepEqual(missing, []);
});

test('no hand profile names an exercise that does not exist', () => {
  const slugs = new Set(CATALOGUE.map((i) => i.slug));
  assert.deepEqual([...HAND_PROFILES.keys()].filter((s) => !slugs.has(s)), []);
});

test('every item gets a valid profile', () => {
  for (const item of CATALOGUE) {
    const p = profileFor(item);
    assert.ok(PATTERNS.includes(p.pattern), `${item.slug}: pattern ${p.pattern}`);
    assert.ok(ROLES.includes(p.role), `${item.slug}: role ${p.role}`);
    assert.ok(p.regions.length > 0 && p.regions.every((r) => ['lower', 'upper', 'trunk'].includes(r)), `${item.slug}: regions`);
    for (const [key, max] of [['fatigue', 5], ['impact', 3], ['technique', 3], ['legLoad', 3]]) {
      assert.ok(Number.isInteger(p[key]) && p[key] >= (key === 'fatigue' || key === 'technique' ? 1 : 0) && p[key] <= max, `${item.slug}: ${key} ${p[key]}`);
    }
    assert.ok(typeof p.group === 'string' && p.group.length > 0, `${item.slug}: group`);
    if (p.role === 'conditioning' && item.kind === 'exercise') assert.ok(p.conditioning, `${item.slug}: conditioning type`);
  }
});

test('the session roles a gym day needs all exist in the library', () => {
  const core = CATALOGUE.filter((i) => i.kind === 'exercise').map(profileFor);
  for (const role of ['prep', 'power', 'speed', 'primary', 'secondary', 'accessory', 'trunk', 'conditioning', 'mobility', 'recovery']) {
    assert.ok(core.filter((p) => p.role === role).length >= 3, `role ${role}`);
  }
  for (const pattern of ['squat', 'hinge', 'push', 'pull', 'unilateral-lower', 'carry', 'rotation', 'anti-rotation', 'jump', 'throw', 'sprint']) {
    assert.ok(core.some((p) => p.pattern === pattern), `pattern ${pattern}`);
  }
});
