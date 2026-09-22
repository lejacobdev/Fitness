/**
 * The shape of a catalogue item, and the validator §7 requires to block the
 * build: "every item has at least one quality with weight ≥ 0.5, non-empty cues
 * and execution, a resolvable substitute list, a valid dose, and a pose pair."
 *
 * Validation is strict and total. A catalogue that half-validates is worse than
 * none, because the generator in §10 would silently skip the broken items and
 * quietly narrow every athlete's plan.
 */

import { isMuscle } from './muscles.js';
import { isProp } from './props.js';
import { isQuality } from './qualities.js';

export const ITEM_KINDS = ['exercise', 'drill'];

/** §7: field, court, ice, pool, gym, anywhere. */
export const SURFACES = ['field', 'court', 'ice', 'pool', 'gym', 'track', 'anywhere'];

/**
 * §7's youth gating is a field, not an afterthought. `COACHED` items are
 * excluded by §10's generator unless the athlete has confirmed in Settings that
 * they train under supervision, and are never prescribed to under-14s at all.
 */
export const SUPERVISION_LEVELS = ['SELF', 'COACHED'];

/**
 * Equipment levels exist so §21 can assert that every sport resolves to at least
 * 40 eligible items *at every level* — that an athlete with nothing but a field
 * and a ball still gets a complete session rather than an empty one.
 */
export const EQUIPMENT_LEVELS = ['none', 'minimal', 'full'];

/**
 * Every piece of equipment an item may require, and the lowest level at which it
 * is available. `level: 'none'` means the athlete needs nothing they would not
 * already have.
 */
export const EQUIPMENT = {
  // Nothing required
  none: 'none',
  wall: 'none',
  step: 'none',

  // Minimal: a ball, a band, cones, something to jump onto
  ball: 'minimal',
  'med-ball': 'minimal',
  band: 'minimal',
  'mini-band': 'minimal',
  cones: 'minimal',
  hurdle: 'minimal',
  box: 'minimal',
  bench: 'minimal',
  'jump-rope': 'minimal',
  'slider': 'minimal',
  'foam-roller': 'minimal',
  'pull-up-bar': 'minimal',
  /** Any low horizontal anchor — rack pins, a sturdy table, suspension straps. */
  'low-bar': 'minimal',
  'stick': 'minimal',
  'racket': 'minimal',
  'bat': 'minimal',
  'goal': 'minimal',
  'net': 'minimal',
  'puck': 'minimal',
  'skates': 'minimal',
  'blocks': 'minimal',
  'sled': 'minimal',
  'partner': 'minimal',

  // Full: a weight room
  barbell: 'full',
  dumbbell: 'full',
  kettlebell: 'full',
  'trap-bar': 'full',
  rack: 'full',
  'cable-machine': 'full',
  'lat-pulldown': 'full',
  'leg-curl-machine': 'full',
  'reverse-hyper': 'full',
  'landmine': 'full',
  'safety-squat-bar': 'full',
  'weight-plate': 'full',
  'bumper-plates': 'full',
};

export const DOSE_KINDS = ['reps', 'time', 'distance', 'contacts'];

/**
 * §7: plyometric volume is prescribed in ground contacts, not sets, with a
 * weekly ceiling. An item whose dose kind is `contacts` is a plyometric as far
 * as §10's volume cap is concerned — that is the only place the cap reads from,
 * so mis-tagging a dose is how a plyometric escapes the ceiling.
 */
export const PLYOMETRIC_DOSE_KIND = 'contacts';

export const MIN_QUALITY_WEIGHT = 0.05;
export const MAX_QUALITY_WEIGHT = 1.0;

function fail(errors, slug, message) {
  errors.push(`${slug}: ${message}`);
}

