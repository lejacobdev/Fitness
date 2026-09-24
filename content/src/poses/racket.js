/**
 * Racket and paddle sports: tennis, badminton, table tennis, squash,
 * pickleball, racquetball. Right-handed players: the racket is in R.
 */
import { P, both, kf, library, mirror, reach, reachBoth } from './kit.js';

const lib = library();
const def = lib.def;
const at = (f, h, l = 0) => ({ at: [f, h, l] });
const TB = { r: 2.8, color: 'yellow' };
const TT = { r: 1.8, color: 'orange' };
const SQ = { r: 2.2, color: 'black' };
const RB = { r: 2.6, color: 'blue' };
const racket = { kind: 'racket', at: 'R' };
const paddle = { kind: 'paddle', at: 'R' };

const ready = both({ hip: 30, knee: 36, ankle: 16, hipAbd: 16 });
const readyArms = { shoulderR: 40, elbowR: 60, shoulderL: 40, elbowL: 60, shoulderAbdL: -10, shoulderAbdR: -10 };

// Groundstrokes ------------------------------------------------------------------
/** Forehand: unit turn with the racket back, load the outside (right) leg, rotate through contact in front, finish over the left shoulder. */
const forehand = (low = false) => {
  const knee = low ? 70 : 40, hip = low ? 60 : 34;
  return [
    kf(P(ready, readyArms, { spine: 14 }), 'feet', { hold: 0.25, move: 0.3, ball: 'none' }),
    kf(P({ spine: low ? 30 : 16, twist: -60, turn: -20, hipL: hip - 10, kneeL: knee - 16, ankleL: 14, hipR: hip, kneeR: knee, ankleR: 24, hipAbdL: 16, hipAbdR: 16,
      shoulderR: 20, shoulderAbdR: 70, elbowR: 20, shoulderL: 80, shoulderAbdL: 20, elbowL: 10 }), 'feet', { hold: 0.1, move: 0.26, ball: at(130, low ? 20 : 50, -30) }),
    kf(P({ spine: low ? 30 : 14, twist: 0, turn: 0, hipL: hip, kneeL: knee, ankleL: 20, hipR: hip - 20, kneeR: knee - 10, ankleR: -10, hipAbdL: 16, hipAbdR: 16,
      shoulderR: 50, shoulderAbdR: 40, elbowR: 16, shoulderL: 40, shoulderAbdL: 30, elbowL: 30 }), 'L+Rtoe', { move: 0.12, ball: 'head' }),
    kf(P({ spine: low ? 24 : 10, twist: 50, turn: 16, hipL: hip, kneeL: knee - 10, ankleL: 16, hipR: 0, kneeR: 20, ankleR: -30, hipAbdL: 16, hipAbdR: 16,
      shoulderR: 130, shoulderAbdR: -30, elbowR: 90, shoulderL: 20, shoulderAbdL: -10, elbowL: 80 }), 'L+Rtoe', { hold: 0.35, move: 0.4, ball: at(260, 60, -30) }),
  ];
};
def('tennis-forehand', 'Tennis forehand', { view: 'three-quarter', implement: racket, ball: TB, thumb: 2, keyframes: forehand() });
def('low-forehand', 'Low forehand drive (squash, racquetball)', { view: 'three-quarter', implement: racket, ball: SQ, thumb: 2, keyframes: forehand(true) });
/** Two-handed backhand: turn the shoulders to the left, swing across with both hands. */
const bhGrip = (p, f, h, l) => reachBoth(p, () => [f, h, l], () => [f - 2, h - 8, l]);
def('tennis-backhand', 'Two-handed backhand', {
  view: 'three-quarter', implement: racket, ball: TB, thumb: 2,
  keyframes: [
    kf(P(ready, readyArms, { spine: 14 }), 'feet', { hold: 0.25, move: 0.3, ball: 'none' }),
    kf(bhGrip(P({ spine: 16, twist: 70, turn: 20, hipL: 40, kneeL: 44, ankleL: 22, hipR: 24, kneeR: 30, ankleR: 10, hipAbdL: 16, hipAbdR: 16 }), -10, 30, 30), 'feet', { hold: 0.1, move: 0.26, ball: at(130, 50, 30) }),
    kf(bhGrip(P({ spine: 12, twist: 0, hipL: 30, kneeL: 34, ankleL: 14, hipR: 36, kneeR: 40, ankleR: 20, hipAbdL: 16, hipAbdR: 16 }), 40, 30, 20), 'R+Ltoe', { move: 0.12, ball: 'head' }),
    kf(bhGrip(P({ spine: 8, twist: -50, turn: -16, hipL: 0, kneeL: 20, ankleL: -30, hipR: 30, kneeR: 30, ankleR: 14, hipAbdL: 16, hipAbdR: 16 }), 20, 80, -20), 'R+Ltoe', { hold: 0.35, move: 0.4, ball: at(260, 60, 20) }),
  ],
});

