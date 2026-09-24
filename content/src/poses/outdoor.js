/**
 * Skiing, surfing, sailing, skateboarding, climbing, riding, esports
 * conditioning, ultimate, and crew rowing: skis and poles on a slope with
 * linked turns, a surfboard to paddle and pop up on, hiking out over a
 * bench, a skateboard that tilts with the feet, a climbing wall, a horse,
 * and a rowing shell with a sweep oar.
 */
import { add, apply } from '../rig3d.js';
import { STRENGTH, rowAt } from './strength.js';
import { MISC_SPORTS } from './miscSports.js';
import { P, air, both, flatHands, ground, handsToFloor, kf, library, mirror, reach, reachBoth, side } from './kit.js';

const lib = library();
const def = lib.def;
const spec = (slug) => {
  const { slug: _s, name: _n, ...rest } = [...STRENGTH, ...MISC_SPORTS].find((p) => p.slug === slug);
  return rest;
};

// ── Skiing ─────────────────────────────────────────────────────────────────
const SKIS = { kind: 'skis', poles: true };
/** Athletic ski stance: ankles and knees flexed, hands forward, poles back. */
const skiStance = (extra = {}) => P(both({ hip: 36, knee: 44, ankle: 24, hipAbd: 6, shoulder: 40, shoulderAbd: 14, elbow: 50 }), { spine: 24, neck: -14 }, extra);
/** Angulated into a turn: hips in, shoulders level, outside leg long. */
const turn = (dir) => P(skiStance(), { bend: -10 * dir, turn: 10 * dir, [`hipAbd${dir > 0 ? 'R' : 'L'}`]: 14, [`knee${dir > 0 ? 'L' : 'R'}`]: 54 });
def('ski-short-turns', 'Short-radius turns with pole plants', {
  view: 'three-quarter', implement: SKIS, loop: true, thumb: 0,
  path: { kind: 'line', length: 520, speed: 220, grade: -0.1, swerve: { amp: 40, length: 180 } },
  keyframes: [
    kf(P(turn(1), { shoulderL: 70, elbowL: 30 }), 'air', { move: 0.2 }),
    kf(turn(1), 'air', { move: 0.21 }),
    kf(P(turn(-1), { shoulderR: 70, elbowR: 30 }), 'air', { move: 0.2 }),
    kf(turn(-1), 'air', { move: 0.21 }),
  ],
});
def('ski-javelin-turns', 'Javelin turns (on the outside ski)', {
  view: 'three-quarter', implement: SKIS, loop: true, thumb: 0,
  path: { kind: 'line', length: 520, speed: 200, grade: -0.1, swerve: { amp: 50, length: 260 } },
  keyframes: [
    kf(P(turn(1), { hipL: 50, kneeL: 50, hipAbdL: -14, hipRotL: 30, twist: -14 }), 'air', { move: 0.6 }),
    kf(P(turn(-1), { hipR: 50, kneeR: 50, hipAbdR: -14, hipRotR: 30, twist: 14 }), 'air', { move: 0.6 }),
  ],
});
/** Hop turns: plant the pole, hop both skis off the snow, pivot, land on the new edges. */
def('ski-hop-turns', 'Hop turns', {
  view: 'three-quarter', implement: SKIS, loop: true, thumb: 1,
  keyframes: [
    kf(P(skiStance(both({ hip: 50, knee: 60 })), { turn: 20, shoulderL: 70, elbowL: 30 }), 'feet', { hold: 0.1, move: 0.16 }),
    kf(P(both({ hip: 40, knee: 60, ankle: 10, shoulder: 40, elbow: 50 }), { spine: 20, turn: 0, lift: 18 }), 'air', { move: 0.16 }),
    kf(P(skiStance(both({ hip: 50, knee: 60 })), { turn: -20, shoulderR: 70, elbowR: 30 }), 'feet', { hold: 0.1, move: 0.16 }),
    kf(P(both({ hip: 40, knee: 60, ankle: 10, shoulder: 40, elbow: 50 }), { spine: 20, turn: 0, lift: 18 }), 'air', { move: 0.16 }),
  ],
});
/** Tuck: compact, back flat, hands forward, poles tucked under the arms. */
def('ski-tuck', 'Tuck glide', {
  view: 'side', implement: SKIS, loop: true, thumb: 0,
  path: { kind: 'line', length: 600, speed: 380, grade: -0.08 },
  keyframes: [
    kf(P(both({ hip: 100, knee: 110, ankle: 34, shoulder: 70, elbow: 110, hipAbd: 6 }), { spine: 62, neck: -40 }), 'feet', { move: 0.8 }),
    kf(P(both({ hip: 102, knee: 112, ankle: 34, shoulder: 70, elbow: 110, hipAbd: 6 }), { spine: 64, neck: -40 }), 'feet', { move: 0.8 }),
  ],
});
def('wall-sit-tuck', 'Wall sit in a tuck', {
  ...spec('wall-sit'),
  keyframes: spec('wall-sit').keyframes.map((k) => ({ ...k, pose: P(k.pose, both({ shoulder: 80, elbow: 90, shoulderAbd: 10 })) })),
});
/** Start-gate pull: bands from a high anchor ahead, pulled down past the hips as the chest drives forward. */
def('start-gate-pull', 'Start-gate band pulls', {
  view: 'side', implement: { kind: 'band', at: 'hands', to: [90, 110, 0] }, thumb: 1,
  keyframes: [
    kf(skiStance({ ...both({ shoulder: 100, elbow: 10 }), spine: 10 }), 'feet', { hold: 0.3, move: 0.2 }),
    kf(P(skiStance({ spine: 44 }), both({ shoulder: -40, elbow: 10 })), 'Ltoe+Rtoe', { hold: 0.3, move: 0.8 }),
  ],
});
def('double-pole-pull', 'Double-pole band pulls', {
  view: 'side', implement: { kind: 'band', at: 'hands', to: [90, 110, 0] }, thumb: 1,
  keyframes: [
    kf(P(both({ hip: 10, knee: 10, shoulder: 120, elbow: 10 }), { spine: 6 }), 'feet', { hold: 0.2, move: 0.3 }),
    kf(P(both({ hip: 60, knee: 20, ankle: 10, shoulder: -10, elbow: 10 }), { spine: 50, neck: -20 }), 'feet', { hold: 0.3, move: 0.9 }),
  ],
});

