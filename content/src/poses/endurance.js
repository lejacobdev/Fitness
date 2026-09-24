/**
 * Goalball, orienteering, triathlon and duathlon, and para-track extras:
 * eyeshades and full-length blocks, a map and a control flag, getting on
 * and off the bike, a helmet in transition, a seated chest pass.
 */
import { STRENGTH } from './strength.js';
import { P, air, armsSwing, both, ground, kf, library, mirror, reachBoth } from './kit.js';

const lib = library();
const def = lib.def;
const spec = (slug) => {
  const { slug: _s, name: _n, ...rest } = STRENGTH.find((p) => p.slug === slug);
  return rest;
};
const EYES = ['eyeshade'];

// ── Goalball (eyeshades on; the ball has bells in it) ──────────────────────
const GOALBALL = { r: 12, color: 'blue' };
/** Low defensive crouch on the knees and toes, hands forward, listening. */
const gbCrouch = P(both({ hip: 72, knee: 96, ankle: 30, hipAbd: 24, shoulder: 40, shoulderAbd: 30, elbow: 40 }), { spine: 40, neck: -20 });
def('goalball-throw-partner', 'Goalball thrower (partner)', {
  view: 'three-quarter', wear: EYES, loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 30, knee: 30, ankle: 14 }), { spine: 20, shoulderR: -40, elbowR: 10 }), 'feet', { hold: 0.3, move: 0.3 }),
    kf(P({ spine: 50, hipL: 80, kneeL: 90, ankleL: 30, hipR: 10, kneeR: 60, ankleR: -20, shoulderR: 60, elbowR: 10 }), 'L+Rtoe', { hold: 1.4, move: 0.4, travel: [30, 0] }),
  ],
});
def('goalball-block', 'Full-extension block', {
  view: 'three-quarter', wear: EYES, ball: GOALBALL, thumb: 2,
  cast: [{ pattern: 'goalball-throw-partner', at: [420, 30], facing: 180, phase: 0.1 }],
  keyframes: [
    kf(gbCrouch, 'feet', { hold: 0.4, move: 0.4, ball: 'c0:R' }),
    kf(P(gbCrouch, { bend: -12, hipAbdR: 56, kneeR: 10, hipR: 10, ankleR: 0, kneeL: 80, hipL: 64 }), 'L', { move: 0.2, ball: { floor: 'L', dx: 160, dl: -40 } }),
    kf(P({ bend: -88, spine: 0, neck: 0, ...both({ hip: 0, knee: 0, ankle: -20, hipAbd: 2, shoulder: 176, elbow: 4, shoulderAbd: 4 }) }), 'air', { hold: 0.6, move: 0.5, travel: [0, -60], ball: { floor: 'L', dx: 50, dl: -60 } }),
    kf(P(both({ hip: 0, knee: 90, ankle: -60 }), { spine: 20, shoulderL: 60, shoulderR: 60, elbowL: 30, elbowR: 30 }), 'knees', { move: 0.4, ball: { floor: 'L', dx: 60, dl: -80 } }),
    kf(gbCrouch, 'feet', { hold: 0.4, travel: [0, 60] }),
  ],
});
/** Listening for the bells: the body turns to face the sound and a hand points at it. */
const track = (deg, pointSide) => P(gbCrouch, { turn: deg, neckTurn: deg / 3, [`shoulder${pointSide}`]: 80, [`elbow${pointSide}`]: 4 });
def('goalball-sound-tracking', 'Sound tracking', {
  view: 'three-quarter', wear: EYES, ball: GOALBALL, loop: true, thumb: 0,
  keyframes: [
    kf(track(30, 'L'), 'feet', { hold: 0.6, move: 0.5, ball: { at: [300, 12, 160] } }),
    kf(track(0, 'R'), 'feet', { hold: 0.6, move: 0.5, ball: { at: [300, 12, 0] } }),
    kf(track(-30, 'R'), 'feet', { hold: 0.6, move: 0.5, ball: { at: [300, 12, -160] } }),
    kf(track(0, 'L'), 'feet', { hold: 0.6, move: 0.5, ball: { at: [300, 12, 0] } }),
  ],
});
def('goalball-spin-throw', 'Spin throw', {
  view: 'three-quarter', wear: EYES, ball: GOALBALL, thumb: 3,
  keyframes: [
    kf(P(both({ hip: 20, knee: 24, ankle: 10, hipAbd: 10 }), { spine: 14, shoulderR: 20, elbowR: 60, shoulderL: 20, elbowL: 60 }), 'feet', { hold: 0.4, move: 0.3, ball: 'hands' }),
    kf(P(both({ hip: 30, knee: 34, ankle: 14, hipAbd: 10 }), { spine: 20, turn: -140, shoulderR: -30, elbowR: 10, shoulderAbdR: 30, shoulderL: 40, elbowL: 40 }), 'feet', { move: 0.28, ball: 'R' }),
    kf(P({ turn: -260, spine: 30, hipL: 50, kneeL: 50, ankleL: 20, hipR: 10, kneeR: 40, ankleR: -10, shoulderR: -40, elbowR: 10, shoulderL: 50, elbowL: 30 }), 'L+Rtoe', { move: 0.22, ball: 'R', travel: [20, 0] }),
    kf(P({ turn: -360, spine: 56, neck: -20, hipL: 90, kneeL: 96, ankleL: 30, hipR: 0, kneeR: 50, ankleR: -30, shoulderR: 70, elbowR: 6, shoulderL: 30, elbowL: 40 }), 'L+Rtoe', { move: 0.3, ball: 'R', travel: [40, 0] }),
    kf(P({ turn: -360, spine: 50, neck: -20, hipL: 86, kneeL: 90, ankleL: 30, hipR: 0, kneeR: 50, ankleR: -30, shoulderR: 90, elbowR: 4, shoulderL: 30, elbowL: 40 }), 'L+Rtoe', { hold: 0.5, ball: { floor: 'L', dx: 460, dl: 0 } }),
  ],
});
def('goalball-slide', 'Lateral coverage slide', {
  view: 'three-quarter', wear: EYES, loop: true, thumb: 0,
  path: { kind: 'shuttle', length: 200, dir: 'left', speed: 90 },
  keyframes: [
    kf(gbCrouch, 'air', { move: 0.2 }),
    kf(P(gbCrouch, { hipAbdL: 40, hipAbdR: 14, lift: 2 }), 'air', { move: 0.2 }),
  ],
});
/** Feeling the floor's tactile lines with a hand to find the way back to position. */
def('goalball-orientation', 'Finding your spot by the lines', {
  view: 'three-quarter', wear: EYES, thumb: 1,
  keyframes: [
    kf(gbCrouch, 'feet', { hold: 0.4, move: 0.5 }),
    kf(reachBoth(P(gbCrouch, { spine: 50, kneeL: 84, kneeR: 84 }), ground(40, 20, 3), air(20, 10, -20)), 'feet', { hold: 0.3, move: 0.3 }),
    kf(reachBoth(P(gbCrouch, { spine: 50, kneeL: 84, kneeR: 84, hipAbdL: 36 }), ground(40, 30, 3), air(20, 10, -20)), 'feet', { move: 0.3, travel: [0, 30] }),
    kf(reachBoth(P(gbCrouch, { spine: 50, kneeL: 84, kneeR: 84 }), ground(40, 20, 3), air(20, 10, -20)), 'feet', { move: 0.3, travel: [0, 20] }),
    kf(gbCrouch, 'feet', { hold: 0.6 }),
  ],
});

