/**
 * Wrestling, judo and fencing. Partner drills show the partner: the one who
 * shoots while you sprawl, the one on top when you stand up, the one you
 * turn in on, the opponent you parry.
 */
import { skeleton } from '../rig3d.js';
import { STRENGTH } from './strength.js';
import { P, air, both, ground, kf, levelFeet, library, mirror, reachBoth, side } from './kit.js';

const lib = library();
const def = lib.def;
const spec = (slug) => {
  const { slug: _s, name: _n, ...rest } = STRENGTH.find((p) => p.slug === slug);
  return rest;
};

// ── Wrestling ──────────────────────────────────────────────────────────────
/** Neutral stance: staggered (left foot forward), low, hips back, hands active in front. */
const stance = (low = 0) => P({ spine: 36 + low / 2, neck: -20, hipL: 60 + low, kneeL: 70 + low, ankleL: 26, hipR: 30 + low, kneeR: 60 + low, ankleR: 10, hipAbdL: 14, hipAbdR: 14, shoulderL: 50, elbowL: 80, shoulderR: 44, elbowR: 84, shoulderAbdL: 14, shoulderAbdR: 14 });
const penStep = [
  kf(stance(), 'feet', { hold: 0.3, move: 0.2 }),
  kf(stance(20), 'feet', { move: 0.18 }),
  kf(P({ spine: 30, neck: -24, hipL: 90, kneeL: 90, ankleL: -10, hipR: -10, kneeR: 60, ankleR: -30, hipAbdL: 10, hipAbdR: 14, shoulderL: 70, elbowL: 60, shoulderR: 70, elbowR: 60 }), 'Lknee+Rtoe', { move: 0.2, travel: [60, 0] }),
  kf(P({ spine: 34, neck: -20, hipL: 80, kneeL: 100, ankleL: -20, hipR: 80, kneeR: 90, ankleR: 20, hipAbdL: 10, hipAbdR: 20, shoulderL: 70, elbowL: 70, shoulderR: 70, elbowR: 70 }), 'Lknee+R', { move: 0.24, travel: [20, 0] }),
  kf(stance(), 'feet', { hold: 0.3, travel: [20, 0] }),
];
def('wrestling-pen-step', 'Penetration step', { view: 'side', thumb: 2, keyframes: penStep });
/** Sprawl: legs thrown back, hips driven down to the mat, chest up on the hands. */
/**
 * Sprawl: legs shot back flat on the mat, hips down, chest up about 35
 * degrees, hands on the mat. The elbow bend is solved so the hands reach
 * the floor with the hips resting on it.
 */
