import assert from 'node:assert/strict';
import test from 'node:test';

import { expandCatalogue } from '../src/expand.js';
import { EXERCISES } from '../src/items/exercises.js';
import { isMuscle } from '../src/muscles.js';
import { isPosePattern } from '../src/poses.js';
import { isProp } from '../src/props.js';
import { isQuality, QUALITY_SLUGS } from '../src/qualities.js';
import { itemAvailableAt, itemEquipmentLevel, validateItem } from '../src/schema.js';

const CATALOGUE = expandCatalogue(EXERCISES);
const BY_SLUG = new Map(CATALOGUE.map((i) => [i.slug, i]));

test('base exercise count is a real, growing base (not a stub)', () => {
  assert.ok(EXERCISES.length >= 40, `only ${EXERCISES.length} base exercises`);
});

test('every base exercise slug is unique', () => {
  const slugs = EXERCISES.map((i) => i.slug);
  assert.equal(new Set(slugs).size, slugs.length);
});

test('every expanded catalogue item validates with zero errors — §7\'s build-blocking test', () => {
  const errors = [];
  for (const item of CATALOGUE) validateItem(item, errors);
  assert.deepEqual(errors, []);
});

test('every expanded catalogue slug is unique', () => {
  const slugs = CATALOGUE.map((i) => i.slug);
  assert.equal(new Set(slugs).size, slugs.length);
});

test('§7: every quality has at least one bodyweight-only item at weight >= 0.5', () => {
  const missing = QUALITY_SLUGS.filter((q) => !CATALOGUE.some(
    (item) => itemEquipmentLevel(item) === 'none' && (item.qualities[q] ?? 0) >= 0.5,
  ));
  assert.deepEqual(missing, [], `qualities with no bodyweight path: ${missing.join(', ')}`);
});

test('every quality slug referenced anywhere in the catalogue is real', () => {
  for (const item of CATALOGUE) {
    for (const q of Object.keys(item.qualities)) {
      assert.ok(isQuality(q), `${item.slug} references unknown quality ${q}`);
    }
  }
});

test('every muscle slug referenced anywhere in the catalogue is real', () => {
  for (const item of CATALOGUE) {
    for (const m of Object.keys(item.muscles)) {
      assert.ok(isMuscle(m), `${item.slug} references unknown muscle ${m}`);
    }
  }
});

test('every startPose/endPose resolves to a real pose pattern', () => {
  for (const item of CATALOGUE) {
    assert.ok(isPosePattern(item.startPose), `${item.slug}.startPose ${item.startPose} unknown`);
    assert.ok(isPosePattern(item.endPose), `${item.slug}.endPose ${item.endPose} unknown`);
  }
});

test('every declared prop resolves to a real §9 prop', () => {
  for (const item of CATALOGUE) {
    if (item.prop !== undefined) assert.ok(isProp(item.prop), `${item.slug}.prop ${item.prop} unknown`);
  }
});

test('every substitutes/progressions/regressions reference resolves within the catalogue', () => {
  const missing = [];
  for (const item of EXERCISES) {
    for (const field of ['substitutes', 'progressions', 'regressions']) {
      for (const ref of item[field]) {
        if (!BY_SLUG.has(ref)) missing.push(`${item.slug}.${field} -> ${ref}`);
      }
    }
  }
  assert.deepEqual(missing, []);
});

test('every reference is to a real base item slug, not a stray derived-only slug', () => {
  // References should point at base items (the canonical, stable target), not
  // at one specific equipment/tempo derivative — a derivative's own baseSlug
  // resolving is what expand.test.js already covers.
  const baseSlugs = new Set(EXERCISES.map((i) => i.slug));
  for (const item of EXERCISES) {
    for (const field of ['substitutes', 'progressions', 'regressions']) {
      for (const ref of item[field]) {
        assert.ok(baseSlugs.has(ref), `${item.slug}.${field} -> ${ref} is not a base item slug`);
      }
    }
  }
});

test('no item lists itself as its own substitute, progression or regression', () => {
  for (const item of EXERCISES) {
    for (const field of ['substitutes', 'progressions', 'regressions']) {
      assert.ok(!item[field].includes(item.slug), `${item.slug}.${field} includes itself`);
    }
  }
});

