/** Strength, power and gym patterns. */
import { BONES, add, apply, scale, skeleton, sub } from '../rig3d.js';
import { ATHLETIC, P, STAND, both, clear, mirror as mirrorKit, elbowsDown, flatHands, handsToFloor, kf, library, on, reach, reachBoth, reachLeg, side, solve, toeDown, levelFeet, tween } from './kit.js';

const lib = library();
const def = lib.def;

// Push-up --------------------------------------------------------------
const pushTop = handsToFloor(P(both({ shoulder: 88, elbow: 0, shoulderAbd: 10, ankle: 30, wrist: -85 }), { neck: -10 }));
const pushBottom = handsToFloor(P(both({ shoulder: 30, elbow: 72, shoulderAbd: 30, ankle: 30, wrist: -85 }), { neck: -10 }));
const pushDown = kf(pushTop, 'hands', { hold: 0.3, move: 0.8 });
const pushLow = kf(pushBottom, 'hands', { hold: 0.15, move: 0.7 });
def('push-up', 'Push-up', {
  keyframes: [
    ...tween(pushDown, pushLow, 3, handsToFloor),
    ...tween(pushLow, kf(pushTop, 'hands', { hold: 0.1 }), 3, handsToFloor),
    kf(pushTop, 'hands', { hold: 0.1 }),
  ],
  thumb: 4,
});

// Pull-up --------------------------------------------------------------
const barHang = P(both({ shoulder: 172, shoulderAbd: 18, elbow: 4, hip: 8, knee: 30, ankle: -20 }));
const chinOver = P(both({ shoulder: 48, shoulderAbd: 30, elbow: 128, hip: 18, knee: 36, ankle: -20 }), { spine: -8, neck: -10 });
def('pull-up', 'Pull-up', {
  view: 'three-quarter',
  fixture: { kind: 'bar' },
  keyframes: [
    kf(barHang, 'grip', { hold: 0.3, move: 0.9, surface: 14 }),
    kf(chinOver, 'grip', { hold: 0.25, move: 1.0 }),
    kf(barHang, 'grip', { hold: 0.1 }),
  ],
});

// Lateral raise (front view) -------------------------------------------
def('lateral-raise', 'Lateral raise', {
  view: 'front',
  implement: { kind: 'dumbbells', at: 'hands' },
  keyframes: [
    kf(P(both({ shoulderAbd: 10, elbow: 10 })), 'feet', { hold: 0.3, move: 0.8 }),
    kf(P(both({ shoulderAbd: 88, elbow: 12, shoulder: 12 })), 'feet', { hold: 0.2, move: 1.0 }),
    kf(P(both({ shoulderAbd: 10, elbow: 10 })), 'feet', { hold: 0.1 }),
  ],
});

// Bench press ----------------------------------------------------------
const benchLegs = both({ hip: 8, knee: 96, ankle: 6, hipAbd: 14 });
const benchTop = P(benchLegs, both({ shoulder: 90, shoulderAbd: 14, elbow: 0 }), { spine: -90 });
const benchBottom = P(benchLegs, both({ shoulder: 18, shoulderAbd: 58, elbow: 92 }), { spine: -90 });
def('bench-press', 'Bench press', {
  view: 'three-quarter',
  fixture: { kind: 'bench', from: -56, to: 12, below: -10 },
  implement: { kind: 'barbell', at: 'hands' },
  keyframes: [
    kf(benchTop, 'feet', { hold: 0.3, move: 0.9 }),
    kf(benchBottom, 'feet', { hold: 0.15, move: 0.8 }),
    kf(benchTop, 'feet', { hold: 0.1 }),
  ],
});


// ── Shared helpers ─────────────────────────────────────────────────────

const up = (sk) => apply(sk.trunk, [0, 1, 0]);
const fwd = (sk) => apply(sk.trunk, [1, 0, 0]);
const lat = (sk) => apply(sk.chest, [0, 0, 1]);
const floorY = (sk) => Math.min(sk.L.ankle[1], sk.R.ankle[1]);
/** Arms hanging straight down (vertical), whatever the trunk lean. */
const hang = (p, extra = 0) => ({ ...p, shoulderL: p.spine + extra, shoulderR: p.spine + extra, elbowL: 2, elbowR: 2, shoulderAbdL: 8, shoulderAbdR: 8 });
/** A point in front of the chest (trunk frame): d forward of the sternum, h below the neck. */
const chestPoint = (d, h, w) => (sk) => add(add(add(sk.neckBase, up(sk), -h), fwd(sk), d), lat(sk), w);
const ROTS = [-60, -45, -30, -15, 0, 15, 30, 45, 60];
const goblet = (p) => reachBoth(p, chestPoint(15, 14, 4.5), chestPoint(15, 14, -4.5), { rot: ROTS, prefer: elbowsDown });
const rack = (p) => reachBoth(p, ...on.rackBar(19), { rot: ROTS, prefer: (sk, side) => -sk[side].elbow[0] });
const backBar = (p) => reachBoth(p, ...on.backBar(26));
/** Hands on a floor bar over mid-foot (bar centre 12 up — plates resting on the floor). */
const barAtFloor = (dx = 4, h = 12, w = 21) => [
  (sk) => [ (sk.L.ankle[0] + sk.R.ankle[0]) / 2 + dx, floorY(sk) + h, w ], (sk) => [(sk.L.ankle[0] + sk.R.ankle[0]) / 2 + dx, floorY(sk) + h, -w]];
/** Wrist-to-shoulder distance for straight arms. */
const ARM = BONES.upperArm + BONES.forearm;
/** Lean the trunk (spine) until straight arms just reach the targets. */
const leanToReach = (p, target, lo = 0, hi = 90) => solve(p, 'spine', (sk) => {
  const t = target(sk);
  return Math.hypot(t[0] - sk.L.shoulder[0], t[1] - sk.L.shoulder[1], t[2] - sk.L.shoulder[2]) - (ARM - 1);
}, lo, hi);
const standBar = (p) => ({ ...p });
const W = (id, pose, contact = 'feet', o = {}) => kf(pose, contact, o);

// Squats ---------------------------------------------------------------
const squatStand = P(both({ hipAbd: 9, hipRot: -9, shoulder: 8 }));
const squatLow = (arms = {}) => P(both({ hip: 112, knee: 120, ankle: 36, hipAbd: 16, hipRot: -16, ...arms }), { spine: 42, neck: -32 });
const rep3 = (a, b, { down = 0.9, upT = 0.8, holdTop = 0.35, holdLow = 0.2, contact = 'feet' } = {}) => [
  kf(a, contact, { hold: holdTop, move: down }), kf(b, contact, { hold: holdLow, move: upT }), kf(a, contact, { hold: 0.1 }),
];

def('squat-bodyweight', 'Bodyweight squat', {
  view: 'three-quarter',
  keyframes: rep3(P(both({ hipAbd: 9, hipRot: -9, shoulder: 8 })), squatLow({ shoulder: 88, elbow: 6, shoulderAbd: 8 })),
});
def('goblet-squat', 'Goblet squat', {
  view: 'three-quarter', implement: { kind: 'goblet', at: 'chest' },
  keyframes: rep3(goblet(squatStand), goblet(P(both({ hip: 114, knee: 122, ankle: 36, hipAbd: 18, hipRot: -18 }), { spine: 34, neck: -26 }))),
});
def('back-squat', 'Barbell back squat', {
  view: 'three-quarter', implement: { kind: 'barbell', at: 'back' },
  keyframes: rep3(backBar(squatStand), backBar(P(both({ hip: 106, knee: 112, ankle: 32, hipAbd: 15, hipRot: -15 }), { spine: 44, neck: -34 })), { down: 1.0 }),
});
def('front-squat', 'Barbell front squat', {
  view: 'three-quarter', implement: { kind: 'barbell', at: 'rack' },
  keyframes: rep3(rack(squatStand), rack(P(both({ hip: 112, knee: 124, ankle: 38, hipAbd: 15, hipRot: -15 }), { spine: 26, neck: -18 })), { down: 1.0 }),
});
const ohArms = both({ shoulder: 174, shoulderAbd: 30, elbow: 0 });
def('overhead-squat', 'Overhead squat', {
  view: 'three-quarter', implement: { kind: 'barbell', at: 'hands' },
  keyframes: rep3(P(ohArms, both({ hipAbd: 10, hipRot: -10 })), P(both({ hip: 116, knee: 124, ankle: 38, hipAbd: 17, hipRot: -17, shoulder: 198, shoulderAbd: 28, elbow: 0 }), { spine: 22, neck: -10 }), { down: 1.1 }),
});
def('squat-hold', 'Deep squat hold', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 118, knee: 132, ankle: 40, hipAbd: 20, hipRot: -20, shoulder: 70, elbow: 70, shoulderAbd: 10 }), { spine: 30, neck: -20 }), 'feet', { hold: 0.8, move: 1.4 }),
    kf(P(both({ hip: 116, knee: 131, ankle: 40, hipAbd: 21, hipRot: -21, shoulder: 72, elbow: 70, shoulderAbd: 10 }), { spine: 27, neck: -22 }), 'feet', { hold: 0.8, move: 1.4 }),
  ],
});
const wallSeat = P(both({ hip: 90, knee: 90, ankle: 0, hipAbd: 8, shoulder: 0, elbow: 6 }));
def('wall-sit', 'Wall sit', {
  loop: true, thumb: 0, fixture: { kind: 'wall', at: -11 },
  keyframes: [kf(wallSeat, 'feet', { hold: 1.2, move: 1.2 }), kf({ ...wallSeat, neck: -4, shoulderL: 3, shoulderR: 3 }, 'feet', { hold: 1.2, move: 1.2 })],
});

// Split stances --------------------------------------------------------
/** L (near) leg forward and planted flat, R (far) leg back on its toes. */
const split = (frontHip, frontKnee, backHip, backKnee, extra = {}) =>
  toeDown(P({ hipL: frontHip, kneeL: frontKnee, hipR: backHip, kneeR: backKnee, ankleL: Math.max(0, frontKnee - frontHip) * 0.5, ...extra }), 'R');
/** Solves the back knee so the back toe can reach the floor, then points it down. */
const splitFit = (frontHip, frontKnee, backHip, extra = {}) => {
  const p = solve(P({ hipL: frontHip, kneeL: frontKnee, hipR: backHip, ...extra }), 'kneeR',
    (sk) => (sk.R.ankle[1] - 11) - sk.L.ankle[1], 0, 150);
  return toeDown(p, 'R');
};
const splitArms = { shoulderL: -10, shoulderR: -10, elbowL: 10, elbowR: 10 };
def('split-squat', 'Split squat', {
  keyframes: rep3(splitFit(24, 8, -22, { spine: 2, ...splitArms }), splitFit(88, 92, -12, { spine: 6, ...splitArms }), { contact: 'L' }),
});
/** Rear foot laces-down on a bench `back` behind the front ankle, `height` up. */
const rearOnBench = (p, back = 66, height = 34) => ({
  ...reachLeg(p, 'R', (sk) => [sk.L.ankle[0] - back, sk.L.ankle[1] + height + 3, sk.R.hip[2]]),
  ankleR: -56,
});
def('bulgarian-split-squat', 'Bulgarian split squat', {
  fixture: { kind: 'bench', from: -84, to: -44, top: 34 },
  keyframes: rep3(
    rearOnBench(P({ hipL: 26, kneeL: 16, ankleL: 10, spine: 8, ...splitArms })),
    rearOnBench(P({ hipL: 100, kneeL: 104, ankleL: 24, spine: 20, ...splitArms })), { contact: 'L' }),
});
const lungeStand = P({ ...splitArms });
const reverseStep = splitFit(20, 6, -30, { spine: 4, ...splitArms });
const reverseLow = splitFit(86, 90, -12, { spine: 6, ...splitArms });
def('reverse-lunge', 'Reverse lunge', {
  thumb: 2,
  keyframes: [
    kf(lungeStand, 'feet', { hold: 0.3, move: 0.55 }),
    kf(reverseStep, 'L', { move: 0.6 }),
    kf(reverseLow, 'L', { hold: 0.2, move: 0.6 }),
    kf(reverseStep, 'L', { move: 0.55 }),
    kf(lungeStand, 'feet', { hold: 0.1 }),
  ],
});
def('walking-lunge', 'Walking lunge', {
  thumb: 3,
  keyframes: [
    kf(P(splitArms), 'feet', { hold: 0.2, move: 0.45 }),
    kf(P({ ...splitArms, hipL: 48, kneeL: 62, ankleL: 4, shoulderL: -20, shoulderR: 16 }), 'R', { move: 0.35 }),
    kf(levelFeet(P({ hipL: 28, kneeL: 4, ankleL: 10, hipR: -22, spine: 3, shoulderL: -22, shoulderR: 18, elbowL: 12, elbowR: 12 }), 'R', 'kneeR'), 'L+R', { move: 0.6 }),
    kf(splitFit(88, 92, -12, { spine: 6, ...splitArms }), 'L+Rtoe', { hold: 0.2, move: 0.4 }),
    kf(P({ ...splitArms, spine: 6, hipL: 46, kneeL: 44, ankleL: 20, hipR: -4, kneeR: 104, ankleR: -30 }), 'L', { move: 0.35 }),
    kf(P({ ...splitArms, hipL: 4, kneeL: 4, hipR: 42, kneeR: 72, ankleR: 4, shoulderL: 16, shoulderR: -20 }), 'L', { move: 0.35 }),
    kf(P(splitArms), 'feet', { hold: 0.15 }),
  ],
});
def('step-up', 'Step-up', {
  fixture: { kind: 'box', from: 10, to: 56, top: 30 },
  thumb: 1,
  keyframes: [
    kf(P({ hipL: 72, kneeL: 96, ankleL: 20, spine: 10, ...splitArms }), 'R', { hold: 0.3, move: 0.9 }),
    kf(P({ hipL: 4, kneeL: 4, hipR: 60, kneeR: 90, ankleR: -10, ...splitArms }), 'L', { surface: 30, hold: 0.25, move: 0.9 }),
    kf(P({ hipL: 72, kneeL: 96, ankleL: 20, spine: 10, ...splitArms }), 'R', { hold: 0.1 }),
  ],
});
def('step-down', 'Eccentric step-down', {
  view: 'three-quarter', fixture: { kind: 'box', from: -24, to: 16, top: 30 },
  keyframes: rep3(
    P({ hipR: 14, kneeR: 2, ankleR: 4, shoulderL: 50, shoulderR: 50, elbowL: 10, elbowR: 10 }),
    P({ hipL: 64, kneeL: 84, ankleL: 30, hipR: 40, kneeR: 0, ankleR: -10, spine: 26, shoulderL: 70, shoulderR: 70, elbowL: 10, elbowR: 10 }),
    { contact: 'L', down: 1.2, upT: 0.9 }).map((k) => ({ ...k, surface: 30 })),
});
def('lateral-lunge', 'Lateral lunge', {
  view: 'front',
  keyframes: rep3(
    P(both({ hipAbd: 14, shoulder: 10 })),
    solve(P({ hipL: 84, kneeL: 100, ankleL: 30, hipAbdL: 30, hipRotL: -12, hipR: 6, kneeR: 0, spine: 34, neck: -20,
      shoulderL: 84, shoulderR: 84, elbowL: 20, elbowR: 20 }), 'hipAbdR', (sk) => sk.R.ankle[1] - sk.L.ankle[1], 0, 85),
    { contact: 'feet' }),
});

// Hinges ---------------------------------------------------------------
const midfootX = (sk) => (sk.L.ankle[0] + sk.R.ankle[0]) / 2 + 4;
/** Straight arms holding a bar that stays over mid-foot (a vertical bar path). */
const barOverMidfoot = (p, w = 21) => {
  const tgt = (sgn) => (sk) => {
    const sh = sk[sgn > 0 ? 'L' : 'R'].shoulder;
    const x = midfootX(sk), dz = sgn * w - sh[2];
    const reachLen = ARM - 0.8;
    const dx = sh[0] - x;
    const dy = Math.sqrt(Math.max(1, reachLen * reachLen - dx * dx - dz * dz));
    return [x, sh[1] - dy, sgn * w];
  };
  return reachBoth(p, tgt(1), tgt(-1));
};
const barAtFloorTargets = barAtFloor();
/** Deadlift start: trunk at `lean`, hips lowered until straight arms reach the bar on the floor. */
const dlStart = (lean) => {
  const base = (k) => P(both({ knee: k, hip: lean + k * 0.62, ankle: k * 0.36, hipAbd: 8 }), { spine: lean, neck: -28 });
  let k = solve(base(60), 'kneeL', (sk) => {
    const q = base(sk.L.knee ? 0 : 0);
    return 0;
  }, 0, 1).kneeL;
  // 1D search on knee bend: distance shoulder → floor bar = straight arm.
  let lo = 20, hi = 120;
  const gap = (kn) => {
    const sk = skeleton(base(kn));
    const t = barAtFloorTargets[0](sk);
    return Math.hypot(t[0] - sk.L.shoulder[0], t[1] - sk.L.shoulder[1], t[2] - sk.L.shoulder[2]) - (ARM - 0.8);
  };
  for (let i = 0; i < 40; i++) { const m = (lo + hi) / 2; if (gap(m) > 0) lo = m; else hi = m; }
  k = (lo + hi) / 2;
  return reachBoth(base(k), ...barAtFloorTargets);
};
const dlSetup = dlStart(58);
const dlTop = barOverMidfoot(P(both({ hipAbd: 8 }), { neck: 0 }));
const dlKnee = barOverMidfoot(P(both({ hip: 52, knee: 22, ankle: 8, hipAbd: 8 }), { spine: 44, neck: -20 }));
def('deadlift', 'Deadlift', {
  view: 'side', implement: { kind: 'barbell', at: 'hands' }, thumb: 0,
  keyframes: [
    ...tween(kf(dlSetup, 'feet', { hold: 0.45, move: 0.6 }), kf(dlKnee, 'feet'), 1, barOverMidfoot),
    ...tween(kf(dlKnee, 'feet', { move: 0.6 }), kf(dlTop, 'feet'), 1, barOverMidfoot),
    kf(dlTop, 'feet', { hold: 0.35, move: 1.0 }),
    kf(dlSetup, 'feet', { hold: 0.2 }),
  ],
});
const rdlTop = barOverMidfoot(P(both({ knee: 8, hipAbd: 6 })));
const rdlLow = barOverMidfoot(P(both({ hip: 82, knee: 20, ankle: 8, hipAbd: 6 }), { spine: 72, neck: -30 }));
def('rdl', 'Romanian deadlift', {
  implement: { kind: 'barbell', at: 'hands' },
  keyframes: [
    ...tween(kf(rdlTop, 'feet', { hold: 0.3, move: 1.1 }), kf(rdlLow, 'feet'), 2, barOverMidfoot),
    ...tween(kf(rdlLow, 'feet', { hold: 0.15, move: 0.9 }), kf(rdlTop, 'feet'), 2, barOverMidfoot),
    kf(rdlTop, 'feet', { hold: 0.1 }),
  ],
});
const rowHinge = { ...both({ hip: 78, knee: 22, ankle: 10, hipAbd: 6 }), spine: 64, neck: -26 };
const rowHang = barOverMidfoot(P(rowHinge));
const rowTop = reachBoth(P(rowHinge), (sk) => add(add(add(sk.pelvis, up(sk), 22), fwd(sk), 11), lat(sk), 22),
  (sk) => add(add(add(sk.pelvis, up(sk), 22), fwd(sk), 11), lat(sk), -22), { rot: ROTS, prefer: (sk, sd) => sk[sd].elbow[1] * -1 });