const sprawl = (() => {
  const at = (e) => P({ spine: 55, neck: -30, ...both({ hip: -35, knee: 4, ankle: -30, hipAbd: 22, shoulder: 70, elbow: e }) });
  const handsBelowHips = (e) => { const sk = skeleton(at(e)); return (sk.pelvis[1] - 8) - (Math.min(sk.L.wrist[1] - 2.7, sk.L.handTip[1] - 1.5)); };
  let lo = 0, hi = 140;
  for (let i = 0; i < 30; i++) { const mid = (lo + hi) / 2; if (handsBelowHips(mid) > 0) lo = mid; else hi = mid; }
  return at((lo + hi) / 2);
})();
const sprawlFrames = [
  kf(stance(), 'feet', { hold: 0.4, move: 0.16 }),
  kf(sprawl, 'hands+front', { hold: 0.4, move: 0.3, travel: [-30, 0] }),
  kf(P(sprawl, { turn: 40 }), 'hands+front', { move: 0.3 }),
  kf(stance(), 'feet', { hold: 0.2, travel: [20, 0] }),
];
def('wrestling-sprawl', 'Sprawl', {
  view: 'three-quarter', thumb: 1,
  cast: [{ pattern: 'wrestling-pen-step', at: [150, 0], facing: 180, phase: 0.9 }],
  keyframes: sprawlFrames,
});
def('wrestling-sprawl-and-shoot', 'Sprawl, then shoot', {
  view: 'three-quarter', thumb: 1,
  keyframes: [...sprawlFrames.slice(0, 3), ...penStep.slice(0, 4), kf(stance(), 'feet', { hold: 0.2, travel: [20, 0] })],
});
def('wrestling-motion', 'Stance and motion', {
  view: 'three-quarter', thumb: 0,
  keyframes: [
    kf(stance(), 'feet', { hold: 0.2, move: 0.3 }),
    kf(stance(), 'feet', { move: 0.3, travel: [0, 30] }),
    kf(P(stance(), { shoulderL: 80, elbowL: 40 }), 'feet', { move: 0.3, travel: [20, 20] }),
    kf(stance(24), 'feet', { hold: 0.3, move: 0.3 }),
    kf(P(stance(), { turn: -30, shoulderR: 80, elbowR: 40 }), 'feet', { move: 0.3, travel: [0, -40] }),
    kf(stance(), 'feet', { hold: 0.2, travel: [-20, -10] }),
  ],
});
/** Tie-ups: a hand on the partner's collar (neck), the other controlling a wrist. */
const tie = (collar, wrist) => reachBoth(stance(-10), air(56, 52, collar), air(38, 16, wrist));
def('wrestling-ties-partner', 'Hand fighting (partner)', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [
    kf(tie(-6, 16), 'feet', { hold: 0.3, move: 0.4 }),
    kf(P(tie(-6, 16), { spine: 40 }), 'feet', { hold: 0.2, move: 0.4 }),
  ],
});
def('wrestling-hand-fighting', 'Hand fighting for ties', {
  view: 'three-quarter', loop: true, thumb: 0,
  cast: [{ pattern: 'wrestling-ties-partner', at: [70, 0], facing: 180, phase: 0.3 }],
  keyframes: [
    kf(tie(6, -16), 'feet', { hold: 0.3, move: 0.35 }),
    kf(reachBoth(stance(-6), air(40, 14, 16), air(40, 20, 12)), 'feet', { hold: 0.3, move: 0.35 }),
    kf(P(tie(6, -16), { spine: 44 }), 'feet', { hold: 0.3, move: 0.35 }),
  ],
});
def('towel-hang', 'Towel-grip hang', {
  ...spec('dead-hang'), fixture: { kind: 'bar', above: 26 }, implement: { kind: 'towels', at: 'hands' },
});
def('towel-pull-up', 'Gi / towel-grip pull-up', {
  ...spec('pull-up'), fixture: { kind: 'bar', above: 26 }, implement: { kind: 'towels', at: 'hands' },
});
/** Wrestler's bridge: up on the feet and shoulders, turn onto the shoulder and hip, up to the knees. */
def('wrestling-bridge-turn', 'Bridge and turn', {
  view: 'three-quarter', thumb: 1,
  keyframes: [
    kf(P({ spine: -90, neck: 10, ...both({ hip: 60, knee: 90, ankle: 0, shoulder: 10, elbow: 90, hipAbd: 14 }) }), 'air', { hold: 0.3, move: 0.6 }),
    kf(P({ spine: -90, neck: 20, ...both({ hip: -10, knee: 80, ankle: 10, shoulder: 10, elbow: 90, hipAbd: 14 }) }), 'air', { hold: 0.5, move: 0.5 }),
    kf(P({ spine: -60, neck: 10, bend: 60, ...both({ hip: 20, knee: 90, ankle: 0, hipAbd: 10 }), shoulderL: 60, elbowL: 60 }), 'air', { move: 0.5 }),
    kf(P({ spine: 20, turn: 180, ...both({ hip: 0, knee: 90, ankle: -60 }), shoulderL: 30, shoulderR: 30, elbowL: 60, elbowR: 60 }), 'knees', { hold: 0.4 }),
  ],
});
/** Hip heist: from hands and feet, thread one leg under and kick it through to face the other way. */
const bear = P({ spine: 88, neck: -20, ...both({ hip: 100, knee: 90, ankle: 0, shoulder: 90, elbow: 0 }) });
def('hip-heist', 'Hip heist series', {
  view: 'three-quarter', thumb: 1,
  keyframes: [
    kf(bear, 'hands+Ltoe+Rtoe', { hold: 0.2, move: 0.4 }),
    kf(P({ spine: 60, neck: -10, turn: 60, bend: 40, hipL: 90, kneeL: 10, hipAbdL: -20, hipR: 90, kneeR: 90, ankleR: 0, shoulderR: 80, elbowR: 0, shoulderL: 40, elbowL: 40 }), 'Rhand+R', { move: 0.35 }),
    kf(P(bear, { turn: 180 }), 'hands+Ltoe+Rtoe', { hold: 0.2, move: 0.4, travel: [0, 20] }),
    kf(P({ spine: 60, neck: -10, turn: 120, bend: -40, hipR: 90, kneeR: 10, hipAbdR: -20, hipL: 90, kneeL: 90, ankleL: 0, shoulderL: 80, elbowL: 0, shoulderR: 40, elbowR: 40 }), 'Lhand+L', { move: 0.35 }),
    kf(bear, 'hands+Ltoe+Rtoe', { hold: 0.2, travel: [0, -20] }),
  ],
});
/** Referee's position: the bottom wrestler on hands and knees, the partner on top gripping the waist. */
const bottom = P({ spine: 66, neck: -14, ...both({ hip: 90, knee: 90, ankle: -60, shoulder: 90, elbow: 0 }) });
def('wrestling-top-ride', 'Riding on top (partner)', {
  view: 'three-quarter', thumb: 0,
  keyframes: [
    kf(P({ spine: 60, neck: -10, hipL: 90, kneeL: 90, ankleL: -60, hipR: 40, kneeR: 90, ankleR: -40, shoulderL: 80, elbowL: 40, shoulderR: 70, elbowR: 60 }), 'knees', { hold: 0.6, move: 0.6 }),
    kf(P({ spine: 40, neck: -10, hipL: 70, kneeL: 80, ankleL: 10, hipR: 30, kneeR: 80, ankleR: 10, shoulderL: 60, elbowL: 50, shoulderR: 50, elbowR: 60 }), 'feet', { hold: 0.8, move: 0.5 }),
    kf(stance(), 'feet', { hold: 0.4 }),
  ],
});
def('wrestling-stand-up', 'Stand-up from the bottom', {
  view: 'three-quarter', thumb: 2,
  cast: [{ pattern: 'wrestling-top-ride', at: [-40, 30], facing: 0 }],
  keyframes: [
    kf(bottom, 'hands+knees', { hold: 0.6, move: 0.3 }),
    kf(P({ spine: 60, neck: -10, hipL: 90, kneeL: 90, ankleL: 10, hipR: 90, kneeR: 90, ankleR: -60, shoulderL: 60, elbowL: 40, shoulderR: 80, elbowR: 10 }), 'L+Rknee', { move: 0.3 }),
    kf(P({ spine: 10, neck: 0, hipL: 60, kneeL: 70, ankleL: 20, hipR: 40, kneeR: 70, ankleR: 10, shoulderL: -20, elbowL: 90, shoulderR: -20, elbowR: 90 }), 'feet', { hold: 0.2, move: 0.3 }),
    kf(P(stance(), { turn: 180 }), 'feet', { hold: 0.4 }),
  ],
});
/** Double leg: penetrate, hands locked behind the partner's knees, drive through and turn the corner. */
def('wrestling-taken-down', 'Taken down (partner)', {
  view: 'three-quarter', thumb: 0,
  keyframes: [
    kf(stance(-10), 'feet', { hold: 0.9, move: 0.5 }),
    kf(P({ spine: 10, neck: -10, ...both({ hip: 10, knee: 20, ankle: 0 }), shoulderL: 60, shoulderR: 60, elbowL: 30, elbowR: 30 }), 'feet', { move: 0.4 }),
    kf(P({ spine: -60, neck: 20, ...both({ hip: 80, knee: 90, ankle: 0 }), shoulderL: 30, shoulderR: 30, elbowL: 60, elbowR: 60 }), 'air', { hold: 0.6 }),
  ],
});
def('wrestling-double-leg', 'Double-leg finish', {
  view: 'three-quarter', thumb: 3,
  cast: [{ pattern: 'wrestling-taken-down', at: [130, 0], facing: 180 }],
  keyframes: [
    kf(stance(), 'feet', { hold: 0.3, move: 0.2 }),
    kf(stance(20), 'feet', { move: 0.18 }),
    penStep[2],
    kf(P({ spine: 40, neck: -10, hipL: 80, kneeL: 90, ankleL: -10, hipR: 20, kneeR: 70, ankleR: -20, shoulderL: 90, elbowL: 30, shoulderR: 90, elbowR: 30 }), 'Lknee+Rtoe', { hold: 0.3, move: 0.4 }),
    kf(P({ spine: 60, neck: -20, turn: 40, hipL: 60, kneeL: 70, ankleL: 20, hipR: 20, kneeR: 50, ankleR: -10, shoulderL: 80, elbowL: 50, shoulderR: 80, elbowR: 50 }), 'feet', { hold: 0.4, travel: [30, 20] }),
  ],
});
/** Mat return: hands locked round the partner's waist from behind, step to the side, sweep the far leg. */
def('wrestling-returned', 'Returned to the mat (partner)', {
  view: 'three-quarter', thumb: 0,
  keyframes: [
    kf(P(both({ hip: 20, knee: 30, ankle: 10 }), { spine: 20 }), 'feet', { hold: 0.8, move: 0.6 }),
    kf(bottom, 'hands+knees', { hold: 0.8 }),
  ],
});
def('wrestling-mat-return', 'Mat return', {
  view: 'three-quarter', thumb: 2,
  cast: [{ pattern: 'wrestling-returned', at: [40, 0], facing: 0 }],
  keyframes: [
    kf(reachBoth(P(both({ hip: 30, knee: 40, ankle: 16 }), { spine: 30 }), air(34, 10, 14), air(34, 10, -14)), 'feet', { hold: 0.4, move: 0.4 }),
    kf(reachBoth(P({ spine: 40, hipL: 40, kneeL: 50, ankleL: 20, hipR: 20, kneeR: 40, ankleR: 10, hipAbdR: 30 }), air(34, 0, 14), air(34, 0, -14)), 'feet', { move: 0.3, travel: [0, -20] }),
    kf(P({ spine: 70, neck: -10, hipL: 90, kneeL: 90, ankleL: -60, hipR: 40, kneeR: 90, ankleR: -40, shoulderL: 80, elbowL: 40, shoulderR: 70, elbowR: 60 }), 'knees', { hold: 0.6, travel: [0, 10] }),
  ],
});

