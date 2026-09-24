/**
 * Bat-and-ball and field sports: baseball, softball, beep baseball,
 * American and flag football, rugby, and the rest of soccer. Right-handed
 * athletes; hitters and pitchers are shown side-on so the rotation reads.
 */
import { P, both, clear, kf, library, mirror, on, reach, reachBoth, solve, toeDown } from './kit.js';

/** Both hands together in front of the chest (in the body's own facing, so turned bodies work). */
const handsFront = (p, d = 22, h = 42, w = 3.5) => reachBoth(p, ...on.front(d, h, w));

const lib = library();
const def = lib.def;
const at = (f, h, l = 0) => ({ at: [f, h, l] });
const BASEBALL = { r: 2.6, color: 'white' };
const SOFTBALL = { r: 3.4, color: 'yellow' };
const FOOTBALL = { r: 4.6, color: 'brown' };
const RUGBY = { r: 5.2, color: 'white' };
const SOCCER = { r: 5.8, color: 'white' };
const bat = { kind: 'bat2', at: 'hands' };

// Hitting (front view: the batter faces the camera, pitcher to their left) -----
/** Both hands on the bat: bottom (L) hand at `lo`, top (R) hand 7 further along. */
const grip = (p, lo, hi) => reachBoth(p, () => lo, () => hi);
const stance = both({ hip: 26, knee: 30, ankle: 14, hipAbd: 20 });
const swing = (ballColor = BASEBALL, pitchFrom = 180) => [
  kf(grip(P(stance, { spine: 18, twist: -12 }), [-6, 52, -18], [-8, 60, -22]), 'feet', { hold: 0.35, move: 0.35, ball: at(20, 60, pitchFrom) }),
  kf(grip(P(stance, { spine: 18, twist: -30, hipL: 50, kneeL: 60, hipAbdL: 10, kneeR: 34 }), [-12, 54, -26], [-14, 62, -30]), 'R', { move: 0.3, ball: at(20, 50, pitchFrom * 0.6) }),
  kf(grip(P(stance, { spine: 18, twist: -30, hipAbdL: 30 }), [-12, 54, -26], [-14, 62, -30]), 'feet', { move: 0.14, ball: at(20, 44, pitchFrom * 0.25), travel: [0, 8] }),
  kf(grip(P(stance, { spine: 16, twist: 20, turn: 30, hipRotR: 30, ankleR: -24, hipAbdL: 30 }), [18, 34, 10], [26, 36, 12]), 'L+Rtoe', { move: 0.1, ball: 'head' }),
  kf(grip(P(stance, { spine: 10, twist: 60, turn: 50, hipRotR: 40, ankleR: -30, hipAbdL: 30 }), [0, 70, 30], [-4, 74, 34]), 'L+Rtoe', { hold: 0.4, ball: at(60, 80, -260), ballArc: 0 }),
];
def('baseball-swing', 'Baseball swing', { view: 'front', implement: bat, ball: BASEBALL, thumb: 3, keyframes: swing() });
def('softball-swing', 'Softball swing', { view: 'front', implement: bat, ball: SOFTBALL, thumb: 3, keyframes: swing(SOFTBALL) });
def('dry-swing', 'Dry swing (no ball)', { view: 'front', implement: bat, thumb: 3, keyframes: swing().map((k) => ({ ...k, ball: undefined })) });
def('hip-shoulder-separation', 'Hip-shoulder separation', {
  view: 'front', thumb: 1,
  keyframes: [
    kf(reachBoth(P(stance, { spine: 18, twist: -20 }), () => [-6, 56, -18], () => [-8, 62, -22]), 'feet', { hold: 0.3, move: 0.4 }),
    kf(reachBoth(P(stance, { spine: 18, twist: -40, turn: 30, hipRotR: 30, ankleR: -20 }), () => [-6, 56, -18], () => [-8, 62, -22]), 'L+Rtoe', { hold: 0.8, move: 0.3 }),
    kf(reachBoth(P(stance, { spine: 14, twist: 30, turn: 40, hipRotR: 36, ankleR: -24 }), () => [16, 40, 10], () => [22, 42, 12]), 'L+Rtoe', { hold: 0.5, move: 0.4 }),
    kf(reachBoth(P(stance, { spine: 18, twist: -20 }), () => [-6, 56, -18], () => [-8, 62, -22]), 'feet', { hold: 0.1 }),
  ],
});

