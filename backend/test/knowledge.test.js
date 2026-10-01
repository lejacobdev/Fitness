import assert from 'node:assert/strict';
import test from 'node:test';

import { currentRelease } from '../src/routes/knowledge.js';

const at = (n) => new Date(Date.UTC(2026, 9, 1, 12, n));
const fake = (actions) => ({ knowledgeAction: { findMany: async () => actions } });

test('knowledge release: an append-only log folded into what the app applies', async () => {
  assert.deepEqual(await currentRelease(fake([])), { release: 'k0', disabledRules: [], quarantinedItems: [], reviewedItems: [], reviewedSports: [] });
  const release = await currentRelease(fake([
    { kind: 'disable_rule', target: 'SCHED-CONGESTION-05', createdAt: at(1) },
    { kind: 'disable_rule', target: 'SAFE-CONCUSSION-01', createdAt: at(2) },
    { kind: 'review_item', target: 'goblet-squat', createdAt: at(3) },
    { kind: 'quarantine_item', target: 'box-jump', createdAt: at(4) },
    { kind: 'review_item', target: 'box-jump', createdAt: at(5) },
    { kind: 'review_sport', target: 'basketball', createdAt: at(6) },
  ]));
  assert.deepEqual(release.disabledRules, ['SCHED-CONGESTION-05'], 'safety rules can never be switched off');
  assert.deepEqual(release.quarantinedItems, ['box-jump']);
  assert.deepEqual(release.reviewedItems, ['goblet-squat'], 'a quarantined exercise is not reviewed');
  assert.deepEqual(release.reviewedSports, ['basketball']);
  assert.equal(release.release, 'k6-2026-10-01');
  const restored = await currentRelease(fake([
    { kind: 'disable_rule', target: 'SCHED-CONGESTION-05', createdAt: at(1) },
    { kind: 'enable_rule', target: 'SCHED-CONGESTION-05', createdAt: at(2) },
    { kind: 'quarantine_item', target: 'box-jump', createdAt: at(3) },
    { kind: 'release_item', target: 'box-jump', createdAt: at(4) },
  ]));
  assert.deepEqual([restored.disabledRules, restored.quarantinedItems], [[], []]);
});
