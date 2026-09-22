/**
 * Item expansion — §7: "Expansion then applies parameter rules once, not per
 * item: equipment substitution..., unilateral/bilateral, tempo emphasis
 * (eccentric, isometric, explosive), and for drills, constraint variations."
 *
 * A base item is hand-authored once, with real setup/execution/cues/mistakes.
 * Everything below is a pure, deterministic transform from a base item plus a
 * small parameter to a derived item — never a second hand-authored copy. This
 * is the mechanism that turns ~200 exercises + ~400 drills into "well over
 * 1,500 items" without 1,500 hand-written entries.
 *
 * The exact weight-adjustment numbers are a rule this project owns (§7 asks
 * for "adjusted by rule" without specifying one) — documented at each
 * transform so a future change is a deliberate edit, not a guess.
 */

import { MAX_QUALITY_WEIGHT, MIN_QUALITY_WEIGHT } from './schema.js';

function clampWeight(w) {
  return Math.max(MIN_QUALITY_WEIGHT, Math.min(MAX_QUALITY_WEIGHT, w));
}

function round2(n) {
  return Math.round(n * 100) / 100;
}

// ═══════════════════════════════════════════════════════════════════════════
// Equipment substitution
// ═══════════════════════════════════════════════════════════════════════════

/**
 * The load-bearing qualities that a lighter implement cannot develop as far.
 * Stepping an item down a tier decays these; §6's control qualities are
 * boosted slightly in return, because a bodyweight or band variant demands
 * more stabilisation for the same relative effort.
 */
const LOAD_QUALITIES = new Set([
  'lower-body-strength', 'upper-body-push', 'upper-body-pull', 'grip', 'overhead-power',
]);
const CONTROL_QUALITIES = new Set([
  'single-leg-stability', 'trunk-anti-rotation', 'shoulder-stability',
]);

const LOAD_DECAY_PER_TIER = 0.85;
const CONTROL_BOOST_PER_TIER = 0.06;

/**
 * §7's substitution chain: barbell → dumbbell → band → bodyweight. A base
 * item declares its own chain (not every item has all four — a band pull-apart
 * has no barbell version, a Nordic curl has no meaningful equipment ladder at
 * all) via `equipmentChain: [{ tier, equipment: [...] }, ...]`, ordered
 * heaviest first. This generates one derived item per entry after the first.
 */
export function expandEquipment(base, chainEntry, chainIndex) {
  const decay = LOAD_DECAY_PER_TIER ** chainIndex;
  const boost = CONTROL_BOOST_PER_TIER * chainIndex;

  const qualities = {};
  for (const [q, w] of Object.entries(base.qualities)) {
    let adjusted = w;
    if (LOAD_QUALITIES.has(q)) adjusted = w * decay;
    else if (CONTROL_QUALITIES.has(q)) adjusted = w + boost;
    qualities[q] = round2(clampWeight(adjusted));
  }

  return {
    ...base,
    slug: `${base.slug}-${chainEntry.tier}`,
    name: `${base.name} (${chainEntry.label})`,
    equipment: chainEntry.equipment,
    qualities,
    baseSlug: base.slug,
    variant: { axis: 'equipment', tier: chainEntry.tier },
  };
}

/** Every derived item from a base item's declared equipment chain. */
export function expandEquipmentChain(base) {
  if (!base.equipmentChain || base.equipmentChain.length < 2) return [];
  return base.equipmentChain
    .slice(1) // the first entry in the chain is the base item itself
    .map((entry, i) => expandEquipment(base, entry, i + 1));
}

// ═══════════════════════════════════════════════════════════════════════════
// Unilateral / bilateral
// ═══════════════════════════════════════════════════════════════════════════

