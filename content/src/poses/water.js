/**
 * More swimming, water polo and rowing: catch-up and arms-only freestyle,
 * a supported float, eggbeater variations and passing/shooting with a ball
 * that really flies, climbing out onto the deck, the rowing pick drill and
 * its variations, and band shoulder care for swimmers and throwers.
 */
import { EGG_A, EGG_B, FREE_ARM, freestyle } from './individualSports.js';
import { rowAt } from './strength.js';
import { P, air, both, kf, library, mirror, reachBoth, side } from './kit.js';

const lib = library();
const def = lib.def;
const at = (f, h, l = 0) => ({ at: [f, h, l] });

// ── Swimming ───────────────────────────────────────────────────────────────
/** Catch-up: one hand waits out in front until the other arrives to touch it. */
const catchUp = () => {
  const legs = (i) => ({ hipL: i % 2 ? 6 : -6, kneeL: i % 2 ? 4 : 16, ankleL: -45, hipR: i % 2 ? -6 : 6, kneeR: i % 2 ? 16 : 4, ankleR: -45 });
  const frames = [];
  const waitL = { shoulder: 176, shoulderAbd: 8, elbow: 4 };
  [1, 2, 3, 4, 5, 0].forEach((phase, i) => frames.push(kf(P(side('L', waitL), side('R', FREE_ARM[phase]), legs(i), { spine: 88, neck: -20, twist: -12 }), 'water', { move: 0.24 })));
  [1, 2, 3, 4, 5, 0].forEach((phase, i) => frames.push(kf(P(side('R', waitL), side('L', FREE_ARM[phase]), legs(i), { spine: 88, neck: -20, twist: 12 }), 'water', { move: 0.24 })));
  return frames;
};
def('swim-catch-up', 'Catch-up freestyle', {
  path: { kind: 'line', length: 220, speed: 70 },
  loop: true, thumb: 0, fixture: { kind: 'water', level: 12 },
  keyframes: catchUp(),
});
/** Arms only: the legs trail long and still (as with a pull buoy). */
def('swim-arms-only', 'Arms-only freestyle', {
  path: { kind: 'line', length: 220, speed: 80 },
  loop: true, thumb: 0, fixture: { kind: 'water', level: 12 },
  keyframes: freestyle().map((k) => ({ ...k, pose: P(k.pose, both({ hip: 0, knee: 2, ankle: -50 })) })),
});
/** Floating face-down, long, with a coach standing in the water supporting the hips. */
def('water-support-partner', 'Supporting a swimmer (partner)', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 10, knee: 14, ankle: 6, hipAbd: 12, shoulder: 50, elbow: 40 }), { spine: 20, neck: -20 }), 'feet', { hold: 1, move: 1 }),
    kf(P(both({ hip: 12, knee: 16, ankle: 6, hipAbd: 12, shoulder: 54, elbow: 38 }), { spine: 22, neck: -20 }), 'feet', { hold: 1, move: 1 }),
  ],
});
def('swim-supported-float', 'Supported float', {
  view: 'three-quarter', loop: true, thumb: 0, fixture: { kind: 'water', level: 8 },
  cast: [{ pattern: 'water-support-partner', at: [10, -44, -86], facing: 90 }],
  keyframes: [
    kf(P(both({ shoulder: 170, shoulderAbd: 16, elbow: 8, ankle: -40 }), { spine: 88, neck: -8 }), 'water', { hold: 0.8, move: 1.2 }),
    kf(P(both({ shoulder: 170, shoulderAbd: 18, elbow: 10, ankle: -40, hip: 8, knee: 14 }), { spine: 86, neck: -8 }), 'water', { hold: 0.4, move: 0.6 }),
    kf(P(both({ shoulder: 170, shoulderAbd: 18, elbow: 10, ankle: -40, hip: -8, knee: 4 }), { spine: 86, neck: -8 }), 'water', { hold: 0.4, move: 0.6 }),
  ],
});

