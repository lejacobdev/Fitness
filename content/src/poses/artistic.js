/**
 * Gymnastics, cheer and dance: round-offs, back tucks and handsprings (the
 * body turns right over — `acrobatic`), beam walks and vault punches, jumps
 * with their real shapes (toe touch, herkie, pike), cheer motions, stunts
 * with a flyer, leaps, pirouettes and développés.
 */
import { P, both, flatHands, ground, kf, library, mirror, reachBoth, side } from './kit.js';

const lib = library();
const def = lib.def;

// ── Arm shapes (cheer motions) ────────────────────────────────────────────
const HIGH_V = both({ shoulder: 150, shoulderAbd: 40, elbow: 0 });
const LOW_V = both({ shoulder: 10, shoulderAbd: 40, elbow: 0 });
const T = both({ shoulder: 0, shoulderAbd: 90, elbow: 0 });
const TOUCHDOWN = both({ shoulder: 178, shoulderAbd: 6, elbow: 0 });
const DAGGERS = both({ shoulder: 10, shoulderAbd: 20, elbow: 150 });
const HIPS = both({ shoulder: 0, shoulderAbd: 30, elbow: 110, shoulderRot: 40 });
const stand = (arms = {}) => P(arms);
const dip = (arms = {}) => P(both({ hip: 40, knee: 50, ankle: 22 }), { spine: 16 }, arms);

// ── Jumps with their shapes ───────────────────────────────────────────────
const jump = (shape) => [
  kf(stand(HIGH_V), 'feet', { hold: 0.2, move: 0.2 }),
  kf(dip(both({ shoulder: 30, shoulderAbd: 10, elbow: 90 })), 'feet', { move: 0.14 }),
  kf(P(both({ ankle: -30 }), TOUCHDOWN), 'Ltoe+Rtoe', { move: 0.12 }),
  kf(shape, 'air', { hold: 0.08, move: 0.16 }),
  kf(P(both({ ankle: -20 }), both({ shoulder: 20, elbow: 0 }), { lift: 20 }), 'air', { move: 0.14 }),
  kf(dip(both({ shoulder: 20, elbow: 0 })), 'feet', { hold: 0.4 }),
];
/** Toe touch: straddle up to the hands, arms in a T. */
const toeTouch = P(both({ hip: 100, hipAbd: 70, knee: 0, ankle: -30 }), T, { spine: 10, lift: 48 });
/** Herkie: one leg straddled high (straight), the other bent underneath. */
const herkie = P({ hipL: 100, hipAbdL: 60, kneeL: 0, ankleL: -30, hipR: -20, kneeR: 90, ankleR: -30, shoulderL: 0, shoulderAbdL: 90, shoulderR: 150, shoulderAbdR: 30, spine: 10, lift: 44 });
/** Pike: legs together straight out in front, reaching for the toes. */
const pike = P(both({ hip: 100, knee: 0, ankle: -30, shoulder: 100, elbow: 0 }), { spine: 30, lift: 50 });
def('toe-touch-jump', 'Toe-touch jump', { view: 'front', thumb: 3, keyframes: jump(toeTouch) });
def('cheer-jump-series', 'Toe touch, herkie and pike jumps', {
  view: 'three-quarter', thumb: 3,
  keyframes: [...jump(toeTouch), ...jump(herkie), ...jump(pike)],
});
def('tuck-jumps-rebound', 'Tuck jumps', {
  view: 'side', loop: true, thumb: 1,
  keyframes: [
    kf(dip(both({ shoulder: 20, elbow: 20 })), 'feet', { move: 0.16 }),
    kf(P(both({ hip: 120, knee: 140, ankle: -20, shoulder: 60, elbow: 60 }), { spine: 10, lift: 40 }), 'air', { move: 0.2 }),
    kf(P(both({ ankle: -26, shoulder: 20 }), { lift: 16 }), 'air', { move: 0.16 }),
  ],
});
def('jump-stick-landing', 'Small jumps, stuck landings', {
  view: 'three-quarter', thumb: 2,
  keyframes: [
    kf(stand(), 'feet', { hold: 0.2, move: 0.2 }),
    kf(P(both({ ankle: -20, shoulder: 60 }), { lift: 14 }), 'air', { move: 0.2 }),
    kf(P(both({ hip: 50, knee: 60, ankle: 26, shoulder: 70, elbow: 0 }), { spine: 24 }), 'feet', { hold: 2, move: 0.3 }),
    kf(P({ hipL: 10, kneeL: 20, ankleL: -20, hipR: 40, kneeR: 80, shoulderL: 60, shoulderR: 60 }, { lift: 12 }), 'air', { move: 0.2 }),
    kf(P({ hipL: 40, kneeL: 50, ankleL: 24, hipR: 40, kneeR: 90, shoulderL: 70, shoulderR: 70, spine: 20 }), 'L', { hold: 2 }),
  ],
});

