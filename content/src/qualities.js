/**
 * The athletic qualities — §6, "the spine that makes 70 sports tractable".
 *
 * Sports do not have unique physical demands; they have unique *mixtures* of
 * shared demands. A hockey crossover and a soccer cut are both lateral force
 * production off one leg. So there is one library tagged by quality, and every
 * sport and position is a weighting across this same fixed list.
 *
 * This list is FIXED and VERSIONED. Adding or removing a quality invalidates
 * every sport profile and every item tag at once, so `QUALITY_MODEL_VERSION` is
 * bumped and the catalogue integrity tests fail until all of them are updated.
 * That failure is the point — a silently renamed quality would quietly
 * mis-select exercises for every athlete in the affected sports.
 *
 * `group` drives session ordering in §10 (speed and power while fresh, strength
 * next, endurance after, control last) and the grouping of the weekly review
 * in §12.
 */

export const QUALITY_MODEL_VERSION = 1;

export const QUALITY_GROUPS = ['speed', 'power', 'strength', 'endurance', 'control'];

/**
 * Order within the list is the order the app displays them in. It follows the
 * §6 table exactly rather than alphabetically.
 */
export const QUALITIES = [
  // ── Speed ───────────────────────────────────────────────────────────────
  {
    slug: 'acceleration',
    group: 'speed',
    name: 'Acceleration',
    shortName: 'Acceleration',
    description: 'Producing speed from a standstill over the first ten metres.',
  },
  {
    slug: 'max-velocity',
    group: 'speed',
    name: 'Maximum velocity',
    shortName: 'Top speed',
    description: 'The highest speed reachable once already moving.',
  },
  {
    slug: 'change-of-direction',
    group: 'speed',
    name: 'Change of direction',
    shortName: 'Cutting',
    description: 'Planting, reorienting and re-accelerating along a new line.',
  },
  {
    slug: 'lateral-power',
    group: 'speed',
    name: 'Lateral power',
    shortName: 'Lateral power',
    description: 'Force production sideways off one leg — a crossover, a shuffle, a cut.',
  },
  {
    slug: 'deceleration',
    group: 'speed',
    name: 'Deceleration and eccentric braking',
    shortName: 'Braking',
    description: 'Absorbing speed under control, which is what makes cutting possible.',
  },

  // ── Power ───────────────────────────────────────────────────────────────
  {
    slug: 'vertical-power',
    group: 'power',
    name: 'Vertical power',
    shortName: 'Vertical power',
    description: 'Jumping height from one or both legs.',
  },
  {
    slug: 'horizontal-power',
    group: 'power',
    name: 'Horizontal power',
    shortName: 'Horizontal power',
    description: 'Projecting the body forward — broad jumps, first steps, dives.',
  },
  {
    slug: 'rotational-power',
    group: 'power',
    name: 'Rotational power',
    shortName: 'Rotational power',
    description: 'Transferring force through a turning trunk into a throw, swing or strike.',
  },
  {
    slug: 'overhead-power',
    group: 'power',
    name: 'Overhead and throwing power',
    shortName: 'Overhead power',
    description: 'Accelerating an implement or the hand above shoulder height.',
  },
  {
    slug: 'reactive-strength',
    group: 'power',
    name: 'Reactive strength',
    shortName: 'Stiffness',
    description: 'Short ground contacts — spending as little time on the floor as possible.',
  },

  // ── Strength ────────────────────────────────────────────────────────────
  {
    slug: 'lower-body-strength',
    group: 'strength',
    name: 'Lower-body maximum strength',
    shortName: 'Leg strength',
    description: 'The force the legs and hips can produce against heavy resistance.',
  },
  {
    slug: 'upper-body-push',
    group: 'strength',
    name: 'Upper-body push',
    shortName: 'Push',
    description: 'Pressing away from the body, horizontally or overhead.',
  },
  {
    slug: 'upper-body-pull',
    group: 'strength',
    name: 'Upper-body pull',
    shortName: 'Pull',
    description: 'Drawing toward the body, vertically or horizontally.',
  },
  {
    slug: 'trunk-anti-rotation',
    group: 'strength',
    name: 'Trunk and anti-rotation',
    shortName: 'Trunk',
    description: 'Resisting bend and twist so the limbs have something to push against.',
  },
  {
    slug: 'grip',
    group: 'strength',
    name: 'Grip',
    shortName: 'Grip',
    description: 'Holding on — a stick, a bar, an opponent, a bat.',
  },

  // ── Endurance ───────────────────────────────────────────────────────────
  {
    slug: 'aerobic-base',
    group: 'endurance',
    name: 'Aerobic base',
    shortName: 'Aerobic base',
    description: 'The engine that carries a whole match and speeds recovery between efforts.',
  },
  {
    slug: 'anaerobic-capacity',
    group: 'endurance',
    name: 'Anaerobic capacity',
    shortName: 'Anaerobic',
    description: 'Sustaining hard work for thirty seconds to two minutes.',
  },
  {
    slug: 'repeat-sprint',
    group: 'endurance',
    name: 'Repeat-sprint ability',
    shortName: 'Repeat sprint',
    description: 'Sprinting again, and again, with short rest and little drop-off.',
  },

  // ── Control ─────────────────────────────────────────────────────────────
  {
    slug: 'single-leg-stability',
    group: 'control',
    name: 'Single-leg stability',
    shortName: 'Single-leg control',
    description: 'Staying organised on one leg, which is how most sport actually happens.',
  },
  {
    slug: 'hip-mobility',
    group: 'control',
    name: 'Hip mobility',
    shortName: 'Hip mobility',
    description: 'Usable range at the hip, so positions are reachable without compensating.',
  },
  {
    slug: 'shoulder-stability',
    group: 'control',
    name: 'Shoulder and overhead stability',
    shortName: 'Shoulder control',
    description: 'Controlling the shoulder blade and joint under load above the head.',
  },
  {
    slug: 'ankle-stiffness',
    group: 'control',
    name: 'Ankle stiffness',
    shortName: 'Ankle stiffness',
    description: 'An ankle that returns energy instead of collapsing on contact.',
  },
  {
    slug: 'landing-mechanics',
    group: 'control',
    name: 'Balance and landing mechanics',
    shortName: 'Landing',
    description: 'Arriving back on the ground organised, from any height or direction.',
  },
];

export const QUALITY_SLUGS = QUALITIES.map((q) => q.slug);

const BY_SLUG = new Map(QUALITIES.map((q) => [q.slug, q]));

export function quality(slug) {
  const found = BY_SLUG.get(slug);
  if (!found) throw new Error(`unknown quality ${JSON.stringify(slug)}`);
  return found;
}

export function isQuality(slug) {
  return BY_SLUG.has(slug);
}

export function qualitiesInGroup(group) {
  return QUALITIES.filter((q) => q.group === group);
}

/**
 * §6 tags items with 1.0 for a primary quality and 0.5 for a secondary one.
 * Expansion rules in §7 scale these, so intermediate values occur; the
 * authored values are only ever these two.
 */
export const PRIMARY_WEIGHT = 1.0;
export const SECONDARY_WEIGHT = 0.5;
