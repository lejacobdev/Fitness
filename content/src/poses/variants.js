/**
 * Variants that need to look different from their base movement: the same
 * lift with the equipment the variant actually uses (dumbbells, a band under
 * the feet, a trap bar, bodyweight), and single-side versions that really
 * work one side. Each is a copy of an authored pattern with its equipment
 * or one side changed — the movement itself stays exactly as reviewed.
 */
import { STRENGTH, goblet } from './strength.js';
import { ENDURANCE } from './endurance.js';
import { SOCCER } from './soccer.js';
import { FIELD_SPORTS } from './fieldSports.js';
import { HOCKEY } from './hockey.js';
import { BASKETBALL } from './basketball.js';
import { STICK_SPORTS } from './stickSports.js';
import { VOLLEYBALL } from './volleyball.js';
import { P, kf, library } from './kit.js';

const lib = library();
const def = lib.def;
const BY_LOCAL = (slug) => lib.get(slug);
const BY = new Map([...STRENGTH, ...ENDURANCE, ...SOCCER, ...FIELD_SPORTS, ...HOCKEY, ...BASKETBALL, ...STICK_SPORTS, ...VOLLEYBALL].map((p) => [p.slug, p]));
const base = (slug) => { const { slug: _s, name: _n, ...spec } = BY.get(slug); return spec; };
/** A pattern with every keyframe's pose (and optionally contact) changed. */
const edit = (spec, pose, contact) => ({
  ...spec,
  keyframes: spec.keyframes.map((k, i) => ({ ...k, pose: P(k.pose, pose(k.pose, i)), contact: contact ? contact(k.contact, i) : k.contact })),
});
const BAND_FEET = { kind: 'band', at: 'hands', underFeet: true };
const BAND_FLOOR = { kind: 'band', at: 'hands', underHands: true };
const TRAP = { kind: 'barbell', at: 'hands', trap: true };

// ── The same lift, other equipment ──────────────────────────────────────────
// Trap bar: hands at the sides of the legs on the handles.
def('deadlift-trapbar', 'Trap-bar deadlift', edit({ ...base('deadlift'), implement: TRAP }, () => ({ shoulderAbdL: 12, shoulderAbdR: 12 })));
def('deadlift-dumbbells', 'Dumbbell deadlift', { ...base('deadlift'), implement: { kind: 'dumbbells', at: 'hands' } });
def('deadlift-band', 'Band deadlift', { ...base('deadlift'), implement: BAND_FEET });
def('goblet-squat-band', 'Band-resisted squat', { ...base('goblet-squat'), implement: BAND_FEET });
def('front-squat-dumbbells', 'Dumbbell front squat', { ...base('front-squat'), implement: { kind: 'dumbbells', at: 'hands' } });
def('rdl-band', 'Band Romanian deadlift', { ...base('rdl'), implement: BAND_FEET });
def('hip-thrust-band', 'Band hip thrust', { ...base('hip-thrust'), implement: BAND_FLOOR });
def('step-up-dumbbells', 'Dumbbell step-up', { ...base('step-up'), implement: { kind: 'dumbbells', at: 'hands' } });
def('reverse-lunge-dumbbells', 'Dumbbell reverse lunge', { ...base('reverse-lunge'), implement: { kind: 'dumbbells', at: 'hands' } });
def('floor-press-band', 'Band floor press', { ...base('floor-press'), implement: BAND_FLOOR });
def('overhead-press-dumbbells', 'Dumbbell overhead press', { ...base('overhead-press'), implement: { kind: 'dumbbells', at: 'hands' } });
def('overhead-press-band', 'Band overhead press', { ...base('overhead-press'), implement: BAND_FEET });
def('woodchop-band', 'Band woodchop', { ...base('woodchop'), implement: { ...base('woodchop').implement, kind: 'band' } });
def('lat-pulldown-band', 'Band pulldown', { ...base('lat-pulldown'), implement: { ...base('lat-pulldown').implement, kind: 'band' } });
def('seated-cable-row-band', 'Seated band row', { ...base('seated-cable-row'), implement: { ...base('seated-cable-row').implement, kind: 'band' } });
def('face-pull-band', 'Band face pull', { ...base('face-pull'), implement: { ...base('face-pull').implement, kind: 'band' } });
def('triceps-pressdown-band', 'Band pressdown', { ...base('triceps-pressdown'), implement: { ...base('triceps-pressdown').implement, kind: 'band' } });
def('biceps-curl-band', 'Band curl', { ...base('biceps-curl'), implement: BAND_FEET });
def('reverse-fly-band', 'Bent-over band reverse fly', { ...base('reverse-fly'), implement: BAND_FEET });
def('suitcase-carry-kettlebell', 'Kettlebell suitcase carry', { ...base('suitcase-carry'), implement: { kind: 'kettlebell', at: 'R' } });
def('single-leg-rdl-bodyweight', 'Single-leg Romanian deadlift (bodyweight)', { ...base('single-leg-rdl'), implement: undefined });
def('single-leg-rdl-barbell', 'Single-leg Romanian deadlift (barbell)', { ...base('single-leg-rdl'), implement: { kind: 'barbell', at: 'hands' } });
def('single-leg-rdl-trapbar', 'Single-leg trap-bar deadlift', { ...base('single-leg-rdl'), implement: TRAP });
def('split-squat-goblet', 'Goblet split squat', {
  ...base('split-squat'), implement: { kind: 'goblet', at: 'chest' },
  keyframes: base('split-squat').keyframes.map((k) => ({ ...k, pose: goblet(k.pose) })),
});

