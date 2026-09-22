/**
 * Assembles the §9 muscle-map path data: one SVG path string per
 * (muscle, view, side) key, generated from rig.js's segments and
 * muscleRegions.js's placements — never traced or imported art.
 */

import { DRAWABLE_MUSCLES } from './muscles.js';
import { MUSCLE_REGIONS } from './muscleRegions.js';
import { mirrorPolygon, polygonArea, polygonToSvgPath, regionPolygon } from './geometry.js';

/** A minimum area (in the 100x200 canonical space) below which a region is degenerate. */
const MIN_REGION_AREA = 1;

export function buildMuscleMapPaths() {
  const paths = {};

  for (const muscle of DRAWABLE_MUSCLES) {
    const placements = MUSCLE_REGIONS[muscle.slug];
    if (!placements) throw new Error(`${muscle.slug} has no region placement in muscleRegions.js`);

    for (const view of muscle.views) {
      const placement = placements.find((p) => p.view === view);
      if (!placement) {
        throw new Error(`${muscle.slug} declares view ${view} in muscles.js but has no ${view} placement`);
      }

      const rightPolygon = regionPolygon(placement);
      const area = polygonArea(rightPolygon);
      if (area < MIN_REGION_AREA) {
        throw new Error(`${muscle.slug}.${view}.right region is degenerate (area ${area})`);
      }
      paths[`${muscle.slug}.${view}.right`] = polygonToSvgPath(rightPolygon);

      const leftPolygon = mirrorPolygon(rightPolygon);
      paths[`${muscle.slug}.${view}.left`] = polygonToSvgPath(leftPolygon);
    }

    // Every placement entry must be used by a view muscles.js actually declares
    // — an orphaned placement is a stale row nobody is drawing.
    for (const p of placements) {
      if (!muscle.views.includes(p.view)) {
        throw new Error(`${muscle.slug} has a ${p.view} placement but muscles.js does not list that view`);
      }
    }
  }

  return paths;
}
