/**
 * Goalkeepers: the soccer keeper's set position, diving and high catches,
 * distribution; the hockey goaltender's butterfly and T-push; the lacrosse
 * goalie's step to the ball. Keeper plans get these, field players never do.
 */
import { P, air, both, ground, holdLax, kf, library, mirror, reachBoth } from './kit.js';

const lib = library();
const def = lib.def;
const SOCCER_BALL = { r: 11, color: 'white' };
const at = (f, h, l = 0) => ({ at: [f, h, l] });

// ── Soccer goalkeeper ──────────────────────────────────────────────────────
/** Set position: feet shoulder-width, knees bent, on the balls of the feet, hands up in front. */
const set = (extra = {}) => P(both({ hip: 40, knee: 50, ankle: 22, hipAbd: 14, shoulder: 50, shoulderAbd: 26, elbow: 60 }), { spine: 22, neck: -12 }, extra);
def('gk-set-shuffle', 'Keeper set and shuffle', {
  view: 'front', loop: true, thumb: 0,
  path: { kind: 'shuttle', length: 220, dir: 'left', speed: 120 },
  keyframes: [
    kf(set(), 'air', { move: 0.16 }),
    kf(set({ hipAbdL: 30, hipAbdR: 8, lift: 3 }), 'air', { move: 0.16 }),
  ],
});
def('gk-dive-save', 'Keeper low diving save', {
  view: 'three-quarter', ball: SOCCER_BALL, thumb: 3,
  cast: [{ pattern: 'ball-roll-feed', at: [320, 40], facing: 185, phase: 0.9 }],
  keyframes: [
    kf(set(), 'feet', { hold: 0.4, move: 0.4, ball: 'c0:R' }),
    kf(set({ hipAbdR: 34, kneeR: 40, hipR: 30, bend: -10 }), 'L', { move: 0.14, ball: { floor: 'L', dx: 100, dl: -70 } }),
    kf(P({ bend: -80, spine: 10, neck: 10, ...both({ hip: 30, knee: 30 }), shoulderR: 170, elbowR: 10, shoulderL: 150, elbowL: 20 }), 'air', { move: 0.2, travel: [0, -60], ball: { floor: 'L', dx: 20, dl: -110 } }),
    kf(P({ bend: -84, spine: 10, neck: 10, ...both({ hip: 40, knee: 50 }), shoulderR: 110, elbowR: 60, shoulderL: 100, elbowL: 70 }), 'air', { hold: 0.5, move: 0.4, ball: 'hands' }),
    kf(set(), 'feet', { hold: 0.3, travel: [0, 40], ball: 'hands' }),
  ],
});
def('gk-high-catch', 'Keeper high catch', {
  view: 'three-quarter', ball: SOCCER_BALL, thumb: 2,
  cast: [{ pattern: 'throw-partner', at: [260, 30], facing: 190, phase: 0.2 }],
  keyframes: [
    kf(set(), 'feet', { hold: 0.3, move: 0.3, ball: 'c0:hands' }),
    kf(P({ spine: 10, hipL: 20, kneeL: 30, ankleL: 10, hipR: -10, kneeR: 30, shoulderL: 60, shoulderR: 60, elbowL: 30, elbowR: 30 }), 'L', { move: 0.2, travel: [30, 0], ball: { at: [120, 190, 0] }, ballArc: 30 }),
    kf(reachBoth(P({ hipL: 0, kneeL: 10, ankleL: -30, hipR: 90, kneeR: 100, ankleR: 0, lift: 34 }), air(24, 92, 6), air(24, 92, -6)), 'air', { hold: 0.1, move: 0.24, travel: [16, 0], ball: { at: [34, 196, 0] } }),
    kf(P(both({ hip: 40, knee: 50, ankle: 24, shoulder: 40, elbow: 120 }), { spine: 20 }), 'feet', { hold: 0.5, travel: [10, 0], ball: 'hands' }),
  ],
});
def('gk-reaction-save', 'Keeper reaction save', {
  view: 'three-quarter', ball: SOCCER_BALL, loop: true, thumb: 2,
  cast: [{ pattern: 'soccer-instep-kick', at: [330, 20], facing: 190, phase: 0.2 }],
  keyframes: [
    kf(set(), 'feet', { hold: 0.6, move: 0.2, ball: 'c0:footR' }),
    kf(set({ lift: 4, ankleL: -20, ankleR: -20 }), 'air', { move: 0.14, ball: 'c0:footR' }),
    kf(reachBoth(set({ spine: 10 }), air(34, 44, 8), air(34, 44, -8)), 'feet', { hold: 0.5, move: 0.3, ball: 'hands' }),
    kf(P(both({ hip: 30, knee: 40, ankle: 20, shoulder: 40, elbow: 120 }), { spine: 16 }), 'feet', { hold: 0.6, ball: 'hands' }),
  ],
});
def('gk-overarm-throw', 'Keeper overarm throw', {
  view: 'three-quarter', ball: SOCCER_BALL, thumb: 2,
  keyframes: [
    kf(P({ turn: -70, ...both({ hip: 10, knee: 14, hipAbd: 14 }), shoulderR: 40, elbowR: 80, shoulderL: 40, elbowL: 80 }), 'feet', { hold: 0.4, move: 0.4, ball: 'R' }),
    kf(P({ turn: -70, twist: -30, hipL: 40, kneeL: 30, ankleL: 10, hipR: -6, kneeR: 20, shoulderR: -50, elbowR: 4, shoulderL: 80, elbowL: 10 }), 'R', { move: 0.3, ball: 'R' }),
    kf(P({ turn: -40, spine: 20, twist: 30, hipL: 40, kneeL: 30, ankleL: 14, hipR: -20, kneeR: 30, ankleR: -24, shoulderR: 170, elbowR: 4, shoulderL: 20, elbowL: 40 }), 'L+Rtoe', { move: 0.14, ball: 'R', travel: [24, 0] }),
    kf(P({ turn: -30, spine: 30, twist: 40, hipL: 46, kneeL: 34, ankleL: 16, hipR: -20, kneeR: 40, ankleR: -26, shoulderR: 40, elbowR: 10, shoulderL: -10, elbowL: 40 }), 'L+Rtoe', { hold: 0.5, ball: at(460, 20, 0) }),
  ],
});
def('gk-punt', 'Keeper punt', {
  view: 'side', ball: SOCCER_BALL, thumb: 2,
  keyframes: [
    kf(P({ hipL: 20, kneeL: 20, hipR: -10, kneeR: 20, ...both({ shoulder: 70, elbow: 20 }) }), 'feet', { hold: 0.3, move: 0.3, ball: 'hands' }),
    kf(P({ hipL: 30, kneeL: 30, ankleL: 10, hipR: -40, kneeR: 90, ankleR: -30, shoulderL: 60, elbowL: 10, shoulderR: 10, elbowR: 20, spine: 4 }), 'L', { move: 0.2, travel: [30, 0], ball: at(34, 20, -8) }),
    kf(P({ hipL: 20, kneeL: 20, ankleL: 10, hipR: 80, kneeR: 10, ankleR: -40, shoulderL: 40, shoulderAbdL: 40, elbowL: 10, shoulderR: -20, elbowR: 20, spine: -10 }), 'L', { move: 0.12, ball: 'footR' }),
    kf(P({ hipL: 10, kneeL: 10, ankleL: -10, hipR: 110, kneeR: 10, ankleR: -40, shoulderL: 30, shoulderAbdL: 40, elbowL: 10, shoulderR: -30, elbowR: 20, spine: -16, lift: 6 }), 'air', { hold: 0.4, ball: at(460, 260, 0), ballArc: 0 }),
  ],
});

