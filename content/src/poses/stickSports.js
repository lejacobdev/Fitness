/**
 * Lacrosse, field hockey, inline and floor hockey.
 *
 * Lacrosse is shown right-handed: bottom hand L at the butt of the stick,
 * top hand R, the head (with the ball in its pocket) past the top hand.
 * Field hockey is played on the right: left hand on top of the stick, right
 * hand lower, the ball in front of the right foot (`leftTop`).
 */
import { P, air, armsSwing, both, gait, ground, holdLax, holdStick, kf, levelFeet, library, mirror, solve } from './kit.js';

const lib = library();
const def = lib.def;

// ── Lacrosse ───────────────────────────────────────────────────────────────
const LAX = { kind: 'lacrosse2' };
const LAX_BALL = { r: 3.2, color: 'white' };
const at = (f, h, l = 0) => ({ at: [f, h, l] });
/** Stick up by the right shoulder, bottom hand in front of the chest: carrying / cradling. */
const carry = (p, f = 0) => holdLax(p, air(18 + f, 4, -2), air(-40 + f, 72, -30));
const laxStance = both({ hip: 36, knee: 44, ankle: 20, hipAbd: 14 });
const splitL = { hipL: 30, kneeL: 30, ankleL: 14, hipR: -8, kneeR: 34, ankleR: -10, hipAbdL: 8, hipAbdR: 8 };

const runPhases = [
  { hipL: 36, kneeL: 18, ankleL: 2, hipR: -12, kneeR: 96, ankleR: -24, lift: 0 },
  { hipL: 8, kneeL: 40, ankleL: 22, hipR: 46, kneeR: 122, ankleR: 0 },
  { hipL: -26, kneeL: 22, ankleL: -32, hipR: 84, kneeR: 96, ankleR: 8, lift: 4 },
  { hipL: -14, kneeL: 84, ankleL: -18, hipR: 58, kneeR: 40, ankleR: 4, lift: 9 },
];
/** A run with the stick carried up in both hands (legs mirror, arms stay on the stick). */
const stickRun = (hold, { lean = 12, move = 0.09 } = {}) => {
  const legs = [...runPhases, ...runPhases.map((ph) => mirror(P(ph)))];
  return legs.map((ph) => kf(hold(P(ph, { spine: lean, neck: -6 })), 'air', { move }));
};

def('lax-stick-sprint', 'Sprint carrying the stick', {
  view: 'three-quarter', loop: true, thumb: 0, implement: LAX,
  path: { kind: 'line', length: 460 },
  keyframes: stickRun((p) => carry(p)),
});
def('lax-cradle-run', 'Run cradling the ball', {
  view: 'three-quarter', loop: true, thumb: 0, implement: LAX, ball: LAX_BALL,
  path: { kind: 'line', length: 400, speed: 330 },
  keyframes: stickRun((p) => carry(p), { move: 0.1 }).map((k, i) => ({ ...k, ball: 'head', pose: i % 2 ? carry(k.pose, 4) : k.pose })),
});
def('lax-overhand-shot', 'Overhand shot', {
  view: 'three-quarter', ball: LAX_BALL, implement: LAX, thumb: 2,
  keyframes: [
    kf(holdLax(P(laxStance, splitL, { spine: 12, twist: -10 }), air(12, 30, 4), air(-40, 80, -28)), 'feet', { hold: 0.3, move: 0.3, ball: 'head' }),
    kf(holdLax(P(laxStance, splitL, { spine: 8, twist: -40, neck: -4 }), air(0, 44, -4), air(-66, 66, -30)), 'feet', { move: 0.14, ball: 'head' }),
    kf(holdLax(P({ spine: 20, twist: 20, hipL: 40, kneeL: 30, ankleL: 16, hipR: -20, kneeR: 30, ankleR: -24, hipAbdL: 8, hipAbdR: 8 }), air(34, 30, 4), air(70, 96, -6)), 'L+Rtoe', { move: 0.1, ball: 'head', travel: [22, 0] }),
    kf(holdLax(P({ spine: 34, twist: 40, hipL: 46, kneeL: 34, ankleL: 18, hipR: -20, kneeR: 36, ankleR: -26, hipAbdL: 8, hipAbdR: 8 }), air(24, 0, 18), air(44, -50, 40)), 'L+Rtoe', { hold: 0.4, ball: at(420, 60, 0) }),
  ],
});