def('bent-over-row', 'Barbell bent-over row', {
  view: 'three-quarter', implement: { kind: 'barbell', at: 'hands' },
  keyframes: rep3(rowHang, rowTop, { down: 0.7, upT: 0.9, holdTop: 0.25 }),
});
const slHinge = (lean, backHip, knee = 14) => P({ spine: lean, neck: -24, hipL: lean + 6, kneeL: knee, ankleL: 8,
  hipR: -(90 - lean) * 0.2 + backHip, kneeR: 6, ankleR: 10, shoulderL: lean, shoulderR: lean, elbowL: 4, elbowR: 4 });
def('single-leg-rdl', 'Single-leg Romanian deadlift', {
  implement: { kind: 'dumbbell', at: 'R' },
  keyframes: rep3(slHinge(4, 10, 8), P({ spine: 82, neck: -30, hipL: 84, kneeL: 18, ankleL: 12, hipR: -4, kneeR: 4, ankleR: 10,
    shoulderL: 82, shoulderR: 82, elbowL: 4, elbowR: 4 }), { contact: 'L', down: 1.2, upT: 1.0 }),
});
const bell = { kind: 'kettlebell', at: 'hands' };
const swingHike = reachBoth(P(both({ hip: 88, knee: 34, ankle: 16, hipAbd: 16, hipRot: -10 }), { spine: 66, neck: -34 }),
  (sk) => add(add(sk.pelvis, [0, -18, 0]), [-8, 0, 3]), (sk) => add(add(sk.pelvis, [0, -18, 0]), [-8, 0, -3]));
const swingFloat = P(both({ hipAbd: 14, knee: 4, shoulder: 92, shoulderAbd: 4, elbow: 2 }), { spine: -4 });
def('kettlebell-swing', 'Kettlebell swing', {
  view: 'side', implement: bell, loop: true, thumb: 1,
  keyframes: [kf(swingHike, 'feet', { hold: 0.05, move: 0.55 }), kf(swingFloat, 'feet', { hold: 0.12, move: 0.55 })],
});
/** Solves the trunk so the upper back rests at `height` above the floor (bench or floor). */
const upperBack = (sk) => add(add(sk.pelvis, up(sk), 32), fwd(sk), -9.5);
const backAt = (p, height, lo = -100, hi = -20) => solve(p, 'spine', (sk) => upperBack(sk)[1] - floorY(sk) - height, lo, hi);
const BENCH = 34;
const hipsBar = [(sk) => add(add(sk.pelvis, fwd(sk), 12), lat(sk), 24), (sk) => add(add(sk.pelvis, fwd(sk), 12), lat(sk), -24)];
const thrustPose = (hip, knee) => reachBoth(backAt(P(both({ hip, knee, ankle: 4, hipAbd: 10 })), BENCH), ...hipsBar);
const thrustBottom = thrustPose(88, 72);
const thrustTop = thrustPose(0, 92);
def('hip-thrust', 'Barbell hip thrust', {
  view: 'three-quarter', implement: { kind: 'barbell', at: 'hips' },
  fixture: { kind: 'bench', from: -64, to: -28, top: BENCH },
  keyframes: [
    ...tween(kf(thrustBottom, 'feet', { hold: 0.3, move: 0.8 }), kf(thrustTop, 'feet'), 2, (q) => reachBoth(backAt(q, BENCH), ...hipsBar)),
    ...tween(kf(thrustTop, 'feet', { hold: 0.35, move: 0.8 }), kf(thrustBottom, 'feet'), 2, (q) => reachBoth(backAt(q, BENCH), ...hipsBar)),
    kf(thrustBottom, 'feet', { hold: 0.1 }),
  ],
  thumb: 3,
});
const bridgeArms = both({ shoulder: 12, shoulderAbd: 18, elbow: 2 });
const pelvisBack = (sk) => add(sk.pelvis, fwd(sk), -9.5);
const lieFlat = (p) => {
  let q = { ...p };
  for (let i = 0; i < 6; i++) {
    q = backAt(q, 0, -100, -60);
    const knee = solve(q, 'kneeL', (sk) => pelvisBack(sk)[1] - floorY(sk), 60, 150).kneeL;
    q = { ...q, kneeL: knee, kneeR: q.hipR === q.hipL ? knee : q.kneeR };
  }
  return q;
};
const bridgeDown = lieFlat(P(both({ hip: 60, knee: 104, ankle: 10, hipAbd: 8 }), bridgeArms));
const bridgeUp = backAt(P(both({ hip: 2, knee: 96, ankle: 10, hipAbd: 8 }), bridgeArms), 0);
def('glute-bridge', 'Glute bridge', {
  keyframes: [
    ...tween(kf(bridgeDown, 'feet', { hold: 0.3, move: 0.8 }), kf(bridgeUp, 'feet'), 2, (q) => backAt(q, 0)),
    ...tween(kf(bridgeUp, 'feet', { hold: 0.4, move: 0.8 }), kf(bridgeDown, 'feet'), 2, (q) => backAt(q, 0)),
    kf(bridgeDown, 'feet', { hold: 0.1 }),
  ],
  thumb: 3,
});
const slbDown = lieFlat(P({ hipL: 60, kneeL: 104, ankleL: 10, hipR: 60, kneeR: 0, ankleR: 10, ...bridgeArms }));
const slbUp = backAt(P({ hipL: 2, kneeL: 96, ankleL: 10, hipR: 34, kneeR: 0, ankleR: 10, ...bridgeArms }), 0);
def('single-leg-glute-bridge', 'Single-leg glute bridge', {
  keyframes: [
    ...tween(kf(slbDown, 'L', { hold: 0.3, move: 0.8 }), kf(slbUp, 'L'), 2, (q) => backAt(q, 0)),
    ...tween(kf(slbUp, 'L', { hold: 0.4, move: 0.8 }), kf(slbDown, 'L'), 2, (q) => backAt(q, 0)),
    kf(slbDown, 'L', { hold: 0.1 }),
  ],
  thumb: 3,
});
/** Kneeling (shins flat behind), body straight from knee to head, leaning by `lean`. */
const kneelLean = (lean, arms) => P(both({ hip: 0, knee: 90 - lean, ankle: -88 }), { spine: lean, neck: lean > 30 ? -20 : 0 }, arms);
const crossArms = both({ shoulder: 40, shoulderAbd: -20, elbow: 130 });
def('nordic-curl', 'Nordic hamstring curl', {
  thumb: 1,
  keyframes: [
    kf(kneelLean(0, crossArms), 'knees', { hold: 0.35, move: 2.0 }),
    kf(reachBoth(kneelLean(60, both({ wrist: -40 })), (sk) => [sk.L.shoulder[0] + 12, Math.min(sk.L.knee[1], sk.R.knee[1]) + 10, 16],
      (sk) => [sk.L.shoulder[0] + 12, Math.min(sk.L.knee[1], sk.R.knee[1]) + 10, -16]), 'knees', { hold: 0.1, move: 0.5 }),
    kf(flatHands(reachBoth(kneelLean(74, {}), (sk) => [sk.L.shoulder[0] + 4, Math.min(sk.L.knee[1], sk.R.knee[1]) - 5.2 + 2.9, 16],
      (sk) => [sk.L.shoulder[0] + 4, Math.min(sk.L.knee[1], sk.R.knee[1]) - 5.2 + 2.9, -16])), 'knees+hands', { hold: 0.2, move: 0.5 }),
    kf(reachBoth(kneelLean(52, both({ wrist: -30 })), (sk) => [sk.L.shoulder[0] + 10, Math.min(sk.L.knee[1], sk.R.knee[1]) + 14, 16],
      (sk) => [sk.L.shoulder[0] + 10, Math.min(sk.L.knee[1], sk.R.knee[1]) + 14, -16]), 'knees', { move: 0.6 }),
    kf(kneelLean(0, crossArms), 'knees', { hold: 0.1 }),
  ],
});
def('reverse-nordic', 'Reverse Nordic', {
  keyframes: rep3(kneelLean(0, crossArms), kneelLean(-40, crossArms), { contact: 'knees', down: 1.4, upT: 1.1 }),
});
const proneLegs = (knee) => P(both({ knee, ankle: 0, shoulder: 150, shoulderAbd: 30, elbow: 90 }), { spine: 90, neck: -20 });
def('prone-leg-curl', 'Lying leg curl', {
  fixture: { kind: 'bench', from: -2, to: 62, top: 34 },
  keyframes: rep3(proneLegs(4), proneLegs(118), { contact: 'front', down: 0.9, upT: 1.1 }).map((k) => ({ ...k, surface: 34 })),
});
/** Supine bridge: heels and upper back on the floor, pelvis lifted to `lift`. */
const slider = (knee, lift) => {
  const base = (hip) => {
    let q = P(both({ hip, knee, ankle: 16, shoulder: 12, shoulderAbd: 20 }), { spine: -80, neck: 14 });
    return solve(q, 'spine', (sk) => upperBack(sk)[1] - sk.L.heel[1], -110, -30);
  };
  let lo = -40, hi = 80;
  const f = (h) => { const sk = skeleton(base(h)); return (sk.pelvis[1] - 9.5) - sk.L.heel[1] - lift; };
  // Pelvis height changes monotonically with hip flexion here; bisect.
  const flo = f(lo);
  for (let i = 0; i < 40; i++) { const m = (lo + hi) / 2; if (Math.sign(f(m)) === Math.sign(flo)) lo = m; else hi = m; }
  return base((lo + hi) / 2);
};
def('hamstring-slider-curl', 'Hamstring slider curl', {
  thumb: 1,
  keyframes: [
    kf(slider(14, 16), 'Lheel+Rheel', { hold: 0.3, move: 1.1 }),
    kf(slider(100, 24), 'Lheel+Rheel', { hold: 0.2, move: 1.2 }),
    kf(slider(14, 16), 'Lheel+Rheel', { hold: 0.1 }),
  ],
});
def('back-extension', 'Back extension', {
  fixture: { kind: 'bench', from: -6, to: 18, below: -8 },
  keyframes: rep3(P(both({ ankle: 0, shoulder: 40, shoulderAbd: -20, elbow: 130 }), { spine: 45 }),
    P(both({ hip: 80, ankle: 0, shoulder: 40, shoulderAbd: -20, elbow: 130 }), { spine: 125, neck: 10 }), { down: 1.0, upT: 1.0 })
    .map((k) => ({ ...k, pose: { ...k.pose, hipL: k.pose.spine === 45 ? 0 : 80, hipR: k.pose.spine === 45 ? 0 : 80 } })),
});
const tipToes = P(both({ ankle: -36 }));
def('calf-raise', 'Standing calf raise', {
  view: 'three-quarter', thumb: 1,
  keyframes: [kf(P(), 'feet', { hold: 0.25, move: 0.6 }), kf(tipToes, 'Ltoe+Rtoe', { hold: 0.35, move: 0.8 }), kf(P(), 'feet', { hold: 0.1 })],
});
const seatedArms = both({ shoulder: 38, elbow: 52, shoulderAbd: 8 });
const seatFlat = P(both({ hip: 90, knee: 90 }), seatedArms, { spine: 8 });
/** Heels up with the seat unmoved: hips flex back until the toes stay where the soles were. */
const seatTiptoe = solve(P(both({ hip: 90, knee: 90, ankle: -34 }), seatedArms, { spine: 8 }), 'hipL',
  (sk) => sk.L.toe[1] - skeleton(seatFlat).L.ankle[1], 60, 100);
seatTiptoe.hipR = seatTiptoe.hipL;
def('seated-calf-raise', 'Seated calf raise', {
  fixture: { kind: 'bench', from: -16, to: 14, below: -10 },
  keyframes: [kf(seatFlat, 'seat', { hold: 0.25, move: 0.7 }), kf(seatTiptoe, 'seat', { hold: 0.3, move: 0.8 }), kf(seatFlat, 'seat', { hold: 0.1 })],
});
const wallLean = (ankle) => P(both({ ankle, shoulder: 0, elbow: 6 }), { spine: -14 });
def('tibialis-raise', 'Tibialis wall raise', {
  fixture: { kind: 'wall', at: -12 }, thumb: 1,
  keyframes: [kf(wallLean(14), 'feet', { hold: 0.2, move: 0.6 }), kf(wallLean(44), 'Lheel+Rheel', { hold: 0.3, move: 0.7 }), kf(wallLean(14), 'feet', { hold: 0.1 })],
});

// Upper body: pressing -----------------------------------------------
/** Tilts the trunk so the hands are `h` above the toes (push-up family). */
const handsAbove = (p, h, lo = 20, hi = 160) => solve(p, 'spine', (sk) => Math.min(sk.L.wrist[1] - 2.7, sk.L.handTip[1] - 1.5) - sk.L.toe[1] - h, lo, hi);
const plankArms = (sh, el) => both({ shoulder: sh, elbow: el, shoulderAbd: 12 + el * 0.2, ankle: 30, wrist: -85 });
const inclineTop = handsAbove(P(plankArms(84, 0), { neck: -10 }), 34, 20, 90);
const inclineLow = handsAbove(P(plankArms(28, 88), { neck: -10 }), 34, 20, 90);
def('incline-push-up', 'Incline push-up', {
  fixture: { kind: 'box', under: 'hands', width: 30, top: 34 },
  keyframes: rep3(inclineTop, inclineLow, { contact: 'Ltoe+Rtoe', down: 0.8, upT: 0.7 }),
});
const plyoAir = handsAbove(P(plankArms(92, 0), { neck: -12 }), 10, 20, 95);
def('plyo-push-up', 'Plyometric push-up', {
  thumb: 3,
  keyframes: [
    kf(pushTop, 'hands+Ltoe+Rtoe', { hold: 0.2, move: 0.55 }),
    kf(pushBottom, 'hands+Ltoe+Rtoe', { hold: 0.05, move: 0.1, chain: [0, 2] }),
    kf(handsAbove(P(plankArms(60, 40), { neck: -12 }), 0.5, 20, 95), 'Ltoe+Rtoe', { move: 0.12, chain: [1, 2] }),
    kf(plyoAir, 'Ltoe+Rtoe', { hold: 0.05, move: 0.12, chain: [0, 2] }),
    kf(handsAbove(P(plankArms(80, 14), { neck: -12 }), 2, 20, 95), 'Ltoe+Rtoe', { move: 0.13, chain: [1, 2] }),
    kf(pushTop, 'hands+Ltoe+Rtoe', { hold: 0.2 }),
  ],
});
const pikeTop = handsAbove(P(both({ shoulder: 168, elbow: 0, shoulderAbd: 12, hip: 96, ankle: 24, wrist: -85 }), { neck: 10 }), 0, 100, 175);
const pikeLow = handsAbove(P(both({ shoulder: 120, elbow: 96, shoulderAbd: 26, hip: 104, ankle: 24, wrist: -85 }), { neck: 14 }), 0, 100, 175);
def('pike-push-up', 'Pike push-up', {
  keyframes: rep3(pikeTop, pikeLow, { contact: 'hands+Ltoe+Rtoe', down: 0.9, upT: 0.8 }),
});
const dbBenchTop = P(benchLegs, both({ shoulder: 90, shoulderAbd: 16, elbow: 0 }), { spine: -90 });
const dbBenchLow = P(benchLegs, both({ shoulder: 14, shoulderAbd: 52, elbow: 90 }), { spine: -90 });
def('dumbbell-bench-press', 'Dumbbell bench press', {
  view: 'three-quarter', fixture: { kind: 'bench', from: -56, to: 12, below: -10 }, implement: { kind: 'dumbbells', at: 'hands' },
  keyframes: rep3(dbBenchTop, dbBenchLow, { down: 0.9, upT: 0.8 }),
});
const incLegs = both({ hip: 62, knee: 90, ankle: 6, hipAbd: 14 });
def('incline-dumbbell-press', 'Incline dumbbell press', {
  view: 'three-quarter', fixture: { kind: 'incline' }, implement: { kind: 'dumbbells', at: 'hands' },
  keyframes: rep3(P(incLegs, both({ shoulder: 128, shoulderAbd: 14, elbow: 0 }), { spine: -38 }),
    P(incLegs, both({ shoulder: 40, shoulderAbd: 56, elbow: 96 }), { spine: -38 }), { contact: 'seat', down: 0.9, upT: 0.8 }),
});
const floorLegs = both({ hip: 56, knee: 100, ankle: 8, hipAbd: 10 });
def('floor-press', 'Dumbbell floor press', {
  view: 'three-quarter', implement: { kind: 'dumbbells', at: 'hands' },
  keyframes: rep3(lieFlat(P(floorLegs, both({ shoulder: 90, shoulderAbd: 14, elbow: 0 }))),
    lieFlat(P(floorLegs, both({ shoulder: 8, shoulderAbd: 58, elbow: 92 }))), { down: 0.9, upT: 0.8 }),
});
const pressRack = rack(P(both({ hipAbd: 6 })));
const pressTop = P(both({ shoulder: 176, shoulderAbd: 18, elbow: 2, hipAbd: 6 }), { neck: -4 });
def('overhead-press', 'Overhead press', {
  view: 'three-quarter', implement: { kind: 'barbell', at: 'hands' },
  keyframes: rep3(pressRack, pressTop, { down: 0.8, upT: 0.8, holdTop: 0.3 }),
});
def('push-press', 'Push press', {
  view: 'three-quarter', implement: { kind: 'barbell', at: 'hands' }, thumb: 2,
  keyframes: [
    kf(pressRack, 'feet', { hold: 0.3, move: 0.35 }),
    kf(rack(P(both({ hip: 22, knee: 30, ankle: 16, hipAbd: 6 }), { spine: 2 })), 'feet', { move: 0.22 }),
    kf(P(both({ shoulder: 150, shoulderAbd: 18, elbow: 40, ankle: -20, hipAbd: 6 })), 'Ltoe+Rtoe', { move: 0.25 }),
    kf(pressTop, 'feet', { hold: 0.35, move: 0.7 }),
    kf(pressRack, 'feet', { hold: 0.1 }),
  ],
});
const halfKneel = solve(P({ hipL: 88, kneeL: 90, ankleL: 0, hipR: -10, kneeR: 100, ankleR: -88 }), 'hipL',
  (sk) => sk.L.ankle[1] - (sk.R.knee[1] - 5.2), 50, 110);