// ── Ice-hockey goaltender (stick in the right hand, blocker side) ─────────
const GOALIE_STICK = { kind: 'stick', at: 'R' };
const gStance = P(both({ hip: 50, knee: 60, ankle: 26, hipAbd: 22, hipRot: 10 }), { spine: 30, neck: -16, shoulderL: 60, shoulderAbdL: 30, elbowL: 70, shoulderR: 30, shoulderAbdR: 20, elbowR: 30 });
/** Butterfly: knees together on the ice, lower legs flared out flat, chest up, stick on the ice. */
const butterfly = P({ spine: 12, neck: -10, ...both({ hip: 0, knee: 100, ankle: -30, hipAbd: -10, hipRot: -50 }), shoulderL: 60, shoulderAbdL: 30, elbowL: 70, shoulderR: 30, shoulderAbdR: 20, elbowR: 30 });
def('goalie-butterfly-slide', 'Goaltender butterfly slides', {
  view: 'front', implement: GOALIE_STICK, loop: true, thumb: 1,
  path: { kind: 'shuttle', length: 200, dir: 'left', speed: 90 },
  keyframes: [
    kf(gStance, 'feet', { hold: 0.2, move: 0.3 }),
    kf(butterfly, 'knees', { hold: 0.6, move: 0.3 }),
    kf(gStance, 'feet', { move: 0.3 }),
  ],
});
def('goalie-t-push', 'Goaltender T-pushes', {
  view: 'front', implement: GOALIE_STICK, loop: true, thumb: 1,
  path: { kind: 'shuttle', length: 220, dir: 'left', speed: 110 },
  keyframes: [
    kf(gStance, 'feet', { hold: 0.2, move: 0.2 }),
    kf(P(gStance, { hipAbdR: 40, kneeR: 20, hipRotL: 40, turn: 20 }), 'L', { move: 0.3 }),
    kf(P(gStance, { turn: 10 }), 'feet', { hold: 0.2, move: 0.3 }),
  ],
});

// ── Lacrosse goalie ────────────────────────────────────────────────────────
const LAX_GOALIE = { kind: 'lacrosse2', head: 80 };
const LAX_BALL = { r: 3.2, color: 'white' };
const lgStance = holdLax(P(both({ hip: 30, knee: 40, ankle: 18, hipAbd: 14 }), { spine: 16 }), air(20, 24, -2), air(10, 110, -16), 30);
def('lax-goalie-step-save', 'Goalie step-to-ball saves', {
  view: 'three-quarter', implement: LAX_GOALIE, ball: LAX_BALL, loop: true, thumb: 2,
  cast: [{ pattern: 'lax-overhand-shot', at: [320, 40], facing: 190, phase: 0.4 }],
  keyframes: [
    kf(lgStance, 'feet', { hold: 0.6, move: 0.2, ball: 'c0:head' }),
    kf(holdLax(P({ spine: 20, hipR: 50, kneeR: 50, ankleR: 20, hipAbdR: 20, hipL: 10, kneeL: 30, ankleL: 10, hipAbdL: 10 }), air(24, 20, -10), air(30, 90, -60), 30), 'feet', { hold: 0.4, move: 0.2, travel: [10, -14], ball: 'head' }),
    kf(lgStance, 'feet', { hold: 0.4, move: 0.4, travel: [-10, 14], ball: 'head' }),
  ],
});

export const KEEPERS = lib.patterns;
void ground; void mirror;