/** Stick head low and to the right, both hands at the hip: a sidearm load. */
def('lax-sidearm-shot', 'Sidearm shot', {
  view: 'three-quarter', ball: LAX_BALL, implement: LAX, thumb: 2,
  keyframes: [
    kf(holdLax(P(laxStance, splitL, { spine: 20, twist: -10 }), air(14, 20, 4), air(-40, 70, -30)), 'feet', { hold: 0.3, move: 0.3, ball: 'head' }),
    kf(holdLax(levelFeet(P(laxStance, splitL, { spine: 26, twist: -44, bend: 8 }), 'R', 'kneeR'), air(4, 10, -10), air(-50, 20, -80)), 'feet', { move: 0.14, ball: 'head' }),
    kf(holdLax(P({ spine: 28, twist: 16, bend: 6, hipL: 44, kneeL: 34, ankleL: 16, hipR: -18, kneeR: 34, ankleR: -24, hipAbdL: 10, hipAbdR: 10 }), air(30, 12, 0), air(90, 14, -40)), 'L+Rtoe', { move: 0.1, ball: 'head', travel: [18, 0] }),
    kf(holdLax(P({ spine: 30, twist: 44, hipL: 46, kneeL: 34, ankleL: 18, hipR: -20, kneeR: 36, ankleR: -26, hipAbdL: 10, hipAbdR: 10 }), air(22, 10, 22), air(50, 10, 90)), 'L+Rtoe', { hold: 0.4, ball: at(420, 20, -10) }),
  ],
});
def('lax-wall-ball', 'Wall ball: throw and catch', {
  view: 'three-quarter', ball: LAX_BALL, implement: LAX, fixture: { kind: 'wall', at: 230 }, loop: true, thumb: 1,
  keyframes: [
    kf(holdLax(P(laxStance, splitL, { spine: 10, twist: -30 }), air(4, 42, -2), air(-56, 80, -30)), 'feet', { hold: 0.15, move: 0.16, ball: 'head' }),
    kf(holdLax(P(laxStance, splitL, { spine: 16, twist: 14 }), air(30, 34, 4), air(70, 96, -8)), 'feet', { move: 0.22, ball: 'head' }),
    kf(holdLax(P(laxStance, splitL, { spine: 12, twist: 0 }), air(20, 34, 2), air(10, 110, -16)), 'feet', { move: 0.22, ball: at(224, 90, -8) }),
    kf(holdLax(P(laxStance, splitL, { spine: 10, twist: -12 }), air(18, 36, 2), air(-10, 110, -20)), 'feet', { hold: 0.1, move: 0.3, ball: 'head' }),
  ],
});
const runL = { hipL: 50, kneeL: 40, ankleL: 14, hipR: -16, kneeR: 70, ankleR: -24, lift: 3 };
def('lax-split-dodge', 'Split dodge', {
  view: 'front', ball: LAX_BALL, implement: LAX, thumb: 2,
  keyframes: [
    kf(carry(P(runL, { spine: 16 })), 'air', { move: 0.18, ball: 'head', travel: [0, 0] }),
    kf(carry(P({ spine: 22, hipR: 50, kneeR: 60, ankleR: 22, hipAbdR: 34, hipL: 30, kneeL: 50, ankleL: 10, hipAbdL: 10, bend: -12, twist: -10 })), 'R', { hold: 0.12, move: 0.16, ball: 'head', travel: [30, -30] }),
    kf(holdLax(levelFeet(P({ spine: 24, bend: 14, hipR: 40, kneeR: 50, ankleR: 20, hipAbdR: 30, hipL: 50, kneeL: 60, ankleL: 20, hipAbdL: 20, twist: 18 }), 'R', 'hipAbdR'), air(16, 8, 10), air(-30, 76, 40)), 'feet', { move: 0.16, ball: 'head' }),
    kf(holdLax(P({ spine: 30, turn: 30, hipL: 60, kneeL: 60, ankleL: 20, hipR: -10, kneeR: 30, ankleR: -30, twist: 10 }), air(16, 8, 10), air(-30, 76, 40)), 'Rtoe', { hold: 0.3, ball: 'head', travel: [30, 40] }),
  ],
});
/** A defender's ready stance: low, stick held across in front, head up. */
const defendStick = (p, poke = 0) => holdLax(p, air(24 + poke, 22, 20), air(80 + poke * 2, 50, -30));
def('lax-defend-stance', 'Defensive stance with stick', {
  view: 'three-quarter', loop: true, thumb: 0, implement: LAX,
  keyframes: [
    kf(defendStick(P(laxStance, { spine: 26, neck: -16 })), 'feet', { hold: 0.2, move: 0.3 }),
    kf(defendStick(P(laxStance, { spine: 28, neck: -16 }), 14), 'feet', { hold: 0.1, move: 0.3 }),
  ],
});
def('lax-roll-dodge', 'Roll dodge off the defender', {
  view: 'three-quarter', ball: LAX_BALL, implement: LAX, thumb: 2,
  cast: [{ pattern: 'lax-defend-stance', at: [120, 34], facing: 180 }],
  keyframes: [
    kf(carry(P(runL, { spine: 16 })), 'air', { move: 0.2, ball: 'head' }),
    kf(carry(P({ spine: 20, hipL: 50, kneeL: 54, ankleL: 20, hipR: -10, kneeR: 40, ankleR: -20, hipAbdL: 12 })), 'L', { hold: 0.1, move: 0.2, ball: 'head', travel: [50, 0] }),
    kf(carry(P({ spine: 20, turn: 100, hipL: 44, kneeL: 50, ankleL: 20, hipR: 20, kneeR: 60, ankleR: -10, hipAbdR: 30 })), 'L', { move: 0.2, ball: 'head' }),
    kf(carry(P({ spine: 20, turn: 190, hipL: 30, kneeL: 40, ankleL: 20, hipR: 50, kneeR: 50, ankleR: 10, hipAbdR: 10 })), 'feet', { move: 0.2, ball: 'head', travel: [10, -40] }),
    kf(carry(P(runL, { spine: 16, turn: 0 })), 'air', { hold: 0.3, ball: 'head', travel: [60, -30] }),
  ],
});
def('lax-ground-ball', 'Ground ball: scoop and go', {
  view: 'three-quarter', ball: LAX_BALL, implement: LAX, thumb: 2,
  keyframes: [
    kf(carry(P(runL, { spine: 18 })), 'air', { move: 0.2, ball: { floor: 'L', dx: 90 } }),
    kf(holdLax(P({ spine: 44, neck: -30, hipL: 80, kneeL: 90, ankleL: 30, hipR: 10, kneeR: 60, ankleR: -20, hipAbdL: 10 }), air(30, -10, 0), ground(120, -4)), 'L+Rtoe', { move: 0.14, ball: { floor: 'L', dx: 60 }, travel: [40, 0] }),
    kf(holdLax(P({ spine: 46, neck: -30, hipL: 84, kneeL: 94, ankleL: 30, hipR: 14, kneeR: 64, ankleR: -20, hipAbdL: 10 }), air(34, -12, 0), ground(110, -4)), 'L+Rtoe', { move: 0.18, ball: 'head', travel: [14, 0] }),
    kf(carry(P(mirror(P(runL)), { spine: 22 })), 'air', { hold: 0.3, ball: 'head', travel: [50, 0] }),
  ],
});
/** Face-off: crouched over the ball, hands choked up by the head, the head on the ground at the ball. */
const LAX_FO = { kind: 'lacrosse2', head: 30 };
const faceoff = (p, head, bottom = air(24, -18, 0)) => holdLax(p, bottom, head, 22);
const foLegs = { ...both({ hip: 84, knee: 100, ankle: 32, hipAbd: 26 }), spine: 64, neck: -30 };
def('lax-faceoff-opponent', 'Face-off opponent', {
  view: 'three-quarter', implement: LAX_FO, thumb: 0,
  keyframes: [
    kf(faceoff(P(foLegs), ground(54, -2, 4)), 'feet', { hold: 0.5, move: 0.14 }),
    kf(faceoff(P(foLegs, { twist: -10 }), ground(52, 6, 4)), 'feet', { hold: 0.6, move: 0.3 }),
    kf(faceoff(P(foLegs), ground(54, -2, 4)), 'feet', { hold: 0.2 }),
  ],
});
def('lax-faceoff-clamp', 'Face-off clamp and pop', {
  view: 'three-quarter', ball: LAX_BALL, implement: LAX_FO, thumb: 1,
  cast: [{ pattern: 'lax-faceoff-opponent', at: [110, 0], facing: 180 }],
  keyframes: [
    kf(faceoff(P(foLegs), ground(54, -4, 4)), 'feet', { hold: 0.5, move: 0.12, ball: { floor: 'L', dx: 24, dl: -8 } }),
    kf(faceoff(P(foLegs, { spine: 66, hipL: 86, hipR: 86 }), ground(52, -6, 6)), 'feet', { hold: 0.25, move: 0.2, ball: { floor: 'L', dx: 24, dl: -8 } }),
    kf(faceoff(P(foLegs, { twist: -20, spine: 58 }), ground(34, -44, 10), air(20, -16, -12)), 'feet', { move: 0.2, ball: { floor: 'L', dx: 4, dl: -44 } }),
    kf(holdLax(P({ spine: 40, turn: -40, hipL: 60, kneeL: 70, ankleL: 24, hipR: 30, kneeR: 60, ankleR: 10, hipAbdR: 20 }), air(20, 6, 0), ground(60, -4, 6), 22), 'feet', { move: 0.2, ball: 'head', travel: [10, -30] }),
    kf(holdLax(P(laxStance, { spine: 20, turn: -60 }), air(20, 24, 0), air(0, 80, -24), 26), 'feet', { hold: 0.3, ball: 'head' }),
  ],
});
def('lax-cradle-carrier', 'Ball carrier protecting the stick', {
  view: 'three-quarter', implement: LAX, loop: true, thumb: 0,
  keyframes: [
    kf(holdLax(P(laxStance, { spine: 22, turn: -30, neck: -10 }), air(10, 10, -12), air(-50, 70, -50)), 'feet', { hold: 0.2, move: 0.4 }),
    kf(holdLax(P(laxStance, { spine: 24, turn: -60, neck: -10, twist: -10 }), air(6, 14, -16), air(-60, 76, -40)), 'feet', { hold: 0.2, move: 0.4 }),
  ],
});
def('lax-cradle-protect', 'Cradle under pressure', {
  view: 'three-quarter', ball: LAX_BALL, implement: LAX, loop: true, thumb: 0,
  cast: [{ pattern: 'lax-defend-stance', at: [84, 64], facing: 200 }],
  keyframes: [
    kf(holdLax(P(laxStance, { spine: 22, turn: -30, neck: -10 }), air(10, 10, -12), air(-50, 70, -50)), 'feet', { hold: 0.2, move: 0.4, ball: 'head' }),
    kf(holdLax(P(laxStance, { spine: 24, turn: -60, neck: -10, twist: -10 }), air(6, 14, -16), air(-60, 76, -40)), 'feet', { hold: 0.2, move: 0.4, ball: 'head' }),
  ],
});
/** A teammate who catches and passes on (for passing drills). */
def('lax-catch-pass', 'Catch and pass (teammate)', {
  view: 'three-quarter', implement: LAX, loop: true, thumb: 0,
  keyframes: [
    kf(holdLax(P(laxStance, { spine: 10 }), air(16, 30, 4), air(10, 100, -20)), 'feet', { hold: 0.4, move: 0.3 }),
    kf(holdLax(P(laxStance, { spine: 10, twist: -30 }), air(4, 44, -4), air(-60, 70, -30)), 'feet', { hold: 0.1, move: 0.2 }),
    kf(holdLax(P(laxStance, { spine: 18, twist: 16 }), air(30, 34, 4), air(70, 96, -8)), 'feet', { hold: 0.3, move: 0.3 }),
  ],
});
def('lax-passing-triangle', 'Passing triangle', {
  view: 'three-quarter', ball: LAX_BALL, implement: LAX, loop: true, thumb: 0,
  cast: [
    { pattern: 'lax-catch-pass', at: [230, 120], facing: 210, phase: 0.33 },
    { pattern: 'lax-catch-pass', at: [230, -120], facing: 150, phase: 0.67 },
  ],
  keyframes: [
    kf(holdLax(P(laxStance, { spine: 10 }), air(16, 30, 4), air(10, 100, -20)), 'feet', { hold: 0.4, move: 0.3, ball: 'head' }),
    kf(holdLax(P(laxStance, { spine: 10, twist: -30, turn: -20 }), air(4, 44, -4), air(-60, 70, -30)), 'feet', { hold: 0.1, move: 0.2, ball: 'head' }),
    kf(holdLax(P(laxStance, { spine: 18, twist: 16, turn: -20 }), air(30, 34, 4), air(70, 96, -8)), 'feet', { hold: 0.3, move: 0.5, ball: 'c1:head', ballArc: 20 }),
    kf(holdLax(P(laxStance, { spine: 10, turn: 10 }), air(16, 30, 4), air(10, 100, -20)), 'feet', { hold: 0.6, move: 0.5, ball: 'c0:head', ballArc: 20 }),
  ],
});
def('lax-run-pass', 'Pass on the run (fast break)', {
  view: 'three-quarter', ball: LAX_BALL, implement: LAX, thumb: 2,
  cast: [
    { pattern: 'lax-catch-pass', at: [300, 160], facing: 220, phase: 0.1 },
    { pattern: 'lax-defend-stance', at: [200, -70], facing: 180 },
  ],
  keyframes: [
    kf(carry(P(runL, { spine: 16 })), 'air', { move: 0.16, ball: 'head' }),
    kf(carry(P(mirror(P(runL)), { spine: 16 })), 'air', { move: 0.16, ball: 'head', travel: [40, 0] }),
    kf(holdLax(P({ spine: 12, twist: -34, hipL: 40, kneeL: 30, ankleL: 14, hipR: -12, kneeR: 40, ankleR: -20 }), air(0, 44, -4), air(-60, 70, -30)), 'L', { move: 0.12, ball: 'head', travel: [40, 0] }),
    kf(holdLax(P({ spine: 20, twist: 20, turn: 20, hipL: 36, kneeL: 30, ankleL: 14, hipR: -18, kneeR: 34, ankleR: -24 }), air(30, 30, 8), air(60, 90, 20)), 'L+Rtoe', { move: 0.4, ball: 'head', travel: [10, 0] }),
    kf(holdLax(P({ spine: 26, twist: 30, turn: 20, hipL: 36, kneeL: 30, ankleL: 14, hipR: -18, kneeR: 34, ankleR: -24 }), air(22, 6, 18), air(44, -40, 40)), 'L+Rtoe', { hold: 0.4, ball: 'c0:head', ballArc: 24 }),
  ],
});
/** A teammate setting a screen: wide, still, stick in front. */
def('lax-screen', 'Setting a screen', {
  view: 'three-quarter', implement: LAX, thumb: 0,
  keyframes: [
    kf(holdLax(P(both({ hip: 30, knee: 36, ankle: 16, hipAbd: 22 }), { spine: 16 }), air(20, 20, 10), air(20, 100, -24)), 'feet', { hold: 1, move: 0.6 }),
    kf(holdLax(P(both({ hip: 32, knee: 38, ankle: 16, hipAbd: 22 }), { spine: 18 }), air(20, 20, 10), air(20, 100, -24)), 'feet', { hold: 1 }),
  ],
});
def('lax-pick-and-roll', 'Pick-and-roll dodge', {
  view: 'three-quarter', ball: LAX_BALL, implement: LAX, thumb: 2,
  cast: [{ pattern: 'lax-screen', at: [110, 40], facing: 90 }],
  keyframes: [
    kf(carry(P(runL, { spine: 16 })), 'air', { move: 0.2, ball: 'head' }),
    kf(carry(P(mirror(P(runL)), { spine: 18 })), 'air', { move: 0.2, ball: 'head', travel: [50, 0] }),
    kf(carry(P({ spine: 24, bend: 14, turn: 30, hipL: 50, kneeL: 50, ankleL: 20, hipR: -10, kneeR: 40, ankleR: -20, hipAbdL: 16 })), 'L', { move: 0.2, ball: 'head', travel: [60, 10] }),
    kf(carry(P(runL, { spine: 18, turn: 40 })), 'air', { hold: 0.3, ball: 'head', travel: [60, 50] }),
  ],
});
/** Partner pushing a stick across the athlete's back numbers. */
def('lax-cross-check-push', 'Cross-check pressure (partner)', {
  view: 'three-quarter', implement: LAX, loop: true, thumb: 0,
  keyframes: [
    kf(holdLax(P({ spine: 20, hipL: 40, kneeL: 30, ankleL: 14, hipR: -10, kneeR: 30, ankleR: -20 }), air(32, 44, 26), air(34, 44, -60)), 'feet', { hold: 0.5, move: 0.5 }),
    kf(holdLax(P({ spine: 24, hipL: 44, kneeL: 36, ankleL: 16, hipR: -12, kneeR: 34, ankleR: -22 }), air(36, 42, 26), air(38, 42, -60)), 'feet', { hold: 0.5, move: 0.5 }),
  ],
});
def('lax-cross-check-absorb', 'Absorb a cross-check and seal', {
  view: 'three-quarter', implement: LAX, thumb: 1,
  cast: [{ pattern: 'lax-cross-check-push', at: [-44, 0], facing: 0, follow: true }],
  keyframes: [
    kf(carry(P(both({ hip: 50, knee: 64, ankle: 26, hipAbd: 24 }), { spine: 30, neck: -14 })), 'feet', { hold: 1.2, move: 0.4 }),
    kf(carry(P(both({ hip: 52, knee: 66, ankle: 26, hipAbd: 24 }), { spine: 32, neck: -14 })), 'feet', { hold: 0.6, move: 0.4 }),
    kf(carry(P(both({ hip: 44, knee: 56, ankle: 24, hipAbd: 26 }), { spine: 24, turn: -90 })), 'feet', { hold: 1 }),
  ],
});
def('lax-inside-roll-shot', 'Inside roll and finish', {
  view: 'three-quarter', ball: LAX_BALL, implement: LAX, thumb: 3,
  cast: [{ pattern: 'lax-defend-stance', at: [100, -20], facing: 180 }],
  keyframes: [
    kf(carry(P(runL, { spine: 16 })), 'air', { move: 0.2, ball: 'head' }),
    kf(carry(P({ spine: 20, hipL: 50, kneeL: 54, ankleL: 20, hipR: -10, kneeR: 40, ankleR: -20, hipAbdL: 12 })), 'L', { hold: 0.1, move: 0.2, ball: 'head', travel: [40, 0] }),
    kf(carry(P({ spine: 20, turn: 150, hipL: 44, kneeL: 50, ankleL: 20, hipR: 30, kneeR: 50, ankleR: -10, hipAbdR: 30 })), 'L', { move: 0.2, ball: 'head' }),
    kf(holdLax(P({ spine: 12, turn: 360, twist: -36, hipL: 40, kneeL: 30, ankleL: 14, hipR: -12, kneeR: 40, ankleR: -20 }), air(0, 44, -4), air(-60, 70, -30)), 'L', { move: 0.12, ball: 'head', travel: [10, 40] }),
    kf(holdLax(P({ spine: 30, turn: 360, twist: 36, hipL: 46, kneeL: 34, ankleL: 18, hipR: -20, kneeR: 36, ankleR: -26 }), air(24, 0, 18), air(44, -50, 40)), 'L+Rtoe', { hold: 0.4, ball: at(400, 50, 0) }),
  ],
});
def('lax-defend-shuffle', 'Defensive slide with the stick on the gloves', {
  view: 'three-quarter', implement: LAX, loop: true, thumb: 0,
  path: { kind: 'line', length: 220, dir: 'left', speed: 110 },
  cast: [{ pattern: 'lax-cradle-carrier', at: [100, 0], facing: 180, follow: true }],
  keyframes: [
    kf(defendStick(P(laxStance, { spine: 26, neck: -14 })), 'air', { move: 0.16 }),
    kf(defendStick(P(laxStance, { spine: 26, neck: -14, hipAbdL: 30, hipAbdR: 10, kneeR: 40, lift: 2 })), 'air', { move: 0.16, travel: [0, 22] }),
  ],
});
/** Feeder behind the net: catches, then passes across to the crease. */
def('lax-quick-stick', 'Quick stick on the crease', {
  view: 'three-quarter', ball: LAX_BALL, implement: LAX, thumb: 1,
  cast: [{ pattern: 'lax-catch-pass', at: [260, 60], facing: 180, phase: 0.55 }],
  keyframes: [
    kf(holdLax(P(laxStance, { spine: 14 }), air(20, 34, 4), air(30, 100, -10)), 'feet', { hold: 0.5, move: 0.35, ball: 'c0:head', ballArc: 18 }),
    kf(holdLax(P(laxStance, { spine: 16, twist: -6 }), air(22, 34, 4), air(34, 100, -10)), 'feet', { move: 0.1, ball: 'head' }),
    kf(holdLax(P(laxStance, { spine: 22, twist: 20 }), air(28, 26, 8), air(80, 40, 10)), 'feet', { hold: 0.4, ball: at(200, 20, 30) }),
  ],
});

