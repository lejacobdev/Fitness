/**
 * V6 exercise knowledge base (docs/VERSION-6.md §10): what each exercise IS
 * for the planner — its movement pattern, its role in a session, how much
 * it costs — so sessions are built by purpose, not by keyword.
 *
 * Every base exercise in the core library is tagged by hand below. Variants
 * (tempo, unilateral, equipment tiers) inherit their base's profile; sport
 * drills, which are skill work first, get a rule-based profile from their
 * qualities.
 *
 *   pattern     squat · hinge · push · pull · carry · rotation · anti-rotation ·
 *               unilateral-lower · jump · throw · sprint · deceleration ·
 *               change-of-direction · locomotion · conditioning · mobility ·
 *               isolation · balance · breathing · skill
 *   role        where it goes in a session: prep · power · speed · primary ·
 *               secondary · accessory · trunk · conditioning · mobility ·
 *               recovery · skill
 *   regions     l (lower body) · u (upper body) · t (trunk)
 *   fatigue     1 (barely any) … 5 (a hard, heavy compound or a hard interval set)
 *   impact      0 none · 1 low · 2 moderate (running) · 3 high (jumps, max sprints)
 *   technique   1 simple · 2 needs practice · 3 needs coaching
 *   legLoad     0 … 3: how much it adds to leg fatigue (the after-practice budget)
 *   group       replacement group: exercises that can stand in for each other
 *   conditioning (conditioning items only) { type, modality }
 */

