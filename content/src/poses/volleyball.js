/**
 * Volleyball (indoor, boys', sand, sitting) and roundnet. Right-handed
 * hitters: the hitting arm is R (the far arm), so most attacks use the
 * three-quarter camera where the swing reads clearly.
 */
import { P, both, clear, kf, library, mirror, reach, reachBoth, solve, toeDown } from './kit.js';

const lib = library();
const def = lib.def;
const VB = { r: 8.4, color: 'yellow' };
const SB = { r: 4.5, color: 'yellow' };
const at = (f, h, l = 0) => ({ at: [f, h, l] });
const NET = { kind: 'net', at: 40, top: 196 };

// Attacking -------------------------------------------------------------------
const armsBack = both({ shoulder: -60, elbow: 10, shoulderAbd: 10 });
const approach = [
  kf(P({ spine: 12, hipL: 34, kneeL: 20, ankleL: 10, hipR: -16, kneeR: 40, ankleR: -24, shoulderL: -10, shoulderR: 20, elbowL: 30, elbowR: 30 }), 'L', { move: 0.3 }),
  kf(P({ spine: 24, hipR: 50, kneeR: 40, ankleR: 20, hipL: -22, kneeL: 30, ankleL: -30, ...armsBack }), 'R', { move: 0.22, travel: [46, 0] }),
  kf(P({ spine: 40, neck: -16, ...both({ hip: 80, knee: 84, ankle: 30, hipAbd: 8 }), ...armsBack }), 'feet', { move: 0.16, travel: [40, 0] }),
  kf(P(both({ ankle: -32, hipAbd: 6, shoulder: 170, elbow: 6 }), { spine: 2 }), 'Ltoe+Rtoe', { move: 0.18 }),
];
/** Spike: bow-and-arrow draw with the R elbow high, contact at full reach in front of the shoulder. */
const draw = P(both({ ankle: -26, knee: 20, hip: 10 }), { spine: -8, twist: -30, lift: 36, shoulderL: 160, elbowL: 10, shoulderAbdL: 10,
  shoulderR: 120, shoulderAbdR: 70, shoulderRotR: -80, elbowR: 100, neck: -26 });
const contact = P(both({ ankle: -26, knee: 20, hip: 30 }), { spine: 8, twist: 20, lift: 36, shoulderL: 40, elbowL: 50, shoulderR: 168, shoulderAbdR: 10, elbowR: 4, wristR: 30, neck: -20 });
const snap = P(both({ ankle: -20, knee: 30, hip: 40 }), { spine: 20, twist: 30, lift: 30, shoulderL: 20, elbowL: 60, shoulderR: 80, shoulderAbdR: -10, elbowR: 20, wristR: 60 });
const landing = P(both({ hip: 60, knee: 70, ankle: 28, hipAbd: 10, shoulder: 30, elbow: 40 }), { spine: 26 });
def('vb-spike', 'Approach and spike', {
  view: 'three-quarter', ball: VB, thumb: 5,
  keyframes: [
    ...approach.map((k) => ({ ...k, ball: at(90, 220, -10) })),
    kf(draw, 'air', { move: 0.14, ball: at(34, 160, -14) }),
    kf(contact, 'air', { move: 0.1, ball: at(36, 150, -14) }),
    kf(snap, 'air', { move: 0.26, ball: at(160, 40, -14) }),
    kf(landing, 'feet', { hold: 0.35, ball: 'none' }),
  ],
});
def('vb-approach-swing', 'Approach and arm swing', {
  view: 'three-quarter', thumb: 4,
  keyframes: [...approach, kf(draw, 'air', { move: 0.14 }), kf(contact, 'air', { move: 0.3 }), kf(landing, 'feet', { hold: 0.35 })],
});
/** Block: hands at shoulder height by the net, jump and press both hands over it. */
const blockReady = P(both({ hip: 20, knee: 26, ankle: 12, hipAbd: 8, shoulder: 120, shoulderAbd: 20, elbow: 70 }), { spine: 4 });
def('vb-block', 'Block jump and press', {
  thumb: 2, fixture: NET,
  keyframes: [
    kf(blockReady, 'feet', { hold: 0.35, move: 0.2 }),
    kf(P(both({ hip: 50, knee: 60, ankle: 26, hipAbd: 8, shoulder: 110, elbow: 80 }), { spine: 14 }), 'feet', { move: 0.18 }),
    kf(P(both({ ankle: -30, knee: 4, shoulder: 150, shoulderAbd: 10, elbow: 2, wrist: 30 }), { lift: 30, spine: 6, neck: -10 }), 'air', { hold: 0.15, move: 0.35 }),
    kf(P(both({ hip: 40, knee: 50, ankle: 24, hipAbd: 8, shoulder: 120, shoulderAbd: 20, elbow: 60 }), { spine: 12 }), 'feet', { hold: 0.2 }),
  ],
});
def('vb-block-footwork', 'Step-crossover-plant block', {
  view: 'front', thumb: 3,
  keyframes: [
    kf(blockReady, 'feet', { hold: 0.3, move: 0.2 }),
    kf(P(blockReady, { hipAbdL: 24, lift: 1 }), 'R', { move: 0.2, travel: [0, 20] }),
    kf(P(blockReady, { hipR: 30, kneeR: 40, hipAbdR: -24, hipRotR: -20, twist: 10 }), 'L', { move: 0.22, travel: [0, 26] }),
    kf(P(both({ hip: 50, knee: 60, ankle: 26, hipAbd: 10, shoulder: 110, elbow: 80 }), { spine: 14 }), 'feet', { move: 0.16, travel: [0, 18] }),
    kf(P(both({ ankle: -30, knee: 4, shoulder: 168, shoulderAbd: 12, elbow: 2 }), { lift: 30, neck: -10 }), 'air', { hold: 0.15, move: 0.35 }),
    kf(P(both({ hip: 40, knee: 50, ankle: 24, hipAbd: 10, shoulder: 120, shoulderAbd: 20, elbow: 60 }), { spine: 12 }), 'feet', { hold: 0.2 }),
  ],
});

