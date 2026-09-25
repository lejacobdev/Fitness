/**
 * Compact authoring helpers for sport drills. Every drill still carries the
 * full §7 field set — these only fill in the fields that are the same for
 * nearly every drill (kind, sport, youth defaults, empty link lists) so each
 * entry below states what is distinctive about it.
 *
 * `skills` links a drill to the named skills (§8) of its sport that it
 * directly builds, so "I want to get better at shooting" can surface the
 * drills written for exactly that, before falling back to quality matching.
 */

import { sportBySlug } from '../sports.js';

export function drill(sport, spec) {
  return {
    kind: 'drill',
    sport,
    minAge: 13,
    supervisionLevel: 'SELF',
    progressions: [],
    regressions: [],
    substitutes: [],
    restSeconds: 60,
    skills: [],
    ...spec,
    slug: `${sport}-${spec.slug}`,
  };
}

/**
 * Drills of a variant merged into its main sport (beach volleyball into
 * Volleyball): they belong to `sport`, go only to athletes in `format`, and
 * keep their original slugs (`prefix-…`) so history and animations stay put.
 * A null format (a position group, e.g. field-hockey goalkeeping) gives the
 * drills to the whole sport; pass `positions` to gate them instead.
 */
export function formatDrills(sport, prefix, format, specs, { positions } = {}) {
  // Skills named after the old variant sport's menu carry over where the main
  // sport has a skill of the same name; the rest are dropped.
  const own = new Set(sportBySlug(sport).skills.map((s) => s.slug));
  return specs.map((spec) => ({
    ...drill(sport, spec),
    skills: (spec.skills ?? []).filter((s) => own.has(s)),
    slug: `${prefix}-${spec.slug}`,
    ...(format ? { formats: [format] } : {}),
    ...(positions ? { positions } : {}),
  }));
}

/** Build a group of drills for one sport: `sportDrills('tennis', [...])`. */
export function sportDrills(sport, specs) {
  return specs.map((spec) => drill(sport, spec));
}

export const reps = (sets, count, load = 'bodyweight') => ({ kind: 'reps', sets, reps: count, load });
export const time = (sets, seconds) => ({ kind: 'time', sets, seconds });
export const dist = (sets, metres) => ({ kind: 'distance', sets, metres });
export const contacts = (sets, count) => ({ kind: 'contacts', sets, contacts: count });
