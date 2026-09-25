/**
 * Individual and endurance sport movement patterns (see ../poses.js for the
 * format and ../rig3d.js for every angle convention): swimming and water
 * polo, track and field, cycling, rowing, combat sports, gymnastics, cheer,
 * dance, step, colour guard and marching band.
 */
import { BONES, add, apply, keyframeAt, len, placeKeyframes, skeleton, sub } from '../rig3d.js';
import { ATHLETIC, P, STAND, both, kf, library, reach, reachBoth, side, solve, toeDown } from './kit.js';

const lib = library();
const def = lib.def;

// ── Local helpers ────────────────────────────────────────────────────────

/** Leg IK in the sagittal plane: hip flexion + knee so side s's ankle lands on target(skeleton). */
function legReach(p, s, target) {
  const T = BONES.thigh, S = BONES.shin;
  let q = { ...p };
  for (let round = 0; round < 3; round++) {
    const sk = skeleton(q);
    const goal = target(sk);
    const d = Math.min(Math.max(len(sub(goal, sk[s].hip)), 10), T + S - 0.2);
    const cosK = (T * T + S * S - d * d) / (2 * T * S);
    q[`knee${s}`] = 180 - (Math.acos(Math.max(-1, Math.min(1, cosK))) * 180) / Math.PI;
    const err = (h) => len(sub(skeleton({ ...q, [`hip${s}`]: h })[s].ankle, target(skeleton({ ...q, [`hip${s}`]: h }))));
    let best = q[`hip${s}`], bestErr = err(best);
    for (let h = -45; h <= 150; h += 3) { const e = err(h); if (e < bestErr) { bestErr = e; best = h; } }
    for (const step of [2, 1, 0.5, 0.25, 0.1]) {
      for (const c of [best + step, best - step]) { const e = err(c); if (e < bestErr) { bestErr = e; best = c; } }
    }
    q[`hip${s}`] = best;
  }
  return q;
}

/** A point relative to the pelvis in body axes (x forward, y up, z left) — for IK targets. */
const rel = (x, y, z = 0) => (sk) => add(add(add(sk.pelvis, apply(sk.root, [1, 0, 0]), x), [0, y, 0]), apply(sk.root, [0, 0, 1]), z);

/** Shift a keyframe list so every pose is built from a shared base. */
const withBase = (base, parts) => P(base, parts);

// ── Swimming (fixture water, contact water) ──────────────────────────────

/** Freestyle arm phases for a prone swimmer: entry, catch, push, exit, two recovery points. */
export const FREE_ARM = [
  { shoulder: 176, shoulderAbd: 10, elbow: 6, shoulderRot: 0 },
  { shoulder: 118, shoulderAbd: 16, elbow: 70, shoulderRot: 35 },
  { shoulder: 55, shoulderAbd: 14, elbow: 55, shoulderRot: 20 },
  { shoulder: 8, shoulderAbd: 16, elbow: 18, shoulderRot: 0 },
  { shoulder: -30, shoulderAbd: 62, elbow: 70, shoulderRot: -20 },
  { shoulder: 110, shoulderAbd: 92, elbow: 95, shoulderRot: -10 },
];

export function freestyle({ spine = 88, neck = -20, neckTurns = [0, 0, 0, 0, 0, 0], kick = 12, roll = 22 } = {}) {
  const frames = [];
  for (let i = 0; i < 6; i++) {
    const L = FREE_ARM[i], R = FREE_ARM[(i + 3) % 6];
    const flutter = i % 2 === 0 ? 1 : -1;
    frames.push(kf(P(side('L', L), side('R', R), {
      spine, neck, neckTurn: neckTurns[i], twist: [roll, roll * 0.5, -roll * 0.5, -roll, -roll * 0.5, roll * 0.5][i],
      hipL: flutter * kick * 0.6, kneeL: flutter > 0 ? 18 : 4, ankleL: -45, hipR: -flutter * kick * 0.6, kneeR: flutter > 0 ? 4 : 18, ankleR: -45,
    }), 'water', { move: 0.22 }));
  }
  return frames;
}

def('swim-headup-freestyle', 'Head-up freestyle', {
  loop: true, thumb: 1,
  fixture: { kind: 'water', level: 10 },
  keyframes: freestyle({ spine: 72, neck: -52, roll: 12, kick: 16 }),
});

def('swim-sighting-freestyle', 'Freestyle with sighting', {
  loop: true, thumb: 0,
  fixture: { kind: 'water', level: 7 },
  keyframes: freestyle({ spine: 86, neck: -20 }).map((k, i) => (i === 0 || i === 1 ? { ...k, pose: { ...k.pose, neck: -44 } } : k)),
});

const streamline = P(both({ shoulder: 180, shoulderAbd: 2, elbow: 0, ankle: -50 }), { spine: 90, neck: 0 });
def('swim-streamline-dolphin', 'Streamline dolphin kick', {
  loop: true, thumb: 0,
  fixture: { kind: 'water', level: 22 },
  keyframes: [
    kf(P(streamline, both({ hip: 12, knee: 30 }), { spine: 94 }), 'water', { move: 0.28 }),
    kf(P(streamline, both({ hip: -10, knee: 2 }), { spine: 86 }), 'water', { move: 0.28 }),
  ],
});