// ── Water polo ─────────────────────────────────────────────────────────────
const WP_BALL = { r: 11, color: 'yellow' };
const WATER = { kind: 'water', level: 50 };
def('wp-eggbeater-hands-up', 'Eggbeater, hands out of the water', {
  view: 'three-quarter', loop: true, thumb: 0, fixture: WATER,
  keyframes: [
    kf(P(EGG_A, both({ shoulder: 120, shoulderAbd: 40, elbow: 40 }), { spine: 8 }), 'water', { move: 0.45 }),
    kf(P(EGG_B, both({ shoulder: 124, shoulderAbd: 40, elbow: 40 }), { spine: 8 }), 'water', { move: 0.45 }),
  ],
});
def('wp-eggbeater-lateral', 'Sideways eggbeater', {
  view: 'three-quarter', loop: true, thumb: 0, fixture: WATER,
  path: { kind: 'shuttle', length: 300, dir: 'left', speed: 60 },
  keyframes: [
    kf(P(EGG_A, both({ shoulder: 60, shoulderAbd: 60, elbow: 30 }), { spine: 10 }), 'water', { move: 0.4 }),
    kf(P(EGG_B, both({ shoulder: 60, shoulderAbd: 60, elbow: 30 }), { spine: 10 }), 'water', { move: 0.4 }),
  ],
});
/** Pass and receive with a raised hand: the ball never touches the water. */
const wpPassCatch = (ball) => [
  kf(P(EGG_A, side('R', { shoulder: 160, shoulderAbd: 30, elbow: 20 }), side('L', { shoulder: 60, shoulderAbd: 30, elbow: 20 }), { spine: 4 }), 'water', { hold: 0.2, move: 0.3, ...(ball && { ball: 'R' }) }),
  kf(P(EGG_B, side('R', { shoulder: 160, shoulderAbd: 40, shoulderRot: -40, elbow: 80 }), side('L', { shoulder: 60, shoulderAbd: 30, elbow: 20 }), { spine: -4, twist: -20 }), 'water', { hold: 0.2, move: 0.3, ...(ball && { ball: 'R' }) }),
  kf(P(EGG_A, side('R', { shoulder: 130, shoulderAbd: 20, shoulderRot: 20, elbow: 5 }), side('L', { shoulder: 40, shoulderAbd: 30, elbow: 30 }), { spine: 6, twist: 10 }), 'water', { hold: 1.2, move: 0.5, ...(ball && { ball: ball.out, ballArc: 30 }) }),
];
def('wp-pass-partner', 'Pass and catch (partner)', { view: 'three-quarter', loop: true, thumb: 0, fixture: WATER, keyframes: wpPassCatch(null) });
def('wp-wall-passing', 'Dry passing with a partner', {
  view: 'three-quarter', loop: true, thumb: 1, fixture: WATER, ball: WP_BALL,
  cast: [{ pattern: 'wp-pass-partner', at: [330, 0], facing: 180, phase: 0.5 }],
  keyframes: wpPassCatch({ out: 'c0:R' }),
});
def('wp-shot-flight', 'Shot from the eggbeater', {
  view: 'three-quarter', fixture: { kind: 'water', level: 46 }, ball: WP_BALL, thumb: 1,
  keyframes: [
    kf(P(EGG_A, side('R', { shoulder: 150, shoulderAbd: 70, shoulderRot: -70, elbow: 95 }), side('L', { shoulder: 80, shoulderAbd: 20, elbow: 20 }), { spine: -8, twist: -35, turn: -20 }), 'water', { hold: 0.35, move: 0.25, ball: 'R' }),
    kf(P(EGG_B, side('R', { shoulder: 165, shoulderAbd: 30, shoulderRot: 10, elbow: 20 }), side('L', { shoulder: 40, shoulderAbd: 30, elbow: 40 }), { spine: 8, twist: 15, turn: -10 }), 'water', { move: 0.3, ball: 'R' }),
    kf(P(EGG_A, side('R', { shoulder: 70, shoulderAbd: 20, shoulderRot: 40, elbow: 10 }), side('L', { shoulder: 10, shoulderAbd: 30, elbow: 40 }), { spine: 25, twist: 30, turn: 0 }), 'water', { hold: 0.5, ball: at(460, 20, 0) }),
  ],
});
def('wp-catch-and-shoot', 'Catch high and shoot', {
  view: 'three-quarter', fixture: { kind: 'water', level: 46 }, ball: WP_BALL, thumb: 1,
  cast: [{ pattern: 'wp-pass-partner', at: [330, 200], facing: 215, phase: 0.2 }],
  keyframes: [
    kf(P(EGG_A, side('R', { shoulder: 170, shoulderAbd: 30, elbow: 10 }), side('L', { shoulder: 60, shoulderAbd: 30, elbow: 20 }), { spine: 4, turn: 30 }), 'water', { hold: 0.2, move: 0.5, ball: 'c0:R', ballArc: 30 }),
    kf(P(EGG_B, side('R', { shoulder: 160, shoulderAbd: 60, shoulderRot: -60, elbow: 80 }), side('L', { shoulder: 70, shoulderAbd: 20, elbow: 20 }), { spine: -6, twist: -30, turn: 0 }), 'water', { move: 0.2, ball: 'R' }),
    kf(P(EGG_A, side('R', { shoulder: 70, shoulderAbd: 20, shoulderRot: 40, elbow: 10 }), side('L', { shoulder: 10, shoulderAbd: 30, elbow: 40 }), { spine: 25, twist: 30 }), 'water', { hold: 0.5, ball: at(460, 20, -60) }),
  ],
});
/** Head-up sprint, pop up to eggbeater for a look, sprint again. */
def('wp-counterattack', 'Head-up sprint into eggbeater', {
  fixture: { kind: 'water', level: 12 }, thumb: 6,
  keyframes: [
    ...freestyle({ spine: 72, neck: -52, roll: 12, kick: 16 }).map((k) => ({ ...k, travel: [26, 0] })),
    kf(P(EGG_A, both({ shoulder: 60, shoulderAbd: 60, elbow: 30 }), { spine: 10 }), 'water', { hold: 0.2, move: 0.4, surface: -38 }),
    kf(P(EGG_B, both({ shoulder: 60, shoulderAbd: 60, elbow: 30 }), { spine: 10 }), 'water', { hold: 0.2, move: 0.4, surface: -38 }),
    kf(P(EGG_A, both({ shoulder: 60, shoulderAbd: 60, elbow: 30 }), { spine: 10 }), 'water', { hold: 0.2, move: 0.4, surface: -38 }),
  ],
});
/** Defender behind the centre: a hand on the centre's back, strong eggbeater to hold the spot. */
def('wp-centre-hold', 'Centre holding position (partner)', {
  view: 'three-quarter', loop: true, thumb: 0, fixture: WATER,
  keyframes: [
    kf(P(EGG_A, both({ shoulder: 50, shoulderAbd: 50, elbow: 40 }), { spine: -6 }), 'water', { move: 0.45 }),
    kf(P(EGG_B, both({ shoulder: 54, shoulderAbd: 50, elbow: 40 }), { spine: -8 }), 'water', { move: 0.45 }),
  ],
});
def('wp-defend-centre', 'Defending the centre', {
  view: 'three-quarter', loop: true, thumb: 0, fixture: WATER,
  cast: [{ pattern: 'wp-centre-hold', at: [70, -44], facing: 0 }],
  keyframes: [
    kf(P(EGG_A, side('L', { shoulder: 90, elbow: 20, shoulderAbd: 10 }), side('R', { shoulder: 50, shoulderAbd: 60, elbow: 30 }), { spine: 14 }), 'water', { move: 0.45 }),
    kf(P(EGG_B, side('L', { shoulder: 92, elbow: 18, shoulderAbd: 10 }), side('R', { shoulder: 54, shoulderAbd: 60, elbow: 30 }), { spine: 16 }), 'water', { move: 0.45 }),
  ],
});

