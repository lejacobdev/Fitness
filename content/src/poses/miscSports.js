/** miscSports movement patterns (see ../poses.js for the format). */
import { add, apply, implementHead, keyframeAt, placeKeyframes, rotY, scale } from '../rig3d.js';
import { ATHLETIC, P, STAND, both, handsToFloor, kf, library, on, reach, reachBoth, side, solve, toeDown, levelFeet } from './kit.js';

const lib = library();
const def = lib.def;

// ── Local helpers ────────────────────────────────────────────────────────

/** A point in the chest's frame (x forward, y up, z left) from the neck base. */
const inChest = (x, y, z) => (sk) => add(sk.neckBase, apply(sk.chest, [x, y, z]));
/** A point in the pelvis/trunk frame from the pelvis. */
const inTrunk = (x, y, z) => (sk) => add(sk.pelvis, apply(sk.trunk, [x, y, z]));
/** A point in the body-root frame (x forward, y up, z left, level) from the pelvis. */
const inRoot = (x, y, z) => (sk) => add(sk.pelvis, apply(sk.root, [x, y, z]));
/** Both hands together on one point (a club, a bat, a ball held in two hands). */
const handsOn = (p, target, gap = 3) => reachBoth(p,
  (sk) => add(target(sk), apply(sk.chest, [0, 0, 1]), gap / 2),
  (sk) => add(target(sk), apply(sk.chest, [0, 0, 1]), -gap / 2));
/** Legs set so both feet sit level and flat (right leg's knee solves it). */
const levelR = (p) => levelFeet(p, 'R', 'kneeR');

// ── Golf ────────────────────────────────────────────────────────────────
// Face-on camera (front view) for a right-handed golfer: the target is to
// the athlete's left (screen left). Spine tilt stays fixed; the shoulders
// turn around it (twist), the hips turn less (turn, with the legs rotating
// back so the feet stay square).

const golfLegs = both({ hip: 42, knee: 22, ankle: 12, hipAbd: 9 });
const golfAddress = handsOn(P(golfLegs, { spine: 34, neck: 22 }), inRoot(24, -12, 0));
const golfTop = reachBoth(
  P(golfLegs, { spine: 34, neck: 22, twist: -78, turn: -18, hipRotL: -14, hipRotR: 18, kneeL: 30, neckTurn: 60 }, side('L', { wrist: 75, shoulderRot: 60 }), side('R', { wrist: 10 })),
  inChest(12, 14, -22), inChest(10, 16, -26));
const golfImpact = handsOn(P(golfLegs, { spine: 34, neck: 22, twist: 8, turn: 22, hipRotL: 18, hipRotR: -14, kneeR: 34, neckTurn: -12 }), inRoot(20, -13, 2));
const golfFinish = toeDown(reachBoth(
  P(both({ hip: 10, knee: 8, hipAbd: 8 }), { spine: 6, neck: 0, twist: 34, turn: 70, hipRotL: 40, hipRotR: -52, kneeR: 38, neckTurn: -10 }, side('L', { wrist: 20 }), side('R', { wrist: 10 })),
  inChest(4, 14, 24), inChest(6, 12, 20)), 'R');

def('golf-full-swing', 'Golf full swing', {
  view: 'front',
  thumb: 2,
  implement: { kind: 'club', at: 'L' },
  keyframes: [
    kf(golfAddress, 'feet', { hold: 0.5, move: 1.0 }),
    kf(golfTop, 'feet', { hold: 0.12, move: 0.32 }),
    kf(golfImpact, 'feet', { hold: 0, move: 0.32 }),
    kf(golfFinish, 'L', { hold: 0.7 }),
  ],
});

def('golf-swing-hold-finish', 'Golf swing, holding the finish', {
  view: 'front',
  thumb: 3,
  implement: { kind: 'club', at: 'L' },
  keyframes: [
    kf(golfAddress, 'feet', { hold: 0.4, move: 1.0 }),
    kf(golfTop, 'feet', { hold: 0.1, move: 0.32 }),
    kf(golfImpact, 'feet', { hold: 0, move: 0.32 }),
    kf(golfFinish, 'L', { hold: 2.2 }),
  ],
});

