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

/** Build a group of drills for one sport: `sportDrills('tennis', [...])`. */
export function sportDrills(sport, specs) {
  return specs.map((spec) => drill(sport, spec));
}

export const reps = (sets, count, load = 'bodyweight') => ({ kind: 'reps', sets, reps: count, load });
export const time = (sets, seconds) => ({ kind: 'time', sets, seconds });
export const dist = (sets, metres) => ({ kind: 'distance', sets, metres });
export const contacts = (sets, count) => ({ kind: 'contacts', sets, contacts: count });