// ── Cheer motions, stunts and balance ─────────────────────────────────────
def('cheer-motions', 'Sharp motions', {
  view: 'front', loop: true, thumb: 0,
  keyframes: [HIGH_V, LOW_V, T, TOUCHDOWN, DAGGERS, HIPS].map((arms) => kf(stand(arms), 'feet', { hold: 0.5, move: 0.1 })),
});
/** Liberty: standing on one leg, the other knee up with its foot at the knee, arms high. */
const liberty = P({ hipR: 90, kneeR: 120, hipRotR: 40, hipAbdR: 30, ankleR: -30 }, HIGH_V);
def('liberty-hold', 'Liberty balance', {
  view: 'front', loop: true, thumb: 0,
  keyframes: [kf(liberty, 'L', { hold: 1.2, move: 0.4 }), kf(P(liberty, { bend: 2 }), 'L', { hold: 1.2, move: 0.4 })],
});
def('liberty-heel-stretch', 'Liberty, then heel stretch', {
  view: 'front', thumb: 1,
  keyframes: [
    kf(stand(), 'feet', { hold: 0.3, move: 0.5 }),
    kf(liberty, 'L', { hold: 1.5, move: 0.8 }),
    kf(P({ hipR: 150, hipAbdR: 20, kneeR: 0, ankleR: -20, shoulderR: 170, elbowR: 10, shoulderL: 150, shoulderAbdL: 40 }), 'L', { hold: 1.5, move: 0.6 }),
    kf(stand(), 'feet', { hold: 0.3 }),
  ],
});
/** A base's quarter squat with the hands level at the chest, holding weights as if under a prep. */
def('base-prep-hold', 'Base hold (quarter squat)', {
  view: 'three-quarter', implement: { kind: 'dumbbells', at: 'hands' }, loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 30, knee: 40, ankle: 18, hipAbd: 16, shoulder: 80, elbow: 110 }), { spine: 8 }), 'feet', { hold: 1, move: 0.6 }),
    kf(P(both({ hip: 32, knee: 42, ankle: 18, hipAbd: 16, shoulder: 80, elbow: 112 }), { spine: 9 }), 'feet', { hold: 1, move: 0.6 }),
  ],
});
def('dumbbell-push-press', 'Dumbbell push press (base press)', {
  view: 'three-quarter', implement: { kind: 'dumbbells', at: 'hands' }, thumb: 2,
  keyframes: [
    kf(P(both({ hipAbd: 10, shoulder: 20, shoulderAbd: 60, elbow: 130 })), 'feet', { hold: 0.3, move: 0.3 }),
    kf(P(both({ hip: 20, knee: 26, ankle: 12, hipAbd: 10, shoulder: 20, shoulderAbd: 60, elbow: 130 }), { spine: 6 }), 'feet', { move: 0.2 }),
    kf(P(both({ hipAbd: 10, shoulder: 170, shoulderAbd: 20, elbow: 0 })), 'feet', { hold: 0.4, move: 0.8 }),
    kf(P(both({ hipAbd: 10, shoulder: 20, shoulderAbd: 60, elbow: 130 })), 'feet', { hold: 0.2 }),
  ],
});
/** Flyer standing in the bases' hands at prep height. */
def('flyer-prep', 'Flyer at prep level', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hipAbd: 8 }), HIGH_V, { lift: 48 }), 'air', { hold: 1.2, move: 0.4 }),
    kf(P(both({ hip: 20, knee: 30, ankle: 14, hipAbd: 8 }), both({ shoulder: 30, elbow: 60 }), { lift: 0 }), 'air', { hold: 0.4, move: 0.3 }),
    kf(P(both({ hipAbd: 8 }), HIGH_V, { lift: 48 }), 'air', { hold: 0.4, move: 0.3 }),
  ],
});
def('stunt-timing', 'Stunt timing on counts', {
  view: 'three-quarter', loop: true, thumb: 0,
  cast: [{ pattern: 'flyer-prep', at: [42, 0, 70], facing: 180 }],
  keyframes: [
    kf(reachBoth(P(both({ hip: 20, knee: 30, ankle: 14, hipAbd: 16 }), { spine: 6 }), (sk) => [sk.pelvis[0] + 40, 118, 9], (sk) => [sk.pelvis[0] + 40, 118, -9]), 'feet', { hold: 1.2, move: 0.4 }),
    kf(reachBoth(P(both({ hip: 60, knee: 80, ankle: 30, hipAbd: 16 }), { spine: 20 }), (sk) => [sk.pelvis[0] + 40, 70, 9], (sk) => [sk.pelvis[0] + 40, 70, -9]), 'feet', { hold: 0.4, move: 0.3 }),
    kf(reachBoth(P(both({ hip: 20, knee: 30, ankle: 14, hipAbd: 16 }), { spine: 6 }), (sk) => [sk.pelvis[0] + 40, 118, 9], (sk) => [sk.pelvis[0] + 40, 118, -9]), 'feet', { hold: 0.4, move: 0.3 }),
  ],
});
const danceStep = (s, arms) => kf(P({ [`hip${s}`]: 30, [`knee${s}`]: 40, [`ankle${s}`]: 10, spine: 6 }, arms), s === 'L' ? 'R' : 'L', { move: 0.2, travel: [0, s === 'L' ? 20 : -20] });
def('cheer-routine-circuit', 'Routine run-through: motions, jumps, dance', {
  view: 'front', thumb: 6,
  keyframes: [
    kf(stand(HIGH_V), 'feet', { hold: 0.3, move: 0.1 }), kf(stand(T), 'feet', { hold: 0.3, move: 0.1 }), kf(stand(DAGGERS), 'feet', { hold: 0.3, move: 0.1 }),
    ...jump(toeTouch),
    danceStep('L', HIGH_V), danceStep('R', LOW_V), danceStep('L', T), danceStep('R', TOUCHDOWN),
    kf(stand(HIPS), 'feet', { hold: 0.4 }),
  ],
});
/** Hollow on the back, roll to an arch on the front, roll back. */
def('hollow-arch-roll', 'Hollow to arch rocks', {
  thumb: 0,
  keyframes: [
    kf(P(both({ hip: 42, knee: 0, ankle: -30, shoulder: 176, shoulderAbd: 6, elbow: 0 }), { spine: -72, neck: 20 }), 'air', { hold: 1.5, move: 0.8 }),
    kf(P(both({ hip: 10, knee: 0, ankle: -30, shoulder: 176, elbow: 0 }), { bend: 88 }), 'air', { move: 0.6 }),
    kf(P(both({ hip: -24, knee: 0, ankle: -40, shoulder: 170, elbow: 0 }), { spine: 110, neck: -30 }), 'air', { hold: 1.5, move: 0.8 }),
  ],
});
/** Lying on the back, kick the jump leg up to the herkie shape, then stand and jump it. */
def('herkie-drill', 'Herkie drill', {
  view: 'three-quarter', thumb: 1,
  keyframes: [
    kf(P(both({ hip: 0, knee: 0, ankle: -20 }), { spine: -90 }), 'air', { hold: 0.2, move: 0.3 }),
    kf(P({ spine: -90, hipL: 100, hipAbdL: 50, kneeL: 0, ankleL: -30, hipR: 0, kneeR: 0 }), 'air', { move: 0.3 }),
    kf(P(both({ hip: 0, knee: 0, ankle: -20 }), { spine: -90 }), 'air', { move: 0.3 }),
    kf(P({ spine: -90, hipL: 100, hipAbdL: 50, kneeL: 0, ankleL: -30, hipR: 0, kneeR: 0 }), 'air', { move: 0.6 }),
    ...jump(herkie).slice(1),
  ],
});

