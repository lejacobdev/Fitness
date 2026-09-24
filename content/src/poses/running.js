/**
 * Track and field, cross-country, unified and para track: starts from
 * blocks, curve running, hurdling, the long jump, relays with a baton,
 * running on hills, guide running with a tether, a racing wheelchair and a
 * running blade.
 */
import { add, apply, strideSpeed } from '../rig3d.js';
import { STRENGTH } from './strength.js';
import { P, air, armsSwing, both, flatHands, gait, ground, kf, library, mirror, reach, reachBoth, toeDown } from './kit.js';

const lib = library();
const def = lib.def;
const spec = (slug) => {
  const { slug: _s, name: _n, ...rest } = STRENGTH.find((p) => p.slug === slug);
  return rest;
};
/** Makes a travelling rep pattern's path take exactly one keyframe cycle. */
const oneCyclePath = (slug) => {
  const p = lib.patterns.find((q) => q.slug === slug);
  const moves = p.loop ? p.keyframes.length : p.keyframes.length - 1;
  let cycle = 0;
  p.keyframes.forEach((k, i) => { cycle += (k.hold ?? 0) + (i < moves ? k.move ?? 0.6 : 0); });
  p.path.length = strideSpeed(p) * cycle;
};

// ── Runs at different efforts ────────────────────────────────────────────
const sprintPhases = [
  { hipL: 36, kneeL: 18, ankleL: 2, hipR: -12, kneeR: 96, ankleR: -24, ...armsSwing(-40, 60, 92), lift: 0 },
  { hipL: 8, kneeL: 40, ankleL: 22, hipR: 46, kneeR: 122, ankleR: 0, ...armsSwing(-10, 30, 92) },
  { hipL: -26, kneeL: 22, ankleL: -32, hipR: 84, kneeR: 96, ankleR: 8, ...armsSwing(45, -40, 88), lift: 4 },
  { hipL: -14, kneeL: 84, ankleL: -18, hipR: 58, kneeR: 40, ankleR: 4, ...armsSwing(30, -30, 90), lift: 9 },
];
const tempoPhases = [
  { hipL: 30, kneeL: 16, ankleL: 4, hipR: -12, kneeR: 84, ankleR: -22, ...armsSwing(-32, 46, 88) },
  { hipL: 6, kneeL: 36, ankleL: 20, hipR: 38, kneeR: 104, ankleR: 0, ...armsSwing(-8, 22, 88) },
  { hipL: -22, kneeL: 18, ankleL: -28, hipR: 66, kneeR: 80, ankleR: 6, ...armsSwing(36, -32, 86), lift: 3 },
  { hipL: -12, kneeL: 70, ankleL: -16, hipR: 46, kneeR: 34, ankleR: 4, ...armsSwing(24, -22, 88), lift: 6 },
];
def('tempo-run', 'Running at tempo pace', {
  path: { kind: 'line', length: 420 }, loop: true, thumb: 0,
  keyframes: gait(tempoPhases, { lean: 8, neck: -4, move: 0.11 }),
});
def('hill-run-up', 'Running uphill', {
  path: { kind: 'line', length: 360, grade: 0.14 }, loop: true, thumb: 0,
  keyframes: gait(tempoPhases.map((ph) => ({ ...ph, hipL: ph.hipL + 8, hipR: ph.hipR + 8, ankleL: ph.ankleL + 8, ankleR: ph.ankleR + 8 })), { lean: 18, neck: -10, move: 0.1 }),
});
def('hill-run-down', 'Running downhill', {
  path: { kind: 'line', length: 360, grade: -0.12 }, loop: true, thumb: 0,
  keyframes: gait(tempoPhases.map((ph) => ({ ...ph, shoulderAbdL: 30, shoulderAbdR: 30, kneeL: ph.kneeL * 0.8, kneeR: ph.kneeR * 0.8 })), { lean: 2, neck: 4, move: 0.09 }),
});
def('curve-sprint', 'Sprinting the curve', {
  view: 'three-quarter', path: { kind: 'circle', radius: 320, turn: 1 }, loop: true, thumb: 0,
  keyframes: gait(sprintPhases, { lean: 12, neck: -6, move: 0.085, extra: { bend: 10 } }),
});
def('prosthetic-strides', 'Strides on a running blade', {
  path: { kind: 'line', length: 440 }, loop: true, thumb: 0, prosthetic: 'L',
  keyframes: gait(tempoPhases, { lean: 9, neck: -4, move: 0.1 }),
});