def('landmine-press', 'Half-kneeling landmine press', {
  view: 'three-quarter', implement: { kind: 'landmine', at: 'R' },
  keyframes: rep3(P(halfKneel, { shoulderR: 40, shoulderAbdR: 10, elbowR: 125, shoulderL: 10, elbowL: 20 }),
    P(halfKneel, { shoulderR: 132, shoulderAbdR: 4, elbowR: 6, shoulderL: 10, elbowL: 20, twist: 6 }), { contact: 'L+Rknee', down: 0.8, upT: 0.8 }),
});
/** Bench dip: heels on the floor, hands on a bench behind at 34. */
const dip = (elbow) => {
  let q = P(both({ hip: 88, knee: 8, ankle: 10, shoulder: -52 + elbow * 0.35, elbow, shoulderAbd: 10, wrist: -70 }));
  q = solve(q, 'spine', (sk) => (sk.L.wrist[1] - 2.7) - sk.L.heel[1] - 34, -25, 25);
  return q;
};
def('bench-dip', 'Bench dip', {
  fixture: { kind: 'bench', from: -34, to: 2, top: 34 },
  keyframes: rep3(dip(4), dip(88), { contact: 'Lheel+Rheel', down: 0.9, upT: 0.8 }),
});
const elbowsIn = { shoulderL: 8, shoulderR: 8, shoulderAbdL: 4, shoulderAbdR: 4 };
def('triceps-pressdown', 'Cable triceps pressdown', {
  view: 'three-quarter', implement: { kind: 'cable', at: 'hands', to: [26, 170, 0] },
  keyframes: rep3(P({ ...elbowsIn, elbowL: 100, elbowR: 100, spine: 8 }, both({ knee: 8 })), P({ ...elbowsIn, elbowL: 4, elbowR: 4, spine: 8 }, both({ knee: 8 })),
    { down: 0.7, upT: 0.8 }),
});

// Upper body: pulling -------------------------------------------------
const seatLegs = both({ hip: 90, knee: 90, hipAbd: 10 });
def('lat-pulldown', 'Lat pulldown', {
  view: 'three-quarter', fixture: { kind: 'bench', from: -16, to: 14, below: -10 }, implement: { kind: 'cable', at: 'hands', to: [4, 210, 0] },
  keyframes: rep3(P(seatLegs, both({ shoulder: 170, shoulderAbd: 34, elbow: 4 }), { spine: -8 }),
    P(seatLegs, both({ shoulder: 40, shoulderAbd: 62, elbow: 118 }), { spine: -14, neck: -6 }), { contact: 'seat', down: 0.8, upT: 1.0 }),
});
def('dead-hang', 'Dead hang', {
  view: 'three-quarter', fixture: { kind: 'bar' }, loop: true, thumb: 0,
  keyframes: [kf(barHang, 'grip', { hold: 1.0, move: 1.2, surface: 14 }), kf({ ...barHang, neck: -4, kneeL: 34, kneeR: 34 }, 'grip', { hold: 1.0, move: 1.2 })],
});
def('scapular-pull-up', 'Scapular pull-up', {
  view: 'three-quarter', fixture: { kind: 'bar' },
  keyframes: rep3(barHang, P(both({ shoulder: 160, shoulderAbd: 14, elbow: 2, hip: 8, knee: 30, ankle: -20 }), { spine: -6 }), { contact: 'grip', down: 0.6, upT: 0.7 })
    .map((k, i) => (i === 0 ? { ...k, surface: 14 } : k)),
});
def('hanging-knee-raise', 'Hanging knee raise', {
  view: 'side', fixture: { kind: 'bar' },
  keyframes: rep3(barHang, P(both({ shoulder: 172, shoulderAbd: 18, elbow: 4, hip: 104, knee: 100, ankle: -10 }), { spine: -8 }), { contact: 'grip', down: 0.8, upT: 0.9 })
    .map((k, i) => (i === 0 ? { ...k, surface: 14 } : k)),
});
/** Inverted row under a bar 92 above the floor, 118 in front of the heels. */
const rowBar = (sk, sgn) => [sk.L.heel[0] + 118, sk.L.heel[1] + 92, sgn * 24];
const invRow = (chestToBar) => {
  const base = (sp) => P(both({ ankle: 22, shoulder: 90, shoulderAbd: 20 }), { spine: sp, neck: 0 });
  const gap = (sp) => {
    const sk = skeleton(base(sp));
    const chest = add(add(sk.pelvis, up(sk), 30), fwd(sk), 10);
    const bar = rowBar(sk, 1);
    return chestToBar ? chest[1] - (bar[1] - 5) : Math.hypot(bar[0] - sk.L.shoulder[0], bar[1] - sk.L.shoulder[1], bar[2] - sk.L.shoulder[2]) - (ARM - 1);
  };
  let lo = -95, hi = -30;
  const g0 = gap(lo);
  for (let i = 0; i < 40; i++) { const m = (lo + hi) / 2; if (Math.sign(gap(m)) === Math.sign(g0)) lo = m; else hi = m; }
  return reachBoth(base((lo + hi) / 2), (sk) => rowBar(sk, 1), (sk) => rowBar(sk, -1), { rot: ROTS, prefer: (sk, sd) => -sk[sd].elbow[1] });
};
def('inverted-row', 'Inverted row', {
  view: 'three-quarter', fixture: { kind: 'bar' },
  keyframes: rep3(invRow(false), invRow(true), { contact: 'Lheel+Rheel', down: 0.8, upT: 0.9 }),
});
/** One-arm dumbbell row: left knee and hand on a bench, right foot on the floor. */
const dbRow = (pulled) => {
  let q = P({ spine: 84, neck: -30, hipR: 84, kneeR: 8, ankleR: 8, hipL: 90, kneeL: 90, ankleL: -88, hipAbdR: 8 });
  q = reach(q, 'L', (sk) => [sk.L.shoulder[0] + 2, sk.R.ankle[1] + 34 + 2.7, sk.L.shoulder[2]]);
  q = flatHands(q);
  const R = pulled
    ? reach(q, 'R', (sk) => add(add(sk.pelvis, up(sk), 22), lat(sk), -16), { rot: ROTS, prefer: (sk) => -sk.R.elbow[1] })
    : reach(q, 'R', (sk) => [sk.R.shoulder[0], sk.R.shoulder[1] - ARM + 1, sk.R.shoulder[2]]);
  return R;
};
def('dumbbell-row', 'One-arm dumbbell row', {
  view: 'rear-three-quarter', fixture: { kind: 'bench', from: -48, to: 34, top: 34 }, implement: { kind: 'dumbbell', at: 'R' },
  keyframes: rep3(dbRow(false), dbRow(true), { contact: 'R', down: 0.7, upT: 0.9 }),
});
const cableSeat = both({ hip: 96, knee: 24, ankle: 18, hipAbd: 8 });
def('seated-cable-row', 'Seated cable row', {
  view: 'side', fixture: { kind: 'bench', from: -20, to: 30, below: -10 }, implement: { kind: 'cable', at: 'hands', to: [70, 40, 0] },
  keyframes: rep3(P(cableSeat, both({ shoulder: 84, shoulderAbd: 6, elbow: 2 }), { spine: 12 }),
    reachBoth(P(cableSeat, { spine: -4 }), (sk) => add(add(sk.pelvis, up(sk), 20), fwd(sk), 11), (sk) => add(add(sk.pelvis, up(sk), 20), fwd(sk), 11),
      { rot: ROTS, prefer: (sk, sd) => sk[sd].elbow[0] }), { contact: 'seat', down: 0.8, upT: 1.0 }),
});
def('face-pull', 'Face pull', {
  view: 'three-quarter', implement: { kind: 'cable', at: 'hands', to: [90, 150, 0] },
  keyframes: rep3(P(both({ shoulder: 96, shoulderAbd: 6, elbow: 2, knee: 6 }), { spine: -4 }),
    P(both({ shoulder: 90, shoulderAbd: 84, shoulderRot: -70, elbow: 94, knee: 6 }), { spine: -6 }), { down: 0.7, upT: 0.9 }),
});
def('band-pull-apart', 'Band pull-apart', {
  view: 'front', implement: { kind: 'band', at: 'hands' },
  keyframes: rep3(P(both({ shoulder: 90, shoulderAbd: 4, elbow: 0 })), P(both({ shoulder: 90, shoulderAbd: 86, elbow: 0 })), { down: 0.7, upT: 0.8 }),
});
const flyHinge = { ...both({ hip: 72, knee: 22, ankle: 10, hipAbd: 6 }), spine: 62, neck: -26 };
def('reverse-fly', 'Bent-over reverse fly', {
  view: 'three-quarter', implement: { kind: 'dumbbells', at: 'hands' },
  keyframes: rep3(P(flyHinge, both({ shoulder: 62, shoulderAbd: 4, elbow: 14 })), P(flyHinge, both({ shoulder: 62, shoulderAbd: 84, elbow: 14 })), { down: 0.7, upT: 0.8 }),
});
def('band-external-rotation', 'Band external rotation', {
  view: 'front', implement: { kind: 'band', at: 'L', to: [10, 108, -40] },
  keyframes: rep3(P({ shoulderL: 4, shoulderAbdL: 8, elbowL: 90, shoulderRotL: 30 }), P({ shoulderL: 4, shoulderAbdL: 8, elbowL: 90, shoulderRotL: -70 }), { down: 0.7, upT: 0.8 }),
});
const proneBase = { spine: 90, neck: -14, ...both({ ankle: -80 }) };
def('prone-ytw', 'Prone Y-T-W raise', {
  view: 'three-quarter', thumb: 1,
  keyframes: [
    kf(P(proneBase, both({ shoulder: 160, shoulderAbd: 30, elbow: 0 })), 'front', { hold: 0.2, move: 0.6 }),
    kf(P(proneBase, both({ shoulder: 172, shoulderAbd: 40, elbow: 0 }), { neck: -24 }), 'front', { hold: 0.3, move: 0.7 }),
    kf(P(proneBase, both({ shoulder: 90, shoulderAbd: 90, elbow: 0 }), { neck: -24 }), 'front', { hold: 0.3, move: 0.7 }),
    kf(P(proneBase, both({ shoulder: 46, shoulderAbd: 60, elbow: 92 }), { neck: -24 }), 'front', { hold: 0.3, move: 0.7 }),
    kf(P(proneBase, both({ shoulder: 160, shoulderAbd: 30, elbow: 0 })), 'front', { hold: 0.1 }),
  ],
});
def('biceps-curl', 'Dumbbell curl', {
  view: 'three-quarter', implement: { kind: 'dumbbells', at: 'hands' },
  keyframes: rep3(P(both({ shoulder: 2, shoulderAbd: 8, elbow: 6, shoulderRot: -20 })), P(both({ shoulder: 16, shoulderAbd: 8, elbow: 138, shoulderRot: -20 })), { down: 0.8, upT: 0.9 }),
});
const rollerArms = both({ shoulder: 88, shoulderAbd: 12, elbow: 2 });
def('wrist-roller', 'Wrist roller', {
  view: 'three-quarter', implement: { kind: 'wristroller', at: 'hands' }, loop: true, thumb: 0,
  keyframes: [kf(P(rollerArms, { wristL: 40, wristR: -40 }), 'feet', { move: 0.45 }), kf(P(rollerArms, { wristL: -40, wristR: 40 }), 'feet', { move: 0.45 })],
});
const wcSeat = both({ hip: 90, knee: 90, hipAbd: 12 });
const wcArms = (w) => reachBoth(P(wcSeat, { spine: 30, neck: -20 }), (sk) => add(sk.L.knee, [2, 7, -2]), (sk) => add(sk.R.knee, [2, 7, 2]));
def('wrist-curl', 'Seated wrist curl', {
  fixture: { kind: 'bench', from: -16, to: 14, below: -10 }, implement: { kind: 'dumbbells', at: 'hands' },
  keyframes: rep3({ ...wcArms(), wristL: -50, wristR: -50 }, { ...wcArms(), wristL: 60, wristR: 60 }, { contact: 'seat', down: 0.6, upT: 0.7 }),
});

// Gait ---------------------------------------------------------------
const mirror = (p) => {
  const out = {};
  for (const [k, v] of Object.entries(p)) {
    const o = k.endsWith('L') ? `${k.slice(0, -1)}R` : k.endsWith('R') ? `${k.slice(0, -1)}L` : k;
    out[o] = v;
  }
  return out;
};
/**
 * A treadmill-style gait loop: four phases for the left stride, mirrored for
 * the right. The pelvis stays put and the stance foot rolls back under it,
 * always on the floor ('air' contact → lowest point on the ground).
 */
const gait = (phases, { lean = 0, neck = 0, move = 0.1, extra = {} } = {}) => {
  const left = phases.map((ph) => P({ spine: lean, neck, ...extra, ...ph }));
  const frames = [...left, ...left.map(mirror)];
  return frames.map((p) => kf(p, 'air', { move }));
};
const armsSwing = (fwdL, backR, elbow) => ({ shoulderL: fwdL, shoulderR: backR, elbowL: elbow, elbowR: elbow, shoulderAbdL: 8, shoulderAbdR: 8 });

def('sprint', 'Sprinting', {
  path: { kind: 'line', length: 460 },
  loop: true, thumb: 0,
  keyframes: gait([
    { hipL: 36, kneeL: 18, ankleL: 2, hipR: -12, kneeR: 96, ankleR: -24, ...armsSwing(-40, 60, 92), lift: 0 },
    { hipL: 8, kneeL: 40, ankleL: 22, hipR: 46, kneeR: 122, ankleR: 0, ...armsSwing(-10, 30, 92) },
    { hipL: -26, kneeL: 22, ankleL: -32, hipR: 84, kneeR: 96, ankleR: 8, ...armsSwing(45, -40, 88), lift: 4 },
    { hipL: -14, kneeL: 84, ankleL: -18, hipR: 58, kneeR: 40, ankleR: 4, ...armsSwing(30, -30, 90), lift: 9 },
  ], { lean: 12, neck: -6, move: 0.085 }),
});
def('jog', 'Easy run', {
  path: { kind: 'line', length: 380 },
  loop: true, thumb: 0,
  keyframes: gait([
    { hipL: 26, kneeL: 14, ankleL: 4, hipR: -10, kneeR: 70, ankleR: -20, ...armsSwing(-26, 34, 86) },
    { hipL: 4, kneeL: 32, ankleL: 18, hipR: 30, kneeR: 88, ankleR: 0, ...armsSwing(-6, 16, 86) },
    { hipL: -20, kneeL: 16, ankleL: -26, hipR: 50, kneeR: 64, ankleR: 6, ...armsSwing(28, -24, 84), lift: 2 },
    { hipL: -10, kneeL: 56, ankleL: -14, hipR: 36, kneeR: 28, ankleR: 4, ...armsSwing(18, -16, 86), lift: 4 },
  ], { lean: 6, neck: -2, move: 0.13 }),
});
def('walk', 'Walking', {
  path: { kind: 'line', length: 300, speed: 110 },
  loop: true, thumb: 0,
  keyframes: gait([
    { hipL: 24, kneeL: 2, ankleL: 10, hipR: -14, kneeR: 14, ankleR: -22, ...armsSwing(-16, 18, 12) },
    { hipL: 4, kneeL: 8, ankleL: 4, hipR: 16, kneeR: 52, ankleR: 0, ...armsSwing(0, 2, 12) },
    { hipL: -16, kneeL: 4, ankleL: -8, hipR: 26, kneeR: 8, ankleR: 8, ...armsSwing(16, -14, 12) },
    { hipL: -12, kneeL: 30, ankleL: -24, hipR: 24, kneeR: 2, ankleR: 10, ...armsSwing(14, -14, 12) },
  ], { lean: 2, move: 0.17 }),
});
def('march', 'Marching', {
  path: { kind: 'line', length: 240, speed: 70 },
  loop: true, thumb: 1,
  keyframes: gait([
    { hipL: 0, kneeL: 2, hipR: 0, kneeR: 4, ...armsSwing(0, 0, 10) },
    { hipL: 0, kneeL: 2, hipR: 72, kneeR: 88, ankleR: -10, ...armsSwing(40, -30, 80) },
  ], { move: 0.28 }),
});
def('high-knees', 'High knees', {
  path: { kind: 'line', length: 220, speed: 60 },
  loop: true, thumb: 1,
  keyframes: gait([
    { hipL: 0, kneeL: 6, ankleL: -20, hipR: 40, kneeR: 60, ...armsSwing(-10, 20, 90) },
    { hipL: -4, kneeL: 4, ankleL: -30, hipR: 92, kneeR: 96, ankleR: -10, ...armsSwing(50, -40, 90), lift: 3 },
  ], { lean: 2, move: 0.12 }),
});
def('a-skip', 'A-skip', {
  path: { kind: 'line', length: 300, speed: 95 },
  loop: true, thumb: 1,
  keyframes: gait([
    { hipL: 0, kneeL: 8, ankleL: 0, hipR: 30, kneeR: 50, ...armsSwing(-10, 20, 90) },
    { hipL: -6, kneeL: 4, ankleL: -34, hipR: 90, kneeR: 100, ankleR: 10, ...armsSwing(55, -45, 90), lift: 5 },
    { hipL: 0, kneeL: 10, ankleL: 0, hipR: 20, kneeR: 30, ankleR: 0, ...armsSwing(10, -10, 90), lift: 1 },
  ], { lean: 3, move: 0.15 }),
});
def('b-skip', 'B-skip', {
  path: { kind: 'line', length: 300, speed: 95 },
  loop: true, thumb: 2,
  keyframes: gait([
    { hipL: 0, kneeL: 8, ankleL: 0, hipR: 30, kneeR: 50, ...armsSwing(-10, 20, 90) },
    { hipL: -6, kneeL: 4, ankleL: -34, hipR: 88, kneeR: 100, ankleR: 10, ...armsSwing(55, -45, 90), lift: 5 },
    { hipL: -6, kneeL: 4, ankleL: -34, hipR: 80, kneeR: 10, ankleR: 10, ...armsSwing(40, -35, 90), lift: 4 },
    { hipL: 0, kneeL: 10, ankleL: 0, hipR: 16, kneeR: 12, ankleR: 0, ...armsSwing(0, 0, 90), lift: 0 },
  ], { lean: 3, move: 0.14 }),
});
def('backpedal', 'Backpedal', {
  path: { kind: 'line', length: 300, dir: 'back', speed: 130 },
  loop: true, thumb: 0,
  keyframes: gait([
    { hipL: 44, kneeL: 60, ankleL: 24, hipR: 64, kneeR: 90, ankleR: -10, ...armsSwing(-20, 30, 88) },
    { hipL: 36, kneeL: 48, ankleL: 18, hipR: 44, kneeR: 70, ankleR: -20, ...armsSwing(20, -20, 88), lift: 2 },
  ], { lean: 26, neck: -18, move: 0.14 }),
});

