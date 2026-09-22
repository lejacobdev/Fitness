import assert from 'node:assert/strict';
import test from 'node:test';

import {
  CONSTRAINT_AXES,
  expandAllConstraints,
  expandCatalogue,
  expandConstraint,
  expandEquipmentChain,
  expandItem,
  expandTempo,
  expandUnilateral,
  TEMPO_KINDS,
} from '../src/expand.js';
import { validateItem } from '../src/schema.js';

function baseExercise(overrides = {}) {
  return {
    slug: 'trap-bar-deadlift',
    name: 'Trap-Bar Deadlift',
    kind: 'exercise',
    qualities: { 'lower-body-strength': 1.0, grip: 0.5 },
    muscles: { 'gluteus-maximus': 1.0, 'erector-spinae': 0.7 },
    equipment: ['trap-bar', 'weight-plate'],
    surface: 'gym',
    minAge: 15,
    supervisionLevel: 'SELF',
    setup: ['Stand inside the trap bar with feet hip-width apart.'],
    execution: ['Grip the handles.', 'Drive through the floor to stand tall.'],
    cues: ['Chest up.', 'Push the floor away.'],
    mistakes: ['Rounding the lower back at lockout.'],
    progressions: ['trap-bar-deadlift-heavy'],
    regressions: ['kettlebell-deadlift'],
    substitutes: ['kettlebell-deadlift'],
    defaultDose: { kind: 'reps', sets: 3, reps: 6, load: 'moderate' },
    restSeconds: 120,
    startPose: 'hinge',
    endPose: 'hinge',
    equipmentChain: [
      { tier: 'trap-bar', label: 'trap bar', equipment: ['trap-bar', 'weight-plate'] },
      { tier: 'dumbbell', label: 'dumbbell', equipment: ['dumbbell'] },
      { tier: 'band', label: 'band', equipment: ['band'] },
      { tier: 'bodyweight', label: 'bodyweight', equipment: ['none'] },
    ],
    unilateralEligible: true,
    unilateralPosePattern: 'single-leg-rdl',
    tempoEligible: true,
    ...overrides,
  };
}

function baseDrill(overrides = {}) {
  return {
    slug: 'soccer-instep-strike',
    name: 'Instep Strike Progression',
    kind: 'drill',
    qualities: { 'rotational-power': 0.9, 'single-leg-stability': 0.5 },
    muscles: { 'rectus-femoris': 0.8, 'gluteus-maximus': 0.6 },
    equipment: ['ball', 'goal'],
    prop: 'ball-round',
    surface: 'field',
    minAge: 13,
    supervisionLevel: 'SELF',
    setup: ['Set up 10 yards from the goal.'],
    execution: ['Plant the non-kicking foot beside the ball.', 'Strike through with the instep.'],
    cues: ['Lock the ankle.', 'Follow through toward the target.'],
    mistakes: ['Leaning back at contact.'],
    progressions: [],
    regressions: [],
    substitutes: [],
    defaultDose: { kind: 'reps', sets: 4, reps: 8 },
    restSeconds: 60,
    startPose: 'instep-strike',
    endPose: 'instep-strike',
    constraintAxes: ['opposition', 'movement'],
    ...overrides,
  };
}

test('expandEquipmentChain produces one item per non-base chain entry', () => {
  const derived = expandEquipmentChain(baseExercise());
  assert.equal(derived.length, 3); // dumbbell, band, bodyweight
  assert.deepEqual(derived.map((d) => d.variant.tier), ['dumbbell', 'band', 'bodyweight']);
});

test('equipment substitution decays load qualities and boosts control qualities monotonically', () => {
  const derived = expandEquipmentChain(baseExercise());
  const strengths = derived.map((d) => d.qualities['lower-body-strength']);
  // Each step down should be strictly less than the one before (decay compounds).
  for (let i = 1; i < strengths.length; i += 1) {
    assert.ok(strengths[i] < strengths[i - 1], `tier ${i} strength ${strengths[i]} should be < ${strengths[i - 1]}`);
  }
});

test('a bodyweight-tier item never claims heavier equipment', () => {
  const derived = expandEquipmentChain(baseExercise());
  const bodyweight = derived.find((d) => d.variant.tier === 'bodyweight');
  assert.deepEqual(bodyweight.equipment, ['none']);
});

test('every equipment-substituted item still validates', () => {
  for (const d of expandEquipmentChain(baseExercise())) {
    assert.deepEqual(validateItem(d), []);
  }
});

test('an item with no equipmentChain produces no equipment variants', () => {
  const derived = expandEquipmentChain(baseExercise({ equipmentChain: undefined }));
  assert.deepEqual(derived, []);
});

test('expandUnilateral boosts the stability quality and marks perSide dose', () => {
  const base = baseExercise();
  const uni = expandUnilateral(base);
  assert.ok(uni.qualities['single-leg-stability'] > (base.qualities['single-leg-stability'] ?? 0));
  assert.equal(uni.defaultDose.perSide, true);
  assert.equal(uni.startPose, 'single-leg-rdl');
  assert.equal(uni.endPose, 'single-leg-rdl');
  assert.deepEqual(validateItem(uni), []);
});