def('golf-slow-swing', 'Slow-motion golf swing', {
  view: 'front',
  thumb: 2,
  implement: { kind: 'club', at: 'L' },
  keyframes: [
    kf(golfAddress, 'feet', { hold: 0.4, move: 3.0 }),
    kf(golfTop, 'feet', { hold: 0.3, move: 2.2 }),
    kf(golfImpact, 'feet', { hold: 0, move: 1.6 }),
    kf(golfFinish, 'L', { hold: 0.8 }),
  ],
});

// Step-through: the lead foot starts beside the trail foot and steps toward
// the target during the backswing (seen face-on, the step goes screen-left).
const stepLegs = both({ hip: 36, knee: 20, ankle: 10, hipAbd: 2 });
const golfStepAddress = handsOn(P(stepLegs, { spine: 30, neck: 20 }), inRoot(24, -12, 0));
const golfStepLift = reachBoth(
  P(stepLegs, { spine: 30, neck: 20, twist: -60, turn: -10, hipRotR: 10, neckTurn: 50, hipL: 50, kneeL: 45, hipAbdL: 14 }, side('L', { wrist: 25 })),
  inChest(12, 10, -22), inChest(10, 12, -26));
const golfStepTop = reachBoth(
  P(golfLegs, { spine: 34, neck: 22, twist: -78, turn: -18, hipRotL: -14, hipRotR: 18, kneeL: 30, neckTurn: 60 }, side('L', { wrist: 75, shoulderRot: 60 }), side('R', { wrist: 10 })),
  inChest(12, 14, -22), inChest(10, 16, -26));
def('golf-step-through', 'Golf step-through drill', {
  view: 'front',
  thumb: 2,
  implement: { kind: 'club', at: 'L' },
  keyframes: [
    kf(golfStepAddress, 'feet', { hold: 0.4, move: 0.6 }),
    kf(golfStepLift, 'R', { hold: 0, move: 0.4 }),
    kf(golfStepTop, 'feet', { hold: 0.1, move: 0.32, travel: [0, 0] }),
    kf(golfImpact, 'feet', { move: 0.32 }),
    kf(golfFinish, 'L', { hold: 0.7 }),
  ],
});

// Chipping: narrow stance, weight forward, a pendulum of the shoulders.
const chipLegs = both({ hip: 32, knee: 18, ankle: 10, hipAbd: 4 });
const chipAddress = handsOn(P(chipLegs, { spine: 30, neck: 25, bend: 4 }), inRoot(20, -16, 4));
const chipBack = handsOn(P(chipLegs, { spine: 30, neck: 25, bend: 4, twist: -30, neckTurn: 20 }, side('L', { wrist: 15 })), inRoot(12, -12, -14));
const chipThrough = handsOn(P(chipLegs, { spine: 30, neck: 25, bend: 4, twist: 26, turn: 8, hipRotL: 6, neckTurn: -14 }), inRoot(14, -12, 18));
def('golf-chip', 'Golf chip shot', {
  view: 'front',
  thumb: 2,
  implement: { kind: 'club', at: 'L' },
  keyframes: [
    kf(chipAddress, 'feet', { hold: 0.4, move: 0.6 }),
    kf(chipBack, 'feet', { hold: 0.05, move: 0.45 }),
    kf(chipThrough, 'feet', { hold: 0.6 }),
  ],
});

// Putting: eyes over the ball, arms hanging, a small rocking of the shoulders.
const puttLegs = both({ hip: 30, knee: 14, ankle: 8, hipAbd: 6 });
const puttAddress = handsOn(P(puttLegs, { spine: 38, neck: 40 }, both({ wrist: 0 })), inRoot(18, -8, 0));
const puttBack = handsOn(P(puttLegs, { spine: 38, neck: 40, twist: -12, bend: -3 }), inRoot(18, -8, -9));
const puttThrough = handsOn(P(puttLegs, { spine: 38, neck: 40, twist: 12, bend: 3 }), inRoot(18, -8, 11));
def('golf-putt', 'Golf putt', {
  view: 'front',
  thumb: 0,
  implement: { kind: 'club', at: 'L' },
  keyframes: [
    kf(puttAddress, 'feet', { hold: 0.6, move: 0.6 }),
    kf(puttBack, 'feet', { hold: 0.05, move: 0.5 }),
    kf(puttThrough, 'feet', { hold: 0.7 }),
  ],
});

