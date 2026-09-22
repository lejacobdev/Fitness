/**
 * Pure geometry for turning a rig segment + placement descriptor into a
 * polygon, and a polygon into an SVG path string. Every region is a
 * straight-edged polygon — no arcs — matching §9's "clean uniform-stroke line
 * art" and keeping the generator free of curve-fitting math.
 */

import { REST_POINTS, SEGMENTS, mirrorX } from './rig.js';

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function point(p) {
  return { x: p.x, y: p.y };
}

/**
 * A sub-rectangle of a line segment: `t0`/`t1` run 0-1 along the segment's
 * length, `xInsetFrac` positions the patch across the segment's width (0 =
 * centreline, 1 = the far edge, negative biases toward the opposite edge),
 * `widthFrac` is the patch's own width relative to the segment's half-width.
 */
export function lineSegmentPatch(segmentId, { t0, t1, xInsetFrac, widthFrac }) {
  const seg = SEGMENTS[segmentId];
  if (!seg || seg.kind !== 'line') throw new Error(`${segmentId} is not a line segment`);
  const a = REST_POINTS[seg.a];
  const b = REST_POINTS[seg.b];

  // The segment runs roughly along y; "width" runs along x. This is true for
  // every segment in this rig (a standing figure), so a fixed x-perpendicular
  // is enough rather than a general perpendicular-to-direction calculation.
  const yTop = lerp(a.y, b.y, t0);
  const yBottom = lerp(a.y, b.y, t1);
  const xAtTop = lerp(a.x, b.x, t0);
  const xAtBottom = lerp(a.x, b.x, t1);

  const halfW = seg.halfWidth * widthFrac;
  const centreOffset = seg.halfWidth * xInsetFrac;

  const xInner = (xAt) => xAt + centreOffset - halfW;
  const xOuter = (xAt) => xAt + centreOffset + halfW;

  return [
    point({ x: xInner(xAtTop), y: yTop }),
    point({ x: xOuter(xAtTop), y: yTop }),
    point({ x: xOuter(xAtBottom), y: yBottom }),
    point({ x: xInner(xAtBottom), y: yBottom }),
  ];
}

/**
 * A small polygon approximating a circle/ellipse on a point segment, offset
 * from its centre by a fraction of its own radius — used for the shoulder and
 * hip caps, where several muscles cluster around one joint.
 */
export function pointSegmentPatch(segmentId, { dxFrac = 0, dyFrac = 0, radiusFrac = 1, sides = 10 }) {
  const seg = SEGMENTS[segmentId];
  if (!seg || seg.kind !== 'point') throw new Error(`${segmentId} is not a point segment`);
  const c = REST_POINTS[seg.center];
  const cx = c.x + seg.radius * dxFrac;
  const cy = c.y + seg.radius * dyFrac;
  const r = seg.radius * radiusFrac;

  const points = [];
  for (let i = 0; i < sides; i += 1) {
    const angle = (i / sides) * Math.PI * 2;
    points.push(point({ x: cx + r * Math.cos(angle), y: cy + r * Math.sin(angle) }));
  }
  return points;
}

/** Resolve a muscle's region descriptor (rig.js placement data) to a polygon. */
export function regionPolygon(placement) {
  const seg = SEGMENTS[placement.segment];
  if (!seg) throw new Error(`unknown segment ${JSON.stringify(placement.segment)}`);
  return seg.kind === 'line' ? lineSegmentPatch(placement.segment, placement)
    : pointSegmentPatch(placement.segment, placement);
}

export function mirrorPolygon(points) {
  return points.map((p) => ({ x: mirrorX(p.x), y: p.y }));
}

function round(n) {
  return Math.round(n * 100) / 100;
}

export function polygonToSvgPath(points) {
  if (points.length < 3) throw new Error('a region needs at least 3 points');
  const [first, ...rest] = points;
  const commands = [`M${round(first.x)},${round(first.y)}`];
  for (const p of rest) commands.push(`L${round(p.x)},${round(p.y)}`);
  commands.push('Z');
  return commands.join(' ');
}

/** Signed area via the shoelace formula — used to reject degenerate regions. */
export function polygonArea(points) {
  let sum = 0;
  for (let i = 0; i < points.length; i += 1) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return Math.abs(sum) / 2;
}