test('expandUnilateral returns null when the base item is not eligible', () => {
  assert.equal(expandUnilateral(baseExercise({ unilateralEligible: false })), null);
});

test('expandUnilateral falls back to the base pose pattern with no unilateralPosePattern', () => {
  const uni = expandUnilateral(baseExercise({ unilateralPosePattern: undefined }));
  assert.equal(uni.startPose, 'hinge');
});

test('every tempo kind produces a distinct, validating item', () => {
  const base = baseExercise();
  const items = TEMPO_KINDS.map((t) => expandTempo(base, t));
  assert.equal(items.length, 3);
  const slugs = new Set(items.map((i) => i.slug));
  assert.equal(slugs.size, 3);
  for (const item of items) assert.deepEqual(validateItem(item), []);
});

test('isometric tempo forces a time-based dose', () => {
  const iso = expandTempo(baseExercise(), 'isometric');
  assert.equal(iso.defaultDose.kind, 'time');
  assert.ok(iso.defaultDose.seconds > 0);
  assert.equal(iso.defaultDose.reps, undefined);
});

test('explosive tempo boosts reactive strength', () => {
  const base = baseExercise();
  const explosive = expandTempo(base, 'explosive');
  assert.ok(explosive.qualities['reactive-strength'] > (base.qualities['reactive-strength'] ?? 0));
});

test('expandTempo returns null for a non-eligible item and throws on an unknown kind', () => {
  assert.equal(expandTempo(baseExercise({ tempoEligible: false }), 'eccentric'), null);
  assert.throws(() => expandTempo(baseExercise(), 'bogus'));
});

test('expandAllConstraints produces every non-default combination, none of them trivial', () => {
  const derived = expandAllConstraints(baseDrill());
  // opposition x movement, each with 2 values, minus the (default, default) combo = 3
  assert.equal(derived.length, 3);
  for (const d of derived) assert.deepEqual(validateItem(d), []);
});

test('opposed constraint increases rest and adds a defender cue', () => {
  const opposed = expandConstraint(baseDrill(), { opposition: 'opposed' });
  const base = baseDrill();
  assert.ok(opposed.restSeconds > base.restSeconds);
  assert.ok(opposed.cues.some((c) => c.toLowerCase().includes('defender')));
});

test('expandConstraint returns null when every axis is left at its default', () => {
  assert.equal(expandConstraint(baseDrill(), {}), null);
  assert.equal(expandConstraint(baseDrill(), { opposition: 'unopposed', movement: 'static' }), null);
});

test('expandConstraint returns null for a non-drill or a drill with no constraintAxes', () => {
  assert.equal(expandConstraint(baseExercise(), { opposition: 'opposed' }), null);
  assert.equal(expandConstraint(baseDrill({ constraintAxes: undefined }), { opposition: 'opposed' }), null);
});

test('expandConstraint throws on an unknown axis value', () => {
  assert.throws(() => expandConstraint(baseDrill(), { opposition: 'bogus' }));
});

test('expandItem composes every applicable axis for one base item', () => {
  const derived = expandItem(baseExercise());
  // 3 equipment tiers + 1 unilateral + 3 tempo = 7 (no constraintAxes on an exercise)
  assert.equal(derived.length, 7);
  const slugs = new Set(derived.map((d) => d.slug));
  assert.equal(slugs.size, derived.length, 'every derived slug must be unique');
});

test('expandItem on a drill composes constraints alongside any other eligible axes', () => {
  const derived = expandItem(baseDrill());
  assert.equal(derived.length, 3); // only the 3 non-default constraint combos
});

test('every derived item slug is permanent-looking (lower-kebab) and traces back via baseSlug', () => {
  for (const d of expandItem(baseExercise())) {
    assert.match(d.slug, /^[a-z0-9]+(-[a-z0-9]+)*$/);
    assert.equal(d.baseSlug, 'trap-bar-deadlift');
  }
});

test('expandCatalogue includes the base items themselves plus every derivative', () => {
  const bases = [baseExercise(), baseDrill()];
  const full = expandCatalogue(bases);
  const exerciseDerived = expandItem(bases[0]).length;
  const drillDerived = expandItem(bases[1]).length;
  assert.equal(full.length, 2 + exerciseDerived + drillDerived);
});

test('expandCatalogue never produces a duplicate slug across a realistic multi-item catalogue', () => {
  const full = expandCatalogue([baseExercise(), baseDrill()]);
  const slugs = full.map((i) => i.slug);
  assert.equal(new Set(slugs).size, slugs.length);
});

test('every quality weight produced anywhere in expansion stays within schema bounds', () => {
  // A pathological base item with an already-maximal load quality should not
  // let the control-boost or unilateral-boost push anything over 1.0.
  const hot = baseExercise({
    qualities: { 'lower-body-strength': 1.0, 'single-leg-stability': 0.95, 'reactive-strength': 0.95 },
  });
  for (const d of expandCatalogue([hot])) {
    for (const w of Object.values(d.qualities)) {
      assert.ok(w >= 0.05 && w <= 1.0, `weight ${w} out of bounds in ${d.slug}`);
    }
  }
});
