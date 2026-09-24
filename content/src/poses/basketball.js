/**
 * Basketball, netball, team handball and wheelchair basketball. Balls are
 * placed with `ball` specs on each keyframe (see rig3d.js ballAt); held balls
 * sit exactly where the hands are solved to hold them.
 */
import { add } from '../rig3d.js';
import { P, both, clear, kf, library, mirror, reach, reachBoth, side, solve, toeDown } from './kit.js';

const lib = library();
const def = lib.def;
const R = 9; // basketball radius (rig units)
const BB = { r: R, color: 'orange' };
const HB = { r: 7, color: 'blue' };
const NB = { r: 8.6, color: 'yellow' };

/** Ball `at` a point [forward, up, left] from the pelvis. */
const at = (f, h, l = 0) => ({ at: [f, h, l] });
/** Both hands on the sides of a ball centred at [f, h, l]. */
const hold = (p, f, h, l = 0, r = R) => reachBoth(p, () => [f, h, l + r * 0.95], () => [f, h, l - r * 0.95]);
/** Shooting grip: right hand behind/under the ball, left hand on its side. */
const shootGrip = (p, f, h, l = -6, r = R) => reachBoth(p, () => [f - 2, h + 2, l + r], () => [f - r * 0.7, h - r * 0.6, l]);
const armsSwing = (fwdL, backR, elbow) => ({ shoulderL: fwdL, shoulderR: backR, elbowL: elbow, elbowR: elbow, shoulderAbdL: 8, shoulderAbdR: 8 });

// Shooting ---------------------------------------------------------------
const shotStance = both({ hipAbd: 8, hip: 14, knee: 18, ankle: 10 });
const setShot = (jump) => {
  const dip = P(both({ hipAbd: 8, hip: 44, knee: 58, ankle: 26 }), { spine: 12, neck: -10 });
  const pocket = shootGrip(dip, 14, 58, -6);
  const release = shootGrip(P(both({ hipAbd: 8, ankle: -24 }), { neck: -18, ...(jump ? { lift: 22 } : {}) }), 20, 98, -6);
  const follow = { ...P(both({ hipAbd: 8, ankle: jump ? -20 : -24 }), { neck: -18, shoulderR: 158, shoulderAbdR: 10, elbowR: 8, wristR: 70, shoulderL: 130, shoulderAbdL: 30, elbowL: 30, ...(jump ? { lift: 22 } : {}) }) };
  return [
    kf(hold(P(shotStance), 22, 38), 'feet', { hold: 0.3, move: 0.35, ball: at(22, 38) }),
    kf(pocket, 'feet', { hold: 0.08, move: 0.3, ball: at(14, 58, -6) }),
    kf(release, jump ? 'air' : 'Ltoe+Rtoe', { move: 0.14, ball: at(20, 98, -6) }),
    kf(follow, jump ? 'air' : 'Ltoe+Rtoe', { hold: 0.4, move: 0.4, ball: at(150, 150, -6), ballArc: 0 }),
    kf(P(shotStance), 'feet', { hold: 0.2, ball: 'none' }),
  ];
};
def('bb-set-shot', 'Basketball set shot', { view: 'three-quarter', ball: BB, thumb: 2, keyframes: setShot(false) });
def('bb-jump-shot', 'Basketball jump shot', { view: 'three-quarter', ball: BB, thumb: 2, keyframes: setShot(true) });

