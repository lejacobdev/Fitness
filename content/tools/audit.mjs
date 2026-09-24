// Dev-only: audits every catalogue item's animation against its text and
// against physics the unit tests don't cover. Prints one line per finding:
//   CODE | item slug | pattern | detail
//   node --max-old-space-size=6000 tools/audit.mjs [codes,…]
import { CATALOGUE } from '../src/catalogue.js';
import { POSE_ASSIGNMENTS } from '../src/poseAssignments/index.js';
import { POSE_PATTERNS } from '../src/poses.js';
import { castAt, frameAt, lowestY, placeKeyframes, timing } from '../src/rig3d.js';

const only = process.argv[2] ? new Set(process.argv[2].split(',')) : null;
const BY = new Map(POSE_PATTERNS.map((p) => [p.slug, p]));
const out = [];
const flag = (code, item, p, detail) => { if (!only || only.has(code)) out.push(`${code} | ${item} | ${p} | ${detail}`); };

// What the app shows for an item (CatalogueItemPose.swift: own slug, then base, then startPose).
const patternOf = (i) => BY.get(POSE_ASSIGNMENTS[i.slug] ?? i.startPose);

const tok = (c) => new Set(c.split('+'));
const GROUND = ['feet', 'L', 'R', 'Ltoe', 'Rtoe', 'Lheel', 'Rheel', 'hands', 'Lhand', 'Rhand', 'knees', 'Lknee', 'Rknee', 'back', 'front'];
const kinds = (p) => ({ imp: p.implement?.kind ?? null, fx: p.fixture?.kind ?? null });
const text = (i) => [i.name, ...(i.setup ?? []), ...(i.execution ?? [])].join(' ').toLowerCase();

// ── Equipment the item lists vs what the animation shows ─────────────────
const SHOWS = {
  barbell: (k) => ['barbell', 'landmine'].includes(k.imp) || k.fx === 'bar',
  'trap-bar': (k) => ['barbell', 'dumbbells'].includes(k.imp),
  dumbbell: (k) => ['dumbbell', 'dumbbells', 'goblet'].includes(k.imp),
  kettlebell: (k) => ['kettlebell', 'goblet', 'dumbbell'].includes(k.imp),
  'med-ball': (k, p) => ['medball', 'ball'].includes(k.imp) || !!p.ball || k.fx === 'ball',
  'pull-up-bar': (k) => k.fx === 'bar',
  'low-bar': (k) => k.fx === 'bar',
  bench: (k) => ['bench', 'incline', 'box'].includes(k.fx),
  box: (k) => ['box', 'bench'].includes(k.fx),
  step: (k) => ['box', 'bench'].includes(k.fx),
  hurdle: (k) => k.fx === 'hurdle',
  'jump-rope': (k) => k.imp === 'jumprope',
  landmine: (k) => k.imp === 'landmine',
  'cable-machine': (k) => k.imp === 'cable',
  'lat-pulldown': (k) => k.imp === 'cable' || k.fx === 'bar',
  'foam-roller': (k) => k.fx === 'roller',
  sled: (k) => k.fx === 'sled',
  band: (k) => k.imp === 'band',
  racket: (k) => ['racket', 'paddle'].includes(k.imp),
  bat: (k) => ['bat', 'bat2'].includes(k.imp),
  puck: (k, p) => !!p.ball || !!p.implement?.puck,
  ball: (k, p) => !!p.ball || !!p.implement?.puck || !!p.implement?.ball || ['medball', 'ball', 'bowlingballs', 'disc'].includes(k.imp) || ['ball', 'kickball'].includes(k.fx),
  partner: (k, p) => !!p.cast?.length,
  wall: (k) => ['wall', 'climbwall'].includes(k.fx),
};
// Implements that are gear the item must list (a bodyweight variant must not show a barbell).
const NEEDS = {
  barbell: ['barbell', 'trap-bar', 'bumper-plates', 'landmine'], dumbbell: ['dumbbell', 'kettlebell'], dumbbells: ['dumbbell', 'kettlebell', 'trap-bar'],
  goblet: ['dumbbell', 'kettlebell'], kettlebell: ['kettlebell', 'dumbbell'], medball: ['med-ball', 'ball'], cable: ['cable-machine', 'band', 'lat-pulldown'],
  band: ['band', 'mini-band'], landmine: ['landmine', 'barbell'], jumprope: ['jump-rope'], plate: ['weight-plate', 'bumper-plates'],
};
const FX_NEEDS = { bar: ['pull-up-bar', 'low-bar', 'rack', 'barbell', 'lat-pulldown'], sled: ['sled'], roller: ['foam-roller'], hurdle: ['hurdle', 'cones'] };