// Serving --------------------------------------------------------------------
const serveStance = { hipL: 20, kneeL: 10, ankleL: 6, hipR: -10, kneeR: 14, ankleR: -10 };
def('vb-float-serve', 'Float serve', {
  view: 'three-quarter', ball: VB, thumb: 2,
  keyframes: [
    kf(reachBoth(P(serveStance, { spine: 6 }), () => [26, 50, 10], () => [18, 60, -12]), 'L', { hold: 0.35, move: 0.25, ball: 'L' }),
    kf(P(serveStance, { spine: -4, twist: -24, shoulderL: 150, elbowL: 4, shoulderR: 120, shoulderAbdR: 70, shoulderRotR: -80, elbowR: 100, neck: -20 }), 'L', { move: 0.3, ball: at(26, 140, -8), ballArc: 20 }),
    kf(P({ hipL: 40, kneeL: 20, ankleL: 12, hipR: -4, kneeR: 16, ankleR: -30, spine: 10, twist: 16, shoulderL: 40, elbowL: 40, shoulderR: 150, shoulderAbdR: 20, elbowR: 4, wristR: 0 }), 'L', { hold: 0.3, move: 0.3, ball: at(30, 132, -10) }),
    kf(P({ hipL: 40, kneeL: 20, ankleL: 12, hipR: -4, kneeR: 16, ankleR: -30, spine: 10, twist: 16, shoulderL: 40, elbowL: 40, shoulderR: 150, shoulderAbdR: 20, elbowR: 4 }), 'L', { hold: 0.2, ball: at(240, 150, -10) }),
  ],
});
def('vb-jump-serve', 'Jump serve', {
  view: 'three-quarter', ball: VB, thumb: 4,
  keyframes: [
    kf(reach(P(serveStance, { spine: 6 }), 'R', () => [24, 46, -10]), 'L+Rtoe', { hold: 0.3, move: 0.25, ball: 'R' }),
    kf(P(serveStance, { spine: 0, shoulderR: 170, elbowR: 10, shoulderL: 20 }), 'L+Rtoe', { move: 0.25, ball: at(70, 220, -10), ballArc: 20 }),
    ...approach.slice(1).map((k) => ({ ...k, ball: at(70, 200, -10) })),
    kf(draw, 'air', { move: 0.14, ball: at(40, 160, -14) }),
    kf(contact, 'air', { move: 0.12, ball: at(38, 152, -14) }),
    kf(landing, 'feet', { hold: 0.35, ball: at(260, 130, -14) }),
  ],
});

