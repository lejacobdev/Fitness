import assert from 'node:assert/strict';
import test from 'node:test';

import { CATALOGUE } from '../src/catalogue.js';
import { cycleSeconds } from '../src/rig3d.js';
import { posePattern } from '../src/poses.js';
import { HELD_POSITION_SECONDS, SLOW_LOWERING_SECONDS, TEMPO_PATTERN_SPEC, tempoPatternSlug } from '../src/tempoSpec.js';

const tempoItems = CATALOGUE.filter((i) => i.variant?.axis === 'tempo');

test('every tempo item shows its base pattern retimed, or the base pattern itself when the movement has no slow phase', () => {
  assert.ok(tempoItems.length > 0);
  for (const item of tempoItems) {
    const base = CATALOGUE.find((i) => i.slug === item.baseSlug);
    const retimed = TEMPO_PATTERN_SPEC[base.startPose] ? tempoPatternSlug(base.startPose, item.variant.tempo) : base.startPose;
    assert.equal(item.startPose, retimed, item.slug);
  }
});

test('tempo specs point at real segments and keyframes', () => {
  for (const [slug, spec] of Object.entries(TEMPO_PATTERN_SPEC)) {
    const p = posePattern(slug);
    const segments = p.loop ? p.keyframes.length : p.keyframes.length - 1;
    for (const i of [...spec.ecc, ...spec.con]) assert.ok(i >= 0 && i < segments, `${slug}: segment ${i}`);
    for (const i of spec.mid) assert.ok(i >= 0 && i < p.keyframes.length, `${slug}: keyframe ${i}`);
    assert.ok(spec.ecc.length && spec.con.length && spec.mid.length, slug);
  }
});

test('slow lowering takes at least 3.5 s, a held position at least 3 s, a fast lift is quicker', () => {
  for (const [slug, spec] of Object.entries(TEMPO_PATTERN_SPEC)) {
    const base = posePattern(slug);
    const slow = posePattern(tempoPatternSlug(slug, 'eccentric'));
    const held = posePattern(tempoPatternSlug(slug, 'isometric'));
    const fast = posePattern(tempoPatternSlug(slug, 'explosive'));
    const lowering = spec.ecc.reduce((a, i) => a + (slow.keyframes[i].move ?? 0.6), 0);
    assert.ok(lowering >= SLOW_LOWERING_SECONDS - 1e-9, `${slug} lowers in ${lowering}s`);
    assert.ok(Math.max(...spec.mid.map((i) => held.keyframes[i].hold)) >= HELD_POSITION_SECONDS * 0.8 - 1e-9, `${slug} hold`);
    assert.ok(cycleSeconds(slow) > cycleSeconds(base), `${slug} slow`);
    assert.ok(cycleSeconds(held) > cycleSeconds(base), `${slug} held`);
    assert.ok(cycleSeconds(fast) <= cycleSeconds(base), `${slug} fast`);
    assert.equal(slow.keyframes.length, base.keyframes.length);
  }
});
