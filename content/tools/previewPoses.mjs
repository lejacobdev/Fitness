// Dev-only: contact sheet of every pose pattern at t = 0, 0.5, 1.
import fs from 'node:fs';
import { POSE_PATTERNS } from '../src/poses.js';
import { bounds, lerpPose, renderFigure, skeleton } from './rigModel.mjs';

const out = process.argv[2] ?? '/tmp/poses.svg';
const only = process.argv[3] ? process.argv[3].split(',') : null;
const patterns = POSE_PATTERNS.filter((p) => !only || only.includes(p.slug));
const cellW = 130, cellH = 120, cols = 3;
let body = '';
patterns.forEach((p, row) => {
  const frames = [0, 0.5, 1].map((t) => skeleton(lerpPose(p.start, p.end, t)));
  const b = frames.map(bounds).reduce((a, c) => ({ minX: Math.min(a.minX, c.minX), maxX: Math.max(a.maxX, c.maxX), minY: Math.min(a.minY, c.minY), maxY: Math.max(a.maxY, c.maxY) }));
  const scale = Math.min((cellW - 10) / (b.maxX - b.minX), (cellH - 22) / (b.maxY - b.minY));
  frames.forEach((s, col) => {
    const x0 = col * cellW, y0 = row * cellH;
    const tx = x0 + 5 - b.minX * scale + ((cellW - 10) - (b.maxX - b.minX) * scale) / 2;
    const ty = y0 + 16 - b.minY * scale;
    body += `<rect x="${x0 + 1}" y="${y0 + 1}" width="${cellW - 2}" height="${cellH - 2}" rx="8" fill="#f4f4f6"/>`;
    body += `<line x1="${x0 + 6}" x2="${x0 + cellW - 6}" y1="${ty}" y2="${ty}" stroke="#d0d0d6" stroke-width="1"/>`;
    body += `<g transform="translate(${tx},${ty}) scale(${scale})">${renderFigure(s)}</g>`;
    if (col === 0) body += `<text x="${x0 + 8}" y="${y0 + 13}" font-family="Helvetica" font-size="10" fill="#333">${p.slug}</text>`;
  });
});
fs.writeFileSync(out, `<svg xmlns="http://www.w3.org/2000/svg" width="${cols * cellW * 2}" height="${patterns.length * cellH * 2}" viewBox="0 0 ${cols * cellW} ${patterns.length * cellH}"><rect width="100%" height="100%" fill="#fff"/>${body}</svg>`);