// ── Out of the pool ────────────────────────────────────────────────────────
/** Swim in, hands on the deck, press up, knee up, stand and jog off peeling the cap. */
def('pool-exit', 'Climbing out and jogging off', {
  view: 'side', thumb: 3, fixture: { kind: 'water', level: 12, deck: 44, deckTop: 36 },
  keyframes: [
    ...freestyle().slice(0, 3).map((k) => ({ ...k, travel: [20, 0] })),
    kf(reachBoth(P(both({ hip: 10, knee: 20, ankle: -30 }), { spine: 20, neck: -10 }), air(40, 40, 16), air(40, 40, -16)), 'water', { hold: 0.2, move: 0.4, surface: -36, travel: [30, 0] }),
    kf(reachBoth(P(both({ hip: 30, knee: 40, ankle: -30 }), { spine: 40, neck: -20 }), air(20, -10, 16), air(20, -10, -16)), 'water', { move: 0.4, surface: 10 }),
    kf(P({ spine: 50, hipL: 120, kneeL: 120, ankleL: 30, hipR: 40, kneeR: 90, ankleR: -40, ...both({ shoulder: 40, elbow: 10 }) }), 'L+Rknee', { move: 0.5, surface: 36, travel: [64, 0] }),
    kf(P({ spine: 4, shoulderL: 160, elbowL: 100, shoulderR: 160, elbowR: 100 }), 'feet', { hold: 0.3, move: 0.3, surface: 36, travel: [20, 0] }),
    kf(P({ spine: 8, hipL: 26, kneeL: 14, ankleL: 4, hipR: -10, kneeR: 70, ankleR: -20, shoulderL: 160, elbowL: 100, shoulderR: 160, elbowR: 100 }), 'L', { move: 0.2, surface: 36, travel: [30, 0] }),
    kf(P({ spine: 8, hipR: 26, kneeR: 14, ankleR: 4, hipL: -10, kneeL: 70, ankleL: -20, shoulderL: 60, elbowL: 90, shoulderR: 160, elbowR: 100 }), 'R', { hold: 0.3, surface: 36, travel: [40, 0] }),
  ],
});