// ── Para track extras ──────────────────────────────────────────────────────
const MEDBALL = { r: 9, color: 'brown' };
const seated = (spine) => ({ ...both({ hip: 88 + spine, knee: 96, ankle: 0, hipAbd: 6 }), spine });
def('chest-pass-partner', 'Catching and passing back (partner)', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 20, knee: 24, ankle: 10, hipAbd: 10, shoulder: 70, elbow: 50 }), { spine: 10 }), 'feet', { hold: 0.8, move: 0.3 }),
    kf(P(both({ hip: 20, knee: 24, ankle: 10, hipAbd: 10, shoulder: 88, elbow: 4 }), { spine: 16 }), 'feet', { hold: 0.4, move: 0.4 }),
  ],
});
def('seated-chest-pass', 'Seated medicine-ball chest pass', {
  view: 'three-quarter', fixture: { kind: 'wheelchair' }, ball: MEDBALL, loop: true, thumb: 1,
  cast: [{ pattern: 'chest-pass-partner', at: [280, 0], facing: 180, phase: 0.62 }],
  keyframes: [
    kf(P(seated(10), both({ shoulder: 30, elbow: 130, shoulderAbd: 20 })), 'seat', { hold: 0.4, move: 0.2, ball: 'hands' }),
    kf(P(seated(16), both({ shoulder: 88, elbow: 2, shoulderAbd: 8 })), 'seat', { hold: 0.3, move: 0.5, ball: 'c0:hands', ballArc: 16 }),
    kf(P(seated(8), both({ shoulder: 70, elbow: 40, shoulderAbd: 10 })), 'seat', { hold: 0.6, move: 0.4, ball: 'hands', ballArc: 16 }),
  ],
});
/** Band anchored ahead at chest height, pulled to the ribs. */
def('band-row', 'Band row', {
  view: 'side', implement: { kind: 'band', at: 'hands', to: [110, 40, 0] },
  keyframes: [
    kf(P(both({ hip: 30, knee: 30, ankle: 14, hipAbd: 8, shoulder: 80, shoulderAbd: 8, elbow: 2 }), { spine: 10 }), 'feet', { hold: 0.3, move: 0.7 }),
    kf(P(both({ hip: 30, knee: 30, ankle: 14, hipAbd: 8, shoulder: -20, shoulderAbd: 14, elbow: 100 }), { spine: 8 }), 'feet', { hold: 0.5, move: 1.2 }),
    kf(P(both({ hip: 30, knee: 30, ankle: 14, hipAbd: 8, shoulder: 80, shoulderAbd: 8, elbow: 2 }), { spine: 10 }), 'feet', { hold: 0.2 }),
  ],
});