// Dribbling --------------------------------------------------------------
const dribbleStance = { ...both({ hip: 40, knee: 50, ankle: 22, hipAbd: 14 }), spine: 26, neck: -24, shoulderL: 40, elbowL: 70 };
const dribbleTop = reach(P(dribbleStance), 'R', () => [30, 18, -20]);
const dribbleLow = reach(P(dribbleStance), 'R', () => [34, 4, -20]);
def('bb-dribble', 'Stationary dribble', {
  view: 'three-quarter', loop: true, ball: BB, thumb: 0,
  keyframes: [
    kf(dribbleTop, 'feet', { move: 0.17, ball: 'Rdown' }),
    kf(dribbleLow, 'feet', { move: 0.17, ball: { floor: 'R', dx: 4 } }),
  ],
});
/** Running with a right-hand dribble: jog phases, ball bouncing each stride. */
const runPhases = [
  { hipL: 28, kneeL: 14, ankleL: 4, hipR: -10, kneeR: 70, ankleR: -20 },
  { hipL: 4, kneeL: 32, ankleL: 18, hipR: 30, kneeR: 88, ankleR: 0 },
  { hipL: -20, kneeL: 16, ankleL: -26, hipR: 50, kneeR: 64, ankleR: 6, lift: 2 },
  { hipL: -10, kneeL: 56, ankleL: -14, hipR: 36, kneeR: 28, ankleR: 4, lift: 4 },
];
const dribbleRun = () => {
  const frames = [...runPhases, ...runPhases.map(mirror)].map((ph, i) => {
    const up = i % 4 < 2;
    const p = reach(P({ spine: 16, neck: -12, shoulderL: 30 - (i < 4 ? 20 : -20), elbowL: 80, ...ph }), 'R', () => [34, up ? 22 : 6, -20]);
    return kf(p, 'air', { move: 0.13, ball: up ? 'Rdown' : { floor: 'R', dx: 12 } });
  });
  return frames;
};
def('bb-dribble-run', 'Dribbling on the run', {
  path: { kind: 'line', length: 380 }, loop: true, ball: BB, thumb: 0, keyframes: dribbleRun() });
/** Crossover: low dribble from right to left hand in front of the body. */
def('bb-crossover', 'Crossover dribble', {
  view: 'front', loop: true, ball: BB, thumb: 1,
  keyframes: [
    kf(reach(P(dribbleStance, { shoulderL: 20, elbowL: 60 }), 'R', () => [30, 16, -24]), 'feet', { move: 0.18, ball: 'Rdown' }),
    kf(reach(reach(P(dribbleStance, { twist: 10 }), 'R', () => [34, 10, 0]), 'L', () => [30, 14, 26]), 'feet', { move: 0.18, ball: { floor: 'hands', dx: 6 } }),
    kf(reach(P(dribbleStance, { shoulderR: 20, elbowR: 60 }), 'L', () => [30, 16, 24]), 'feet', { move: 0.18, ball: 'Ldown' }),
    kf(reach(reach(P(dribbleStance, { twist: -10 }), 'L', () => [34, 10, 0]), 'R', () => [30, 14, -26]), 'feet', { move: 0.18, ball: { floor: 'hands', dx: 6 } }),
  ],
});
/** First-step attack: jab, push off the far foot, long first step with a low dribble. */
def('bb-first-step', 'First-step attack', {
  view: 'three-quarter', ball: BB, thumb: 1,
  keyframes: [
    kf(hold(P(dribbleStance), 26, 26), 'feet', { hold: 0.4, move: 0.2, ball: at(26, 26) }),
    kf(reach(P({ spine: 40, neck: -14, hipL: 80, kneeL: 90, ankleL: 30, hipR: -16, kneeR: 20, ankleR: -30, shoulderL: -30, elbowL: 70 }), 'R', () => [52, 4, -12]), 'L+Rtoe', { move: 0.22, ball: { floor: 'R', dx: 8 }, travel: [30, 0] }),
    kf(reach(P({ spine: 26, neck: -10, hipR: 64, kneeR: 70, ankleR: 10, hipL: -14, kneeL: 30, ankleL: -30, shoulderL: 40, elbowL: 80 }), 'R', () => [40, 22, -16]), 'Ltoe', { hold: 0.3, ball: 'Rdown' }),
  ],
});
const hesitate = reach(P({ ...both({ hip: 30, knee: 30, ankle: 14, hipAbd: 10 }), spine: 16, neck: -10, shoulderL: 30, elbowL: 70 }), 'R', () => [28, 18, -18]);
def('bb-change-of-pace', 'Hesitation and burst', {
  ball: BB, thumb: 2,
  keyframes: [
    kf(hesitate, 'feet', { hold: 0.35, move: 0.18, ball: 'Rdown' }),
    kf(reach(P({ ...both({ hip: 30, knee: 30, ankle: 14, hipAbd: 10 }), spine: 16, neck: -10, shoulderL: 30, elbowL: 70 }), 'R', () => [30, 4, -18]), 'feet', { move: 0.16, ball: { floor: 'R', dx: 4 } }),
    kf(reach(P({ spine: 38, neck: -12, hipL: 84, kneeL: 96, ankleL: 30, hipR: -18, kneeR: 20, ankleR: -30, shoulderL: -30, elbowL: 70 }), 'R', () => [50, 16, -14]), 'L+Rtoe', { move: 0.2, ball: 'Rdown', travel: [34, 0] }),
    kf(reach(P({ spine: 30, neck: -10, hipR: 80, kneeR: 96, ankleR: 10, hipL: -14, kneeL: 40, ankleL: -30, shoulderL: 50, elbowL: 80 }), 'R', () => [46, 4, -14]), 'Ltoe', { hold: 0.2, ball: { floor: 'R', dx: 10 }, travel: [30, 0] }),
  ],
});