// ── Text cues ─────────────────────────────────────────────────────────────
const PEOPLE = /\b(partner|teammate|opponent|defender|attacker|feeder|coach (feeds|tosses|throws|serves|rolls|passes|hits)|a passer|receiver|in pairs|pairs? up|two players|three players|1v1|2v1|2v2|3v2|3v3|4v4|goalkeeper faces|shooter)\b/;
const BALLISH = /\b(ball|puck|shuttlecock|frisbee|disc|medicine ball|med ball)\b/;
const NOBALL = /\b(no ball|without (a|the) (ball|puck|shuttle)|imaginary|shadow|ghost|dry swing|no-ball|then add the ball)\b/;
const NOT_A_BALL = /\b(balls? of (the|your|each|one) (foot|feet)|toe-ball-heel|ball movement|as if saving a ball)\b/g;

for (const i of CATALOGUE) {
  const p = patternOf(i);
  if (!p) { flag('NOPATTERN', i.slug, '-', `startPose ${i.startPose}`); continue; }
  const k = kinds(p);
  const eq = new Set(i.equipment ?? []);
  const t = text(i).replace(NOT_A_BALL, '');
  const name = i.name.toLowerCase();

  for (const e of eq) if (SHOWS[e] && !SHOWS[e](k, p)) flag('EQ-MISSING', i.slug, p.slug, `lists ${e}, shows imp=${k.imp} fx=${k.fx} ball=${!!p.ball} cast=${p.cast?.length ?? 0}`);
  if (k.imp && NEEDS[k.imp] && !NEEDS[k.imp].some((e) => eq.has(e))) flag('EQ-EXTRA', i.slug, p.slug, `shows ${k.imp}, lists ${[...eq].join(',')}`);
  if (k.fx && FX_NEEDS[k.fx] && !FX_NEEDS[k.fx].some((e) => eq.has(e))) flag('EQ-EXTRA', i.slug, p.slug, `shows fixture ${k.fx}, lists ${[...eq].join(',')}`);

  if (PEOPLE.test(t) && !p.cast?.length && !eq.has('partner')) flag('PEOPLE', i.slug, p.slug, `text: "${t.match(PEOPLE)[0]}" but no cast`);
  if (BALLISH.test(t) && !NOBALL.test(t) && !p.ball && !p.implement?.puck && !p.implement?.ball && !['medball', 'ball', 'disc', 'bowlingballs'].includes(k.imp) && !['ball', 'kickball'].includes(k.fx)) flag('BALL', i.slug, p.slug, `text: "${t.match(BALLISH)[0]}" but no ball`);

  const contacts = p.keyframes.map((f) => tok(f.contact));
  const any = (c) => contacts.some((s) => s.has(c));
  if (/\b(jump|hop|bound|leap|skip|pogo|tuck jump|burpee)/.test(name) && !any('air') && !p.fixture) flag('NOAIR', i.slug, p.slug, 'name says jump/hop but the body never leaves the floor');
  if (/\b(kneeling|half-kneeling|tall-kneeling|quadruped|on your knees)\b/.test(name) && !['knees', 'Lknee', 'Rknee', 'hands'].some(any)) flag('KNEEL', i.slug, p.slug, 'name says kneeling, no knee contact');
  if (/\b(seated|sitting|sit-up|v-up)\b/.test(name) && !['seat', 'back'].some(any) && !p.fixture) flag('SEAT', i.slug, p.slug, 'name says seated, no seat contact');
  if (/\b(supine|lying|prone|dead bug|glute bridge|plank|crunch)\b/.test(name) && !['back', 'front', 'hands', 'Lhand', 'Rhand', 'knees', 'seat'].some(any)) flag('LYING', i.slug, p.slug, 'name says lying/plank, standing contacts only');
  if (/\b(single-leg|one-leg|single leg|one leg|pistol)\b/.test(name) && contacts.every((s) => s.has('feet'))) flag('ONELEG', i.slug, p.slug, 'name says single-leg, both feet planted throughout');
  if (/\b(hang|hanging|pull-up|chin-up|toes-to-bar)\b/.test(name) && k.fx !== 'bar' && !any('grip')) flag('HANG', i.slug, p.slug, 'name says hanging, no bar');
  if (i.variant?.axis === 'unilateral' && !isUnilateral(p)) flag('VARIANT-UNI', i.slug, p.slug, 'single-side variant shows the two-sided base movement');
  if (i.variant?.axis === 'constraint' && i.variant.values && Object.keys(i.variant.values).includes('opposition') && !p.cast?.length) flag('VARIANT-OPP', i.slug, p.slug, `adds opposition, no defender shown`);
}

function isUnilateral(p) {
  // Something clearly one-sided: a single-foot contact, or big L/R differences.
  return p.keyframes.some((f) => /(^|\+)(L|R|Ltoe|Rtoe|Lhand|Rhand|Lknee|Rknee)(\+|$)/.test(f.contact))
    || p.keyframes.some((f) => ['hip', 'knee', 'shoulder', 'elbow'].some((j) => Math.abs(f.pose[`${j}L`] - f.pose[`${j}R`]) > 35));
}