// slug: pattern role regions fatigue impact technique legLoad group
const TABLE = `
acceleration-wall-drill: sprint prep l 1 1 1 1 sprint-accel-drill
acceleration-march: locomotion prep l 1 1 1 1 sprint-accel-drill
sled-push: sprint speed l 3 1 1 3 sprint-accel-resisted
flying-sprint: sprint speed l 3 3 2 2 sprint-maxv
lateral-shuffle-cone-drill: change-of-direction speed l 2 2 1 2 cod
5-10-5-shuttle: change-of-direction speed l 3 2 1 2 cod
lateral-bound: jump power l 2 3 2 2 jump-lateral
deceleration-drop-stick: deceleration power l 2 2 1 2 decel
countermovement-jump: jump power l 2 3 1 2 jump-vertical
weighted-jump-squat: jump power l 3 3 2 2 jump-vertical
broad-jump: jump power l 2 3 1 2 jump-horizontal
rotational-step-through-throw: throw power ut 1 0 1 0 throw-rotational
med-ball-rotational-throw: throw power ut 2 0 1 0 throw-rotational
explosive-wall-reach-jump: jump power lu 2 3 1 2 jump-vertical
med-ball-overhead-throw: throw power ut 2 0 1 0 throw-overhead
pogo-hop: jump power l 1 3 1 1 reactive-hop
trap-bar-deadlift: hinge primary lt 5 0 2 3 hinge-bilateral
goblet-squat: squat primary lt 3 0 1 2 squat-bilateral
barbell-back-squat: squat primary lt 5 0 3 3 squat-bilateral
bulgarian-split-squat: unilateral-lower primary l 4 0 2 3 single-leg-knee
split-squat: unilateral-lower secondary l 2 0 1 2 single-leg-knee
nordic-hamstring-curl: hinge accessory l 3 0 2 2 hamstring-eccentric
bodyweight-squat: squat secondary l 1 0 1 1 squat-bilateral
push-up: push primary ut 2 0 1 0 push-horizontal
bench-press: push primary u 4 0 2 0 push-horizontal
incline-push-up: push secondary u 1 0 1 0 push-horizontal
pull-up: pull primary u 3 0 2 0 pull-vertical
band-assisted-pull-up: pull primary u 2 0 1 0 pull-vertical
inverted-row: pull primary ut 2 0 1 0 pull-horizontal
prone-y-t-w-raise: isolation accessory u 1 0 1 0 shoulder-health
band-pull-apart: isolation accessory u 1 0 1 0 shoulder-health
plank-shoulder-tap: anti-rotation trunk tu 1 0 1 0 anti-rotation
pallof-press: anti-rotation trunk t 1 0 1 0 anti-rotation
bear-crawl-hold: anti-rotation trunk tu 1 0 1 0 anti-extension
farmers-carry: carry accessory lut 3 0 1 1 carry
continuous-easy-run: conditioning conditioning l 2 2 1 2 conditioning-aerobic
hill-sprint-repeats: sprint conditioning l 4 2 1 3 conditioning-anaerobic
shuttle-repeat-sprints: conditioning conditioning l 4 2 1 3 conditioning-rsa
tempo-run: conditioning conditioning l 3 2 1 2 conditioning-tempo
single-leg-balance-reach: balance accessory l 1 0 1 1 balance
single-leg-rdl: hinge secondary l 2 0 2 1 single-leg-hip
90-90-hip-switch: mobility mobility l 1 0 1 0 mobility-hip
mobility-flow-series: mobility mobility lut 1 0 1 0 mobility-flow
scapular-wall-slide: isolation prep u 1 0 1 0 shoulder-health
single-leg-ankle-hop: jump power l 1 3 1 1 reactive-hop
drop-landing-stick: deceleration power l 1 2 1 1 landing
shadow-cutting-drill: change-of-direction speed l 2 2 1 2 cod
in-place-suicide-sprints: conditioning conditioning l 3 2 1 2 conditioning-rsa
a-skip: locomotion prep l 1 1 1 1 sprint-mechanics
b-skip: locomotion prep l 1 1 2 1 sprint-mechanics
straight-leg-bound: sprint speed l 2 3 2 2 sprint-maxv
falling-start: sprint speed l 2 2 1 2 sprint-accel
sprint-from-push-up-start: sprint speed l 2 2 1 2 sprint-accel
resisted-band-sprint: sprint speed l 3 2 1 2 sprint-accel-resisted
wicket-runs: sprint speed l 2 2 2 2 sprint-maxv
build-up-strides: sprint prep l 1 2 1 1 sprint-mechanics
hill-bounds: jump power l 3 3 2 3 jump-horizontal
t-drill: change-of-direction speed l 2 2 1 2 cod
l-drill: change-of-direction speed l 2 2 1 2 cod
pro-agility-plant-hold: deceleration power l 2 2 1 2 decel
reactive-mirror-drill: change-of-direction speed l 2 2 1 2 cod
crossover-run-drill: change-of-direction speed l 2 2 2 2 cod
backpedal-to-sprint: change-of-direction speed l 2 2 1 2 cod
eccentric-step-down: unilateral-lower accessory l 2 0 1 1 single-leg-knee
box-jump: jump power l 2 2 1 2 jump-vertical
depth-jump: jump power l 3 3 3 2 reactive-hop
tuck-jump: jump power l 2 3 1 2 jump-vertical
hurdle-hops: jump power l 2 3 2 2 reactive-hop
skater-hops: jump power l 2 3 1 2 jump-lateral
single-leg-hop-and-hold: deceleration power l 2 3 2 2 landing
split-squat-jump: jump power l 3 3 2 2 jump-vertical
lateral-line-hops: jump prep l 1 2 1 1 reactive-hop
jump-rope-intervals: conditioning conditioning l 2 2 1 1 conditioning-interval
broad-jump-to-sprint: jump power l 3 3 2 2 jump-horizontal
med-ball-scoop-toss: throw power lut 2 0 1 1 throw-rotational
med-ball-shotput-throw: throw power ut 2 0 1 0 throw-rotational
med-ball-slam: throw power ut 2 0 1 1 throw-overhead
med-ball-chest-pass: throw power u 1 0 1 0 throw-chest
band-woodchop: rotation trunk t 1 0 1 0 rotation
landmine-rotation: rotation trunk tu 2 0 2 1 rotation
barbell-front-squat: squat primary lt 5 0 3 3 squat-bilateral
romanian-deadlift: hinge primary lt 4 0 2 3 hinge-bilateral
hip-thrust: hinge secondary l 3 0 1 2 hinge-hip-extension
step-up: unilateral-lower secondary l 3 0 1 2 single-leg-knee
reverse-lunge: unilateral-lower secondary l 3 0 1 2 single-leg-knee
lateral-lunge: unilateral-lower secondary l 2 0 1 2 single-leg-lateral
cossack-squat: unilateral-lower mobility l 1 0 2 1 single-leg-lateral
wall-sit: squat accessory l 2 0 1 2 knee-isometric
spanish-squat: squat accessory l 2 0 1 2 knee-isometric
sissy-squat-assisted: squat accessory l 2 0 2 2 knee-isometric
hamstring-slider-curl: hinge accessory l 2 0 1 2 hamstring-eccentric
leg-curl-machine: isolation accessory l 2 0 1 1 hamstring-eccentric
kettlebell-swing: hinge power l 3 0 2 2 hinge-ballistic
single-leg-glute-bridge: hinge accessory l 1 0 1 1 hinge-hip-extension
dumbbell-bench-press: push primary u 3 0 1 0 push-horizontal
overhead-press-dumbbell: push primary ut 3 0 1 0 push-vertical
landmine-press: push secondary ut 2 0 1 0 push-vertical
dips-parallel: push secondary u 3 0 2 0 push-vertical
pike-push-up: push secondary u 2 0 1 0 push-vertical
plyo-push-up: push power u 2 0 2 0 throw-chest
tempo-push-up: push secondary ut 2 0 1 0 push-horizontal
dumbbell-row: pull primary u 2 0 1 0 pull-horizontal
lat-pulldown: pull primary u 2 0 1 0 pull-vertical
chin-up: pull primary u 3 0 2 0 pull-vertical
seated-cable-row: pull primary u 2 0 1 0 pull-horizontal
face-pull: isolation accessory u 1 0 1 0 shoulder-health
towel-row: pull secondary u 2 0 1 0 pull-horizontal
scap-pull-up: pull accessory u 1 0 1 0 shoulder-health
band-external-rotation: isolation accessory u 1 0 1 0 shoulder-health
sleeper-stretch: mobility mobility u 1 0 1 0 mobility-shoulder
serratus-wall-slide: isolation prep u 1 0 1 0 shoulder-health
prone-i-raise: isolation accessory u 1 0 1 0 shoulder-health
dumbbell-curl: isolation accessory u 1 0 1 0 arm-isolation
triceps-extension-band: isolation accessory u 1 0 1 0 arm-isolation
dead-hang: carry accessory u 1 0 1 0 grip
suitcase-carry: carry trunk tlu 2 0 1 1 carry
overhead-carry: carry trunk tu 2 0 1 1 carry
plate-pinch: isolation accessory u 1 0 1 0 grip
wrist-roller: isolation accessory u 1 0 1 0 grip
band-wrist-extension: isolation accessory u 1 0 1 0 grip
dead-bug: anti-rotation trunk t 1 0 1 0 anti-extension
bird-dog: anti-rotation trunk t 1 0 1 0 anti-rotation
side-plank: anti-rotation trunk t 1 0 1 0 anti-lateral
hollow-hold: anti-rotation trunk t 1 0 1 0 anti-extension
ab-wheel-rollout: anti-rotation trunk tu 2 0 2 0 anti-extension
half-kneeling-chop: rotation trunk t 1 0 1 0 rotation
hanging-knee-raise: anti-rotation trunk tu 2 0 1 0 anti-extension
stir-the-pot: anti-rotation trunk t 2 0 1 0 anti-extension
back-extension: hinge accessory lt 2 0 1 1 hinge-hip-extension
superman-hold: hinge trunk t 1 0 1 0 back-extension
copenhagen-plank: anti-rotation accessory lt 2 0 2 1 hip-adductor
adductor-squeeze: isolation accessory l 1 0 1 0 hip-adductor
tibialis-raise: isolation accessory l 1 0 1 1 calf-ankle
standing-calf-raise: isolation accessory l 1 0 1 1 calf-ankle
bent-knee-calf-raise: isolation accessory l 1 0 1 1 calf-ankle
ankle-alphabet: mobility recovery l 1 0 1 0 mobility-ankle
short-foot-drill: balance accessory l 1 0 1 0 foot
towel-toe-curls: isolation recovery l 1 0 1 0 foot
single-leg-balance-eyes-closed: balance accessory l 1 0 1 1 balance
star-excursion-reach: balance accessory l 1 0 1 1 balance
lateral-band-walk: locomotion prep l 1 0 1 1 hip-activation
clamshell: isolation prep l 1 0 1 0 hip-activation
reverse-nordic: squat accessory l 2 0 2 2 knee-eccentric
neck-isometrics: isolation accessory u 1 0 1 0 neck
band-neck-extension: isolation accessory u 1 0 1 0 neck
chin-tuck: isolation recovery u 1 0 1 0 neck
worlds-greatest-stretch: mobility prep lut 1 0 1 0 mobility-flow
couch-stretch: mobility mobility l 1 0 1 0 mobility-hip
deep-squat-hold: mobility mobility l 1 0 1 0 mobility-hip
pigeon-stretch: mobility mobility l 1 0 1 0 mobility-hip
hamstring-floss: mobility mobility l 1 0 1 0 mobility-hamstring
thoracic-open-book: mobility mobility tu 1 0 1 0 mobility-thoracic
cat-camel: mobility recovery t 1 0 1 0 mobility-spine
ankle-knee-to-wall: mobility prep l 1 0 1 0 mobility-ankle
foam-roll-quads-calves: mobility recovery l 1 0 1 0 soft-tissue
hip-circles-standing: mobility prep l 1 0 1 0 mobility-hip
shoulder-dislocates-band: mobility prep u 1 0 1 0 mobility-shoulder
bike-intervals: conditioning conditioning l 4 0 1 2 conditioning-interval
easy-bike-ride: conditioning conditioning l 1 0 1 1 conditioning-aerobic
burpee: conditioning conditioning lut 3 2 1 2 conditioning-interval
mountain-climbers: conditioning conditioning lt 2 1 1 1 conditioning-interval
30-15-intermittent-run: conditioning conditioning l 4 2 1 2 conditioning-rsa
fartlek-run: conditioning conditioning l 3 2 1 2 conditioning-aerobic
sled-drag-backward: locomotion conditioning l 2 0 1 2 conditioning-sled
battle-rope-waves: conditioning conditioning ut 3 0 1 0 conditioning-upper
stair-runs: conditioning conditioning l 3 2 1 3 conditioning-anaerobic
rowing-machine-intervals: conditioning conditioning lut 4 0 2 2 conditioning-interval
hang-power-clean: hinge power lut 4 0 3 2 olympic
clean-pull-dumbbell: hinge power lu 2 0 2 1 olympic
push-press: push power ult 3 0 2 1 push-vertical-power
barbell-bent-over-row: pull primary ut 3 0 2 1 pull-horizontal
barbell-deadlift: hinge primary lt 5 0 3 3 hinge-bilateral
barbell-overhead-squat-pvc: mobility prep lut 1 0 2 0 mobility-flow
lateral-box-jump: jump power l 2 2 1 2 jump-lateral
single-leg-box-jump: jump power l 2 2 2 2 jump-vertical
triple-broad-jump: jump power l 3 3 2 2 jump-horizontal
medball-overhead-backward-toss: throw power lut 2 0 1 1 throw-overhead
medball-side-toss-lateral-step: throw power lut 2 0 1 1 throw-rotational
dumbbell-snatch-single-arm: hinge power lut 3 0 2 1 olympic
repeat-shuttle-10m: conditioning conditioning l 3 2 1 2 conditioning-rsa
tempo-200s: conditioning conditioning l 3 2 1 2 conditioning-tempo
long-easy-run: conditioning conditioning l 2 2 1 2 conditioning-aerobic
box-step-over-conditioning: conditioning conditioning l 2 1 1 2 conditioning-interval
goblet-lateral-squat: unilateral-lower secondary l 2 0 1 2 single-leg-lateral
split-squat-bottom-hold: unilateral-lower accessory l 2 0 1 2 knee-isometric
kickstand-rdl: hinge secondary l 2 0 1 2 single-leg-hip
inverted-row-feet-elevated: pull primary ut 2 0 1 0 pull-horizontal
push-up-plus: push accessory u 1 0 1 0 shoulder-health
bear-crawl-forward: locomotion prep lut 1 0 1 1 crawl
turkish-get-up: carry trunk lut 2 0 2 1 get-up
pallof-hold-split-stance: anti-rotation trunk t 1 0 1 0 anti-rotation
farmers-march: carry trunk lt 2 0 1 1 carry
nordic-assisted-band: hinge accessory l 2 0 1 2 hamstring-eccentric
hip-airplane: balance accessory l 1 0 2 1 balance
lateral-hop-to-stick: deceleration power l 2 2 1 2 landing
drop-squat: deceleration power l 2 1 1 2 decel
sprint-arm-drill: sprint prep u 1 0 1 0 sprint-mechanics
curtsy-lunge: unilateral-lower secondary l 2 0 1 2 single-leg-lateral
dumbbell-incline-press: push primary u 3 0 1 0 push-incline
reverse-fly-dumbbell: isolation accessory u 1 0 1 0 shoulder-health
breathing-90-90: breathing recovery t 1 0 1 0 breathing
`;