// ── Orienteering ───────────────────────────────────────────────────────────
const MAP = { kind: 'map' };
const readMap = (ph) => ({ ...ph, shoulderL: 50, elbowL: 100, shoulderAbdL: 10, wristL: 20 });
const runPhases = [
  { hipL: 26, kneeL: 14, ankleL: 4, hipR: -10, kneeR: 70, ankleR: -20, ...armsSwing(-26, 34, 86) },
  { hipL: 4, kneeL: 32, ankleL: 18, hipR: 30, kneeR: 88, ankleR: 0, ...armsSwing(-6, 16, 86) },
  { hipL: -20, kneeL: 16, ankleL: -26, hipR: 50, kneeR: 64, ankleR: 6, ...armsSwing(28, -24, 84), lift: 2 },
  { hipL: -10, kneeL: 56, ankleL: -14, hipR: 36, kneeR: 28, ankleR: 4, ...armsSwing(18, -16, 86), lift: 4 },
];
def('map-run', 'Running while reading the map', {
  view: 'three-quarter', implement: MAP, loop: true, thumb: 0,
  path: { kind: 'line', length: 380 },
  keyframes: [...runPhases.map((ph) => P(ph)), ...runPhases.map((ph) => mirror(P(ph)))].map((p) => kf(P(p, readMap({}), { spine: 10, neck: -24 }), 'air', { move: 0.13 })),
});
def('control-punch', 'Sprint, punch the control, go', {
  view: 'three-quarter', thumb: 3, fixture: { kind: 'control', at: 190 },
  keyframes: [
    kf(P({ hipL: 36, kneeL: 18, ankleL: 2, hipR: -12, kneeR: 96, ankleR: -24, ...armsSwing(-40, 60, 92) }, { spine: 12 }), 'air', { move: 0.1 }),
    kf(P({ hipR: 36, kneeR: 18, ankleR: 2, hipL: -12, kneeL: 96, ankleL: -24, ...armsSwing(60, -40, 92) }, { spine: 12 }), 'air', { move: 0.1, travel: [60, 0] }),
    kf(P({ spine: 24, neck: -14, hipL: 76, kneeL: 84, ankleL: 30, hipR: 36, kneeR: 66, ankleR: 20, ...armsSwing(40, 40, 70), hipAbdL: 10, hipAbdR: 10 }), 'feet', { move: 0.14, travel: [60, 0] }),
    kf(P({ spine: 20, neck: -14, hipL: 60, kneeL: 64, ankleL: 26, hipR: 30, kneeR: 50, ankleR: 16, hipAbdL: 10, hipAbdR: 10, shoulderR: 70, elbowR: 10, shoulderL: 20, elbowL: 60 }), 'feet', { hold: 0.2, move: 0.14 }),
    kf(P({ spine: 30, turn: 40, hipL: 10, kneeL: 20, ankleL: -30, hipR: 90, kneeR: 100, ankleR: 10, ...armsSwing(-50, 60, 88) }), 'Ltoe', { move: 0.14, travel: [20, 20] }),
    kf(P({ spine: 20, turn: 40, hipR: 10, kneeR: 20, ankleR: -30, hipL: 84, kneeL: 96, ankleL: 8, ...armsSwing(50, -40, 90), lift: 2 }), 'Rtoe', { hold: 0.2, travel: [40, 36] }),
  ],
});
/** Single-leg hops forward, to the side and back, landing softly, then the other leg. */
const hopLoad = (s) => P({ spine: 20, [`hip${s}`]: 44, [`knee${s}`]: 54, [`ankle${s}`]: 24, [`hip${s === 'L' ? 'R' : 'L'}`]: 40, [`knee${s === 'L' ? 'R' : 'L'}`]: 90, shoulderL: 20, shoulderR: 20, elbowL: 80, elbowR: 80 });
const hopAir = (s) => P({ spine: 10, [`hip${s}`]: 20, [`knee${s}`]: 20, [`ankle${s}`]: -20, [`hip${s === 'L' ? 'R' : 'L'}`]: 40, [`knee${s === 'L' ? 'R' : 'L'}`]: 90, shoulderL: 60, shoulderR: 60, elbowL: 60, elbowR: 60, lift: 14 });
const hopTo = (s, dir) => [
  kf(hopLoad(s), s, { hold: 0.2, move: 0.18 }),
  kf(hopAir(s), 'air', { move: 0.18, travel: dir }),
  kf(hopLoad(s), s, { hold: 0.3, move: 0.3, travel: dir }),
];
def('single-leg-hops-directions', 'Single-leg hops in every direction', {
  view: 'three-quarter', thumb: 1,
  keyframes: [...hopTo('L', [30, 0]), ...hopTo('L', [0, 26]), ...hopTo('L', [-30, 0]), ...hopTo('R', [0, -26])],
});

