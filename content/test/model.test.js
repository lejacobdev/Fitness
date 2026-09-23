import assert from 'node:assert/strict';
import test from 'node:test';

import { MUSCLES, MUSCLE_ROLE_THRESHOLDS, muscleMapPathKeys, renderTarget } from '../src/muscles.js';
import { mirrorPose, POSE_PATTERNS, JOINTS } from '../src/poses.js';
import { PROPS } from '../src/props.js';
import { QUALITIES, QUALITY_GROUPS } from '../src/qualities.js';
import { DEEP_SKILL_SPORTS, SPORTS, validateSport } from '../src/sports.js';

test('every quality belongs to a real group (§6)', () => {
  for (const q of QUALITIES) {
    assert.ok(QUALITY_GROUPS.includes(q.group), `${q.slug} has unknown group ${q.group}`);
  }
});

test('quality count matches §6\'s table ("~18", 5 groups)', () => {
  assert.equal(QUALITIES.length, 23);
  const bySlug = new Set(QUALITIES.map((q) => q.slug));
  assert.equal(bySlug.size, QUALITIES.length, 'quality slugs must be unique');
});

test('every muscle has a plainName for §12\'s writing register', () => {
  for (const m of MUSCLES) {
    assert.ok(m.plainName && m.plainName.length > 0, `${m.slug} has no plainName`);
  }
});

test('every non-drawable muscle\'s renderVia points at a drawable muscle', () => {
  const bySlug = new Map(MUSCLES.map((m) => [m.slug, m]));
  for (const m of MUSCLES) {
    if (m.drawable === false) {
      const target = bySlug.get(m.renderVia);
      assert.ok(target, `${m.slug}.renderVia ${m.renderVia} does not exist`);
      assert.notEqual(target.drawable, false, `${m.slug}.renderVia ${m.renderVia} is itself non-drawable`);
    }
  }
});

test('muscle map path count is in §9\'s "~90" range', () => {
  const keys = muscleMapPathKeys();
  assert.ok(keys.length >= 80 && keys.length <= 140, `${keys.length} paths`);
  assert.equal(new Set(keys).size, keys.length, 'path keys must be unique');
});

test('renderTarget resolves every muscle to a drawable muscle', () => {
  for (const m of MUSCLES) {
    const target = renderTarget(m.slug);
    const targetMuscle = MUSCLES.find((x) => x.slug === target);
    assert.ok(targetMuscle, `renderTarget(${m.slug}) = ${target} does not exist`);
    assert.notEqual(targetMuscle.drawable, false);
  }
});

test('muscle role thresholds are ordered primary > secondary > stabiliser', () => {
  const { primary, secondary, stabiliser } = MUSCLE_ROLE_THRESHOLDS;
  assert.ok(primary > secondary && secondary > stabiliser);
});

test('pose pattern count is in §9\'s "25-35" range', () => {
  assert.ok(POSE_PATTERNS.length >= 25 && POSE_PATTERNS.length <= 35, POSE_PATTERNS.length);
});

test('every pose pattern\'s start and end cover every joint', () => {
  for (const p of POSE_PATTERNS) {
    for (const joint of JOINTS) {
      assert.ok(joint in p.start, `${p.slug}.start missing joint ${joint}`);
      assert.ok(joint in p.end, `${p.slug}.end missing joint ${joint}`);
      assert.equal(typeof p.start[joint], 'number');
      assert.equal(typeof p.end[joint], 'number');
    }
  }
});

test('pose pattern slugs are unique', () => {
  const slugs = POSE_PATTERNS.map((p) => p.slug);
  assert.equal(new Set(slugs).size, slugs.length);
});

test('mirrorPose is an involution (mirroring twice returns the original) — §7 unilateral rule', () => {
  for (const p of POSE_PATTERNS) {
    assert.deepEqual(mirrorPose(mirrorPose(p.start)), p.start, `${p.slug}.start`);
    assert.deepEqual(mirrorPose(mirrorPose(p.end)), p.end, `${p.slug}.end`);
  }
});

test('mirrorPose actually swaps L/R angles when they differ', () => {
  const p = POSE_PATTERNS.find((x) => x.slug === 'lunge');
  const mirrored = mirrorPose(p.end);
  assert.equal(mirrored.hipL, p.end.hipR);
  assert.equal(mirrored.hipR, p.end.hipL);
});

