/**
 * The movement library — §9 job 2. One pattern per real movement, each a
 * sequence of keyframes on the 3D rig (rig3d.js has every angle convention),
 * played the way the movement is actually done: a squat goes down and back
 * up, a throw winds up, releases and follows through, a sprint cycles.
 *
 * A pattern:
 *   slug, name
 *   view       camera: 'side' | 'front' | 'three-quarter' | 'back' | 'rear-three-quarter'
 *   loop       true for continuous rhythms (running, pedalling, swimming) that
 *              wrap from the last keyframe to the first; false for reps, which
 *              play through once, hold, and restart
 *   keyframes  [{ pose, contact, hold, move, surface?, travel? }] — see rig3d.js
 *   fixture    optional world object (bench, bar, box, wall, bike, rower, water, mat, …)
 *   implement  optional held equipment { kind, at }
 *   thumb      keyframe index for the still thumbnail
 *
 * Every item in the catalogue names exactly one pattern (poseAssignments.js).
 * Tests (test/poses.test.js) check every keyframe for planted feet on the
 * floor, hands where they should be, and joints inside human range.
 */
import { keyframeAt, placeKeyframes } from './rig3d.js';
import { JOINTS } from './poses/kit.js';
import { STRENGTH } from './poses/strength.js';
import { TEAM_SPORTS } from './poses/teamSports.js';
import { INDIVIDUAL_SPORTS } from './poses/individualSports.js';
import { MISC_SPORTS } from './poses/miscSports.js';
import { HOCKEY } from './poses/hockey.js';
import { SOCCER } from './poses/soccer.js';
import { BASKETBALL } from './poses/basketball.js';
import { VOLLEYBALL } from './poses/volleyball.js';
import { RACKET } from './poses/racket.js';
import { FIELD_SPORTS } from './poses/fieldSports.js';
import { STICK_SPORTS } from './poses/stickSports.js';
import { RUNNING } from './poses/running.js';
import { ENDURANCE } from './poses/endurance.js';
import { BIKES } from './poses/bikes.js';
import { WATER_SPORTS } from './poses/water.js';
import { COMBAT } from './poses/combat.js';
import { ARTISTIC } from './poses/artistic.js';
import { PRECISION } from './poses/precision.js';
import { OUTDOOR } from './poses/outdoor.js';

export const POSE_MODEL_VERSION = 3;
export { JOINTS };

const PATTERNS = [...STRENGTH, ...TEAM_SPORTS, ...INDIVIDUAL_SPORTS, ...MISC_SPORTS, ...HOCKEY, ...SOCCER, ...BASKETBALL, ...VOLLEYBALL, ...RACKET, ...FIELD_SPORTS, ...STICK_SPORTS, ...RUNNING, ...ENDURANCE, ...BIKES, ...WATER_SPORTS, ...COMBAT, ...ARTISTIC, ...PRECISION, ...OUTDOOR];

export const POSE_PATTERNS = PATTERNS;
export const POSE_PATTERN_SLUGS = PATTERNS.map((p) => p.slug);
const BY_SLUG = new Map(PATTERNS.map((p) => [p.slug, p]));

// A drill's other people (partner, passer, defender) play library patterns:
// resolve each member's slug to that pattern once, here.
for (const p of PATTERNS) {
  for (const c of p.cast ?? []) {
    const ref = BY_SLUG.get(c.pattern);
    if (!ref) throw new Error(`${p.slug}: cast member plays unknown pattern ${JSON.stringify(c.pattern)}`);
    if (ref.cast) throw new Error(`${p.slug}: cast member ${c.pattern} has its own cast`);
    Object.defineProperty(c, 'ref', { value: ref, enumerable: false });
  }
}

export function posePattern(slug) {
  const found = BY_SLUG.get(slug);
  if (!found) throw new Error(`unknown pose pattern ${JSON.stringify(slug)}`);
  return found;
}
export const isPosePattern = (slug) => BY_SLUG.has(slug);
export const LOOPING_PATTERNS = new Set(PATTERNS.filter((p) => p.loop).map((p) => p.slug));

/** Swaps every L/R joint pair (its own inverse). */
export function mirrorPose(angles) {
  const out = {};
  for (const j of JOINTS) {
    const other = j.endsWith('L') ? j.slice(0, -1) + 'R' : j.endsWith('R') ? j.slice(0, -1) + 'L' : j;
    out[j] = angles[other];
  }
  return out;
}

export { keyframeAt, placeKeyframes };
