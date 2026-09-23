import assert from 'node:assert/strict';
import test from 'node:test';

import { isContact, JOINTS, frameAt, keyframeAt, lowestY, placeKeyframes } from '../src/rig3d.js';
import { POSE_PATTERNS, mirrorPose } from '../src/poses.js';

const RANGES = {
  spine: [-135, 170], bend: [-95, 95], twist: [-80, 80], turn: [-360, 360], neck: [-60, 70], neckTurn: [-80, 80], lift: [0, 90],
  shoulder: [-100, 210], shoulderAbd: [-95, 180], shoulderRot: [-100, 100], elbow: [0, 160], wrist: [-95, 80],
  hip: [-95, 170], hipAbd: [-30, 90], hipRot: [-60, 60], knee: [0, 160], ankle: [-95, 45],
};
const range = (j) => RANGES[j] ?? RANGES[j.slice(0, -1)];
const IMPLEMENTS = new Set(['barbell', 'dumbbell', 'dumbbells', 'goblet', 'kettlebell', 'medball', 'plate', 'ball', 'football', 'puck',
  'bat', 'club', 'stick', 'racket', 'paddle', 'javelin', 'pole', 'lacrosse', 'bow', 'oar', 'band', 'cable', 'rope', 'prop', 'disc', 'shot', 'rifle', 'sword', 'glove', 'board', 'landmine', 'wristroller', 'jumprope', 'wheel', 'kickboard', 'hockeystick']);
const FIXTURES = new Set(['bench', 'box', 'wall', 'bar', 'water', 'bike', 'rower', 'mat', 'hurdle', 'cone', 'ladder', 'net', 'wheelchair', 'sled', 'roller', 'ball', 'incline', 'kickball']);
const SAMPLES = 16;

test('pattern slugs are unique', () => {
  const slugs = POSE_PATTERNS.map((p) => p.slug);
  assert.equal(new Set(slugs).size, slugs.length);
});

for (const p of POSE_PATTERNS) {
  test(`${p.slug}: well-formed`, () => {
    assert.ok(p.keyframes.length >= 2, 'needs at least two keyframes');
    assert.ok(p.thumb >= 0 && p.thumb < p.keyframes.length, 'thumb out of range');
    if (p.implement) assert.ok(IMPLEMENTS.has(p.implement.kind), `implement ${p.implement.kind}`);
    if (p.fixture) assert.ok(FIXTURES.has(p.fixture.kind), `fixture ${p.fixture.kind}`);
    for (const [i, k] of p.keyframes.entries()) {
      assert.ok(isContact(k.contact), `keyframe ${i} contact ${k.contact}`);
      for (const j of JOINTS) {
        const v = k.pose[j];
        assert.equal(typeof v, 'number', `keyframe ${i} missing ${j}`);
        const [lo, hi] = range(j);
        assert.ok(v >= lo && v <= hi, `keyframe ${i} ${j} = ${v.toFixed(1)} outside ${lo}…${hi}`);
      }
    }
  });

  test(`${p.slug}: planted feet stay on the floor, nothing goes through it`, () => {
    const placed = placeKeyframes(p);
    for (let i = 0; i < p.keyframes.length; i++) {
      const k = p.keyframes[i];
      const s = keyframeAt(p, i, placed);
      const surface = k.surface ?? 0;
      for (const side of ['L', 'R']) {
        if (k.contact.split('+').some((c) => c === 'feet' || c === side)) {
          const y = s[side].ankle[1];
          assert.ok(Math.abs(y - surface) < 2, `keyframe ${i}: planted ${side} foot is ${(y - surface).toFixed(1)} off the floor`);
        }
      }
      if (k.contact === 'hands' && !k.handsOn) {
        for (const side of ['L', 'R']) {
          const y = s[side].wrist[1] - 2.7;
          assert.ok(Math.abs(y - surface) < 2.5, `keyframe ${i}: ${side} hand is ${(y - surface).toFixed(1)} off the floor`);
        }
      }
    }
    if (p.fixture?.kind === 'water') return;
    for (let n = 0; n < SAMPLES; n++) {
      const s = frameAt(p, n / SAMPLES, placed);
      assert.ok(lowestY(s) > -2, `t=${(n / SAMPLES).toFixed(2)}: body ${lowestY(s).toFixed(1)} below the floor`);
    }
  });
}

test('mirrorPose is an involution', () => {
  for (const p of POSE_PATTERNS) for (const k of p.keyframes) assert.deepEqual(mirrorPose(mirrorPose(k.pose)), k.pose);
});