// ── Tumbling (acrobatic: the body turns right over) ───────────────────────
def('round-off-rebound', 'Round-off rebound', {
  view: 'side', acrobatic: true, thumb: 4,
  keyframes: [
    kf(P({ hipL: 30, kneeL: 10, hipR: -10, kneeR: 20 }, TOUCHDOWN), 'feet', { hold: 0.3, move: 0.2 }),
    kf(P({ hipL: 90, kneeL: 90, ankleL: 10, hipR: -10, kneeR: 0, ankleR: -30 }, TOUCHDOWN, { lift: 12 }), 'air', { move: 0.2, travel: [40, 0] }),
    kf(P({ spine: 60, hipL: 70, kneeL: 20, ankleL: 10, hipR: -40, kneeR: 0 }, TOUCHDOWN), 'L', { move: 0.16, travel: [40, 0] }),
    kf(P({ spine: 150, hipL: -20, kneeL: 0, hipR: 30, kneeR: 0, turn: 45 }, TOUCHDOWN), 'Lhand', { move: 0.14, travel: [40, 0] }),
    kf(flatHands(P(both({ hip: 0, knee: 0, ankle: -30 }), TOUCHDOWN, { spine: 180, turn: 90 })), 'hands', { move: 0.14 }),
    kf(P(both({ hip: 40, knee: 20, ankle: -10 }), TOUCHDOWN, { spine: 310, turn: 180, lift: 80 }), 'air', { move: 0.14, travel: [-30, 0] }),
    kf(P(both({ hip: 20, knee: 30, ankle: 20 }), TOUCHDOWN, { spine: 380, turn: 180 }), 'feet', { move: 0.14, travel: [-20, 0] }),
    kf(P(both({ hip: 0, knee: 0, ankle: -30 }), TOUCHDOWN, { spine: 360, turn: 180, lift: 36 }), 'air', { move: 0.2 }),
    kf(P(both({ hip: 40, knee: 50, ankle: 22 }), both({ shoulder: 150, elbow: 0 }), { spine: 376, turn: 180 }), 'feet', { hold: 0.5 }),
  ],
});
def('back-tuck', 'Standing back tuck', {
  view: 'side', acrobatic: true, thumb: 3, fixture: { kind: 'mat' },
  keyframes: [
    kf(stand(TOUCHDOWN), 'feet', { hold: 0.3, move: 0.2 }),
    kf(dip(both({ shoulder: -40, elbow: 0 })), 'feet', { move: 0.14 }),
    kf(P(both({ ankle: -30 }), TOUCHDOWN, { spine: -10 }), 'Ltoe+Rtoe', { move: 0.12 }),
    kf(P(both({ hip: 120, knee: 130, ankle: -20, shoulder: 60, elbow: 60 }), { spine: -140, lift: 80 }), 'air', { move: 0.16, travel: [-10, 0] }),
    kf(P(both({ hip: 110, knee: 120, ankle: -20, shoulder: 60, elbow: 60 }), { spine: -250, lift: 70 }), 'air', { move: 0.16, travel: [-6, 0] }),
    kf(P(both({ hip: 30, knee: 30, ankle: 10, shoulder: 150, elbow: 0 }), { spine: -330, lift: 20 }), 'air', { move: 0.14 }),
    kf(P(both({ hip: 50, knee: 60, ankle: 26, shoulder: 150, elbow: 0 }), { spine: -340 }), 'feet', { hold: 0.5 }),
  ],
});
def('back-handspring-barrel', 'Back handspring over a barrel', {
  view: 'side', acrobatic: true, thumb: 3, fixture: { kind: 'ball', dx: -50, r: 34 },
  keyframes: [
    kf(stand(TOUCHDOWN), 'feet', { hold: 0.3, move: 0.3 }),
    kf(P(both({ hip: 70, knee: 90, ankle: 30, shoulder: -40, elbow: 0 }), { spine: 10 }), 'feet', { move: 0.2 }),
    kf(P(both({ hip: -10, knee: 20, ankle: -20 }), TOUCHDOWN, { spine: -60 }), 'Ltoe+Rtoe', { move: 0.2, travel: [-20, 0] }),
    kf(flatHands(P(both({ hip: -20, knee: 10, ankle: -30 }), TOUCHDOWN, { spine: -170 })), 'hands', { move: 0.2, travel: [-60, 0] }),
    kf(flatHands(P(both({ hip: 20, knee: 10, ankle: -30 }), TOUCHDOWN, { spine: -250 })), 'hands', { move: 0.16 }),
    kf(P(both({ hip: 30, knee: 30, ankle: 20 }), TOUCHDOWN, { spine: -350 }), 'feet', { move: 0.2, travel: [-40, 0] }),
    kf(P(both({ hip: 30, knee: 40, ankle: 20, shoulder: 150, elbow: 0 }), { spine: -350 }), 'feet', { hold: 0.4 }),
  ],
});

