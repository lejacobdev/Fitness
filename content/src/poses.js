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
import { apply, implementHead, keyframeAt, lerpPose, placeKeyframes, rotY } from './rig3d.js';
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
import { VARIANTS } from './poses/variants.js';
import { EQUIPMENT } from './poses/equipment.js';
import { PARTNERS } from './poses/partners.js';
import { PRECISION } from './poses/precision.js';
import { OUTDOOR } from './poses/outdoor.js';
import { KEEPERS } from './poses/keepers.js';

export const POSE_MODEL_VERSION = 3;
export { JOINTS };

const PATTERNS = [...STRENGTH, ...TEAM_SPORTS, ...INDIVIDUAL_SPORTS, ...MISC_SPORTS, ...HOCKEY, ...SOCCER, ...BASKETBALL, ...VOLLEYBALL, ...RACKET, ...FIELD_SPORTS, ...STICK_SPORTS, ...RUNNING, ...ENDURANCE, ...BIKES, ...WATER_SPORTS, ...COMBAT, ...ARTISTIC, ...PRECISION, ...OUTDOOR, ...KEEPERS, ...VARIANTS, ...EQUIPMENT, ...PARTNERS];

/**
 * Patterns where one planted foot moves to a new spot between two keyframes
 * (a stride, a step into a throw, a change of stance) would otherwise glide
 * it along the floor. `autoStep` inserts the step: halfway through the move
 * that foot lifts (the other stays planted), then it lands where the next
 * keyframe puts it. Listed explicitly — skating and sliding glide on purpose.
 */
const STEPPED = new Set(['baseball-swing', 'baseball-swing-coached', 'baseball-swing-front-toss', 'baseball-swing-pitched', 'bb-box-out-vs',
  'bb-chest-pass', 'bb-chest-pass-partner', 'bodyweight-circuit', 'chest-pass', 'chest-pass-wall', 'curtsy-lunge', 'dry-swing',
  'emom-squat-pushup-situp', 'fence-hip-flow', 'fh-hit', 'field-grounder', 'field-grounder-fed', 'gk-hip-opener-flow', 'gk-reaction-save',
  'goalball-spin-throw', 'golf-pre-shot-routine', 'hip-shoulder-separation', 'lax-cross-check-absorb', 'low-forehand', 'low-forehand-fed',
  'movement-screen', 'overarm-pass', 'overarm-pass-receiver', 'overhead-throw-medball', 'overhead-throw-wall', 'pvc-snatch-progression', 'rifle-dry-fire',
  'rifle-jog-then-aim', 'rotational-scoop-wall', 'rotational-throw', 'rotational-throw-wall', 'rotational-throw-wall-coached', 'roundnet-serve',
  'roundnet-serve-received', 'sail-crouch-turns', 'softball-swing', 'stick-mobility-complex', 'stretch-series', 'walking-lunge', 'wrestling-stand-up']);
const feetOf = (contact) => contact.split('+').flatMap((t) => (t === 'feet' ? ['L', 'R'] : [t]));
const footDown = (contact, side) => feetOf(contact).some((t) => t === side || t === `${side}toe` || t === `${side}heel`);
function autoStep(p) {
  const placed = placeKeyframes(p);
  const n = p.keyframes.length, moves = p.loop ? n : n - 1;
  const out = [];
  let thumb = p.thumb;
  for (let i = 0; i < n; i++) {
    const a = p.keyframes[i];
    out.push(a);
    if (i >= moves) continue;
    const j = (i + 1) % n, b = p.keyframes[j];
    const sa = keyframeAt(p, i, placed), sb = keyframeAt(p, j, placed);
    if (!['L', 'R'].every((side) => footDown(a.contact, side) && footDown(b.contact, side))) continue;
    // The stance changes when the feet move relative to each other; the foot
    // that moves more relative to the body is the one stepping.
    const gap = (sk) => [sk.L.ankle[0] - sk.R.ankle[0], sk.L.ankle[2] - sk.R.ankle[2]];
    const ga = gap(sa), gb = gap(sb);
    if (Math.hypot(ga[0] - gb[0], ga[1] - gb[1]) <= 6) continue;
    const drift = (side) => Math.hypot((sb[side].ankle[0] - sb.pelvis[0]) - (sa[side].ankle[0] - sa.pelvis[0]), (sb[side].ankle[2] - sb.pelvis[2]) - (sa[side].ankle[2] - sa.pelvis[2]));
    const side = drift('L') >= drift('R') ? 'L' : 'R';
    const keep = feetOf(a.contact).filter((t) => t !== side && t !== `${side}toe` && t !== `${side}heel`);
    if (!keep.some((t) => /^(L|R)(toe|heel)?$/.test(t))) continue;
    const half = (a.move ?? 0.6) / 2;
    const pose = lerpPose(a.pose, b.pose, 0.5);
    pose[`hip${side}`] += 25;
    pose[`knee${side}`] += 45;
    out[out.length - 1] = { ...a, move: half };
    out.push({ ...a, pose, contact: keep.join('+'), hold: 0, move: half });
    if (thumb > i) thumb += 1;
  }
  return { ...p, thumb, keyframes: out };
}
for (let i = 0; i < PATTERNS.length; i++) if (STEPPED.has(PATTERNS[i].slug)) PATTERNS[i] = autoStep(PATTERNS[i]);

/**
 * A ball waiting on the ground to be struck stays exactly where the stick
 * head meets it at contact (the first keyframe with the ball on the head),
 * whatever the hands do before it (the backswing).
 */
const PINNED_BALLS = new Set(['fh-hit']);
for (const p of PATTERNS) {
  if (!PINNED_BALLS.has(p.slug)) continue;
  const contact = p.keyframes.findIndex((k) => k.ball === 'head');
  const pin = { contact, before: [...Array(contact).keys()] };
  const placed = placeKeyframes(p);
  const r = p.ball.r ?? 3;
  const head = implementHead(p.implement, keyframeAt(p, pin.contact, placed), r);
  const spot = [head[0], r, head[2]];
  const fw = apply(rotY(placed.view), [1, 0, 0]), lt = apply(rotY(placed.view), [0, 0, 1]);
  for (const i of pin.before) {
    const pel = keyframeAt(p, i, placed).pelvis;
    const d = [spot[0] - pel[0], spot[1] - pel[1], spot[2] - pel[2]];
    p.keyframes[i] = { ...p.keyframes[i], ball: { at: [d[0] * fw[0] + d[2] * fw[2], d[1], d[0] * lt[0] + d[2] * lt[2]] } };
  }
}

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