const CONDITIONING = {
  'continuous-easy-run': ['aerobic-base', 'run'],
  'long-easy-run': ['aerobic-base', 'run'],
  'fartlek-run': ['aerobic-base', 'run'],
  'tempo-run': ['tempo', 'run'],
  'tempo-200s': ['tempo', 'run'],
  '30-15-intermittent-run': ['aerobic-power', 'run'],
  'bike-intervals': ['aerobic-power', 'bike'],
  'easy-bike-ride': ['aerobic-base', 'bike'],
  'rowing-machine-intervals': ['aerobic-power', 'row'],
  'jump-rope-intervals': ['aerobic-power', 'rope'],
  'box-step-over-conditioning': ['aerobic-power', 'bodyweight'],
  'burpee': ['anaerobic', 'bodyweight'],
  'mountain-climbers': ['anaerobic', 'bodyweight'],
  'battle-rope-waves': ['anaerobic', 'rope'],
  'stair-runs': ['anaerobic', 'stairs'],
  'hill-sprint-repeats': ['repeated-sprint', 'run'],
  'shuttle-repeat-sprints': ['repeated-sprint', 'run'],
  'in-place-suicide-sprints': ['repeated-sprint', 'run'],
  'repeat-shuttle-10m': ['repeated-sprint', 'run'],
  'sled-drag-backward': ['tempo', 'sled'],
};