// ── Field hockey ───────────────────────────────────────────────────────────
const FH = { kind: 'hockeystick', leftTop: true, length: 96 };
const FH_BALL = { r: 3.6, color: 'white' };
/** Left hand on top in front of the body, right hand lower; blade at `blade`. */
const fh = (p, blade, top = air(22, 16, 8), share = 0.34) => holdStick(p, blade, top, { leftTop: true, share });
const fhStance = { ...both({ hip: 56, knee: 60, ankle: 26, hipAbd: 16 }), spine: 40, neck: -26 };
const fhLow = { ...both({ hip: 70, knee: 80, ankle: 30, hipAbd: 20 }), spine: 48, neck: -30 };

def('fh-stick-sprint', 'Sprint carrying the stick', {
  view: 'three-quarter', loop: true, thumb: 0, implement: FH,
  path: { kind: 'line', length: 460 },
  keyframes: stickRun((p) => fh(p, air(70, -46, -22), air(18, 14, 6))),
});
/** Indian dribble: the ball pulled across in front, open stick to reverse, while jogging. */
const jogL = [
  { hipL: 34, kneeL: 30, ankleL: 10, hipR: 0, kneeR: 60, ankleR: -20 },
  { hipL: 10, kneeL: 40, ankleL: 20, hipR: 40, kneeR: 70, ankleR: 0, lift: 3 },
];
const jogFrames = [...jogL.map((j) => P(j)), ...jogL.map((j) => mirror(P(j)))];
def('fh-indian-dribble', 'Indian dribble on the move', {
  view: 'three-quarter', loop: true, thumb: 0, implement: FH, ball: FH_BALL,
  path: { kind: 'line', length: 360, speed: 150 },
  keyframes: jogFrames.map((legs, i) => kf(fh(P(legs, { spine: 40, neck: -26 }), ground(64, i % 2 ? 22 : -34, 3)), 'air', { move: 0.16, ball: 'head' })),
});
/** Push pass: side-on, the stick stays on the ball and sweeps it forward. */
const pushPass = (ball) => [
  kf(fh(P(fhStance, { twist: -20, hipL: 50, kneeL: 50, hipR: 50, kneeR: 64 }), ground(40, -26, 3)), 'feet', { hold: 0.5, move: 0.3, ...(ball && { ball: 'head' }) }),
  kf(fh(P(fhStance, { twist: -30, spine: 44 }), ground(20, -36, 3)), 'feet', { hold: 0.1, move: 0.18, ...(ball && { ball: 'head' }) }),
  kf(fh(P({ spine: 40, neck: -24, twist: 10, hipL: 60, kneeL: 60, ankleL: 26, hipR: 10, kneeR: 40, ankleR: -10, hipAbdL: 12, hipAbdR: 12 }), ground(90, -10, 6), air(40, 10, 10)), 'L+Rtoe', { hold: 0.3, move: 0.3, ...(ball && { ball: ball.out, ballArc: 0 }), travel: [16, 0] }),
  kf(fh(P(fhStance), ground(44, -24, 3)), 'feet', { hold: 1.4, ...(ball && { ball: ball.back }) }),
];
def('fh-push-pass-partner', 'Push pass (partner)', { view: 'three-quarter', implement: FH, loop: true, thumb: 0, keyframes: pushPass(null) });
def('fh-push-pass', 'Push pass to a partner', {
  view: 'three-quarter', implement: FH, ball: FH_BALL, loop: true, thumb: 2,
  cast: [{ pattern: 'fh-push-pass-partner', at: [300, -30], facing: 180, phase: 0.5 }],
  keyframes: pushPass({ out: 'c0:head', back: 'head' }),
});
def('fh-hit', 'Hit', {
  view: 'three-quarter', implement: FH, ball: FH_BALL, thumb: 2,
  keyframes: [
    kf(fh(P(fhStance, { twist: -10 }), ground(40, -28, 3), air(22, 16, 4), 0.1), 'feet', { hold: 0.4, move: 0.4, ball: { floor: 'L', dx: 40, dl: -34 } }),
    kf(fh(P(fhStance, { twist: -50, spine: 30, hipR: 60, kneeR: 64 }), air(-60, 80, -60), air(-4, 34, -20), 0.1), 'feet', { hold: 0.1, move: 0.16, ball: { floor: 'L', dx: 40, dl: -34 } }),
    kf(fh(P({ spine: 42, neck: -30, twist: 0, hipL: 60, kneeL: 56, ankleL: 24, hipR: 30, kneeR: 50, ankleR: -4, hipAbdL: 14, hipAbdR: 14 }), ground(40, -30, 3), air(24, 10, -6), 0.1), 'feet', { move: 0.08, ball: 'head' }),
    kf(fh(P({ spine: 30, neck: -16, twist: 40, hipL: 56, kneeL: 50, ankleL: 22, hipR: 10, kneeR: 40, ankleR: -14, hipAbdL: 14, hipAbdR: 14 }), air(80, 60, 50), air(34, 30, 20), 0.1), 'L+Rtoe', { hold: 0.4, ball: at(480, 10, 0) }),
  ],
});
def('fh-drag-flick', 'Drag flick', {
  view: 'three-quarter', implement: FH, ball: FH_BALL, thumb: 3,
  keyframes: [
    kf(fh(P(fhLow, { hipL: 80, kneeL: 70, hipR: 20, kneeR: 90, ankleR: -10 }), ground(30, -30, 3)), 'L', { move: 0.2, ball: { floor: 'L', dx: 60, dl: -30 } }),
    kf(fh(P({ spine: 56, neck: -30, hipL: 100, kneeL: 104, ankleL: 32, hipAbdL: 20, hipR: -10, kneeR: 30, ankleR: -30, hipAbdR: 30 }), ground(-20, -40, 3), air(10, 0, 10)), 'L+Rtoe', { hold: 0.12, move: 0.22, ball: 'head', travel: [60, 0] }),
    kf(fh(P({ spine: 50, neck: -26, twist: 10, hipL: 94, kneeL: 96, ankleL: 32, hipAbdL: 20, hipR: -6, kneeR: 30, ankleR: -30, hipAbdR: 30 }), ground(60, -24, 4), air(40, 4, 16)), 'L+Rtoe', { move: 0.12, ball: 'head' }),
    kf(fh(P({ spine: 24, neck: -10, twist: 36, hipL: 60, kneeL: 40, ankleL: 20, hipR: 10, kneeR: 40, ankleR: -20, hipAbdL: 16, hipAbdR: 16 }), air(110, 60, 30), air(40, 34, 24)), 'L+Rtoe', { hold: 0.4, ball: at(460, 140, 0), travel: [10, 0] }),
  ],
});
/** Receives on the reverse (left) side, transfers to the open stick, passes back. */
def('fh-reverse-receive', 'Reverse-stick receive and return', {
  view: 'three-quarter', implement: FH, ball: FH_BALL, loop: true, thumb: 1,
  cast: [{ pattern: 'fh-push-pass-partner', at: [300, 30], facing: 180, phase: 0.62 }],
  keyframes: [
    kf(fh(P(fhStance, { twist: 20 }), ground(46, 30, 3), air(24, 14, 16)), 'feet', { hold: 0.2, move: 0.5, ball: 'c0:head' }),
    kf(fh(P(fhStance, { twist: 24, spine: 44 }), ground(46, 34, 3), air(24, 12, 18)), 'feet', { hold: 0.2, move: 0.3, ball: 'head' }),
    kf(fh(P(fhStance, { twist: -10 }), ground(44, -26, 3)), 'feet', { hold: 0.2, move: 0.2, ball: 'head' }),
    kf(fh(P(fhStance, { twist: 10, spine: 44 }), ground(90, -10, 6), air(40, 10, 10)), 'feet', { hold: 0.8, move: 0.4, ball: 'c0:head' }),
  ],
});
/** A dribbling attacker (for defending drills): walking, ball on the stick. */
def('fh-dribble-walk', 'Attacker dribbling', {
  view: 'three-quarter', loop: true, thumb: 0, implement: FH,
  keyframes: jogFrames.map((legs, i) => kf(fh(P(legs, { spine: 40, neck: -26 }), ground(64, i % 2 ? 10 : -26, 3)), 'air', { move: 0.2 })),
});
def('fh-shadow-defend', 'Low shadow defending', {
  view: 'three-quarter', loop: true, thumb: 0, implement: FH, ball: FH_BALL,
  path: { kind: 'line', length: 260, dir: 'back', speed: 90 },
  cast: [{ pattern: 'fh-dribble-walk', at: [120, -10], facing: 180, follow: true }],
  keyframes: [
    kf(fh(P(fhLow, { hipL: 76, kneeL: 84, hipR: 60, kneeR: 90, ankleR: 10 }), ground(56, 34, 3), air(20, 6, 20)), 'air', { move: 0.22, ball: 'c0:head' }),
    kf(fh(P(fhLow, { hipL: 60, kneeL: 90, ankleL: 10, hipR: 76, kneeR: 84, lift: 2 }), ground(56, 30, 3), air(20, 6, 20)), 'air', { move: 0.22, ball: 'c0:head' }),
  ],
});
def('fh-block-tackle', 'Block tackle', {
  view: 'three-quarter', implement: FH, ball: FH_BALL, thumb: 2,
  cast: [{ pattern: 'fh-dribble-walk', at: [170, 20], facing: 180 }],
  keyframes: [
    kf(fh(P(jogFrames[0], { spine: 36, neck: -20 }), ground(60, -20, 3)), 'air', { move: 0.24, ball: 'c0:head' }),
    kf(fh(P(fhStance, { hipL: 60, kneeL: 64, hipR: 30, kneeR: 50, ankleR: 0 }), ground(60, 0, 3)), 'L', { move: 0.2, ball: 'c0:head', travel: [30, 0] }),
    kf(fh(P(fhLow, { spine: 56 }), ground(70, -40, 2), air(40, -24, 40), 0.3), 'feet', { hold: 0.4, move: 0.3, ball: { floor: 'L', dx: 64, dl: -10 } }),
    kf(fh(P(fhStance, { twist: -20 }), ground(50, -30, 3)), 'feet', { hold: 0.3, ball: 'head' }),
  ],
});
/** A feeder who passes in (for receiving drills). */
def('fh-feed', 'Feeder push-pass', {
  view: 'three-quarter', implement: FH, thumb: 0,
  keyframes: pushPass(null).map((k, i) => (i === 3 ? { ...k, hold: 0.8 } : k)),
});
def('fh-circle-entry', 'Receive on the move and finish', {
  view: 'three-quarter', implement: FH, ball: FH_BALL, thumb: 2,
  cast: [{ pattern: 'fh-feed', at: [210, 250], facing: 240 }],
  keyframes: [
    kf(fh(P(jogFrames[0], { spine: 36, neck: -20 }), ground(64, -20, 3)), 'air', { move: 0.3, ball: 'c0:head' }),
    kf(fh(P(jogFrames[2], { spine: 36, neck: -20 }), ground(64, -10, 3)), 'air', { move: 0.3, ball: 'c0:head', travel: [50, 0] }),
    kf(fh(P(fhStance, { twist: 10 }), ground(56, 10, 3)), 'feet', { move: 0.16, ball: 'head', travel: [40, 0], ballArc: 0 }),
    kf(fh(P({ spine: 36, neck: -20, twist: 20, hipL: 60, kneeL: 56, ankleL: 24, hipR: 10, kneeR: 40, ankleR: -14, hipAbdL: 14, hipAbdR: 14 }), ground(100, -4, 10), air(46, 20, 14)), 'L+Rtoe', { hold: 0.4, ball: at(420, 30, 0) }),
  ],
});
/** Scoop: the stick laid back under the ball and lifted; the partner traps it dead. */
const scoopTrap = (ball) => [
  kf(fh(P(fhStance, { spine: 46 }), ground(50, -20, 2), air(30, 0, 10), 0.3), 'feet', { hold: 0.5, move: 0.3, ...(ball && { ball: 'head' }) }),
  kf(fh(P(fhStance, { spine: 40, twist: -10 }), ground(40, -20, 3), air(10, 20, 0)), 'feet', { hold: 0.2, move: 0.26, ...(ball && { ball: 'head' }) }),
  kf(fh(P(fhStance, { spine: 30, twist: 6 }), air(80, 10, -10), air(26, 30, 10)), 'feet', { hold: 0.3, move: 0.5, ...(ball && { ball: 'c0:head', ballArc: 70 }) }),
  kf(fh(P(fhStance), ground(46, -20, 3)), 'feet', { hold: 1.2, ...(ball && { ball: 'c0:head' }) }),
];
def('fh-scoop-partner', 'Scoop and trap (partner)', { view: 'three-quarter', implement: FH, loop: true, thumb: 0, keyframes: scoopTrap(null) });
def('fh-scoop-trap', 'Aerial lift and trap', {
  view: 'three-quarter', implement: FH, ball: FH_BALL, loop: true, thumb: 2,
  fixture: { kind: 'cone', at: 150 },
  cast: [{ pattern: 'fh-scoop-partner', at: [300, 0], facing: 180, phase: 0.5 }],
  keyframes: scoopTrap({}).map((k, i) => (i === 3 ? { ...k, ball: 'c0:head' } : k)),
});
def('fh-split-stance-hold', 'Low split stance hold', {
  view: 'three-quarter', implement: FH, thumb: 0,
  keyframes: [
    kf(fh(P({ spine: 44, neck: -26, hipL: 80, kneeL: 90, ankleL: 30, hipAbdL: 24, hipR: -10, kneeR: 40, ankleR: -20, hipAbdR: 24 }), ground(70, -20, 2)), 'L+Rtoe', { hold: 1.5, move: 0.8 }),
    kf(fh(P({ spine: 46, neck: -26, hipL: 84, kneeL: 96, ankleL: 32, hipAbdL: 24, hipR: -10, kneeR: 44, ankleR: -20, hipAbdR: 24 }), ground(72, -20, 2)), 'L+Rtoe', { hold: 1.5 }),
  ],
});
/** T-drill with the stick: sprint up, shuffle left, across right, back to centre, backpedal. */
const shuffle = (open) => P(fhStance, open ? { hipAbdL: 30, hipAbdR: 30 } : { hipAbdL: 12, hipAbdR: 12, lift: 3 });
const tFrames = [];
for (let i = 0; i < 4; i++) tFrames.push(kf(fh(P(i % 2 ? mirror(P(runL)) : P(runL), { spine: 24 }), air(70, -40, -20)), 'air', { move: 0.14, travel: [45, 0] }));
const sh = (dl, n) => { for (let i = 0; i < n; i++) tFrames.push(kf(fh(shuffle(i % 2 === 0), ground(50, -20, 10)), 'air', { move: 0.14, travel: [0, dl] })); };
sh(30, 4); sh(-30, 8); sh(30, 4);
for (let i = 0; i < 4; i++) tFrames.push(kf(fh(P({ spine: 30, hipL: 44, kneeL: 60, ankleL: 24, hipR: 64, kneeR: 90, ankleR: -10 }, i % 2 ? {} : { lift: 2 }), air(60, -40, -20)), 'air', { move: 0.14, travel: [-45, 0] }));
tFrames.push(kf(fh(P(fhStance), ground(50, -20, 10)), 'feet', { hold: 0.4 }));
def('fh-t-drill', 'T-drill with the stick', { view: 'three-quarter', implement: FH, thumb: 5, keyframes: tFrames });