// ── Physics per pattern (only patterns some item actually shows) ──────────
const used = new Set(CATALOGUE.map((i) => patternOf(i)?.slug).filter(Boolean));
const S = 48;
for (const p of POSE_PATTERNS) {
  if (!used.has(p.slug)) continue;
  const placed = placeKeyframes(p);
  const n = p.keyframes.length;
  let prev = null, slideMax = { L: 0, R: 0, hands: 0 }, floatMax = 0, ballLow = 0, nan = false, castNear = Infinity, legsThrough = 0;
  for (let q = 0; q < S; q++) {
    const tt = q / S;
    const { segment, u } = timing(p, tt);
    const k0 = p.keyframes[segment], k1 = p.keyframes[(segment + 1) % n];
    const c0 = tok(k0.contact), c1 = tok(k1.contact);
    let s;
    try { s = frameAt(p, tt, placed); } catch (e) { flag('CRASH', '-', p.slug, e.message); break; }
    if ([s.pelvis, s.head, s.L.ankle, s.R.ankle, s.L.wrist, s.R.wrist].some((v) => v.some((x) => !Number.isFinite(x)))) nan = true;
    const water = p.fixture?.kind === 'water' || c0.has('water');
    // Floating: both ends of the segment are on the floor, but the body isn't.
    const grounded = (c) => [...c].some((x) => GROUND.includes(x)) && !c.has('air') && !c.has('water') && !c.has('grip') && !c.has('seat');
    if (!p.fixture && !water && grounded(c0) && grounded(c1) && !(k0.surface || k1.surface)) floatMax = Math.max(floatMax, lowestY(s));
    // Sliding: a foot planted at both ends of the segment moves along the floor.
    if (prev && prev.segment === segment && !p.path && !k0.travel && !k1.travel) {
      for (const side of ['L', 'R']) {
        const planted = (c) => c.has(side) || c.has('feet');
        if (planted(c0) && planted(c1)) {
          const d = Math.hypot(s[side].ankle[0] - prev.s[side].ankle[0], s[side].ankle[2] - prev.s[side].ankle[2]);
          slideMax[side] = Math.max(slideMax[side], d);
        }
      }
      if (c0.has('hands') && c1.has('hands')) {
        const d = Math.hypot(s.L.wrist[0] - prev.s.L.wrist[0], s.L.wrist[2] - prev.s.L.wrist[2]);
        slideMax.hands = Math.max(slideMax.hands, d);
      }
    }
    if (s.ball && !water && p.ball) ballLow = Math.min(ballLow, s.ball[1] - (p.ball.r ?? 6));
    if (p.cast?.length && !p.contactSport) {
      for (const m of castAt(p, tt, placed) ?? []) {
        if (!m?.s) continue;
        const d = Math.hypot(m.s.pelvis[0] - s.pelvis[0], m.s.pelvis[2] - s.pelvis[2]);
        castNear = Math.min(castNear, d);
      }
    }
    const kk = Math.hypot(s.L.knee[0] - s.R.knee[0], s.L.knee[1] - s.R.knee[1], s.L.knee[2] - s.R.knee[2]);
    const aa = Math.hypot(s.L.ankle[0] - s.R.ankle[0], s.L.ankle[1] - s.R.ankle[1], s.L.ankle[2] - s.R.ankle[2]);
    if (kk < 5 || aa < 4) legsThrough++;
    prev = { segment, s };
  }
  if (nan) flag('NAN', '-', p.slug, 'non-finite joint position');
  if (floatMax > 5) flag('FLOAT', '-', p.slug, `body ${floatMax.toFixed(1)} above the floor between grounded keyframes`);
  for (const side of ['L', 'R', 'hands']) if (slideMax[side] > 4) flag('SLIDE', '-', p.slug, `${side} planted but moves ${slideMax[side].toFixed(1)} per step`);
  if (ballLow < -3) flag('BALL-FLOOR', '-', p.slug, `ball ${ballLow.toFixed(1)} below the floor`);
  if (castNear < 26) flag('CAST-NEAR', '-', p.slug, `partner pelvis ${castNear.toFixed(1)} from the athlete`);
  if (legsThrough > S / 4) flag('LEGS', '-', p.slug, `knees/ankles overlap in ${legsThrough}/${S} frames`);
}

// Patterns shared by many items with different names: worth a look.
const users = new Map();
for (const i of CATALOGUE) { if (i.baseSlug) continue; const p = patternOf(i); if (!p) continue; users.set(p.slug, [...(users.get(p.slug) ?? []), i.slug]); }
for (const [p, list] of users) if (list.length >= 4) flag('SHARED', list.join(','), p, `${list.length} items share it`);

console.log(out.join('\n'));
const counts = {};
for (const l of out) counts[l.split(' | ')[0]] = (counts[l.split(' | ')[0]] ?? 0) + 1;
console.error(JSON.stringify(counts));
