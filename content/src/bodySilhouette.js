/**
 * The continuous base figure drawn behind the coloured muscle patches. A
 * muscle map that is only floating colour patches on a blank background
 * reads as disconnected shapes rather than a body; this gives the app a
 * skin-tone silhouette to render first, so every patch sits ON a person
 * instead of hanging in empty space next to their neighbours.
 *
 * Built from the same rig segments the muscle regions attach to, each drawn
 * as its own soft rounded shape at FULL width — deliberately not unioned
 * into one outline path (that needs real polygon boolean ops, which is a lot
 * of geometry code for a schematic figure that only needs to look coherent,
 * not survive a hit-test). Segments are sized to overlap generously at every
 * joint, and every shape shares one fill, so the seams do not show.
 */

import { REST_POINTS, SEGMENTS } from './rig.js';
import {
  lineSegmentOutline, mirrorPolygon, pointSegmentOutline, roundedPolygonToSvgPath,
} from './geometry.js';

/** Which segments are visible from which view — both, unless stated. */
const SEGMENT_VIEWS = {
  head: ['front', 'back'],
  neck: ['front', 'back'],
  'trunk-upper': ['front', 'back'],
  'trunk-lower': ['front', 'back'],
  shoulderCap: ['front', 'back'],
  upperArm: ['front', 'back'],
  forearm: ['front', 'back'],
  hipCap: ['front', 'back'],
  thigh: ['front', 'back'],
  shin: ['front', 'back'],
  foot: ['front'], // the foot silhouette in this rig only reads front-on
};

/** A generous corner rounding so segments read as soft capsules, not boxes. */
const SILHOUETTE_CORNER_FRAC = 0.42;

export function buildBodySilhouettePaths() {
  const paths = { front: [], back: [] };

  for (const [segmentId, seg] of Object.entries(SEGMENTS)) {
    const views = SEGMENT_VIEWS[segmentId] ?? ['front', 'back'];
    const outline = seg.kind === 'line' ? lineSegmentOutline(segmentId) : pointSegmentOutline(segmentId);
    const rightPath = roundedPolygonToSvgPath(outline, seg.kind === 'point' ? 0.5 : SILHOUETTE_CORNER_FRAC);
    const leftPath = roundedPolygonToSvgPath(mirrorPolygon(outline), seg.kind === 'point' ? 0.5 : SILHOUETTE_CORNER_FRAC);

    for (const view of views) {
      paths[view].push({ segment: segmentId, side: 'right', d: rightPath });
      paths[view].push({ segment: segmentId, side: 'left', d: leftPath });
    }
  }

  return paths;
}

/** Every REST_POINTS key any segment references — used to sanity-check the rig. */
export function referencedRestPoints() {
  const names = new Set();
  for (const seg of Object.values(SEGMENTS)) {
    if (seg.kind === 'line') { names.add(seg.a); names.add(seg.b); } else { names.add(seg.center); }
  }
  return [...names].filter((n) => n in REST_POINTS);
}