// ── Surfing ────────────────────────────────────────────────────────────────
const BOARD_MAT = { kind: 'surfboard', from: -100, to: 100 };
const BOARD_WATER = { kind: 'surfboard', from: -100, to: 100, y: 30, water: 1 };
/** Prone on the board, chest lifted, arms paddling alternately. */
const paddle = (l, r) => P({ spine: 80, neck: -30, ...both({ hip: -6, knee: 20, ankle: -40 }) }, side('L', l), side('R', r));
const STROKE = [{ shoulder: 170, elbow: 10 }, { shoulder: 110, elbow: 30 }, { shoulder: 30, elbow: 20 }, { shoulder: 110, shoulderAbd: 40, elbow: 90 }];
def('surf-paddle', 'Prone paddling', {
  view: 'side', fixture: BOARD_WATER, loop: true, thumb: 0,
  keyframes: [0, 1, 2, 3].map((i) => kf(paddle(STROKE[i], STROKE[(i + 2) % 4]), 'air', { move: 0.24, surface: 12 })),
});
def('band-paddle-pull', 'Band paddle pulls', {
  view: 'side', implement: { kind: 'band', at: 'hands', to: [80, 120, 0] }, loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 60, knee: 20, ankle: 10 }), { spine: 60, neck: -20, shoulderL: 170, elbowL: 10, shoulderR: 20, elbowR: 20 }), 'feet', { move: 0.6 }),
    kf(P(both({ hip: 60, knee: 20, ankle: 10 }), { spine: 60, neck: -20, shoulderR: 170, elbowR: 10, shoulderL: 20, elbowL: 20 }), 'feet', { move: 0.6 }),
  ],
});
/** Surf stance: side-on, feet across the board, knees bent, arms out for balance. */
const surfStance = (extra = {}) => P({ turn: 80, spine: 20, neck: -10, neckTurn: -60, ...both({ hip: 46, knee: 60, ankle: 26, hipAbd: 24 }), shoulderL: 40, shoulderAbdL: 60, elbowL: 20, shoulderR: 20, shoulderAbdR: 60, elbowR: 30 }, extra);
const popUp = (hold) => [
  kf(flatHands(P({ spine: 88, neck: -20, ...both({ hip: 0, knee: 4, ankle: -40, shoulder: 20, shoulderAbd: 40, elbow: 120 }) })), 'air', { hold: 0.5, move: 0.3 }),
  kf(flatHands(P({ spine: 60, neck: -20, ...both({ hip: -10, knee: 4, ankle: -40, shoulder: 80, elbow: 0 }) })), 'hands+Ltoe+Rtoe', { move: 0.2 }),
  kf(surfStance(), 'feet', { hold, move: 0.5, travel: [30, 0] }),
];
def('surf-pop-up', 'Pop-ups', { view: 'side', fixture: BOARD_MAT, thumb: 2, keyframes: popUp(0.6) });
def('surf-pop-up-hold', 'Pop-up and hold the stance', { view: 'side', fixture: BOARD_MAT, thumb: 2, keyframes: popUp(3) });
def('surf-stance-balance', 'Surf stance balance with shoulder turns', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [kf(surfStance({ twist: 20 }), 'feet', { hold: 0.6, move: 0.8 }), kf(surfStance({ twist: -20 }), 'feet', { hold: 0.6, move: 0.8 })],
});

