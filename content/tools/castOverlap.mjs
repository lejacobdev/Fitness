// Dev-only: finds drills where a partner's torso passes through the athlete's.
//   node --max-old-space-size=6000 tools/castOverlap.mjs [threshold] [slug,…]
import { POSE_PATTERNS } from '../src/poses.js';
import { applyOverrides } from './_override.mjs';
import { frameAtTime, pathSeconds, placeKeyframes } from '../src/rig3d.js';

applyOverrides(POSE_PATTERNS);
const limit = Number(process.argv[2] ?? 12);
const only = process.argv[3] ? new Set(process.argv[3].split(',')) : null;
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
function segDist(p1, q1, p2, q2) {
  const d1 = sub(q1, p1), d2 = sub(q2, p2), r = sub(p1, p2);
  const a = dot(d1, d1), e = dot(d2, d2), f = dot(d2, r);
  const c = dot(d1, r), b = dot(d1, d2), den = a * e - b * b;
  const cl = (x) => Math.max(0, Math.min(1, x));
  let s = den > 1e-9 ? cl((b * f - c * e) / den) : 0;
  let t = (b * s + f) / e;
  if (t < 0) { t = 0; s = cl(-c / a); } else if (t > 1) { t = 1; s = cl((b - c) / a); }
  const c1 = [p1[0] + d1[0] * s, p1[1] + d1[1] * s, p1[2] + d1[2] * s];
  const c2 = [p2[0] + d2[0] * t, p2[1] + d2[1] * t, p2[2] + d2[2] * t];
  return Math.hypot(...sub(c1, c2));
}
const spine = (s) => [s.pelvis, s.head];
const flat = (v) => [v[0], v[1] * Math.cos(0.35), 0];
const rows = [];
for (const p of POSE_PATTERNS) {
  if (!p.cast?.length || (only && !only.has(p.slug))) continue;
  const placed = placeKeyframes(p);
  const cyc = pathSeconds(p, placed);
  let best = Infinity, at = 0, merged = 0, frames = 0;
  for (let q = 0; q < 80; q++) {
    const s = frameAtTime(p, (q / 80) * cyc, placed);
    for (const m of s.cast ?? []) {
      if (!m?.s) continue;
      const d = segDist(...spine(s), ...spine(m.s));
      if (d < best) { best = d; at = q / 80; }
      frames++;
      if (segDist(...spine(s).map(flat), ...spine(m.s).map(flat)) < 9) merged++;
    }
  }
  if (best < limit || merged / Math.max(frames, 1) > 0.2) rows.push([best, p.slug, at, merged / Math.max(frames, 1)]);
}
rows.sort((a, b) => a[0] - b[0]);
for (const [d, slug, at, m] of rows) console.log(`${d.toFixed(1).padStart(5)} | ${slug} | t=${at.toFixed(2)} | screen-merged ${(m * 100).toFixed(0)}%`);
console.log(rows.length, 'patterns under', limit);