// ── Gymnastics apparatus and holds ─────────────────────────────────────────
def('handstand-shrugs', 'Handstand shoulder shrugs against the wall', {
  view: 'side', acrobatic: true, loop: true, thumb: 0, fixture: { kind: 'wall', at: -34 },
  keyframes: [
    kf(flatHands(P(both({ hip: 0, knee: 0, ankle: -30, shoulder: 176, shoulderAbd: 4, elbow: 0 }), { spine: 176, neck: -10 })), 'hands', { hold: 0.4, move: 0.6 }),
    kf(flatHands(P(both({ hip: 0, knee: 0, ankle: -30, shoulder: 186, shoulderAbd: 4, elbow: 0 }), { spine: 178, neck: -10 })), 'hands', { hold: 0.4, move: 0.6 }),
  ],
});
/** Hanging from the bar: hollow (feet forward) and arch (feet back) build the kip swing. */
def('bar-hollow-arch-swing', 'Kip swing (hollow and arch)', {
  view: 'side', fixture: { kind: 'bar' }, loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ shoulder: 176, shoulderAbd: 6, elbow: 0, hip: 40, knee: 0, ankle: -30 }), { spine: -20 }), 'grip', { move: 0.5, surface: 50 }),
    kf(P(both({ shoulder: 176, shoulderAbd: 6, elbow: 0, hip: -20, knee: 10, ankle: -30 }), { spine: 20 }), 'grip', { move: 0.5 }),
  ],
});
/** Low beam: relevé walks, a half turn, an arabesque. */
const releve = (s) => P({ [`hip${s}`]: 20, [`knee${s}`]: 4, [`ankle${s}`]: -40, [`ankle${s === 'L' ? 'R' : 'L'}`]: -40, shoulderAbdL: 80, shoulderAbdR: 80 });
def('beam-walk', 'Beam walks and arabesque', {
  view: 'three-quarter', thumb: 5, fixture: { kind: 'bench', from: -60, to: 160, top: 20 },
  keyframes: [
    kf(releve('L'), 'Ltoe+Rtoe', { move: 0.5, surface: 20 }),
    kf(releve('R'), 'Ltoe+Rtoe', { move: 0.5, surface: 20, travel: [30, 0] }),
    kf(releve('L'), 'Ltoe+Rtoe', { move: 0.5, surface: 20, travel: [30, 0] }),
    kf(P(releve('R'), { turn: 180 }), 'Ltoe+Rtoe', { move: 0.6, surface: 20 }),
    kf(P(releve('L'), { turn: 180 }), 'Ltoe+Rtoe', { move: 0.5, surface: 20, travel: [-30, 0] }),
    kf(P({ turn: 180, spine: 30, hipR: -60, kneeR: 0, ankleR: -30, ankleL: 0, shoulderL: 110, shoulderR: 60, shoulderAbdR: 40 }), 'L', { hold: 1.5, surface: 20 }),
  ],
});
/** Active flexibility: front, side and back leg lifts held at the top, no swing. */
def('leg-lift-holds', 'Active flexibility kicks', {
  view: 'three-quarter', thumb: 1,
  keyframes: [
    kf(stand(both({ shoulderAbd: 70 })), 'feet', { hold: 0.2, move: 0.8 }),
    kf(P({ hipR: 110, kneeR: 0, ankleR: -30, shoulderAbdL: 70, shoulderAbdR: 70 }), 'L', { hold: 1, move: 0.8 }),
    kf(stand(both({ shoulderAbd: 70 })), 'feet', { move: 0.8 }),
    kf(P({ hipAbdR: 80, kneeR: 0, ankleR: -30, shoulderAbdL: 70, shoulderAbdR: 70, bend: -10 }), 'L', { hold: 1, move: 0.8 }),
    kf(stand(both({ shoulderAbd: 70 })), 'feet', { move: 0.8 }),
    kf(P({ hipR: -50, kneeR: 0, ankleR: -30, spine: 20, shoulderAbdL: 70, shoulderAbdR: 70 }), 'L', { hold: 1, move: 0.8 }),
    kf(stand(both({ shoulderAbd: 70 })), 'feet', { hold: 0.2 }),
  ],
});
/** Vault: run, hurdle onto the board, punch up and forward, stick the landing. */
def('vault-board-punch', 'Vault board punch', {
  view: 'side', thumb: 4, fixture: { kind: 'box', from: 90, to: 140, top: 10 },
  keyframes: [
    kf(P({ hipL: 36, kneeL: 18, ankleL: 2, hipR: -12, kneeR: 96, ankleR: -24, shoulderL: -40, shoulderR: 60, spine: 12 }), 'air', { move: 0.12 }),
    kf(P({ hipR: 36, kneeR: 18, ankleR: 2, hipL: -12, kneeL: 96, ankleL: -24, shoulderR: -40, shoulderL: 60, spine: 12 }), 'air', { move: 0.12, travel: [50, 0] }),
    kf(P({ hipL: 60, kneeL: 60, hipR: 0, kneeR: 10, ankleR: -30, shoulderL: -30, shoulderR: -30, spine: 8, lift: 14 }), 'air', { move: 0.16, travel: [40, 0] }),
    kf(P(both({ hip: 30, knee: 30, ankle: 20, shoulder: -50, elbow: 0 }), { spine: 10 }), 'feet', { move: 0.1, surface: 10, travel: [20, 0] }),
    kf(P(both({ ankle: -30 }), TOUCHDOWN, { spine: -4, lift: 50 }), 'air', { move: 0.24, travel: [60, 0] }),
    kf(P(both({ hip: 50, knee: 60, ankle: 26, shoulder: 150, shoulderAbd: 30, elbow: 0 }), { spine: 20 }), 'feet', { hold: 0.6, travel: [60, 0] }),
  ],
});
/** Straddle press prep: sitting straddled, lean forward and lift the legs with the hip flexors. */
const straddleSit = (lift) => P(both({ hip: 100 + lift, hipAbd: 40, knee: 0, ankle: -30, shoulder: 70, elbow: 0 }), { spine: -10 + lift / 2 });
def('straddle-lift', 'Straddle press prep', {
  view: 'three-quarter', thumb: 1,
  keyframes: [kf(straddleSit(0), 'air', { hold: 0.3, move: 0.5 }), kf(straddleSit(24), 'air', { hold: 1, move: 0.5 }), kf(straddleSit(0), 'air', { hold: 0.2 })],
});
/** Splits: right, left (supported on blocks), then middle. */
def('splits-hold', 'Splits holds', {
  view: 'three-quarter', thumb: 0,
  keyframes: [
    kf(P({ hipL: 90, kneeL: 0, ankleL: -20, hipR: -90, kneeR: 0, ankleR: -40, shoulderL: 30, shoulderR: 30, shoulderAbdL: 30, shoulderAbdR: 30 }), 'air', { hold: 2, move: 1 }),
    kf(P({ hipR: 90, kneeR: 0, ankleR: -20, hipL: -90, kneeL: 0, ankleL: -40, shoulderL: 30, shoulderR: 30, shoulderAbdL: 30, shoulderAbdR: 30 }), 'air', { hold: 2, move: 1 }),
    kf(P(both({ hip: 90, hipAbd: 88, knee: 0, ankle: -20, shoulder: 60, elbow: 0 }), { spine: 20 }), 'air', { hold: 2 }),
  ],
});