// Finishing and rebounding ---------------------------------------------------
/** Layup: last two steps with the ball gathered, take off the left foot, right knee drives, release high. */
def('bb-layup', 'Layup', {
  ball: BB, thumb: 3,
  keyframes: [
    kf(hold(P({ spine: 12, hipR: 44, kneeR: 30, ankleR: 10, hipL: -18, kneeL: 50, ankleL: -24 }), 22, 36), 'R', { move: 0.24, ball: at(22, 36) }),
    kf(hold(P({ spine: 14, hipL: 46, kneeL: 34, ankleL: 14, hipR: -20, kneeR: 50, ankleR: -24 }), 20, 44), 'L', { move: 0.2, ball: at(20, 44), travel: [40, 0] }),
    kf(hold(P({ spine: 4, hipL: 0, kneeL: 4, ankleL: -34, hipR: 90, kneeR: 100, ankleR: -10 }), 16, 80, -4), 'Ltoe', { move: 0.2, ball: at(16, 80, -4), travel: [20, 0] }),
    kf(reach(P({ spine: 0, hipL: 4, kneeL: 20, ankleL: -30, hipR: 84, kneeR: 90, shoulderL: 60, elbowL: 30, lift: 30 }), 'R', () => [24, 110, -8]), 'air', { hold: 0.1, move: 0.3, ball: at(30, 118, -8) }),
    kf(P(both({ hip: 40, knee: 50, ankle: 22, hipAbd: 10 }), { spine: 14, shoulderL: 40, shoulderR: 60, elbowL: 30, elbowR: 30 }), 'feet', { hold: 0.3, ball: at(60, 150, -8), travel: [20, 0] }),
  ],
});
def('bb-mikan', 'Mikan drill', {
  view: 'front', ball: BB, loop: true, thumb: 1,
  keyframes: [
    kf(hold(P(both({ hip: 30, knee: 34, ankle: 16, hipAbd: 10 }), { spine: 8 }), 18, 60, -10), 'feet', { move: 0.35, ball: at(18, 60, -10) }),
    kf(reach(P({ hipL: 0, kneeL: 6, ankleL: -30, hipR: 80, kneeR: 90, shoulderL: 60, elbowL: 30, lift: 18 }), 'R', () => [16, 108, -14]), 'air', { move: 0.35, ball: at(20, 116, -14) }),
    kf(hold(P(both({ hip: 30, knee: 34, ankle: 16, hipAbd: 10 }), { spine: 8 }), 18, 60, 10), 'feet', { move: 0.35, ball: at(18, 60, 10) }),
    kf(reach(P({ hipR: 0, kneeR: 6, ankleR: -30, hipL: 80, kneeL: 90, shoulderR: 60, elbowR: 30, lift: 18 }), 'L', () => [16, 108, 14]), 'air', { move: 0.35, ball: at(20, 116, 14) }),
  ],
});
const reachUp = both({ shoulder: 172, shoulderAbd: 16, elbow: 6 });
def('bb-rebound', 'Rebound', {
  view: 'three-quarter', ball: BB, thumb: 2,
  keyframes: [
    kf(P(both({ hip: 60, knee: 70, ankle: 28, hipAbd: 20, shoulder: 60, shoulderAbd: 30, elbow: 60 }), { spine: 30, neck: -30 }), 'feet', { hold: 0.2, move: 0.2, ball: at(60, 200) }),
    kf(P(both({ ankle: -30, hipAbd: 10 }), reachUp), 'Ltoe+Rtoe', { move: 0.2, ball: at(40, 170) }),
    kf(hold(P(both({ ankle: -26, knee: 8, hipAbd: 10 }), { lift: 26, neck: -20 }), 14, 120), 'air', { hold: 0.08, move: 0.3, ball: at(14, 120) }),
    kf(hold(P(both({ hip: 60, knee: 70, ankle: 28, hipAbd: 24 }), { spine: 26, neck: -10 }), 14, 44), 'feet', { hold: 0.4, ball: at(14, 44) }),
  ],
});
def('bb-tip-series', 'Rebound tip series', {
  view: 'three-quarter', ball: BB, loop: true, thumb: 1,
  keyframes: [
    kf(P(both({ hip: 30, knee: 40, ankle: 20, hipAbd: 10 }), reachUp, { spine: 8, neck: -24 }), 'feet', { move: 0.22, ball: at(24, 190) }),
    kf(hold(P(both({ ankle: -30, knee: 6, hipAbd: 10 }), { lift: 24, neck: -30 }), 12, 132), 'air', { move: 0.22, ball: at(12, 132) }),
  ],
});
def('bb-box-out', 'Box-out and rebound', {
  view: 'three-quarter', ball: BB, thumb: 1,
  keyframes: [
    kf(P(both({ hip: 30, knee: 34, ankle: 16, hipAbd: 12, shoulder: 40, elbow: 60 }), { spine: 10, turn: 180 }), 'feet', { hold: 0.2, move: 0.4, ball: 'none' }),
    kf(P(both({ hip: 64, knee: 74, ankle: 28, hipAbd: 30, hipRot: -10, shoulder: 70, shoulderAbd: 70, elbow: 70 }), { spine: 24, neck: -30 }), 'feet', { hold: 0.8, move: 0.2, ball: at(40, 190) }),
    kf(P(both({ ankle: -30, hipAbd: 12 }), reachUp, { neck: -30 }), 'Ltoe+Rtoe', { move: 0.2, ball: at(20, 160) }),
    kf(hold(P(both({ ankle: -26, knee: 8, hipAbd: 12 }), { lift: 22, neck: -20 }), 14, 120), 'air', { hold: 0.1, move: 0.3, ball: at(14, 120) }),
    kf(hold(P(both({ hip: 60, knee: 70, ankle: 28, hipAbd: 24 }), { spine: 24 }), 14, 44), 'feet', { hold: 0.3, ball: at(14, 44) }),
  ],
});
// The opponent the box-out holds off: sets behind, leans in, reaches late.
def('bb-box-out-opponent', 'Box-out opponent', {
  view: 'three-quarter', thumb: 1,
  keyframes: [
    kf(P(both({ hip: 24, knee: 28, ankle: 12, hipAbd: 10, shoulder: 30, elbow: 50 }), { spine: 8 }), 'feet', { hold: 0.2, move: 0.4 }),
    kf(P(both({ hip: 40, knee: 44, ankle: 20, hipAbd: 14, shoulder: 80, elbow: 40 }), { spine: 30, neck: -24 }), 'feet', { hold: 0.8, move: 0.2 }),
    kf(P(both({ hip: 30, knee: 34, ankle: 16, hipAbd: 12 }), reachUp, { spine: 14, neck: -30 }), 'feet', { move: 0.2 }),
    kf(P(both({ hip: 30, knee: 34, ankle: 16, hipAbd: 12 }), reachUp, { spine: 14, neck: -30 }), 'feet', { hold: 0.1, move: 0.3 }),
    kf(P(both({ hip: 24, knee: 28, ankle: 12, hipAbd: 10, shoulder: 30, elbow: 50 }), { spine: 8 }), 'feet', { hold: 0.3 }),
  ],
});
def('bb-box-out-vs', 'Box-out and rebound (with opponent)', {
  ...lib.get('bb-box-out'), cast: [{ pattern: 'bb-box-out-opponent', at: [-42, 22], facing: 0 }],
});