// Starts and changes of direction -------------------------------------------
def('acceleration-start', 'Acceleration start', {
  thumb: 1,
  keyframes: [
    kf(P({ spine: 30, neck: -14, hipL: 50, kneeL: 56, ankleL: 24, hipR: -4, kneeR: 40, ankleR: -30, ...armsSwing(-30, 40, 88) }), 'L+Rtoe', { hold: 0.35, move: 0.18 }),
    kf(P({ spine: 46, neck: -10, hipL: 8, kneeL: 10, ankleL: -32, hipR: 96, kneeR: 110, ankleR: 10, ...armsSwing(60, -50, 88) }), 'Ltoe', { move: 0.18 }),
    kf(P({ spine: 42, neck: -8, hipR: 20, kneeR: 30, ankleR: 20, hipL: 60, kneeL: 116, ankleL: -10, ...armsSwing(-40, 60, 88), lift: 3 }), 'air', { move: 0.18, travel: [34, 0] }),
    kf(P({ spine: 36, neck: -8, hipR: -8, kneeR: 12, ankleR: -30, hipL: 96, kneeL: 106, ankleL: 8, ...armsSwing(-50, 64, 88), lift: 2 }), 'Rtoe', { hold: 0.3, travel: [30, 0] }),
  ],
});
def('three-point-start', 'Three-point stance start', {
  thumb: 0,
  keyframes: [
    kf(flatHands(reach(toeDown(P({ spine: 76, neck: -18, hipL: 100, kneeL: 100, ankleL: 24, hipR: 64, kneeR: 104, shoulderL: -30, elbowL: 20 }), 'R'), 'R',
      (sk) => [sk.R.shoulder[0] + 4, sk.L.ankle[1] + 2.9, sk.R.shoulder[2]])), 'L+Rtoe', { hold: 0.5, move: 0.2 }),
    kf(P({ spine: 52, neck: -10, hipL: 12, kneeL: 12, ankleL: -30, hipR: 96, kneeR: 116, ankleR: 10, ...armsSwing(-40, 60, 88) }), 'Ltoe', { move: 0.2 }),
    kf(P({ spine: 44, neck: -8, hipR: -4, kneeR: 14, ankleR: -30, hipL: 94, kneeL: 104, ankleL: 8, ...armsSwing(60, -50, 88), lift: 2 }), 'Rtoe', { hold: 0.3, travel: [44, 0] }),
  ],
});
def('falling-start', 'Falling start', {
  thumb: 1,
  keyframes: [
    kf(P(both({ ankle: -4 }), { spine: 2 }), 'feet', { hold: 0.3, move: 0.5 }),
    kf(P({ spine: 20, hipL: -20, kneeL: 4, ankleL: -10, hipR: -20, kneeR: 4, ankleR: 10, ...armsSwing(0, 0, 10) }), 'Ltoe+Rtoe', { move: 0.2 }),
    kf(P({ spine: 40, neck: -10, hipL: 10, kneeL: 10, ankleL: -30, hipR: 94, kneeR: 110, ankleR: 10, ...armsSwing(60, -50, 88) }), 'Ltoe', { move: 0.2 }),
    kf(P({ spine: 40, neck: -8, hipR: -6, kneeR: 12, ankleR: -30, hipL: 94, kneeL: 104, ankleL: 8, ...armsSwing(-50, 64, 88), lift: 2 }), 'Rtoe', { hold: 0.3, travel: [42, 0] }),
  ],
});
def('deceleration-stop', 'Deceleration to a stop', {
  thumb: 2,
  keyframes: [
    kf(P({ spine: 12, neck: -6, hipL: 60, kneeL: 30, ankleL: 10, hipR: -20, kneeR: 80, ankleR: -24, ...armsSwing(-30, 40, 88), lift: 3 }), 'air', { move: 0.18 }),
    kf(clear(P({ spine: 4, hipL: 50, kneeL: 30, ankleL: 12, hipR: -10, kneeR: 50, ankleR: -30, ...armsSwing(30, -20, 80) }), 'L'), 'L', { move: 0.22, travel: [30, 0] }),
    kf(levelFeet(P({ spine: 24, neck: -14, hipL: 76, kneeL: 84, ankleL: 30, hipR: 36, kneeR: 66, ankleR: 20, ...armsSwing(40, 40, 70), hipAbdL: 10, hipAbdR: 10 }), 'R', 'hipR'), 'feet', { hold: 0.5 }),
  ],
});
def('cut-45', '45-degree cut', {
  view: 'three-quarter', thumb: 1,
  keyframes: [
    kf(P({ spine: 14, hipL: 40, kneeL: 30, ankleL: 10, hipR: -20, kneeR: 70, ankleR: -24, ...armsSwing(-30, 40, 88), lift: 3 }), 'air', { move: 0.16 }),
    kf(clear(P({ spine: 24, neck: -12, hipR: 50, kneeR: 56, ankleR: 22, hipAbdR: 30, hipL: 34, kneeL: 70, ankleL: -10, hipAbdL: 4, bend: 16, ...armsSwing(20, 30, 80), twist: -18 }), 'R'), 'R', { hold: 0.12, move: 0.2, travel: [28, 0] }),
    kf(P({ spine: 30, neck: -10, turn: 45, hipR: -10, kneeR: 14, ankleR: -30, hipL: 90, kneeL: 100, ankleL: 8, ...armsSwing(50, -40, 88), lift: 2 }), 'Rtoe', { hold: 0.3 }),
  ],
});
const stance = both({ hip: 44, knee: 54, ankle: 24, hipAbd: 20, hipRot: -4, shoulder: 30, elbow: 80, shoulderAbd: 14 });
def('lateral-shuffle', 'Lateral shuffle', {
  path: { kind: 'line', length: 240, dir: 'left', speed: 140 },
  view: 'front', loop: true, thumb: 0,
  keyframes: [
    kf(P(stance, { spine: 26, neck: -16 }), 'air', { move: 0.14, travel: [0, 0] }),
    kf(P(stance, { spine: 26, neck: -16, hipAbdL: 30, hipAbdR: 10, kneeR: 50, lift: 3 }), 'air', { move: 0.14 }),
  ],
});
def('crossover-run', 'Crossover run', {
  path: { kind: 'line', length: 300, dir: 'left', speed: 170 },
  view: 'front', loop: true, thumb: 1,
  keyframes: [
    kf(P(stance, { spine: 20, neck: -12, twist: 10 }), 'air', { move: 0.14 }),
    kf(P(stance, { spine: 20, neck: -12, hipR: 64, kneeR: 80, hipAbdR: -18, hipRotR: -20, twist: -24, turn: -20, lift: 3 }), 'air', { move: 0.14 }),
    kf(P(stance, { spine: 20, neck: -12, twist: 10 }), 'air', { move: 0.14 }),
    kf(P(stance, { spine: 20, neck: -12, hipL: 64, kneeL: 80, hipAbdL: -18, hipRotL: -20, twist: 24, turn: 20, lift: 3 }), 'air', { move: 0.14 }),
  ],
});
def('carioca', 'Carioca', {
  path: { kind: 'line', length: 260, dir: 'left', speed: 120 },
  view: 'front', loop: true, thumb: 1,
  keyframes: [
    kf(P(both({ hip: 16, knee: 20, ankle: 8, hipAbd: 14 }), { spine: 8, shoulderAbdL: 70, shoulderAbdR: 70, elbowL: 10, elbowR: 10 }), 'air', { move: 0.15 }),
    kf(P(both({ hip: 16, knee: 20, ankle: 8 }), { spine: 8, hipR: 40, kneeR: 50, hipAbdR: -20, hipRotR: -24, twist: -30, shoulderAbdL: 70, shoulderAbdR: 70, elbowL: 10, elbowR: 10, lift: 2 }), 'air', { move: 0.15 }),
    kf(P(both({ hip: 16, knee: 20, ankle: 8, hipAbd: 14 }), { spine: 8, shoulderAbdL: 70, shoulderAbdR: 70, elbowL: 10, elbowR: 10 }), 'air', { move: 0.15 }),
    kf(P(both({ hip: 16, knee: 20, ankle: 8 }), { spine: 8, hipR: -14, kneeR: 30, hipAbdR: -20, twist: 30, shoulderAbdL: 70, shoulderAbdR: 70, elbowL: 10, elbowR: 10, lift: 2 }), 'air', { move: 0.15 }),
  ],
});
def('lateral-band-walk', 'Lateral band walk', {
  path: { kind: 'line', length: 160, dir: 'left', speed: 32 },
  view: 'front', loop: true, thumb: 1,
  keyframes: [
    kf(P(both({ hip: 36, knee: 42, ankle: 20, hipAbd: 12, shoulder: 30, elbow: 70 }), { spine: 22 }), 'feet', { hold: 0.1, move: 0.4 }),
    kf(P(both({ hip: 36, knee: 42, ankle: 20, shoulder: 30, elbow: 70 }), { spine: 22, hipAbdL: 26, hipAbdR: 12, kneeL: 36 }), 'R', { hold: 0.1, move: 0.4 }),
  ],
});

// Jumps and landings -----------------------------------------------------
const loadArms = both({ shoulder: -46, elbow: 14, shoulderAbd: 8 });
const reachArms = both({ shoulder: 170, elbow: 4, shoulderAbd: 14 });
const jumpLoad = P(both({ hip: 84, knee: 92, ankle: 32, hipAbd: 8 }), loadArms, { spine: 40, neck: -22 });
const takeoff = P(both({ ankle: -34, hipAbd: 6 }), reachArms, { spine: 2 });
const landSoft = P(both({ hip: 70, knee: 80, ankle: 30, hipAbd: 8, shoulder: 50, elbow: 30 }), { spine: 32, neck: -16 });
def('vertical-jump', 'Countermovement jump', {
  view: 'three-quarter', thumb: 3,
  keyframes: [
    kf(P(both({ hipAbd: 6 })), 'feet', { hold: 0.3, move: 0.45 }),
    kf(jumpLoad, 'feet', { hold: 0.05, move: 0.18 }),
    kf(takeoff, 'Ltoe+Rtoe', { move: 0.2 }),
    kf(P(both({ ankle: -30, knee: 10, hipAbd: 6 }), reachArms, { lift: 30 }), 'air', { hold: 0.08, move: 0.26 }),
    kf(landSoft, 'feet', { hold: 0.35, move: 0.5 }),
    kf(P(both({ hipAbd: 6 })), 'feet', { hold: 0.1 }),
  ],
});
def('tuck-jump', 'Tuck jump', {
  view: 'side', thumb: 3,
  keyframes: [
    kf(P(both({ hip: 40, knee: 46, ankle: 20, shoulder: -30, elbow: 20 }), { spine: 20 }), 'feet', { hold: 0.15, move: 0.18 }),
    kf(takeoff, 'Ltoe+Rtoe', { move: 0.15 }),
    kf(P(both({ ankle: -20, knee: 10 }), both({ shoulder: 60, elbow: 60 }), { lift: 18 }), 'air', { move: 0.13 }),
    kf(P(both({ hip: 120, knee: 130, ankle: -20, shoulder: 70, elbow: 70 }), { spine: 8, lift: 30 }), 'air', { move: 0.2 }),
    kf(landSoft, 'feet', { hold: 0.3, move: 0.3 }),
    kf(P(both({ hip: 40, knee: 46, ankle: 20, shoulder: -30, elbow: 20 }), { spine: 20 }), 'feet', { hold: 0.1 }),
  ],
});
def('broad-jump', 'Broad jump', {
  thumb: 3,
  keyframes: [
    kf(P(both({ shoulder: 60, elbow: 10 })), 'feet', { hold: 0.3, move: 0.45 }),
    kf(P(both({ hip: 90, knee: 90, ankle: 30 }), loadArms, { spine: 52, neck: -18 }), 'feet', { hold: 0.05, move: 0.18 }),
    kf(P(both({ ankle: -30, hip: 0 }), both({ shoulder: 140, elbow: 10 }), { spine: 40 }), 'Ltoe+Rtoe', { move: 0.22 }),
    kf(P(both({ hip: 70, knee: 60, ankle: -10 }), both({ shoulder: 100, elbow: 20 }), { spine: 24, lift: 22 }), 'air', { move: 0.25, travel: [60, 0] }),
    kf(P(both({ hip: 94, knee: 96, ankle: 30, shoulder: 70, elbow: 30 }), { spine: 40, neck: -16 }), 'feet', { hold: 0.4, travel: [70, 0] }),
  ],
});
def('box-jump', 'Box jump', {
  thumb: 4, fixture: { kind: 'box', from: 58, to: 104, top: 50 },
  keyframes: [
    kf(P(both({ hipAbd: 6 })), 'feet', { hold: 0.3, move: 0.45 }),
    kf(jumpLoad, 'feet', { hold: 0.05, move: 0.18 }),
    kf(takeoff, 'Ltoe+Rtoe', { move: 0.2 }),
    kf(P(both({ hip: 100, knee: 110, ankle: -10 }), both({ shoulder: 100, elbow: 20 }), { spine: 20, lift: 56 }), 'air', { move: 0.24, travel: [40, 0] }),
    kf(P(both({ hip: 88, knee: 96, ankle: 32, shoulder: 70, elbow: 30 }), { spine: 34, neck: -16 }), 'feet', { hold: 0.2, move: 0.5, surface: 50, travel: [38, 0] }),
    kf(P(both({ hipAbd: 6 })), 'feet', { hold: 0.3, surface: 50 }),
  ],
});
def('depth-jump', 'Depth jump', {
  thumb: 3, fixture: { kind: 'box', from: -26, to: 16, top: 40 },
  keyframes: [
    kf(P({ hipR: 30, kneeR: 30, ankleR: 0, shoulderL: 20, shoulderR: 20 }), 'L', { hold: 0.3, move: 0.3, surface: 40 }),
    kf(P(both({ ankle: -20, knee: 10, shoulder: 30 }), { lift: 2 }), 'air', { move: 0.3, surface: 40, travel: [36, 0] }),
    kf(P(both({ hip: 50, knee: 60, ankle: 28 }), loadArms, { spine: 32 }), 'feet', { move: 0.18, travel: [4, 0] }),
    kf(takeoff, 'Ltoe+Rtoe', { move: 0.2 }),
    kf(P(both({ ankle: -30, knee: 10 }), reachArms, { lift: 26 }), 'air', { move: 0.26 }),
    kf(landSoft, 'feet', { hold: 0.35 }),
  ],
});
def('drop-landing', 'Drop landing', {
  thumb: 2, fixture: { kind: 'box', from: -26, to: 16, top: 40 },
  keyframes: [
    kf(P({ hipR: 30, kneeR: 30, ankleR: 0, shoulderL: 20, shoulderR: 20 }), 'L', { hold: 0.35, move: 0.3, surface: 40 }),
    kf(P(both({ ankle: -20, knee: 10, shoulder: 40, elbow: 10 }), { lift: 2 }), 'air', { move: 0.3, surface: 40, travel: [36, 0] }),
    kf(P(both({ hip: 74, knee: 84, ankle: 32, shoulder: 70, elbow: 20, hipAbd: 8 }), { spine: 34, neck: -18 }), 'feet', { hold: 0.7, travel: [4, 0] }),
  ],
});
def('single-leg-hop-stick', 'Single-leg hop and stick', {
  thumb: 3,
  keyframes: [
    kf(P({ hipL: 30, kneeL: 34, ankleL: 16, hipR: 40, kneeR: 80, spine: 20, shoulderL: -30, shoulderR: -30 }), 'L', { hold: 0.3, move: 0.2 }),
    kf(P({ ankleL: -30, hipR: 50, kneeR: 90, shoulderL: 90, shoulderR: 90, elbowL: 20, elbowR: 20 }), 'Ltoe', { move: 0.25 }),
    kf(P({ hipL: 20, kneeL: 30, ankleL: -20, hipR: 40, kneeR: 90, shoulderL: 70, shoulderR: 70, lift: 14 }), 'air', { move: 0.25, travel: [40, 0] }),
    kf(P({ hipL: 60, kneeL: 64, ankleL: 30, hipR: 30, kneeR: 80, spine: 28, shoulderL: 50, shoulderR: 50, elbowL: 20, elbowR: 20 }), 'L', { hold: 0.6, travel: [8, 0] }),
  ],
});
def('split-squat-jump', 'Split-squat jump', {
  thumb: 2, loop: true,
  keyframes: [
    kf(splitFit(88, 92, -12, { spine: 6, ...armsSwing(-20, 30, 80) }), 'L+Rtoe', { hold: 0.05, move: 0.25 }),
    kf(P({ ankleL: -20, ankleR: -20, hipL: 20, hipR: -10, kneeR: 20, ...armsSwing(40, -30, 80), lift: 22 }), 'air', { move: 0.22 }),
    kf(mirror(splitFit(88, 92, -12, { spine: 6, ...armsSwing(-20, 30, 80) })), 'R+Ltoe', { hold: 0.05, move: 0.25 }),
    kf(P({ ankleL: -20, ankleR: -20, hipR: 20, hipL: -10, kneeL: 20, ...armsSwing(-30, 40, 80), lift: 22 }), 'air', { move: 0.22 }),
  ],
});
def('approach-jump', 'Approach jump', {
  view: 'side', thumb: 4,
  keyframes: [
    kf(P({ spine: 12, hipL: 40, kneeL: 30, ankleL: 10, hipR: -16, kneeR: 50, ankleR: -24, ...armsSwing(-20, 30, 80) }), 'L', { hold: 0.1, move: 0.26 }),
    kf(P({ spine: 20, hipR: 50, kneeR: 40, ankleR: 10, hipL: -20, kneeL: 40, ankleL: -30, ...armsSwing(30, -20, 60) }), 'R', { move: 0.24, travel: [50, 0] }),
    kf(P({ spine: 40, neck: -16, ...both({ hip: 80, knee: 84, ankle: 30 }), ...loadArms }), 'feet', { move: 0.18, travel: [40, 0] }),
    kf(takeoff, 'Ltoe+Rtoe', { move: 0.2 }),
    kf(P(both({ ankle: -30, knee: 10 }), { ...reachArms, shoulderR: 120, elbowR: 60, lift: 34 }), 'air', { hold: 0.1, move: 0.3 }),
    kf(landSoft, 'feet', { hold: 0.35 }),
  ],
});
def('pogo', 'Pogo hops', {
  view: 'three-quarter', loop: true, thumb: 1,
  keyframes: [
    kf(P(both({ knee: 10, ankle: 12, shoulder: 16, elbow: 80 })), 'feet', { move: 0.14 }),
    kf(P(both({ knee: 4, ankle: -34, shoulder: 16, elbow: 80 }), { lift: 8 }), 'air', { move: 0.14 }),
  ],
});
def('jump-rope', 'Jump rope', {
  view: 'three-quarter', loop: true, thumb: 1, implement: { kind: 'jumprope', at: 'hands' },
  keyframes: [
    kf(P(both({ knee: 8, ankle: 8, shoulder: 12, shoulderAbd: 22, elbow: 70 })), 'feet', { move: 0.15 }),
    kf(P(both({ knee: 4, ankle: -30, shoulder: 12, shoulderAbd: 22, elbow: 70 }), { lift: 6 }), 'air', { move: 0.15 }),
  ],
});
def('bound', 'Bounding', {
  path: { kind: 'line', length: 420 },
  loop: true, thumb: 1,
  keyframes: gait([
    { hipL: 40, kneeL: 20, ankleL: 4, hipR: -20, kneeR: 50, ankleR: -24, ...armsSwing(-40, 50, 60) },
    { hipL: -30, kneeL: 10, ankleL: -30, hipR: 88, kneeR: 90, ankleR: 10, ...armsSwing(70, -50, 40), lift: 10 },
    { hipL: -20, kneeL: 60, ankleL: -20, hipR: 70, kneeR: 40, ankleR: 10, ...armsSwing(50, -40, 50), lift: 16 },
  ], { lean: 10, move: 0.16 }),
});
def('skater-bound', 'Skater bound', {
  view: 'front', thumb: 1, loop: true,
  keyframes: [
    kf(clear(P({ spine: 30, neck: -12, hipL: 70, kneeL: 76, ankleL: 28, hipAbdL: 10, hipR: 40, kneeR: 70, hipAbdR: -14, bend: 10, ...armsSwing(40, -20, 40) }), 'L'), 'L', { hold: 0.2, move: 0.3 }),
    kf(P({ spine: 16, hipL: 10, kneeL: 20, hipR: 30, kneeR: 50, hipAbdL: 14, hipAbdR: 4, lift: 14, shoulderAbdL: 40, shoulderAbdR: 30 }), 'air', { move: 0.3, travel: [0, -60] }),
    kf(clear(mirror(P({ spine: 30, neck: -12, hipL: 70, kneeL: 76, ankleL: 28, hipAbdL: 10, hipR: 40, kneeR: 70, hipAbdR: -14, bend: 10, ...armsSwing(40, -20, 40) })), 'R'), 'R', { hold: 0.2, move: 0.3, travel: [0, -60] }),
    kf(P({ spine: 16, hipL: 30, kneeL: 50, hipR: 10, kneeR: 20, hipAbdL: 4, hipAbdR: 14, lift: 14, shoulderAbdL: 30, shoulderAbdR: 40 }), 'air', { move: 0.3, travel: [0, 60] }),
  ],
});