// ── Disc sports (disc golf, ultimate) ─────────────────────────────────────
// Right-handed thrower. Backhand: side-on to the target, which is to the
// athlete's right — face-on camera, so the throw goes screen-right.

const discStance = both({ hip: 30, knee: 34, ankle: 16, hipAbd: 14 });
const bhHold = reachBoth(P(discStance, { spine: 14 }), inChest(20, -16, 4), inChest(20, -16, -4));
const bhReach = reach(P(both({ hip: 30, knee: 30, ankle: 14, hipAbd: 14 }), { spine: 20, twist: 60, bend: -6, kneeL: 44, neckTurn: -70 }, side('L', { shoulder: 30, elbow: 60 }), side('R', { wrist: 10 })),
  'R', inRoot(-4, 36, 58));
const bhRelease = reach(P(both({ hip: 32, knee: 30, ankle: 14, hipAbd: 14 }), { spine: 16, twist: -26, bend: 6, kneeR: 42, neckTurn: -80 }, side('L', { shoulder: -20, shoulderAbd: 30, elbow: 40 }), side('R', { wrist: -20 })),
  'R', inRoot(16, 34, -46));
const bhFollow = toeDown(reach(P(both({ hip: 24, knee: 20, ankle: 12, hipAbd: 14 }), { spine: 14, twist: -64, bend: 8, kneeR: 32, kneeL: 30, turn: -24, hipRotL: -24, hipRotR: 20, neckTurn: -60 }, side('L', { shoulder: -30, shoulderAbd: 40, elbow: 50 })),
  'R', inRoot(-10, 30, -40)), 'L');




// X-step run-up: step right, cross the left foot behind, plant the right and throw.
const xs0 = reachBoth(P(both({ hip: 16, knee: 18, ankle: 10, hipAbd: 6 }), { spine: 8 }), inChest(20, -16, 4), inChest(20, -16, -4));
const xs1 = reachBoth(P(both({ hip: 16, knee: 18, ankle: 10 }), { spine: 8, hipAbdR: 4, hipL: 28, kneeL: 50, hipAbdL: -14, hipRotL: 10 }), inChest(20, -16, 4), inChest(20, -16, -4));
const xs2 = levelFeet(reachBoth(P(both({ hip: 16, knee: 18, ankle: 10 }), { spine: 10, hipAbdR: 10, hipAbdL: -16, hipL: -4, twist: 30, neckTurn: -40 }), inChest(18, -12, 12), inChest(18, -12, 4)), 'L', 'kneeL');
const xs3 = reach(P(both({ hip: 20, knee: 24, ankle: 12 }), { spine: 16, hipAbdL: -8, hipAbdR: 34, hipR: 30, kneeR: 40, twist: 56, neckTurn: -70 }, side('L', { shoulder: 30, elbow: 60 })), 'R', inRoot(-4, 36, 54));


// Disc-golf putting. Staggered: right foot forward, facing the basket (screen right).
const putStag = (p) => levelFeet(p, 'L', 'kneeL');
const dpSet = putStag(reach(P({ spine: 12, hipR: 30, kneeR: 34, ankleR: 20, hipL: -12, kneeL: 20, neck: -6 }, side('L', { shoulder: 20, elbow: 40 }), side('R', { wrist: -30 })), 'R', inRoot(24, 26, -6)));
const dpDip = putStag(reach(P({ spine: 18, hipR: 44, kneeR: 56, ankleR: 28, hipL: -6, kneeL: 34, neck: -10 }, side('L', { shoulder: 20, elbow: 40 }), side('R', { wrist: -40 })), 'R', inRoot(16, 24, -8)));
const dpRelease = toeDown(reach(P({ spine: 8, hipR: 18, kneeR: 14, ankleR: 10, hipL: -24, kneeL: 20, neck: -6 }, side('L', { shoulder: 10, elbow: 30 }), side('R', { wrist: 20 })), 'R', inRoot(48, 44, -8)), 'L');
def('disc-putt-staggered', 'Disc-golf putt (staggered)', {
  view: 'side',
  thumb: 2,
  implement: { kind: 'disc', at: 'R' },
  keyframes: [
    kf(dpSet, 'feet', { hold: 0.5, move: 0.45 }),
    kf(dpDip, 'feet', { hold: 0.1, move: 0.35 }),
    kf(dpRelease, 'R', { hold: 0.9 }),
  ],
});