/**
 * §9: "unilateral mirrors and dims one side." A bilateral base item performed
 * on one limb at a time demands more single-leg or single-arm stability for
 * the same relative load, so that quality is boosted; the dose becomes
 * per-side rather than per-set, which is why the dose note carries "each side"
 * instead of doubling the rep count.
 *
 * §9's "mirror" is a rendering-time operation on the rig (dim the resting
 * limb, mirror the working one), not a transform on the pattern data here —
 * `poses.js`'s pose patterns already encode genuinely asymmetric positions
 * (a lunge, a single-leg RDL) where that is what the movement looks like. So a
 * base item eligible for a unilateral derivative names which pattern its
 * `startPose`/`endPose` should switch to via `unilateralPosePattern`; if it
 * does not declare one (the silhouette does not meaningfully change — a
 * single-arm row looks the same as a two-arm row from the side, only the load
 * is asymmetric) the derived item keeps the base item's own pattern, and the
 * app renders the asymmetric load through the §9 prop layer instead.
 */
const UNILATERAL_STABILITY_BOOST = 0.25;

export function expandUnilateral(base) {
  if (!base.unilateralEligible) return null;

  const qualities = { ...base.qualities };
  const key = base.unilateralStabilityQuality ?? 'single-leg-stability';
  qualities[key] = round2(clampWeight((qualities[key] ?? 0.3) + UNILATERAL_STABILITY_BOOST));

  const pattern = base.unilateralPosePattern ?? base.startPose;

  return {
    ...base,
    slug: `${base.slug}-unilateral`,
    name: `Single-side ${base.name}`,
    qualities,
    startPose: pattern,
    endPose: pattern,
    baseSlug: base.slug,
    variant: { axis: 'unilateral' },
    defaultDose: { ...base.defaultDose, perSide: true },
    cues: [...base.cues, 'Complete the full set on one side before switching.'],
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// Tempo emphasis
// ═══════════════════════════════════════════════════════════════════════════

/**
 * §9: tempo is "annotation rather than geometry" — the pose pair is unchanged,
 * only the dose and coaching cue shift. §7 names three: eccentric, isometric,
 * explosive.
 */
export const TEMPO_KINDS = ['eccentric', 'isometric', 'explosive'];

const TEMPO_RULES = {
  eccentric: {
    label: 'slow eccentric',
    cue: 'Take 3-4 seconds on the lowering phase; the effort is in the control, not the speed.',
    doseNote: '3-4s eccentric',
    qualityBoost: null,
  },
  isometric: {
    label: 'isometric hold',
    cue: 'Hold the midpoint position; brace and breathe rather than rushing through it.',
    doseNote: 'held, not repped',
    qualityBoost: null,
    forceDoseKind: 'time',
  },
  explosive: {
    label: 'explosive',
    cue: 'Move the concentric phase as fast as you can produce force safely — intent matters more than range.',
    doseNote: 'maximal intended speed',
    qualityBoost: 'reactive-strength',
  },
};

export function expandTempo(base, tempoKind) {
  if (!base.tempoEligible) return null;
  const rule = TEMPO_RULES[tempoKind];
  if (!rule) throw new Error(`unknown tempo kind ${JSON.stringify(tempoKind)}`);

  const qualities = { ...base.qualities };
  if (rule.qualityBoost) {
    qualities[rule.qualityBoost] = round2(
      clampWeight((qualities[rule.qualityBoost] ?? 0.3) + 0.15),
    );
  }

  const defaultDose = { ...base.defaultDose, tempo: rule.doseNote };
  if (rule.forceDoseKind === 'time' && defaultDose.kind !== 'time') {
    defaultDose.kind = 'time';
    defaultDose.seconds = defaultDose.seconds ?? 20;
    delete defaultDose.reps;
  }

  return {
    ...base,
    slug: `${base.slug}-${tempoKind}`,
    name: `${base.name} (${rule.label})`,
    qualities,
    defaultDose,
    baseSlug: base.slug,
    variant: { axis: 'tempo', tempo: tempoKind },
    cues: [...base.cues, rule.cue],
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// Drill constraint variations (drills only)
// ═══════════════════════════════════════════════════════════════════════════

/** §7: opposed/unopposed, static/moving, one touch/two touch. */
export const CONSTRAINT_AXES = {
  opposition: ['unopposed', 'opposed'],
  movement: ['static', 'moving'],
  touches: ['one-touch', 'two-touch'],
};

const CONSTRAINT_RULES = {
  opposed: { qualityBoost: { 'anaerobic-capacity': 0.15, 'reactive-strength': 0.1 }, cue: 'Add a live defender at match intensity.', restMultiplier: 1.3 },
  unopposed: { qualityBoost: {}, cue: null, restMultiplier: 1 },
  moving: { qualityBoost: { 'change-of-direction': 0.15 }, cue: 'Perform the pattern while moving through the space rather than from a static start.', restMultiplier: 1.1 },
  static: { qualityBoost: {}, cue: null, restMultiplier: 1 },
  'one-touch': { qualityBoost: { 'reactive-strength': 0.1 }, cue: 'Play every ball first time — no controlling touch.', restMultiplier: 1 },
  'two-touch': { qualityBoost: {}, cue: null, restMultiplier: 1 },
};

/**
 * Constraint values are named per axis (e.g. { opposition: 'opposed' }); only
 * axes the base drill declares as `constraintAxes` are eligible, and only a
 * non-default value produces a derived item — the default values above (the
 * ones with no cue) describe the base drill itself, not a new item.
 */
export function expandConstraint(base, axisValues) {
  if (base.kind !== 'drill' || !base.constraintAxes) return null;

  // A value "applies" only when it is the non-default half of its axis (the
  // one with a cue — see CONSTRAINT_RULES). A combo of nothing but defaults
  // (e.g. { opposition: 'unopposed', movement: 'static' }) describes the base
  // drill itself, not a new item, so it must not register as applied.
  const applied = [];
  const qualities = { ...base.qualities };
  let restMultiplier = 1;
  const cues = [...base.cues];
  const nameParts = [];

  for (const axis of base.constraintAxes) {
    const value = axisValues[axis];
    if (!value) continue;
    const rule = CONSTRAINT_RULES[value];
    if (!rule) throw new Error(`unknown constraint value ${JSON.stringify(value)} for axis ${axis}`);
    if (!rule.cue) continue; // the default value for this axis — no-op
    applied.push(value);
    for (const [q, boost] of Object.entries(rule.qualityBoost)) {
      qualities[q] = round2(clampWeight((qualities[q] ?? 0.3) + boost));
    }
    restMultiplier *= rule.restMultiplier;
    cues.push(rule.cue);
    nameParts.push(value);
  }

  if (applied.length === 0) return null; // every axis was left at its default

  return {
    ...base,
    slug: `${base.slug}-${applied.join('-')}`,
    name: `${base.name} (${nameParts.join(', ')})`,
    qualities,
    restSeconds: Math.round(base.restSeconds * restMultiplier),
    cues,
    baseSlug: base.slug,
    variant: { axis: 'constraint', values: axisValues },
  };
}

/** Every non-trivial combination of a drill's declared constraint axes. */
export function expandAllConstraints(base) {
  if (base.kind !== 'drill' || !base.constraintAxes) return [];
  const axes = base.constraintAxes;
  const valueLists = axes.map((a) => CONSTRAINT_AXES[a]);

  const combos = [{}];
  for (let i = 0; i < axes.length; i += 1) {
    const axis = axes[i];
    const values = valueLists[i];
    const next = [];
    for (const combo of combos) {
      for (const v of values) next.push({ ...combo, [axis]: v });
    }
    combos.length = 0;
    combos.push(...next);
  }

  return combos
    .map((combo) => expandConstraint(base, combo))
    .filter((item) => item !== null);
}

// ═══════════════════════════════════════════════════════════════════════════
// Top-level: every derived item from one base item
// ═══════════════════════════════════════════════════════════════════════════

export function expandItem(base) {
  const derived = [];
  derived.push(...expandEquipmentChain(base));
  const uni = expandUnilateral(base);
  if (uni) derived.push(uni);
  if (base.tempoEligible) {
    for (const t of TEMPO_KINDS) derived.push(expandTempo(base, t));
  }
  derived.push(...expandAllConstraints(base));
  return derived;
}

export function expandCatalogue(baseItems) {
  const all = [...baseItems];
  for (const base of baseItems) all.push(...expandItem(base));
  return all;
}