// Overheads -------------------------------------------------------------------
const trophy = P({ spine: -10, twist: -40, turn: -30, hipL: 10, kneeL: 30, ankleL: 20, hipR: -8, kneeR: 40, ankleR: 16, hipAbdL: 10, hipAbdR: 10,
  shoulderL: 170, elbowL: 4, shoulderR: 100, shoulderAbdR: 80, shoulderRotR: -80, elbowR: 100 });
const drop = P({ spine: -14, twist: -30, hipL: 20, kneeL: 44, ankleL: 26, hipR: 0, kneeR: 50, ankleR: 20, hipAbdL: 10, hipAbdR: 10,
  shoulderL: 120, elbowL: 20, shoulderR: 130, shoulderAbdR: 70, shoulderRotR: -100, elbowR: 140 });
const reachContact = P({ spine: 6, twist: 10, hipL: 0, kneeL: 4, ankleL: -34, hipR: -10, kneeR: 20, ankleR: -30, shoulderL: 40, elbowL: 60,
  shoulderR: 172, shoulderAbdR: 10, elbowR: 4, wristR: 20, lift: 8 });
const serveFinish = P({ spine: 30, twist: 40, hipL: 40, kneeL: 40, ankleL: 20, hipR: -30, kneeR: 50, ankleR: -30, shoulderL: 20, elbowL: 80,
  shoulderR: 60, shoulderAbdR: -30, elbowR: 30 });
def('tennis-serve', 'Tennis serve', {
  view: 'three-quarter', implement: racket, ball: TB, thumb: 1,
  keyframes: [
    kf(P({ hipL: 10, kneeL: 10, hipR: -8, kneeR: 14, ankleR: -10, shoulderL: 60, elbowL: 20, shoulderR: 50, elbowR: 30, turn: -30 }), 'feet', { hold: 0.35, move: 0.5, ball: 'L' }),
    kf(trophy, 'feet', { hold: 0.1, move: 0.26, ball: at(30, 150, 10), ballArc: 0 }),
    kf(drop, 'feet', { move: 0.14, ball: at(36, 140, 4) }),
    kf(reachContact, 'air', { move: 0.14, ball: 'head' }),
    kf(serveFinish, 'L', { hold: 0.4, ball: at(300, 60, -10), travel: [30, 0] }),
  ],
});
def('tennis-overhead', 'Overhead smash', {
  view: 'three-quarter', implement: racket, ball: TB, thumb: 2,
  keyframes: [
    kf(P(ready, readyArms, { spine: 10 }), 'feet', { hold: 0.2, move: 0.3, ball: at(40, 240) }),
    kf(trophy, 'feet', { move: 0.3, ball: at(40, 170, 4), travel: [-24, 0] }),
    kf(reachContact, 'air', { move: 0.14, ball: 'head' }),
    kf(serveFinish, 'L', { hold: 0.35, ball: at(240, 0, -10), travel: [16, 0] }),
  ],
});
def('badminton-smash', 'Badminton jump smash', {
  view: 'three-quarter', implement: racket, thumb: 2,
  keyframes: [
    kf(P(ready, readyArms, { spine: 10 }), 'feet', { hold: 0.2, move: 0.3 }),
    kf({ ...trophy, kneeL: 50, kneeR: 60, hipL: 30, hipR: 20 }, 'feet', { move: 0.22, travel: [-30, 0] }),
    kf({ ...reachContact, lift: 26, kneeL: 20, kneeR: 40 }, 'air', { move: 0.12 }),
    kf({ ...serveFinish, lift: 14 }, 'air', { move: 0.2 }),
    kf(P({ spine: 20, hipR: 40, kneeR: 50, ankleR: 20, hipL: -20, kneeL: 40, ankleL: -30, shoulderR: 60, elbowR: 40, shoulderL: 20, elbowL: 60 }), 'R', { hold: 0.3, travel: [20, 0] }),
  ],
});
def('badminton-clear', 'Badminton overhead clear or drop', {
  view: 'three-quarter', implement: racket, thumb: 2,
  keyframes: [
    kf(P(ready, readyArms, { spine: 10 }), 'feet', { hold: 0.2, move: 0.3 }),
    kf(trophy, 'feet', { move: 0.3, travel: [-26, 0] }),
    kf({ ...reachContact, lift: 0 }, 'Ltoe+Rtoe', { move: 0.12 }),
    kf(serveFinish, 'L', { hold: 0.35, travel: [16, 0] }),
  ],
});