// ── Sailing ────────────────────────────────────────────────────────────────
/** Hiking: sitting on the bench edge, feet under the strap, body out straight. */
const hike = (reach) => P({ spine: -80, neck: 20, ...both({ hip: 14, knee: 30, ankle: 10 }), ...both(reach ? { shoulder: 120, elbow: 10 } : { shoulder: 40, elbow: 90 }) });
def('sail-hiking', 'Hiking holds', {
  view: 'side', fixture: { kind: 'bench', from: -30, to: 20, top: 44 }, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 90, knee: 90, ankle: 0 }), { spine: 0 }), 'seat', { hold: 0.3, move: 0.8, surface: 44 }),
    kf(hike(false), 'seat', { hold: 2.5, move: 0.8 }),
    kf(hike(true), 'seat', { hold: 1, move: 0.6 }),
    kf(hike(false), 'seat', { hold: 1, move: 0.6 }),
    kf(P(both({ hip: 90, knee: 90, ankle: 0 }), { spine: 0 }), 'seat', { hold: 0.3 }),
  ],
});
/** Tacking: duck low, cross to the other side facing forward, hike out again. */
def('sail-tack', 'Tack crossovers', {
  view: 'front', fixture: { kind: 'bench', from: -30, to: 20, top: 44 }, thumb: 2,
  keyframes: [
    kf(P({ bend: 40, ...both({ hip: 90, knee: 30, ankle: 10 }), shoulderL: 40, elbowL: 90, shoulderR: 40, elbowR: 90 }), 'seat', { hold: 0.8, move: 0.4, surface: 44 }),
    kf(P(both({ hip: 90, knee: 110, ankle: 30, shoulder: 40, elbow: 90 }), { spine: 50, neck: -20 }), 'air', { move: 0.4, travel: [0, -30] }),
    kf(P({ bend: -40, ...both({ hip: 90, knee: 30, ankle: 10 }), shoulderL: 40, elbowL: 90, shoulderR: 40, elbowR: 90 }), 'seat', { hold: 0.8, move: 0.4, surface: 44, travel: [0, -30] }),
  ],
});
def('sail-crouch-turns', 'Crouch transitions', {
  view: 'three-quarter', thumb: 1,
  keyframes: [
    kf(P(both({ hip: 110, knee: 130, ankle: 34, hipAbd: 20, shoulder: 50, elbow: 70 }), { spine: 30 }), 'feet', { hold: 0.3, move: 0.3 }),
    kf(P(both({ hip: 20, knee: 26, ankle: 10, hipAbd: 16, shoulder: 50, elbow: 70 }), { spine: 10, turn: 90 }), 'feet', { hold: 0.3, move: 0.3 }),
    kf(P(both({ hip: 110, knee: 130, ankle: 34, hipAbd: 20, shoulder: 50, elbow: 70 }), { spine: 30, turn: 90 }), 'feet', { hold: 0.3, move: 0.3 }),
    kf(P(both({ hip: 20, knee: 26, ankle: 10, hipAbd: 16, shoulder: 50, elbow: 70 }), { spine: 10, turn: 180 }), 'feet', { hold: 0.3 }),
  ],
});
def('wall-sit-reach', 'Wall sit with arm reaches', {
  ...spec('wall-sit'), loop: true,
  keyframes: [
    { ...spec('wall-sit').keyframes[0], pose: P(spec('wall-sit').keyframes[0].pose, both({ shoulder: 90, elbow: 0 })), hold: 1, move: 0.6 },
    { ...spec('wall-sit').keyframes[0], pose: P(spec('wall-sit').keyframes[0].pose, both({ shoulder: 175, elbow: 0 })), hold: 1, move: 0.6 },
  ],
});
def('towel-inverted-row', 'Towel inverted row', {
  ...spec('inverted-row'), fixture: { ...spec('inverted-row').fixture, above: 22 }, implement: { kind: 'towels', at: 'hands' },
});
/** Balancing on one foot, catching and returning throws from a partner. */
const CATCH_BALL = { r: 11, color: 'yellow' };
def('throw-partner', 'Partner throwing', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 10, knee: 14, shoulder: 60, elbow: 60 })), 'feet', { hold: 0.7, move: 0.3 }),
    kf(P(both({ hip: 10, knee: 14, shoulder: 90, elbow: 4 })), 'feet', { hold: 0.9, move: 0.3 }),
  ],
});
def('balance-catch', 'Single-leg balance catches', {
  view: 'three-quarter', ball: CATCH_BALL, loop: true, thumb: 1,
  cast: [{ pattern: 'throw-partner', at: [240, 30], facing: 190, phase: 0.1 }],
  keyframes: [
    kf(P({ hipR: 40, kneeR: 70, ...both({ shoulder: 70, elbow: 30 }) }), 'L', { hold: 0.5, move: 0.5, ball: 'c0:hands', ballArc: 20 }),
    kf(P({ hipR: 40, kneeR: 70, ...both({ shoulder: 70, elbow: 40 }) }), 'L', { hold: 0.4, move: 0.5, ball: 'hands' }),
    kf(P({ hipR: 40, kneeR: 70, ...both({ shoulder: 90, elbow: 4 }) }), 'L', { hold: 0.4, ball: 'c0:hands', ballArc: 20 }),
  ],
});