// Pitching and throwing ---------------------------------------------------------
/** Overhand pitch: set, leg lift, stride with the arm cocked, release out front, follow through. */
def('baseball-pitch', 'Pitching delivery', {
  view: 'three-quarter', ball: BASEBALL, thumb: 3,
  keyframes: [
    kf(handsFront(P({ turn: -80, spine: 4 })), 'feet', { hold: 0.4, move: 0.5, ball: 'hands' }),
    kf(handsFront(P({ turn: -80, spine: 2, hipL: 100, kneeL: 110, ankleL: -10, hipR: 4, kneeR: 12 })), 'R', { hold: 0.2, move: 0.4, ball: 'hands' }),
    kf(P({ turn: -40, twist: -40, spine: 6, hipL: 50, kneeL: 40, ankleL: 16, hipAbdL: 10, hipR: -10, kneeR: 40, ankleR: -20, hipAbdR: 20,
      shoulderL: 70, shoulderAbdL: 40, elbowL: 30, shoulderR: 90, shoulderAbdR: 90, shoulderRotR: -90, elbowR: 90 }), 'L+R', { move: 0.14, ball: 'R', travel: [50, 0] }),
    kf(P({ turn: 0, twist: 10, spine: 30, hipL: 70, kneeL: 40, ankleL: 20, hipR: 0, kneeR: 40, ankleR: -40,
      shoulderL: 0, shoulderAbdL: 40, elbowL: 80, shoulderR: 130, shoulderAbdR: 40, elbowR: 20, wristR: 40 }), 'L+Rtoe', { move: 0.14, ball: 'R' }),
    kf(P({ turn: 10, twist: 30, spine: 60, neck: -20, hipL: 90, kneeL: 50, ankleL: 24, hipR: 30, kneeR: 60, ankleR: -30,
      shoulderL: -20, shoulderAbdL: 20, elbowL: 70, shoulderR: 50, shoulderAbdR: -30, elbowR: 30 }), 'L', { hold: 0.4, ball: at(300, 70, 0) }),
  ],
});
/** Softball windmill: the arm circles forward-up-back-down, releasing at the hip. */
def('softball-windmill', 'Windmill pitch', {
  ball: SOFTBALL, thumb: 3,
  keyframes: [
    kf(handsFront(P({ spine: 6, hipR: 4, kneeR: 10, hipL: -4, kneeL: 10 }), 24, 38), 'feet', { hold: 0.4, move: 0.3, ball: 'hands' }),
    kf(P({ spine: 6, hipL: 40, kneeL: 30, hipR: 0, kneeR: 20, shoulderR: 110, elbowR: 4, shoulderL: 60, elbowL: 20 }), 'R', { move: 0.14, ball: 'R' }),
    kf(P({ spine: 0, hipL: 50, kneeL: 20, ankleL: 10, hipR: -10, kneeR: 30, ankleR: -20, shoulderR: 190, elbowR: 4, shoulderL: 90, elbowL: 20 }), 'L+Rtoe', { move: 0.14, ball: 'R', travel: [40, 0] }),
    kf(P({ spine: 4, hipL: 50, kneeL: 20, ankleL: 12, hipR: -10, kneeR: 30, ankleR: -30, shoulderR: 270, elbowR: 4, shoulderL: 40, elbowL: 30 }), 'L+Rtoe', { move: 0.12, ball: 'R' }),
    kf(P({ spine: 10, hipL: 50, kneeL: 24, ankleL: 14, hipR: 0, kneeR: 30, ankleR: -34, shoulderR: 290, elbowR: 8, wristR: 40, shoulderL: 10, elbowL: 40 }), 'L+Rtoe', { hold: 0.35, ball: at(300, 40, -10) }),
  ],
});
/** Throw with a crow hop (outfield), or a quarterback's drop and throw. */
const cocked = { shoulderR: 90, shoulderAbdR: 90, shoulderRotR: -90, elbowR: 90, shoulderL: 70, shoulderAbdL: 30, elbowL: 20 };
const releaseArms = { shoulderR: 120, shoulderAbdR: 30, elbowR: 10, wristR: 40, shoulderL: -10, shoulderAbdL: 30, elbowL: 50 };
def('crow-hop-throw', 'Crow-hop throw', {
  view: 'three-quarter', ball: BASEBALL, thumb: 3,
  keyframes: [
    kf(reachBoth(P({ spine: 30, ...both({ hip: 50, knee: 50, ankle: 22, hipAbd: 14 }) }), () => [30, 4, 3], () => [30, 4, -3]), 'feet', { hold: 0.2, move: 0.2, ball: 'hands' }),
    kf(P({ turn: -60, spine: 10, hipR: 50, kneeR: 50, ankleR: 20, hipL: 30, kneeL: 60, ...cocked, lift: 8 }), 'air', { move: 0.2, ball: 'R', travel: [30, 0] }),
    kf(P({ turn: -60, twist: -20, spine: 4, hipR: 30, kneeR: 30, ankleR: 14, hipL: 40, kneeL: 30, ankleL: 10, ...cocked }), 'R', { move: 0.18, ball: 'R', travel: [20, 0] }),
    kf(P({ turn: 0, twist: 30, spine: 30, hipL: 60, kneeL: 40, ankleL: 20, hipR: 0, kneeR: 30, ankleR: -34, ...releaseArms }), 'L+Rtoe', { hold: 0.4, ball: at(300, 90, 0), travel: [30, 0] }),
  ],
});
def('qb-drop-throw', 'Three-step drop and throw', {
  view: 'three-quarter', ball: FOOTBALL, thumb: 4,
  keyframes: [
    kf(reachBoth(P({ spine: 20, ...both({ hip: 30, knee: 36, ankle: 16, hipAbd: 14 }) }), () => [24, 30, 3], () => [24, 30, -3]), 'feet', { hold: 0.3, move: 0.2, ball: 'hands' }),
    kf(handsFront(P({ turn: -40, spine: 10, hipL: 30, kneeL: 30, hipR: -10, kneeR: 40, ankleR: -20 }), 24, 46), 'L', { move: 0.2, ball: 'hands', travel: [-30, 0] }),
    kf(handsFront(P({ turn: -60, spine: 8, hipR: 30, kneeR: 30, hipL: -10, kneeL: 40, ankleL: -20 }), 24, 50), 'R', { move: 0.2, ball: 'hands', travel: [-34, 0] }),
    kf(P({ turn: -70, twist: -20, spine: 0, hipR: 30, kneeR: 30, ankleR: 14, hipL: 30, kneeL: 20, ankleL: 10, ...cocked }), 'R', { hold: 0.1, move: 0.18, ball: 'R', travel: [-20, 0] }),
    kf(P({ turn: 0, twist: 30, spine: 24, hipL: 50, kneeL: 30, ankleL: 16, hipR: 0, kneeR: 30, ankleR: -30, ...releaseArms }), 'L+Rtoe', { hold: 0.4, ball: at(320, 120, 0), travel: [24, 0] }),
  ],
});
def('long-toss', 'Long toss', {
  view: 'three-quarter', ball: BASEBALL, thumb: 2,
  keyframes: [
    kf(P({ turn: -70, spine: 4, hipL: 20, kneeL: 20, hipR: 0, kneeR: 20, shoulderL: 60, elbowL: 30, shoulderR: 20, elbowR: 60 }), 'feet', { hold: 0.3, move: 0.3, ball: 'R' }),
    kf(P({ turn: -60, twist: -30, spine: -6, hipL: 40, kneeL: 20, ankleL: 10, hipR: -10, kneeR: 30, ankleR: -20, ...cocked }), 'L+Rtoe', { move: 0.18, ball: 'R', travel: [30, 0] }),
    kf(P({ turn: 0, twist: 30, spine: 20, hipL: 50, kneeL: 30, ankleL: 16, hipR: 0, kneeR: 30, ankleR: -34, ...releaseArms, shoulderR: 140 }), 'L+Rtoe', { hold: 0.4, ball: at(300, 190, 0) }),
  ],
});

