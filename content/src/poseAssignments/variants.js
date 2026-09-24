/**
 * Variants (dumbbell / band / bodyweight versions, single-side versions,
 * opposed drills) that look different from their base item. Any variant not
 * listed shows its base item's pattern.
 */
export const VARIANT_POSES = {
  // Equipment tiers
  'trap-bar-deadlift-dumbbell': 'deadlift-dumbbells', 'trap-bar-deadlift-band': 'deadlift-band', 'trap-bar-deadlift-bodyweight': 'squat-bodyweight',
  'trap-bar-deadlift-unilateral': 'single-leg-rdl-trapbar',
  'goblet-squat-band': 'goblet-squat-band', 'goblet-squat-bodyweight': 'squat-bodyweight', 'goblet-squat-unilateral': 'split-squat-goblet',
  'bench-press-dumbbell': 'dumbbell-bench-press', 'bench-press-band': 'floor-press-band', 'bench-press-bodyweight': 'push-up',
  'bench-press-unilateral': 'dumbbell-bench-press-single',
  'single-leg-rdl-bodyweight': 'single-leg-rdl-bodyweight',
  'band-woodchop-band': 'woodchop-band',
  'barbell-front-squat-dumbbell': 'front-squat-dumbbells', 'barbell-front-squat-bodyweight': 'squat-bodyweight',
  'romanian-deadlift-dumbbell': 'rdl-dumbbells', 'romanian-deadlift-band': 'rdl-band', 'romanian-deadlift-unilateral': 'single-leg-rdl-barbell',
  'hip-thrust-band': 'hip-thrust-band', 'hip-thrust-bodyweight': 'glute-bridge', 'hip-thrust-unilateral': 'hip-thrust-single-leg',
  'step-up-bodyweight': 'step-up', 'reverse-lunge-bodyweight': 'reverse-lunge',
  'dumbbell-bench-press-band': 'floor-press-band', 'dumbbell-bench-press-bodyweight': 'push-up', 'dumbbell-bench-press-unilateral': 'dumbbell-bench-press-single',
  'overhead-press-dumbbell-band': 'overhead-press-band', 'overhead-press-dumbbell-unilateral': 'overhead-press-single',
  'dumbbell-row-band': 'band-row', 'lat-pulldown-band': 'lat-pulldown-band', 'seated-cable-row-band': 'seated-cable-row-band',
  'face-pull-band': 'face-pull-band', 'dumbbell-curl-band': 'biceps-curl-band', 'triceps-extension-band-band': 'triceps-pressdown-band',
  'suitcase-carry-dumbbell': 'suitcase-carry', 'half-kneeling-chop-band': 'half-kneeling-lift-band',
  'push-press-dumbbell': 'dumbbell-push-press', 'reverse-fly-dumbbell-band': 'reverse-fly-band',
  'standing-calf-raise-unilateral': 'calf-raise-step-single', 'countermovement-jump-unilateral': 'vertical-jump-single-leg',
  // Opposed drills show the defender
  'soccer-plant-and-strike-opposed': 'soccer-instep-kick-opposed', 'soccer-cone-dribble-slalom-opposed': 'soccer-dribble-opposed',
  'flag-football-hesitation-burst-opposed': 'ball-carry-run-opposed', 'basketball-first-step-attack-opposed': 'bb-first-step-opposed',
  'basketball-approach-and-finish-opposed': 'bb-layup-opposed', 'basketball-mikan-drill-opposed': 'bb-mikan-opposed',
  'volleyball-approach-and-swing-footwork-opposed': 'vb-approach-swing-opposed', 'volleyball-box-set-attack-opposed': 'vb-spike-opposed',
  'ice-hockey-toe-drag-stickhandling-opposed': 'hockey-toe-drag-opposed', 'field-hockey-indian-dribble-lane-opposed': 'fh-indian-dribble-opposed',
  'lacrosse-split-dodge-cones-opposed': 'lax-split-dodge-opposed', 'lacrosse-ground-ball-scoop-and-go-opposed': 'lax-ground-ball-opposed',
  'hamstring-slider-curl-unilateral': 'hamstring-slider-curl-single', 'leg-curl-machine-unilateral': 'prone-leg-curl-single',
};