// Net play, lunges and volleys ------------------------------------------------------
/** Racket-foot lunge to the front court, racket up and in front; push back to base. */
const netLunge = [
  kf(P(ready, readyArms, { spine: 12 }), 'feet', { hold: 0.2, move: 0.3 }),
  kf(P({ spine: 18, hipR: 90, kneeR: 90, ankleR: 26, hipL: -20, kneeL: 20, ankleL: -30, shoulderR: 90, elbowR: 10, wristR: -30, shoulderL: -30, shoulderAbdL: 30, elbowL: 20 }), 'R+Ltoe', { hold: 0.3, move: 0.3, travel: [70, 0] }),
  kf(P(ready, readyArms, { spine: 12 }), 'feet', { hold: 0.2, travel: [-70, 0] }),
];
def('racket-net-lunge', 'Lunge to the net and recover', { view: 'three-quarter', implement: racket, thumb: 1, keyframes: netLunge });
def('squash-lunge-drop', 'Lunge and drop shot', { view: 'three-quarter', implement: racket, thumb: 1, keyframes: netLunge.map((k, i) => (i === 1 ? { ...k, pose: { ...k.pose, shoulderR: 60, elbowR: 20, wristR: 0 } } : k)) });
def('split-step', 'Split step and push-off', {
  view: 'front', thumb: 2,
  keyframes: [
    kf(P(both({ hip: 20, knee: 24, ankle: 10, hipAbd: 12 }), readyArms, { spine: 10 }), 'feet', { hold: 0.2, move: 0.16 }),
    kf(P(both({ hip: 10, knee: 10, ankle: -20, hipAbd: 12 }), readyArms, { spine: 8, lift: 6 }), 'air', { move: 0.14 }),
    kf(P(both({ hip: 44, knee: 54, ankle: 26, hipAbd: 26 }), readyArms, { spine: 20 }), 'feet', { move: 0.16 }),
    kf(P({ spine: 20, hipL: 50, kneeL: 60, ankleL: 26, hipAbdL: 40, hipR: 10, kneeR: 10, ankleR: -30, hipAbdR: 30, ...readyArms, twist: 20 }), 'L+Rtoe', { hold: 0.3, travel: [0, 30] }),
  ],
});
def('volley', 'Volley', {
  view: 'three-quarter', implement: paddle, ball: TB, thumb: 1, loop: true,
  keyframes: [
    kf(P(ready, { spine: 14, shoulderR: 60, elbowR: 60, shoulderAbdR: 20, shoulderL: 50, elbowL: 60 }), 'feet', { move: 0.28, ball: at(120, 60, -20) }),
    kf(P(ready, { spine: 16, twist: 10, shoulderR: 80, elbowR: 20, shoulderAbdR: 10, shoulderL: 40, elbowL: 60 }), 'feet', { move: 0.28, ball: 'head' }),
  ],
});
/** Pickleball dink: knees bent, a short soft push from low to low-high, ball barely clearing the net. */
def('pickleball-dink', 'Dink', {
  view: 'three-quarter', implement: paddle, ball: TB, thumb: 1,
  keyframes: [
    kf(P(both({ hip: 50, knee: 60, ankle: 26, hipAbd: 18 }), { spine: 26, shoulderR: 20, elbowR: 30, shoulderL: 40, elbowL: 60 }), 'feet', { hold: 0.2, move: 0.3, ball: at(90, 14, -16) }),
    kf(P(both({ hip: 50, knee: 60, ankle: 26, hipAbd: 18 }), { spine: 26, shoulderR: 50, elbowR: 10, wristR: -20, shoulderL: 40, elbowL: 60 }), 'feet', { move: 0.3, ball: 'head' }),
    kf(P(both({ hip: 44, knee: 54, ankle: 24, hipAbd: 18 }), { spine: 24, shoulderR: 70, elbowR: 6, wristR: -30, shoulderL: 40, elbowL: 60 }), 'feet', { hold: 0.3, ball: at(150, 30, -18), ballArc: 12 }),
  ],
});
def('underhand-serve', 'Underhand serve', {
  view: 'three-quarter', implement: paddle, ball: TB, thumb: 2,
  keyframes: [
    kf(P({ hipL: 20, kneeL: 14, hipR: -10, kneeR: 14, ankleR: -10, spine: 12, shoulderL: 40, elbowL: 30, shoulderR: -40, elbowR: 10 }), 'feet', { hold: 0.35, move: 0.3, ball: 'L' }),
    kf(P({ hipL: 30, kneeL: 20, hipR: -10, kneeR: 20, ankleR: -20, spine: 16, shoulderL: 20, elbowL: 40, shoulderR: -50, elbowR: 10 }), 'L', { move: 0.3, ball: at(30, 10, -4) }),
    kf(P({ hipL: 36, kneeL: 24, hipR: 0, kneeR: 20, ankleR: -30, spine: 14, shoulderL: 10, elbowL: 40, shoulderR: 40, elbowR: 10 }), 'L', { move: 0.2, ball: 'head' }),
    kf(P({ hipL: 36, kneeL: 20, hipR: 10, kneeR: 20, ankleR: -30, spine: 10, shoulderL: 10, elbowL: 40, shoulderR: 110, elbowR: 10 }), 'L', { hold: 0.35, ball: at(260, 70, -12), ballArc: 20 }),
  ],
});