// Straddle putt: feet wide and square to the basket, dip and push.
const stLegs = (hip, knee, ankle) => both({ hip, knee, ankle, hipAbd: 24, hipRot: -14 });
const spSet = reach(P(stLegs(22, 26, 14), { spine: 10 }, side('L', { shoulder: 25, elbow: 50 }), side('R', { wrist: -30 })), 'R', inRoot(22, 26, -4));
const spDip = reach(P(stLegs(50, 70, 32), { spine: 22 }, side('L', { shoulder: 25, elbow: 50 }), side('R', { wrist: -40 })), 'R', inRoot(18, 20, -4));
const spRelease = reach(P(stLegs(12, 10, 6), { spine: 6 }, side('L', { shoulder: 15, elbow: 40 }), side('R', { wrist: 20 })), 'R', inRoot(50, 44, -4));
def('disc-putt-straddle', 'Disc-golf straddle putt', {
  view: 'three-quarter',
  thumb: 2,
  implement: { kind: 'disc', at: 'R' },
  keyframes: [
    kf(spSet, 'feet', { hold: 0.4, move: 0.45 }),
    kf(spDip, 'feet', { hold: 0.1, move: 0.35 }),
    kf(spRelease, 'feet', { hold: 1.2 }),
  ],
});

// Ultimate forehand (flick): step out wide to the right, side-arm snap.
const fhSet = reachBoth(P(both({ hip: 22, knee: 26, ankle: 14, hipAbd: 8 }), { spine: 12 }), inChest(20, -16, 4), inChest(20, -16, -4));
const fhStep = reach(levelFeet(P({ spine: 30, bend: -14, twist: -30, hipL: 10, kneeL: 20, ankleL: 10, hipAbdL: 4, hipR: 50, kneeR: 64, ankleR: 26, hipAbdR: 34, neckTurn: 20 }, side('L', { shoulder: 30, elbow: 70 }), side('R', { shoulderRot: -60, wrist: -50 })), 'L', 'kneeL'),
  'R', inRoot(-20, 8, -46));
const fhRelease = reach(levelFeet(P({ spine: 26, bend: -12, twist: 18, hipL: 10, kneeL: 20, ankleL: 10, hipAbdL: 4, hipR: 50, kneeR: 64, ankleR: 26, hipAbdR: 34, neckTurn: 10 }, side('L', { shoulder: 30, elbow: 70 }), side('R', { shoulderRot: -60, wrist: 40 })), 'L', 'kneeL'),
  'R', inRoot(34, 14, -40));
def('ultimate-forehand-flick', 'Forehand flick', {
  view: 'three-quarter',
  thumb: 2,
  implement: { kind: 'disc', at: 'R' },
  keyframes: [
    kf(fhSet, 'feet', { hold: 0.3, move: 0.45 }),
    kf(fhStep, 'L', { hold: 0.08, move: 0.2 }),
    kf(fhRelease, 'feet', { hold: 0.6 }),
  ],
});

