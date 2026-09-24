/**
 * Bowling, archery, target rifle and boccia: the four-step approach and
 * release, a bow drawn to the anchor and released, standing / kneeling /
 * prone rifle positions, and boccia throws and ramp shots from a chair.
 */
import { add, apply } from '../rig3d.js';
import { P, air, both, kf, library, reach, reachBoth, side } from './kit.js';

const lib = library();
const def = lib.def;

// ── Bowling (right-handed, four-step approach) ────────────────────────────
const BOWL = { r: 11, color: 'black' };
const balance = { shoulderL: 30, shoulderAbdL: 60, elbowL: 10 };
const bowlStance = reachBoth(P(both({ hip: 16, knee: 20, ankle: 10 }), { spine: 14 }), air(24, 30, 2), air(24, 26, -6));
const approach = (ball, { holdFinish = 0.8 } = {}) => [
  kf(bowlStance, 'feet', { hold: 0.5, move: 0.3, ...(ball && { ball: 'R' }) }),
  kf(P({ spine: 14, hipR: 24, kneeR: 10, ankleR: 10, hipL: -6, kneeL: 20, ankleL: -10, shoulderR: 50, elbowR: 10, shoulderL: 50, elbowL: 20 }), 'R+Ltoe', { move: 0.3, travel: [30, 0], ...(ball && { ball: 'R' }) }),
  kf(P({ spine: 16, hipL: 24, kneeL: 14, ankleL: 10, hipR: -8, kneeR: 20, ankleR: -10, shoulderR: 0, elbowR: 0 }, balance), 'L+Rtoe', { move: 0.3, travel: [34, 0], ...(ball && { ball: 'R' }) }),
  kf(P({ spine: 22, hipR: 30, kneeR: 24, ankleR: 12, hipL: -10, kneeL: 24, ankleL: -12, shoulderR: -70, elbowR: 0 }, balance), 'R+Ltoe', { move: 0.3, travel: [36, 0], ...(ball && { ball: 'R' }) }),
  kf(P({ spine: 34, neck: -16, hipL: 76, kneeL: 84, ankleL: 30, hipAbdL: 6, hipR: -30, kneeR: 10, ankleR: -30, hipAbdR: -16, shoulderR: 10, elbowR: 0 }, balance), 'L+Rtoe', { move: 0.24, travel: [50, 0], ...(ball && { ball: { floor: 'R', dx: 8 } }) }),
  kf(P({ spine: 30, neck: -16, hipL: 76, kneeL: 84, ankleL: 30, hipAbdL: 6, hipR: -30, kneeR: 10, ankleR: -30, hipAbdR: -16, shoulderR: 150, elbowR: 10 }, balance), 'L+Rtoe', { hold: holdFinish, ...(ball && { ball: { floor: 'R', dx: 420 } }) }),
];
def('bowling-approach', 'Four-step approach and release', { view: 'side', ball: BOWL, thumb: 4, keyframes: approach(true) });
def('bowling-approach-no-ball', 'Approach without a ball', { view: 'side', thumb: 4, keyframes: approach(false) });
def('bowling-follow-through', 'Release and freeze the follow-through', { view: 'side', ball: BOWL, thumb: 5, keyframes: approach(true, { holdFinish: 2.5 }) });
def('bowling-one-step', 'One-step release', {
  view: 'side', ball: BOWL, thumb: 2,
  keyframes: [
    kf(P({ spine: 22, hipR: 20, kneeR: 20, hipL: -6, kneeL: 20, ankleL: -10, shoulderR: -60, elbowR: 0 }, balance), 'R+Ltoe', { hold: 0.4, move: 0.3, ball: 'R' }),
    ...approach(true).slice(4),
  ],
});
def('bowling-slide-hold', 'Slide and hold the finish', {
  view: 'side', thumb: 1,
  keyframes: [
    kf(P({ spine: 16, hipL: 24, kneeL: 14, ankleL: 10, hipR: -8, kneeR: 20, ankleR: -10 }, balance), 'L+Rtoe', { move: 0.4 }),
    kf(P({ spine: 34, neck: -16, hipL: 76, kneeL: 84, ankleL: 30, hipAbdL: 6, hipR: -30, kneeR: 10, ankleR: -30, hipAbdR: -16, shoulderR: 120, elbowR: 10 }, balance), 'L+Rtoe', { hold: 5, move: 0.5, travel: [40, 0] }),
  ],
});
def('bowling-ball-hold', 'Bowling-grip hold', {
  view: 'three-quarter', ball: BOWL, loop: true, thumb: 0,
  keyframes: [
    kf(P({ shoulderR: 0, elbowR: 0, wristR: -10 }), 'feet', { hold: 2, move: 0.6, ball: 'Rdown' }),
    kf(P({ shoulderR: 0, elbowR: 0, wristR: -14, spine: 2 }), 'feet', { hold: 2, move: 0.6, ball: 'Rdown' }),
  ],
});
def('bowling-ball-carry', 'Carrying bowling balls', {
  view: 'three-quarter', implement: { kind: 'bowlingballs', at: 'hands' }, loop: true, thumb: 0,
  path: { kind: 'line', length: 300, speed: 90 },
  keyframes: ['L', 'R'].flatMap((sd) => {
    const o = sd === 'L' ? 'R' : 'L';
    return [
      kf(P({ [`hip${sd}`]: 20, [`knee${sd}`]: 4, [`ankle${sd}`]: 8, [`hip${o}`]: -12, [`knee${o}`]: 14, [`ankle${o}`]: -18, ...both({ shoulderAbd: 12 }) }), 'air', { move: 0.18 }),
      kf(P({ [`hip${sd}`]: 4, [`knee${sd}`]: 8, [`hip${o}`]: 16, [`knee${o}`]: 44, ...both({ shoulderAbd: 12 }) }), 'air', { move: 0.18 }),
    ];
  }),
});
/** Bodyweight single-leg reach: hinge on one leg, reach toward the floor, back leg long. */
def('single-leg-reach', 'Single-leg reach (RDL)', {
  view: 'side', thumb: 1,
  keyframes: [
    kf(P({ hipR: 10, kneeR: 20 }), 'L', { hold: 0.3, move: 1 }),
    kf(P({ spine: 80, neck: -20, hipL: 80, kneeL: 20, ankleL: 10, hipR: -6, kneeR: 4, ankleR: -30, ...both({ shoulder: 90, elbow: 0 }) }), 'L', { hold: 0.5, move: 1 }),
    kf(P({ hipR: 10, kneeR: 20 }), 'L', { hold: 0.3 }),
  ],
});

