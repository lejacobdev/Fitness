/**
 * The single assembly point for the whole item catalogue — §7's "one library"
 * that every sport draws on (§6). Codegen, the pack builder and every test
 * that needs "the whole catalogue" import from here rather than reaching into
 * items/exercises.js or items/drills.js directly, so there is exactly one
 * place that combines base authoring with expansion.
 */

import { expandCatalogue } from './expand.js';
import { DRILLS } from './items/drills.js';
import { EXERCISES } from './items/exercises.js';

export const BASE_ITEMS = [...EXERCISES, ...DRILLS];

export const CATALOGUE = expandCatalogue(BASE_ITEMS);

const BY_SLUG = new Map(CATALOGUE.map((i) => [i.slug, i]));

export function itemBySlug(slug) {
  return BY_SLUG.get(slug);
}

export function hasItem(slug) {
  return BY_SLUG.has(slug);
}