// Olympic-style lifts ------------------------------------------------------
const hangPos = barOverMidfoot(P(both({ hip: 40, knee: 22, ankle: 10, hipAbd: 8 }), { spine: 34, neck: -12 }));
const barAtHips = [(sk) => add(add(add(sk.pelvis, fwd(sk), 12), up(sk), 6), lat(sk), 21), (sk) => add(add(add(sk.pelvis, fwd(sk), 12), up(sk), 6), lat(sk), -21)];
const barAtChest = [(sk) => add(add(add(sk.pelvis, fwd(sk), 12), up(sk), 30), lat(sk), 21), (sk) => add(add(add(sk.pelvis, fwd(sk), 12), up(sk), 30), lat(sk), -21)];
const triple = reachBoth(P(both({ ankle: -30, hipAbd: 8 }), { spine: -6, neck: -4 }), ...barAtHips);
const catchRack = rack(P(both({ hip: 50, knee: 60, ankle: 26, hipAbd: 14, hipRot: -10 }), { spine: 14 }));
def('hang-clean', 'Hang power clean', {
  view: 'three-quarter', implement: { kind: 'barbell', at: 'hands' }, thumb: 3,
  keyframes: [
    kf(dlTop, 'feet', { hold: 0.3, move: 0.4 }),
    kf(hangPos, 'feet', { hold: 0.1, move: 0.2 }),
    kf(triple, 'Ltoe+Rtoe', { move: 0.16 }),
    kf(catchRack, 'feet', { hold: 0.2, move: 0.5 }),
    kf(pressRack, 'feet', { hold: 0.3 }),
  ],
});
def('high-pull', 'High pull', {
  view: 'three-quarter', implement: { kind: 'barbell', at: 'hands' }, thumb: 2,
  keyframes: [
    kf(hangPos, 'feet', { hold: 0.3, move: 0.22 }),
    kf(triple, 'Ltoe+Rtoe', { move: 0.2 }),
    kf(reachBoth(P(both({ ankle: -26, hipAbd: 8 }), { spine: -4 }), ...barAtChest, { rot: ROTS, prefer: (sk, sd) => -sk[sd].elbow[1] }), 'Ltoe+Rtoe', { hold: 0.1, move: 0.5 }),
    kf(hangPos, 'feet', { hold: 0.1 }),
  ],
});
def('dumbbell-snatch', 'Single-arm dumbbell snatch', {
  view: 'three-quarter', implement: { kind: 'dumbbell', at: 'R' }, thumb: 3,
  keyframes: [
    kf(P(both({ hip: 70, knee: 50, ankle: 24, hipAbd: 14 }), { spine: 50, neck: -20, shoulderR: 50, elbowR: 4, shoulderL: 30, elbowL: 20 }), 'feet', { hold: 0.3, move: 0.2 }),
    kf(P(both({ ankle: -30, hipAbd: 10 }), { spine: -4, shoulderR: 60, shoulderAbdR: 40, elbowR: 100, shoulderL: -10 }), 'Ltoe+Rtoe', { move: 0.2 }),
    kf(P(both({ hip: 40, knee: 46, ankle: 20, hipAbd: 14 }), { spine: 12, shoulderR: 176, shoulderAbdR: 10, elbowR: 2, shoulderL: 30, elbowL: 30 }), 'feet', { hold: 0.15, move: 0.4 }),
    kf(P(both({ hipAbd: 10 }), { shoulderR: 178, shoulderAbdR: 10, elbowR: 2 }), 'feet', { hold: 0.3 }),
  ],
});
// Turkish get-up: lying → elbow → hand → bridge → kneel → stand (right arm up).
const tguArm = { shoulderR: 90, shoulderAbdR: 6, elbowR: 0 };
def('turkish-get-up', 'Turkish get-up', {
  view: 'three-quarter', implement: { kind: 'kettlebell', at: 'R' }, thumb: 3,
  keyframes: [
    kf(lieFlat(P({ hipR: 50, kneeR: 100, ankleR: 10, hipL: 4, hipAbdL: 20, shoulderL: 20, shoulderAbdL: 40, ...tguArm, spine: -90 })), 'back', { hold: 0.4, move: 0.8 }),
    kf(P({ spine: -45, twist: 20, hipR: 30, kneeR: 100, ankleR: 10, hipL: 4, hipAbdL: 20, shoulderL: -20, shoulderAbdL: 50, elbowL: 90, shoulderR: 140, elbowR: 0 }), 'back', { move: 0.8 }),
    kf(P({ spine: -20, twist: 20, hipR: 70, kneeR: 100, ankleR: 10, hipL: 60, hipAbdL: 16, kneeL: 10, shoulderL: -40, shoulderAbdL: 40, elbowL: 0, shoulderR: 170, elbowR: 0 }), 'back', { move: 0.8 }),
    kf(P({ spine: 0, hipL: -10, kneeL: 90, ankleL: -88, hipR: 90, kneeR: 90, ankleR: 0, shoulderR: 178, shoulderAbdR: 6, elbowR: 0, shoulderL: 10 }), 'R+Lknee', { hold: 0.3, move: 0.9 }),
    kf(P({ shoulderR: 178, shoulderAbdR: 6, elbowR: 0 }), 'feet', { hold: 0.4 }),
  ],
});
// Burpee: stand → squat, hands down → kick back to plank → push-up → jump in → jump.
const burpSquat = flatHands(reachBoth(P(both({ hip: 120, knee: 124, ankle: 36, hipAbd: 14 }), { spine: 54, neck: -20 }),
  (sk) => [sk.L.ankle[0] + 26, sk.L.ankle[1] + 2.8, 14], (sk) => [sk.L.ankle[0] + 26, sk.L.ankle[1] + 2.8, -14]));
def('burpee', 'Burpee', {
  thumb: 2,
  keyframes: [
    kf(P(), 'feet', { hold: 0.15, move: 0.35 }),
    kf(burpSquat, 'feet+hands', { move: 0.25 }),
    kf(pushTop, 'hands+Ltoe+Rtoe', { move: 0.35 }),
    kf(pushBottom, 'hands+Ltoe+Rtoe', { move: 0.3 }),
    kf(pushTop, 'hands+Ltoe+Rtoe', { move: 0.25 }),
    kf(burpSquat, 'feet+hands', { move: 0.25 }),
    kf(takeoff, 'Ltoe+Rtoe', { move: 0.2 }),
    kf(P(both({ ankle: -30, knee: 8 }), reachArms, { lift: 20 }), 'air', { move: 0.3 }),
    kf(P(), 'feet', { hold: 0.1 }),
  ],
});
const mcPlank = (hipL, kneeL) => handsToFloor(P(both({ shoulder: 82, elbow: 0, shoulderAbd: 10, wrist: -85, ankle: 30 }), { hipL, kneeL, ankleL: 10, neck: -10 }));
def('mountain-climber', 'Mountain climbers', {
  loop: true, thumb: 0,
  keyframes: [
    kf(mcPlank(96, 110), 'hands+Rtoe', { move: 0.2 }),
    kf(mirror(mcPlank(96, 110)), 'hands+Ltoe', { move: 0.2 }),
  ],
});
const crawl = (a) => handsAbove(P(both({ hip: 90, knee: 90, ankle: 30, shoulder: 88, elbow: 0, shoulderAbd: 8, wrist: -85 }), { neck: -14 },
  { hipL: 90 + a, kneeL: 90 + a * 0.4, hipR: 90 - a, kneeR: 90 - a * 0.4, shoulderL: 88 - a * 0.6, shoulderR: 88 + a * 0.6 }), 0, 40, 110);
def('bear-crawl', 'Bear crawl', {
  path: { kind: 'line', length: 200, speed: 50 },
  loop: true, thumb: 0,
  keyframes: [kf(crawl(16), 'hands+Ltoe+Rtoe', { move: 0.35 }), kf(crawl(-16), 'hands+Ltoe+Rtoe', { move: 0.35 })],
});
const sledArms = both({ shoulder: 110, elbow: 30, shoulderAbd: 10 });
def('sled-push', 'Sled push', {
  loop: true, thumb: 0, fixture: { kind: 'sled', at: 50 },
  keyframes: gait([
    { hipL: 70, kneeL: 70, ankleL: 20, hipR: 0, kneeR: 16, ankleR: -24, ...sledArms },
    { hipL: 40, kneeL: 40, ankleL: 30, hipR: 30, kneeR: 90, ankleR: -10, ...sledArms },
  ], { lean: 55, neck: -20, move: 0.3 }),
});
def('sled-drag', 'Backward sled drag', {
  loop: true, thumb: 0, implement: { kind: 'band', at: 'hands', to: [90, 20, 0] },
  keyframes: gait([
    { hipL: 50, kneeL: 70, ankleL: 30, hipR: 70, kneeR: 90, ankleR: -10, ...both({ shoulder: 60, elbow: 10 }) },
    { hipL: 60, kneeL: 60, ankleL: 20, hipR: 30, kneeR: 70, ankleR: -10, ...both({ shoulder: 60, elbow: 10 }) },
  ], { lean: 10, neck: -4, move: 0.3 }),
});
const carryArms = both({ shoulder: 0, shoulderAbd: 10, elbow: 0 });
const walkPhases = (arms, extra = {}) => [
  { hipL: 22, kneeL: 2, ankleL: 10, hipR: -12, kneeR: 14, ankleR: -20, ...arms, ...extra },
  { hipL: 4, kneeL: 8, ankleL: 4, hipR: 14, kneeR: 48, ankleR: 0, ...arms, ...extra },
  { hipL: -14, kneeL: 4, ankleL: -8, hipR: 24, kneeR: 8, ankleR: 8, ...arms, ...extra },
  { hipL: -10, kneeL: 28, ankleL: -22, hipR: 22, kneeR: 2, ankleR: 10, ...arms, ...extra },
];
def('farmers-carry', "Farmer's carry", {
  path: { kind: 'line', length: 280, speed: 100 }, view: 'three-quarter', loop: true, thumb: 0, implement: { kind: 'dumbbells', at: 'hands' }, keyframes: gait(walkPhases(carryArms), { move: 0.2 }) });
def('suitcase-carry', 'Suitcase carry', {
  path: { kind: 'line', length: 280, dir: 'left', speed: 100 }, view: 'front', loop: true, thumb: 0, implement: { kind: 'dumbbell', at: 'R' }, keyframes: gait(walkPhases({ ...carryArms, shoulderAbdL: 20 }, { bend: 3 }), { move: 0.2 }) });
def('overhead-carry', 'Overhead carry', {
  path: { kind: 'line', length: 280, speed: 100 }, view: 'three-quarter', loop: true, thumb: 0, implement: { kind: 'dumbbells', at: 'hands' }, keyframes: gait(walkPhases(both({ shoulder: 176, shoulderAbd: 14, elbow: 2 })), { move: 0.2 }) });
const ropeStance = both({ hip: 50, knee: 50, ankle: 22, hipAbd: 14 });
def('battle-ropes', 'Battle rope waves', {
  view: 'three-quarter', loop: true, thumb: 0, implement: { kind: 'rope', at: 'hands' },
  keyframes: [
    kf(P(ropeStance, { spine: 26, shoulderL: 70, elbowL: 30, shoulderR: 30, elbowR: 30 }), 'feet', { move: 0.16 }),
    kf(P(ropeStance, { spine: 26, shoulderL: 30, elbowL: 30, shoulderR: 70, elbowR: 30 }), 'feet', { move: 0.16 }),
  ],
});

// Medicine-ball throws -----------------------------------------------------
const mb = { kind: 'medball', at: 'chest' };
def('chest-pass', 'Medicine-ball chest pass', {
  view: 'three-quarter', implement: mb, thumb: 1,
  keyframes: [
    kf(P(both({ hip: 30, knee: 34, ankle: 16, hipAbd: 10, shoulder: 30, elbow: 130, shoulderAbd: 20 }), { spine: 16 }), 'feet', { hold: 0.3, move: 0.2 }),
    kf(P({ hipL: 30, kneeL: 20, ankleL: 10, hipR: -10, kneeR: 20, ankleR: -30, ...both({ shoulder: 88, elbow: 2, shoulderAbd: 8 }), spine: 20 }), 'L+Rtoe', { hold: 0.4, move: 0.5 }),
    kf(P(both({ hip: 30, knee: 34, ankle: 16, hipAbd: 10, shoulder: 30, elbow: 130, shoulderAbd: 20 }), { spine: 16 }), 'feet', { hold: 0.1 }),
  ],
});
def('overhead-throw-medball', 'Overhead medicine-ball throw', {
  implement: mb, thumb: 1,
  keyframes: [
    kf(P({ hipL: 20, kneeL: 10, hipR: -14, kneeR: 16, ankleR: -20, ...both({ shoulder: 196, elbow: 70 }), spine: -14 }), 'L+Rtoe', { hold: 0.3, move: 0.25 }),
    kf(P({ hipL: 34, kneeL: 22, ankleL: 12, hipR: -8, kneeR: 12, ankleR: -32, ...both({ shoulder: 110, elbow: 4 }), spine: 24 }), 'L+Rtoe', { hold: 0.4, move: 0.6 }),
    kf(P({ hipL: 20, kneeL: 10, hipR: -14, kneeR: 16, ankleR: -20, ...both({ shoulder: 196, elbow: 70 }), spine: -14 }), 'L+Rtoe', { hold: 0.1 }),
  ],
});
def('medball-slam', 'Medicine-ball slam', {
  view: 'three-quarter', implement: mb, thumb: 1,
  keyframes: [
    kf(P(both({ ankle: -26, shoulder: 186, elbow: 20, hipAbd: 10 }), { spine: -8 }), 'Ltoe+Rtoe', { hold: 0.2, move: 0.22 }),
    kf(P(both({ hip: 96, knee: 70, ankle: 26, shoulder: 70, elbow: 10, hipAbd: 12 }), { spine: 70, neck: -20 }), 'feet', { hold: 0.35, move: 0.6 }),
    kf(P(both({ ankle: -26, shoulder: 186, elbow: 20, hipAbd: 10 }), { spine: -8 }), 'Ltoe+Rtoe', { hold: 0.1 }),
  ],
});
const rotLoad = P(both({ hip: 30, knee: 36, ankle: 16, hipAbd: 16 }), { spine: 14, twist: 50, turn: 0, shoulderL: 50, shoulderAbdL: 30, elbowL: 20, shoulderR: 50, shoulderAbdR: -30, elbowR: 30 });
const rotRelease = P({ hipL: 20, kneeL: 20, ankleL: 10, hipAbdL: 14, hipR: 10, kneeR: 30, ankleR: -30, hipAbdR: 14, hipRotR: 30 },
  { spine: 10, twist: -40, turn: -30, shoulderL: 70, shoulderAbdL: -40, elbowL: 20, shoulderR: 80, shoulderAbdR: 40, elbowR: 10 });