// ── Archery (right-handed: bow in the left hand, left side to the target) ─
const BOW = { kind: 'bow2' };
const ARROW = { r: 1, color: 'red', shape: 'arrow' };
/** Side-on stance, feet shoulder width, the target along +x (the left side faces it). */
const archStance = { turn: -90, ...both({ hipAbd: 10, knee: 4 }), neckTurn: -80 };
/** Anchor: the draw hand under the jaw. */
const anchor = (sk) => add(add(sk.head, apply(sk.headFrame, [3, -9, 0])), apply(sk.headFrame, [0, 0, -4]), 1);
const bowArm = { shoulderAbdL: 90, shoulderL: 0, elbowL: 4 };
const archSet = P(archStance, { shoulderL: 10, elbowL: 10, shoulderR: 20, elbowR: 60, shoulderAbdR: 20 });
const archRaise = P(archStance, bowArm, { shoulderAbdR: 80, elbowR: 60, shoulderR: 10 });
const archDraw = reach(P(archStance, bowArm, { shoulderAbdR: 90, elbowR: 150 }), 'R', anchor, { rot: [-60, -30, 0, 30, 60], prefer: (sk) => -sk.R.elbow[1] });
const archRelease = reach(P(archStance, bowArm, { shoulderAbdR: 90, elbowR: 130 }), 'R', (sk) => add(anchor(sk), apply(sk.root, [1, 0, 0]), -10), { rot: [-60, -30, 0, 30, 60], prefer: (sk) => -sk.R.elbow[1] });
def('archery-shot', 'Shot sequence: raise, draw, anchor, release', {
  view: 'three-quarter', implement: BOW, ball: ARROW, thumb: 3,
  keyframes: [
    kf(archSet, 'feet', { hold: 0.6, move: 0.6, ball: 'none' }),
    kf(archRaise, 'feet', { hold: 0.2, move: 0.8, ball: 'none' }),
    kf(archDraw, 'feet', { hold: 2, move: 0.2, ball: 'none' }),
    kf(archRelease, 'feet', { hold: 1, move: 0.6, ball: { at: [70, 48, 0] } }),
    kf(archRelease, 'feet', { hold: 0.3, ball: { at: [520, 48, 0] } }),
  ],
});
/** A band stands in for the bow: raise, draw to the anchor, hold, expand a little. */
def('archery-band-draw', 'Band draw and hold', {
  view: 'three-quarter', implement: { kind: 'band', at: 'hands' }, thumb: 2,
  keyframes: [
    kf(archSet, 'feet', { hold: 0.4, move: 0.6 }),
    kf(archRaise, 'feet', { move: 0.8 }),
    kf(archDraw, 'feet', { hold: 2.5, move: 0.8 }),
    kf(reach(P(archStance, bowArm, { shoulderAbdR: 92, elbowR: 150 }), 'R', (sk) => add(anchor(sk), apply(sk.root, [1, 0, 0]), -3), { rot: [-60, -30, 0, 30, 60], prefer: (sk) => -sk.R.elbow[1] }), 'feet', { hold: 2, move: 1.2 }),
    kf(archRaise, 'feet', { hold: 0.3, move: 1.2 }),
    kf(archSet, 'feet', { hold: 0.3 }),
  ],
});
def('archery-bow-arm-hold', 'Bow-arm and draw-elbow position holds', {
  view: 'three-quarter', fixture: { kind: 'wall', at: -20 }, thumb: 1,
  keyframes: [
    kf(P(archStance), 'feet', { hold: 0.3, move: 0.6 }),
    kf(P(archStance, bowArm), 'feet', { hold: 3, move: 0.6 }),
    kf(P(archStance), 'feet', { move: 0.6 }),
    kf(archDraw, 'feet', { hold: 3, move: 0.8 }),
  ],
});
def('archery-aim-balance', 'Aiming stance, then on one foot', {
  view: 'three-quarter', implement: BOW, thumb: 1,
  keyframes: [
    kf(archDraw, 'feet', { hold: 2, move: 0.6 }),
    kf(P(archDraw, { hipR: 30, kneeR: 50 }), 'L', { hold: 2, move: 0.6 }),
    kf(archDraw, 'feet', { hold: 0.3 }),
  ],
});