def('high-pull-dumbbells', 'Dumbbell high pull', { ...base('high-pull'), implement: { kind: 'dumbbells', at: 'hands' } });
def('overhead-squat-pvc', 'PVC overhead squat', { ...base('overhead-squat'), implement: { kind: 'barbell', at: 'hands', pvc: true } });
def('wrist-curl-band', 'Band wrist curl', { ...base('wrist-curl'), implement: BAND_FEET });
def('pull-up-band', 'Band-assisted pull-up', { ...base('pull-up'), implement: { kind: 'band', at: 'hands', loopFeet: true } });

// ── Single side ───────────────────────────────────────────────────────────
/** The free arm rests: along the body when lying, hand at the hip when standing. */
def('dumbbell-bench-press-single', 'Single-arm dumbbell bench press',
  edit({ ...base('dumbbell-bench-press'), implement: { kind: 'dumbbell', at: 'R' } }, () => ({ shoulderL: 30, shoulderAbdL: 30, elbowL: 20, shoulderRotL: 0 })));
def('overhead-press-single', 'Single-arm dumbbell overhead press',
  edit({ ...base('overhead-press'), implement: { kind: 'dumbbell', at: 'R' } }, () => ({ shoulderL: -6, shoulderAbdL: 30, elbowL: 80, shoulderRotL: 40 })));
/** The free knee driven up (thigh toward the chest), foot off the floor. */
def('hip-thrust-single-leg', 'Single-leg hip thrust',
  edit(base('hip-thrust'), (q) => ({ hipL: q.hipR + 75, kneeL: 95, ankleL: 10 }), () => 'R'));
def('hamstring-slider-curl-single', 'Single-leg slider curl',
  edit(base('hamstring-slider-curl'), (q) => ({ hipL: q.hipR + 30, kneeL: 4 }), () => 'Rheel'));
/** Only the right foot works; the left is tucked up behind. */
const rightOnly = (c) => c.replace(/\bfeet\b/, 'R').replace('Ltoe+Rtoe', 'Rtoe');
const stepRaise = base('calf-raise-step');
def('calf-raise-step-straight', 'Standing calf raise off a step', {
  ...stepRaise, keyframes: [stepRaise.keyframes[0], { ...stepRaise.keyframes[1], move: 0.8 }, { ...stepRaise.keyframes[0], hold: 0.1 }],
});
def('calf-raise-step-single', 'Single-leg calf raise off a step', edit(BY_LOCAL('calf-raise-step-straight'), () => ({ hipL: 10, kneeL: 70, ankleL: 10 }), rightOnly));
def('vertical-jump-single-leg', 'Single-leg countermovement jump', edit(base('vertical-jump'), (q) => ({ hipL: q.hipR + 25, kneeL: Math.min(150, q.kneeR + 75), ankleL: 10 }), rightOnly));
def('prone-leg-curl-single', 'Single-leg lying leg curl', edit(base('prone-leg-curl'), () => ({ kneeL: 4 })));

