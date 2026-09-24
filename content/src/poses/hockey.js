/**
 * Ice-hockey movements (left-handed shot: right hand on top of the stick,
 * left hand lower, blade on the athlete's left). Skating is shown in place,
 * like a treadmill: the glide foot slides back under the body as it would
 * on the ice.
 */
import { add, apply, implementHead, keyframeAt, norm, placeKeyframes, rotY, scale, sub } from '../rig3d.js';
import { P, both, kf, library, mirror, reachBoth } from './kit.js';

const lib = library();
const def = lib.def;
const stick = (extra = {}) => ({ kind: 'hockeystick', at: 'hands', ...extra });

/**
 * Hands on the stick: the top hand (R) at `top(sk)`, the blade at `blade(sk)`;
 * the bottom hand (L) sits `share` of the way down the shaft. The drawn
 * shaft runs through both hands to the ice.
 */
const holdStick = (p, blade, top, share = 0.42) => reachBoth(p,
  (sk) => add(top(sk), sub(blade(sk), top(sk)), share), (sk) => top(sk), { rot: [-40, -20, 0, 20, 40], prefer: (sk, s) => sk[s].elbow[1] });
const fwdOf = (sk) => apply(sk.root, [1, 0, 0]);
const leftOf = (sk) => apply(sk.root, [0, 0, 1]);
const floorY = (sk) => Math.min(sk.L.ankle[1], sk.R.ankle[1]);
/** A point on the ice: `f` forward of the pelvis, `l` to its left. */
const ice = (f, l) => (sk) => add(add([sk.pelvis[0], floorY(sk) + 1, sk.pelvis[2]], fwdOf(sk), f), leftOf(sk), l);
/** A point at chest height (h above the pelvis), f forward, l left. */
const air = (f, h, l) => (sk) => add(add(add(sk.pelvis, fwdOf(sk), f), [0, h, 0]), leftOf(sk), l);

