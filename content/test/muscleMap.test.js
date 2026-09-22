import assert from 'node:assert/strict';
import test from 'node:test';

import { mirrorPolygon, polygonArea, regionPolygon } from '../src/geometry.js';
import { MUSCLE_REGIONS } from '../src/muscleRegions.js';
import { buildMuscleMapPaths } from '../src/muscleMap.js';
import { DRAWABLE_MUSCLES, muscleMapPathKeys } from '../src/muscles.js';
import { MIDLINE_X, REST_POINTS, SEGMENTS } from '../src/rig.js';

test('every rig segment endpoint/centre references a real REST_POINTS key', () => {
  for (const [id, seg] of Object.entries(SEGMENTS)) {
    if (seg.kind === 'line') {
      assert.ok(seg.a in REST_POINTS, `${id}.a ${seg.a} missing from REST_POINTS`);
      assert.ok(seg.b in REST_POINTS, `${id}.b ${seg.b} missing from REST_POINTS`);
    } else {
      assert.ok(seg.center in REST_POINTS, `${id}.center ${seg.center} missing from REST_POINTS`);
    }
  }
});

test('every drawable muscle has a region placement for every view it declares', () => {
  for (const m of DRAWABLE_MUSCLES) {
    const placements = MUSCLE_REGIONS[m.slug];
    assert.ok(placements, `${m.slug} has no entry in MUSCLE_REGIONS`);
    for (const view of m.views) {
      assert.ok(placements.some((p) => p.view === view), `${m.slug} has no ${view} placement`);
    }
    // and no orphan placements for a view muscles.js does not declare
    for (const p of placements) {
      assert.ok(m.views.includes(p.view), `${m.slug} has a stray ${p.view} placement`);
    }
  }
});

test('buildMuscleMapPaths produces exactly the keys muscleMapPathKeys expects', () => {
  const paths = buildMuscleMapPaths();
  const expected = new Set(muscleMapPathKeys());
  const actual = new Set(Object.keys(paths));
  assert.deepEqual([...actual].sort(), [...expected].sort());
});

test('every generated path is a well-formed, non-degenerate SVG path', () => {
  const paths = buildMuscleMapPaths();
  for (const [key, d] of Object.entries(paths)) {
    assert.match(d, /^M-?\d+(\.\d+)?,-?\d+(\.\d+)?( L-?\d+(\.\d+)?,-?\d+(\.\d+)?)+ Z$/, `${key} path is malformed: ${d}`);
  }
});

test('every region polygon has a non-trivial area', () => {
  for (const [slug, placements] of Object.entries(MUSCLE_REGIONS)) {
    for (const p of placements) {
      const area = polygonArea(regionPolygon(p));
      assert.ok(area >= 1, `${slug}.${p.view} region area ${area} is degenerate`);
    }
  }
});

test('mirroring a region reflects it across the midline without changing its shape', () => {
  const rightmost = regionPolygon(MUSCLE_REGIONS['pectoralis-major'][0]);
  const mirrored = mirrorPolygon(rightmost);
  assert.ok(Math.abs(polygonArea(rightmost) - polygonArea(mirrored)) < 1e-9);
  // Every mirrored x should be the reflection of the original x.
  for (let i = 0; i < rightmost.length; i += 1) {
    assert.equal(mirrored[i].x, 2 * MIDLINE_X - rightmost[i].x);
    assert.equal(mirrored[i].y, rightmost[i].y);
  }
});

test('left/right path pairs for an asymmetric region are not identical strings', () => {
  const paths = buildMuscleMapPaths();
  // A region placed off the midline must actually differ between sides; an
  // accidental xInsetFrac of 0 would make left and right silently coincide.
  assert.notEqual(paths['pectoralis-major.front.left'], paths['pectoralis-major.front.right']);
  assert.notEqual(paths['biceps-brachii.front.left'], paths['biceps-brachii.front.right']);
});

test('every muscle region stays within the canonical 0-100 x 0-200 rig bounds', () => {
  const PAD = 2; // a small tolerance for a region straddling the figure's outer edge
  for (const [slug, placements] of Object.entries(MUSCLE_REGIONS)) {
    for (const p of placements) {
      for (const side of [regionPolygon(p), mirrorPolygon(regionPolygon(p))]) {
        for (const pt of side) {
          assert.ok(pt.x >= -PAD && pt.x <= 100 + PAD, `${slug}.${p.view} x=${pt.x} out of bounds`);
          assert.ok(pt.y >= -PAD && pt.y <= 200 + PAD, `${slug}.${p.view} y=${pt.y} out of bounds`);
        }
      }
    }
  }
});