// Defence ----------------------------------------------------------------------
const defStance = both({ hip: 52, knee: 62, ankle: 28, hipAbd: 24, shoulderAbd: 60, elbow: 20, shoulder: 30 });
def('bb-defensive-slide', 'Defensive slide', {
  path: { kind: 'line', length: 220, dir: 'left', speed: 110 },
  view: 'front', loop: true, thumb: 0,
  keyframes: [
    kf(P(defStance, { spine: 26, neck: -14 }), 'feet', { move: 0.16 }),
    kf(P(defStance, { spine: 26, neck: -14, hipAbdL: 36, hipAbdR: 14, kneeR: 58, lift: 2 }), 'air', { move: 0.16, travel: [0, 22] }),
  ],
});
def('bb-closeout', 'Closeout', {
  view: 'three-quarter', thumb: 3,
  keyframes: [
    kf(P(defStance, { spine: 26, neck: -14 }), 'feet', { hold: 0.2, move: 0.2 }),
    kf(P({ spine: 20, hipL: 60, kneeL: 40, ankleL: 10, hipR: -16, kneeR: 80, ankleR: -24, shoulderL: -30, shoulderR: 50, elbowL: 80, elbowR: 80, lift: 3 }), 'air', { move: 0.2, travel: [40, 0] }),
    kf(P(both({ hip: 40, knee: 50, ankle: 24, hipAbd: 18 }), { spine: 18, shoulderL: 170, elbowL: 4, shoulderR: 40, shoulderAbdR: 50, elbowR: 30 }), 'Ltoe+Rtoe', { move: 0.12, travel: [30, 0] }),
    kf(P(both({ hip: 44, knee: 54, ankle: 26, hipAbd: 20 }), { spine: 20, shoulderL: 172, elbowL: 4, shoulderR: 40, shoulderAbdR: 50, elbowR: 30 }), 'feet', { hold: 0.5, travel: [8, 0] }),
  ],
});