// ── Half-kneeling cable lift: inside knee down, low to high across the body ──
const hk = { hipL: -8, kneeL: 92, ankleL: -40, hipR: 88, kneeR: 92, ankleR: 4, hipAbdL: 6, hipAbdR: 6, spine: 2 };
const liftLow = P(hk, { twist: 34, neckTurn: 20, shoulderL: 34, shoulderAbdL: 30, elbowL: 10, shoulderR: 40, shoulderAbdR: -30, elbowR: 12 });
const liftHigh = P(hk, { twist: -30, neckTurn: -20, shoulderL: 150, shoulderAbdL: -14, elbowL: 10, shoulderR: 150, shoulderAbdR: 30, elbowR: 10 });
const halfKneelingLift = (kind) => ({
  view: 'three-quarter', thumb: 1, implement: { kind, at: 'hands', to: [10, 12, 70] },
  keyframes: [kf(liftLow, 'Lknee+R', { hold: 0.3, move: 0.8 }), kf(liftHigh, 'Lknee+R', { hold: 0.25, move: 1.0 }), kf(liftLow, 'Lknee+R', { hold: 0.1 })],
});
def('half-kneeling-lift', 'Half-kneeling cable lift', halfKneelingLift('cable'));
def('half-kneeling-lift-band', 'Half-kneeling band lift', halfKneelingLift('band'));

// ── Opposed: the same drill against a live defender ───────────────────────
// The shadow-defending drills' own defenders, without the attacker they mirror.
def('hockey-defender', 'Hockey defender', { ...base('hockey-shadow-defend'), cast: undefined, path: undefined });
def('fh-defender', 'Field hockey defender', { ...base('fh-shadow-defend'), cast: undefined, path: undefined, ball: undefined });
const opposed = (slug, member) => def(`${slug}-opposed`, `${BY.get(slug).name} (opposed)`, { ...base(slug), cast: [...(base(slug).cast ?? []), member] });
opposed('soccer-instep-kick', { pattern: 'bb-defensive-slide', at: [210, 40], facing: 180, phase: 0.3 });
opposed('soccer-dribble', { pattern: 'bb-defensive-slide', at: [120, 20], facing: 180, follow: true });
opposed('ball-carry-run', { pattern: 'bb-defensive-slide', at: [130, 30], facing: 180, follow: true });
opposed('bb-first-step', { pattern: 'bb-defensive-slide', at: [100, 44], facing: 180, phase: 0.5 });
opposed('bb-layup', { pattern: 'vb-block', at: [160, 40], facing: 180, phase: 0.3 });
opposed('bb-mikan', { pattern: 'vb-block', at: [34, -60], facing: 120, phase: 0.2 });
opposed('vb-approach-swing', { pattern: 'vb-block', at: [175, 0], facing: 180, phase: 0.2 });
opposed('vb-spike', { pattern: 'vb-block', at: [165, 0], facing: 180, phase: 0.2 });
opposed('hockey-toe-drag', { pattern: 'hockey-defender', at: [110, 0], facing: 180 });
opposed('fh-indian-dribble', { pattern: 'fh-defender', at: [110, 0], facing: 180 });
opposed('lax-split-dodge', { pattern: 'lax-defend-stance', at: [110, 44], facing: 180 });
opposed('lax-ground-ball', { pattern: 'lax-defend-stance', at: [60, -120], facing: 150, phase: 0.4 });

export const VARIANTS = lib.patterns;