def('swim-push-off', 'Push off the wall into streamline', {
  fixture: { kind: 'water', level: 24 },
  keyframes: [
    kf(P(both({ shoulder: 150, elbow: 60, hip: 120, knee: 120, ankle: 10 }), { spine: 60, neck: -10 }), 'water', { hold: 0.4, move: 0.35 }),
    kf(P(streamline, both({ hip: 0, knee: 0 })), 'water', { hold: 0.2, move: 0.6, travel: [45, 0] }),
    kf(P(streamline, both({ hip: 8, knee: 20 }), { spine: 92 }), 'water', { hold: 0.4, travel: [30, 0] }),
  ],
});

def('swim-flip-turn', 'Flip turn', {
  fixture: { kind: 'water', level: 16 },
  keyframes: [
    kf(P(side('L', FREE_ARM[3]), side('R', FREE_ARM[3]), { spine: 90, neck: -10 }, both({ ankle: -45 })), 'water', { hold: 0.1, move: 0.35 }),
    kf(P(both({ shoulder: 30, elbow: 40, hip: 120, knee: 130, ankle: -30 }), { spine: 100, neck: 40 }), 'water', { move: 0.35, surface: -22 }),
    kf(P(both({ shoulder: 180, elbow: 20, hip: 72, knee: 104, ankle: 10 }), { spine: -90, neck: 0 }), 'water', { hold: 0.25, move: 0.4, surface: -34 }),
    kf(P(both({ shoulder: 180, shoulderAbd: 2, elbow: 0, ankle: -45 }), { spine: -90 }), 'water', { hold: 0.35, travel: [-40, 0], surface: -30 }),
  ],
});

def('swim-float', 'Face-down float', {
  loop: true, thumb: 0,
  fixture: { kind: 'water', level: 8 },
  keyframes: [
    kf(P(both({ shoulder: 170, shoulderAbd: 16, elbow: 8, ankle: -40 }), { spine: 88, neck: -8 }), 'water', { hold: 0.6, move: 1.4 }),
    kf(P(both({ shoulder: 170, shoulderAbd: 18, elbow: 10, ankle: -40, hip: 4, knee: 6 }), { spine: 86, neck: -8 }), 'water', { hold: 0.6, move: 1.4 }),
  ],
});

def('swim-rhythmic-breathing', 'Rhythmic breathing', {
  loop: true, thumb: 1,
  fixture: { kind: 'water', level: 8 },
  keyframes: [
    kf(P(both({ shoulder: 170, shoulderAbd: 16, elbow: 8, ankle: -40 }), { spine: 88, neck: 6 }), 'water', { hold: 1.0, move: 0.5 }),
    kf(P(side('L', { shoulder: 170, shoulderAbd: 16, elbow: 8 }), side('R', { shoulder: 170, shoulderAbd: 16, elbow: 8 }), both({ ankle: -40 }), { spine: 88, neck: -14, neckTurn: 70, twist: 18 }), 'water', { hold: 0.6, move: 0.5 }),
  ],
});

/** Track start: off the pool deck's edge (26 above the water) into the pool ahead. */
def('swim-track-start', 'Track start dive', {
  fixture: { kind: 'box', from: -22, to: 26, top: 26 },
  keyframes: [
    kf(toeDown(P({ spine: 88, neck: 30, hipL: 118, kneeL: 92, ankleL: 30, hipR: 52, kneeR: 110, ankleR: 0, shoulderL: 100, shoulderR: 100, elbowL: 20, elbowR: 20 }), 'R'), 'L', { surface: 26, hold: 0.6, move: 0.3 }),
    kf(P({ spine: 60, neck: 10, hipL: 60, kneeL: 30, ankleL: -20, hipR: -10, kneeR: 30, ankleR: -40, shoulderL: 150, shoulderR: 150, elbowL: 10, elbowR: 10 }), 'L', { surface: 26, move: 0.3 }),
    kf(P(both({ shoulder: 180, shoulderAbd: 2, elbow: 0, hip: 0, knee: 0, ankle: -45 }), { spine: 78, neck: 10, lift: 30 }), 'air', { move: 0.4, travel: [70, 0] }),
    kf(P(both({ shoulder: 180, shoulderAbd: 2, elbow: 0, hip: -8, knee: 0, ankle: -45 }), { spine: 100, neck: 10, lift: 0 }), 'air', { hold: 0.4, travel: [50, 0] }),
  ],
});

// Water polo: upright in the water, eggbeater legs.
export const EGG_A = { hipL: 90, hipAbdL: 40, hipRotL: -30, kneeL: 100, ankleL: 20, hipR: 80, hipAbdR: 40, hipRotR: -30, kneeR: 60, ankleR: 20 };
export const EGG_B = { hipL: 80, hipAbdL: 40, hipRotL: -30, kneeL: 60, ankleL: 20, hipR: 90, hipAbdR: 40, hipRotR: -30, kneeR: 100, ankleR: 20 };