// ── Dance ──────────────────────────────────────────────────────────────────
def('grand-jete', 'Grand jeté', {
  view: 'side', thumb: 3,
  keyframes: [
    kf(P({ hipL: 36, kneeL: 18, ankleL: 2, hipR: -12, kneeR: 90, ankleR: -24, shoulderL: 60, shoulderR: 60, shoulderAbdL: 60, shoulderAbdR: 60 }), 'air', { move: 0.14 }),
    kf(P({ hipR: 36, kneeR: 18, ankleR: 2, hipL: -12, kneeL: 90, ankleL: -24, shoulderL: 60, shoulderR: 60, shoulderAbdL: 60, shoulderAbdR: 60 }), 'air', { move: 0.14, travel: [60, 0] }),
    kf(P({ hipL: 20, kneeL: 30, ankleL: 20, hipR: -20, kneeR: 10, ankleR: -30, shoulderL: 100, shoulderR: 40, shoulderAbdR: 60 }), 'L', { move: 0.14, travel: [40, 0] }),
    kf(P({ hipR: 90, kneeR: 0, ankleR: -40, hipL: -80, kneeL: 0, ankleL: -40, shoulderL: 150, shoulderR: 40, shoulderAbdR: 80, lift: 50 }), 'air', { move: 0.22, travel: [90, 0] }),
    kf(P({ hipR: 30, kneeR: 50, ankleR: 24, hipL: -30, kneeL: 10, ankleL: -30, shoulderL: 100, shoulderR: 40, shoulderAbdR: 70 }), 'R', { hold: 0.4, travel: [70, 0] }),
  ],
});
/** Relevé passé, then a single pirouette spotting the head, finishing in fourth. */
const passe = (turn, neckTurn = 0) => P({ turn, neckTurn, hipR: 80, kneeR: 130, hipRotR: 50, hipAbdR: 40, ankleR: -40, ankleL: -40, ...both({ shoulder: 60, shoulderAbd: 30, elbow: 40 }) });
def('pirouette', 'Pirouette with spotting', {
  view: 'front', thumb: 2,
  keyframes: [
    kf(P({ hipL: 20, kneeL: 30, ankleL: 14, hipR: -20, kneeR: 30, ankleR: 10, ...both({ shoulder: 40, shoulderAbd: 50, elbow: 20 }) }), 'feet', { hold: 0.3, move: 0.3 }),
    kf(passe(0), 'Ltoe', { hold: 0.6, move: 0.2 }),
    kf(passe(150, -60), 'Ltoe', { move: 0.14 }),
    kf(passe(250, 60), 'Ltoe', { move: 0.12 }),
    kf(passe(360), 'Ltoe', { hold: 0.2, move: 0.2 }),
    kf(P({ turn: 360, hipL: 20, kneeL: 30, ankleL: 14, hipR: -20, kneeR: 30, ankleR: 10, ...both({ shoulder: 40, shoulderAbd: 50, elbow: 20 }) }), 'feet', { hold: 0.4 }),
  ],
});
/** Développé: through passé, unfold the leg front, side, back and hold each. */
def('developpe', 'Développé extensions', {
  view: 'three-quarter', thumb: 2,
  keyframes: [
    kf(stand(both({ shoulderAbd: 70 })), 'feet', { hold: 0.2, move: 0.6 }),
    kf(P({ hipR: 80, kneeR: 120, hipRotR: 40, ankleR: -30, shoulderAbdL: 70, shoulderAbdR: 70 }), 'L', { move: 0.6 }),
    kf(P({ hipR: 100, kneeR: 0, ankleR: -40, shoulderAbdL: 70, shoulderAbdR: 70 }), 'L', { hold: 1.5, move: 0.6 }),
    kf(P({ hipR: 80, kneeR: 120, hipRotR: 40, ankleR: -30, shoulderAbdL: 70, shoulderAbdR: 70 }), 'L', { move: 0.6 }),
    kf(P({ hipR: 30, hipAbdR: 80, kneeR: 0, ankleR: -40, shoulderAbdL: 70, shoulderAbdR: 70 }), 'L', { hold: 1.5, move: 0.6 }),
    kf(P({ hipR: 80, kneeR: 120, hipRotR: 40, ankleR: -30, shoulderAbdL: 70, shoulderAbdR: 70 }), 'L', { move: 0.6 }),
    kf(P({ hipR: -60, kneeR: 0, ankleR: -40, spine: 20, shoulderL: 110, shoulderAbdR: 70 }), 'L', { hold: 1.5, move: 0.6 }),
    kf(stand(both({ shoulderAbd: 70 })), 'feet', { hold: 0.2 }),
  ],
});
/** Sautés in first: jump, land toe-ball-heel into a deep quiet plié. */
const first = both({ hipRot: 40, hipAbd: 10 });
def('saute-plie', 'Sautés landing in plié', {
  view: 'front', loop: true, thumb: 1,
  keyframes: [
    kf(P(first, both({ hip: 40, knee: 60, ankle: 26, shoulder: 30, shoulderAbd: 40, elbow: 30 })), 'feet', { hold: 0.2, move: 0.18 }),
    kf(P(first, both({ ankle: -40, shoulder: 30, shoulderAbd: 40, elbow: 30 }), { lift: 16 }), 'air', { move: 0.18 }),
    kf(P(first, both({ ankle: -30, shoulder: 30, shoulderAbd: 40, elbow: 30 })), 'Ltoe+Rtoe', { move: 0.14 }),
  ],
});
/** Fouetté prep: plié, relevé, the working leg front, whipped to the side, into passé. */
def('fouette-prep', 'Fouetté prep', {
  view: 'front', thumb: 3,
  keyframes: [
    kf(P({ hipL: 30, kneeL: 40, ankleL: 20, hipR: 30, kneeR: 40, ankleR: 20, ...both({ shoulder: 40, shoulderAbd: 60, elbow: 20 }) }), 'feet', { hold: 0.2, move: 0.3 }),
    kf(P({ hipR: 90, kneeR: 0, ankleR: -40, ankleL: -40, ...both({ shoulder: 40, shoulderAbd: 60, elbow: 20 }) }), 'Ltoe', { move: 0.3 }),
    kf(P({ hipR: 20, hipAbdR: 80, kneeR: 0, ankleR: -40, ankleL: -40, ...both({ shoulder: 10, shoulderAbd: 85, elbow: 0 }) }), 'Ltoe', { move: 0.2 }),
    kf(passe(0), 'Ltoe', { hold: 0.4, move: 0.3 }),
    kf(passe(360), 'Ltoe', { move: 0.5 }),
    kf(P({ turn: 360, hipL: 30, kneeL: 40, ankleL: 20, hipR: 30, kneeR: 40, ankleR: 20, ...both({ shoulder: 40, shoulderAbd: 60, elbow: 20 }) }), 'feet', { hold: 0.3 }),
  ],
});
/** Across the floor: chassés, a leap, a turn — back and forth. */
def('across-the-floor', 'Across the floor: chassé, leap, turn', {
  view: 'side', thumb: 3,
  keyframes: [
    kf(P({ hipL: 30, kneeL: 20, hipR: -10, ankleR: -30, shoulderAbdL: 70, shoulderAbdR: 70 }), 'L+Rtoe', { move: 0.2 }),
    kf(P({ hipL: 20, kneeL: 10, hipR: 10, kneeR: 10, ankleL: -30, ankleR: -30, shoulderAbdL: 70, shoulderAbdR: 70, lift: 10 }), 'air', { move: 0.2, travel: [40, 0] }),
    kf(P({ hipL: 30, kneeL: 20, hipR: -10, ankleR: -30, shoulderAbdL: 70, shoulderAbdR: 70 }), 'L+Rtoe', { move: 0.2, travel: [30, 0] }),
    kf(P({ hipL: 90, kneeL: 0, ankleL: -40, hipR: -80, kneeR: 0, ankleR: -40, shoulderL: 150, shoulderR: 40, shoulderAbdR: 80, lift: 44 }), 'air', { move: 0.24, travel: [80, 0] }),
    kf(P({ hipL: 30, kneeL: 50, ankleL: 24, hipR: -30, kneeR: 10, ankleR: -30, shoulderAbdL: 70, shoulderAbdR: 70 }), 'L', { move: 0.2, travel: [60, 0] }),
    kf(passe(0), 'Ltoe', { move: 0.14, travel: [10, 0] }),
    kf(passe(360), 'Ltoe', { move: 0.4 }),
    kf(P({ turn: 360, shoulderAbdL: 70, shoulderAbdR: 70 }), 'feet', { hold: 0.3 }),
  ],
});