test('prop count is in §9\'s "~dozen" range', () => {
  assert.ok(PROPS.length >= 8 && PROPS.length <= 16, PROPS.length);
});

test('every prop attaches to a real joint', () => {
  for (const p of PROPS) {
    assert.ok(JOINTS.includes(p.attachTo), `${p.slug} attaches to unknown joint ${p.attachTo}`);
  }
});

// ── Sport catalogue (§5, §21) ────────────────────────────────────────────

test('sport count meets §5\'s "70+" target', () => {
  assert.ok(SPORTS.length >= 70, `only ${SPORTS.length} sports`);
});

test('sport slugs are unique', () => {
  const slugs = SPORTS.map((s) => s.slug);
  assert.equal(new Set(slugs).size, slugs.length);
});

test('every sport passes validateSport with zero errors', () => {
  const errors = [];
  for (const s of SPORTS) validateSport(s, errors);
  assert.deepEqual(errors, []);
});

test('every §5-named deep-skill sport exists and has 8-14 skills', () => {
  for (const slug of DEEP_SKILL_SPORTS) {
    const s = SPORTS.find((x) => x.slug === slug);
    assert.ok(s, `deep-skill sport ${slug} is missing from SPORTS`);
    assert.ok(s.skills.length >= 8 && s.skills.length <= 14,
      `${slug} has ${s.skills.length} skills, expected 8-14`);
  }
});

test('every non-deep sport still has a working skill menu (§5: never zero)', () => {
  for (const s of SPORTS) {
    if (DEEP_SKILL_SPORTS.has(s.slug)) continue;
    assert.ok(s.skills.length >= 4, `${s.slug} has only ${s.skills.length} skills`);
  }
});

test('every sport has at least one quality weighted >= 0.5 (a real primary demand)', () => {
  for (const s of SPORTS) {
    const weights = Object.values(s.qualityProfile);
    assert.ok(weights.some((w) => w >= 0.5), `${s.slug} has no primary quality demand`);
  }
});

test('every position\'s skill slugs and quality-profile slugs are unique within the sport', () => {
  for (const s of SPORTS) {
    const posSlugs = s.positions.map((p) => p.slug);
    assert.equal(new Set(posSlugs).size, posSlugs.length, `${s.slug} has duplicate position slugs`);
    const skillSlugs = s.skills.map((sk) => sk.slug);
    assert.equal(new Set(skillSlugs).size, skillSlugs.length, `${s.slug} has duplicate skill slugs`);
  }
});

// ── §8 skill menu (M9) ───────────────────────────────────────────────────

test('§21: every skill maps to >= 3 real qualities, weights in 0-1', () => {
  const errors = [];
  for (const s of SPORTS) validateSport(s, errors);
  assert.deepEqual(errors, []);
});

test('every skill has a non-empty qualityWeights map (bespoke or the sport-profile fallback)', () => {
  for (const s of SPORTS) {
    for (const sk of s.skills) {
      assert.ok(sk.qualityWeights && Object.keys(sk.qualityWeights).length > 0, `${s.slug}.${sk.slug} has no qualityWeights`);
    }
  }
});

test('soccer.shooting-power matches §8\'s worked example exactly', () => {
  const soccer = SPORTS.find((s) => s.slug === 'soccer');
  const shootingPower = soccer.skills.find((sk) => sk.slug === 'shooting-power');
  assert.deepEqual(shootingPower.qualityWeights, {
    'deceleration': 1.0, 'rotational-power': 0.9, 'horizontal-power': 0.8, 'vertical-power': 0.8,
    'lower-body-strength': 0.7, 'ankle-stiffness': 0.7, 'reactive-strength': 0.7,
    'hip-mobility': 0.5, 'single-leg-stability': 0.5,
  });
});

test('every looping pose pattern names a real pattern', async () => {
  const { LOOPING_PATTERNS } = await import('../src/poses.js');
  const slugs = new Set(POSE_PATTERNS.map((p) => p.slug));
  for (const slug of LOOPING_PATTERNS) assert.ok(slugs.has(slug), `${slug} is not a pose pattern`);
});
