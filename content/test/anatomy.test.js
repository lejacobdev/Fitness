import assert from 'node:assert/strict';
import test from 'node:test';

import { ANATOMY_HEIGHT, ANATOMY_WIDTH, BACK_MUSCLES, FRONT_MUSCLES, buildAnatomy, splinePath } from '../src/anatomy.js';
import { DRAWABLE_MUSCLES, muscleMapPathKeys } from '../src/muscles.js';

const anatomy = buildAnatomy();

function numbers(d) {
  return (d.match(/-?\d+(\.\d+)?/g) ?? []).map(Number);
}

test('the mannequin draws exactly the muscle paths muscles.js expects — no missing, no orphaned', () => {
  assert.deepEqual(new Set(Object.keys(anatomy.muscles)), new Set(muscleMapPathKeys()));
});

test('every drawable muscle is drawn in every view it declares', () => {
  for (const m of DRAWABLE_MUSCLES) {
    for (const view of m.views) {
      const table = view === 'front' ? FRONT_MUSCLES : BACK_MUSCLES;
      assert.ok(table[m.slug], `${m.slug} has no ${view} shape`);
    }
  }
});

test('every path is well-formed SVG using only M, C and Z', () => {
  for (const [key, d] of [...Object.entries(anatomy.muscles), ['outline', anatomy.outline]]) {
    assert.match(d, /^M/, key);
    assert.match(d.trim(), /Z$/, key);
    assert.ok(/^[MCZ0-9.,\s-]+$/.test(d), `${key} uses an unsupported command`);
  }
  for (const d of [...anatomy.details.front, ...anatomy.details.back]) {
    assert.match(d, /^M[\d.,\s-]+C/);
  }
});

test('everything stays inside the 100 x 200 canvas', () => {
  const all = [...Object.values(anatomy.muscles), anatomy.outline, ...anatomy.details.front, ...anatomy.details.back];
  for (const d of all) {
    const values = numbers(d);
    for (let i = 0; i + 1 < values.length; i += 2) {
      assert.ok(values[i] >= 0 && values[i] <= ANATOMY_WIDTH, `x ${values[i]} out of bounds in ${d.slice(0, 40)}`);
      assert.ok(values[i + 1] >= 0 && values[i + 1] <= ANATOMY_HEIGHT, `y ${values[i + 1]} out of bounds`);
    }
  }
});

test('the left side is the mirror image of the right', () => {
  for (const key of Object.keys(anatomy.muscles).filter((k) => k.endsWith('.right'))) {
    const left = anatomy.muscles[key.replace(/\.right$/, '.left')];
    const rightXs = numbers(anatomy.muscles[key]).filter((_, i) => i % 2 === 0);
    const leftXs = numbers(left).filter((_, i) => i % 2 === 0);
    assert.notEqual(left, anatomy.muscles[key], key);
    const rightMean = rightXs.reduce((a, b) => a + b, 0) / rightXs.length;
    const leftMean = leftXs.reduce((a, b) => a + b, 0) / leftXs.length;
    assert.ok(Math.abs(rightMean + leftMean - 100) < 0.5, `${key} is not mirrored about x = 50`);
  }
});

test('splinePath passes through every authored point', () => {
  const pts = [[10, 10], [20, 12], [15, 25]];
  const d = splinePath(pts);
  for (const [x, y] of pts) assert.ok(d.includes(`${x},${y}`), `${x},${y} missing`);
  assert.throws(() => splinePath([[1, 1]]));
});