// ── Drill series ───────────────────────────────────────────────────────────
def('ab-skip-series', 'A-skip then B-skip', {
  path: { kind: 'line', length: 420, speed: 95 }, loop: true, thumb: 1,
  keyframes: [...spec('a-skip').keyframes, ...spec('a-skip').keyframes, ...spec('b-skip').keyframes, ...spec('b-skip').keyframes],
});
const ankling = gait([
  { hipL: 4, kneeL: 6, ankleL: -10, hipR: 14, kneeR: 20, ankleR: 10, ...armsSwing(-16, 20, 88) },
  { hipL: 0, kneeL: 4, ankleL: -24, hipR: 8, kneeR: 10, ankleR: -4, ...armsSwing(16, -16, 88), lift: 1 },
], { lean: 3, move: 0.1 });
const buttKicks = gait([
  { hipL: 0, kneeL: 8, ankleL: -10, hipR: 4, kneeR: 90, ankleR: -20, ...armsSwing(-20, 24, 90) },
  { hipL: -4, kneeL: 6, ankleL: -26, hipR: 6, kneeR: 140, ankleR: -30, ...armsSwing(24, -20, 90), lift: 3 },
], { lean: 4, move: 0.1 });
const straightLeg = gait([
  { hipL: 0, kneeL: 2, ankleL: -6, hipR: -20, kneeR: 4, ankleR: -10, ...armsSwing(-30, 40, 30) },
  { hipL: -10, kneeL: 2, ankleL: -26, hipR: 60, kneeR: 4, ankleR: 10, ...armsSwing(50, -40, 30), lift: 4 },
], { lean: -2, move: 0.12 });
def('running-form-drills', 'Form drills: ankling, high knees, butt kicks, straight-leg bounds', {
  path: { kind: 'line', length: 460, speed: 110 }, loop: true, thumb: 5,
  keyframes: [...ankling, ...ankling, ...spec('high-knees').keyframes, ...spec('high-knees').keyframes, ...buttKicks, ...buttKicks, ...straightLeg, ...straightLeg],
});

// ── Starts ─────────────────────────────────────────────────────────────────
/** Hands just behind the line, shoulder-width, fingers bridged. */
const onLine = (p) => flatHands(reachBoth(p, ground(62, 18, 2.9), ground(62, -18, 2.9)));
def('block-start', 'Start from blocks', {
  thumb: 1, fixture: { kind: 'blocks' },
  keyframes: [
    kf(onLine(toeDown(P({ spine: 70, neck: -30, hipL: 118, kneeL: 110, ankleL: 20, hipR: 70, kneeR: 116, ankleR: -30 }), 'L')), 'hands+Ltoe+Rknee', { hold: 0.6, move: 0.5 }),
    kf(onLine(toeDown(P({ spine: 84, neck: -30, hipL: 106, kneeL: 88, ankleL: 22, hipR: 64, kneeR: 124, ankleR: -10 }), 'L')), 'hands+Ltoe+Rtoe', { hold: 0.5, move: 0.16 }),
    kf(P({ spine: 58, neck: -14, hipL: 30, kneeL: 20, ankleL: -30, hipR: 100, kneeR: 110, ankleR: 10, ...armsSwing(-60, 70, 88) }), 'Ltoe', { move: 0.16, travel: [30, 0] }),
    kf(P({ spine: 50, neck: -12, hipR: 20, kneeR: 20, ankleR: -30, hipL: 96, kneeL: 104, ankleL: 10, ...armsSwing(60, -50, 88) }), 'Rtoe', { move: 0.14, travel: [44, 0] }),
    kf(P({ spine: 40, neck: -10, hipL: 16, kneeL: 22, ankleL: -30, hipR: 90, kneeR: 100, ankleR: 10, ...armsSwing(-50, 50, 88) }), 'Ltoe', { move: 0.14, travel: [50, 0] }),
    kf(P({ spine: 28, neck: -8, hipR: 10, kneeR: 24, ankleR: -30, hipL: 84, kneeL: 96, ankleL: 8, ...armsSwing(50, -40, 90), lift: 2 }), 'Rtoe', { hold: 0.3, travel: [56, 0] }),
  ],
});
def('stand-watch', 'Partner watching', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 6, knee: 8, hipAbd: 8 }), { spine: 6, shoulderL: 20, elbowL: 90, shoulderR: 20, elbowR: 90, neckTurn: -10 }), 'feet', { hold: 1, move: 0.8 }),
    kf(P(both({ hip: 6, knee: 8, hipAbd: 8 }), { spine: 8, shoulderL: 20, elbowL: 90, shoulderR: 20, elbowR: 90, neckTurn: 10 }), 'feet', { hold: 1, move: 0.8 }),
  ],
});
def('partner-sprint-start', 'Sprint start side by side', {
  ...spec('acceleration-start'), view: 'three-quarter',
  cast: [{ pattern: 'acceleration-start', at: [0, 90], facing: 0 }],
});
def('approach-run-check', 'Approach run with a partner watching the marks', {
  ...spec('sprint'), view: 'three-quarter',
  cast: [{ pattern: 'stand-watch', at: [0, -140], facing: 90 }],
});
def('broad-jump-marked', 'Standing long jump, partner marks it', {
  ...spec('broad-jump'), view: 'three-quarter',
  cast: [{ pattern: 'stand-watch', at: [150, -110], facing: 90 }],
});