// Ball control --------------------------------------------------------------
/** Forearm pass: a flat platform, arms straight and joined, passing with the legs. */
const platform = (p, f, h) => reachBoth(p, () => [f, h, 3], () => [f, h, -3]);
const passLow = platform(P(both({ hip: 70, knee: 80, ankle: 30, hipAbd: 18 }), { spine: 34, neck: -26 }), 36, -8);
const passUp = platform(P(both({ hip: 30, knee: 34, ankle: 14, hipAbd: 16 }), { spine: 20, neck: -20 }), 40, 8);
def('vb-forearm-pass', 'Forearm pass', {
  view: 'three-quarter', ball: VB, thumb: 1,
  keyframes: [
    kf(passLow, 'feet', { hold: 0.2, move: 0.3, ball: at(120, 60) }),
    kf(passLow, 'feet', { move: 0.25, ball: at(46, -4) }),
    kf(passUp, 'feet', { hold: 0.35, ball: at(60, 150) }),
  ],
});
/** Setting: hands in a window above the forehead; legs and arms extend together. */
const setHands = (p, h) => reachBoth(p, () => [10, h, 7], () => [10, h, -7]);
def('vb-set', 'Overhead set', {
  view: 'three-quarter', ball: VB, thumb: 1,
  keyframes: [
    kf(setHands(P(both({ hip: 30, knee: 40, ankle: 20, hipAbd: 10 }), { spine: 4, neck: -30 }), 68), 'feet', { hold: 0.1, move: 0.3, ball: at(40, 200) }),
    kf(setHands(P(both({ hip: 36, knee: 46, ankle: 22, hipAbd: 10 }), { spine: 4, neck: -32 }), 64), 'feet', { move: 0.25, ball: at(12, 76) }),
    kf(setHands(P(both({ hip: 4, knee: 6, ankle: -10, hipAbd: 10 }), { neck: -36 }), 96), 'feet', { hold: 0.35, ball: at(20, 200) }),
  ],
});
def('vb-shuffle-dig', 'Shuffle and dig', {
  view: 'front', ball: VB, thumb: 2,
  keyframes: [
    kf(platform(P(both({ hip: 50, knee: 60, ankle: 26, hipAbd: 22 }), { spine: 28 }), 30, 10), 'feet', { hold: 0.25, move: 0.2, ball: 'none' }),
    kf(platform(P(both({ hip: 50, knee: 56, ankle: 26, hipAbd: 30 }), { spine: 28, lift: 2 }), 30, 10), 'air', { move: 0.18, travel: [0, 26], ball: at(80, 60, 40) }),
    kf(platform(P({ spine: 34, hipL: 70, kneeL: 84, ankleL: 30, hipAbdL: 30, hipR: 30, kneeR: 40, hipAbdR: 30 }), 34, -14), 'feet', { move: 0.2, travel: [0, 22], ball: at(36, -12, 8) }),
    kf(platform(P({ spine: 30, hipL: 60, kneeL: 70, ankleL: 28, hipAbdL: 30, hipR: 30, kneeR: 40, hipAbdR: 30 }), 38, 0), 'feet', { hold: 0.3, ball: at(40, 170, -20) }),
  ],
});
def('vb-dive', 'Sprawl and dig', {
  thumb: 2, ball: VB,
  keyframes: [
    kf(platform(P(both({ hip: 50, knee: 60, ankle: 26, hipAbd: 16 }), { spine: 30 }), 30, 10), 'feet', { hold: 0.2, move: 0.24, ball: at(140, 20) }),
    kf(platform(P({ spine: 60, hipL: 80, kneeL: 90, ankleL: 30, hipR: -10, kneeR: 20, ankleR: -30 }), 44, -10), 'L+Rtoe', { move: 0.2, travel: [30, 0], ball: at(58, -10) }),
    kf(P({ spine: 88, neck: -24, ...both({ shoulder: 120, elbow: 80, hip: 0, knee: 20, ankle: -60 }) }), 'front', { hold: 0.2, move: 0.4, travel: [50, 0], ball: at(60, 160) }),
    kf(P(both({ hip: 44, knee: 54, ankle: 24, hipAbd: 16, shoulder: 40, elbow: 60 }), { spine: 26 }), 'feet', { hold: 0.2, ball: 'none' }),
  ],
});