// Fielding --------------------------------------------------------------------------
def('field-grounder', 'Field a ground ball and throw', {
  view: 'three-quarter', ball: BASEBALL, thumb: 2, implement: { kind: 'glove', at: 'L' },
  keyframes: [
    kf(P({ spine: 30, ...both({ hip: 44, knee: 50, ankle: 22, hipAbd: 22 }), shoulderL: 40, elbowL: 50, shoulderR: 40, elbowR: 50 }), 'feet', { hold: 0.2, move: 0.26, ball: at(200, 3, 0) }),
    kf(P({ spine: 30, turn: 20, hipL: 50, kneeL: 50, ankleL: 22, hipR: 20, kneeR: 40, ankleR: -10, hipAbdR: 30, shoulderL: 40, elbowL: 50, shoulderR: 40, elbowR: 50 }), 'L', { move: 0.22, ball: at(100, 3, 0), travel: [20, 20] }),
    kf(reachBoth(P({ spine: 56, neck: -26, ...both({ hip: 96, knee: 100, ankle: 30, hipAbd: 30 }) }), () => [44, -38, 6], () => [40, -30, -8]), 'feet', { hold: 0.15, move: 0.3, ball: at(48, -46, 4), travel: [20, 0] }),
    kf(reachBoth(P({ spine: 20, ...both({ hip: 40, knee: 50, ankle: 22, hipAbd: 20 }) }), () => [16, 34, 3], () => [16, 34, -3]), 'feet', { move: 0.2, ball: 'hands' }),
    kf(P({ turn: 0, twist: 30, spine: 24, hipL: 50, kneeL: 30, ankleL: 16, hipR: 0, kneeR: 30, ankleR: -30, ...releaseArms }), 'L+Rtoe', { hold: 0.35, ball: at(300, 80, 0) }),
  ],
});
def('side-dive', 'Lateral fielding dive', {
  view: 'front', thumb: 2,
  keyframes: [
    kf(P(both({ hip: 40, knee: 50, ankle: 22, hipAbd: 20, shoulder: 40, elbow: 50 }), { spine: 26 }), 'feet', { hold: 0.3, move: 0.26 }),
    kf(P({ spine: 30, bend: -30, hipL: 40, kneeL: 20, ankleL: -20, hipAbdL: 30, hipR: 30, kneeR: 50, shoulderR: 100, shoulderAbdR: 80, elbowR: 10, shoulderL: 60, elbowL: 50 }), 'Ltoe', { move: 0.22, travel: [0, -30] }),
    kf(P({ bend: -84, spine: 6, neck: 20, ...both({ hip: 20, knee: 30 }), shoulderR: 170, elbowR: 10, shoulderL: 150, elbowL: 20 }), 'air', { hold: 0.5, travel: [0, -40] }),
  ],
});
def('side-fall', 'Kneeling side fall', {
  view: 'front', thumb: 1,
  keyframes: [
    kf(P(both({ hip: 0, knee: 90, ankle: -88 }), { shoulderL: 40, shoulderR: 40, elbowL: 60, elbowR: 60 }), 'knees', { hold: 0.4, move: 0.6 }),
    kf(P(both({ hip: 30, knee: 90, ankle: -60 }), { bend: -85, neck: 24, shoulderR: 120, elbowR: 30, shoulderL: 60, elbowL: 60 }), 'air', { hold: 0.6, move: 0.8 }),
    kf(P(both({ hip: 0, knee: 90, ankle: -88 }), { shoulderL: 40, shoulderR: 40, elbowL: 60, elbowR: 60 }), 'knees', { hold: 0.2 }),
  ],
});
def('catch-high', 'Hands catch and tuck', {
  view: 'three-quarter', ball: FOOTBALL, thumb: 2,
  keyframes: [
    kf(P({ spine: 12, hipL: 40, kneeL: 30, ankleL: 10, hipR: -16, kneeR: 60, ankleR: -24, shoulderL: -30, shoulderR: 50, elbowL: 80, elbowR: 80 }), 'L', { move: 0.24, ball: at(200, 70, 30) }),
    kf(reachBoth(P({ spine: 6, hipR: 40, kneeR: 30, ankleR: 10, hipL: -16, kneeL: 50, ankleL: -24 }), () => [40, 64, 5], () => [40, 64, -5]), 'R', { move: 0.2, ball: at(46, 64, 0), travel: [30, 0] }),
    kf(P({ spine: 14, hipL: 40, kneeL: 30, ankleL: 10, hipR: -16, kneeR: 60, ankleR: -24, shoulderL: 20, shoulderAbdL: -10, elbowL: 120, shoulderR: 50, elbowR: 80 }), 'L', { hold: 0.3, ball: 'L', travel: [30, 0] }),
  ],
});
/** Carrying the ball high and tight under the right arm while running. */
const carryPhases = [
  { hipL: 28, kneeL: 14, ankleL: 4, hipR: -10, kneeR: 70, ankleR: -20 },
  { hipL: 4, kneeL: 32, ankleL: 18, hipR: 30, kneeR: 88, ankleR: 0 },
  { hipL: -20, kneeL: 16, ankleL: -26, hipR: 50, kneeR: 64, ankleR: 6, lift: 2 },
  { hipL: -10, kneeL: 56, ankleL: -14, hipR: 36, kneeR: 28, ankleR: 4, lift: 4 },
];
def('ball-carry-run', 'Running with the ball tucked', {
  path: { kind: 'line', length: 380 },
  loop: true, ball: FOOTBALL, thumb: 0,
  keyframes: [...carryPhases, ...carryPhases.map(mirror)].map((ph, i) => {
    const m = i < 4 ? 1 : -1;
    return kf(P({ spine: 14, neck: -8, ...ph, hipL: i < 4 ? ph.hipL : ph.hipL, shoulderR: 20, shoulderAbdR: -10, elbowR: 120, shoulderL: 30 * m, elbowL: 80 }), 'air', { move: 0.13, ball: 'R' });
  }),
});