// ── Judo (a jacket/gi is shown as the grips) ─────────────────────────────
/** Back breakfall: sit back chin tucked, roll, slap the mat with both arms at 45°. */
def('judo-breakfall', 'Back breakfall (ukemi)', {
  view: 'three-quarter', thumb: 2,
  keyframes: [
    kf(P(both({ hip: 90, knee: 110, ankle: 30, shoulder: 90, elbow: 0 }), { spine: 30, neck: -30 }), 'feet', { hold: 0.3, move: 0.4 }),
    kf(P(both({ hip: 100, knee: 90, ankle: 10, shoulder: 90, elbow: 0 }), { spine: -30, neck: -40 }), 'air', { move: 0.3 }),
    kf(P(both({ hip: 90, knee: 60, ankle: 0, shoulder: 45, shoulderAbd: 45, elbow: 0 }), { spine: -80, neck: -40 }), 'back', { hold: 0.5, move: 0.5 }),
    kf(P(both({ hip: 100, knee: 90, ankle: 10, shoulder: 90, elbow: 0 }), { spine: -30, neck: -40 }), 'air', { move: 0.5 }),
    kf(P(both({ hip: 90, knee: 110, ankle: 30, shoulder: 90, elbow: 0 }), { spine: 30, neck: -30 }), 'feet', { hold: 0.2 }),
  ],
});
/** Grips on the partner's sleeve (left hand) and lapel (right hand). */
const grips = (p, pull = 0) => reachBoth(p, air(40 - pull, 28, 14), air(48 - pull, 44, -4));
const judoStand = (extra = {}) => P(both({ hip: 20, knee: 26, ankle: 10, hipAbd: 12 }), { spine: 14, neck: -10 }, extra);
def('judo-uke', 'Partner (uke)', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [
    kf(grips(judoStand()), 'feet', { hold: 0.6, move: 0.4 }),
    kf(grips(judoStand({ spine: 22, ankleL: -20, ankleR: -20 }), -6), 'Ltoe+Rtoe', { hold: 0.4, move: 0.4 }),
  ],
});
def('judo-uchikomi', 'Uchikomi (turn-in) entries', {
  view: 'three-quarter', thumb: 2,
  cast: [{ pattern: 'judo-uke', at: [70, 0], facing: 180, phase: 0.2 }],
  keyframes: [
    kf(grips(judoStand()), 'feet', { hold: 0.3, move: 0.3 }),
    kf(grips(judoStand({ spine: 4 }), 10), 'feet', { move: 0.25 }),
    kf(P({ turn: 180, spine: 30, neck: -10, ...both({ hip: 50, knee: 70, ankle: 26, hipAbd: 14 }), shoulderL: 110, elbowL: 20, shoulderR: 60, elbowR: 90 }), 'feet', { hold: 0.4, move: 0.3, travel: [54, 0] }),
    kf(grips(judoStand()), 'feet', { hold: 0.2, travel: [-54, 0] }),
  ],
});
def('judo-kuzushi', 'Kuzushi (off-balancing) pull', {
  view: 'three-quarter', loop: true, thumb: 1,
  cast: [{ pattern: 'judo-uke', at: [70, 0], facing: 180 }],
  keyframes: [
    kf(grips(judoStand()), 'feet', { hold: 0.5, move: 0.4 }),
    kf(grips(judoStand({ spine: 4, hipL: 10, kneeL: 10, ankleL: 0, hipR: -10, kneeR: 30, ankleR: -10 }), 14), 'L+Rtoe', { hold: 0.3, move: 0.4, travel: [-12, 0] }),
  ],
});
def('judo-grip-fight', 'Randori (standing practice)', {
  view: 'three-quarter', loop: true, thumb: 0,
  cast: [{ pattern: 'judo-uke', at: [70, 0], facing: 180, phase: 0.5 }],
  keyframes: [
    kf(grips(judoStand()), 'feet', { move: 0.5 }),
    kf(grips(judoStand({ turn: -10 }), 6), 'feet', { move: 0.5, travel: [0, 20] }),
    kf(grips(judoStand({ turn: 10 }), -4), 'feet', { move: 0.5, travel: [0, -20] }),
  ],
});
/** Newaza: partner flat on the back; kesa-gatame (beside, arm round the head), then yoko-shiho (across the chest). */
def('judo-held-down', 'Held down (partner)', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 40, knee: 70, ankle: 0, shoulder: 40, elbow: 60 }), { spine: -90, neck: 10 }), 'air', { hold: 0.5, move: 0.8 }),
    kf(P(both({ hip: 50, knee: 80, ankle: 0, shoulder: 60, elbow: 60 }), { spine: -90, neck: 10, bend: 8 }), 'air', { hold: 0.5, move: 0.8 }),
  ],
});
def('judo-newaza', 'Hold-down transitions', {
  view: 'three-quarter', thumb: 1,
  cast: [{ pattern: 'judo-held-down', at: [0, 50], facing: 90 }],
  keyframes: [
    kf(P({ spine: 20, neck: -10, hipL: 90, kneeL: 90, ankleL: -40, hipR: 40, kneeR: 100, ankleR: -20, shoulderL: 90, elbowL: 60, shoulderR: 60, elbowR: 80 }), 'air', { hold: 0.4, move: 0.6 }),
    kf(P({ spine: -20, neck: -10, bend: 20, hipL: 90, kneeL: 20, hipAbdL: 30, hipR: 20, kneeR: 90, ankleR: 0, shoulderL: 100, elbowL: 70, shoulderR: 50, elbowR: 40 }), 'air', { hold: 0.8, move: 0.7 }),
    kf(P({ spine: 84, neck: -10, ...both({ hip: 70, knee: 100, ankle: -60, hipAbd: 30 }), shoulderL: 70, elbowL: 50, shoulderR: 70, elbowR: 50 }), 'knees', { hold: 0.8 }),
  ],
});
def('band-throw-rotation', 'Band throw rotation', {
  view: 'three-quarter', implement: { kind: 'band', at: 'hands', to: [90, 60, 0] }, thumb: 2,
  keyframes: [
    kf(P(both({ hip: 20, knee: 26, ankle: 10, hipAbd: 12, shoulder: 80, elbow: 20 }), { spine: 14 }), 'feet', { hold: 0.3, move: 0.4 }),
    kf(P({ spine: 10, hipL: 30, kneeL: 30, ankleL: 10, hipR: 0, kneeR: 20, ankleR: -10, ...both({ shoulder: 80, elbow: 20 }) }), 'L+Rtoe', { move: 0.3, travel: [20, 0] }),
    kf(P({ turn: 180, spine: 30, ...both({ hip: 50, knee: 70, ankle: 26, hipAbd: 14 }), shoulderL: 110, elbowL: 20, shoulderR: 60, elbowR: 90 }), 'feet', { hold: 0.4, move: 0.5, travel: [10, 0] }),
    kf(P(both({ hip: 20, knee: 26, ankle: 10, hipAbd: 12, shoulder: 80, elbow: 20 }), { spine: 14 }), 'feet', { hold: 0.2, travel: [-30, 0] }),
  ],
});

