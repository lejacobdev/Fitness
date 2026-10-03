// Dev-only: review sheets. One PNG per N patterns (keyframe filmstrips, wrapped) plus a
// text file with what each pattern is supposed to show (item names, equipment, steps).
//   node --max-old-space-size=6000 tools/sheets.mjs outDir [perSheet=6] [filterRegex] [only=exercise|drill]
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import { BASE_ITEMS, CATALOGUE } from '../src/catalogue.js';
import { POSE_ASSIGNMENTS } from '../src/poseAssignments/index.js';
import { POSE_PATTERNS } from '../src/poses.js';
import { cycleSeconds, frameAtTime, placeFixture, placeKeyframes } from '../src/rig3d.js';
import { sceneShapes as figureShapes } from '../src/rigDraw.js';

const outDir = process.argv[2];
const per = Number(process.argv[3] ?? 6);
const re = process.argv[4] && process.argv[4] !== '-' ? new RegExp(process.argv[4]) : null;
const kindOnly = process.argv[5] ?? null;
fs.mkdirSync(outDir, { recursive: true });
const BY = new Map(POSE_PATTERNS.map((p) => [p.slug, p]));
const patternOf = (i) => POSE_ASSIGNMENTS[i.slug] ?? i.startPose;
const users = new Map();
for (const i of CATALOGUE) {
  if (kindOnly && i.kind !== kindOnly) continue;
  const s = patternOf(i);
  if (!BY.has(s)) continue;
  users.set(s, [...(users.get(s) ?? []), i]);
}
let slugs = [...users.keys()];
if (re) slugs = slugs.filter((s) => re.test(s) || users.get(s).some((i) => re.test(i.slug)));

function timeOfKeyframe(p, i) {
  let at = 0;
  const moves = p.loop ? p.keyframes.length : p.keyframes.length - 1;
  for (let k = 0; k < i; k++) at += (p.keyframes[k].hold ?? 0) + (k < moves ? p.keyframes[k].move ?? 0.6 : 0);
  return (at + 1e-6) / cycleSeconds(p);
}
const cellW = 170, cellH = 190, MAXC = 8;
const esc = (t) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;');
for (let s0 = 0; s0 < slugs.length; s0 += per) {
  const group = slugs.slice(s0, s0 + per);
  let body = '', y = 0, caption = '';
  group.forEach((slug) => {
    const p = BY.get(slug);
    const placed = placeKeyframes(p);
    const place = placeFixture(p, placed);
    const frames = p.keyframes.map((_, i) => frameAtTime(p, timeOfKeyframe(p, i) * cycleSeconds(p), placed));
    const shapesOf = (s) => figureShapes(s, { scheme: 'light', implement: p.implement, fixture: p.fixture, fixturePlace: place, glow: p.previewGlow ?? {}, ball: p.ball, prosthetic: p.prosthetic, wear: p.wear });
    const all = frames.flatMap((s) => shapesOf(s).filter((sh) => sh.depth > -1e5 && !sh.isBall).flatMap((sh) => sh.points));
    const xs = all.map((q) => q[0]), ys = all.map((q) => q[1]);
    const minX = Math.min(...xs) - 4, maxX = Math.max(...xs) + 4, minY = Math.min(...ys) - 4, maxY = Math.max(4, Math.max(...ys)) + 4;
    const k = Math.min((cellW - 8) / (maxX - minX), (cellH - 26) / (maxY - minY));
    const rows = Math.ceil(frames.length / MAXC);
    frames.forEach((s, f) => {
      const col = f % MAXC, row = Math.floor(f / MAXC);
      const x0 = col * cellW, y0 = y + row * cellH;
      body += `<rect x="${x0 + 1}" y="${y0 + 1}" width="${cellW - 2}" height="${cellH - 2}" rx="8" fill="#f4f4f6"/>`;
      const tx = x0 + 4 - minX * k + ((cellW - 8) - (maxX - minX) * k) / 2, ty = y0 + 22 - minY * k;
      const clip = `c${y}_${f}`;
      body += `<clipPath id="${clip}"><rect x="${x0 + 1}" y="${y0 + 1}" width="${cellW - 2}" height="${cellH - 2}" rx="8"/></clipPath><g clip-path="url(#${clip})"><g transform="translate(${tx},${ty}) scale(${k})">`;
      for (const sh of shapesOf(s)) {
        if (sh.points.length < 2) continue;
        const d = `M${sh.points.map((q) => `${q[0].toFixed(2)},${q[1].toFixed(2)}`).join(' L')} Z`;
        body += `<path d="${d}" fill="${sh.fill === 'none' ? 'none' : sh.fill}"${sh.opacity != null ? ` fill-opacity="${sh.opacity.toFixed(2)}"` : ''}${sh.stroke ? ` stroke="${sh.stroke}" stroke-width="${sh.width ?? 1}"` : ''}/>`;
      }
      const g = p.path?.grade ?? 0;
      if (p.fixture?.kind !== 'water') body += `<line x1="${minX}" y1="${-minX * g}" x2="${maxX}" y2="${-maxX * g}" stroke="#c9c9d0" stroke-width="${1.2 / k}"/>`;
      body += `</g></g><text x="${x0 + cellW - 8}" y="${y0 + 13}" text-anchor="end" font-family="Helvetica" font-size="10" fill="#999">${f + 1}</text>`;
      if (f === 0) body += `<text x="${x0 + 6}" y="${y0 + 13}" font-family="Helvetica" font-size="11" font-weight="700" fill="#222">${esc(slug)}</text>`;
    });
    y += rows * cellH;
    const items = users.get(slug);
    const base = items.find((i) => !i.baseSlug) ?? items[0];
    caption += `\n## ${slug}  [${p.keyframes.length} kf, ${p.loop ? 'loop' : 'rep'}${p.fixture ? ', fx ' + p.fixture.kind : ''}${p.implement ? ', imp ' + p.implement.kind : ''}${p.cast?.length ? ', cast ' + p.cast.length : ''}]\n`;
    caption += `items: ${items.slice(0, 6).map((i) => i.name).join(' | ')}${items.length > 6 ? ` (+${items.length - 6})` : ''}\n`;
    caption += `equip: ${(base.equipment ?? []).join(',')}\n`;
    caption += `setup: ${(base.setup ?? []).join(' ')}\nsteps: ${(base.execution ?? []).join(' ')}\n`;
  });
  const n = String(s0 / per).padStart(3, '0');
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${MAXC * cellW}" height="${y}"><rect width="100%" height="100%" fill="#fff"/>${body}</svg>`;
  fs.writeFileSync(`${outDir}/${n}.svg`, svg);
  execFileSync('rsvg-convert', ['-w', String(Math.min(MAXC * cellW, 1400)), '-o', `${outDir}/${n}.png`, `${outDir}/${n}.svg`]);
  fs.unlinkSync(`${outDir}/${n}.svg`);
  fs.writeFileSync(`${outDir}/${n}.txt`, caption);
}
console.log(`${slugs.length} patterns -> ${Math.ceil(slugs.length / per)} sheets`);