// Skating ------------------------------------------------------------------
const glide = { spine: 40, neck: -26 };
const skateArms = (l, r) => ({ shoulderL: l, shoulderR: r, elbowL: 30, elbowR: 30, shoulderAbdL: 20, shoulderAbdR: 20 });
/** One skating stride on the left leg, right leg pushing out to the side and back. */
const stride = [
  P(glide, { hipL: 62, kneeL: 76, ankleL: 30, hipR: 20, kneeR: 8, ankleR: -10, hipAbdR: 42, hipRotR: -34, ...skateArms(60, -30) }),
  P(glide, { hipL: 60, kneeL: 74, ankleL: 30, hipR: 58, kneeR: 90, ankleR: -4, hipAbdR: 8, hipRotR: -10, ...skateArms(20, 20) }),
];
def('hockey-skating-stride', 'Skating stride', {
  view: 'three-quarter', loop: true, thumb: 0, path: { kind: 'line', length: 420, speed: 260 },
  keyframes: [...stride, ...stride.map(mirror)].map((p) => kf(p, 'air', { move: 0.24 })),
});
def('hockey-skating-with-stick', 'Skating with the puck', {
  path: { kind: 'line', length: 420, speed: 220 },
  view: 'three-quarter', loop: true, thumb: 0, implement: stick({ puck: true }),
  keyframes: [...stride, ...stride.map(mirror)].map((p) => kf(holdStick(p, ice(80, 20), air(10, 4, -8)), 'air', { move: 0.26 })),
});
/** Crossovers turning left: the right skate steps over the left. */
const lean = { spine: 30, neck: -18, bend: 16, turn: 12 };
const crossA = P(lean, { hipL: 56, kneeL: 72, ankleL: 30, hipAbdL: -12, hipR: 40, kneeR: 50, hipAbdR: 30, ...skateArms(50, 10) });
const crossB = P(lean, { hipL: 30, kneeL: 20, ankleL: -10, hipAbdL: -30, hipRotL: 10, hipR: 64, kneeR: 80, ankleR: 26, hipAbdR: -18, hipRotR: -14, ...skateArms(20, 40) });
def('hockey-crossovers', 'Crossovers', {
  view: 'three-quarter', loop: true, thumb: 1, path: { kind: 'circle', radius: 110, turn: 1, speed: 200 },
  keyframes: [kf(crossA, 'air', { move: 0.3 }), kf(crossB, 'air', { move: 0.3 })],
});
def('hockey-tight-turn', 'Tight turn on the inside edges', {
  path: { kind: 'circle', radius: 60, turn: 1, speed: 150 },
  view: 'front', loop: true, thumb: 0, implement: stick({ puck: true }),
  keyframes: [
    kf(holdStick(P({ spine: 34, neck: -20, bend: 26, hipL: 74, kneeL: 90, ankleL: 32, hipAbdL: 6, hipR: 50, kneeR: 60, hipAbdR: 26 }), ice(64, 60), air(12, 4, -4)), 'air', { hold: 0.2, move: 0.6 }),
    kf(holdStick(P({ spine: 34, neck: -20, bend: 30, hipL: 76, kneeL: 92, ankleL: 32, hipAbdL: 8, hipR: 50, kneeR: 62, hipAbdR: 30 }), ice(66, 58), air(12, 4, -4)), 'air', { hold: 0.2, move: 0.6 }),
  ],
});
/** Hockey stop: skating, then both skates turned across, knees deep, shoulders square. */
const stopPose = P({ turn: 80, twist: -60, spine: 20, neck: -10, hipL: 60, kneeL: 80, ankleL: 30, hipAbdL: 20, hipR: 50, kneeR: 70, ankleR: 26, hipAbdR: 26, bend: -14, ...skateArms(50, 50) });
def('hockey-stop-start', 'Hockey stop and start', {
  view: 'three-quarter', thumb: 2,
  keyframes: [
    kf(stride[0], 'air', { move: 0.24 }),
    kf(mirror(stride[0]), 'air', { move: 0.3 }),
    kf(stopPose, 'feet', { hold: 0.35, move: 0.3 }),
    kf(P(glide, { spine: 44, hipL: 62, kneeL: 76, ankleL: 30, hipR: 10, kneeR: 10, ankleR: -30, hipAbdR: 30, hipRotR: -40, ...skateArms(70, -40) }), 'L', { hold: 0.1, move: 0.26 }),
    kf(mirror(stride[0]), 'air', { hold: 0.1 }),
  ],
});
def('hockey-crossover-start', 'Crossover start from the dot', {
  view: 'front', thumb: 2,
  keyframes: [
    kf(P({ spine: 30, neck: -16, ...both({ hip: 44, knee: 54, ankle: 24, hipAbd: 16 }), ...skateArms(30, 30) }), 'feet', { hold: 0.4, move: 0.25 }),
    kf(P(lean, { turn: 40, hipL: 60, kneeL: 76, ankleL: 30, hipRotL: -30, hipR: 30, kneeR: 20, hipAbdR: 30, ...skateArms(60, -20) }), 'air', { move: 0.22 }),
    kf(crossB, 'air', { move: 0.22 }),
    kf(crossA, 'air', { move: 0.22 }),
    kf(crossB, 'air', { move: 0.22 }),
    kf(P(glide, { turn: 70, hipL: 62, kneeL: 76, ankleL: 30, hipR: 20, kneeR: 8, ankleR: -10, hipAbdR: 42, hipRotR: -34, ...skateArms(60, -30) }), 'air', { hold: 0.2 }),
  ],
});
def('hockey-mohawk', 'Mohawk turn, forward to backward', {
  view: 'three-quarter', thumb: 2,
  keyframes: [
    kf(stride[1], 'air', { move: 0.4 }),
    kf(P({ spine: 20, neck: -10, hipL: 30, kneeL: 40, ankleL: 20, hipRotL: -50, hipR: 30, kneeR: 40, ankleR: 20, hipRotR: -50, hipAbdL: 18, hipAbdR: 18, ...skateArms(40, 40) }), 'feet', { hold: 0.25, move: 0.5 }),
    kf(P({ turn: 180, spine: 24, neck: -12, ...both({ hip: 50, knee: 60, ankle: 26, hipAbd: 14 }), ...skateArms(40, 40) }), 'feet', { hold: 0.2, move: 0.4 }),
    kf(P({ turn: 180, spine: 26, neck: -12, hipL: 60, kneeL: 70, ankleL: 28, hipR: 50, kneeR: 40, hipAbdR: 30, hipRotR: 20, ...skateArms(40, 40) }), 'air', { hold: 0.2 }),
  ],
});