// ── Skateboarding ──────────────────────────────────────────────────────────
const SK8 = { kind: 'skateboard' };
/** Skate stance: side-on, front foot over the front bolts, back foot on the tail. */
const skate = (extra = {}) => P({ turn: 80, neckTurn: -70, spine: 10, hipL: 20, kneeL: 30, ankleL: 16, hipAbdL: 20, hipR: 20, kneeR: 30, ankleR: 16, hipAbdR: 20, shoulderAbdL: 40, shoulderAbdR: 40, elbowL: 20, elbowR: 20 }, extra);
def('skate-ollie', 'Ollie over a line', {
  view: 'side', implement: SK8, fixture: { kind: 'cone', at: 60 }, thumb: 3,
  keyframes: [
    kf(skate(), 'feet', { hold: 0.3, move: 0.3, surface: 9 }),
    kf(skate({ ...both({ hip: 60, knee: 80, ankle: 30, hipAbd: 20 }), spine: 20 }), 'feet', { move: 0.14, surface: 9 }),
    kf(skate({ hipR: 30, kneeR: 20, ankleR: -30, hipL: 60, kneeL: 90, ankleL: 10 }), 'Rtoe', { move: 0.14, surface: 9, travel: [20, 0] }),
    kf(skate({ ...both({ hip: 70, knee: 100, ankle: 20, hipAbd: 20 }), spine: 16, lift: 26 }), 'air', { move: 0.2, travel: [40, 0] }),
    kf(skate({ ...both({ hip: 50, knee: 70, ankle: 26, hipAbd: 20 }), spine: 20 }), 'feet', { hold: 0.4, surface: 9, travel: [40, 0] }),
  ],
});
def('skate-manual', 'Manual', {
  view: 'side', implement: SK8, loop: true, thumb: 0,
  path: { kind: 'line', length: 400, speed: 120 },
  keyframes: [
    kf(skate({ hipL: 10, kneeL: 20, ankleL: 30, hipR: 30, kneeR: 50, ankleR: 20, spine: -4 }), 'R', { hold: 0.8, move: 0.4, surface: 9 }),
    kf(skate({ hipL: 12, kneeL: 22, ankleL: 32, hipR: 32, kneeR: 52, ankleR: 20, spine: -6 }), 'R', { hold: 0.8, move: 0.4, surface: 9 }),
  ],
});
def('jump-180', '180 jump landings', {
  view: 'three-quarter', thumb: 2,
  keyframes: [
    kf(P(both({ hip: 40, knee: 50, ankle: 22, shoulder: -20 }), { spine: 16 }), 'feet', { hold: 0.3, move: 0.2 }),
    kf(P(both({ ankle: -30, shoulder: 60, shoulderAbd: 30 }), { turn: 90, lift: 24 }), 'air', { move: 0.2 }),
    kf(P(both({ hip: 50, knee: 60, ankle: 26, shoulder: 40, shoulderAbd: 30 }), { spine: 20, turn: 180 }), 'feet', { hold: 0.6 }),
  ],
});

