// Dev-only: renders pose patterns as filmstrips (SVG → PNG with rsvg-convert)
// using exactly the rig maths and shapes the app uses.
//   node tools/renderRig.mjs out.png [slug,slug,...] [frames=6] [scheme=light]
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import { POSE_PATTERNS } from '../src/poses.js';
import { cycleSeconds, frameAt, frameAtTime, keyframeAt, pathSeconds, placeFixture, placeKeyframes, timing } from '../src/rig3d.js';

/** Cycle position of the start of keyframe i's hold (so KEYFRAMES=1 shows the ball too). */
function timeOfKeyframe(p, i) {
  let at = 0;
  const moves = p.loop ? p.keyframes.length : p.keyframes.length - 1;
  for (let k = 0; k < i; k++) at += (p.keyframes[k].hold ?? 0) + (k < moves ? p.keyframes[k].move ?? 0.6 : 0);
  return (at + 1e-6) / cycleSeconds(p);
}
import { sceneShapes as figureShapes } from '../src/rigDraw.js';

const out = process.argv[2] ?? '/tmp/rig.png';
const only = process.argv[3] && process.argv[3] !== 'all' ? process.argv[3].split(',') : null;
const n = Number(process.argv[4] ?? 6);
const scheme = process.argv[5] ?? 'light';
const keyframesOnly = process.env.KEYFRAMES === '1';
const patterns = POSE_PATTERNS.filter((p) => !only || only.includes(p.slug));

const cellW = 150, cellH = 170;
let body = '';
let cols = 0;
patterns.forEach((p, row) => {
  const placed = placeKeyframes(p);
  const place = placeFixture(p, placed);
  const frames = keyframesOnly
    ? p.keyframes.map((_, i) => frameAtTime(p, timeOfKeyframe(p, i) * cycleSeconds(p), placed))
    : Array.from({ length: n }, (_, i) => frameAtTime(p, (i / n) * pathSeconds(p, placed), placed));
  cols = Math.max(cols, frames.length);
  // One camera box for the whole strip (like the app's fixed frame).
  const all = frames.flatMap((s) => figureShapes(s, { scheme, implement: p.implement, fixture: p.fixture, fixturePlace: place, ball: p.ball, prosthetic: p.prosthetic }).filter((sh) => sh.depth > -1e5 && !sh.isBall).flatMap((sh) => sh.points));
  const xs = all.map((q) => q[0]), ys = all.map((q) => q[1]);
  const minX = Math.min(...xs) - 4, maxX = Math.max(...xs) + 4, minY = Math.min(...ys) - 4, maxY = Math.max(4, Math.max(...ys)) + 4;
  const k = Math.min((cellW - 8) / (maxX - minX), (cellH - 26) / (maxY - minY));
  frames.forEach((s, col) => {
    const x0 = col * cellW, y0 = row * cellH;
    body += `<rect x="${x0 + 1}" y="${y0 + 1}" width="${cellW - 2}" height="${cellH - 2}" rx="8" fill="${scheme === 'light' ? '#f4f4f6' : '#111'}"/>`;
    const tx = x0 + 4 - minX * k + ((cellW - 8) - (maxX - minX) * k) / 2;
    const ty = y0 + 20 - minY * k;
    body += `<g transform="translate(${tx},${ty}) scale(${k})">`;
    for (const sh of figureShapes(s, { scheme, implement: p.implement, fixture: p.fixture, fixturePlace: place, glow: p.previewGlow ?? {}, ball: p.ball, prosthetic: p.prosthetic })) {
      if (sh.points.length < 2) continue;
      const d = `M${sh.points.map((q) => `${q[0].toFixed(2)},${q[1].toFixed(2)}`).join(' L')} Z`;
      const fill = sh.fill === 'none' ? 'none' : sh.fill;
      body += `<path d="${d}" fill="${fill}"${sh.opacity != null ? ` fill-opacity="${sh.opacity.toFixed(2)}"` : ''}${sh.stroke ? ` stroke="${sh.stroke}" stroke-width="${sh.width ?? 1}"` : ''}/>`;
    }
    const g = p.path?.grade ?? 0;
    body += `<line x1="${minX}" x2="${maxX}" y1="${-minX * g}" y2="${-maxX * g}" stroke="#c9c9d0" stroke-width="${0.6 / k * 2}"/>`;
    body += '</g>';
    if (col === 0) body += `<text x="${x0 + 6}" y="${y0 + 13}" font-family="Helvetica" font-size="10" fill="#555">${p.slug}</text>`;
  });
});
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${cols * cellW}" height="${patterns.length * cellH}"><rect width="100%" height="100%" fill="#fff"/>${body}</svg>`;
fs.writeFileSync(out.replace(/\.png$/, '.svg'), svg);
execFileSync('rsvg-convert', ['-o', out, out.replace(/\.png$/, '.svg')]);
console.log(`wrote ${out} (${patterns.length} patterns)`);