// ── Fencing (right-handed: right foot and sword arm lead) ─────────────────
const SWORD = { kind: 'sword', at: 'R' };
const enGarde = (extra = {}) => P({ twist: 50, spine: 4, neck: -4, neckTurn: -40,
  hipR: 40, kneeR: 54, ankleR: 20, hipL: 10, kneeL: 50, ankleL: 20, hipRotL: -30, hipAbdL: 16, hipAbdR: 6,
  shoulderR: 40, shoulderAbdR: 14, elbowR: 60, shoulderL: -10, shoulderAbdL: 80, elbowL: 90 }, extra);
const lunge = (extra = {}) => levelFeet(P({ twist: 50, spine: 12, neck: -4, neckTurn: -40,
  hipR: 84, kneeR: 90, ankleR: 20, hipL: -30, kneeL: 4, ankleL: -10, hipRotL: -30, hipAbdL: 16, hipAbdR: 4,
  shoulderR: 90, shoulderAbdR: 6, elbowR: 0, shoulderL: -40, shoulderAbdL: 30, elbowL: 0 }, extra), 'L', 'hipL');
const advance = (x) => [kf(enGarde({ hipR: 50, kneeR: 40 }), 'L', { move: 0.14, travel: [x * 0.6, 0] }), kf(enGarde(), 'feet', { move: 0.14, travel: [x * 0.4, 0] })];
const retreat = (x) => [kf(enGarde({ hipL: 0, kneeL: 40 }), 'R', { move: 0.14, travel: [-x * 0.6, 0] }), kf(enGarde(), 'feet', { move: 0.14, travel: [-x * 0.4, 0] })];
def('fence-ladder', 'Advance–retreat ladder', {
  view: 'side', implement: SWORD, thumb: 7,
  keyframes: [
    kf(enGarde(), 'feet', { hold: 0.3, move: 0.14 }),
    ...advance(30), ...advance(30), ...retreat(30), ...advance(30),
    kf(P(enGarde(), { shoulderR: 90, elbowR: 0 }), 'feet', { move: 0.1 }),
    kf(lunge(), 'feet', { hold: 0.3, move: 0.3, travel: [50, 0] }),
    kf(enGarde(), 'feet', { hold: 0.3, travel: [-50, 0] }),
  ],
});
def('fence-footwork-loop', 'Bout footwork', {
  view: 'side', implement: SWORD, loop: true, thumb: 0,
  keyframes: [...advance(26), ...advance(26), ...retreat(26), kf(lunge(), 'feet', { hold: 0.2, move: 0.26, travel: [44, 0] }), kf(enGarde(), 'feet', { move: 0.26, travel: [-44, 0] }), ...retreat(26)],
});
/** The follower in the distance game: retreats as the leader advances, and out of reach of the lunge. */
def('fence-footwork-follow', 'Keeping distance (partner)', {
  view: 'side', implement: SWORD, loop: true, thumb: 0,
  keyframes: [...retreat(26), ...retreat(26), ...advance(26), kf(enGarde({ hipL: 0, kneeL: 40 }), 'R', { hold: 0.2, move: 0.26, travel: [-26, 0] }), kf(enGarde(), 'feet', { move: 0.26, travel: [-18, 0] }), ...advance(26)],
});
def('fence-mirror-distance', 'Mirror distance game', {
  view: 'side', implement: SWORD, loop: true, thumb: 0,
  cast: [{ pattern: 'fence-footwork-follow', at: [210, 0], facing: 180 }],
  keyframes: [...advance(26), ...advance(26), ...retreat(26), kf(lunge(), 'feet', { hold: 0.2, move: 0.26, travel: [44, 0] }), kf(enGarde(), 'feet', { move: 0.26, travel: [-44, 0] }), ...retreat(26)],
});
def('fence-lunge-target', 'Lunge to a target', {
  view: 'side', implement: SWORD, fixture: { kind: 'wall', at: 170 }, thumb: 2,
  keyframes: [
    kf(enGarde(), 'feet', { hold: 0.4, move: 0.14 }),
    kf(P(enGarde(), { shoulderR: 90, elbowR: 0 }), 'feet', { move: 0.14 }),
    kf(lunge(), 'feet', { hold: 0.4, move: 0.3, travel: [60, 0] }),
    kf(enGarde(), 'feet', { hold: 0.3, travel: [-60, 0] }),
  ],
});
def('fence-point-circles', 'Point-control circles', {
  view: 'side', implement: SWORD, fixture: { kind: 'wall', at: 110 }, loop: true, thumb: 0,
  keyframes: [0, 1, 2, 3].map((i) => kf(P(enGarde(), { shoulderR: 84, elbowR: 6, wristR: [8, 0, -8, 0][i], shoulderRotR: [0, 8, 0, -8][i] }), 'feet', { move: 0.2 })),
});
/** Partner signals by opening a hand; the fencer extends and lunges to it. */
def('signal-partner', 'Partner giving a signal', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 6, knee: 8, hipAbd: 8 }), { spine: 4, shoulderL: 20, elbowL: 90, shoulderR: 20, elbowR: 90 }), 'feet', { hold: 0.9, move: 0.2 }),
    kf(P(both({ hip: 6, knee: 8, hipAbd: 8 }), { spine: 4, shoulderL: 80, elbowL: 10, shoulderAbdL: 30, shoulderR: 20, elbowR: 90 }), 'feet', { hold: 0.8, move: 0.3 }),
  ],
});
def('fence-reaction', 'Reaction lunge', {
  view: 'side', implement: SWORD, loop: true, thumb: 2,
  cast: [{ pattern: 'signal-partner', at: [230, 0], facing: 180 }],
  keyframes: [
    kf(enGarde(), 'feet', { hold: 1.0, move: 0.1 }),
    kf(P(enGarde(), { shoulderR: 90, elbowR: 0 }), 'feet', { move: 0.12 }),
    kf(lunge(), 'feet', { hold: 0.4, move: 0.3, travel: [60, 0] }),
    kf(enGarde(), 'feet', { move: 0.3, travel: [-60, 0] }),
  ],
});
def('fence-fleche', 'Flèche', {
  view: 'side', implement: SWORD, thumb: 2,
  keyframes: [
    kf(enGarde(), 'feet', { hold: 0.4, move: 0.12 }),
    kf(P(enGarde({ spine: 20, ankleR: 30 }), { shoulderR: 90, elbowR: 0 }), 'R', { move: 0.12 }),
    kf(P({ twist: 40, spine: 30, neckTurn: -30, hipL: 70, kneeL: 60, ankleL: 10, hipR: -20, kneeR: 20, ankleR: -30, shoulderR: 90, elbowR: 0, shoulderL: -40, elbowL: 20 }), 'Rtoe', { move: 0.12, travel: [60, 0] }),
    kf(P({ twist: 30, spine: 20, hipR: 60, kneeR: 50, ankleR: 10, hipL: -20, kneeL: 40, ankleL: -30, shoulderR: 80, elbowR: 10, shoulderL: -30, elbowL: 20 }), 'Ltoe', { move: 0.14, travel: [70, 0] }),
    kf(P({ twist: 20, spine: 10, hipL: 40, kneeL: 40, ankleL: 10, hipR: 0, kneeR: 30, ankleR: -10, shoulderR: 40, elbowR: 40 }), 'feet', { hold: 0.3, travel: [60, 0] }),
  ],
});
def('fence-lunge-pulse', 'Lunge hold with pulses', {
  view: 'side', implement: SWORD, loop: true, thumb: 0,
  keyframes: [
    kf(lunge({ hipR: 80, kneeR: 84 }), 'feet', { move: 0.4 }),
    kf(lunge({ hipR: 88, kneeR: 96 }), 'feet', { move: 0.4 }),
    kf(lunge({ hipR: 80, kneeR: 84 }), 'feet', { move: 0.4 }),
    kf(enGarde(), 'feet', { move: 0.3, travel: [-50, 0] }),
    kf(lunge(), 'feet', { move: 0.3, travel: [50, 0] }),
  ],
});
def('fence-opponent', 'Opponent (en garde)', {
  view: 'side', implement: SWORD, loop: true, thumb: 0,
  keyframes: [kf(enGarde(), 'feet', { hold: 0.8, move: 0.2 }), kf(P(enGarde(), { shoulderR: 50, elbowR: 40, shoulderAbdR: 24 }), 'feet', { hold: 0.6, move: 0.2 })],
});
def('fence-feint-disengage', 'Feint, disengage and lunge', {
  view: 'side', implement: SWORD, thumb: 3,
  cast: [{ pattern: 'fence-opponent', at: [190, 0], facing: 180 }],
  keyframes: [
    kf(enGarde(), 'feet', { hold: 0.4, move: 0.14 }),
    kf(P(enGarde(), { shoulderR: 70, elbowR: 20, shoulderAbdR: 20 }), 'feet', { hold: 0.2, move: 0.12 }),
    kf(P(enGarde(), { shoulderR: 76, elbowR: 14, shoulderAbdR: -6, wristR: -16 }), 'feet', { move: 0.12 }),
    kf(lunge({ shoulderAbdR: -4 }), 'feet', { hold: 0.4, move: 0.3, travel: [60, 0] }),
    kf(enGarde(), 'feet', { hold: 0.3, travel: [-60, 0] }),
  ],
});
def('fence-attacker', 'Opponent lunging', {
  view: 'side', implement: SWORD, loop: true, thumb: 1,
  keyframes: [kf(enGarde(), 'feet', { hold: 0.5, move: 0.3 }), kf(lunge(), 'feet', { hold: 0.5, move: 0.3, travel: [50, 0] }), kf(enGarde(), 'feet', { move: 0.3, travel: [-50, 0] })],
});
def('fence-parry-riposte', 'Parry and riposte', {
  view: 'side', implement: SWORD, loop: true, thumb: 2,
  cast: [{ pattern: 'fence-attacker', at: [230, 0], facing: 180 }],
  keyframes: [
    kf(enGarde(), 'feet', { hold: 0.6, move: 0.14 }),
    kf(P(enGarde(), { shoulderR: 44, elbowR: 60, shoulderAbdR: 34, wristR: 20 }), 'feet', { hold: 0.2, move: 0.14 }),
    kf(P(enGarde(), { shoulderR: 90, elbowR: 0 }), 'feet', { hold: 0.4, move: 0.3 }),
    kf(enGarde(), 'feet', { move: 0.3 }),
  ],
});
def('fence-bound-lunge', 'Bound into a lunge', {
  view: 'side', thumb: 2,
  keyframes: [
    kf(enGarde({ shoulderR: 20, elbowR: 30 }), 'feet', { hold: 0.3, move: 0.2 }),
    kf(P({ twist: 30, spine: 20, hipR: 60, kneeR: 40, ankleR: 0, hipL: -20, kneeL: 20, ankleL: -30, shoulderR: 60, elbowR: 20, shoulderL: -20, elbowL: 30, lift: 12 }), 'air', { move: 0.22, travel: [60, 0] }),
    kf(lunge({ shoulderR: 40, elbowR: 40 }), 'feet', { hold: 1, travel: [40, 0] }),
  ],
});
/** Deep lunge with a rotation, a lateral lunge, then a 90/90 switch. */
def('fence-hip-flow', 'Fencer’s hip mobility flow', {
  view: 'front', thumb: 1,
  keyframes: [
    kf(P({ spine: 10, hipL: 90, kneeL: 90, ankleL: 20, hipR: -20, kneeR: 30, ankleR: -30, shoulderL: 170, elbowL: 10, twist: 40 }), 'L+Rtoe', { hold: 1, move: 1 }),
    kf(P({ hipL: 84, kneeL: 100, ankleL: 30, hipAbdL: 30, hipR: 6, kneeR: 0, hipAbdR: 44, spine: 34, neck: -20, shoulderL: 84, shoulderR: 84, elbowL: 20, elbowR: 20 }), 'feet', { hold: 1, move: 1.2 }),
    kf(P({ spine: 4, hipL: 80, kneeL: 90, hipRotL: -60, hipAbdL: 30, hipR: 60, kneeR: 90, hipRotR: 60, hipAbdR: 30, turn: 20, shoulderL: 20, shoulderR: 20 }), 'air', { hold: 1, move: 1 }),
    kf(P({ spine: 4, hipL: 80, kneeL: 90, hipRotL: 60, hipAbdL: 30, hipR: 60, kneeR: 90, hipRotR: -60, hipAbdR: 30, turn: -20, shoulderL: 20, shoulderR: 20 }), 'air', { hold: 1 }),
  ],
});

export const COMBAT = lib.patterns;
void ground; void side; void mirror;