// ── Hurdles and jumps ─────────────────────────────────────────────────────
/** Lead leg up and over, then the trail leg out to the side, knee high, foot turned out. */
def('hurdle-walkover-track', 'Hurdle walkover (lead and trail leg)', {
  view: 'three-quarter', thumb: 1, fixture: { kind: 'hurdle', at: 40 },
  keyframes: [
    kf(P(both({ shoulderAbd: 20 }), { shoulderL: 30, shoulderR: -20 }), 'feet', { hold: 0.2, move: 0.5 }),
    kf(P({ hipR: 104, kneeR: 90, ankleR: 10, hipL: 0, kneeL: 4, shoulderL: 50, shoulderR: -30, elbowL: 30, elbowR: 30 }), 'L', { move: 0.6 }),
    kf(P({ hipR: 24, kneeR: 6, ankleR: 0, hipL: -12, kneeL: 4, ankleL: -6, shoulderL: 10, shoulderR: 10 }), 'L+R', { move: 0.3, travel: [60, 0] }),
    kf(P({ hipR: 30, kneeR: 10, ankleR: 0, hipL: -10, kneeL: 14, ankleL: -34, shoulderL: 10, shoulderR: 10 }), 'R+Ltoe', { hold: 0.1, move: 0.5 }),
    kf(P({ spine: 6, hipR: 4, kneeR: 6, hipL: 50, kneeL: 110, ankleL: 0, hipAbdL: 70, hipRotL: 40, shoulderR: 40, shoulderL: -20, elbowL: 30, elbowR: 30 }), 'R', { move: 0.6 }),
    kf(P({ hipL: 70, kneeL: 90, ankleL: 10, hipAbdL: 10, hipR: 0, kneeR: 4, shoulderR: 40, shoulderL: -20 }), 'R', { move: 0.4, travel: [10, 0] }),
    kf(P(both({ shoulderAbd: 20 })), 'feet', { hold: 0.3, travel: [30, 0] }),
  ],
});
def('hurdle-clearance', 'Hurdle clearance, three steps between', {
  view: 'three-quarter', thumb: 3, fixture: { kind: 'hurdle', at: 150 },
  keyframes: [
    kf(P(sprintPhases[0], { spine: 12, neck: -6 }), 'air', { move: 0.1 }),
    kf(P(mirror(P(sprintPhases[2])), { spine: 12, neck: -6 }), 'air', { move: 0.1, travel: [50, 0] }),
    kf(P({ spine: 20, neck: -8, hipL: 10, kneeL: 20, ankleL: -30, hipR: 80, kneeR: 90, ankleR: 10, ...armsSwing(-40, 50, 80) }), 'Ltoe', { move: 0.12, travel: [50, 0] }),
    kf(P({ spine: 44, neck: -14, hipR: 100, kneeR: 10, ankleR: 10, hipL: -20, kneeL: 90, hipAbdL: 50, hipRotL: 30, ankleL: 0, shoulderL: 110, elbowL: 20, shoulderR: -30, elbowR: 80, lift: 32 }), 'air', { move: 0.14, travel: [70, 0] }),
    kf(P({ spine: 20, neck: -8, hipR: 6, kneeR: 10, ankleR: -20, hipL: 70, kneeL: 100, hipAbdL: 30, hipRotL: 20, ankleL: 0, ...armsSwing(50, -40, 80) }), 'Rtoe', { move: 0.1, travel: [70, 0] }),
    kf(P(sprintPhases[2], { spine: 12, neck: -6 }), 'air', { move: 0.1, travel: [40, 0] }),
    kf(P(mirror(P(sprintPhases[2])), { spine: 12, neck: -6 }), 'air', { move: 0.1, travel: [50, 0] }),
    kf(P(sprintPhases[2], { spine: 12, neck: -6 }), 'air', { hold: 0.2, travel: [50, 0] }),
  ],
});
def('long-jump', 'Long jump (short approach)', {
  view: 'side', thumb: 4,
  keyframes: [
    kf(P(sprintPhases[0], { spine: 12, neck: -6 }), 'air', { move: 0.1 }),
    kf(P(mirror(P(sprintPhases[2])), { spine: 10, neck: -6 }), 'air', { move: 0.1, travel: [60, 0] }),
    kf(P({ spine: 4, neck: -4, hipL: 26, kneeL: 20, ankleL: 6, hipR: -10, kneeR: 60, ankleR: -20, ...armsSwing(-30, 40, 88) }), 'L', { move: 0.1, travel: [60, 0] }),
    kf(P({ spine: 0, hipL: -20, kneeL: 10, ankleL: -30, hipR: 90, kneeR: 90, ankleR: 10, shoulderR: 150, elbowR: 30, shoulderL: -40, elbowL: 40 }), 'Ltoe', { move: 0.16, travel: [30, 0] }),
    kf(P({ spine: 6, hipL: 20, kneeL: 70, ankleL: -10, hipR: 90, kneeR: 80, ankleR: 10, shoulderR: 170, elbowR: 10, shoulderL: 170, elbowL: 10, lift: 60 }), 'air', { move: 0.24, travel: [80, 0] }),
    kf(P({ spine: 50, neck: -10, ...both({ hip: 110, knee: 20, ankle: 10 }), ...both({ shoulder: 40, elbow: 20 }), lift: 30 }), 'air', { move: 0.2, travel: [80, 0] }),
    kf(P({ spine: 40, neck: -10, ...both({ hip: 100, knee: 110, ankle: 30, hipAbd: 10 }), ...both({ shoulder: 60, elbow: 20 }) }), 'feet', { hold: 0.5, travel: [40, 0] }),
  ],
});