// ── Climbing ───────────────────────────────────────────────────────────────
const BAR = { kind: 'bar' };
const hang = spec('dead-hang').keyframes[0].pose;
def('hang-repeaters', 'Hang repeaters (7 on, 3 off)', {
  view: 'three-quarter', fixture: BAR, thumb: 1,
  keyframes: [
    kf(P(both({ shoulder: 176, shoulderAbd: 14, elbow: 70, hip: 10, knee: 20 })), 'feet', { hold: 0.4, move: 0.4 }),
    kf(hang, 'grip', { hold: 7, move: 0.4, surface: 14 }),
    kf(P(both({ shoulder: 176, shoulderAbd: 14, elbow: 70, hip: 10, knee: 20 })), 'feet', { hold: 3 }),
  ],
});
def('lock-off-holds', 'Lock-off holds', {
  view: 'three-quarter', fixture: BAR, thumb: 2,
  keyframes: [
    kf(hang, 'grip', { hold: 0.4, move: 1, surface: 14 }),
    kf(spec('pull-up').keyframes[1].pose, 'grip', { hold: 5, move: 0.6 }),
    kf(P(spec('pull-up').keyframes[1].pose, both({ elbow: 90, shoulder: 150 })), 'grip', { hold: 5, move: 0.8 }),
    kf(P(spec('pull-up').keyframes[1].pose, both({ elbow: 60, shoulder: 165 })), 'grip', { hold: 5, move: 1.2 }),
    kf(hang, 'grip', { hold: 0.3 }),
  ],
});
def('tuck-front-lever', 'Tuck front lever', {
  view: 'side', fixture: { kind: 'bar' }, loop: true, thumb: 0,
  keyframes: [
    kf(P({ spine: -90, neck: 10, ...both({ shoulder: 90, shoulderAbd: 10, elbow: 0, hip: 120, knee: 130, ankle: -30 }) }), 'grip', { hold: 2, move: 0.6, surface: 90 }),
    kf(P({ spine: -88, neck: 10, ...both({ shoulder: 88, shoulderAbd: 10, elbow: 0, hip: 122, knee: 130, ankle: -30 }) }), 'grip', { hold: 2, move: 0.6 }),
  ],
});
/** Traversing the wall: hands and feet on holds, moving sideways, looking at each foothold. */
const onWall = (reachL, reachR, footL, footR) => P({ spine: -4, neck: 10, shoulderL: 160, shoulderAbdL: 20 + reachL, elbowL: 20, shoulderR: 160, shoulderAbdR: 20 + reachR, elbowR: 20,
  hipL: 40 + footL, kneeL: 70, ankleL: 10, hipAbdL: 30, hipR: 40 + footR, kneeR: 70, ankleR: 10, hipAbdR: 30, lift: 50 });