// Puck skills --------------------------------------------------------------
const handleStance = P({ spine: 38, neck: -24, ...both({ hip: 50, knee: 58, ankle: 26, hipAbd: 16 }) });
def('hockey-stickhandling', 'Stickhandling', {
  view: 'three-quarter', loop: true, thumb: 0, implement: stick({ puck: true }),
  keyframes: [
    kf(holdStick(handleStance, ice(80, 34), air(12, 2, -8)), 'feet', { move: 0.24 }),
    kf(holdStick({ ...handleStance, twist: -8 }, ice(80, -14), air(12, 2, -10)), 'feet', { move: 0.24 }),
  ],
});
def('hockey-toe-drag', 'Toe drag', {
  view: 'three-quarter', thumb: 1, implement: stick({ puck: true }),
  keyframes: [
    kf(holdStick(handleStance, ice(80, 14), air(12, 2, -8)), 'feet', { hold: 0.1, move: 0.3 }),
    kf(holdStick({ ...handleStance, twist: 16 }, ice(92, 46), air(16, 4, -2)), 'feet', { hold: 0.1, move: 0.3 }),
    kf(holdStick({ ...handleStance, twist: -12 }, ice(62, -20), air(8, 2, -12)), 'feet', { hold: 0.2, move: 0.4 }),
    kf(holdStick(handleStance, ice(80, 14), air(12, 2, -8)), 'feet', { hold: 0.1 }),
  ],
});
def('hockey-board-battle', 'Board-battle body position', {
  view: 'three-quarter', loop: true, thumb: 0, implement: stick(),
  keyframes: [
    kf(holdStick(P({ spine: 44, neck: -22, twist: 10, ...both({ hip: 58, knee: 64, ankle: 28, hipAbd: 26 }) }), ice(76, 36), air(12, 4, -6)), 'feet', { hold: 0.3, move: 0.6 }),
    kf(holdStick(P({ spine: 48, neck: -22, twist: 16, bend: -6, ...both({ hip: 60, knee: 68, ankle: 30, hipAbd: 28 }) }), ice(76, 40), air(12, 4, -6)), 'feet', { hold: 0.3, move: 0.6 }),
  ],
});