// ── Field-hockey goalkeeping (stick in the right hand, left glove open) ──
const GK_STICK = { kind: 'stick', at: 'R' };
const gkArms = { shoulderL: 50, shoulderAbdL: 24, elbowL: 40, shoulderR: 30, shoulderAbdR: 30, elbowR: 30 };
const gkReady = P(both({ hip: 44, knee: 54, ankle: 24, hipAbd: 14 }), gkArms, { spine: 26, neck: -16 });
def('fh-gk-ready', 'Goalkeeper ready stance', {
  view: 'three-quarter', implement: GK_STICK, loop: true, thumb: 0,
  keyframes: [kf(gkReady, 'feet', { hold: 0.6, move: 0.4 }), kf(P(gkReady, { spine: 28, kneeL: 58, kneeR: 58, hipL: 46, hipR: 46 }), 'feet', { hold: 0.6, move: 0.4 })],
});
/** A kick save to the right with the inside of the kicker: the leg sweeps out low. */
const kickR = P(gkArms, { spine: 20, neck: -20, bend: 10, hipL: 50, kneeL: 60, ankleL: 24, hipAbdL: 10, hipR: 20, kneeR: 10, ankleR: 10, hipAbdR: 54, hipRotR: 40 });
const kickL = mirror(kickR);
def('fh-gk-kick-save', 'Reaction kick save', {
  view: 'three-quarter', implement: GK_STICK, ball: FH_BALL, thumb: 2,
  cast: [{ pattern: 'fh-push-pass-partner', at: [330, 10], facing: 180, phase: 0.1 }],
  keyframes: [
    kf(gkReady, 'feet', { hold: 0.5, move: 0.35, ball: 'c0:head' }),
    kf(gkReady, 'feet', { move: 0.14, ball: { floor: 'R', dx: 40, dl: -40 } }),
    kf(kickR, 'L', { hold: 0.2, move: 0.3, ball: 'footR' }),
    kf(gkReady, 'feet', { hold: 0.5, ball: at(260, 20, -200) }),
  ],
});
def('fh-gk-lateral-kick', 'Lateral shuffle and kick', {
  view: 'three-quarter', implement: GK_STICK, thumb: 3,
  keyframes: [
    kf(gkReady, 'feet', { hold: 0.2, move: 0.14 }),
    kf(P(gkReady, { hipAbdL: 28, hipAbdR: 8, lift: 2 }), 'air', { move: 0.14, travel: [0, 40] }),
    kf(gkReady, 'feet', { move: 0.2, travel: [0, 40] }),
    kf(kickL, 'R', { hold: 0.2, move: 0.3 }),
    kf(gkReady, 'feet', { hold: 0.2, move: 0.14 }),
    kf(P(gkReady, { hipAbdR: 28, hipAbdL: 8, lift: 2 }), 'air', { move: 0.14, travel: [0, -40] }),
    kf(gkReady, 'feet', { move: 0.14, travel: [0, -40] }),
    kf(P(gkReady, { hipAbdR: 28, hipAbdL: 8, lift: 2 }), 'air', { move: 0.14, travel: [0, -40] }),
    kf(gkReady, 'feet', { move: 0.2, travel: [0, -40] }),
    kf(kickR, 'L', { hold: 0.2, move: 0.3 }),
    kf(gkReady, 'feet', { hold: 0.2 }),
  ],
});
/** The low block: down on the right side, pads stacked along the ground, hands up in front. */
const blockDown = P({ bend: -80, spine: 10, neck: 16, ...both({ hip: 30, knee: 30 }), shoulderL: 90, elbowL: 40, shoulderAbdL: 20, shoulderR: 100, elbowR: 30 });
def('fh-gk-low-block', 'Low block slide', {
  view: 'three-quarter', implement: GK_STICK, ball: FH_BALL, thumb: 2,
  cast: [{ pattern: 'fh-push-pass-partner', at: [320, -40], facing: 180, phase: 0.05 }],
  keyframes: [
    kf(gkReady, 'feet', { hold: 0.4, move: 0.3, ball: 'c0:head' }),
    kf(P(gkReady, { bend: -30, hipAbdR: 40, kneeR: 20, hipR: 20 }), 'L', { move: 0.18, ball: { floor: 'L', dx: 60, dl: -60 } }),
    kf(blockDown, 'air', { hold: 0.6, move: 0.4, ball: { floor: 'L', dx: 26, dl: -60 }, travel: [0, -50] }),
    kf(P(both({ hip: 0, knee: 90, ankle: -60 }), gkArms, { spine: 10 }), 'knees', { move: 0.3, ball: { floor: 'L', dx: 30, dl: -70 } }),
    kf(gkReady, 'feet', { hold: 0.3, ball: { floor: 'L', dx: 30, dl: -70 } }),
  ],
});
def('fh-gk-block-get-up', 'Block save and get up', {
  view: 'front', implement: GK_STICK, thumb: 1,
  keyframes: [
    kf(gkReady, 'feet', { hold: 0.3, move: 0.2 }),
    kf(blockDown, 'air', { hold: 0.3, move: 0.3, travel: [0, -50] }),
    kf(P(both({ hip: 0, knee: 90, ankle: -60 }), gkArms, { spine: 10 }), 'knees', { move: 0.2 }),
    kf(P({ spine: 20, hipL: 80, kneeL: 90, ankleL: 20, hipR: 0, kneeR: 90, ankleR: -60 }, gkArms), 'L+Rknee', { move: 0.2 }),
    kf(gkReady, 'feet', { hold: 0.5 }),
  ],
});
def('fh-gk-angle-walk', 'Arc positioning', {
  view: 'three-quarter', implement: GK_STICK, loop: true, thumb: 0,
  path: { kind: 'arc', radius: 180, angle: 100, speed: 50 },
  keyframes: [
    kf(gkReady, 'feet', { hold: 0.5, move: 0.14 }),
    kf(P(gkReady, { hipAbdL: 26, hipAbdR: 8, lift: 2 }), 'air', { move: 0.14 }),
    kf(gkReady, 'feet', { move: 0.14 }),
    kf(P(gkReady, { hipAbdL: 26, hipAbdR: 8, lift: 2 }), 'air', { move: 0.14 }),
  ],
});
/** A partner rolling a ball in along the ground, underhand. */
def('ball-roll-feed', 'Rolling a ball in (partner)', {
  view: 'three-quarter', loop: true, thumb: 1,
  keyframes: [
    kf(P({ spine: 30, hipL: 50, kneeL: 60, ankleL: 24, hipR: 10, kneeR: 50, ankleR: -10, shoulderR: -30, elbowR: 10 }), 'feet', { hold: 0.3, move: 0.4 }),
    kf(P({ spine: 44, hipL: 70, kneeL: 80, ankleL: 30, hipR: 20, kneeR: 70, ankleR: -10, shoulderR: 60, elbowR: 10 }), 'feet', { hold: 0.2, move: 0.4 }),
    kf(P({ spine: 20, ...both({ hip: 20, knee: 20, ankle: 10 }) }), 'feet', { hold: 1.2 }),
  ],
});
def('fh-gk-kick-clear', 'Kicker clearance', {
  view: 'three-quarter', implement: GK_STICK, ball: FH_BALL, loop: true, thumb: 2,
  cast: [{ pattern: 'ball-roll-feed', at: [320, 0], facing: 180, phase: 0.9 }],
  keyframes: [
    kf(gkReady, 'feet', { hold: 0.3, move: 0.5, ball: 'c0:R' }),
    kf(P(gkReady, { hipR: 20, kneeR: 30, hipRotR: 40 }), 'L', { move: 0.14, ball: { floor: 'L', dx: 40, dl: -16 } }),
    kf(P(gkArms, { spine: 20, hipL: 40, kneeL: 40, ankleL: 18, hipR: 40, kneeR: 20, ankleR: 10, hipAbdR: 10, hipRotR: 50, twist: 20 }), 'L', { hold: 0.3, move: 0.4, ball: 'footR' }),
    kf(gkReady, 'feet', { hold: 0.8, ball: at(260, 20, 220) }),
  ],
});
/** Deep lateral lunge, low squat (elbows push the knees out), other side, then down into 90/90 and back up. */
const latLunge = solve(P({ hipL: 84, kneeL: 100, ankleL: 30, hipAbdL: 30, hipRotL: -12, hipR: 6, kneeR: 0, spine: 34, neck: -20, shoulderL: 84, shoulderR: 84, elbowL: 20, elbowR: 20 }), 'hipAbdR', (sk) => sk.R.ankle[1] - sk.L.ankle[1], 0, 85);
const seat9090 = (sd) => P({ spine: 4, hipL: 80, kneeL: 90, hipRotL: -60 * sd, hipAbdL: 30, hipR: 60, kneeR: 90, hipRotR: 60 * sd, hipAbdR: 30, turn: 20 * sd, shoulderL: 20, shoulderR: 20 });
def('gk-hip-opener-flow', 'Keeper hip-opener flow', {
  view: 'front', thumb: 2,
  keyframes: [
    kf(P(both({ hipAbd: 20 })), 'feet', { hold: 0.3, move: 1 }),
    kf(latLunge, 'feet', { hold: 1, move: 1 }),
    kf(P(both({ hip: 110, knee: 130, ankle: 34, hipAbd: 30, hipRot: -10, shoulder: 44, shoulderAbd: 26, elbow: 116 }), { spine: 30, neck: -20 }), 'feet', { hold: 1, move: 1 }),
    kf(mirror(latLunge), 'feet', { hold: 1, move: 1.2 }),
    kf(seat9090(1), 'air', { hold: 1, move: 1 }),
    kf(seat9090(-1), 'air', { hold: 1, move: 1.2 }),
    kf(P(both({ hipAbd: 20 })), 'feet', { hold: 0.3 }),
  ],
});