// Table tennis (a table in front, waist high) ----------------------------------------
const TABLE = { kind: 'bench', from: 30, to: 110, top: 64 };
const ttStance = both({ hip: 50, knee: 50, ankle: 24, hipAbd: 24 });
def('tt-forehand-loop', 'Forehand loop', {
  view: 'three-quarter', implement: paddle, ball: TT, thumb: 2, fixture: TABLE,
  keyframes: [
    kf(P(ttStance, { spine: 30, shoulderR: 30, elbowR: 90, shoulderL: 40, elbowL: 70 }), 'feet', { hold: 0.2, move: 0.3, ball: 'none' }),
    kf(P(ttStance, { spine: 34, twist: -40, shoulderR: -10, shoulderAbdR: 40, elbowR: 30, shoulderL: 50, elbowL: 60, kneeR: 60 }), 'feet', { move: 0.24, ball: at(100, 40, -30) }),
    kf(P(ttStance, { spine: 26, twist: 0, shoulderR: 50, shoulderAbdR: 20, elbowR: 50, shoulderL: 40, elbowL: 60 }), 'feet', { move: 0.12, ball: 'head' }),
    kf(P(ttStance, { spine: 20, twist: 36, shoulderR: 120, shoulderAbdR: -10, elbowR: 90, shoulderL: 20, elbowL: 80, kneeL: 40 }), 'feet', { hold: 0.3, ball: at(180, 60, -20) }),
  ],
});
def('tt-backhand-flick', 'Backhand flick', {
  view: 'three-quarter', implement: paddle, ball: TT, thumb: 1, fixture: TABLE,
  keyframes: [
    kf(P({ spine: 36, hipR: 70, kneeR: 70, ankleR: 26, hipL: 30, kneeL: 40, ankleL: 14, hipAbdR: 20, hipAbdL: 20, shoulderR: 40, shoulderAbdR: -30, elbowR: 110, wristR: 50, shoulderL: 30, elbowL: 70 }), 'feet', { hold: 0.3, move: 0.2, ball: 'head' }),
    kf(P({ spine: 34, hipR: 70, kneeR: 70, ankleR: 26, hipL: 30, kneeL: 40, ankleL: 14, hipAbdR: 20, hipAbdL: 20, shoulderR: 70, shoulderAbdR: -20, elbowR: 60, wristR: -40, shoulderL: 30, elbowL: 70 }), 'feet', { hold: 0.3, ball: at(160, 40, 10) }),
  ],
});
def('tt-serve', 'Table-tennis serve', {
  view: 'three-quarter', implement: paddle, ball: TT, thumb: 2, fixture: TABLE,
  keyframes: [
    kf(reach(P(ttStance, { spine: 30, shoulderR: 20, elbowR: 90 }), 'L', () => [34, 30, 10]), 'feet', { hold: 0.35, move: 0.3, ball: 'L' }),
    kf(P(ttStance, { spine: 30, shoulderR: 30, shoulderAbdR: 40, elbowR: 80, shoulderL: 40, elbowL: 50 }), 'feet', { move: 0.3, ball: at(36, 60, 4) }),
    kf(P(ttStance, { spine: 34, twist: 20, shoulderR: 50, shoulderAbdR: 0, elbowR: 70, wristR: -40, shoulderL: 30, elbowL: 60 }), 'feet', { hold: 0.35, ball: at(140, 40, 0) }),
  ],
});

export const RACKET = lib.patterns;