def('rotational-throw', 'Rotational medicine-ball throw', {
  view: 'front', implement: mb, thumb: 1,
  keyframes: [
    kf(rotLoad, 'feet', { hold: 0.3, move: 0.3 }),
    kf(rotRelease, 'L+Rtoe', { hold: 0.35, move: 0.6 }),
    kf(rotLoad, 'feet', { hold: 0.1 }),
  ],
});
def('scoop-toss', 'Medicine-ball scoop toss', {
  implement: mb, thumb: 1,
  keyframes: [
    kf(P(both({ hip: 92, knee: 80, ankle: 30, hipAbd: 14, shoulder: 60, elbow: 4 }), { spine: 66, neck: -20 }), 'feet', { hold: 0.3, move: 0.3 }),
    kf(P(both({ ankle: -30, hipAbd: 10, shoulder: 170, elbow: 4 }), { spine: -10 }), 'Ltoe+Rtoe', { hold: 0.35, move: 0.6 }),
    kf(P(both({ hip: 92, knee: 80, ankle: 30, hipAbd: 14, shoulder: 60, elbow: 4 }), { spine: 66, neck: -20 }), 'feet', { hold: 0.1 }),
  ],
});
def('shot-put-throw', 'Medicine-ball shot-put throw', {
  view: 'front', implement: { kind: 'medball', at: 'R' }, thumb: 1,
  keyframes: [
    kf(P({ ...both({ hip: 36, knee: 44, ankle: 18, hipAbd: 18 }), spine: 10, twist: 60, bend: -10, shoulderR: 40, shoulderAbdR: 60, elbowR: 140, shoulderL: 90, shoulderAbdL: 40, elbowL: 10 }), 'feet', { hold: 0.35, move: 0.35 }),
    kf(P({ hipL: 10, kneeL: 10, ankleL: 0, hipAbdL: 16, hipR: 0, kneeR: 20, ankleR: -34, hipAbdR: 16, spine: 6, twist: -40, turn: -20, bend: 10, shoulderR: 120, shoulderAbdR: 20, elbowR: 4, shoulderL: -10, shoulderAbdL: 40, elbowL: 40 }), 'L+Rtoe', { hold: 0.4, move: 0.6 }),
    kf(P({ ...both({ hip: 36, knee: 44, ankle: 18, hipAbd: 18 }), spine: 10, twist: 60, bend: -10, shoulderR: 40, shoulderAbdR: 60, elbowR: 140, shoulderL: 90, shoulderAbdL: 40, elbowL: 10 }), 'feet', { hold: 0.1 }),
  ],
});

// Core ----------------------------------------------------------------------
const breathe = (p, contact, d = {}) => [
  kf(p, contact, { hold: 0.9, move: 1.3 }),
  kf({ ...p, ...Object.fromEntries(Object.entries(d).map(([k, v]) => [k, p[k] + v])) }, contact, { hold: 0.9, move: 1.3 }),
];
/** Forearm plank: elbows under the shoulders, forearms flat, toes down. */
const forearmPlank = solve(P(both({ shoulder: 88, elbow: 90, shoulderAbd: 10, ankle: 30, wrist: 0 }), { neck: -8 }), 'spine',
  (sk) => (sk.L.elbow[1] - 3.8) - sk.L.toe[1], 50, 100);
def('plank', 'Plank', { loop: true, thumb: 0, keyframes: breathe(forearmPlank, 'Ltoe+Rtoe', { neck: -3 }) });
/** Side plank on the left forearm: the whole body tilted onto its left side. */
const sidePlank = { ...P(both({ ankle: 0 }), { shoulderL: 0, shoulderAbdL: 84, elbowL: 90, shoulderRotL: 90, shoulderR: 0, shoulderAbdR: 150, elbowR: 4, bend: 68 }) };
def('side-plank', 'Side plank', { view: 'front', loop: true, thumb: 0, keyframes: breathe(sidePlank, 'air', { bend: 1 }) });
def('copenhagen-plank', 'Copenhagen plank', {
  view: 'front', loop: true, thumb: 0, fixture: { kind: 'bench', under: 'Rfoot', width: 34, top: 30 },
  // Top (right) leg resting on a bench 30 up; the bottom leg hangs underneath.
  keyframes: breathe(solve({ ...sidePlank, hipAbdL: -14, kneeL: 50, hipL: 30 }, 'bend', (sk) => sk.R.ankle[1] - (sk.L.elbow[1] - 3.8) - 30, 20, 88), 'air', { hipAbdR: 1 }),
});
const hollow = P(both({ hip: 42, knee: 0, ankle: -30, shoulder: 176, shoulderAbd: 6, elbow: 0 }), { spine: -72, neck: 20 });
def('hollow-hold', 'Hollow body hold', { loop: true, thumb: 0, keyframes: breathe(hollow, 'back', { spine: -2 }) });
const bugBase = P(both({ hip: 90, knee: 90, ankle: 0, shoulder: 90, shoulderAbd: 6, elbow: 0 }), { spine: -90, neck: 12 });
def('dead-bug', 'Dead bug', {
  view: 'three-quarter', loop: true, thumb: 1,
  keyframes: [
    kf(bugBase, 'back', { hold: 0.2, move: 0.9 }),
    kf({ ...bugBase, shoulderL: 176, hipR: 18, kneeR: 8 }, 'back', { hold: 0.3, move: 0.9 }),
    kf(bugBase, 'back', { hold: 0.2, move: 0.9 }),
    kf({ ...bugBase, shoulderR: 176, hipL: 18, kneeL: 8 }, 'back', { hold: 0.3, move: 0.9 }),
  ],
});
/** Quadruped: hands under shoulders, knees under hips, shins flat. */
const quad = (extra = {}) => solve(P(both({ hip: 90, knee: 90, ankle: -88, shoulder: 90, elbow: 0, shoulderAbd: 4, wrist: -85 }), { neck: -10 }, extra), 'spine',
  (sk) => Math.min(sk.L.wrist[1] - 2.7, sk.L.handTip[1] - 1.5) - (sk.L.knee[1] - 5.2), 60, 120);
def('bird-dog', 'Bird dog', {
  view: 'three-quarter', loop: true, thumb: 1,
  keyframes: [
    kf(quad(), 'hands+knees', { hold: 0.2, move: 0.9 }),
    kf({ ...quad(), shoulderL: 176, elbowL: 0, wristL: 0, hipR: 0, kneeR: 0, ankleR: -40 }, 'Rhand+Lknee', { hold: 0.5, move: 0.9 }),
    kf(quad(), 'hands+knees', { hold: 0.2, move: 0.9 }),
    kf({ ...quad(), shoulderR: 176, elbowR: 0, wristR: 0, hipL: 0, kneeL: 0, ankleL: -40 }, 'Lhand+Rknee', { hold: 0.5, move: 0.9 }),
  ],
});
def('superman', 'Superman hold', {
  loop: true, thumb: 1,
  keyframes: [
    kf(P(both({ shoulder: 170, elbow: 0, ankle: -80 }), { spine: 90, neck: -10 }), 'front', { hold: 0.3, move: 0.8 }),
    kf(P(both({ shoulder: 184, elbow: 0, ankle: -80, hip: -16 }), { spine: 84, neck: -24 }), 'front', { hold: 1.0, move: 0.8 }),
  ],
});
const situpLegs = both({ hip: 60, knee: 100, ankle: 10, hipAbd: 8 });
def('sit-up', 'Sit-up', {
  keyframes: rep3(lieFlat(P(situpLegs, both({ shoulder: 40, shoulderAbd: -30, elbow: 130 }), { neck: 14 })),
    P(situpLegs, both({ shoulder: 40, shoulderAbd: -30, elbow: 130 }), { spine: lieFlat(P(situpLegs)).spine + 60, neck: 10, hipL: lieFlat(P(situpLegs)).hipL + 60, hipR: lieFlat(P(situpLegs)).hipR + 60, kneeL: lieFlat(P(situpLegs)).kneeL, kneeR: lieFlat(P(situpLegs)).kneeR }),
    { contact: 'feet', down: 0.8, upT: 0.8 }),
});
const pallofStance = both({ hip: 18, knee: 22, ankle: 10, hipAbd: 14 });
const pallofIn = reachBoth(P(pallofStance), chestPoint(12, 16, 2), chestPoint(12, 16, -2), { rot: ROTS, prefer: elbowsDown });
const pallofOut = P(pallofStance, both({ shoulder: 90, elbow: 2, shoulderAbd: -8 }));
def('pallof-press', 'Pallof press', {
  view: 'front', implement: { kind: 'band', at: 'hands', to: [20, 110, 90] },
  keyframes: rep3(pallofIn, pallofOut, { down: 0.7, upT: 0.8, holdLow: 0.8 }),
});
def('woodchop', 'Band woodchop', {
  view: 'three-quarter', implement: { kind: 'cable', at: 'hands', to: [10, 190, 70] },
  keyframes: rep3(
    P(both({ hip: 14, knee: 18, ankle: 8, hipAbd: 16 }), { twist: 40, neckTurn: 20, shoulderL: 150, shoulderAbdL: -10, shoulderR: 150, shoulderAbdR: 30, elbowL: 10, elbowR: 10 }),
    P({ hipL: 30, kneeL: 36, ankleL: 14, hipAbdL: 16, hipR: 14, kneeR: 30, ankleR: -20, hipAbdR: 16, hipRotR: 30 }, { spine: 20, twist: -40, neckTurn: -20, shoulderL: 40, shoulderAbdL: 30, shoulderR: 40, shoulderAbdR: -30, elbowL: 10, elbowR: 10 }),
    { down: 0.7, upT: 0.9 }),
});
def('landmine-rotation', 'Landmine rotation', {
  view: 'front', implement: { kind: 'landmine', at: 'L' }, loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 16, knee: 20, ankle: 10, hipAbd: 18 }), { twist: 0, shoulderL: 110, shoulderR: 110, shoulderAbdL: -20, shoulderAbdR: -20, elbowL: 4, elbowR: 4 }), 'feet', { hold: 0.1, move: 0.7 }),
    kf(P(both({ hip: 16, knee: 20, ankle: 10, hipAbd: 18 }), { twist: 40, bend: 0, shoulderL: 80, shoulderR: 80, shoulderAbdL: -30, shoulderAbdR: 10, elbowL: 4, elbowR: 4 }), 'feet', { hold: 0.2, move: 0.7 }),
    kf(P(both({ hip: 16, knee: 20, ankle: 10, hipAbd: 18 }), { twist: 0, shoulderL: 110, shoulderR: 110, shoulderAbdL: -20, shoulderAbdR: -20, elbowL: 4, elbowR: 4 }), 'feet', { hold: 0.1, move: 0.7 }),
    kf(P(both({ hip: 16, knee: 20, ankle: 10, hipAbd: 18 }), { twist: -40, bend: 0, shoulderL: 80, shoulderR: 80, shoulderAbdL: 10, shoulderAbdR: -30, elbowL: 4, elbowR: 4 }), 'feet', { hold: 0.2, move: 0.7 }),
  ],
});
def('plank-shoulder-tap', 'Plank shoulder tap', {
  view: 'three-quarter', loop: true, thumb: 1,
  keyframes: [
    kf(pushTop, 'hands+Ltoe+Rtoe', { hold: 0.1, move: 0.35 }),
    kf(reach(pushTop, 'L', (sk) => add(sk.R.shoulder, [2, 3, 0])), 'Rhand+Ltoe+Rtoe', { hold: 0.2, move: 0.35 }),
    kf(pushTop, 'hands+Ltoe+Rtoe', { hold: 0.1, move: 0.35 }),
    kf(reach(pushTop, 'R', (sk) => add(sk.L.shoulder, [2, 3, 0])), 'Lhand+Ltoe+Rtoe', { hold: 0.2, move: 0.35 }),
  ],
});
/** Kneeling ab-wheel rollout: knees down, straight arms on the wheel on the floor. */
const rollout = (lean) => {
  const q = P(both({ hip: 0 - (90 - lean) * 0.2, knee: 90 - lean + (90 - lean) * 0.2, ankle: -88 }), { spine: lean, neck: -14 });
  return reachBoth(q, (sk) => [sk.L.shoulder[0] + (lean > 60 ? 18 : 6), sk.L.knee[1] - 5.2 + 7 + 3.5, 6], (sk) => [sk.L.shoulder[0] + (lean > 60 ? 18 : 6), sk.L.knee[1] - 5.2 + 7 + 3.5, -6]);
};
def('ab-rollout', 'Ab-wheel rollout', {
  implement: { kind: 'wheel', at: 'hands' },
  keyframes: rep3(rollout(40), rollout(74), { contact: 'knees', down: 1.2, upT: 1.0 }),
});

// Mobility -------------------------------------------------------------------
def('cat-camel', 'Cat-camel', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [kf(quad({ neck: 30, hipL: 100, hipR: 100 }), 'hands+knees', { hold: 0.5, move: 1.2 }), kf(quad({ neck: -40, hipL: 80, hipR: 80 }), 'hands+knees', { hold: 0.5, move: 1.2 })],
});
const sideLie = P(both({ hip: 70, knee: 90, ankle: 0 }), { bend: 88, neck: 0, shoulderL: 90, shoulderAbdL: 0, elbowL: 0, shoulderR: 90, elbowR: 0 });
def('open-book', 'Open book', {
  view: 'front', loop: true, thumb: 1,
  keyframes: [kf(sideLie, 'air', { hold: 0.3, move: 1.2 }), kf({ ...sideLie, twist: 70, shoulderR: 90, shoulderAbdR: 150, neckTurn: -50 }, 'air', { hold: 0.8, move: 1.2 })],
});
def('sleeper-stretch', 'Sleeper stretch', {
  view: 'front', loop: true, thumb: 1,
  keyframes: [
    kf({ ...sideLie, shoulderL: 90, elbowL: 90, shoulderRotL: -20, shoulderR: 60, elbowR: 60 }, 'air', { hold: 0.5, move: 1.2 }),
    kf({ ...sideLie, shoulderL: 90, elbowL: 90, shoulderRotL: 50, shoulderR: 70, elbowR: 40 }, 'air', { hold: 1.0, move: 1.2 }),
  ],
});
def('clamshell', 'Clamshell', {
  view: 'front', thumb: 1,
  keyframes: rep3({ ...sideLie, hipL: 45, hipR: 45, shoulderR: 0, elbowR: 0 }, { ...sideLie, hipL: 45, hipR: 45, hipAbdR: 38, hipRotR: -30, shoulderR: 0, elbowR: 0 }, { contact: 'air', down: 0.7, upT: 0.8 }),
});
const wgsLunge = splitFit(92, 96, -14, { spine: 40, neck: -16 });
def('worlds-greatest-stretch', "World's greatest stretch", {
  view: 'three-quarter', thumb: 2,
  keyframes: [
    kf(flatHands(reach(reach(wgsLunge, 'R', (sk) => [sk.L.ankle[0] + 2, sk.L.ankle[1] + 2.8, -4]), 'L', (sk) => add(sk.L.knee, [-8, -12, -4]))), 'L+Rtoe', { hold: 0.6, move: 0.9 }),
    kf(flatHands(reach({ ...wgsLunge, twist: 50, neckTurn: 40, shoulderL: 90, shoulderAbdL: 120, elbowL: 0 }, 'R', (sk) => [sk.L.ankle[0] + 2, sk.L.ankle[1] + 2.8, -4])), 'L+Rtoe', { hold: 0.8, move: 0.9 }),
    kf(flatHands(reach(reach(wgsLunge, 'R', (sk) => [sk.L.ankle[0] + 2, sk.L.ankle[1] + 2.8, -4]), 'L', (sk) => add(sk.L.knee, [-8, -12, -4]))), 'L+Rtoe', { hold: 0.3 }),
  ],
});
const pigeon = (fold) => P({ spine: fold, neck: fold > 30 ? -20 : 0, hipL: 90 + fold, hipAbdL: 20, hipRotL: -60, kneeL: 100, ankleL: -20,
  hipR: -88 + fold, kneeR: 2, ankleR: -85, ...(fold > 30 ? both({ shoulder: 90 + fold * 0.3, elbow: 10 }) : both({ shoulder: 10, shoulderAbd: 16 })) });
