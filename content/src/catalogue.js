/**
 * The single assembly point for the whole item catalogue — §7's "one library"
 * that every sport draws on (§6). Codegen, the pack builder and every test
 * that needs "the whole catalogue" import from here rather than reaching into
 * items/exercises.js or items/drills.js directly, so there is exactly one
 * place that combines base authoring with expansion.
 */

import { expandCatalogue } from './expand.js';
import { DRILLS } from './items/drills.js';
import { SPORT_DRILLS } from './items/drills/index.js';
import { EXERCISES } from './items/exercises.js';
import { EXTRA_EXERCISES } from './items/exercisesExtra.js';
import { POSE_ASSIGNMENTS } from './poseAssignments/index.js';
import { isPosePattern } from './poses.js';

/**
 * Interim: items whose sport hasn't been given its own patterns yet show the
 * closest general movement, chosen from the movement class they were first
 * authored with. Every item therefore always names one real pattern.
 */
const INTERIM_BY_PAIR = {
  'sprint-cycle→vertical-jump': 'approach-jump', 'vertical-jump→overhead-throw': 'approach-jump', 'vertical-jump→landing': 'vertical-jump',
  'landing→vertical-jump': 'depth-jump', 'swing-stride→overhead-throw': 'overhead-throw-medball', 'sprint-cycle→overhead-throw': 'overhead-throw-medball',
  'lateral-bound→landing': 'skater-bound', 'broad-jump→landing': 'broad-jump', 'horizontal-push→sprint-cycle': 'mountain-climber',
  'squat→horizontal-pull': 'rowing-erg', 'vertical-pull→overhead-throw': 'swim-freestyle', 'hinge→isometric-hold': 'glute-bridge',
};
const INTERIM_BY_POSE = {
  squat: 'squat-bodyweight', hinge: 'rdl', lunge: 'reverse-lunge', 'split-squat': 'split-squat', 'single-leg-rdl': 'single-leg-rdl',
  'horizontal-push': 'push-up', 'horizontal-pull': 'seated-cable-row', 'vertical-push': 'overhead-press', 'vertical-pull': 'pull-up',
  'anti-rotation-press': 'pallof-press', 'trunk-flexion': 'sit-up', 'trunk-rotation': 'woodchop', carry: 'farmers-carry', pogo: 'pogo',
  'vertical-jump': 'vertical-jump', 'broad-jump': 'broad-jump', bound: 'bound', 'lateral-bound': 'skater-bound', 'sprint-start': 'acceleration-start',
  'sprint-cycle': 'sprint', 'deceleration-plant': 'deceleration-stop', cut: 'cut-45', 'lateral-shuffle': 'lateral-shuffle',
  'crossover-stride': 'crossover-run', 'single-leg-balance': 'single-leg-balance', landing: 'drop-landing', 'overhead-throw': 'overhead-throw-medball',
  'rotational-throw': 'rotational-throw', 'instep-strike': 'soccer-instep-kick', 'skating-stride': 'hockey-skating-stride',
  'swing-stride': 'rotational-throw', 'isometric-hold': 'athletic-stance-hold', 'mobility-flow': 'worlds-greatest-stretch',
};
export const interimPose = (item) => INTERIM_BY_PAIR[`${item.startPose}→${item.endPose}`] ?? INTERIM_BY_POSE[item.startPose];

/** Each item shows exactly one movement pattern (poseAssignments/, else interim). */
const withPose = (item) => {
  const pattern = POSE_ASSIGNMENTS[item.slug] ?? interimPose(item);
  if (!pattern) return item;
  const out = { ...item, startPose: pattern, endPose: pattern };
  // A single-side variant keeps its own pattern when that pattern exists
  // (a single-leg RDL); otherwise it shows the same movement as the base.
  if (item.unilateralPosePattern) {
    const uni = { carry: 'suitcase-carry', 'horizontal-push': 'dumbbell-bench-press' }[item.unilateralPosePattern] ?? item.unilateralPosePattern;
    out.unilateralPosePattern = isPosePattern(uni) ? uni : pattern;
  }
  return out;
};

export const RAW_BASE_ITEMS = [...EXERCISES, ...EXTRA_EXERCISES, ...DRILLS, ...SPORT_DRILLS];
export const BASE_ITEMS = RAW_BASE_ITEMS.map(withPose);

export const CATALOGUE = expandCatalogue(BASE_ITEMS);

const BY_SLUG = new Map(CATALOGUE.map((i) => [i.slug, i]));

export function itemBySlug(slug) {
  return BY_SLUG.get(slug);
}

export function hasItem(slug) {
  return BY_SLUG.has(slug);
}