// ── Rowing ─────────────────────────────────────────────────────────────────
const ERG = { fixture: { kind: 'rower' }, implement: { kind: 'cable', at: 'hands', to: [22, 18, 0] } };
const stroke = (k, move, hold = 0) => kf(k, 'seat+feet', { move, hold, surface: 30 });
const FINISH = () => rowAt(4, -18, true), BODY_OVER = () => rowAt(4, 20, false), BACK = () => rowAt(4, -14, false);
/** Pick drill: arms only, then arms and body, then half slide, then full slide. */
def('rowing-pick-drill', 'Pick drill', {
  ...ERG, loop: true, thumb: 0,
  keyframes: [
    stroke(rowAt(4, -18, false), 0.3), stroke(FINISH(), 0.3),
    stroke(rowAt(4, -18, false), 0.3), stroke(FINISH(), 0.3),
    stroke(BODY_OVER(), 0.3), stroke(BACK(), 0.2), stroke(FINISH(), 0.3),
    stroke(BODY_OVER(), 0.3), stroke(rowAt(50, 20, false), 0.3), stroke(BACK(), 0.25), stroke(FINISH(), 0.3),
    stroke(BODY_OVER(), 0.3), stroke(rowAt(104, 22, false), 0.3), stroke(rowAt(50, 20, false), 0.22), stroke(BACK(), 0.2), stroke(FINISH(), 0.3),
  ],
});
def('rowing-pause-body-over', 'Pause at body-over', {
  ...ERG, loop: true, thumb: 3,
  keyframes: [
    stroke(rowAt(104, 22, false), 0.3, 0.05), stroke(rowAt(50, 20, false), 0.22), stroke(BACK(), 0.2), stroke(FINISH(), 0.25, 0.1),
    stroke(BODY_OVER(), 0.8, 0.7),
  ],
});
/** Legs only: arms long, back still — the handle moves with the legs alone. */
def('rowing-legs-only', 'Legs-only rowing', {
  ...ERG, loop: true, thumb: 0,
  keyframes: [stroke(rowAt(104, 20, false), 0.35, 0.05), stroke(rowAt(50, 20, false), 0.25), stroke(rowAt(4, 20, false), 0.5)],
});
/** Renegade row: a plank on two dumbbells, one rowed to the ribs, hips square. */
def('renegade-row', 'Plank row', {
  view: 'three-quarter', implement: { kind: 'dumbbells', at: 'hands' }, thumb: 1,
  keyframes: [
    kf(P(both({ shoulder: 90, elbow: 0, hipAbd: 14, ankle: -10 }), { spine: 90, neck: -10 }), 'hands+Ltoe+Rtoe', { hold: 0.3, move: 0.6 }),
    kf(P(both({ hipAbd: 14, ankle: -10 }), { shoulderL: 90, elbowL: 0, shoulderR: 10, elbowR: 100, spine: 90, neck: -10 }), 'Lhand+Ltoe+Rtoe', { hold: 0.3, move: 0.6 }),
    kf(P(both({ shoulder: 90, elbow: 0, hipAbd: 14, ankle: -10 }), { spine: 90, neck: -10 }), 'hands+Ltoe+Rtoe', { hold: 0.2, move: 0.6 }),
    kf(P(both({ hipAbd: 14, ankle: -10 }), { shoulderR: 90, elbowR: 0, shoulderL: 10, elbowL: 100, spine: 90, neck: -10 }), 'Rhand+Ltoe+Rtoe', { hold: 0.3, move: 0.6 }),
  ],
});

// ── Shoulder care with a band (swimmers, throwers, pushers) ───────────────
/** Band between the hands: external rotations (elbows at the sides), pull-aparts, then Y raises. */
def('band-shoulder-series', 'Band shoulder routine', {
  view: 'front', implement: { kind: 'band', at: 'hands' }, thumb: 1,
  keyframes: [
    kf(P(both({ shoulder: 10, elbow: 90, shoulderRot: 0 })), 'feet', { hold: 0.2, move: 0.8 }),
    kf(P(both({ shoulder: 10, elbow: 90, shoulderRot: -60 })), 'feet', { hold: 0.3, move: 0.8 }),
    kf(P(both({ shoulder: 10, elbow: 90, shoulderRot: 0 })), 'feet', { hold: 0.1, move: 0.6 }),
    kf(P(both({ shoulder: 90, shoulderAbd: 10, elbow: 2 })), 'feet', { hold: 0.1, move: 0.8 }),
    kf(P(both({ shoulder: 90, shoulderAbd: 84, elbow: 2 })), 'feet', { hold: 0.3, move: 0.8 }),
    kf(P(both({ shoulder: 90, shoulderAbd: 10, elbow: 2 })), 'feet', { hold: 0.1, move: 0.6 }),
    kf(P(both({ shoulder: 160, shoulderAbd: 30, elbow: 2 })), 'feet', { hold: 0.3, move: 0.8 }),
  ],
});

export const WATER_SPORTS = lib.patterns;
void mirror;