def('pigeon-stretch', 'Pigeon stretch', {
  view: 'three-quarter', loop: true, thumb: 1,
  keyframes: [kf(pigeon(4), 'air', { hold: 0.8, move: 1.4 }), kf(pigeon(55), 'air', { hold: 1.2, move: 1.4 })],
});
def('couch-stretch', 'Couch stretch', {
  view: 'side', loop: true, thumb: 0, fixture: { kind: 'wall', at: -40 },
  keyframes: [
    kf(P({ spine: 4, hipL: 90, kneeL: 90, ankleL: 0, hipR: -14, kneeR: 150, ankleR: -80, shoulderL: 30, elbowL: 60, shoulderR: 30, elbowR: 60 }), 'L+Rknee', { hold: 1.0, move: 1.4 }),
    kf(P({ spine: -2, hipL: 90, kneeL: 90, ankleL: 0, hipR: -22, kneeR: 150, ankleR: -80, shoulderL: 30, elbowL: 60, shoulderR: 30, elbowR: 60 }), 'L+Rknee', { hold: 1.0, move: 1.4 }),
  ],
});
const seated9090 = (s) => P({ spine: 4, hipL: 80, kneeL: 90, hipRotL: -60 * s, hipAbdL: 30, hipR: 60, kneeR: 90, hipRotR: 60 * s, hipAbdR: 30, turn: 20 * s, shoulderL: 20, shoulderR: 20 });
def('hip-90-90', '90/90 hip switch', {
  view: 'front', loop: true, thumb: 0,
  keyframes: [kf(seated9090(1), 'air', { hold: 0.6, move: 1.1 }), kf(seated9090(-1), 'air', { hold: 0.6, move: 1.1 })],
});
def('hamstring-floss', 'Supine hamstring floss', {
  loop: true, thumb: 1,
  keyframes: [
    kf(lieFlat(P({ hipL: 90, kneeL: 90, ankleL: 0, hipR: 60, kneeR: 104, ankleR: 10, shoulderL: 90, elbowL: 80, shoulderR: 90, elbowR: 80 })), 'back', { hold: 0.2, move: 0.9 }),
    kf(lieFlat(P({ hipL: 90, kneeL: 4, ankleL: 20, hipR: 60, kneeR: 104, ankleR: 10, shoulderL: 90, elbowL: 80, shoulderR: 90, elbowR: 80 })), 'back', { hold: 0.5, move: 0.9 }),
  ],
});
def('knee-to-wall', 'Knee-to-wall ankle mobility', {
  view: 'side', thumb: 1, fixture: { kind: 'wall', at: 48 },
  keyframes: rep3(splitFit(20, 16, -18, { spine: 4, shoulderL: 60, shoulderR: 60, elbowL: 30, elbowR: 30 }),
    splitFit(56, 76, -10, { spine: 10, shoulderL: 64, shoulderR: 64, elbowL: 30, elbowR: 30, ankleL: 40 }), { contact: 'L+Rtoe', down: 0.8, upT: 0.8, holdLow: 0.5 }),
});
def('foam-roll', 'Foam rolling', {
  loop: true, thumb: 0, fixture: { kind: 'roller', under: 'calves' },
  keyframes: [
    kf(flatHands(reachBoth(P(both({ hip: 80, knee: 6, ankle: 10 }), { spine: -40, neck: 10 }), (sk) => add(sk.pelvis, [-18, -12, 12]), (sk) => add(sk.pelvis, [-18, -12, -12]))), 'hands', { move: 1.1 }),
    kf(flatHands(reachBoth(P(both({ hip: 80, knee: 6, ankle: 10 }), { spine: -46, neck: 10 }), (sk) => add(sk.pelvis, [-22, -12, 12]), (sk) => add(sk.pelvis, [-22, -12, -12]))), 'hands', { move: 1.1, travel: [-16, 0] }),
  ],
});
def('neck-isometric', 'Neck isometric', {
  view: 'front', loop: true, thumb: 0,
  keyframes: breathe(reach(P(), 'L', (sk) => add(sk.head, [0, 2, 9.5])), 'feet', { neck: 0.5 }),
});
def('chin-tuck', 'Chin tuck', { keyframes: rep3(P({ neck: -6 }), P({ neck: 14 }), { down: 0.7, upT: 0.7, holdLow: 0.8 }) });
const goal = (up) => P(both({ shoulder: 0, shoulderAbd: up ? 160 : 86, shoulderRot: -90, elbow: up ? 20 : 90, knee: 12, hip: 10 }), { spine: -4 });
def('wall-angel', 'Wall angel', {
  view: 'front', fixture: { kind: 'wall', at: -14 },
  keyframes: rep3(goal(false), goal(true), { down: 1.0, upT: 1.0 }),
});
def('wall-slide', 'Serratus wall slide', {
  view: 'side', fixture: { kind: 'wall', at: 36 },
  keyframes: rep3(P(both({ shoulder: 90, elbow: 90, shoulderAbd: 12 })), P(both({ shoulder: 160, elbow: 40, shoulderAbd: 18 })), { down: 0.9, upT: 0.9 }),
});
def('tendon-glides', 'Tendon glides', {
  view: 'three-quarter', loop: true, thumb: 1,
  keyframes: [
    kf(P(both({ shoulder: 20, elbow: 100, wrist: 0 })), 'feet', { hold: 0.4, move: 0.6 }),
    kf(P(both({ shoulder: 20, elbow: 100, wrist: 50 })), 'feet', { hold: 0.4, move: 0.6 }),
    kf(P(both({ shoulder: 20, elbow: 100, wrist: -50 })), 'feet', { hold: 0.4, move: 0.6 }),
  ],
});
def('stand-breathe', 'Standing breathing', { loop: true, thumb: 0, keyframes: breathe(P({ neck: 2 }), 'feet', { spine: -1.5, shoulderAbdL: 2, shoulderAbdR: 2 }) });
def('breathing-seated', 'Seated breathing', {
  loop: true, thumb: 0, fixture: { kind: 'bench', from: -16, to: 14, below: -10 },
  keyframes: breathe(P(both({ hip: 90, knee: 90, shoulder: 30, elbow: 70, shoulderAbd: 6 }), { neck: 4 }), 'seat', { spine: -2 }),
});
def('breathing-supine', 'Supine breathing', {
  loop: true, thumb: 0,
  keyframes: breathe(lieFlat(P(both({ hip: 60, knee: 104, ankle: 10, shoulder: 10, shoulderAbd: 20 }))), 'feet', { shoulderAbdL: 2, shoulderAbdR: 2 }),
});
def('hip-circles', 'Standing hip circles', {
  view: 'front', loop: true, thumb: 1,
  keyframes: [
    kf(P({ hipR: 80, kneeR: 90, shoulderAbdL: 40, shoulderAbdR: 40 }), 'L', { move: 0.5 }),
    kf(P({ hipR: 70, hipAbdR: 50, hipRotR: -30, kneeR: 90, shoulderAbdL: 40, shoulderAbdR: 40 }), 'L', { move: 0.5 }),
    kf(P({ hipR: 10, hipAbdR: 40, kneeR: 90, shoulderAbdL: 40, shoulderAbdR: 40 }), 'L', { move: 0.5 }),
    kf(P({ hipR: 20, hipAbdR: 5, kneeR: 90, shoulderAbdL: 40, shoulderAbdR: 40 }), 'L', { move: 0.5 }),
  ],
});
def('leg-swings', 'Leg swings', {
  loop: true, thumb: 0, fixture: { kind: 'wall', at: 34 },
  keyframes: [
    kf(P({ hipR: 70, kneeR: 4, ankleR: 10, shoulderL: 70, elbowL: 10, shoulderR: 30 }), 'L', { move: 0.5 }),
    kf(P({ hipR: -30, kneeR: 14, ankleR: -20, shoulderL: 70, elbowL: 10, shoulderR: 30 }), 'L', { move: 0.5 }),
  ],
});
def('hurdle-walkover', 'Hurdle walkover', {
  view: 'front', loop: false, thumb: 1, fixture: { kind: 'hurdle', at: 0 },
  keyframes: [
    kf(P({ shoulderAbdL: 30, shoulderAbdR: 30 }), 'feet', { hold: 0.2, move: 0.6 }),
    kf(P({ hipR: 100, kneeR: 100, hipAbdR: 30, hipRotR: -30, shoulderAbdL: 40, shoulderAbdR: 40 }), 'L', { move: 0.6 }),
    kf(P(both({ hipAbd: 14 }), { shoulderAbdL: 30, shoulderAbdR: 30 }), 'L+R', { hold: 0.2, move: 0.6, travel: [0, -30] }),
    kf(P({ hipAbdR: 14, hipL: 100, kneeL: 100, hipAbdL: 30, hipRotL: -30, shoulderAbdL: 40, shoulderAbdR: 40 }), 'R', { move: 0.6 }),
    kf(P({ shoulderAbdL: 30, shoulderAbdR: 30 }), 'feet', { hold: 0.2, travel: [0, -30] }),
  ],
});

// Balance and adductors ------------------------------------------------------
def('single-leg-balance', 'Single-leg balance', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [
    kf(P({ hipL: 8, kneeL: 10, ankleL: 4, hipR: 60, kneeR: 80, shoulderAbdL: 20, shoulderAbdR: 20 }), 'L', { hold: 0.6, move: 1.2 }),
    kf(P({ hipL: 10, kneeL: 12, ankleL: 6, hipR: 64, kneeR: 82, bend: 2, shoulderAbdL: 24, shoulderAbdR: 18 }), 'L', { hold: 0.6, move: 1.2 }),
  ],
});
def('hip-airplane', 'Hip airplane', {
  view: 'three-quarter', thumb: 1,
  keyframes: rep3(P({ spine: 80, hipL: 84, kneeL: 20, ankleL: 12, hipR: 0, kneeR: 4, shoulderAbdL: 80, shoulderAbdR: 80, shoulderL: 80, shoulderR: 80 }),
    P({ spine: 80, hipL: 84, kneeL: 20, ankleL: 12, hipR: 0, kneeR: 4, turn: -35, hipRotL: 35, shoulderAbdL: 80, shoulderAbdR: 80, shoulderL: 80, shoulderR: 80 }), { contact: 'L', down: 1.0, upT: 1.0 }),
});
const slSquat = (extra) => P({ hipL: 70, kneeL: 80, ankleL: 30, spine: 30, shoulderL: 70, shoulderR: 70, elbowL: 10, elbowR: 10, ...extra });
def('star-excursion', 'Star excursion reach', {
  view: 'three-quarter', thumb: 1,
  keyframes: [
    kf(P({ hipR: 30, kneeR: 50 }), 'L', { hold: 0.2, move: 0.8 }),
    kf(slSquat({ hipR: 70, kneeR: 4, ankleR: 0 }), 'L', { hold: 0.3, move: 0.8 }),
    kf(P({ hipR: 30, kneeR: 50 }), 'L', { hold: 0.1, move: 0.8 }),
    kf(slSquat({ hipR: 10, hipAbdR: 60, kneeR: 4 }), 'L', { hold: 0.3, move: 0.8 }),
    kf(P({ hipR: 30, kneeR: 50 }), 'L', { hold: 0.1, move: 0.8 }),
    kf(slSquat({ hipR: -50, kneeR: 4, spine: 40 }), 'L', { hold: 0.3, move: 0.8 }),
    kf(P({ hipR: 30, kneeR: 50 }), 'L', { hold: 0.1 }),
  ],
});
def('cossack-squat', 'Cossack squat', {
  view: 'front',
  keyframes: rep3(P(both({ hipAbd: 30, hipRot: -20, shoulder: 60, elbow: 30 })),
    P({ hipL: 110, kneeL: 130, ankleL: 36, hipAbdL: 30, hipRotL: -20, hipR: 10, kneeR: 0, ankleR: 30, hipAbdR: 54, hipRotR: -40, spine: 24, shoulderL: 90, shoulderR: 90, elbowL: 60, elbowR: 60 }),
    { contact: 'L+Rheel' }),
});
def('curtsy-lunge', 'Curtsy lunge', {
  view: 'front',
  keyframes: rep3(P(both({ shoulder: 20, elbow: 60 })), P({ hipL: 80, kneeL: 90, ankleL: 26, hipR: -10, hipAbdR: -24, hipRotR: 20, kneeR: 90, spine: 10, shoulderL: 40, shoulderR: 40, elbowL: 70, elbowR: 70 }), { contact: 'L+Rtoe' }),
});
def('adductor-squeeze', 'Adductor squeeze', {
  loop: true, thumb: 0, implement: { kind: 'medball', at: 'knees' },
  keyframes: breathe(lieFlat(P(both({ hip: 60, knee: 104, ankle: 10, hipAbd: 2, shoulder: 10, shoulderAbd: 20 }))), 'feet', { hipAbdL: -1, hipAbdR: -1 }),
});
def('athletic-stance-hold', 'Athletic stance', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: breathe(P(both({ hip: 44, knee: 52, ankle: 24, hipAbd: 18, shoulder: 30, elbow: 70 }), { spine: 30, neck: -18 }), 'feet', { spine: -1 }),
});

// Sprint drills and conditioning extras -------------------------------------
/** Leaning into a wall at ~45°, hands on it, driving one knee up at a time. */
const wallLeanBase = (up) => ({ spine: 44, neck: -6, ...both({ shoulder: 96, elbow: 4, shoulderAbd: 8, wrist: -60 }), ...(up === 'L'
  ? { hipL: 96, kneeL: 104, ankleL: 14, hipR: -44, kneeR: 4, ankleR: -30 } : { hipR: 96, kneeR: 104, ankleR: 14, hipL: -44, kneeL: 4, ankleL: -30 }) });
def('acceleration-wall-drill', 'Acceleration wall drill', {
  thumb: 0, loop: true, fixture: { kind: 'wall', at: 70 },
  keyframes: [kf(P(wallLeanBase('L')), 'Rtoe', { hold: 0.35, move: 0.16 }), kf(P(wallLeanBase('R')), 'Ltoe', { hold: 0.35, move: 0.16 })],
});
def('jump-squat-dumbbells', 'Dumbbell jump squat', {
  view: 'three-quarter', thumb: 2, implement: { kind: 'dumbbells', at: 'hands' },
  keyframes: [
    kf(P(both({ hipAbd: 8, shoulder: 0, shoulderAbd: 10, elbow: 2 })), 'feet', { hold: 0.3, move: 0.4 }),
    kf(P(both({ hip: 80, knee: 86, ankle: 30, hipAbd: 10, shoulder: 30, shoulderAbd: 10, elbow: 2 }), { spine: 36, neck: -20 }), 'feet', { hold: 0.05, move: 0.2 }),
    kf(P(both({ ankle: -32, knee: 6, hipAbd: 8, shoulder: 0, shoulderAbd: 10, elbow: 2 }), { lift: 20 }), 'air', { hold: 0.05, move: 0.24 }),
    kf(P(both({ hip: 64, knee: 74, ankle: 28, hipAbd: 10, shoulder: 20, shoulderAbd: 10, elbow: 2 }), { spine: 30, neck: -16 }), 'feet', { hold: 0.3, move: 0.5 }),
    kf(P(both({ hipAbd: 8, shoulder: 0, shoulderAbd: 10, elbow: 2 })), 'feet', { hold: 0.1 }),
  ],
});
/** Bear hold: hands and toes down, knees hovering just off the floor. */
const bearHold = handsAbove(P(both({ hip: 94, knee: 94, ankle: 34, shoulder: 88, elbow: 0, shoulderAbd: 8, wrist: -85 }), { neck: -14 }), 0, 40, 110);
def('bear-hold', 'Bear crawl hold', { view: 'three-quarter', loop: true, thumb: 0, keyframes: breathe(bearHold, 'hands+Ltoe+Rtoe', { neck: -2 }) });
def('single-leg-pogo', 'Single-leg ankle hops', {
  view: 'three-quarter', loop: true, thumb: 1,
  keyframes: [
    kf(P({ kneeL: 10, ankleL: 12, hipR: 40, kneeR: 80, shoulderL: 16, shoulderR: 16, elbowL: 80, elbowR: 80 }), 'L', { move: 0.15 }),
    kf(P({ kneeL: 4, ankleL: -34, hipR: 40, kneeR: 80, shoulderL: 16, shoulderR: 16, elbowL: 80, elbowR: 80, lift: 6 }), 'air', { move: 0.15 }),
  ],
});
/** Shuttle turn: sprint in, drop low and touch the line, turn and sprint back. */
def('shuttle-turn', 'Shuttle turn', {
  view: 'three-quarter', thumb: 2,
  keyframes: [
    kf(P({ spine: 20, hipL: 60, kneeL: 40, ankleL: 10, hipR: -16, kneeR: 90, ankleR: -24, ...armsSwing(-40, 50, 88), lift: 4 }), 'air', { move: 0.2 }),
    kf(P({ spine: 12, hipL: 50, kneeL: 40, ankleL: 20, hipR: -10, kneeR: 60, ankleR: -24, ...armsSwing(20, -10, 70) }), 'L', { move: 0.22, travel: [30, 0] }),
    kf(flatHands(reach(P({ spine: 60, neck: -20, turn: 60, hipL: 100, kneeL: 110, ankleL: 34, hipAbdL: 20, hipR: 60, kneeR: 80, ankleR: 20, hipAbdR: 30, shoulderR: 30, elbowR: 60 }), 'L',
      (sk) => [sk.L.ankle[0] + 18, sk.L.ankle[1] + 2.9, sk.L.ankle[2] + 12])), 'feet', { hold: 0.12, move: 0.26 }),
    kf(P({ turn: 180, spine: 40, neck: -10, hipL: 10, kneeL: 12, ankleL: -30, hipR: 94, kneeR: 108, ankleR: 10, ...armsSwing(60, -50, 88) }), 'Ltoe', { move: 0.2 }),
    kf(P({ turn: 180, spine: 30, neck: -8, hipR: -8, kneeR: 12, ankleR: -30, hipL: 94, kneeL: 104, ankleL: 8, ...armsSwing(-50, 64, 88), lift: 2 }), 'Rtoe', { hold: 0.3, travel: [36, 0] }),
  ],
});