// ── Inline and floor hockey (left shot, right hand on top) ─────────────────
const HK = { kind: 'hockeystick' };
const PUCK = { r: 3.2, color: 'black' };
const hk = (p, blade, top = air(12, 4, -8)) => holdStick(p, blade, top);
const hkStance = P({ spine: 38, neck: -24, ...both({ hip: 50, knee: 58, ankle: 26, hipAbd: 16 }) });
const skateGlide = { spine: 40, neck: -26 };
def('hockey-backward-c-cuts', 'Backward C-cuts', {
  view: 'three-quarter', loop: true, thumb: 0, implement: HK,
  path: { kind: 'line', length: 380, dir: 'back', speed: 150 },
  keyframes: [
    kf(hk(P(skateGlide, { spine: 20, ...both({ hip: 50, knee: 70, ankle: 30, hipAbd: 10 }), hipAbdL: 30, hipRotL: 30, kneeL: 60 }), ground(70, 10)), 'air', { move: 0.35 }),
    kf(hk(P(skateGlide, { spine: 20, ...both({ hip: 54, knee: 76, ankle: 30, hipAbd: 12 }) }), ground(70, 10)), 'air', { move: 0.35 }),
    kf(hk(P(skateGlide, { spine: 20, ...both({ hip: 50, knee: 70, ankle: 30, hipAbd: 10 }), hipAbdR: 30, hipRotR: 30, kneeR: 60 }), ground(70, 10)), 'air', { move: 0.35 }),
    kf(hk(P(skateGlide, { spine: 20, ...both({ hip: 54, knee: 76, ankle: 30, hipAbd: 12 }) }), ground(70, 10)), 'air', { move: 0.35 }),
  ],
});
def('inline-powerslide', 'Powerslide stop', {
  view: 'three-quarter', thumb: 2,
  keyframes: [
    kf(P(skateGlide, { hipL: 62, kneeL: 76, ankleL: 30, hipR: 20, kneeR: 8, ankleR: -10, hipAbdR: 42, hipRotR: -34, shoulderL: 60, shoulderR: -30, elbowL: 30, elbowR: 30 }), 'air', { move: 0.24 }),
    kf(P(skateGlide, { hipR: 62, kneeR: 76, ankleR: 30, hipL: 20, kneeL: 8, ankleL: -10, hipAbdL: 42, hipRotL: -34, shoulderR: 60, shoulderL: -30, elbowL: 30, elbowR: 30 }), 'air', { move: 0.3, travel: [60, 0] }),
    kf(P({ spine: 20, neck: -10, turn: 30, hipL: 80, kneeL: 96, ankleL: 32, hipAbdL: 8, hipR: 10, kneeR: 6, ankleR: 0, hipAbdR: 50, hipRotR: 60, shoulderL: 50, shoulderR: 40, shoulderAbdR: 40, elbowL: 30, elbowR: 30 }), 'feet', { hold: 0.5, move: 0.3, travel: [70, 0] }),
    kf(P(skateGlide, { hipR: 62, kneeR: 76, ankleR: 30, hipL: 20, kneeL: 8, ankleL: -10, hipAbdL: 42, hipRotL: -34, shoulderR: 60, shoulderL: -30, elbowL: 30, elbowR: 30, turn: 180 }), 'air', { hold: 0.2 }),
  ],
});
def('hockey-figure8-handling', 'Figure-eight stickhandling', {
  view: 'three-quarter', loop: true, thumb: 0, implement: { ...HK, puck: true },
  path: { kind: 'figure8', radius: 90, speed: 170 },
  keyframes: [
    kf(hk(P(skateGlide, { hipL: 62, kneeL: 76, ankleL: 30, hipR: 20, kneeR: 8, ankleR: -10, hipAbdR: 42, hipRotR: -34 }), ground(80, 30)), 'air', { move: 0.26 }),
    kf(hk(P(skateGlide, { hipL: 60, kneeL: 74, ankleL: 30, hipR: 58, kneeR: 90, ankleR: -4, hipAbdR: 8 }), ground(80, -10)), 'air', { move: 0.26 }),
    kf(hk(P(skateGlide, { hipR: 62, kneeR: 76, ankleR: 30, hipL: 20, kneeL: 8, ankleL: -10, hipAbdL: 42, hipRotL: -34 }), ground(80, 30)), 'air', { move: 0.26 }),
    kf(hk(P(skateGlide, { hipR: 60, kneeR: 74, ankleR: 30, hipL: 58, kneeL: 90, ankleL: -4, hipAbdL: 8 }), ground(80, -10)), 'air', { move: 0.26 }),
  ],
});
/** Pass (a forehand sweep) and receive (blade soft behind the puck). */
const hockeyPassReceive = (ball) => [
  kf(hk(P(hkStance, { twist: 20 }), ground(60, 40)), 'feet', { hold: 0.3, move: 0.3, ...(ball && { ball: 'head' }) }),
  kf(hk(P(hkStance, { twist: -16, spine: 34 }), ground(80, -10), air(20, 10, -2)), 'feet', { hold: 0.2, move: 0.5, ...(ball && { ball: ball.out }) }),
  kf(hk(P(hkStance, { twist: 10 }), ground(70, 20)), 'feet', { hold: 1.2, ...(ball && { ball: ball.back }) }),
];
def('hockey-pass-partner', 'Pass and receive (partner)', { view: 'three-quarter', implement: HK, loop: true, thumb: 0, keyframes: hockeyPassReceive(null) });
def('hockey-passing-pairs', 'Passing in pairs', {
  view: 'three-quarter', implement: HK, ball: PUCK, loop: true, thumb: 1,
  cast: [{ pattern: 'hockey-pass-partner', at: [260, 0], facing: 180, phase: 0.5 }],
  keyframes: hockeyPassReceive({ out: 'c0:head', back: 'head' }),
});
def('hockey-give-and-go', 'Give-and-go', {
  view: 'three-quarter', implement: HK, ball: PUCK, thumb: 1,
  cast: [{ pattern: 'hockey-pass-partner', at: [200, 150], facing: 220, phase: 0.3 }],
  keyframes: [
    kf(hk(P(skateGlide, { hipL: 62, kneeL: 76, ankleL: 30, hipR: 20, kneeR: 8, ankleR: -10, hipAbdR: 42, hipRotR: -34 }), ground(80, 20)), 'air', { move: 0.3, ball: 'head' }),
    kf(hk(P(skateGlide, { twist: -20, hipL: 60, kneeL: 74, ankleL: 30, hipR: 58, kneeR: 90, ankleR: -4 }), ground(90, -10), air(24, 10, -2)), 'air', { move: 0.5, ball: 'c0:head', travel: [60, 0] }),
    kf(hk(P(skateGlide, { hipR: 62, kneeR: 76, ankleR: 30, hipL: 20, kneeL: 8, ankleL: -10, hipAbdL: 42, hipRotL: -34 }), ground(80, 20)), 'air', { move: 0.4, ball: 'c0:head', travel: [100, 0] }),
    kf(hk(P(skateGlide, { hipL: 62, kneeL: 76, ankleL: 30, hipR: 20, kneeR: 8, ankleR: -10, hipAbdR: 42, hipRotR: -34 }), ground(80, 30)), 'air', { move: 0.3, ball: 'head', travel: [100, 0] }),
    kf(hk(P(hkStance, { twist: -30, spine: 30 }), ground(90, -20), air(26, 14, -4)), 'L+Rtoe', { hold: 0.4, ball: at(400, 20, 0), travel: [40, 0] }),
  ],
});
/** Walking while moving the puck side to side (floor hockey, gym floor). */
const walkL = [
  { hipL: 24, kneeL: 10, ankleL: 10, hipR: -12, kneeR: 20, ankleR: -20 },
  { hipL: 4, kneeL: 14, ankleL: 4, hipR: 16, kneeR: 50, ankleR: 0 },
];
const walkFrames = [...walkL.map((w) => P(w)), ...walkL.map((w) => mirror(P(w)))];
def('hockey-stickhandling-walk', 'Walking stickhandling', {
  view: 'three-quarter', loop: true, thumb: 0, implement: { ...HK, puck: true },
  path: { kind: 'line', length: 300, speed: 80 },
  keyframes: walkFrames.map((w, i) => kf(hk(P(w, { spine: 30, neck: -20 }), ground(70, i % 2 ? -14 : 30)), 'air', { move: 0.24 })),
});
def('hockey-stop-and-trap', 'Stop and trap the puck, go again', {
  view: 'three-quarter', thumb: 4, implement: HK, ball: PUCK,
  keyframes: [
    ...walkFrames.map((w, i) => kf(hk(P(w, { spine: 30, neck: -20 }), ground(70, i % 2 ? -10 : 26)), 'air', { move: 0.22, ball: 'head', travel: [30, 0] })),
    kf(hk(P(hkStance, { spine: 44 }), ground(56, 10)), 'feet', { hold: 0.6, move: 0.4, ball: 'head' }),
    kf(hk(P(walkFrames[0], { spine: 30, neck: -20, turn: 70 }), ground(70, 20)), 'air', { move: 0.24, ball: 'head', travel: [10, 30] }),
    kf(hk(P(walkFrames[2], { spine: 30, neck: -20, turn: 70 }), ground(70, 0)), 'air', { hold: 0.2, ball: 'head', travel: [10, 30] }),
  ],
});
def('hockey-walk-to-position', 'Move to a zone and set', {
  view: 'three-quarter', thumb: 4, implement: HK,
  keyframes: [
    ...walkFrames.map((w) => kf(hk(P(w, { spine: 16, neck: -10 }), ground(80, 20)), 'air', { move: 0.24, travel: [34, 0] })),
    kf(hk(P(hkStance, { turn: 40 }), ground(70, 20)), 'feet', { hold: 1.2, move: 0.4, travel: [10, 0] }),
  ],
});
def('hockey-shadow-defend', 'Shadow defending with the stick down', {
  view: 'three-quarter', loop: true, thumb: 0, implement: HK,
  path: { kind: 'line', length: 220, dir: 'left', speed: 70 },
  cast: [{ pattern: 'hockey-stickhandling-walk', at: [130, 0], facing: 180, follow: true }],
  keyframes: [
    kf(hk(P(hkStance), ground(70, 20)), 'air', { move: 0.22 }),
    kf(hk(P(hkStance, { hipAbdL: 30, hipAbdR: 10, kneeR: 40, lift: 2 }), ground(70, 20)), 'air', { move: 0.22 }),
  ],
});
export const STICK_SPORTS = lib.patterns;
