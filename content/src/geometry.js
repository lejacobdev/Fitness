/**
 * Pure geometry for turning a rig segment + placement descriptor into a
 * polygon, and a polygon into a smooth SVG path string.
 *
 * Every shape is still computed as a plain point polygon (easy to reason
 * about, easy to test, easy to mirror) — but serialization rounds every
 * corner with a quadratic Bézier curve instead of a sharp line join. A sharp
 * rectangle reads as a "box stuck on a robot"; the same rectangle with its
 * corners rounded off reads as a soft, organic patch of muscle. This is
 * still hand-rolled geometry — no SVG library, no imported art — just a
 * different, cheap curve instead of only straight edges (§9's "no SVG
 * library" is about not depending on a parsing/rendering library, not about
 * banning curves; a quadratic Bézier is a three-point primitive SwiftUI's
 * own `Path.addQuadCurve` draws natively).
 */

import { REST_POINTS, SEGMENTS, mirrorX, segmentHalfWidthAt } from './rig.js';

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

  // A tapered segment (different halfWidthA/B) is narrower at one end than
  // the other, so the patch's own width and inset are computed against the
  // segment's ACTUAL width at that end, not one constant value — otherwise a
  // patch near the narrow end could poke outside the tapered silhouette.
  const widthAtTop = segmentHalfWidthAt(seg, t0);
  const widthAtBottom = segmentHalfWidthAt(seg, t1);

  const xInner = (xAt, w) => xAt + w * xInsetFrac - w * widthFrac;
  const xOuter = (xAt, w) => xAt + w * xInsetFrac + w * widthFrac;

  return [
    point({ x: xInner(xAtTop, widthAtTop), y: yTop }),
    point({ x: xOuter(xAtTop, widthAtTop), y: yTop }),
    point({ x: xOuter(xAtBottom, widthAtBottom), y: yBottom }),
    point({ x: xInner(xAtBottom, widthAtBottom), y: yBottom }),
  ];
}

/**
 * The full outline of a line segment (its whole half-width, t0=0..t1=1) —
 * used for the continuous body silhouette rather than a muscle sub-patch.
 */
export function lineSegmentOutline(segmentId, { t0 = 0, t1 = 1 } = {}) {
  return lineSegmentPatch(segmentId, { t0, t1, xInsetFrac: 0, widthFrac: 1 });
}

/**
 * A small polygon approximating a circle/ellipse on a point segment, offset
 * from its centre by a fraction of its own radius — used for the shoulder and
 * hip caps, where several muscles cluster around one joint.
 */
export function pointSegmentPatch(segmentId, { dxFrac = 0, dyFrac = 0, radiusFrac = 1, sides = 12 }) {
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

/** The full circular outline of a point segment — for the body silhouette. */
export function pointSegmentOutline(segmentId, sides = 16) {
  return pointSegmentPatch(segmentId, { radiusFrac: 1, sides });
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

/** A sharp-cornered polygon path — kept for shapes that should stay crisp. */
export function polygonToSvgPath(points) {
  if (points.length < 3) throw new Error('a region needs at least 3 points');
  const [first, ...rest] = points;
  const commands = [`M${round(first.x)},${round(first.y)}`];
  for (const p of rest) commands.push(`L${round(p.x)},${round(p.y)}`);
  commands.push('Z');
  return commands.join(' ');
}

/**
 * The same polygon, corners rounded with a quadratic Bézier per vertex: each
 * corner is clipped back along both adjacent edges by `cornerFrac` of the
 * shorter edge's length, and the original vertex becomes the curve's control
 * point (`Q controlX,controlY endX,endY`) — the standard "rounded polygon"
 * construction. `cornerFrac` near 0.5 (the max before edges start crossing)
 * reads as a soft capsule; near 0.15 reads as a rectangle with just the
 * corners eased off.
 */
export function roundedPolygonToSvgPath(points, cornerFrac = 0.32) {
  if (points.length < 3) throw new Error('a region needs at least 3 points');
  const n = points.length;
  const frac = Math.max(0, Math.min(0.5, cornerFrac));

  const clipped = points.map((cur, i) => {
    const prev = points[(i - 1 + n) % n];
    const next = points[(i + 1) % n];
    const toPrev = { x: prev.x - cur.x, y: prev.y - cur.y };
    const toNext = { x: next.x - cur.x, y: next.y - cur.y };
    const lenPrev = Math.hypot(toPrev.x, toPrev.y) || 1;
    const lenNext = Math.hypot(toNext.x, toNext.y) || 1;
    const r = Math.min(lenPrev, lenNext) * frac;
    return {
      control: cur,
      entry: { x: cur.x + (toPrev.x / lenPrev) * r, y: cur.y + (toPrev.y / lenPrev) * r },
      exit: { x: cur.x + (toNext.x / lenNext) * r, y: cur.y + (toNext.y / lenNext) * r },
    };
  });

  const commands = [`M${round(clipped[0].entry.x)},${round(clipped[0].entry.y)}`];
  for (let i = 0; i < n; i += 1) {
    const c = clipped[i];
    const nextEntry = clipped[(i + 1) % n].entry;
    commands.push(`Q${round(c.control.x)},${round(c.control.y)} ${round(c.exit.x)},${round(c.exit.y)}`);
    commands.push(`L${round(nextEntry.x)},${round(nextEntry.y)}`);
  }
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
