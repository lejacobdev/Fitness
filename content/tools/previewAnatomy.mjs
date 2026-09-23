// Dev-only: renders the anatomy mannequin to SVG (then PNG via rsvg-convert)
// in the same style MuscleMapView draws it, to judge shapes by eye.
import fs from 'node:fs';
import { buildAnatomy } from '../src/anatomy.js';

const out = process.argv[2] ?? '/tmp/anatomy.svg';
const highlight = JSON.parse(process.argv[3] ?? '{}');
const dark = process.argv[4] === 'dark';
const a = buildAnatomy();
const pal = dark
  ? { bg: '#1c1c1e', skin1: '#4a4a50', skin2: '#38383d', muscle: '#55555c', stroke: '#6b6b73', detail: '#6b6b73', muscle2: '#46464c' }
  : { bg: '#ffffff', skin1: '#ece6e0', skin2: '#d9d0c7', muscle: '#e2d9d0', stroke: '#b9ada2', detail: '#c4b8ad', muscle2: '#d3c7bb' };

function figure(view, dx) {
  let s = `<g transform="translate(${dx},0)">`;
  s += `<path d="${a.outline}" fill="url(#skin)" stroke="${pal.stroke}" stroke-width="0.45"/>`;
  s += `<ellipse cx="${a.head.cx}" cy="${a.head.cy}" rx="${a.head.rx}" ry="${a.head.ry}" fill="url(#skin)" stroke="${pal.stroke}" stroke-width="0.45"/>`;
  const entries = Object.entries(a.muscles).filter(([k]) => k.split('.')[1] === view);
  for (const [key, d] of entries) {
    if (highlight[key.split('.')[0]]) continue;
    s += `<path d="${d}" fill="url(#muscle)" stroke="${pal.stroke}" stroke-width="0.35"/>`;
  }
  for (const [key, d] of entries) {
    const w = highlight[key.split('.')[0]];
    if (!w) continue;
    const op = w >= 1 ? 1 : w >= 0.5 ? 0.6 : 0.3;
    s += `<path d="${d}" fill="url(#hot)" fill-opacity="${op}" stroke="#a61e22" stroke-opacity="${op}" stroke-width="0.4"/>`;
  }
  for (const d of a.details[view]) s += `<path d="${d}" fill="none" stroke="${pal.detail}" stroke-width="0.3" stroke-linecap="round"/>`;
  s += `<path d="${a.outline}" fill="url(#shade)" stroke="none"/>`;
  return s + '</g>';
}

const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 210 200" width="1050" height="1000">
<defs>
<linearGradient id="skin" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${pal.skin1}"/><stop offset="1" stop-color="${pal.skin2}"/></linearGradient>
<linearGradient id="muscle" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${pal.skin1}"/><stop offset="1" stop-color="${pal.muscle2}"/></linearGradient>
<linearGradient id="hot" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F2554F"/><stop offset="1" stop-color="#C4262A"/></linearGradient>
<linearGradient id="shade" x1="0" y1="0" x2="1" y2="0"><stop offset="0.3" stop-color="#000" stop-opacity="0.07"/><stop offset="0.5" stop-color="#000" stop-opacity="0"/><stop offset="0.7" stop-color="#000" stop-opacity="0.07"/></linearGradient>
</defs>
<rect width="210" height="200" fill="${pal.bg}"/>
${figure('front', 0)}${figure('back', 110)}
</svg>`;
fs.writeFileSync(out, svg);