export const PATTERNS = ['squat', 'hinge', 'push', 'pull', 'carry', 'rotation', 'anti-rotation', 'unilateral-lower', 'jump', 'throw', 'sprint',
  'deceleration', 'change-of-direction', 'locomotion', 'conditioning', 'mobility', 'isolation', 'balance', 'breathing', 'skill'];
export const ROLES = ['prep', 'power', 'speed', 'primary', 'secondary', 'accessory', 'trunk', 'conditioning', 'mobility', 'recovery', 'skill'];

function parseTable() {
  const out = new Map();
  for (const line of TABLE.trim().split('\n')) {
    const [slug, rest] = line.split(':');
    const [pattern, role, regions, fatigue, impact, technique, legLoad, group] = rest.trim().split(/\s+/);
    const profile = {
      pattern,
      role,
      regions: [...regions].map((c) => ({ l: 'lower', u: 'upper', t: 'trunk' })[c]),
      fatigue: Number(fatigue),
      impact: Number(impact),
      technique: Number(technique),
      legLoad: Number(legLoad),
      group,
    };
    if (CONDITIONING[slug]) profile.conditioning = { type: CONDITIONING[slug][0], modality: CONDITIONING[slug][1] };
    out.set(slug.trim(), profile);
  }
  return out;
}