function checkWeightMap(errors, slug, field, map, isKnown, kind) {
  if (map === undefined || map === null) {
    fail(errors, slug, `${field} is missing`);
    return;
  }
  const entries = Object.entries(map);
  if (entries.length === 0) {
    fail(errors, slug, `${field} is empty`);
    return;
  }
  for (const [key, weight] of entries) {
    if (!isKnown(key)) fail(errors, slug, `${field} names unknown ${kind} ${JSON.stringify(key)}`);
    if (typeof weight !== 'number' || Number.isNaN(weight)) {
      fail(errors, slug, `${field}.${key} weight is not a number`);
    } else if (weight < MIN_QUALITY_WEIGHT || weight > MAX_QUALITY_WEIGHT) {
      fail(errors, slug, `${field}.${key} weight ${weight} is outside ${MIN_QUALITY_WEIGHT}–${MAX_QUALITY_WEIGHT}`);
    }
  }
}

function checkProse(errors, slug, field, value, { minEntries = 1, minLength = 12 } = {}) {
  if (!Array.isArray(value)) {
    fail(errors, slug, `${field} is not an array`);
    return;
  }
  if (value.length < minEntries) {
    fail(errors, slug, `${field} needs at least ${minEntries} entr${minEntries === 1 ? 'y' : 'ies'}`);
    return;
  }
  value.forEach((line, i) => {
    if (typeof line !== 'string' || line.trim().length < minLength) {
      fail(errors, slug, `${field}[${i}] is too short to be real coaching text`);
    }
  });
}

export function validateDose(errors, slug, dose) {
  if (!dose || typeof dose !== 'object') {
    fail(errors, slug, 'defaultDose is missing');
    return;
  }
  if (!DOSE_KINDS.includes(dose.kind)) {
    fail(errors, slug, `defaultDose.kind ${JSON.stringify(dose.kind)} is not one of ${DOSE_KINDS.join(', ')}`);
    return;
  }
  if (!Number.isInteger(dose.sets) || dose.sets < 1 || dose.sets > 10) {
    fail(errors, slug, `defaultDose.sets ${dose.sets} is not 1–10`);
  }
  const required = { reps: 'reps', time: 'seconds', distance: 'metres', contacts: 'contacts' }[dose.kind];
  const value = dose[required];
  if (!Number.isFinite(value) || value <= 0) {
    fail(errors, slug, `defaultDose.${required} is missing or not positive for kind ${dose.kind}`);
  }
  // §2 cites NSCA youth guidance: 1–3 sets of 6–15 reps, technique before load,
  // and no percentage-of-1RM prescriptions for under-18s. An authored dose
  // outside that envelope would have to be clamped by the generator on every
  // single call, so it is rejected here instead.
  if (dose.kind === 'reps' && (value < 1 || value > 30)) {
    fail(errors, slug, `defaultDose.reps ${value} is implausible`);
  }
  if (dose.kind === 'contacts' && value > 40) {
    fail(errors, slug, `defaultDose.contacts ${value} per set exceeds the youth plyometric envelope`);
  }
  if (dose.load !== undefined && typeof dose.load !== 'string') {
    fail(errors, slug, 'defaultDose.load must be a description like "bodyweight" or "moderate", never a percentage of 1RM');
  }
  if (typeof dose.load === 'string' && /%|1rm|one[- ]rep/i.test(dose.load)) {
    fail(errors, slug, `defaultDose.load ${JSON.stringify(dose.load)} reads as a percentage of 1RM, which §2 forbids for under-18s`);
  }
}

/**
 * Validate one item in isolation. Cross-item checks (substitutes resolving,
 * progressions existing, pose coverage) need the whole catalogue and live in
 * validateCatalogue.
 */