// ── Target rifle (right-handed) ───────────────────────────────────────────
const RIFLE = { kind: 'rifle2' };
const DOWEL = { kind: 'rifle2', dowel: true };
/** Standing: side-on, left elbow on the hip, left hand under the fore-end, head on the stock. */
const rifleStand = reachBoth(P({ turn: -80, neckTurn: -70, neck: 10, bend: -8, ...both({ hipAbd: 10, knee: 4 }), shoulderL: 30, elbowL: 130, shoulderAbdL: 10 }),
  (sk) => add(add(add(sk.neckBase, apply(sk.root, [1, 0, 0]), 16), apply(sk.root, [0, 0, 1]), 16), [0, -10, 0]), (sk) => add(add(sk.R.shoulder, apply(sk.chest, [1, 0, 0]), 8), [0, -6, 0]), { rot: [-60, -30, 0, 30, 60] });
const rifleDown = P({ turn: -80, ...both({ hipAbd: 10, knee: 4 }), shoulderL: 30, elbowL: 40, shoulderR: 10, elbowR: 30 });
def('rifle-standing-hold', 'Standing position hold', {
  view: 'three-quarter', implement: DOWEL, thumb: 1,
  keyframes: [kf(rifleDown, 'feet', { hold: 0.5, move: 0.8 }), kf(rifleStand, 'feet', { hold: 4, move: 0.8 }), kf(rifleDown, 'feet', { hold: 0.8 })],
});
def('rifle-wall-dot', 'Hold the tip on a wall dot', {
  view: 'three-quarter', implement: DOWEL, fixture: { kind: 'wall', at: 110 }, loop: true, thumb: 0,
  keyframes: [kf(rifleStand, 'feet', { hold: 2, move: 0.5 }), kf(P(rifleStand, { bend: -9 }), 'feet', { hold: 2, move: 0.5 })],
});
def('rifle-dry-fire', 'Supervised dry fire', {
  view: 'three-quarter', implement: RIFLE, thumb: 1,
  cast: [{ pattern: 'stand-watch', at: [-20, 110], facing: -60 }],
  keyframes: [kf(rifleDown, 'feet', { hold: 0.5, move: 0.8 }), kf(rifleStand, 'feet', { hold: 1.5, move: 0.8 }), kf(P(rifleStand, { wristR: 6 }), 'feet', { hold: 2, move: 0.1 }), kf(rifleDown, 'feet', { hold: 0.5, move: 0.8 })],
});
def('rifle-mount', 'Consistent shoulder mount', {
  view: 'three-quarter', implement: DOWEL, loop: true, thumb: 1,
  keyframes: [kf(rifleDown, 'feet', { hold: 0.6, move: 0.7 }), kf(rifleStand, 'feet', { hold: 1, move: 0.7 })],
});
/** Prone: lying at an angle to the target, propped on both elbows, cheek on the stock. */
def('rifle-prone', 'Prone position hold', {
  view: 'three-quarter', implement: DOWEL, loop: true, thumb: 0,
  keyframes: [
    kf(reachBoth(P({ spine: 72, neck: -30, turn: -10, ...both({ hip: -8, knee: 4, ankle: -30, hipAbd: 14 }), shoulderL: 70, elbowL: 90, shoulderR: 40, elbowR: 110 }),
      (sk) => add(add(sk.L.shoulder, apply(sk.root, [1, 0, 0]), 34), [0, -2, 0]), (sk) => add(add(sk.R.shoulder, apply(sk.chest, [1, 0, 0]), 8), [0, -4, 0])), 'air', { hold: 2, move: 0.8 }),
    kf(reachBoth(P({ spine: 73, neck: -30, turn: -10, ...both({ hip: -8, knee: 4, ankle: -30, hipAbd: 14 }), shoulderL: 70, elbowL: 90, shoulderR: 40, elbowR: 110 }),
      (sk) => add(add(sk.L.shoulder, apply(sk.root, [1, 0, 0]), 34), [0, -2, 0]), (sk) => add(add(sk.R.shoulder, apply(sk.chest, [1, 0, 0]), 8), [0, -4, 0])), 'air', { hold: 2, move: 0.8 }),
  ],
});
/** Kneeling: sitting on the right heel, left elbow resting just in front of the left knee. */
def('rifle-kneeling', 'Kneeling position hold', {
  view: 'three-quarter', implement: DOWEL, loop: true, thumb: 0,
  keyframes: [
    kf(reachBoth(P({ turn: -40, spine: 20, neck: 10, hipL: 80, kneeL: 90, ankleL: 10, hipR: -10, kneeR: 150, ankleR: -40, shoulderL: 50, elbowL: 90 }),
      (sk) => add(add(sk.L.shoulder, apply(sk.root, [1, 0, 0]), 26), [0, -4, 0]), (sk) => add(add(sk.R.shoulder, apply(sk.chest, [1, 0, 0]), 8), [0, -6, 0])), 'L+Rknee', { hold: 2.5, move: 0.8 }),
    kf(reachBoth(P({ turn: -40, spine: 21, neck: 10, hipL: 80, kneeL: 90, ankleL: 10, hipR: -10, kneeR: 150, ankleR: -40, shoulderL: 50, elbowL: 90 }),
      (sk) => add(add(sk.L.shoulder, apply(sk.root, [1, 0, 0]), 26), [0, -4, 0]), (sk) => add(add(sk.R.shoulder, apply(sk.chest, [1, 0, 0]), 8), [0, -6, 0])), 'L+Rknee', { hold: 2.5, move: 0.8 }),
  ],
});
def('rifle-jog-then-aim', 'Raise the heart rate, then settle a hold', {
  view: 'three-quarter', implement: DOWEL, thumb: 5,
  keyframes: [
    ...[0, 1, 2, 3].map((i) => kf(P(i % 2 ? { hipR: 30, kneeR: 60, hipL: -10, kneeL: 20 } : { hipL: 30, kneeL: 60, hipR: -10, kneeR: 20 }, { shoulderL: 30, elbowL: 40, shoulderR: 10, elbowR: 30, lift: 3 }), 'air', { move: 0.2, travel: [20, 0] })),
    kf(rifleDown, 'feet', { hold: 0.4, move: 0.6 }),
    kf(rifleStand, 'feet', { hold: 4, move: 0.8 }),
  ],
});