// Passing --------------------------------------------------------------------
const passStance = both({ hip: 24, knee: 28, ankle: 14, hipAbd: 10 });
def('bb-chest-pass', 'Chest pass', {
  view: 'three-quarter', ball: BB, thumb: 1,
  keyframes: [
    kf(hold(P(passStance, { spine: 10 }), 18, 46), 'feet', { hold: 0.3, move: 0.2, ball: at(18, 46) }),
    kf(hold(P({ spine: 18, hipL: 40, kneeL: 30, ankleL: 14, hipR: -10, kneeR: 20, ankleR: -24 }), 48, 44), 'L+Rtoe', { move: 0.35, ball: at(48, 44) }),
    kf(P({ spine: 18, hipL: 40, kneeL: 30, ankleL: 14, hipR: -10, kneeR: 20, ankleR: -24, ...both({ shoulder: 84, elbow: 4, wrist: -40, shoulderAbd: 6 }) }), 'L+Rtoe', { hold: 0.3, ball: at(180, 50) }),
  ],
});
/** One-hand overarm pass or throw (handball, netball shoulder pass). */
const overarm = (arc = 0, runIn = false) => [
  ...(runIn ? [kf(P({ spine: 8, hipL: 30, kneeL: 20, ankleL: 8, hipR: -14, kneeR: 50, ankleR: -24, shoulderR: 120, shoulderAbdR: 60, elbowR: 90, shoulderL: 40, elbowL: 60 }), 'L', { move: 0.22, ball: 'R' })] : []),
  kf(P({ spine: -4, twist: -40, hipL: 34, kneeL: 20, ankleL: 10, hipR: -10, kneeR: 20, ankleR: -10,
    shoulderR: 90, shoulderAbdR: 88, shoulderRotR: -80, elbowR: 90, shoulderL: 70, shoulderAbdL: 20, elbowL: 20 }), 'L+Rtoe', { hold: 0.12, move: 0.18, ball: 'R', ...(runIn ? { travel: [30, 0] } : {}) }),
  kf(P({ spine: 20, twist: 30, hipL: 40, kneeL: 30, ankleL: 14, hipR: 0, kneeR: 20, ankleR: -34,
    shoulderR: 110, shoulderAbdR: 40, shoulderRotR: 20, elbowR: 10, wristR: 40, shoulderL: -10, shoulderAbdL: 30, elbowL: 40 }), 'L+Rtoe', { move: 0.2, ball: 'R' }),
  kf(P({ spine: 30, twist: 40, hipL: 50, kneeL: 36, ankleL: 18, hipR: 30, kneeR: 40, ankleR: -30, shoulderR: 40, shoulderAbdR: -20, elbowR: 20, shoulderL: -20, shoulderAbdL: 30, elbowL: 40 }), 'L+Rtoe', { hold: 0.35, ball: at(170, 90 + arc) }),
];
def('handball-three-step-throw', 'Three-step throw', { view: 'three-quarter', ball: HB, thumb: 2, keyframes: overarm(0, true) });
def('overarm-pass', 'One-hand overarm pass', { view: 'three-quarter', ball: HB, thumb: 1, keyframes: overarm(10) });
def('handball-jump-shot', 'Handball jump shot', {
  view: 'three-quarter', ball: HB, thumb: 2,
  keyframes: [
    kf(P({ spine: 10, hipL: 44, kneeL: 40, ankleL: 20, hipR: -10, kneeR: 40, ankleR: -20, shoulderR: 90, shoulderAbdR: 88, shoulderRotR: -80, elbowR: 90, shoulderL: 40, elbowL: 40 }), 'L', { move: 0.22, ball: 'R' }),
    kf(P({ spine: -2, twist: -40, hipL: 0, kneeL: 6, ankleL: -30, hipR: 80, kneeR: 90, shoulderR: 100, shoulderAbdR: 88, shoulderRotR: -90, elbowR: 90, shoulderL: 80, elbowL: 20, lift: 28 }), 'air', { move: 0.16, ball: 'R', travel: [30, 0] }),
    kf(P({ spine: 16, twist: 30, hipL: 10, kneeL: 20, ankleL: -30, hipR: 60, kneeR: 60, shoulderR: 120, shoulderAbdR: 40, elbowR: 10, wristR: 40, shoulderL: -10, shoulderAbdL: 30, elbowL: 40, lift: 26 }), 'air', { move: 0.3, ball: 'R' }),
    kf(P(both({ hip: 40, knee: 50, ankle: 24, hipAbd: 10 }), { spine: 20, shoulderR: 40, elbowR: 20, shoulderL: 20, elbowL: 30 }), 'feet', { hold: 0.35, ball: at(200, 70), travel: [20, 0] }),
  ],
});
def('handball-feint', 'Shot fake and break', {
  view: 'three-quarter', ball: HB, thumb: 1,
  keyframes: [
    kf(P({ spine: 6, hipL: 30, kneeL: 20, ankleL: 10, hipR: -10, kneeR: 30, ankleR: -14, shoulderR: 90, shoulderAbdR: 88, shoulderRotR: -80, elbowR: 90, shoulderL: 50, elbowL: 30 }), 'L+Rtoe', { hold: 0.2, move: 0.18, ball: 'R' }),
    kf(P({ spine: 16, twist: 20, hipL: 36, kneeL: 30, ankleL: 14, hipR: -4, kneeR: 30, ankleR: -24, shoulderR: 110, shoulderAbdR: 50, elbowR: 40, shoulderL: 10, elbowL: 30 }), 'L+Rtoe', { hold: 0.1, move: 0.2, ball: 'R' }),
    kf(P({ spine: 30, turn: -40, hipL: 70, kneeL: 80, ankleL: 28, hipAbdL: 24, hipR: 10, kneeR: 30, ankleR: -24, shoulderR: 60, elbowR: 60, shoulderL: 30, elbowL: 60 }), 'L+Rtoe', { move: 0.22, ball: 'R', travel: [0, 30] }),
    kf(P({ spine: 20, turn: -30, hipR: 80, kneeR: 96, ankleR: 10, hipL: -14, kneeL: 30, ankleL: -30, shoulderR: 60, elbowR: 60, shoulderL: 40, elbowL: 70 }), 'Ltoe', { hold: 0.3, ball: 'R', travel: [30, -20] }),
  ],
});