test('COACHED items all carry minAge >= 15 (§2, §7)', () => {
  for (const item of EXERCISES) {
    if (item.supervisionLevel === 'COACHED') {
      assert.ok(item.minAge >= 15, `${item.slug} is COACHED but minAge is ${item.minAge}`);
    }
  }
});

test('every dose load description avoids %1RM language for every item (§2)', () => {
  for (const item of EXERCISES) {
    const load = item.defaultDose.load;
    if (typeof load === 'string') {
      assert.doesNotMatch(load, /%|1rm|one[- ]rep/i, `${item.slug} dose.load reads as a %1RM: ${load}`);
    }
  }
});

test('reps-kind doses PRIMARILY targeting a strength quality stay within the NSCA-cited youth envelope of 1-3 sets, 6-15 reps (§2)', () => {
  // Only items whose *primary* (weight 1.0) quality is a strength quality are
  // held to this envelope. An item where a strength quality is a secondary
  // 0.5 contributor — a jump squat is genuinely a power exercise that happens
  // to also load the legs — is governed by its own primary quality's dosing
  // norms instead; power work legitimately uses fewer reps and more sets.
  const strengthQualities = ['lower-body-strength', 'upper-body-push', 'upper-body-pull'];
  for (const item of EXERCISES) {
    const isStrengthPrimary = strengthQualities.some((q) => (item.qualities[q] ?? 0) >= 0.95);
    if (isStrengthPrimary && item.defaultDose.kind === 'reps') {
      assert.ok(item.defaultDose.sets >= 1 && item.defaultDose.sets <= 3,
        `${item.slug} has ${item.defaultDose.sets} sets, expected 1-3`);
      assert.ok(item.defaultDose.reps >= 6 && item.defaultDose.reps <= 15,
        `${item.slug} has ${item.defaultDose.reps} reps, expected 6-15`);
    }
  }
});

test('every plyometric (contacts-kind) item stays under a sane per-set ceiling (§7)', () => {
  for (const item of CATALOGUE) {
    if (item.defaultDose.kind === 'contacts') {
      assert.ok(item.defaultDose.contacts <= 40, `${item.slug} prescribes ${item.defaultDose.contacts} contacts in one set`);
    }
  }
});

test('an athlete with zero equipment still gets at least one exercise per quality group', () => {
  const groups = { speed: [], power: [], strength: [], endurance: [], control: [] };
  // group membership pulled directly to avoid a second import cycle in this file
  const groupOf = {
    acceleration: 'speed', 'max-velocity': 'speed', 'change-of-direction': 'speed', 'lateral-power': 'speed', deceleration: 'speed',
    'vertical-power': 'power', 'horizontal-power': 'power', 'rotational-power': 'power', 'overhead-power': 'power', 'reactive-strength': 'power',
    'lower-body-strength': 'strength', 'upper-body-push': 'strength', 'upper-body-pull': 'strength', 'trunk-anti-rotation': 'strength', grip: 'strength',
    'aerobic-base': 'endurance', 'anaerobic-capacity': 'endurance', 'repeat-sprint': 'endurance',
    'single-leg-stability': 'control', 'hip-mobility': 'control', 'shoulder-stability': 'control', 'ankle-stiffness': 'control', 'landing-mechanics': 'control',
  };
  for (const item of CATALOGUE) {
    if (itemEquipmentLevel(item) !== 'none') continue;
    for (const [q, w] of Object.entries(item.qualities)) {
      if (w >= 0.5 && groupOf[q]) groups[groupOf[q]].push(item.slug);
    }
  }
  for (const [group, items] of Object.entries(groups)) {
    assert.ok(items.length >= 1, `no bodyweight item develops any ${group} quality`);
  }
});

test('itemAvailableAt is consistent: a "full" item is never available at "none"', () => {
  for (const item of CATALOGUE) {
    if (itemEquipmentLevel(item) === 'full') {
      assert.equal(itemAvailableAt(item, 'none'), false, `${item.slug} is full-equipment but reads available at none`);
    }
  }
});