def('climb-traverse', 'Silent-feet traverse', {
  view: 'back', fixture: { kind: 'climbwall', at: 26 }, loop: true, thumb: 0,
  path: { kind: 'shuttle', length: 180, dir: 'left', speed: 30 },
  keyframes: [
    kf(onWall(20, 0, 0, 20), 'air', { hold: 0.4, move: 0.8 }),
    kf(P(onWall(20, 0, 20, 0), { neck: 40 }), 'air', { hold: 0.4, move: 0.8 }),
    kf(onWall(0, 20, 20, 0), 'air', { hold: 0.4, move: 0.8 }),
    kf(P(onWall(0, 20, 0, 20), { neck: 40 }), 'air', { hold: 0.4, move: 0.8 }),
  ],
});
def('climb-route-preview', 'Route preview and mime', {
  view: 'three-quarter', fixture: { kind: 'climbwall', at: 90 }, thumb: 1,
  keyframes: [
    kf(P({ neck: -30 }), 'feet', { hold: 0.8, move: 0.5 }),
    kf(P({ neck: -30, shoulderL: 150, shoulderAbdL: 30, elbowL: 30 }), 'feet', { hold: 0.4, move: 0.4 }),
    kf(P({ neck: -34, shoulderR: 170, shoulderAbdR: 20, elbowR: 20, shoulderL: 60, elbowL: 60 }), 'feet', { hold: 0.4, move: 0.4 }),
    kf(P({ neck: -40, shoulderL: 175, shoulderAbdL: 10, elbowL: 10, shoulderR: 90, elbowR: 60 }), 'feet', { hold: 0.4, move: 0.4 }),
    kf(P({ neck: -30 }), 'feet', { hold: 0.4 }),
  ],
});

// ── Riding ─────────────────────────────────────────────────────────────────
/** Two-point: folded at the hip over the heels, heels down, hands forward on the reins. */
def('two-point-hold', 'Two-point hold', {
  view: 'side', fixture: { kind: 'box', under: 'feet', width: 18, top: 16 }, loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 70, knee: 70, ankle: 36, shoulder: 60, elbow: 70 }), { spine: 46, neck: -30 }), 'feet', { hold: 2, move: 0.8, surface: 16 }),
    kf(P(both({ hip: 72, knee: 72, ankle: 38, shoulder: 60, elbow: 70 }), { spine: 48, neck: -30 }), 'feet', { hold: 2, move: 0.8, surface: 16 }),
  ],
});
def('rein-squeeze', 'Rein grip squeezes', {
  view: 'three-quarter', implement: { kind: 'band', at: 'hands' }, loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ shoulder: 40, elbow: 80, shoulderAbd: 6, wrist: 0 }), { spine: 4 }), 'feet', { hold: 1, move: 0.3 }),
    kf(P(both({ shoulder: 40, elbow: 84, shoulderAbd: 6, wrist: 10 }), { spine: 4 }), 'feet', { hold: 1, move: 0.3 }),
  ],
});
/** Riding without stirrups: a long leg and a quiet seat through the sitting trot. */
def('ride-no-stirrups', 'Riding without stirrups', {
  view: 'side', fixture: { kind: 'horse' }, loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 30, knee: 30, ankle: 20, hipAbd: 24, shoulder: 30, elbow: 90 }), { spine: 0 }), 'seat', { move: 0.22, surface: 150 }),
    kf(P(both({ hip: 28, knee: 28, ankle: 20, hipAbd: 24, shoulder: 30, elbow: 90 }), { spine: 2 }), 'seat', { move: 0.22, fx: { lift: 5 } }),
  ],
});