// ── Relays ─────────────────────────────────────────────────────────────────
const BATON = { r: 2, color: 'red', shape: 'baton' };
/** Outgoing runner's right hand reaching straight back, palm open and up. */
const reachBack = (ph) => ({ ...ph, shoulderR: -70, elbowR: 6, shoulderRotR: -40 });
const withBaton = (frames, reachAt, handoffAt) => frames.map((k, i) => {
  const reaching = i >= reachAt && i < handoffAt + 1;
  return { ...k, pose: reaching ? P(k.pose, reachBack({})) : k.pose, ball: i < handoffAt ? 'c0:L' : 'R' };
});
const sprintGait = gait(sprintPhases, { lean: 12, neck: -6, move: 0.1 });
/** The incoming runner, baton in the left hand, on the same stride count. */
def('relay-incoming', 'Incoming relay runner', { view: 'three-quarter', loop: true, thumb: 0, keyframes: [...sprintGait, ...sprintGait, ...sprintGait] });
def('relay-handoff', 'Relay hand-off in the zone', {
  view: 'three-quarter', loop: true, thumb: 9, ball: BATON,
  path: { kind: 'line', length: 600 },
  cast: [{ pattern: 'relay-incoming', at: [-70, 36], follow: true }],
  keyframes: withBaton([...sprintGait, ...sprintGait, ...sprintGait], 8, 11),
});
oneCyclePath('relay-handoff');
const jogGait = gait(tempoPhases.map((ph) => ({ ...ph, kneeL: ph.kneeL * 0.8, kneeR: ph.kneeR * 0.8 })), { lean: 5, neck: -2, move: 0.14 });
def('relay-incoming-jog', 'Incoming runner (walk-through)', { view: 'three-quarter', loop: true, thumb: 0, keyframes: [...jogGait, ...jogGait, ...jogGait] });
def('relay-handoff-walkthrough', 'Relay hand-off walk-through', {
  view: 'three-quarter', loop: true, thumb: 9, ball: BATON,
  path: { kind: 'line', length: 400 },
  cast: [{ pattern: 'relay-incoming-jog', at: [-70, 36], follow: true }],
  keyframes: withBaton([...jogGait, ...jogGait, ...jogGait], 8, 11),
});
oneCyclePath('relay-handoff-walkthrough');