// Sitting volleyball: seated on the floor, legs forward. -----------------------
const floorSit = (spine, extra = {}) => P({ spine, neck: -10, ...both({ hip: 80 + spine, knee: 70, ankle: 10, hipAbd: 14 }), ...extra });
def('sit-vb-spike', 'Seated attack', {
  ball: VB, thumb: 2,
  keyframes: [
    kf(floorSit(-6, { shoulderL: 150, shoulderR: 120, shoulderAbdR: 70, shoulderRotR: -80, elbowR: 100, twist: -24, neck: -24 }), 'air', { hold: 0.25, move: 0.2, ball: at(20, 120, -12) }),
    kf(floorSit(4, { shoulderL: 40, elbowL: 40, shoulderR: 168, elbowR: 4, wristR: 30, twist: 16 }), 'air', { move: 0.12, ball: at(26, 112, -14) }),
    kf(floorSit(16, { shoulderL: 20, elbowL: 50, shoulderR: 80, elbowR: 20, wristR: 60, twist: 26 }), 'air', { hold: 0.35, ball: at(170, 20, -14) }),
  ],
});
def('sit-vb-block', 'Seated block reach', {
  view: 'front', thumb: 1, loop: true,
  keyframes: [
    kf(floorSit(0, both({ shoulder: 120, elbow: 70, shoulderAbd: 20 })), 'air', { hold: 0.3, move: 0.35 }),
    kf(floorSit(6, both({ shoulder: 170, elbow: 2, shoulderAbd: 10 })), 'air', { hold: 0.6, move: 0.35 }),
    kf(floorSit(0, { ...both({ shoulder: 120, elbow: 70, shoulderAbd: 20 }), bend: 10 }), 'air', { hold: 0.3, move: 0.35, travel: [0, 16] }),
    kf(floorSit(6, { ...both({ shoulder: 170, elbow: 2, shoulderAbd: 10 }), bend: 10 }), 'air', { hold: 0.6, move: 0.35 }),
  ],
});
def('sit-vb-serve', 'Seated overhand serve', {
  ball: VB, thumb: 2,
  keyframes: [
    kf(floorSit(4, { shoulderL: 90, elbowL: 20, shoulderR: 60, elbowR: 60 }), 'air', { hold: 0.3, move: 0.3, ball: 'L' }),
    kf(floorSit(-4, { shoulderL: 160, elbowL: 4, shoulderR: 120, shoulderAbdR: 70, shoulderRotR: -80, elbowR: 100, twist: -20, neck: -24 }), 'air', { move: 0.3, ball: at(24, 120, -8), ballArc: 12 }),
    kf(floorSit(10, { shoulderL: 40, elbowL: 40, shoulderR: 150, elbowR: 4, twist: 14 }), 'air', { hold: 0.35, ball: at(200, 130, -8) }),
  ],
});
def('sit-vb-dig', 'Seated dig', {
  view: 'three-quarter', ball: VB, thumb: 1,
  keyframes: [
    kf(platform(floorSit(20), 40, 0), 'air', { hold: 0.2, move: 0.3, ball: at(120, 40) }),
    kf(platform(floorSit(26), 44, -2), 'air', { move: 0.25, ball: at(50, 4) }),
    kf(platform(floorSit(10), 44, 14), 'air', { hold: 0.35, ball: at(60, 140) }),
  ],
});
def('sit-vb-scoot', 'Seated scoot', {
  view: 'front', loop: true, thumb: 0,
  keyframes: [
    kf(floorSit(10, both({ shoulder: -10, elbow: 10, shoulderAbd: 30 })), 'air', { hold: 0.1, move: 0.3 }),
    kf(floorSit(4, { ...both({ shoulder: -20, elbow: 4, shoulderAbd: 30 }), lift: 4 }), 'air', { move: 0.3, travel: [0, 18] }),
  ],
});
def('sit-vb-rotation-throw', 'Seated trunk rotation throw', {
  view: 'front', thumb: 1, implement: { kind: 'medball', at: 'chest' },
  keyframes: [
    kf(reachBoth(floorSit(4, { twist: 50 }), () => [14, 30, 26], () => [14, 30, 8]), 'air', { hold: 0.3, move: 0.3 }),
    kf(reachBoth(floorSit(8, { twist: -44 }), () => [40, 36, -24], () => [40, 36, -8]), 'air', { hold: 0.3, move: 0.5 }),
    kf(reachBoth(floorSit(4, { twist: 50 }), () => [14, 30, 26], () => [14, 30, 8]), 'air', { hold: 0.1 }),
  ],
});