// ── Esports conditioning ───────────────────────────────────────────────────
/** A partner holds a ball out at shoulder height and drops it; catch it before it bounces twice. */
def('drop-partner', 'Partner dropping a ball', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [
    kf(P({ shoulderR: 90, elbowR: 0, wristR: -10 }), 'feet', { hold: 1.2, move: 0.1 }),
    kf(P({ shoulderR: 90, elbowR: 0, wristR: 20 }), 'feet', { hold: 1.2, move: 0.4 }),
  ],
});
def('reaction-ball-drop', 'Reaction ball drops', {
  view: 'three-quarter', ball: { r: 5, color: 'yellow' }, loop: true, thumb: 2,
  cast: [{ pattern: 'drop-partner', at: [80, -30], facing: 180 }],
  keyframes: [
    kf(P(both({ hip: 40, knee: 50, ankle: 22, shoulder: 40, elbow: 60 }), { spine: 24 }), 'feet', { hold: 1.1, move: 0.2, ball: 'c0:R' }),
    kf(P(both({ hip: 40, knee: 50, ankle: 22, shoulder: 40, elbow: 60 }), { spine: 24 }), 'feet', { move: 0.3, ball: { floor: 'R', dx: 34, dl: 6 } }),
    kf(reach(P(both({ hip: 70, knee: 80, ankle: 30 }), { spine: 50, neck: -30 }), 'R', ground(40, -6, 16)), 'L+Rtoe', { hold: 0.5, move: 0.5, ball: 'R', travel: [10, 0] }),
  ],
});
def('bodyweight-circuit', 'Squats, push-ups, reverse lunges, plank', {
  view: 'three-quarter', thumb: 1,
  keyframes: [...spec('squat-bodyweight').keyframes, ...spec('push-up').keyframes, ...spec('reverse-lunge').keyframes, ...spec('plank').keyframes],
});
/** Half-kneeling hip-flexor stretch: squeeze the back glute and shift forward. */
def('hip-flexor-stretch', 'Kneeling hip-flexor stretch', {
  view: 'side', loop: true, thumb: 1,
  keyframes: [
    kf(P({ hipL: 80, kneeL: 90, ankleL: 20, hipR: -10, kneeR: 90, ankleR: -40, shoulderL: 10, shoulderR: 10, spine: -2 }), 'L+Rknee', { hold: 0.5, move: 0.8 }),
    kf(P({ hipL: 60, kneeL: 80, ankleL: 34, hipR: -30, kneeR: 90, ankleR: -40, shoulderL: 10, shoulderR: 10, spine: -6 }), 'L+Rknee', { hold: 2, move: 0.8, travel: [12, 0] }),
  ],
});