// Pivot and break: fake one way, then pivot on the left foot and step wide
// the other way to throw a backhand around the mark.
const pbFake = reach(levelFeet(P({ spine: 26, twist: -20, hipL: 20, kneeL: 30, ankleL: 14, hipR: 46, kneeR: 60, ankleR: 26, hipAbdR: 30, bend: -10 }, side('L', { shoulder: 30, elbow: 70 })), 'L', 'kneeL'), 'R', inRoot(-10, 12, -44));
const pbStep = reach(levelFeet(P({ spine: 28, twist: 46, turn: 40, hipRotL: 40, hipL: 20, kneeL: 30, ankleL: 14, hipR: 56, kneeR: 64, ankleR: 26, hipAbdR: 20, neckTurn: -60 }, side('L', { shoulder: 20, elbow: 70 })), 'L', 'kneeL'), 'R', inRoot(-6, 30, 50));
const pbThrow = reach(levelFeet(P({ spine: 24, twist: -10, turn: 40, hipRotL: 40, hipL: 20, kneeL: 30, ankleL: 14, hipR: 56, kneeR: 64, ankleR: 26, hipAbdR: 20, neckTurn: -40 }, side('L', { shoulder: -10, shoulderAbd: 30, elbow: 50 })), 'L', 'kneeL'), 'R', inRoot(40, 30, -30));
def('ultimate-pivot-break', 'Pivot and break throw', {
  view: 'front',
  thumb: 2,
  implement: { kind: 'disc', at: 'R' },
  keyframes: [
    kf(fhSet, 'feet', { hold: 0.2, move: 0.3 }),
    kf(pbFake, 'L', { hold: 0.15, move: 0.35 }),
    kf(pbStep, 'L', { hold: 0.05, move: 0.25 }),
    kf(pbThrow, 'L', { hold: 0.6 }),
  ],
});

// Marking: low, arms spread, shuffling side to side in front of the thrower.
const markBase = { spine: 30, neck: -20, ...both({ hip: 46, knee: 56, ankle: 24, hipAbd: 20, shoulderAbd: 70, shoulder: 20, elbow: 20 }) };
const markL = P(markBase, { hipAbdL: 12, hipAbdR: 28 });
const markR = P(markBase, { hipAbdL: 28, hipAbdR: 12 });
def('ultimate-mark', 'Marking the thrower', {
  view: 'front',
  loop: true,
  thumb: 0,
  keyframes: [
    kf(P(markBase), 'feet', { hold: 0.15, move: 0.18 }),
    kf(markR, 'L', { move: 0.18 }),
    kf(P(markBase), 'feet', { hold: 0.1, move: 0.18, travel: [0, 0] }),
    kf(markL, 'R', { move: 0.18 }),
  ],
});

// Layout: a full-extension dive to catch, landing on the chest and forearms.
const layCrouch = P(both({ hip: 70, knee: 80, ankle: 30, shoulder: -30, elbow: 20 }), { spine: 50, neck: -30 });
const layFlight = P(both({ hip: 0, knee: 10, ankle: -30, shoulder: 170, elbow: 5, shoulderAbd: 10 }), { spine: 84, neck: -40, lift: 26 });
const layLand = P(both({ hip: -4, knee: 16, ankle: -40, shoulder: 165, elbow: 30, shoulderAbd: 14 }), { spine: 92, neck: -45 });
def('ultimate-layout', 'Layout dive', {
  view: 'side',
  thumb: 1,
  implement: { kind: 'disc', at: 'R' },
  fixture: { kind: 'mat' },
  keyframes: [
    kf(layCrouch, 'feet', { hold: 0.3, move: 0.3 }),
    kf(layFlight, 'air', { move: 0.35, travel: [48, 0] }),
    kf(layLand, 'front', { hold: 0.8, travel: [40, 0] }),
  ],
});

const kneelTall = P(both({ hip: 0, knee: 90, ankle: -40, shoulder: 60, elbow: 30 }), { spine: 10 });
def('ultimate-layout-knees', 'Layout from the knees', {
  view: 'side',
  thumb: 1,
  implement: { kind: 'disc', at: 'R' },
  fixture: { kind: 'mat' },
  keyframes: [
    kf(kneelTall, 'knees', { hold: 0.4, move: 0.45 }),
    kf(P(both({ hip: 0, knee: 60, ankle: -40, shoulder: 165, elbow: 5 }), { spine: 60, neck: -35, lift: 4 }), 'air', { move: 0.3, travel: [18, 0] }),
    kf(P(both({ hip: -6, knee: 40, ankle: -40, shoulder: 165, elbow: 30, shoulderAbd: 14 }), { spine: 90, neck: -45 }), 'front', { hold: 0.9, travel: [22, 0] }),
  ],
});