// ── Step team ──────────────────────────────────────────────────────────────
const stompUp = (s) => P({ [`hip${s}`]: 60, [`knee${s}`]: 80, spine: 6, ...both({ shoulder: 20, shoulderAbd: 20, elbow: 90 }) });
const clap = P(both({ shoulder: 80, shoulderAbd: -10, elbow: 30 }));
const thighSlap = P(both({ shoulder: -10, shoulderAbd: 14, elbow: 20 }), { spine: 6 });
const chestSlap = P(both({ shoulder: 50, shoulderAbd: -20, elbow: 130 }));
def('step-stomp-clap', 'Stomp-stomp-clap', {
  view: 'three-quarter', loop: true, thumb: 0,
  keyframes: [
    kf(stompUp('L'), 'R', { move: 0.14 }), kf(P(), 'feet', { hold: 0.1, move: 0.14 }),
    kf(stompUp('R'), 'L', { move: 0.14 }), kf(P(), 'feet', { hold: 0.1, move: 0.14 }),
    kf(clap, 'feet', { hold: 0.14, move: 0.14 }), kf(thighSlap, 'feet', { hold: 0.14, move: 0.14 }),
    kf(chestSlap, 'feet', { hold: 0.14, move: 0.14 }), kf(clap, 'feet', { hold: 0.14, move: 0.14 }),
  ],
});
def('body-percussion', 'Body percussion with stomps', {
  view: 'front', loop: true, thumb: 0,
  keyframes: [
    kf(chestSlap, 'feet', { hold: 0.1, move: 0.12 }), kf(thighSlap, 'feet', { hold: 0.1, move: 0.12 }),
    kf(clap, 'feet', { hold: 0.1, move: 0.12 }), kf(stompUp('L'), 'R', { move: 0.12 }), kf(P(), 'feet', { hold: 0.1, move: 0.12 }),
  ],
});
def('stomp-jumps', 'Power stomp jumps', {
  view: 'three-quarter', loop: true, thumb: 1,
  keyframes: [
    kf(P(both({ hip: 40, knee: 50, ankle: 22, shoulder: -30 }), { spine: 16 }), 'feet', { move: 0.16 }),
    kf(P(both({ ankle: -30, shoulder: 150, shoulderAbd: 30 }), { lift: 28 }), 'air', { move: 0.18 }),
    kf(P({ hipL: 60, kneeL: 70, hipR: 20, kneeR: 30, ankleR: -20, ...both({ shoulder: 20, elbow: 90 }) }, { lift: 10 }), 'air', { move: 0.1 }),
    kf(P(both({ hip: 30, knee: 40, ankle: 18, shoulder: 0, shoulderAbd: 20, elbow: 90 }), { spine: 10 }), 'feet', { hold: 0.15, move: 0.12 }),
  ],
});
def('step-routine', 'Step routine run-through', {
  view: 'three-quarter', thumb: 4,
  keyframes: [
    kf(stompUp('L'), 'R', { move: 0.14 }), kf(P(), 'feet', { move: 0.14 }), kf(stompUp('R'), 'L', { move: 0.14 }), kf(clap, 'feet', { move: 0.14 }),
    kf(P(clap, { turn: 90 }), 'feet', { move: 0.3, travel: [20, 20] }), kf(P(thighSlap, { turn: 90 }), 'feet', { move: 0.14 }),
    kf(P(stompUp('L'), { turn: 180 }), 'R', { move: 0.2, travel: [0, 20] }), kf(P(chestSlap, { turn: 180 }), 'feet', { move: 0.14 }),
    kf(P(both({ ankle: -30, shoulder: 150, shoulderAbd: 30 }), { turn: 360, lift: 24 }), 'air', { move: 0.4 }),
    kf(P(both({ hip: 30, knee: 40, ankle: 18, shoulder: 0, shoulderAbd: 20, elbow: 90 }), { turn: 360, spine: 10 }), 'feet', { hold: 0.4, travel: [-20, -40] }),
  ],
});
/** Formation change: march to a new spot in eight counts, stomp on eight. */
def('formation-move', 'Formation transition', {
  view: 'three-quarter', thumb: 8,
  keyframes: [
    ...[0, 1, 2, 3, 4, 5, 6].map((i) => kf(stompUp(i % 2 ? 'R' : 'L'), i % 2 ? 'L' : 'R', { move: 0.2, travel: [20, 14] })),
    kf(P(stompUp('R'), { turn: 30 }), 'L', { move: 0.14, travel: [10, 10] }),
    kf(P(both({ hip: 20, knee: 30, ankle: 12, shoulder: 0, shoulderAbd: 20, elbow: 90 }), { turn: 30 }), 'feet', { hold: 0.6 }),
  ],
});
/** Hamstring (heel forward, hinge), half-kneeling hip flexor, lateral lunge for the adductors. */
def('stretch-series', 'Hamstring, hip-flexor and adductor stretches', {
  view: 'three-quarter', thumb: 1,
  keyframes: [
    kf(P({ hipL: 20, kneeL: 0, ankleL: 30, hipR: -6, kneeR: 10 }), 'Lheel+R', { hold: 0.2, move: 0.8 }),
    kf(P({ spine: 50, neck: -20, hipL: 60, kneeL: 0, ankleL: 30, hipR: 40, kneeR: 30, ankleR: 10, ...both({ shoulder: 60, elbow: 0 }) }), 'Lheel+R', { hold: 2, move: 1 }),
    kf(P({ hipL: 80, kneeL: 90, ankleL: 20, hipR: -30, kneeR: 90, ankleR: -40, shoulderL: 170, elbowL: 10, spine: -6 }), 'L+Rknee', { hold: 2, move: 1 }),
    kf(P({ hipL: 84, kneeL: 100, ankleL: 30, hipAbdL: 30, hipR: 6, kneeR: 0, hipAbdR: 44, spine: 34, neck: -20, shoulderL: 84, shoulderR: 84, elbowL: 20, elbowR: 20 }), 'feet', { hold: 2, move: 1 }),
    kf(P(), 'feet', { hold: 0.2 }),
  ],
});