// ── Partners running together ─────────────────────────────────────────────
def('buddy-jog', 'Running side by side', {
  ...spec('jog'), view: 'three-quarter',
  cast: [{ pattern: 'jog', at: [0, 70], follow: true, phase: 0.5 }],
});
def('guide-run-tether', 'Guide running with a tether', {
  ...spec('jog'), view: 'three-quarter',
  cast: [{ pattern: 'jog', at: [0, 48], follow: true, tether: true }],
});
def('standing-arm-swing', 'Standing arm swing', {
  view: 'side', loop: true, thumb: 0,
  keyframes: [
    kf(P({ spine: 4, ...armsSwing(-50, 60, 88), hipL: 20, kneeL: 20, hipR: -6, kneeR: 10, ankleR: -10 }), 'feet', { move: 0.28 }),
    kf(P({ spine: 4, ...armsSwing(60, -50, 88), hipL: 20, kneeL: 20, hipR: -6, kneeR: 10, ankleR: -10 }), 'feet', { move: 0.28 }),
  ],
});
const SOFTBALL = { r: 5, color: 'yellow' };
def('overhand-throw-step', 'Overhand throw, stepping to the target', {
  view: 'three-quarter', ball: SOFTBALL, thumb: 2,
  keyframes: [
    kf(P({ turn: -80, spine: 6, ...both({ hip: 10, knee: 14, hipAbd: 14 }), shoulderR: 40, elbowR: 90, shoulderL: 40, elbowL: 90 }), 'feet', { hold: 0.4, move: 0.4, ball: 'R' }),
    kf(P({ turn: -80, spine: 0, twist: -30, hipL: 50, kneeL: 40, ankleL: 10, hipR: -4, kneeR: 20, shoulderR: 100, shoulderAbdR: 80, elbowR: 90, shoulderRotR: 60, shoulderL: 70, elbowL: 20 }), 'R', { move: 0.24, ball: 'R' }),
    kf(P({ turn: -60, spine: 20, twist: 30, hipL: 40, kneeL: 30, ankleL: 14, hipR: -20, kneeR: 30, ankleR: -24, shoulderR: 170, elbowR: 30, shoulderL: 20, elbowL: 60 }), 'L+Rtoe', { move: 0.12, ball: 'R', travel: [20, 0] }),
    kf(P({ turn: -40, spine: 34, twist: 40, hipL: 50, kneeL: 34, ankleL: 16, hipR: -20, kneeR: 40, ankleR: -26, shoulderR: 40, shoulderAbdR: -20, elbowR: 20, shoulderL: -20, elbowL: 60 }), 'L+Rtoe', { hold: 0.5, ball: { at: [420, 60, 0] } }),
  ],
});

// ── Racing wheelchair ─────────────────────────────────────────────────────
/** Kneeling in the cage: hips and knees deeply bent, chest over the knees. */
const kneelIn = (spine) => ({ ...both({ hip: 120, knee: 150, ankle: 30, hipAbd: 4 }), spine, neck: -40 });
const racingRim = (deg, side) => (sk) => {
  const floor = Math.min(sk.L.ankle[1], sk.R.ankle[1]) - 14;
  const c = [sk.pelvis[0] + 2, floor + 33, side * 21];
  return [c[0] + Math.cos((deg * Math.PI) / 180) * 24, c[1] + Math.sin((deg * Math.PI) / 180) * 24, c[2]];
};
const onRacingRims = (p, deg) => reachBoth(p, racingRim(deg, 1), racingRim(deg, -1));
const RACING = { kind: 'racingchair' };
def('racing-chair-push', 'Racing-chair push stroke', {
  view: 'side', loop: true, thumb: 0, fixture: RACING,
  keyframes: [
    kf(onRacingRims(P(kneelIn(40)), 100), 'seat', { surface: 14, move: 0.22 }),
    kf(onRacingRims(P(kneelIn(58)), 10), 'seat', { surface: 14, move: 0.16 }),
    kf(onRacingRims(P(kneelIn(60)), -60), 'seat', { surface: 14, move: 0.26 }),
    kf(P(kneelIn(48), both({ shoulder: -40, elbow: 90, shoulderAbd: 20 })), 'seat', { surface: 14, move: 0.26 }),
  ],
});
def('racing-chair-start', 'Racing-chair push start', {
  view: 'side', thumb: 1, fixture: RACING,
  keyframes: [
    kf(onRacingRims(P(kneelIn(60)), 60), 'seat', { surface: 14, hold: 0.5, move: 0.12 }),
    kf(onRacingRims(P(kneelIn(66)), 10), 'seat', { surface: 14, move: 0.1 }),
    kf(onRacingRims(P(kneelIn(62)), 60), 'seat', { surface: 14, move: 0.1 }),
    kf(onRacingRims(P(kneelIn(66)), 10), 'seat', { surface: 14, move: 0.1 }),
    kf(onRacingRims(P(kneelIn(62)), 60), 'seat', { surface: 14, move: 0.14 }),
    kf(onRacingRims(P(kneelIn(62)), -40), 'seat', { surface: 14, move: 0.2 }),
    kf(onRacingRims(P(kneelIn(44)), 100), 'seat', { surface: 14, hold: 0.3 }),
  ],
});
export const RUNNING = lib.patterns;