// Skying: a two-foot take-off to catch at the highest point.
const skyLoad = P(both({ hip: 64, knee: 78, ankle: 30, shoulder: -40, elbow: 10 }), { spine: 38, neck: -25 });
const skyPeak = toeDown(P(both({ hip: 2, knee: 10, ankle: -30, shoulder: 175, shoulderAbd: 8, elbow: 6 }), { neck: -35, lift: 28 }), 'L');
def('ultimate-skying', 'Skying catch', {
  view: 'three-quarter',
  thumb: 2,
  keyframes: [
    kf(P(both({ hip: 14, knee: 18, ankle: 8, shoulder: 30, elbow: 40 }), { spine: 6, neck: -20 }), 'feet', { hold: 0.3, move: 0.35 }),
    kf(skyLoad, 'feet', { move: 0.25 }),
    kf(skyPeak, 'air', { hold: 0.15, move: 0.35 }),
    kf(P(both({ hip: 50, knee: 60, ankle: 26, shoulder: 70, elbow: 70 }), { spine: 30, neck: -10 }), 'feet', { hold: 0.5 }),
  ],
});

// Golf variations ------------------------------------------------------------
/** Feet together: the same swing with a narrow base, a shorter backswing and a held finish. */
const narrow = both({ hip: 36, knee: 20, ankle: 10, hipAbd: 1 });
def('golf-feet-together', 'Feet-together swings', {
  view: 'front', thumb: 2, implement: { kind: 'club', at: 'L' },
  keyframes: [
    kf(handsOn(P(narrow, { spine: 32, neck: 22 }), inRoot(22, -12, 0)), 'feet', { hold: 0.5, move: 0.9 }),
    kf(reachBoth(P(narrow, { spine: 32, neck: 22, twist: -60, turn: -10, neckTurn: 50 }, side('L', { wrist: 50, shoulderRot: 40 })), inChest(12, 4, -22), inChest(10, 6, -26)), 'feet', { hold: 0.1, move: 0.4 }),
    kf(handsOn(P(narrow, { spine: 32, neck: 22, twist: 8, turn: 14, neckTurn: -10 }), inRoot(20, -13, 2)), 'feet', { move: 0.3 }),
    kf(reachBoth(P(both({ hip: 10, knee: 8, hipAbd: 1 }), { spine: 8, twist: 30, turn: 50, neckTurn: -10 }), inChest(4, 10, 22), inChest(6, 8, 18)), 'feet', { hold: 3 }),
  ],
});
/** Pre-shot routine: stand behind the ball looking at the target, one rehearsal swing, walk in, set up, go. */
def('golf-pre-shot-routine', 'Pre-shot routine', {
  view: 'front', thumb: 5, implement: { kind: 'club', at: 'L' },
  keyframes: [
    kf(reachBoth(P({ turn: 90, neckTurn: 10 }), inChest(20, -30, 4), inChest(20, -30, -4)), 'feet', { hold: 1, move: 0.6 }),
    kf(golfAddress, 'feet', { move: 0.8, travel: [0, 0] }),
    kf(golfTop, 'feet', { hold: 0.1, move: 0.5 }),
    kf(golfFinish, 'L', { hold: 0.3, move: 0.6 }),
    kf(golfAddress, 'feet', { hold: 0.8, move: 1.0 }),
    kf(golfTop, 'feet', { hold: 0.12, move: 0.32 }),
    kf(golfImpact, 'feet', { move: 0.32 }),
    kf(golfFinish, 'L', { hold: 0.7 }),
  ],
});