export function validateItem(item, errors = []) {
  const slug = item?.slug ?? '<no slug>';

  if (typeof item?.slug !== 'string' || !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(item.slug)) {
    fail(errors, slug, 'slug must be lower-kebab-case');
  }
  if (typeof item?.name !== 'string' || item.name.trim().length < 3) {
    fail(errors, slug, 'name is missing');
  }
  if (!ITEM_KINDS.includes(item?.kind)) {
    fail(errors, slug, `kind ${JSON.stringify(item?.kind)} is not exercise or drill`);
  }

  checkWeightMap(errors, slug, 'qualities', item?.qualities, isQuality, 'quality');
  checkWeightMap(errors, slug, 'muscles', item?.muscles, isMuscle, 'muscle');

  // §7: "every item has at least one quality with weight ≥ 0.5". An item that is
  // only ever a secondary contributor would never be selected by §10 and would
  // sit in the catalogue forever looking like content.
  const weights = Object.values(item?.qualities ?? {}).filter((w) => typeof w === 'number');
  if (weights.length && !weights.some((w) => w >= 0.5)) {
    fail(errors, slug, 'no quality reaches weight 0.5, so nothing would ever select this item');
  }

  if (!Array.isArray(item?.equipment) || item.equipment.length === 0) {
    fail(errors, slug, 'equipment is missing (use ["none"] for bodyweight)');
  } else {
    for (const e of item.equipment) {
      if (!(e in EQUIPMENT)) fail(errors, slug, `unknown equipment ${JSON.stringify(e)}`);
    }
  }

  if (!SURFACES.includes(item?.surface)) {
    fail(errors, slug, `surface ${JSON.stringify(item?.surface)} is not one of ${SURFACES.join(', ')}`);
  }

  if (!Number.isInteger(item?.minAge) || item.minAge < 13 || item.minAge > 18) {
    // §23: the minimum age of the app is 13, so a minAge below it is dead
    // config, and above 18 would be unreachable for the audience.
    fail(errors, slug, `minAge ${item?.minAge} must be 13–18`);
  }
  if (!SUPERVISION_LEVELS.includes(item?.supervisionLevel)) {
    fail(errors, slug, `supervisionLevel ${JSON.stringify(item?.supervisionLevel)} is not SELF or COACHED`);
  }

  checkProse(errors, slug, 'setup', item?.setup);
  checkProse(errors, slug, 'execution', item?.execution, { minEntries: 2 });
  checkProse(errors, slug, 'cues', item?.cues, { minEntries: 2, minLength: 6 });
  checkProse(errors, slug, 'mistakes', item?.mistakes, { minEntries: 1 });

  for (const field of ['progressions', 'regressions', 'substitutes']) {
    if (!Array.isArray(item?.[field])) fail(errors, slug, `${field} is not an array`);
  }

  validateDose(errors, slug, item?.defaultDose);

  if (!Number.isInteger(item?.restSeconds) || item.restSeconds < 0 || item.restSeconds > 600) {
    fail(errors, slug, `restSeconds ${item?.restSeconds} is not 0–600`);
  }

  // §9: every item needs a pose pair so the figure has something to animate.
  if (typeof item?.startPose !== 'string' || item.startPose.length === 0) {
    fail(errors, slug, 'startPose is missing');
  }
  if (typeof item?.endPose !== 'string' || item.endPose.length === 0) {
    fail(errors, slug, 'endPose is missing');
  }

  // §9: "sport drills get a prop layer" — a small named shape positioned
  // relative to a joint. Optional (a bodyweight exercise has nothing to hold),
  // but when present it must be one of the §9 prop shapes, not an equipment
  // slug — `equipment` gates what an athlete needs to perform the item;
  // `prop` says what the rig draws in its hand.
  if (item?.prop !== undefined && !isProp(item.prop)) {
    fail(errors, slug, `prop ${JSON.stringify(item.prop)} is not a known §9 prop`);
  }

  return errors;
}

/** The lowest equipment level at which this item can be performed. */
export function itemEquipmentLevel(item) {
  let level = 'none';
  for (const e of item.equipment) {
    const l = EQUIPMENT[e];
    if (l === 'full') return 'full';
    if (l === 'minimal') level = 'minimal';
  }
  return level;
}

/** Can this item be performed by an athlete who has `available` equipment? */
export function itemAvailableAt(item, level) {
  const need = itemEquipmentLevel(item);
  if (level === 'full') return true;
  if (level === 'minimal') return need !== 'full';
  return need === 'none';
}