// Contact skills ------------------------------------------------------------------
def('football-tackle', 'Form tackle', {
  view: 'three-quarter', thumb: 2,
  keyframes: [
    kf(P({ spine: 20, hipL: 40, kneeL: 30, ankleL: 10, hipR: -16, kneeR: 60, ankleR: -24, shoulderL: -30, shoulderR: 50, elbowL: 80, elbowR: 80 }), 'L', { move: 0.24 }),
    kf(P({ spine: 40, neck: -30, ...both({ hip: 70, knee: 80, ankle: 30, hipAbd: 20, shoulder: 50, elbow: 70 }) }), 'feet', { hold: 0.15, move: 0.2, travel: [40, 0] }),
    kf(P({ spine: 50, neck: -40, hipL: 60, kneeL: 50, ankleL: 20, hipR: 0, kneeR: 30, ankleR: -30, shoulderL: 110, shoulderAbdL: 30, elbowL: 80, shoulderR: 110, shoulderAbdR: 30, elbowR: 80 }), 'L+Rtoe', { move: 0.2, travel: [26, 0] }),
    kf(P({ spine: 40, neck: -30, hipR: 60, kneeR: 50, ankleR: 20, hipL: 0, kneeL: 30, ankleL: -30, shoulderL: 100, shoulderAbdL: 40, elbowL: 110, shoulderR: 100, shoulderAbdR: 40, elbowR: 110 }), 'R+Ltoe', { hold: 0.3, travel: [26, 0] }),
  ],
});
def('hand-strike', 'Hand strike and lockout', {
  view: 'three-quarter', thumb: 1,
  keyframes: [
    kf(P({ spine: 30, ...both({ hip: 50, knee: 60, ankle: 26, hipAbd: 20, shoulder: 20, elbow: 100 }) }), 'feet', { hold: 0.35, move: 0.14 }),
    kf(P({ spine: 34, hipL: 60, kneeL: 50, ankleL: 24, hipAbdL: 16, hipR: 20, kneeR: 40, ankleR: -10, hipAbdR: 20, ...both({ shoulder: 84, elbow: 4, wrist: -60, shoulderAbd: 14 }) }), 'L+R', { hold: 0.35, move: 0.3, travel: [16, 0] }),
    kf(P({ spine: 30, ...both({ hip: 50, knee: 60, ankle: 26, hipAbd: 20, shoulder: 20, elbow: 100 }) }), 'feet', { hold: 0.1, travel: [-16, 0] }),
  ],
});
/** Rugby pass: ball swung from the right hip across the body and released to the left. */
def('rugby-pass', 'Rugby pass', {
  view: 'front', ball: RUGBY, thumb: 2,
  keyframes: [
    kf(reachBoth(P({ spine: 16, twist: -40, turn: 10, ...both({ hip: 30, knee: 36, ankle: 16, hipAbd: 18 }) }), () => [16, 10, -18], () => [10, 12, -30]), 'feet', { hold: 0.2, move: 0.3, ball: at(16, 12, -26) }),
    kf(reachBoth(P({ spine: 14, twist: 30, turn: 10, ...both({ hip: 30, knee: 36, ankle: 16, hipAbd: 18 }) }), () => [30, 36, 30], () => [36, 34, 22]), 'feet', { move: 0.16, ball: at(36, 36, 30) }),
    kf(P({ spine: 12, twist: 40, turn: 10, ...both({ hip: 26, knee: 30, ankle: 14, hipAbd: 18, shoulder: 90, elbow: 10, shoulderAbd: -20 }) }), 'feet', { hold: 0.35, ball: at(80, 50, 260) }),
  ],
});

