// Dev-only: where a pattern's body goes below the floor.
import { POSE_PATTERNS } from '../src/poses.js';
import { contactPoints, frameAt, placeKeyframes, timing } from '../src/rig3d.js';
const names = ['pelvisF', 'pelvisB', 'pelvisL', 'pelvisR', 'chestF', 'chestB', 'chestL', 'chestR', 'head', 'neck', 'sitBones'];
for (const s of ['L', 'R']) for (const j of ['shoulder', 'elbow', 'wrist', 'handTip', 'knee', 'ankle', 'toe', 'heel']) names.push(s + j);
for (const slug of process.argv.slice(2)) {
  const p = POSE_PATTERNS.find((x) => x.slug === slug);
  const pl = placeKeyframes(p);
  for (let n = 0; n < 64; n++) {
    const sk = frameAt(p, n / 64, pl);
    const low = contactPoints(sk).map(([q, r], i) => [q[1] - r, i]).sort((a, b) => a[0] - b[0])[0];
    if (low[0] < -1.5) console.log(slug, n, JSON.stringify(timing(p, n / 64)), low[0].toFixed(1), names[low[1]]);
  }
}