// Disc golf backhand ----------------------------------------------------------
const DISC_BALL = { r: 10, color: 'orange', shape: 'disc' };
const pullThrough = levelFeet(reach(P(both({ hip: 20, knee: 24, ankle: 12 }), { spine: 12, hipAbdR: 20, twist: 0, neckTurn: -30 }, side('L', { shoulder: 30, elbow: 60 })), 'R', inRoot(20, 30, 10)), 'R', 'hipR');
/** Standstill: reach straight back away from the target, pull through close to the chest, snap. */
def('disc-backhand-standstill', 'Standstill backhand', {
  view: 'front', thumb: 1, ball: DISC_BALL,
  keyframes: [
    kf(xs0, 'feet', { hold: 0.4, move: 0.4, ball: 'R' }),
    kf(xs3, 'L', { hold: 0.2, move: 0.3, ball: 'R' }),
    kf(pullThrough, 'L+Rtoe', { move: 0.12, ball: 'R' }),
    kf(bhFollow, 'R+Ltoe', { hold: 0.6, ball: { at: [0, 60, -420] } }),
  ],
});
/** X-step: step, cross the back foot behind, plant, reach back, throw. */
def('disc-x-step-drive', 'X-step run-up and drive', {
  view: 'front', thumb: 4, ball: DISC_BALL,
  keyframes: [
    kf(xs0, 'feet', { hold: 0.3, move: 0.3, ball: 'R' }),
    kf(xs1, 'R', { move: 0.3, travel: [0, -24], ball: 'R' }),
    kf(xs2, 'feet', { move: 0.3, travel: [0, -24], ball: 'R' }),
    kf(xs3, 'L', { move: 0.24, travel: [0, -20], ball: 'R' }),
    kf(pullThrough, 'L+Rtoe', { move: 0.12, ball: 'R', travel: [0, -10] }),
    kf(bhFollow, 'R+Ltoe', { hold: 0.6, ball: { at: [0, 60, -420] } }),
  ],
});
/** Band anchored behind: pull through the throwing path with the hips turning, elbow leading. */
def('band-pull-through', 'Band backhand pull-through', {
  view: 'front', thumb: 1, implement: { kind: 'band', at: 'R', to: [0, 40, 60] },
  keyframes: [
    kf(xs3, 'L', { hold: 0.3, move: 0.5 }),
    kf(pullThrough, 'L+Rtoe', { move: 0.4 }),
    kf(bhFollow, 'R+Ltoe', { hold: 0.3, move: 1 }),
  ],
});


// ── Golf balls ────────────────────────────────────────────────────────────
/**
 * The ball sits where the club face meets it (keyframe `spotFrom`, by default `impact`), so it stays put
 * through the backswing; after `impact` it flies (or rolls, `ground`) to `to` =
 * [forward, height above the ground, left] for the rest of the rep.
 */
function golfBall(slug, impact, to, { arc = 0, ground = false, spotFrom = impact } = {}) {
  const p = lib.patterns.find((q) => q.slug === slug);
  const r = 2.2;
  p.ball = { r, color: 'white' };
  const placed = placeKeyframes(p);
  const spot = implementHead(p.implement, keyframeAt(p, spotFrom, placed), r);
  const fw = apply(rotY(placed.view), [1, 0, 0]), lt = apply(rotY(placed.view), [0, 0, 1]);
  const rel = (i, pt) => {
    const pel = keyframeAt(p, i, placed).pelvis;
    const d = [pt[0] - pel[0], pt[1] - pel[1], pt[2] - pel[2]];
    return { at: [d[0] * fw[0] + d[2] * fw[2], d[1], d[0] * lt[0] + d[2] * lt[2]] };
  };
  const dest = add(add([spot[0], ground ? r : to[1], spot[2]], fw, to[0]), lt, to[2]);
  p.keyframes = p.keyframes.map((k, i) => ({
    ...k,
    ball: rel(i, i <= impact ? [spot[0], r, spot[2]] : dest),
    ...(i === impact ? { ballArc: arc } : {}),
  }));
}
golfBall('golf-full-swing', 2, [30, 140, 520], { arc: 60 });
golfBall('golf-swing-hold-finish', 2, [30, 140, 520], { arc: 60 });
golfBall('golf-slow-swing', 2, [30, 140, 520], { arc: 60 });
golfBall('golf-step-through', 3, [30, 140, 520], { arc: 60 });
golfBall('golf-feet-together', 2, [30, 120, 480], { arc: 50 });
golfBall('golf-pre-shot-routine', 6, [30, 140, 520], { arc: 60 });
golfBall('golf-chip', 1, [10, 0, 150], { arc: 34, ground: true, spotFrom: 0 });
golfBall('golf-putt', 1, [0, 0, 110], { ground: true, spotFrom: 0 });

export const MISC_SPORTS = lib.patterns;
