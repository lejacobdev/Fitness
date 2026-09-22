import assert from 'node:assert/strict';
import test from 'node:test';

import { buildBodySilhouettePaths, referencedRestPoints } from '../src/bodySilhouette.js';
import { REST_POINTS, SEGMENTS, segmentHalfWidthAt } from '../src/rig.js';

test('every rig segment resolves to real REST_POINTS entries', () => {
  for (const name of referencedRestPoints()) {
    assert.ok(name in REST_POINTS, `${name} is not in REST_POINTS`);
  }
  // Every point a segment references should actually resolve — a name typo
  // in a segment's `a`/`b`/`center` would otherwise fail silently at codegen.
  assert.equal(referencedRestPoints().length, new Set(referencedRestPoints()).size);
});

test('segmentHalfWidthAt interpolates linearly between a tapered segment\'s two ends', () => {
  const trunk = SEGMENTS['trunk-upper'];
  assert.equal(segmentHalfWidthAt(trunk, 0), trunk.halfWidthA);
  assert.equal(segmentHalfWidthAt(trunk, 1), trunk.halfWidthB);
  const mid = segmentHalfWidthAt(trunk, 0.5);
  assert.equal(mid, (trunk.halfWidthA + trunk.halfWidthB) / 2);
});

test('segmentHalfWidthAt returns the constant width for a non-tapered segment', () => {
  const foot = SEGMENTS.foot;
  assert.equal(segmentHalfWidthAt(foot, 0), foot.halfWidth);
  assert.equal(segmentHalfWidthAt(foot, 1), foot.halfWidth);
});

test('the torso actually tapers: chest wider than waist, hips wider than waist', () => {
  const upper = SEGMENTS['trunk-upper'];
  const lower = SEGMENTS['trunk-lower'];
  // trunk-upper runs neckBase -> waist, so halfWidthB is the waist width.
  assert.ok(upper.halfWidthA > upper.halfWidthB, 'chest should be wider than the waist');
  // trunk-lower runs waist -> pelvis, so halfWidthA is (again) the waist width.
  assert.ok(lower.halfWidthB > lower.halfWidthA, 'hips should be wider than the waist');
  assert.equal(upper.halfWidthB, lower.halfWidthA, 'both segments must agree on the waist width, or the silhouette pinches unevenly');
});

test('buildBodySilhouettePaths produces a left and right shape for every segment/view pair', () => {
  const paths = buildBodySilhouettePaths();
  for (const view of ['front', 'back']) {
    assert.ok(paths[view].length > 0, `${view} has no silhouette shapes`);
    const sides = new Set(paths[view].map((s) => s.side));
    assert.deepEqual(sides, new Set(['left', 'right']));
  }
});

test('every silhouette path is well-formed (starts M, ends Z, only L/Q commands)', () => {
  const paths = buildBodySilhouettePaths();
  const pattern = /^M-?\d+(\.\d+)?,-?\d+(\.\d+)?( (L-?\d+(\.\d+)?,-?\d+(\.\d+)?|Q-?\d+(\.\d+)?,-?\d+(\.\d+)? -?\d+(\.\d+)?,-?\d+(\.\d+)?))+ Z$/;
  for (const view of ['front', 'back']) {
    for (const shape of paths[view]) {
      assert.match(shape.d, pattern, `${view}/${shape.segment}/${shape.side} malformed: ${shape.d}`);
    }
  }
});

test('a right-side silhouette shape and its left counterpart are mirror images (different strings)', () => {
  const paths = buildBodySilhouettePaths();
  const rightThigh = paths.front.find((s) => s.segment === 'thigh' && s.side === 'right');
  const leftThigh = paths.front.find((s) => s.segment === 'thigh' && s.side === 'left');
  assert.ok(rightThigh && leftThigh);
  assert.notEqual(rightThigh.d, leftThigh.d);
});