// ── Color guard ────────────────────────────────────────────────────────────
const FLAG = { kind: 'flag' };
const FLAG_TOSS = { r: 4, color: 'red', shape: 'flag' };
/** Holding the pole: bottom hand at `lo`, top hand `gap` along it toward `hi`. */
const pole = (p, lo, hi, gap = 30) => reachBoth(p, lo, (sk) => { const a = lo(sk), b = hi(sk); const d = Math.hypot(b[0] - a[0], b[1] - a[1], b[2] - a[2]) || 1; return [a[0] + (b[0] - a[0]) / d * gap, a[1] + (b[1] - a[1]) / d * gap, a[2] + (b[2] - a[2]) / d * gap]; }, { rot: [-40, -20, 0, 20, 40] });
const at = (f, h, l) => (sk) => [sk.pelvis[0] + f, sk.pelvis[1] + h, sk.pelvis[2] + l];
def('flag-spin', 'Flag spins', {
  view: 'three-quarter', implement: FLAG, loop: true, thumb: 0,
  keyframes: [
    kf(pole(P(), at(20, 20, 10), at(20, 120, -20)), 'feet', { move: 0.22 }),
    kf(pole(P(), at(20, 30, -10), at(20, 30, -120)), 'feet', { move: 0.22 }),
    kf(pole(P(), at(20, 50, -10), at(30, 0, 30)), 'feet', { move: 0.22 }),
    kf(pole(P(), at(20, 30, 10), at(20, 30, 120)), 'feet', { move: 0.22 }),
  ],
});
def('flag-toss', 'Flag toss and catch', {
  view: 'three-quarter', ball: FLAG_TOSS, thumb: 2,
  keyframes: [
    kf(P(both({ hip: 20, knee: 26, ankle: 12, shoulder: 60, elbow: 40 })), 'feet', { hold: 0.3, move: 0.3, ball: { at: [20, 40, 0] } }),
    kf(P(both({ shoulder: 160, elbow: 10 })), 'feet', { move: 0.2, ball: { at: [20, 120, 0] } }),
    kf(P(both({ shoulder: 110, elbow: 10 })), 'feet', { hold: 0.5, move: 0.7, ball: { at: [20, 230, 0] }, ballArc: 0 }),
    kf(P(both({ shoulder: 150, elbow: 10 })), 'feet', { move: 0.3, ball: { at: [20, 120, 0] } }),
    kf(P(both({ hip: 20, knee: 26, ankle: 12, shoulder: 60, elbow: 40 })), 'feet', { hold: 0.4, ball: { at: [20, 40, 0] } }),
  ],
});
def('flag-holds', 'Flag holds: out, overhead, present', {
  view: 'three-quarter', implement: FLAG, thumb: 0,
  keyframes: [
    kf(pole(P(), at(30, 30, 0), at(160, 40, 0)), 'feet', { hold: 1.5, move: 0.6 }),
    kf(pole(P(), at(10, 70, 20), at(10, 90, -120)), 'feet', { hold: 1.5, move: 0.6 }),
    kf(pole(P(), at(20, 20, 0), at(110, 120, 0)), 'feet', { hold: 1.5, move: 0.6 }),
  ],
});
def('flag-balance', 'Arabesque and passé with the flag', {
  view: 'three-quarter', implement: FLAG, thumb: 1,
  keyframes: [
    kf(pole(P(), at(20, 20, 0), at(60, 140, 0)), 'feet', { hold: 0.3, move: 0.6 }),
    kf(pole(P({ spine: 30, hipR: -60, kneeR: 0, ankleR: -30 }), at(30, 30, 0), at(80, 140, 0)), 'L', { hold: 2, move: 0.6 }),
    kf(pole(P({ hipR: 80, kneeR: 130, hipRotR: 50, hipAbdR: 40, ankleR: -40, ankleL: -40 }), at(20, 30, 0), at(40, 150, 0)), 'Ltoe', { hold: 2, move: 0.6 }),
    kf(pole(P(), at(20, 20, 0), at(60, 140, 0)), 'feet', { hold: 0.3 }),
  ],
});
def('flag-show', 'Guard show run', {
  view: 'three-quarter', implement: FLAG, thumb: 2,
  keyframes: [
    kf(pole(P(), at(20, 20, 10), at(20, 120, -20)), 'feet', { move: 0.22 }),
    kf(pole(P(), at(20, 30, -10), at(20, 30, -120)), 'feet', { move: 0.22 }),
    kf(pole(P({ hipL: 36, kneeL: 18, hipR: -12, kneeR: 60, ankleR: -24 }), at(30, 30, 0), at(150, 50, 0)), 'air', { move: 0.2, travel: [50, 0] }),
    kf(pole(P({ hipR: 36, kneeR: 18, hipL: -12, kneeL: 60, ankleL: -24 }), at(30, 30, 0), at(150, 50, 0)), 'air', { move: 0.2, travel: [50, 0] }),
    kf(pole(P({ spine: 30, hipR: -60, kneeR: 0, ankleR: -30 }), at(30, 30, 0), at(80, 140, 0)), 'L', { hold: 1, move: 0.4, travel: [20, 0] }),
  ],
});