export const HAND_PROFILES = parseTable();

const SPEED_Q = ['acceleration', 'max-velocity', 'change-of-direction', 'lateral-power', 'deceleration'];
const POWER_Q = ['vertical-power', 'horizontal-power', 'rotational-power', 'overhead-power', 'reactive-strength'];

/**
 * The profile of one (expanded) catalogue item. Variants take their base's;
 * a tempo variant costs a little more, a unilateral one stays the same.
 */
export function profileFor(item) {
  const own = HAND_PROFILES.get(item.slug);
  if (own) return own;
  if (item.baseSlug && HAND_PROFILES.has(item.baseSlug)) {
    const base = HAND_PROFILES.get(item.baseSlug);
    const tempo = item.variant?.axis === 'tempo';
    return { ...base, fatigue: Math.min(5, base.fatigue + (tempo ? 1 : 0)) };
  }
  return derived(item);
}

/** Sport drills (and anything new not yet tagged): from their qualities. */
function derived(item) {
  const q = item.qualities ?? {};
  const top = Object.entries(q).sort((a, b) => b[1] - a[1])[0]?.[0] ?? '';
  const contacts = item.defaultDose?.kind === 'contacts';
  const lowerHeavy = (q['lower-body-strength'] ?? 0) >= 0.7;
  if (item.kind === 'drill') {
    const speedy = SPEED_Q.includes(top) || ['repeat-sprint', 'anaerobic-capacity'].includes(top);
    return {
      pattern: 'skill', role: 'skill',
      regions: lowerHeavy || speedy || contacts ? ['lower'] : ['upper', 'trunk'],
      fatigue: speedy || contacts ? 2 : 1,
      impact: contacts ? 3 : speedy ? 2 : 0,
      technique: 2,
      legLoad: speedy || contacts ? 2 : 1,
      group: `skill-${item.sport ?? 'general'}`,
    };
  }
  if (SPEED_Q.includes(top)) return { pattern: 'sprint', role: 'speed', regions: ['lower'], fatigue: 2, impact: 2, technique: 1, legLoad: 2, group: 'speed' };
  if (POWER_Q.includes(top)) return { pattern: contacts ? 'jump' : 'throw', role: 'power', regions: ['lower'], fatigue: 2, impact: contacts ? 3 : 0, technique: 1, legLoad: contacts ? 2 : 1, group: 'power' };
  if (['aerobic-base', 'anaerobic-capacity', 'repeat-sprint'].includes(top)) {
    return { pattern: 'conditioning', role: 'conditioning', regions: ['lower'], fatigue: 3, impact: 2, technique: 1, legLoad: 2, group: 'conditioning-interval', conditioning: { type: 'aerobic-power', modality: 'run' } };
  }
  if (top === 'hip-mobility') return { pattern: 'mobility', role: 'mobility', regions: ['lower'], fatigue: 1, impact: 0, technique: 1, legLoad: 0, group: 'mobility-hip' };
  if (top === 'trunk-anti-rotation') return { pattern: 'anti-rotation', role: 'trunk', regions: ['trunk'], fatigue: 1, impact: 0, technique: 1, legLoad: 0, group: 'anti-rotation' };
  if (top === 'upper-body-push') return { pattern: 'push', role: 'secondary', regions: ['upper'], fatigue: 2, impact: 0, technique: 1, legLoad: 0, group: 'push-horizontal' };
  if (top === 'upper-body-pull') return { pattern: 'pull', role: 'secondary', regions: ['upper'], fatigue: 2, impact: 0, technique: 1, legLoad: 0, group: 'pull-horizontal' };
  if (top === 'lower-body-strength') return { pattern: 'squat', role: 'secondary', regions: ['lower'], fatigue: 3, impact: 0, technique: 1, legLoad: 2, group: 'squat-bilateral' };
  return { pattern: 'isolation', role: 'accessory', regions: ['lower'], fatigue: 1, impact: 0, technique: 1, legLoad: 1, group: 'accessory' };
}
