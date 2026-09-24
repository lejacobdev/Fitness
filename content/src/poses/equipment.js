/**
 * Drills shown with the equipment their text describes: the wall you jump
 * and reach against, mini hurdles you run or hop over (placed where the feet
 * actually pass them), stairs, a box beside you, a foam pad under the feet,
 * a kettlebell overhead in one hand. Most are an authored movement with its
 * scene completed; the rest are new movements the text needs.
 */
import { add, frameAtTime, keyframeAt, pathSeconds, placeFixture, placeKeyframes } from '../rig3d.js';
import { STRENGTH, goblet } from './strength.js';
import { PRECISION } from './precision.js';
import { OUTDOOR } from './outdoor.js';
import { P, both, kf, library, solve } from './kit.js';
import { VOLLEYBALL } from './volleyball.js';
import { RACKET } from './racket.js';

const lib = library();
const def = lib.def;
const BY = new Map([...STRENGTH, ...PRECISION, ...OUTDOOR, ...VOLLEYBALL, ...RACKET].map((p) => [p.slug, p]));
const base = (slug) => { const { slug: _s, name: _n, ...spec } = BY.get(slug); return spec; };
const edit = (spec, pose, contact) => ({
  ...spec,
  keyframes: spec.keyframes.map((k, i) => ({ ...k, pose: P(k.pose, pose(k.pose, i)), contact: contact ? contact(k.contact, i) : k.contact })),
});
const rightOnly = (c) => c.replace(/\bfeet\b/, 'R').replace('Ltoe+Rtoe', 'Rtoe');

// ── Walls ─────────────────────────────────────────────────────────────────
def('vertical-jump-wall', 'Jump and touch the wall', { ...base('vertical-jump'), fixture: { kind: 'wall', at: 34 } });
def('approach-jump-wall', 'Approach jump, touching the wall', { ...base('approach-jump'), fixture: { kind: 'wall', side: 1, at: 36 } });

// ── Mini hurdles, placed from the movement itself ─────────────────────────
/**
 * Where along the path something happens: sample the whole run and return
 * the forward positions (world x) where `hit(frame, prev)` is true.
 */
function eventsAlong(spec, hit) {
  const p = { slug: 'probe', name: 'probe', ...spec };
  const placed = placeKeyframes(p);
  const total = pathSeconds(p, placed);
  const xs = [];
  let prev = null;
  for (let t = 0; t < total; t += 1 / 120) {
    const s = frameAtTime(p, t, placed);
    if (prev && hit(s, prev)) xs.push(s.pelvis[0]);
    prev = s;
  }
  const origin = placeFixture({ ...p, fixture: { kind: 'hurdle', at: 0 } }, placed).x;
  return { xs, origin };
}
/** Hurdles midway between the given positions (skipping the first few, a run-up). */
function hurdlesBetween(xs, origin, { skip = 2, count = 6, height = 15 }) {
  const mids = xs.slice(skip, skip + count + 1).map((x, i, a) => (i ? (a[i - 1] + x) / 2 : null)).filter((x) => x != null);
  const gap = (mids[mids.length - 1] - mids[0]) / (mids.length - 1);
  return { kind: 'hurdle', at: mids[0] - origin, count: mids.length, gap, height };
}
// Wickets: sprinting, one step between each (a hurdle between every two footfalls).
{
  const sprint = base('sprint');
  const low = (s) => Math.min(s.L.ankle[1], s.R.ankle[1]);
  const { xs, origin } = eventsAlong(sprint, (s, prev) => low(s) > low(prev) && low(prev) < 9 && low(s) >= 9);
  def('wicket-runs', 'Wicket runs', { ...sprint, fixture: hurdlesBetween(xs, origin, { count: 7 }) });
}
// Hurdle hops: two-footed hops, a hurdle under each flight.
{
  const land = P(both({ hip: 34, knee: 40, ankle: 22, shoulder: -20, elbow: 30, hipAbd: 6 }), { spine: 16 });
  const flight = P(both({ hip: 64, knee: 80, ankle: -10, shoulder: 50, elbow: 40, hipAbd: 6 }), { spine: 12, lift: 26 });
  const hops = {
    view: 'side', loop: true, thumb: 1, path: { kind: 'line', length: 520, speed: 170 },
    keyframes: [kf(land, 'feet', { move: 0.16 }), kf(flight, 'air', { move: 0.3 })],
  };
  let rising = false;
  const { xs, origin } = eventsAlong(hops, (s, prev) => {
    const peak = rising && s.pelvis[1] < prev.pelvis[1];
    rising = s.pelvis[1] > prev.pelvis[1];
    return peak;
  });
  // A hurdle under the top of each flight.
  const peaks = xs.slice(1, 7);
  const gap = (peaks[peaks.length - 1] - peaks[0]) / (peaks.length - 1);
  def('hurdle-hops', 'Mini-hurdle hops', { ...hops, fixture: { kind: 'hurdle', at: peaks[0] - origin, count: peaks.length, gap, height: 15 } });
}