// Machines and water ----------------------------------------------------------
/** Seated pedalling: each ankle traces the crank circle; hands on the bars. */
export const CRANK = { f: 20, down: 58, r: 17 };
export const pedal = (deg, { lean = 36, stand = false } = {}) => {
  let q = P({ spine: lean, neck: -24 });
  const at = (a) => (sk) => {
    const c = add(add(sk.pelvis, apply(sk.root, [1, 0, 0]), CRANK.f + (stand ? 6 : 0)), [0, -CRANK.down - (stand ? 10 : 0), 0]);
    return add(c, [Math.cos((a * Math.PI) / 180) * CRANK.r, Math.sin((a * Math.PI) / 180) * CRANK.r, 0]);
  };
  q = reachLeg(q, 'L', (sk) => { const t = at(deg)(sk); return [t[0], t[1], sk.L.hip[2]]; });
  q = reachLeg(q, 'R', (sk) => { const t = at(deg + 180)(sk); return [t[0], t[1], sk.R.hip[2]]; });
  q.ankleL = 4 - Math.sin((deg * Math.PI) / 180) * 12;
  q.ankleR = 4 - Math.sin(((deg + 180) * Math.PI) / 180) * 12;
  return reachBoth(q, (sk) => add(add(sk.pelvis, apply(sk.root, [1, 0, 0]), 52), [0, stand ? 30 : 22, 10]), (sk) => add(add(sk.pelvis, apply(sk.root, [1, 0, 0]), 52), [0, stand ? 30 : 22, -10]));
};
def('cycling', 'Cycling', {
  loop: true, thumb: 0, fixture: { kind: 'bike' },
  keyframes: [0, 45, 90, 135, 180, 225, 270, 315].map((d, i) => kf(pedal(-d), 'seat', { move: 0.08, ...(i === 0 ? { surface: 28 } : {}) })),
});
def('cycling-standing', 'Cycling out of the saddle', {
  loop: true, thumb: 0, fixture: { kind: 'bike', seatDrop: 24, seatBack: 12 },
  keyframes: [0, 45, 90, 135, 180, 225, 270, 315].map((d, i) => kf({ ...pedal(-d, { lean: 30, stand: true }), bend: Math.sin((d * Math.PI) / 180) * 6 }, 'seat', { move: 0.1, ...(i === 0 ? { surface: 28 } : {}) })),
});
/** Rowing erg: catch → legs → body swing → arms → recover. Feet stay on the foot plate. */
export const rowAt = (knee, lean, handleIn) => {
  // Seat and foot plate at the same height: solve the hips so the ankles
  // stay level with the seat through the whole stroke.
  let q = P({ spine: lean, neck: -6, ...both({ knee, hip: 60, ankle: knee * 0.36, hipAbd: 8 }) });
  let best = null;
  for (let h = 0; h <= 170; h += 0.5) {
    const sk = skeleton({ ...q, hipL: h, hipR: h });
    if (sk.L.knee[1] < sk.pelvis[1]) continue; // knees stay up, as on a real rower
    const e = Math.abs(sk.L.ankle[1] - sk.pelvis[1] + 2);
    if (!best || e < best.e) best = { h, e };
  }
  q.hipL = best.h; q.hipR = best.h;
  const handle = handleIn
    ? (s2) => (sk) => add(add(add(sk.pelvis, apply(sk.trunk, [0, 1, 0]), 24), apply(sk.trunk, [1, 0, 0]), 11), apply(sk.root, [0, 0, 1]), s2 * 6)
    : (s2) => (sk) => add([sk.L.ankle[0] + 14 - (knee < 30 ? 0 : 6), sk.pelvis[1] + 16, 0], apply(sk.root, [0, 0, 1]), s2 * 6);
  return reachBoth(q, handle(1), handle(-1), { rot: ROTS, prefer: (sk, sd) => -sk[sd].elbow[1] });
};
def('rowing-erg', 'Rowing machine', {
  loop: true, thumb: 0, fixture: { kind: 'rower' }, implement: { kind: 'cable', at: 'hands', to: [22, 18, 0] },
  keyframes: [
    kf(rowAt(104, 22, false), 'seat+feet', { hold: 0.05, move: 0.3 }),
    kf(rowAt(50, 20, false), 'seat+feet', { move: 0.22 }),
    kf(rowAt(4, -14, false), 'seat+feet', { move: 0.2 }),
    kf(rowAt(4, -18, true), 'seat+feet', { hold: 0.1, move: 0.25 }),
    kf(rowAt(4, 20, false), 'seat+feet', { move: 0.45 }),
  ].map((k) => ({ ...k, surface: 30 })),
});
/** Freestyle: prone in the water, one arm reaching, the other pulling; body rolls. */
const swimBase = { spine: 92, neck: -8, ...both({ ankle: -80, hip: 0 }) };
const stroke = [
  P(swimBase, { shoulderL: 178, elbowL: 4, shoulderR: 20, shoulderAbdR: 10, elbowR: 30, twist: 25, neckTurn: 0, hipL: 6, hipR: -6 }),
  P(swimBase, { shoulderL: 120, elbowL: 50, shoulderR: -20, shoulderAbdR: 40, elbowR: 90, twist: 30, neckTurn: -50, hipL: -6, hipR: 6 }),
  P(swimBase, { shoulderL: 60, elbowL: 70, shoulderR: 110, shoulderAbdR: 30, elbowR: 100, twist: 10, neckTurn: -20, hipL: 6, hipR: -6 }),
  P(swimBase, { shoulderL: 20, shoulderAbdL: 10, elbowL: 30, shoulderR: 178, elbowR: 4, twist: -25, hipL: -6, hipR: 6 }),
];
def('swim-freestyle', 'Freestyle swimming', {
  path: { kind: 'line', length: 220, speed: 90 },
  loop: true, thumb: 0, fixture: { kind: 'water', level: 12 },
  keyframes: [...stroke, ...stroke.map(mirrorKit)].map((p) => kf(p, 'water', { move: 0.22 })),
});
const kickBase = { spine: 90, neck: -20, ...both({ shoulder: 176, elbow: 4, shoulderAbd: 10, ankle: -80 }) };
def('swim-kick-board', 'Kicking with a board', {
  loop: true, thumb: 0, fixture: { kind: 'water', level: 12 }, implement: { kind: 'kickboard', at: 'hands' },
  keyframes: [kf(P(kickBase, { hipL: 14, kneeL: 20, hipR: -12, kneeR: 4 }), 'water', { move: 0.2 }), kf(P(kickBase, { hipR: 14, kneeR: 20, hipL: -12, kneeL: 4 }), 'water', { move: 0.2 })],
});
/** Treading water: upright, eggbeater legs, sculling hands. */
const tread = (a) => P({ spine: 8, neck: -6, hipL: 70, kneeL: 90, hipAbdL: 40, hipRotL: -30 * a, hipR: 70, kneeR: 90, hipAbdR: 40, hipRotR: 30 * a,
  shoulderL: 30, shoulderAbdL: 50, elbowL: 40, shoulderR: 30, shoulderAbdR: 50, elbowR: 40, wristL: 20 * a, wristR: -20 * a });
def('treading-water', 'Treading water', {
  view: 'front', loop: true, thumb: 0, fixture: { kind: 'water', level: 58 },
  keyframes: [kf(tread(1), 'water', { move: 0.3 }), kf(tread(-1), 'water', { move: 0.3 })],
});

// A few more exact moves ------------------------------------------------------
def('shoulder-pass-through', 'Band shoulder pass-through', {
  view: 'three-quarter', implement: { kind: 'band', at: 'hands' }, thumb: 1,
  keyframes: [
    kf(P(both({ shoulder: 20, shoulderAbd: 40, elbow: 0 })), 'feet', { hold: 0.2, move: 0.8 }),
    kf(P(both({ shoulder: 180, shoulderAbd: 50, elbow: 0 })), 'feet', { move: 0.8 }),
    kf(P(both({ shoulder: -30, shoulderAbd: 60, elbow: 0 })), 'feet', { hold: 0.2, move: 0.8 }),
    kf(P(both({ shoulder: 180, shoulderAbd: 50, elbow: 0 })), 'feet', { move: 0.8 }),
    kf(P(both({ shoulder: 20, shoulderAbd: 40, elbow: 0 })), 'feet', { hold: 0.1 }),
  ],
});
def('sissy-squat', 'Assisted sissy squat', {
  keyframes: rep3(P({ shoulderL: 40, elbowL: 20 }), P(both({ hip: -10, knee: 110, ankle: -30 }), { spine: -30, shoulderL: 70, elbowL: 10 }), { contact: 'Ltoe+Rtoe', down: 1.2, upT: 1.0 }),
});
def('spanish-squat', 'Spanish squat', {
  view: 'three-quarter', implement: { kind: 'band', at: 'hands', to: [-60, 40, 0] },
  keyframes: rep3(P(both({ shoulder: 60, elbow: 10 })), P(both({ hip: 94, knee: 100, ankle: 6, hipAbd: 10, shoulder: 80, elbow: 10 }), { spine: 8 }), { holdLow: 0.8 }),
});
def('seated-arm-swing', 'Seated sprint arm drill', {
  loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 90, knee: 0, ankle: 10 }), armsSwing(-40, 60, 88), { spine: 4 }), 'air', { move: 0.22 }),
    kf(P(both({ hip: 90, knee: 0, ankle: 10 }), armsSwing(60, -40, 88), { spine: 4 }), 'air', { move: 0.22 }),
  ],
});
def('lateral-line-hops', 'Lateral line hops', {
  view: 'front', loop: true, thumb: 1,
  keyframes: [
    kf(P(both({ knee: 16, ankle: 16, shoulder: 20, elbow: 80 }), { spine: 10 }), 'feet', { move: 0.14 }),
    kf(P(both({ knee: 8, ankle: -30, shoulder: 20, elbow: 80 }), { spine: 10, lift: 8 }), 'air', { move: 0.14, travel: [0, -24] }),
    kf(P(both({ knee: 16, ankle: 16, shoulder: 20, elbow: 80 }), { spine: 10 }), 'feet', { move: 0.14, travel: [0, -12] }),
    kf(P(both({ knee: 8, ankle: -30, shoulder: 20, elbow: 80 }), { spine: 10, lift: 8 }), 'air', { move: 0.14, travel: [0, 24] }),
  ],
});
def('backward-overhead-toss', 'Backward overhead toss', {
  implement: mb, thumb: 1,
  keyframes: [
    kf(P(both({ hip: 92, knee: 86, ankle: 30, hipAbd: 12, shoulder: 60, elbow: 4 }), { spine: 60, neck: -20 }), 'feet', { hold: 0.3, move: 0.3 }),
    kf(P(both({ ankle: -30, hipAbd: 10, shoulder: 200, elbow: 4 }), { spine: -26, neck: 20 }), 'Ltoe+Rtoe', { hold: 0.3, move: 0.6 }),
    kf(P(both({ hip: 92, knee: 86, ankle: 30, hipAbd: 12, shoulder: 60, elbow: 4 }), { spine: 60, neck: -20 }), 'feet', { hold: 0.1 }),
  ],
});
def('plate-pinch-hold', 'Plate pinch hold', { view: 'three-quarter', loop: true, thumb: 0, implement: { kind: 'dumbbells', at: 'hands' }, keyframes: breathe(P(both({ shoulderAbd: 12, elbow: 2 })), 'feet', { spine: -1 }) });

// Weightlifting technique, powerlifting and conditioning circuits ------------
const PVC = { kind: 'barbell', at: 'hands', pvc: true };
/** Snatch grip: hands wide, the bar over mid-foot. */
const wide = (p) => barOverMidfoot(p, 36);
const snatchHang = wide(P(both({ hip: 40, knee: 22, ankle: 10, hipAbd: 8 }), { spine: 34, neck: -12 }));
const snatchBelowKnee = wide(P(both({ hip: 70, knee: 50, ankle: 20, hipAbd: 8 }), { spine: 50, neck: -20 }));
const snatchTriple = wide(P(both({ ankle: -30, hipAbd: 8 }), { spine: -6, neck: -4 }));
const ohsBottom = P(both({ hip: 116, knee: 124, ankle: 38, hipAbd: 17, hipRot: -17, shoulder: 198, shoulderAbd: 30, elbow: 0 }), { spine: 22, neck: -10 });
const ohsTop = P(both({ hipAbd: 10, hipRot: -10, shoulder: 176, shoulderAbd: 32, elbow: 0 }));
/** PVC progression: overhead squat, snatch balance, hang snatch, then from mid-shin. */
def('pvc-snatch-progression', 'PVC snatch progression', {
  view: 'three-quarter', implement: PVC, thumb: 6,
  keyframes: [
    kf(ohsTop, 'feet', { hold: 0.2, move: 0.9 }), kf(ohsBottom, 'feet', { hold: 0.3, move: 0.8 }), kf(ohsTop, 'feet', { hold: 0.2, move: 0.5 }),
    kf(P(both({ hip: 10, knee: 16, ankle: 6, hipAbd: 10, shoulder: 150, shoulderAbd: 34, elbow: 30 })), 'feet', { move: 0.3 }),
    kf(ohsBottom, 'feet', { hold: 0.3, move: 0.7 }), kf(ohsTop, 'feet', { hold: 0.2, move: 0.5 }),
    kf(snatchHang, 'feet', { hold: 0.2, move: 0.16 }), kf(snatchTriple, 'Ltoe+Rtoe', { move: 0.2 }), kf(ohsBottom, 'feet', { hold: 0.3, move: 0.7 }), kf(ohsTop, 'feet', { hold: 0.2, move: 0.5 }),
    kf(snatchBelowKnee, 'feet', { hold: 0.2, move: 0.3 }), kf(snatchHang, 'feet', { move: 0.14 }), kf(snatchTriple, 'Ltoe+Rtoe', { move: 0.2 }), kf(ohsBottom, 'feet', { hold: 0.3, move: 0.7 }), kf(ohsTop, 'feet', { hold: 0.3 }),
  ],
});
/** Snatch-grip pull: push the floor away, bar close past the knees, finish tall with a shrug — no pull under. */
def('snatch-grip-pull', 'Snatch-grip pull', {
  view: 'three-quarter', implement: { kind: 'barbell', at: 'hands' }, thumb: 2,
  keyframes: [
    kf(snatchBelowKnee, 'feet', { hold: 0.3, move: 0.4 }),
    kf(snatchHang, 'feet', { move: 0.2 }),
    kf(P(snatchTriple, { spine: -8 }), 'Ltoe+Rtoe', { hold: 0.3, move: 0.6 }),
    kf(snatchHang, 'feet', { move: 0.5 }),
    kf(snatchBelowKnee, 'feet', { hold: 0.2 }),
  ],
});
/** Stick mobility: deep squat hold, pass-throughs, ankle rocks, then a paused overhead squat. */
def('stick-mobility-complex', 'Stick mobility complex', {
  view: 'three-quarter', implement: PVC, thumb: 1,
  keyframes: [
    kf(P(both({ shoulder: 20, shoulderAbd: 30, elbow: 0 })), 'feet', { hold: 0.2, move: 0.8 }),
    kf(P(both({ hip: 118, knee: 132, ankle: 40, hipAbd: 20, hipRot: -20, shoulder: 60, shoulderAbd: 30, elbow: 10 }), { spine: 30, neck: -20 }), 'feet', { hold: 1.2, move: 0.8 }),
    kf(P(both({ shoulder: 20, shoulderAbd: 40, elbow: 0 })), 'feet', { move: 0.8 }),
    kf(P(both({ shoulder: 180, shoulderAbd: 50, elbow: 0 })), 'feet', { move: 0.8 }),
    kf(P(both({ shoulder: -30, shoulderAbd: 60, elbow: 0 })), 'feet', { hold: 0.2, move: 0.8 }),
    kf(P(both({ shoulder: 180, shoulderAbd: 50, elbow: 0 })), 'feet', { move: 0.8 }),
    kf(P({ hipL: 60, kneeL: 90, ankleL: 40, hipR: -10, kneeR: 90, ankleR: -40, shoulderL: 30, shoulderR: 30, shoulderAbdL: 30, shoulderAbdR: 30 }), 'L+Rknee', { hold: 0.5, move: 0.8 }),
    kf(ohsTop, 'feet', { move: 0.8 }),
    kf(ohsBottom, 'feet', { hold: 2, move: 1 }),
    kf(ohsTop, 'feet', { hold: 0.3 }),
  ],
});
def('goblet-squat-pause', 'Paused goblet squat', {
  view: 'three-quarter', implement: { kind: 'goblet', at: 'chest' },
  keyframes: rep3(goblet(squatStand), goblet(P(both({ hip: 114, knee: 122, ankle: 36, hipAbd: 18, hipRot: -18 }), { spine: 34, neck: -26 })), { holdLow: 2 }),
});
def('rdl-dumbbells', 'Dumbbell Romanian deadlift', {
  implement: { kind: 'dumbbells', at: 'hands' },
  keyframes: [
    ...tween(kf(rdlTop, 'feet', { hold: 0.3, move: 1.1 }), kf(rdlLow, 'feet'), 2, barOverMidfoot),
    ...tween(kf(rdlLow, 'feet', { hold: 0.15, move: 0.9 }), kf(rdlTop, 'feet'), 2, barOverMidfoot),
    kf(rdlTop, 'feet', { hold: 0.1 }),
  ],
});
/** Inchworm: fold, walk the hands out to a plank, walk the feet in, stand. */
const inchworm = [
  kf(P(), 'feet', { hold: 0.2, move: 0.8 }),
  kf(handsToFloor(P(both({ shoulder: 100, elbow: 0, knee: 30, hip: 20 }), { spine: 90, neck: -10 }), 40, 150), 'hands+Ltoe+Rtoe', { move: 0.8 }),
  kf(P(both({ shoulder: 90, elbow: 0, ankle: -30 }), { spine: 90, neck: -10 }), 'hands+Ltoe+Rtoe', { hold: 0.3, move: 0.9, travel: [60, 0] }),
  kf(handsToFloor(P(both({ shoulder: 100, elbow: 0, knee: 30, hip: 20 }), { spine: 90, neck: -10 }), 40, 150), 'hands+Ltoe+Rtoe', { move: 0.8, travel: [60, 0] }),
  kf(P(), 'feet', { hold: 0.2 }),
];
def('movement-screen', 'Movement quality circuit', {
  view: 'three-quarter', thumb: 1,
  keyframes: [
    ...lib.get('squat-bodyweight').keyframes,
    ...inchworm,
    ...lib.get('walking-lunge').keyframes.slice(0, 4),
    ...lib.get('bear-crawl').keyframes,
  ],
});
def('emom-squat-pushup-situp', 'Squats, push-ups, sit-ups', {
  view: 'three-quarter', thumb: 1,
  keyframes: [...lib.get('squat-bodyweight').keyframes, ...lib.get('push-up').keyframes, ...lib.get('sit-up').keyframes],
});

export const STRENGTH = lib.patterns;