// Netball --------------------------------------------------------------------
def('netball-shot', 'Netball goal shot', {
  view: 'three-quarter', ball: NB, thumb: 2,
  keyframes: [
    kf(shootGrip(P(both({ hipAbd: 8, hip: 10, knee: 12, ankle: 6 }), { neck: -24 }), 10, 110, -2, 8.6), 'feet', { hold: 0.4, move: 0.35, ball: at(10, 110, -2) }),
    kf(shootGrip(P(both({ hipAbd: 8, hip: 40, knee: 54, ankle: 24 }), { spine: 4, neck: -30 }), 8, 96, -2, 8.6), 'feet', { hold: 0.1, move: 0.3, ball: at(8, 96, -2) }),
    kf(P(both({ hipAbd: 8, ankle: -24 }), { neck: -28, shoulderR: 170, elbowR: 8, wristR: 60, shoulderL: 150, shoulderAbdL: 30, elbowL: 30 }), 'Ltoe+Rtoe', { hold: 0.4, ball: at(120, 190, -2) }),
  ],
});
def('netball-drive-catch', 'Drive, catch and land', {
  ball: NB, thumb: 2,
  keyframes: [
    kf(P({ spine: 16, hipL: 40, kneeL: 30, ankleL: 10, hipR: -16, kneeR: 60, ankleR: -24, shoulderL: -30, shoulderR: 50, elbowL: 80, elbowR: 80 }), 'L', { move: 0.22, ball: at(160, 80) }),
    kf(P({ spine: 20, hipR: 60, kneeR: 50, hipL: -20, kneeL: 30, ankleL: -30, ...both({ shoulder: 100, elbow: 10, shoulderAbd: 14 }), lift: 12 }), 'air', { move: 0.2, ball: at(70, 64), travel: [40, 0] }),
    kf(hold(P({ spine: 16, hipL: 50, kneeL: 50, ankleL: 24, hipR: 30, kneeR: 80, ankleR: -10 }), 18, 46, 0, 8.6), 'L', { hold: 0.4, move: 0.4, ball: at(18, 46), travel: [30, 0] }),
    kf(hold(P({ spine: 8, turn: 90, hipL: 30, kneeL: 30, ankleL: 14, hipR: 20, kneeR: 50, ankleR: -20, hipAbdR: 10 }), 18, 50, 0, 8.6), 'L', { hold: 0.3, ball: at(18, 50) }),
  ],
});
def('netball-defend', 'Three-foot defending', {
  view: 'three-quarter', thumb: 1,
  keyframes: [
    kf(P(both({ hip: 24, knee: 30, ankle: 14, hipAbd: 14, shoulder: 150, shoulderAbd: 30, elbow: 10 }), { spine: 8, neck: -20 }), 'feet', { hold: 0.4, move: 0.25 }),
    kf(P(both({ ankle: -30, hipAbd: 10, shoulder: 170, shoulderAbd: 20, elbow: 4 }), { lift: 18, neck: -24 }), 'air', { move: 0.25 }),
    kf(P(both({ hip: 30, knee: 40, ankle: 20, hipAbd: 14, shoulder: 150, shoulderAbd: 30, elbow: 10 }), { spine: 10, neck: -20 }), 'feet', { hold: 0.3 }),
  ],
});