// ── Ultimate ───────────────────────────────────────────────────────────────
const DISC = { r: 10, color: 'white', shape: 'disc' };
def('ultimate-pivot-break-marked', 'Pivot and break the mark', {
  ...spec('ultimate-pivot-break'),
  cast: [{ pattern: 'ultimate-mark', at: [60, -10], facing: 180 }],
});
/** Cut deep, plant, come back under for the disc, catch and pivot. */
def('ultimate-come-back-cut', 'Go-to cut: deep, plant, come back under', {
  view: 'three-quarter', ball: DISC, thumb: 4,
  cast: [{ pattern: 'throw-partner', at: [-40, 160], facing: -60, phase: 0.5 }],
  keyframes: [
    kf(P({ hipL: 36, kneeL: 18, ankleL: 2, hipR: -12, kneeR: 96, ankleR: -24, shoulderL: -40, shoulderR: 60, elbowL: 90, elbowR: 90, spine: 14 }), 'air', { move: 0.12, ball: 'c0:hands' }),
    kf(P({ hipR: 36, kneeR: 18, ankleR: 2, hipL: -12, kneeL: 96, ankleL: -24, shoulderR: -40, shoulderL: 60, elbowL: 90, elbowR: 90, spine: 14 }), 'air', { move: 0.12, travel: [60, 0], ball: 'c0:hands' }),
    kf(P({ spine: 24, neck: -14, hipL: 76, kneeL: 84, ankleL: 30, hipR: 36, kneeR: 66, ankleR: 20, hipAbdL: 10, hipAbdR: 10, shoulderL: 40, shoulderR: 40, elbowL: 70, elbowR: 70 }), 'feet', { move: 0.2, travel: [60, 0], ball: 'c0:hands' }),
    kf(P({ turn: 180, hipL: 36, kneeL: 18, ankleL: 2, hipR: -12, kneeR: 96, ankleR: -24, shoulderL: 60, shoulderR: 60, elbowL: 20, elbowR: 20, spine: 10 }), 'air', { move: 0.3, travel: [-50, 0], ball: { at: [0, 60, 0] }, ballArc: 30 }),
    kf(P({ turn: 180, ...both({ hip: 30, knee: 40, ankle: 20, shoulder: 70, elbow: 30 }), spine: 16 }), 'feet', { hold: 0.4, travel: [-30, 0], ball: 'hands' }),
  ],
});
def('ultimate-skying-contest', 'Skying for the disc', {
  ...spec('ultimate-skying'),
  cast: [{ pattern: 'ultimate-skying', at: [10, 50], facing: 0, phase: 0.04 }],
});
/** A marker holding the force while the thrower pivots to break it. */
def('ultimate-mark-thrower', 'Marking a thrower', {
  ...spec('ultimate-mark'),
  cast: [{ pattern: 'ultimate-pivot-break', at: [60, 10], facing: 180 }],
});

// ── Crew rowing ────────────────────────────────────────────────────────────
/** In the boat: square blades through the stroke, placing the blade together with the crew. */
const crewStroke = [
  kf(rowAt(104, 22, false), 'seat+feet', { hold: 0.05, move: 0.3, surface: 30 }),
  kf(rowAt(50, 20, false), 'seat+feet', { move: 0.22, surface: 30 }),
  kf(rowAt(4, -14, false), 'seat+feet', { move: 0.2, surface: 30 }),
  kf(rowAt(4, -18, true), 'seat+feet', { hold: 0.1, move: 0.25, surface: 30 }),
  kf(rowAt(4, 20, false), 'seat+feet', { move: 0.45, surface: 30 }),
];
def('crew-rower', 'Crew mate rowing', { view: 'three-quarter', implement: { kind: 'oar2', at: 'hands' }, loop: true, thumb: 0, keyframes: crewStroke });
def('rowing-crew-catch', 'Catch timing as a crew', {
  view: 'three-quarter', fixture: { kind: 'boat', level: -26 }, implement: { kind: 'oar2', at: 'hands' }, loop: true, thumb: 0,
  cast: [{ pattern: 'crew-rower', at: [-110, 0], facing: 0 }],
  keyframes: crewStroke,
});

export const OUTDOOR = lib.patterns;
void add; void apply; void air; void handsToFloor; void mirror; void reachBoth;
