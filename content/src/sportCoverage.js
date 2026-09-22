/**
 * §7's build-blocking coverage test: "every sport's profile resolves to at
 * least 40 eligible items at every equipment level." An item is eligible for
 * a sport if it is a sport-agnostic exercise (§7: "selected by quality," so
 * every exercise is a candidate for every sport) or a drill authored for that
 * specific sport, filtered down to what the declared equipment level can
 * actually perform.
 *
 * This is deliberately not the §10 plan generator (a seeded, dated,
 * periodised selection of a handful of items for one session) — it is the
 * much simpler question §7 actually asks: does the *raw pool* a sport can
 * draw from ever run dry. A sport with zero authored drills still clears this
 * on the shared exercise library alone; drills narrow *which* items are most
 * relevant, never whether enough exist.
 */

import { CATALOGUE } from './catalogue.js';
import { EQUIPMENT_LEVELS, itemAvailableAt } from './schema.js';

export function eligibleItemsForSport(sportSlug, equipmentLevel) {
  if (!EQUIPMENT_LEVELS.includes(equipmentLevel)) {
    throw new Error(`unknown equipment level ${JSON.stringify(equipmentLevel)}`);
  }
  return CATALOGUE.filter((item) => {
    const belongsToSport = item.kind === 'exercise' || item.sport === sportSlug;
    return belongsToSport && itemAvailableAt(item, equipmentLevel);
  });
}

export const MIN_ELIGIBLE_ITEMS_PER_SPORT = 40;

/** { sportSlug: { none: count, minimal: count, full: count } } for every sport. */
export function coverageReport(sports) {
  const report = {};
  for (const sport of sports) {
    report[sport.slug] = {};
    for (const level of EQUIPMENT_LEVELS) {
      report[sport.slug][level] = eligibleItemsForSport(sport.slug, level).length;
    }
  }
  return report;
}

/** Sports (and the levels) that fall short of the §7 minimum, empty if none do. */
export function coverageGaps(sports) {
  const report = coverageReport(sports);
  const gaps = [];
  for (const [slug, byLevel] of Object.entries(report)) {
    for (const [level, count] of Object.entries(byLevel)) {
      if (count < MIN_ELIGIBLE_ITEMS_PER_SPORT) gaps.push({ sport: slug, level, count });
    }
  }
  return gaps;
}