// Roundnet --------------------------------------------------------------------
const SPIKE_NET = { kind: 'ball', dx: 60, r: 14 };
def('roundnet-hit', 'Roundnet downward hit', {
  view: 'three-quarter', ball: SB, thumb: 2,
  keyframes: [
    kf(P({ spine: 20, hipL: 40, kneeL: 40, ankleL: 20, hipR: 0, kneeR: 30, ankleR: -20, shoulderR: 150, shoulderAbdR: 30, elbowR: 60, shoulderL: 60, elbowL: 30 }), 'L+Rtoe', { hold: 0.2, move: 0.2, ball: at(40, 100, -12) }),
    kf(P({ spine: 34, hipL: 50, kneeL: 50, ankleL: 24, hipR: 10, kneeR: 34, ankleR: -24, shoulderR: 110, shoulderAbdR: 20, elbowR: 10, shoulderL: 30, elbowL: 40, twist: 10 }), 'L+Rtoe', { move: 0.1, ball: at(44, 80, -14) }),
    kf(P({ spine: 44, hipL: 60, kneeL: 60, ankleL: 28, hipR: 20, kneeR: 40, ankleR: -24, shoulderR: 40, shoulderAbdR: -10, elbowR: 20, shoulderL: 10, elbowL: 40, twist: 20 }), 'L+Rtoe', { hold: 0.35, ball: at(66, 30, -10) }),
  ],
});
def('roundnet-set', 'Roundnet soft set', {
  view: 'three-quarter', ball: SB, thumb: 1,
  keyframes: [
    kf(reach(P(both({ hip: 40, knee: 50, ankle: 24, hipAbd: 14 }), { spine: 26 }), 'R', () => [40, 20, -10]), 'feet', { hold: 0.1, move: 0.3, ball: at(90, 90) }),
    kf(reach(P(both({ hip: 40, knee: 50, ankle: 24, hipAbd: 14 }), { spine: 24 }), 'R', () => [42, 28, -10]), 'feet', { move: 0.25, ball: at(44, 34, -10) }),
    kf(reach(P(both({ hip: 20, knee: 24, ankle: 12, hipAbd: 14 }), { spine: 12 }), 'R', () => [44, 60, -10]), 'feet', { hold: 0.3, ball: at(40, 160, -10) }),
  ],
});
def('roundnet-dive', 'Lateral dive and pop', {
  view: 'front', ball: SB, thumb: 2,
  keyframes: [
    kf(P(both({ hip: 44, knee: 54, ankle: 24, hipAbd: 20, shoulder: 40, elbow: 60 }), { spine: 26 }), 'feet', { hold: 0.2, move: 0.24, ball: at(30, 40, -90) }),
    kf(P({ spine: 30, bend: -30, hipL: 40, kneeL: 20, ankleL: -20, hipAbdL: 30, hipR: 30, kneeR: 50, shoulderR: 90, shoulderAbdR: 90, elbowR: 10, shoulderL: 40, elbowL: 60 }), 'Ltoe', { move: 0.2, travel: [0, -30], ball: at(20, 30, -70) }),
    kf(P({ bend: -80, spine: 10, ...both({ hip: 20, knee: 30 }), shoulderR: 170, elbowR: 10, shoulderL: 60, elbowL: 80 }), 'air', { hold: 0.2, move: 0.4, travel: [0, -40], ball: at(10, 120, -60) }),
    kf(P(both({ hip: 44, knee: 54, ankle: 24, hipAbd: 20, shoulder: 40, elbow: 60 }), { spine: 26 }), 'feet', { hold: 0.2, ball: 'none', travel: [0, -20] }),
  ],
});
def('roundnet-serve', 'Roundnet serve', {
  view: 'three-quarter', ball: SB, thumb: 1,
  keyframes: [
    kf(reach(P({ spine: 30, hipL: 50, kneeL: 50, ankleL: 24, hipR: 0, kneeR: 30, ankleR: -20, shoulderR: 40, shoulderAbdR: 30, elbowR: 20 }), 'L', () => [40, 20, 10]), 'L+Rtoe', { hold: 0.3, move: 0.2, ball: 'L' }),
    kf(P({ spine: 36, hipL: 56, kneeL: 56, ankleL: 26, hipR: 10, kneeR: 30, ankleR: -24, shoulderR: 70, shoulderAbdR: 10, elbowR: 10, shoulderL: 30, elbowL: 40 }), 'L+Rtoe', { move: 0.1, ball: at(44, 10, -8) }),
    kf(P({ spine: 40, hipL: 60, kneeL: 60, ankleL: 28, hipR: 20, kneeR: 34, ankleR: -24, shoulderR: 30, shoulderAbdR: -10, elbowR: 20, shoulderL: 20, elbowL: 40 }), 'L+Rtoe', { hold: 0.35, ball: at(120, 30, -8) }),
  ],
});

export const VOLLEYBALL = lib.patterns;
export { SPIKE_NET };