// ── Stairs: running up, a foot on every step ──────────────────────────────
{
  const RISE = 17, RUN = 30;
  const up = (lead, i) => {
    const pose = lead === 'L'
      ? P({ spine: 16, neck: -6, hipL: 70, kneeL: 84, ankleL: 14, hipR: -10, kneeR: 20, ankleR: -30, shoulderL: -30, shoulderR: 40, elbowL: 90, elbowR: 90 })
      : P({ spine: 16, neck: -6, hipR: 70, kneeR: 84, ankleR: 14, hipL: -10, kneeL: 20, ankleL: -30, shoulderR: -30, shoulderL: 40, elbowL: 90, elbowR: 90 });
    return kf(pose, lead, { surface: RISE * (i + 1), travel: [RUN, 0], move: 0.2 });
  };
  const stand = P({ spine: 8, hipL: 30, kneeL: 40, ankleL: 10, hipR: -6, kneeR: 10, shoulderL: -20, shoulderR: 20, elbowL: 80, elbowR: 80 });
  def('stair-runs', 'Stair runs', {
    view: 'side', thumb: 3, fixture: { kind: 'stairs', from: 12, run: RUN, rise: RISE, count: 7 },
    keyframes: [
      kf(stand, 'R', { hold: 0.2, move: 0.2 }),
      up('L', 0), up('R', 1), up('L', 2), up('R', 3), up('L', 4),
      { ...up('R', 5), hold: 0.3 },
    ],
  });
}

// ── Boxes ─────────────────────────────────────────────────────────────────
// Lateral box jump: facing the camera, jumping sideways onto a low box.
{
  const T = { turn: 90 };
  def('lateral-box-jump', 'Lateral box jump', {
    view: 'side', thumb: 3, fixture: { kind: 'box', from: 40, to: 86, top: 30 },
    keyframes: [
      kf(P(T, both({ hipAbd: 6 })), 'feet', { hold: 0.3, move: 0.3 }),
      kf(P(T, both({ hip: 60, knee: 70, ankle: 26, hipAbd: 8, shoulder: -30, elbow: 20 }), { spine: 30 }), 'feet', { hold: 0.05, move: 0.18 }),
      kf(P(T, both({ hip: 30, knee: 50, ankle: -10, hipAbd: 8, shoulder: 60, elbow: 30 }), { spine: 12, lift: 30 }), 'air', { move: 0.2, travel: [34, 0] }),
      kf(P(T, both({ hip: 56, knee: 66, ankle: 24, hipAbd: 8, shoulder: 50, elbow: 30 }), { spine: 26 }), 'feet', { hold: 0.35, move: 0.4, surface: 30, travel: [30, 0] }),
      kf(P(T, both({ hipAbd: 6 })), 'feet', { hold: 0.3, surface: 30 }),
    ],
  });
}
def('single-leg-box-jump', 'Single-leg box jump', edit(base('box-jump'), (q) => ({ hipL: q.hipR + 25, kneeL: Math.min(150, q.kneeR + 75), ankleL: 10 }), rightOnly));

// ── Carries and loaded movements ──────────────────────────────────────────
def('overhead-carry-single', 'Single-arm kettlebell overhead carry',
  edit({ ...base('overhead-carry'), implement: { kind: 'kettlebell', at: 'R' } }, () => ({ shoulderL: 0, shoulderAbdL: 12, elbowL: 6 })));
def('farmers-march', 'Farmer\'s march', edit({ ...base('march'), implement: { kind: 'dumbbells', at: 'hands' } }, () => both({ shoulder: 0, shoulderAbd: 10, elbow: 2 })));
def('goblet-lateral-squat', 'Goblet lateral squat', {
  ...base('lateral-lunge'), implement: { kind: 'goblet', at: 'chest' },
  keyframes: base('lateral-lunge').keyframes.map((k) => ({ ...k, pose: goblet(k.pose) })),
});
def('hamstring-floss-band', 'Hamstring floss with a band', { ...base('hamstring-floss'), implement: { kind: 'band', at: 'hands', toFootL: true } });

// 90-90 breathing: on the back, hips and knees at 90 degrees, feet flat on a wall.
{
  const spec = edit(base('breathing-supine'), () => ({ hipL: 90, hipR: 90, kneeL: 90, kneeR: 90, ankleL: 0, ankleR: 0 }), () => 'back');
  const p = { slug: 'probe', name: 'probe', ...spec };
  const placed = placeKeyframes(p);
  const k0 = keyframeAt(p, 0, placed);
  const wallAt = Math.max(k0.L.ankle[0], k0.L.toe[0], k0.L.heel[0]) - k0.pelvis[0] + 2;
  def('breathing-90-90-wall', '90-90 breathing, feet on a wall', { ...spec, fixture: { kind: 'wall', at: wallAt } });
}