// Wheelchair basketball ------------------------------------------------------
/** Seated in the chair: hands on the push rims (wheel centre 26 up, rim radius 22). */
/** Sitting in the chair with the trunk leaned `spine`: thighs stay level on the seat. */
const seatedAt = (spine) => ({ ...both({ hip: 88 + spine, knee: 96, ankle: 0, hipAbd: 6 }), spine });
const rim = (deg, side = 1) => (sk) => {
  const floor = Math.min(sk.L.ankle[1], sk.R.ankle[1]);
  const c = [sk.pelvis[0] - 2, floor + 26, side * 17];
  return [c[0] + Math.cos((deg * Math.PI) / 180) * 22, c[1] + Math.sin((deg * Math.PI) / 180) * 22, c[2]];
};
const onRims = (p, degL, degR = degL) => reachBoth(p, rim(degL, 1), rim(degR, -1));
const chair = { kind: 'wheelchair' };
def('wc-push', 'Wheelchair push', {
  view: 'three-quarter', loop: true, thumb: 0, fixture: chair,
  keyframes: [
    kf(onRims(P(seatedAt(18), { neck: -10 }), 110), 'seat', { move: 0.35 }),
    kf(onRims(P(seatedAt(30), { neck: -14 }), 20), 'seat', { move: 0.22 }),
    kf(P(seatedAt(22), { neck: -12, ...both({ shoulder: -20, elbow: 60, shoulderAbd: 20 }) }), 'seat', { move: 0.3 }),
  ],
});
def('wc-pivot', 'Wheelchair pivot turn', {
  view: 'three-quarter', loop: true, thumb: 0, fixture: chair,
  keyframes: [
    kf(onRims(P(seatedAt(16), { turn: 0 }), 100, 30), 'seat', { move: 0.45 }),
    kf(onRims(P(seatedAt(18), { turn: 60 }), 30, 100), 'seat', { move: 0.45 }),
  ],
});
def('wc-shot', 'Seated shot', {
  view: 'three-quarter', fixture: chair, ball: BB, thumb: 1,
  keyframes: [
    kf(shootGrip(P(seatedAt(6), {  }), 14, 60, -6), 'seat', { hold: 0.35, move: 0.3, ball: at(14, 60, -6) }),
    kf(P(seatedAt(-2), { neck: -20, shoulderR: 162, shoulderAbdR: 10, elbowR: 8, wristR: 70, shoulderL: 130, shoulderAbdL: 30, elbowL: 30 }), 'seat', { hold: 0.4, move: 0.4, ball: at(150, 170, -6) }),
    kf(shootGrip(P(seatedAt(6), {  }), 14, 60, -6), 'seat', { hold: 0.1, ball: 'none' }),
  ],
});
def('wc-dribble-push', 'Push and dribble', {
  view: 'three-quarter', loop: true, ball: BB, thumb: 0, fixture: chair,
  keyframes: [
    kf(onRims(P(seatedAt(18), {  }), 110), 'seat', { move: 0.3, ball: { floor: 'R', dx: 30, dl: -14 } }),
    kf(onRims(P(seatedAt(28), {  }), 20), 'seat', { move: 0.3, ball: { floor: 'R', dx: 30, dl: -14 } }),
    kf(reach(P(seatedAt(20), { shoulderL: 10, elbowL: 40 }), 'R', (sk) => [sk.pelvis[0] + 30, sk.pelvis[1] - 4, -24]), 'seat', { move: 0.25, ball: 'Rdown' }),
    kf(reach(P(seatedAt(20), { shoulderL: 10, elbowL: 40 }), 'R', (sk) => [sk.pelvis[0] + 30, sk.pelvis[1] - 12, -24]), 'seat', { move: 0.25, ball: { floor: 'R', dx: 2 } }),
  ],
});

def('netball-shadow-mark', 'Shadow marking (attacker and defender)', {
  ...lib.get('bb-defensive-slide'), view: 'three-quarter', cast: [{ pattern: 'bb-defensive-slide', at: [60, 0], facing: 180, follow: true, phase: 0.5 }],
});

export const BASKETBALL = lib.patterns;