// Soccer ------------------------------------------------------------------------------------
/** Dribbling on the run: small touches with the inside of the right foot every stride. */
def('soccer-dribble', 'Dribbling', {
  path: { kind: 'line', length: 320, speed: 150 },
  loop: true, ball: SOCCER, thumb: 0,
  keyframes: [...carryPhases, ...carryPhases.map(mirror)].map((ph, i) => kf(P({ spine: 12, neck: -20, ...ph, shoulderL: i < 4 ? -20 : 20, shoulderR: i < 4 ? 20 : -20, elbowL: 70, elbowR: 70, shoulderAbdL: 20, shoulderAbdR: 20 }), 'air', {
    move: 0.14, ball: i === 5 ? 'footR' : { floor: 'hands', dx: 40 - (i % 4) * 4 },
  })),
});
def('soccer-first-touch', 'First touch and move away', {
  view: 'three-quarter', ball: SOCCER, thumb: 1,
  keyframes: [
    kf(P({ spine: 8, hipL: 10, kneeL: 20, ankleL: 10, hipR: 30, kneeR: 40, hipRotR: -40, hipAbdR: 10, shoulderAbdL: 30, shoulderAbdR: 30 }), 'L', { hold: 0.1, move: 0.4, ball: { floor: 'hands', dx: 120 } }),
    kf(P({ spine: 10, hipL: 10, kneeL: 24, ankleL: 12, hipR: 20, kneeR: 20, hipRotR: -50, hipAbdR: 16, shoulderAbdL: 30, shoulderAbdR: 30 }), 'L', { move: 0.3, ball: 'footR' }),
    kf(P({ spine: 16, turn: 40, hipL: 30, kneeL: 30, ankleL: 14, hipR: -16, kneeR: 50, ankleR: -24, shoulderAbdL: 30, shoulderAbdR: 30 }), 'L', { hold: 0.3, ball: { floor: 'hands', dx: 60, dl: 30 } }),
  ],
});
def('soccer-header', 'Attacking header', {
  ball: SOCCER, thumb: 2,
  keyframes: [
    kf(P({ spine: 10, hipL: 40, kneeL: 30, ankleL: 10, hipR: -16, kneeR: 60, ankleR: -24, shoulderL: -30, shoulderR: 50, elbowL: 80, elbowR: 80 }), 'L', { move: 0.24, ball: at(160, 220) }),
    kf(P({ spine: -16, neck: 20, hipL: 0, kneeL: 10, ankleL: -30, hipR: 90, kneeR: 90, ...both({ shoulder: 100, shoulderAbd: 40, elbow: 60 }), lift: 20 }), 'air', { move: 0.14, ball: at(30, 110), travel: [30, 0] }),
    kf(P({ spine: 16, neck: -20, hipL: 10, kneeL: 30, ankleL: -20, hipR: 60, kneeR: 70, ...both({ shoulder: 40, shoulderAbd: 40, elbow: 70 }), lift: 20 }), 'air', { move: 0.28, ball: at(200, 90) }),
    kf(P(both({ hip: 40, knee: 50, ankle: 22, hipAbd: 10, shoulder: 30, elbow: 40 }), { spine: 20 }), 'feet', { hold: 0.3, ball: 'none', travel: [16, 0] }),
  ],
});
def('point-and-track', 'Point to the sound', {
  view: 'three-quarter', thumb: 1,
  keyframes: [
    kf(P(both({ hip: 30, knee: 36, ankle: 16, hipAbd: 18, shoulder: 30, elbow: 60 }), { spine: 16, neck: -6 }), 'feet', { hold: 0.5, move: 0.3 }),
    kf(P(both({ hip: 30, knee: 36, ankle: 16, hipAbd: 18 }), { spine: 14, neckTurn: 40, twist: 30, shoulderL: 90, shoulderAbdL: 40, elbowL: 4, shoulderR: 30, elbowR: 60 }), 'feet', { hold: 0.8, move: 0.3 }),
    kf(P(both({ hip: 30, knee: 36, ankle: 16, hipAbd: 18, shoulder: 30, elbow: 60 }), { spine: 16, neck: -6 }), 'feet', { hold: 0.2, move: 0.3 }),
    kf(P(both({ hip: 30, knee: 36, ankle: 16, hipAbd: 18 }), { spine: 14, neckTurn: -40, twist: -30, shoulderR: 90, shoulderAbdR: 40, elbowR: 4, shoulderL: 30, elbowL: 60 }), 'feet', { hold: 0.8 }),
  ],
});

export const FIELD_SPORTS = lib.patterns;