// ── On a foam balance pad ─────────────────────────────────────────────────
const PAD = 6;
const onFoam = (slug, under, width) => {
  const spec = base(slug);
  return {
    ...spec, fixture: { kind: 'box', under, width, top: PAD, foam: 1 },
    keyframes: spec.keyframes.map((k) => ({ ...k, surface: (k.surface ?? 0) + PAD })),
  };
};
def('single-leg-balance-foam', 'Single-leg balance on a foam pad', onFoam('single-leg-balance', 'Lfoot', 34));
def('star-excursion-foam', 'Star excursion reach on a foam pad', onFoam('star-excursion', 'Lfoot', 34));
def('surf-stance-balance-foam', 'Surf stance balance on a foam pad', onFoam('surf-stance-balance', 'feet', 70));
def('archery-aim-balance-foam', 'Aiming stance on a foam pad', onFoam('archery-aim-balance', 'feet', 60));

def('balance-catch-foam', 'Balance catches on a foam pad', onFoam('balance-catch', 'Lfoot', 34));

// ── Stir the pot: forearms on a bench, small circles, body still ─────────
{
  const TOP = 40;
  const onBench = (sh, abd) => solve(P(both({ shoulder: 88 + sh, elbow: 90, shoulderAbd: 10 + abd, ankle: 30, wrist: 0 }), { neck: -8 }), 'spine',
    (sk) => (sk.L.elbow[1] - 3.8) - sk.L.toe[1] - TOP, 20, 100);
  def('stir-the-pot', 'Stir the pot', {
    view: 'three-quarter', loop: true, thumb: 0, fixture: { kind: 'box', under: 'hands', width: 46, top: TOP },
    keyframes: [[8, 0], [0, 8], [-8, 0], [0, -8]].map(([sh, abd]) => kf(onBench(sh, abd), 'Ltoe+Rtoe', { move: 0.5 })),
  });
}

// ── Wall ball: throw it at the wall, let it bounce once, catch ────────────
{
  const stance = both({ hip: 30, knee: 36, ankle: 16, hipAbd: 12 });
  def('wall-ball-catch', 'Wall throw, one bounce, catch', {
    view: 'side', thumb: 4, fixture: { kind: 'wall', at: 200 }, ball: { r: 3.3, color: 'yellow' },
    keyframes: [
      kf(P(stance, { spine: 14, shoulderR: 40, elbowR: 90, shoulderL: 30, elbowL: 80 }), 'feet', { hold: 0.2, move: 0.22, ball: 'R' }),
      kf(P(stance, { spine: 16, shoulderR: 100, elbowR: 10, shoulderL: 30, elbowL: 80 }), 'feet', { move: 0.3, ball: 'R' }),
      kf(P(stance, { spine: 16, shoulderR: 60, elbowR: 30, shoulderL: 30, elbowL: 80 }), 'feet', { move: 0.3, ball: { at: [194, 50, 0] } }),
      kf(P(both({ hip: 44, knee: 54, ankle: 24, hipAbd: 14, shoulder: 50, elbow: 30 }), { spine: 24 }), 'feet', { move: 0.3, ball: { floor: 'R', dx: 80 } }),
      kf(P(both({ hip: 44, knee: 54, ankle: 24, hipAbd: 14, shoulder: 60, elbow: 20 }), { spine: 26 }), 'feet', { hold: 0.4, ball: 'hands' }),
    ],
  });
}
// Setting and volleying against a wall: the ball goes to the wall and back.
{
  const set = base('vb-set');
  def('vb-set-wall', 'Wall setting', { ...set, fixture: { kind: 'wall', at: 62 }, keyframes: set.keyframes.map((k, i) => (i === 2 ? { ...k, ball: { at: [54, 196, 0] } } : k)) });
  const volley = base('volley');
  def('volley-wall', 'Volleys against a wall', { ...volley, fixture: { kind: 'wall', at: 136 }, keyframes: volley.keyframes.map((k, i) => (i === 0 ? { ...k, ball: { at: [128, 60, -20] } } : k)) });
}
// Route running: the break, then a pass arrives and is caught.
def('cut-45-catch', '45-degree cut and catch', {
  ...base('cut-45'), ball: { r: 4.6, color: 'brown' },
  keyframes: base('cut-45').keyframes.map((k, i) => ({ ...k, ball: ['none', { at: [300, 110, -120] }, 'hands'][i], ...(i === 1 ? { ballArc: 24 } : {}) })),
});

export const EQUIPMENT = lib.patterns;
void add;