// ── Marching band ─────────────────────────────────────────────────────────
const HORN = { kind: 'horn' };
/** Horn up at the mouth, both hands on it, elbows out. */
const playing = (p) => reachBoth(p, (sk) => { const hf = [sk.headFrame[0][0], sk.headFrame[0][1], sk.headFrame[0][2]]; return [sk.head[0] + hf[0] * 22, sk.head[1] - 6, sk.head[2] + 4]; },
  (sk) => { const hf = [sk.headFrame[0][0], sk.headFrame[0][1], sk.headFrame[0][2]]; return [sk.head[0] + hf[0] * 30, sk.head[1] - 5, sk.head[2] - 4]; });
/** Roll step: heel strikes first and rolls to the toe; the upper body never moves. */
const roll = (s, phase) => {
  const o = s === 'L' ? 'R' : 'L';
  return phase === 0
    ? { [`hip${s}`]: 24, [`knee${s}`]: 0, [`ankle${s}`]: 24, [`hip${o}`]: -10, [`knee${o}`]: 10, [`ankle${o}`]: -10 }
    : { [`hip${s}`]: 4, [`knee${s}`]: 4, [`ankle${s}`]: 0, [`hip${o}`]: 20, [`knee${o}`]: 40, [`ankle${o}`]: 10 };
};
const marchFrames = (arms) => ['L', 'R'].flatMap((s) => [0, 1].map((ph) => kf(arms(P(roll(s, ph))), 'air', { move: 0.22 })));
def('march-roll-step', 'Eight-to-five roll step', {
  view: 'side', loop: true, thumb: 0, path: { kind: 'line', length: 300, speed: 70 },
  keyframes: marchFrames((p) => P(p, both({ shoulder: 0, elbow: 90, shoulderAbd: 10 }))),
});
def('march-backward', 'Backward march on the toes', {
  view: 'side', loop: true, thumb: 0, path: { kind: 'line', length: 260, speed: 60, dir: 'back' },
  keyframes: ['L', 'R'].flatMap((s) => {
    const o = s === 'L' ? 'R' : 'L';
    return [
      kf(P({ [`hip${s}`]: -14, [`knee${s}`]: 6, [`ankle${s}`]: -30, [`hip${o}`]: 6, [`knee${o}`]: 10, [`ankle${o}`]: -30, ...both({ shoulder: 0, elbow: 90 }) }), 'air', { move: 0.24 }),
      kf(P({ [`hip${s}`]: 0, [`knee${s}`]: 6, [`ankle${s}`]: -30, [`hip${o}`]: 0, [`knee${o}`]: 20, [`ankle${o}`]: -30, ...both({ shoulder: 0, elbow: 90 }) }), 'air', { move: 0.24 }),
    ];
  }),
});
def('horn-march', 'Playing while marching', {
  view: 'three-quarter', implement: HORN, loop: true, thumb: 0, path: { kind: 'line', length: 300, speed: 70 },
  keyframes: marchFrames(playing),
});
def('horn-posture', 'Playing posture, then marking time', {
  view: 'three-quarter', implement: HORN, thumb: 1,
  keyframes: [
    kf(playing(P()), 'feet', { hold: 2, move: 0.3 }),
    ...[0, 1, 2, 3].map((i) => kf(playing(P(i % 2 ? { hipR: 60, kneeR: 80 } : { hipL: 60, kneeL: 80 })), i % 2 ? 'L' : 'R', { move: 0.25 })),
    kf(playing(P()), 'feet', { hold: 0.4 }),
  ],
});
/** Walk holding a weight at chest height in front, then on one side. */
def('front-carry', 'Front-held carry', {
  view: 'three-quarter', implement: { kind: 'goblet', at: 'chest' }, loop: true, thumb: 0, path: { kind: 'line', length: 300, speed: 90 },
  keyframes: marchFrames((p) => reachBoth(p, at(20, 44, 5), at(20, 44, -5))),
});

export const ARTISTIC = lib.patterns;
void ground; void mirror; void side;