// ── Boccia (seated in a wheelchair) ───────────────────────────────────────
const BOCCIA = { r: 4.2, color: 'red' };
const seated = (spine) => ({ ...both({ hip: 88 + spine, knee: 96, ankle: 0, hipAbd: 6 }), spine });
def('boccia-throw', 'Seated underarm throw', {
  view: 'side', fixture: { kind: 'wheelchair' }, ball: BOCCIA, thumb: 2,
  keyframes: [
    kf(P(seated(10), { shoulderR: 30, elbowR: 60, shoulderL: 20, elbowL: 60 }), 'seat', { hold: 0.6, move: 0.5, ball: 'R' }),
    kf(P(seated(20), { shoulderR: -40, elbowR: 4, shoulderAbdR: 20, shoulderL: 20, elbowL: 60 }), 'seat', { hold: 0.2, move: 0.4, ball: 'R' }),
    kf(P(seated(22), { shoulderR: 60, elbowR: 4, shoulderAbdR: 14, shoulderL: 20, elbowL: 60 }), 'seat', { move: 0.9, ball: { floor: 'R', dx: 300 }, ballArc: 30 }),
    kf(P(seated(22), { shoulderR: 70, elbowR: 4, shoulderAbdR: 14, shoulderL: 20, elbowL: 60 }), 'seat', { hold: 0.5, ball: { floor: 'R', dx: 320 } }),
  ],
});
def('boccia-lob', 'Soft lob onto the jack', {
  view: 'side', fixture: { kind: 'wheelchair' }, ball: BOCCIA, thumb: 2,
  keyframes: [
    kf(P(seated(10), { shoulderR: 30, elbowR: 60, shoulderL: 20, elbowL: 60 }), 'seat', { hold: 0.6, move: 0.5, ball: 'R' }),
    kf(P(seated(16), { shoulderR: -20, elbowR: 4, shoulderAbdR: 20, shoulderL: 20, elbowL: 60 }), 'seat', { hold: 0.2, move: 0.4, ball: 'R' }),
    kf(P(seated(12), { shoulderR: 100, elbowR: 4, shoulderAbdR: 14, shoulderL: 20, elbowL: 60 }), 'seat', { move: 1.2, ball: { floor: 'R', dx: 240 }, ballArc: 90 }),
    kf(P(seated(12), { shoulderR: 100, elbowR: 4, shoulderAbdR: 14, shoulderL: 20, elbowL: 60 }), 'seat', { hold: 0.5, ball: { floor: 'R', dx: 250 } }),
  ],
});
/** The assistant behind the chair sets the ramp; the athlete lets the ball go. */
def('ramp-assistant', 'Assistant setting the ramp', {
  view: 'side', loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 30, knee: 30, ankle: 14 }), { spine: 30, shoulderL: 70, elbowL: 30, shoulderR: 70, elbowR: 30 }), 'feet', { hold: 1.4, move: 0.6 }),
    kf(P(both({ hip: 34, knee: 34, ankle: 14 }), { spine: 34, shoulderL: 74, elbowL: 26, shoulderR: 74, elbowR: 26 }), 'feet', { hold: 1.4, move: 0.6 }),
  ],
});
def('boccia-ramp', 'Ramp shot with an assistant', {
  view: 'side', fixture: { kind: 'ramp', from: 16, to: 120, top: 62 }, ball: BOCCIA, thumb: 1,
  cast: [{ pattern: 'ramp-assistant', at: [40, -70], facing: 30 }],
  keyframes: [
    kf(reach(P(seated(20), { shoulderL: 20, elbowL: 60 }), 'R', air(18, 20, -10)), 'seat', { hold: 1, move: 0.4, surface: 44, ball: { at: [20, 18, 0] } }),
    kf(reach(P(seated(24), { shoulderL: 20, elbowL: 60 }), 'R', air(22, 18, -10)), 'seat', { move: 0.9, ball: { at: [120, -40, 0] } }),
    kf(P(seated(16), { shoulderL: 20, elbowL: 60, shoulderR: 30, elbowR: 60 }), 'seat', { hold: 0.6, ball: { at: [320, -40, 0] } }),
  ],
});
def('seated-reaches', 'Tall sitting with arm reaches', {
  view: 'three-quarter', fixture: { kind: 'wheelchair' }, thumb: 1,
  keyframes: [
    kf(P(seated(0), both({ shoulder: 20, elbow: 60 })), 'seat', { hold: 1, move: 0.8 }),
    kf(P(seated(0), both({ shoulder: 90, elbow: 0 })), 'seat', { hold: 1, move: 0.8 }),
    kf(P(seated(0), { shoulderL: 10, shoulderAbdL: 90, elbowL: 0, shoulderR: 20, elbowR: 60 }), 'seat', { hold: 1, move: 0.8 }),
    kf(P(seated(0), { shoulderR: 10, shoulderAbdR: 90, elbowR: 0, shoulderL: 20, elbowL: 60 }), 'seat', { hold: 1, move: 0.8 }),
    kf(P(seated(0), both({ shoulder: 20, elbow: 60 })), 'seat', { hold: 0.4 }),
  ],
});
def('seated-band-row', 'Seated band row', {
  view: 'side', fixture: { kind: 'wheelchair' }, implement: { kind: 'band', at: 'hands', to: [90, 30, 0] }, thumb: 1,
  keyframes: [
    kf(P(seated(4), both({ shoulder: 70, elbow: 4, shoulderAbd: 8 })), 'seat', { hold: 0.3, move: 0.8 }),
    kf(P(seated(0), both({ shoulder: -20, elbow: 100, shoulderAbd: 14 })), 'seat', { hold: 0.6, move: 1.2 }),
    kf(P(seated(4), both({ shoulder: 70, elbow: 4, shoulderAbd: 8 })), 'seat', { hold: 0.2 }),
  ],
});

export const PRECISION = lib.patterns;
void side;