// Shooting (front view: the shot goes to the athlete's left) ----------------
const shotStance = { spine: 22, neck: -18, ...both({ hip: 36, knee: 44, ankle: 20, hipAbd: 24 }) };
const slapSetup = holdStick(P(shotStance), ice(30, 70), air(4, 12, -6));
const slapBack = holdStick(P(shotStance, { twist: -46, turn: -10, hipL: 24, kneeL: 20, hipR: 44, kneeR: 54 }), air(-30, 110, -80), air(-2, 30, -8));
const slapImpact = holdStick(P(shotStance, { twist: 6, hipL: 46, kneeL: 56, hipR: 26, kneeR: 30, bend: 6 }), ice(20, 72), air(6, 8, 8));
const slapFollow = holdStick(P(shotStance, { twist: 44, turn: 20, hipL: 44, kneeL: 50, hipR: 16, kneeR: 20, ankleR: -30, bend: 10 }), air(40, 70, 110), air(10, 30, 20));
/** The puck: on the blade until contact, then off towards the net (the athlete's left). */
const PUCK = { r: 3.4, shape: 'puck', color: 'black' };
const shotAway = (h = 14) => ({ at: [70, h, 300] });
def('hockey-slap-shot', 'Slap shot', {
  view: 'front', thumb: 2, implement: stick(), ball: PUCK,
  keyframes: [
    kf(slapSetup, 'feet', { hold: 0.3, move: 0.5, ball: 'head' }),
    kf(slapBack, 'feet', { hold: 0.15, move: 0.22 }),
    kf(slapImpact, 'feet', { move: 0.14, ball: 'head' }),
    kf(slapFollow, 'L+Rtoe', { hold: 0.4, move: 0.6, ball: shotAway(24) }),
    kf(slapSetup, 'feet', { hold: 0.1, ball: 'none' }),
  ],
});
const snapBack = holdStick(P(shotStance, { twist: -20, hipR: 42, kneeR: 50 }), ice(0, 50), air(0, 12, -6));
// While the stick is raised, the puck waits on the ice where the blade meets it at impact.
{
  const p = lib.patterns.find((q) => q.slug === 'hockey-slap-shot');
  const placed = placeKeyframes(p);
  const spot = implementHead(p.implement, keyframeAt(p, 2, placed), PUCK.r);
  const fw = apply(rotY(placed.view), [1, 0, 0]), lt = apply(rotY(placed.view), [0, 0, 1]);
  for (const i of [0, 1]) {
    const pel = keyframeAt(p, i, placed).pelvis;
    const d = [spot[0] - pel[0], spot[1] - pel[1], spot[2] - pel[2]];
    p.keyframes[i] = { ...p.keyframes[i], ball: { at: [d[0] * fw[0] + d[2] * fw[2], d[1], d[0] * lt[0] + d[2] * lt[2]] } };
  }
}
def('hockey-snap-shot', 'Snap shot', {
  view: 'front', thumb: 2, implement: stick(), ball: PUCK,
  keyframes: [
    kf(slapSetup, 'feet', { hold: 0.25, move: 0.3, ball: 'head' }),
    kf(snapBack, 'feet', { hold: 0.05, move: 0.14, ball: 'head' }),
    kf(slapImpact, 'feet', { move: 0.12, ball: 'head' }),
    kf(holdStick(P(shotStance, { twist: 30, turn: 14, hipL: 42, kneeL: 50, hipR: 18, kneeR: 24 }), air(40, 20, 100), air(10, 16, 14)), 'feet', { hold: 0.4, move: 0.5, ball: shotAway() }),
    kf(slapSetup, 'feet', { hold: 0.1, ball: 'none' }),
  ],
});

// Wrist shot: the blade stays on the ice, sweeping the puck from behind the
// back foot forward while the weight moves back to front, then a low-to-high finish.
def('hockey-wrist-shot', 'Wrist shot', {
  view: 'front', thumb: 1, implement: stick(), ball: PUCK,
  keyframes: [
    kf(holdStick(P(shotStance, { twist: -26, hipR: 44, kneeR: 54, hipL: 28, kneeL: 30 }), ice(-6, 20), air(0, 12, -8)), 'feet', { hold: 0.3, move: 0.3, ball: 'head' }),
    kf(holdStick(P(shotStance, { twist: 8, hipL: 44, kneeL: 54, hipR: 28, kneeR: 32 }), ice(24, 64), air(8, 10, 6)), 'feet', { move: 0.18, ball: 'head' }),
    kf(holdStick(P(shotStance, { twist: 34, turn: 12, hipL: 44, kneeL: 50, hipR: 18, kneeR: 24 }), air(40, 30, 100), air(10, 18, 16)), 'feet', { hold: 0.4, move: 0.5, ball: shotAway(30) }),
    kf(holdStick(P(shotStance, { twist: -26, hipR: 44, kneeR: 54, hipL: 28, kneeL: 30 }), ice(-6, 20), air(0, 12, -8)), 'feet', { hold: 0.1, ball: 'none' }),
  ],
});
def('hockey-stickhandling-dryland', 'Dryland stickhandling', {
  view: 'three-quarter', loop: true, thumb: 0, implement: stick({ puck: true, ball: true }),
  keyframes: [
    kf(holdStick(handleStance, ice(80, 34), air(12, 2, -8)), 'feet', { move: 0.24 }),
    kf(holdStick({ ...handleStance, twist: -8 }, ice(80, -14), air(12, 2, -10)), 'feet', { move: 0.24 }),
  ],
});

export const HOCKEY = lib.patterns;