def('wp-eggbeater-ball-overhead', 'Eggbeater with the ball overhead', {
  view: 'three-quarter', loop: true, thumb: 0,
  fixture: { kind: 'water', level: 52 },
  implement: { kind: 'ball', at: 'hands' },
  keyframes: [
    kf(P(EGG_A, both({ shoulder: 165, shoulderAbd: 20, elbow: 30 }), { spine: 10 }), 'water', { move: 0.45 }),
    kf(P(EGG_B, both({ shoulder: 165, shoulderAbd: 20, elbow: 30 }), { spine: 10 }), 'water', { move: 0.45 }),
  ],
});

def('wp-vertical-lunge', 'Vertical out of the water', {
  view: 'three-quarter',
  fixture: { kind: 'water', level: 52 },
  keyframes: [
    kf(P(EGG_A, both({ shoulder: 40, shoulderAbd: 50, elbow: 20 }), { spine: 12 }), 'water', { hold: 0.2, move: 0.4 }),
    kf(P(EGG_B, both({ shoulder: 30, shoulderAbd: 60, elbow: 20 }), { spine: 12 }), 'water', { move: 0.35 }),
    kf(P(both({ hip: 20, knee: 20, ankle: -40, hipAbd: 20 }), side('L', { shoulder: 175, shoulderAbd: 10, elbow: 4 }), side('R', { shoulder: 20, shoulderAbd: 60, elbow: 20 }), { spine: 0, lift: 0 }), 'water', { hold: 0.4, move: 0.6, travel: [0, 0] }),
  ],
});

/** Overhand water-polo throw from an upright eggbeater: cock, rotate, release, follow through. */
def('wp-shot', 'Water polo shot', {
  view: 'three-quarter',
  fixture: { kind: 'water', level: 44 },
  implement: { kind: 'ball', at: 'R' },
  keyframes: [
    kf(P(EGG_A, side('R', { shoulder: 150, shoulderAbd: 70, shoulderRot: -70, elbow: 95 }), side('L', { shoulder: 80, shoulderAbd: 20, elbow: 20 }), { spine: -8, twist: -35, turn: -20 }), 'water', { hold: 0.35, move: 0.25 }),
    kf(P(EGG_B, side('R', { shoulder: 165, shoulderAbd: 30, shoulderRot: 10, elbow: 20 }), side('L', { shoulder: 40, shoulderAbd: 30, elbow: 40 }), { spine: 8, twist: 15, turn: -10 }), 'water', { move: 0.3 }),
    kf(P(EGG_A, side('R', { shoulder: 70, shoulderAbd: 20, shoulderRot: 40, elbow: 10 }), side('L', { shoulder: 10, shoulderAbd: 30, elbow: 40 }), { spine: 25, twist: 30, turn: 0 }), 'water', { hold: 0.35 }),
  ],
});

def('wp-pass', 'Dry pass from the water', {
  view: 'three-quarter',
  fixture: { kind: 'water', level: 48 },
  implement: { kind: 'ball', at: 'R' },
  keyframes: [
    kf(P(EGG_A, side('R', { shoulder: 160, shoulderAbd: 40, shoulderRot: -40, elbow: 70 }), side('L', { shoulder: 60, shoulderAbd: 30, elbow: 20 }), { spine: -4, twist: -20 }), 'water', { hold: 0.3, move: 0.35 }),
    kf(P(EGG_B, side('R', { shoulder: 130, shoulderAbd: 20, shoulderRot: 20, elbow: 5, wrist: 30 }), side('L', { shoulder: 40, shoulderAbd: 30, elbow: 30 }), { spine: 6, twist: 10 }), 'water', { hold: 0.35 }),
  ],
});

// Swimming start/dive approach on land.
def('dive-hurdle', 'Springboard approach and hurdle', {
  keyframes: [
    kf(P(STAND, both({ shoulder: 0, elbow: 10 })), 'feet', { hold: 0.2, move: 0.45 }),
    kf(P({ hipL: 90, kneeL: 90, ankleL: 20, hipR: 0, kneeR: 0, ankleR: -35, shoulderL: 170, shoulderR: 170, shoulderAbdL: 12, shoulderAbdR: 12, elbowL: 4, elbowR: 4, lift: 14 }), 'air', { move: 0.45, travel: [30, 0] }),
    kf(P(both({ hip: 60, knee: 70, ankle: 30, shoulder: -40, elbow: 10 }), { spine: 30 }), 'feet', { move: 0.35, travel: [20, 0] }),
    kf(P(both({ hip: 0, knee: 0, ankle: -40, shoulder: 175, shoulderAbd: 8, elbow: 2 }), { lift: 26 }), 'air', { hold: 0.3 }),
  ],
});

// The deck and the water: the start stands on the deck edge where the block
// was; the water surface sits at the floor the dive lands on.
{
  const p = lib.patterns.find((q) => q.slug === 'swim-track-start');
  const pelY = keyframeAt(p, 0, placeKeyframes(p)).pelvis[1];
  p.fixture = { kind: 'water', level: -pelY, deck: 26, deckTop: 26, deckBehind: 1 };
}

export const INDIVIDUAL_SPORTS = lib.patterns;
