import assert from 'node:assert/strict';
import test from 'node:test';

import {
  coverageGaps, coverageReport, eligibleItemsForSport, MIN_ELIGIBLE_ITEMS_PER_SPORT,
} from '../src/sportCoverage.js';
import { SPORTS } from '../src/sports.js';

test('§7: every sport resolves to at least 40 eligible items at every equipment level — the build-blocking coverage test', () => {
  const gaps = coverageGaps(SPORTS);
  assert.deepEqual(gaps, [], `coverage gaps: ${JSON.stringify(gaps)}`);
});

test('the bodyweight ("none") tier alone already clears the minimum for every sport', () => {
  // The strongest form of the guarantee: an athlete with literally nothing
  // but a field never runs dry, even before any minimal or full equipment is
  // available and even for a sport with zero authored drills yet.
  for (const sport of SPORTS) {
    const count = eligibleItemsForSport(sport.slug, 'none').length;
    assert.ok(count >= MIN_ELIGIBLE_ITEMS_PER_SPORT, `${sport.slug} has only ${count} bodyweight-eligible items`);
  }
});

test('eligible item count is monotonically non-decreasing as equipment level rises', () => {
  // More equipment can only ever unlock more items, never fewer — a level
  // ordering bug in itemAvailableAt would show up here as a sport with more
  // "none"-tier items than "full"-tier ones.
  for (const sport of SPORTS) {
    const none = eligibleItemsForSport(sport.slug, 'none').length;
    const minimal = eligibleItemsForSport(sport.slug, 'minimal').length;
    const full = eligibleItemsForSport(sport.slug, 'full').length;
    assert.ok(none <= minimal, `${sport.slug}: none (${none}) > minimal (${minimal})`);
    assert.ok(minimal <= full, `${sport.slug}: minimal (${minimal}) > full (${full})`);
  }
});

test('a sport with authored drills is never worse off than one without', () => {
  // Soccer's own drills should only ever ADD to what the shared exercise
  // library already provides, never crowd it out.
  const soccerCount = eligibleItemsForSport('soccer', 'minimal').length;
  const exerciseOnlyBaseline = eligibleItemsForSport('archery', 'minimal').length; // no drills authored
  assert.ok(soccerCount >= exerciseOnlyBaseline);
});

test('eligibleItemsForSport rejects an unknown equipment level', () => {
  assert.throws(() => eligibleItemsForSport('soccer', 'bogus'));
});

test('coverageReport covers every sport with all three equipment levels present', () => {
  const report = coverageReport(SPORTS);
  assert.equal(Object.keys(report).length, SPORTS.length);
  for (const sport of SPORTS) {
    assert.deepEqual(Object.keys(report[sport.slug]).sort(), ['full', 'minimal', 'none']);
  }
});