// ── Triathlon and duathlon ─────────────────────────────────────────────────
const cycling = spec('cycling');
const ride = cycling.keyframes.slice(0, 8);
/** Off the bike (left side), then away running with short quick steps. */
const runOff = [
  kf(P({ spine: 20, hipL: 10, kneeL: 10, ankleL: 0, hipR: 70, kneeR: 90, ankleR: 10, shoulderL: 60, shoulderR: 60, elbowL: 20, elbowR: 20 }), 'L', { move: 0.3, travel: [0, 40] }),
  kf(P({ spine: 16, hipL: 6, kneeL: 8, ankleL: 0, hipR: -30, kneeR: 40, hipAbdR: 30, shoulderL: 50, shoulderR: 50, elbowL: 20, elbowR: 20 }), 'L', { move: 0.3 }),
  kf(P({ spine: 10, ...armsSwing(-20, 30, 88), hipL: 20, kneeL: 20, ankleL: 6, hipR: -10, kneeR: 50, ankleR: -20 }), 'L', { move: 0.14, travel: [20, 10] }),
  ...[0, 1, 2, 3].map((i) => kf(i % 2 ? mirror(P(runPhases[2], { spine: 8 })) : P(runPhases[2], { spine: 8 }), 'air', { move: 0.12, travel: [40, 0] })),
];
def('bike-to-run', 'Bike-to-run transition', {
  fixture: { ...cycling.fixture, placeTo: 8 }, view: 'three-quarter', thumb: 9,
  keyframes: [...ride, ...runOff],
});
/** Running in, swinging a leg over and pedalling away. */
def('run-to-bike', 'Run-to-bike transition', {
  fixture: { ...cycling.fixture, placeFrom: 5 }, view: 'three-quarter', thumb: 5,
  keyframes: [
    ...[0, 1, 2].map((i) => kf(i % 2 ? mirror(P(runPhases[2], { spine: 8 })) : P(runPhases[2], { spine: 8 }), 'air', { move: 0.14, travel: [40, 0] })),
    kf(P({ spine: 16, hipL: 6, kneeL: 8, ankleL: 0, hipR: -30, kneeR: 40, hipAbdR: 30, shoulderL: 60, shoulderR: 60, elbowL: 20, elbowR: 20 }), 'L', { move: 0.3, travel: [20, 0] }),
    kf(P({ spine: 20, hipL: 10, kneeL: 10, ankleL: 0, hipR: 70, kneeR: 90, ankleR: 10, shoulderL: 60, shoulderR: 60, elbowL: 20, elbowR: 20 }), 'L', { move: 0.3 }),
    ...ride.map((k, i) => ({ ...k, ...(i === 0 ? { travel: [0, -40] } : {}) })),
  ],
});
/** T1: in from the swim, cap and goggles off, helmet on and buckled, out to the bike. */
def('transition-t1', 'Swim-to-bike transition (T1)', {
  view: 'three-quarter', thumb: 4,
  keyframes: [
    kf(P(runPhases[0], { spine: 8 }), 'air', { move: 0.14 }),
    kf(mirror(P(runPhases[2], { spine: 8 })), 'air', { move: 0.14, travel: [40, 0] }),
    kf(P(both({ hip: 6, knee: 10 }), { spine: 8, neck: -10, shoulderL: 160, elbowL: 100, shoulderR: 160, elbowR: 100, shoulderAbdL: 30, shoulderAbdR: 30 }), 'feet', { hold: 0.5, move: 0.3, travel: [40, 0] }),
    kf(P(both({ hip: 6, knee: 10 }), { spine: 4, neck: 10, shoulderL: 60, elbowL: 150, shoulderR: 60, elbowR: 150, shoulderAbdL: 20, shoulderAbdR: 20 }), 'feet', { hold: 0.6, move: 0.3 }),
    kf(P(runPhases[0], { spine: 8 }), 'air', { move: 0.14, travel: [10, 0] }),
    kf(mirror(P(runPhases[2], { spine: 8 })), 'air', { hold: 0.2, travel: [40, 0] }),
  ],
});
/** Heels drop below the step, then rise onto the toes (straight knee). */
def('calf-raise-step', 'Calf raise off a step', {
  view: 'side', thumb: 1, fixture: { kind: 'box', under: 'feet', width: 16, shift: 8, top: 16 },
  keyframes: [
    kf(P(both({ ankle: 20 })), 'Ltoe+Rtoe', { hold: 0.4, move: 0.8, surface: 16 }),
    kf(P(both({ ankle: -34 })), 'Ltoe+Rtoe', { hold: 0.4, move: 3, surface: 16 }),
    kf(P(both({ ankle: 20, knee: 20, hip: 10 })), 'Ltoe+Rtoe', { hold: 0.4, move: 0.8, surface: 16 }),
    kf(P(both({ ankle: -34, knee: 20, hip: 10 })), 'Ltoe+Rtoe', { hold: 0.4, surface: 16 }),
  ],
});

export const ENDURANCE = lib.patterns;
