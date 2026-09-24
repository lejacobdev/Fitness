import assert from 'node:assert/strict';
import test from 'node:test';

import { CATALOGUE } from '../src/catalogue.js';
import { POSE_ASSIGNMENTS } from '../src/poseAssignments/index.js';
import { isPosePattern } from '../src/poses.js';

test('every assignment names a real pattern and a real item', () => {
  const slugs = new Set(CATALOGUE.map((i) => i.slug));
  for (const [item, pattern] of Object.entries(POSE_ASSIGNMENTS)) {
    assert.ok(slugs.has(item), `assignment for unknown item ${item}`);
    assert.ok(isPosePattern(pattern), `${item} → unknown pattern ${pattern}`);
  }
});
