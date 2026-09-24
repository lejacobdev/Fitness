/**
 * Turns a placed 3D skeleton (rig3d.js) into flat, depth-sorted shapes:
 * the same parts, sizes, colours and ordering RigPoseView.swift draws. Kept
 * separate from the kinematics so tests can use one without the other.
 *
 * Every shape is a closed polygon in screen space (x right, y down) with a
 * depth; drawing them far-to-near is the whole renderer.
 */
import { BONES, LACROSSE_HEAD, add, apply, dot, norm, project, scale, sub, rotY } from './rig3d.js';

export const PALETTE = {
  light: {
    skinNear: '#D9A47A', skinFar: '#A9764F', shirtNear: '#2B2D33', shirtFar: '#17181C',
    shortsNear: '#434957', shortsFar: '#272B33', shoe: '#15161A', sole: '#F2F2F4', hair: '#2A1D15',
    ground: '#E3E3E8', shadow: 'rgba(0,0,0,0.12)', steel: '#8E9199', plate: '#26272C', wood: '#B98A5A',
    pad: '#3A3D46', water: '#9CC7F0', glow: '#E5383B', implementRed: '#E5383B',
  },
  dark: {
    skinNear: '#D9A47A', skinFar: '#A9764F', shirtNear: '#5C6272', shirtFar: '#3E4250',
    shortsNear: '#707688', shortsFar: '#4E5363', shoe: '#E8E8EC', sole: '#9A9AA2', hair: '#2A1D15',
    ground: '#3A3A40', shadow: 'rgba(0,0,0,0.35)', steel: '#B8BBC4', plate: '#D6D7DC', wood: '#C99A6A',
    pad: '#6A6E7A', water: '#3F6E99', glow: '#FF4D4F', implementRed: '#FF4D4F',
  },
};

/** A cast member's kit: lighter, so the athlete doing the drill stands out. */
export const PARTNER = {
  light: { shirtNear: '#9AA3B5', shirtFar: '#7A8396', shortsNear: '#6E7688', shortsFar: '#555C6C', hair: '#4A3525' },
  dark: { shirtNear: '#3A3F4C', shirtFar: '#2A2E38', shortsNear: '#4A505E', shortsFar: '#353945', hair: '#4A3525' },
};

/** Torso cross-sections: t along pelvis→neck, lateral half-width, front and back depth. */
export const TORSO = [
  [0, 13.5, 8, 9.5], [0.18, 12.8, 9, 8.6], [0.45, 12.2, 8, 7.6],
  [0.72, 15, 10.2, 9], [0.9, 16, 8.8, 9.4], [1, 9, 5, 5.5],
];

const SLICE_POINTS = 18;

function hex(c) {
  const n = parseInt(c.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
export function mix(a, b, t) {
  const x = hex(a), y = hex(b);
  const k = Math.max(0, Math.min(1, t));
  const c = x.map((v, i) => Math.round(v + (y[i] - v) * k));
  return `#${c.map((v) => v.toString(16).padStart(2, '0')).join('')}`;
}

/** Near parts light, far parts shaded: by camera depth. */
const shade = (far, near, depth) => mix(far, near, (depth + 13) / 26);

// ── 2D helpers ──────────────────────────────────────────────────────────

export function hull(points) {
  const p = points.map((q) => [q[0], q[1]]).sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  if (p.length < 3) return p;
  const cross = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const lower = [], upper = [];
  for (const q of p) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], q) <= 0) lower.pop();
    lower.push(q);
  }
  for (let i = p.length - 1; i >= 0; i--) {
    const q = p[i];
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], q) <= 0) upper.pop();
    upper.push(q);
  }
  upper.pop(); lower.pop();
  return lower.concat(upper);
}

function circlePts(c, r, n = 14) {
  const out = [];
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    out.push([c[0] + Math.cos(a) * r, c[1] + Math.sin(a) * r]);
  }
  return out;
}

/** A tapered capsule between two screen points: hull of two circles. */
export function capsule2(a, b, ra, rb) {
  return hull([...circlePts(a, ra), ...circlePts(b, rb)]);
}

/** Half of a capsule on one side of its axis (side vector in screen space). */
function halfCapsule2(a, b, ra, rb, sideVec) {
  const l = Math.hypot(sideVec[0], sideVec[1]) || 1;
  const n = [sideVec[0] / l, sideVec[1] / l];
  return [a, b, [b[0] + n[0] * rb, b[1] + n[1] * rb], [a[0] + n[0] * ra, a[1] + n[1] * ra]];
}

const P = (p) => { const q = project(p); return [q.x, q.y]; };

/**
 * A long thin object (bar, stick, band, rope) as short pieces, each at its
 * own depth — so hands and limbs pass correctly in front of or behind it
 * along its length rather than all of it sitting at one depth.
 */
export function segmented(a, b, ra, rb, fill, bias = 0, n = 10) {
  const out = [];
  for (let i = 0; i < n; i++) {
    const t0 = i / n, t1 = (i + 1) / n;
    const p0 = add(scale(a, 1 - t0), b, t0), p1 = add(scale(a, 1 - t1), b, t1);
    out.push({ points: capsule2(P(p0), P(p1), ra + (rb - ra) * t0, ra + (rb - ra) * t1), fill, depth: (D(p0) + D(p1)) / 2 + bias });
  }
  return out;
}
/** Hands sit on top of whatever they grip. */
const GRIP_BIAS = 0.6;
const D = (p) => project(p).depth;
/** Screen-space direction of a world direction. */
const dir2 = (v) => { const q = project(v); return [q.x, q.y]; };
/** How much a world direction points at the camera (−1…1). */
const facing = (v) => project(norm(v)).depth;

// ── The figure ──────────────────────────────────────────────────────────

/**
 * Shapes for one frame. `glow`: region → opacity. `implement`: resolved
 * implement spec or null. `fixture`: resolved fixture spec or null.
 */
/** Ball colours by sport. */
export const BALL_COLORS = { orange: '#E8762B', white: '#F4F4F2', yellow: '#D8E83A', red: '#E5383B', brown: '#8B4A2B', blue: '#2F6FE0', black: '#1E1E22' };

export function figureShapes(s, { scheme = 'light', palette = null, glow = {}, implement = null, fixture = null, fixturePlace = null, ball = null, prosthetic = null, wear = null } = {}) {
  const pal = palette === 'partner' ? { ...PALETTE[scheme], ...PARTNER[scheme] } : PALETTE[scheme];
  const shapes = [];
  const push = (points, fill, depth, extra = {}) => shapes.push({ points, fill, depth, ...extra });

  // Shadow on the floor (always first).
  const floor = s.floor ?? 0;
  const inWater = fixture?.kind === 'water';
  const feet = [s.L.toe, s.L.heel, s.R.toe, s.R.heel, s.pelvis, s.L.wrist, s.R.wrist];
  const onFloor = feet.map((p) => [p[0], floor, p[2]]);
  const xs = onFloor.map((p) => P(p)[0]);
  const minX = Math.min(...xs) - 6, maxX = Math.max(...xs) + 6;
  const lowest = Math.min(...feet.map((p) => p[1])) - floor;
  if (lowest < 30 && !inWater) {
    const k = Math.max(0.25, 1 - lowest / 40);
    const cx = (minX + maxX) / 2, rx = (maxX - minX) / 2, cy = P([0, floor, 0])[1];
    push(Array.from({ length: 20 }, (_, i) => { const a = (i / 20) * Math.PI * 2; return [cx + Math.cos(a) * rx, cy + Math.sin(a) * 2.4 * k]; }), pal.shadow, -1e6);
  }

  if (fixture) for (const f of fixtureShapes(s, fixture, fixturePlace, pal)) shapes.push(f);

  // Torso.
  const slices = TORSO.map(([t, w, f, b]) => {
    const frame = s.trunk;
    const up = apply(frame, [0, 1, 0]);
    const centre = add(add(s.pelvis, up, BONES.torso * t), apply(frame, [(f - b) / 2, 0, 0]));
    const twisted = mulM(frame, rotY(s.twist * t));
    const pts = [];
    for (let i = 0; i < SLICE_POINTS; i++) {
      const a = (i / SLICE_POINTS) * Math.PI * 2;
      const local = [Math.sin(a) * (f + b) / 2, 0, Math.cos(a) * w];
      pts.push({ world: add(centre, apply(twisted, local)), front: Math.sin(a) });
    }
    return { t, pts };
  });
  const torsoDepth = (D(s.pelvis) + D(s.neckBase)) / 2 - 2;
  const shirt = shade(pal.shirtFar, pal.shirtNear, torsoDepth + 8);
  for (let i = 0; i < slices.length - 1; i++) {
    push(hull([...slices[i].pts, ...slices[i + 1].pts].map((p) => P(p.world))), shirt, torsoDepth, { part: 'torso' });
  }
  // Shorts over the pelvis.
  push(hull([...slices[0].pts, ...slices[1].pts].map((p) => P(add(s.pelvis, scale(sub(p.world, s.pelvis), 1.05))))),
    shade(pal.shortsFar, pal.shortsNear, torsoDepth + 8), torsoDepth + 0.01, { part: 'torso' });

  // Torso glow: front or back halves of slices in a band.
  const trunkFwd = apply(s.trunk, [1, 0, 0]);
  const band = (t0, t1, front) => {
    const pts = [];
    for (const sl of slices) {
      if (sl.t < t0 - 1e-6 || sl.t > t1 + 1e-6) continue;
      for (const p of sl.pts) if (front ? p.front > -0.05 : p.front < 0.05) pts.push(P(p.world));
    }
    return pts.length >= 3 ? hull(pts) : null;
  };
  const torsoGlow = (region, t0, t1, front) => {
    const o = glow[region];
    if (!o) return;
    const f = facing(trunkFwd) * (front ? 1 : -1);
    const alpha = o * 0.85 * (0.4 + 0.6 * Math.max(0, f + 0.35));
    const poly = band(t0, t1, front);
    if (poly) push(poly, pal.glow, torsoDepth + 0.02, { opacity: alpha });
  };
  torsoGlow('chest', 0.6, 0.95, true);
  torsoGlow('abs', 0.12, 0.6, true);
  torsoGlow('upperBack', 0.5, 0.95, false);
  torsoGlow('lowerBack', 0.12, 0.5, false);
  torsoGlow('glutes', 0, 0.2, false);

  // Head, neck, hair.
  const neckDepth = D(s.neckTop);
  push(capsule2(P(s.neckBase), P(s.neckTop), 4.4, 4.1), shade(pal.skinFar, pal.skinNear, neckDepth + 6), torsoDepth + 0.5, { glowRegion: 'neck' });
  const headUp = apply(s.headFrame, [0, 1, 0]);
  const headFwd = apply(s.headFrame, [1, 0, 0]);
  const hairC = add(add(s.head, headUp, 1.6), headFwd, -1.7);
  const faceC = add(add(s.head, headUp, -0.8), headFwd, 1.2);
  const hairShape = circlePts(P(hairC), BONES.headR + 0.4, 24);
  const faceShape = circlePts(P(faceC), BONES.headR - 0.6, 24);
  const headDepth = D(s.head) + 1;
  const skinHead = shade(pal.skinFar, pal.skinNear, D(faceC) + 8);
  // Face in front of the hair unless the head faces away from the camera.
  if (facing(headFwd) >= -0.35) {
    push(hairShape, pal.hair, headDepth);
    push(faceShape, skinHead, headDepth + 0.001);
  } else {
    push(faceShape, skinHead, headDepth);
    push(hairShape, pal.hair, headDepth + 0.001);
  }
  // Headwear: goalball eyeshades, a bike helmet.
  if (wear?.includes('helmet')) {
    const faceY = P(faceC)[1];
    const dome = circlePts(P(add(hairC, headUp, 1.2)), BONES.headR + 1.6, 28).filter((q) => q[1] <= faceY + 1);
    if (dome.length >= 3) push(hull(dome), pal.implementRed, headDepth + 0.004);
  }
  if (wear?.includes('eyeshade') && facing(headFwd) > -0.5) {
    const lat = apply(s.headFrame, [0, 0, 1]);
    const eye = add(add(s.head, headFwd, BONES.headR - 1.2), headUp, 0.6);
    push(capsule2(P(add(eye, lat, -5.8)), P(add(eye, lat, 5.8)), 2.4, 2.4), '#1E1E22', headDepth + 0.003);
  }
  // Ears (only the one facing the camera shows).
  for (const σ of [1, -1]) {
    const lat = apply(s.headFrame, [0, 0, σ]);
    if (facing(lat) < 0.2) continue;
    const ear = add(add(s.head, lat, BONES.headR - 1), headFwd, -0.8);
    push(circlePts(P(ear), 1.9, 10), mix(pal.skinFar, pal.skinNear, 0.7), D(ear) + 1.2);
  }

  // Limbs.
  for (const k of ['L', 'R']) {
    const l = s[k];
    const d = (p, q) => (D(p) + D(q)) / 2;
    const skin = (depth) => shade(pal.skinFar, pal.skinNear, depth);
    // Leg.
    const thighD = d(l.hip, l.knee), shinD = d(l.knee, l.ankle);
    push(capsule2(P(l.hip), P(l.knee), 8.2, 5.4), skin(thighD), thighD, { glow: limbGlow(glow, l.thigh, l.hip, l.knee, 8.2, 5.4, ['thighFront', 'thighBack', 'thigh']) });
    if (prosthetic === k) {
      // A below-knee running blade: socket, then a carbon C-curve to the toe.
      const down = norm(sub(l.ankle, l.knee)), back = norm(sub(l.heel, l.toe));
      const socket = add(l.knee, down, 16);
      const bend = add(add(l.ankle, back, 7), down, -4);
      push(capsule2(P(l.knee), P(socket), 5.4, 4.2), pal.steel, shinD + 0.02);
      push(capsule2(P(socket), P(bend), 2.2, 2.0), pal.plate, shinD + 0.01);
      push(capsule2(P(bend), P(add(l.toe, [0, 1, 0])), 2.0, 1.6), pal.plate, d(l.ankle, l.toe));
      const shortsEnd = add(l.hip, apply(l.thigh, [0, -1, 0]), BONES.thigh * 0.55);
      push(capsule2(P(l.hip), P(shortsEnd), 9.2, 7), shade(pal.shortsFar, pal.shortsNear, thighD), thighD + 0.01);
    }
    if (prosthetic !== k) {
    const calfC = add(add(l.knee, apply(l.shin, [0, -1, 0]), BONES.shin * 0.33), apply(l.shin, [-1, 0, 0]), 2.2);
    push(hull([...capsule2(P(l.knee), P(l.ankle), 5.2, 3.2), ...circlePts(P(calfC), 4.6)]), skin(shinD), shinD, { glow: limbGlow(glow, l.shin, l.knee, l.ankle, 5.2, 3.2, ['shinFront', 'shinBack', null]) });
    const shortsEnd = add(l.hip, apply(l.thigh, [0, -1, 0]), BONES.thigh * 0.55);
    push(capsule2(P(l.hip), P(shortsEnd), 9.2, 7), shade(pal.shortsFar, pal.shortsNear, thighD), thighD + 0.01);
    // Shoe: a box around heel→toe.
    const fd = l.footDir;
    const fl = norm(apply(l.foot, [0, 0, 1]));
    const fu = norm(sub(scale(apply(l.foot, [0, 1, 0]), 1), scale(fd, dot(apply(l.foot, [0, 1, 0]), fd))));
    const box = [];
    for (const [along, up, w] of [[-BONES.heel - 0.5, 0, 3.6], [BONES.foot + 0.8, 0, 3.2], [-BONES.heel, 5.5, 3.4], [2, 6.4, 3.6], [BONES.foot - 1, 2.6, 3.2], [BONES.foot + 0.6, 1.2, 3]]) {
      for (const σ of [1, -1]) box.push(P(add(add(add(l.ankle, fd, along), fu, up), fl, σ * w)));
    }
    const footD = D(add(l.ankle, fd, 5));
    push(hull(box), pal.shoe, footD, { glow: glow.foot ? { poly: hull(box), alpha: glow.foot * 0.6 } : null });
    }
    // Arm.
    const upperD = d(l.shoulder, l.elbow), foreD = d(l.elbow, l.wrist);
    push(capsule2(P(l.shoulder), P(l.elbow), 5, 3.9), skin(upperD), upperD, { glow: limbGlow(glow, l.arm, l.shoulder, l.elbow, 5, 3.9, ['upperArmFront', 'upperArmBack', null]) });
    const sleeveEnd = add(l.shoulder, apply(l.arm, [0, -1, 0]), BONES.upperArm * 0.42);
    push(capsule2(P(l.shoulder), P(sleeveEnd), 5.7, 4.8), shade(pal.shirtFar, pal.shirtNear, upperD), upperD + 0.01,
      { glow: glow.shoulderCap ? { poly: circlePts(P(l.shoulder), 5.8), alpha: glow.shoulderCap * 0.85 } : null });
    push(capsule2(P(l.elbow), P(l.wrist), 3.8, 2.7), skin(foreD), foreD, { glow: glow.forearm ? { poly: capsule2(P(l.elbow), P(l.wrist), 3.8, 2.7), alpha: glow.forearm * 0.85 } : null });
    const handC = add(l.wrist, apply(l.hand, [0, -1, 0]), BONES.hand * 0.45);
    push(capsule2(P(l.wrist), P(handC), 2.8, 3.2), skin(D(handC)), D(handC) + GRIP_BIAS);
  }

  if (implement) for (const f of implementShapes(s, implement, pal)) shapes.push(f);
  if (s.ball && ball) {
    const r = ball.r ?? 6, depth = D(s.ball) + r * 0.5;
    // White balls get a thin dark rim so they read on a light background.
    if ((ball.color ?? 'red') === 'white') push(sphere(s.ball, r + 0.5), '#8A8A90', depth - 0.001, { isBall: true });
    push(sphere(s.ball, r), BALL_COLORS[ball.color ?? 'red'] ?? pal.implementRed, depth, { isBall: true });
  }

  // Expand per-shape glow into overlay shapes right after their base.
  const out = [];
  shapes.sort((a, b) => a.depth - b.depth);
  for (const sh of shapes) {
    out.push(sh);
    if (sh.glow) out.push({ points: sh.glow.poly, fill: pal.glow, opacity: sh.glow.alpha, depth: sh.depth });
    if (sh.glowRegion && glow[sh.glowRegion]) out.push({ points: sh.points, fill: pal.glow, opacity: glow[sh.glowRegion] * 0.85, depth: sh.depth });
  }
  return out;
}

/**
 * A whole scene: the athlete plus any cast (partner, passer, defender).
 * Each person is drawn whole, far to near (they stand apart, so whole-figure
 * order is right); every floor shadow goes first; the ball is sorted into
 * the nearest person's shapes so it passes in front of or behind them
 * correctly. Cast members wear a lighter kit and never glow.
 */
export function sceneShapes(s, { scheme = 'light', glow = {}, implement = null, fixture = null, fixturePlace = null, ball = null, prosthetic = null, wear = null } = {}) {
  const pal = PALETTE[scheme];
  const groups = [{ s, shapes: figureShapes(s, { scheme, glow, implement, fixture, fixturePlace, ball: null, prosthetic, wear }) }];
  for (const m of s.cast ?? []) groups.push({ s: m.s, shapes: figureShapes(m.s, { scheme, palette: 'partner', implement: m.ref.implement ?? null, prosthetic: m.ref.prosthetic ?? null, wear: m.ref.wear ?? null }) });
  // A guide's tether: a short cord from the athlete's left hand to the guide's right.
  (s.cast ?? []).forEach((m, i) => {
    if (!m.tether) return;
    const a = s.L.wrist, b = m.s.R.wrist;
    const sag = add(scale(add(a, b), 0.5), [0, -6, 0]);
    const group = groups[i + 1];
    group.shapes.push({ points: capsule2(P(a), P(sag), 0.7, 0.7), fill: pal.implementRed, depth: (D(a) + D(sag)) / 2 + 0.5 });
    group.shapes.push({ points: capsule2(P(sag), P(b), 0.7, 0.7), fill: pal.implementRed, depth: (D(sag) + D(b)) / 2 + 0.5 });
  });
  if (s.ball && ball) {
    const r = ball.r ?? 6, depth = D(s.ball) + r * 0.5;
    const balls = [];
    if (ball.shape === 'baton') {
      // A relay baton: a short tube standing up in the hand.
      const up = norm(add([0, 1, 0], apply(s.root, [1, 0, 0]), 0.35));
      balls.push({ points: capsule2(P(add(s.ball, up, -14)), P(add(s.ball, up, 14)), 1.9, 1.9), fill: BALL_COLORS[ball.color ?? 'red'] ?? pal.implementRed, depth, isBall: true });
    } else {
    if ((ball.color ?? 'red') === 'white') balls.push({ points: sphere(s.ball, r + 0.5), fill: '#8A8A90', depth: depth - 0.001, isBall: true });
    balls.push({ points: sphere(s.ball, r), fill: BALL_COLORS[ball.color ?? 'red'] ?? pal.implementRed, depth, isBall: true });
    }
    const dist = (g) => Math.hypot(g.s.pelvis[0] - s.ball[0], g.s.pelvis[2] - s.ball[2]);
    const near = groups.reduce((a, b) => (dist(b) < dist(a) ? b : a));
    const at = near.shapes.findIndex((sh) => sh.depth > depth);
    near.shapes.splice(at < 0 ? near.shapes.length : at, 0, ...balls);
  }
  groups.sort((a, b) => D(a.s.pelvis) - D(b.s.pelvis));
  const shadows = groups.flatMap((g) => g.shapes.filter((sh) => sh.depth <= -1e5));
  return [...shadows, ...groups.flatMap((g) => g.shapes.filter((sh) => sh.depth > -1e5))];
}

const mulM = (a, b) => [apply(a, b[0]), apply(a, b[1]), apply(a, b[2])];

/**
 * A limb's red overlay: the half facing the muscle's side of the limb (front
 * or back), or the whole segment when seen end-on, fading as it turns away.
 */
function limbGlow(glow, frame, a, b, ra, rb, [frontKey, backKey, wholeKey]) {
  const anterior = apply(frame, [1, 0, 0]);
  const pa = P(a), pb = P(b);
  const side2 = dir2(anterior);
  const sideLen = Math.hypot(side2[0], side2[1]);
  let best = null;
  for (const [key, sign] of [[frontKey, 1], [backKey, -1]]) {
    if (!key || !glow[key]) continue;
    const f = facing(anterior) * sign;
    const alpha = glow[key] * 0.85 * (0.45 + 0.55 * Math.max(0, f + 0.4));
    const poly = sideLen > 0.35 ? halfCapsule2(pa, pb, ra, rb, [side2[0] * sign, side2[1] * sign]) : capsule2(pa, pb, ra, rb);
    if (!best || alpha > best.alpha) best = { poly, alpha };
  }
  if (wholeKey && glow[wholeKey] && (!best || glow[wholeKey] * 0.85 > best.alpha)) best = { poly: capsule2(pa, pb, ra, rb), alpha: glow[wholeKey] * 0.85 };
  return best;
}

// ── Implements (held equipment) ────────────────────────────────────────

/** Where an implement sits: named places on the body. */
export function implementPoint(s, at) {
  const fwd = apply(s.chest, [1, 0, 0]);
  const up = apply(s.trunk, [0, 1, 0]);
  const mid = (p, q) => scale(add(p, q), 0.5);
  const grip = (l) => add(l.wrist, apply(l.hand, [0, -1, 0]), 3.5);
  switch (at) {
    case 'back': return add(add(s.neckBase, up, -4), fwd, -8.5);
    case 'rack': return add(add(s.neckBase, up, -5), fwd, 9);
    case 'chest': return mid(grip(s.L), grip(s.R));
    case 'hips': return add(s.pelvis, apply(s.trunk, [1, 0, 0]), 11);
    case 'knees': return scale(add(s.L.knee, s.R.knee), 0.5);
    case 'L': return grip(s.L);
    case 'R': return grip(s.R);
    case 'footL': return add(s.L.toe, [4, 4.5, 0]);
    case 'footR': return add(s.R.toe, [4, 4.5, 0]);
    default: return mid(grip(s.L), grip(s.R));
  }
}

function discPoly(centre, normal, r, n = 18) {
  const nn = norm(normal);
  const helper = Math.abs(nn[1]) < 0.9 ? [0, 1, 0] : [1, 0, 0];
  const u = norm(cross3(nn, helper)), v = cross3(nn, u);
  const pts = [];
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    pts.push(P(add(add(centre, u, Math.cos(a) * r), v, Math.sin(a) * r)));
  }
  return pts;
}
const cross3 = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];

function sphere(c, r) { return circlePts(P(c), r, 18); }

export function implementShapes(s, spec, pal) {
  const out = [];
  const lateral = apply(s.chest, [0, 0, 1]);
  const at = implementPoint(s, spec.at);
  const push = (points, fill, depth, extra = {}) => out.push({ points, fill, depth, ...extra });
  const handDir = (l) => apply(l.hand, [0, -1, 0]);
  switch (spec.kind) {
    case 'barbell': {
      const half = 52;
      const a = add(at, lateral, half), b = add(at, lateral, -half);
      out.push(...segmented(a, b, 1.1, 1.1, pal.steel, 0, 14));
      // pvc: a light pipe for technique work — no plates.
      if (!spec.pvc) for (const σ of [1, -1]) {
        for (const off of [34, 38]) {
          const c = add(at, lateral, σ * off);
          push(hull(discPoly(c, lateral, off === 34 ? 12 : 10)), pal.plate, D(c) + (σ > 0 ? 0 : -0.1));
        }
      }
      break;
    }
    case 'dumbbell': case 'dumbbells': {
      const hands = spec.kind === 'dumbbells' ? ['L', 'R'] : [spec.at === 'R' ? 'R' : 'L'];
      for (const h of hands) {
        const g = implementPoint(s, h);
        const ax = apply(s[h].hand, [0, 0, 1]);
        push(capsule2(P(add(g, ax, 7)), P(add(g, ax, -7)), 1.2, 1.2), pal.steel, D(g) + 0.3);
        for (const σ of [1, -1]) push(hull(discPoly(add(g, ax, σ * 7.5), ax, 4.6, 8)), pal.plate, D(add(g, ax, σ * 7.5)) + 0.3);
      }
      break;
    }
    case 'goblet': {
      // A dumbbell held vertically against the chest, cupped under the top head.
      const upv = apply(s.trunk, [0, 1, 0]);
      const c = add(at, upv, 4);
      push(capsule2(P(add(c, upv, 7)), P(add(c, upv, -7)), 1.3, 1.3), pal.steel, D(at) + 0.6);
      for (const σ of [1, -1]) push(hull(discPoly(add(c, upv, σ * 7.5), upv, 5.2, 12)), pal.plate, D(at) + 0.61);
      break;
    }
    case 'kettlebell': {
      const c = add(at, [0, -7, 0], 1);
      push(sphere(c, 6.4), pal.plate, D(c) + 0.4);
      push(capsule2(P(at), P(add(at, [0, -2, 0])), 2.4, 2.4), pal.plate, D(at) + 0.4);
      break;
    }
    case 'medball': {
      const fwd = apply(s.chest, [1, 0, 0]);
      const c = add(at, fwd, 5);
      push(sphere(c, 7.5), pal.implementRed, D(c) + 0.6);
      break;
    }
    case 'plate': {
      const fwd = apply(s.chest, [1, 0, 0]);
      push(hull(discPoly(at, fwd, 11)), pal.plate, D(at) + 0.6);
      break;
    }
    case 'ball': case 'football': {
      const c = spec.at?.startsWith('foot') ? at : add(at, apply(s.chest, [1, 0, 0]), 4);
      push(sphere(c, spec.kind === 'football' ? 5 : 5.6), pal.implementRed, D(c) + 0.7);
      break;
    }
    case 'puck': {
      const c = add(s.L.toe, [10, 0.8, 0]);
      push(hull(discPoly(c, [0, 1, 0], 3.2, 10)), pal.shoe, D(c));
      break;
    }
    case 'bat': case 'club': case 'stick': case 'racket': case 'paddle': case 'javelin': case 'pole': case 'lacrosse': case 'bow': case 'oar': {
      const h = s[spec.at === 'R' ? 'R' : 'L'];
      const g = implementPoint(s, spec.at === 'R' ? 'R' : 'L');
      const lengths = { bat: 48, club: 58, stick: 56, racket: 30, paddle: 20, javelin: 70, pole: 62, lacrosse: 50, bow: 40, oar: 60 };
      const along = spec.kind === 'javelin' || spec.kind === 'pole' ? norm(add(handDir(h), apply(h.hand, [1, 0, 0]), 0)) : handDir(h);
      const dir = spec.kind === 'bow' ? apply(s.chest, [0, 1, 0]) : norm(add(along, apply(h.fore, [0, -1, 0]), 0.6));
      const start = spec.kind === 'javelin' ? add(g, dir, -30) : g;
      const tip = add(g, dir, lengths[spec.kind]);
      const thick = spec.kind === 'bat' ? [1.4, 2.8] : [1.1, 1.3];
      out.push(...segmented(start, tip, thick[0], thick[1], spec.kind === 'bat' ? pal.wood : pal.implementRed, 0, 8));
      if (spec.kind === 'racket' || spec.kind === 'paddle') {
        const head = add(g, dir, lengths[spec.kind] + (spec.kind === 'racket' ? 9 : 6));
        push(hull(discPoly(head, apply(h.hand, [1, 0, 0]), spec.kind === 'racket' ? 10 : 7, 16)), pal.implementRed, D(g) + 0.81, { outline: true });
      }
      if (spec.kind === 'stick' || spec.kind === 'club') {
        const fwd = norm([apply(s.root, [1, 0, 0])[0], 0, apply(s.root, [1, 0, 0])[2]]);
        push(capsule2(P(tip), P(add(tip, fwd, 9)), 1.6, 1.6), pal.implementRed, D(g) + 0.8);
      }
      break;
    }
    case 'disc': {
      const h = s[spec.at === 'R' ? 'R' : 'L'];
      const g = implementPoint(s, spec.at === 'R' ? 'R' : 'L');
      push(hull(discPoly(add(g, apply(h.hand, [1, 0, 0]), 3), apply(h.hand, [1, 0, 0]), 10.5, 18)), pal.implementRed, D(g) + 0.8);
      break;
    }
    case 'shot': {
      const g = implementPoint(s, spec.at === 'R' ? 'R' : spec.at === 'L' ? 'L' : 'hands');
      push(sphere(g, 4.8), pal.plate, D(g) + 0.8);
      break;
    }
    case 'rifle': case 'sword': {
      const h = s[spec.at === 'R' ? 'R' : 'L'];
      const g = implementPoint(s, spec.at === 'R' ? 'R' : 'L');
      const dir = spec.kind === 'rifle' ? norm(apply(h.fore, [0, -1, 0])) : norm(add(handDir(h), apply(h.fore, [0, -1, 0]), 1));
      const back = spec.kind === 'rifle' ? 22 : 2, fwdLen = spec.kind === 'rifle' ? 38 : 52;
      push(capsule2(P(add(g, dir, -back)), P(add(g, dir, fwdLen)), spec.kind === 'rifle' ? 2.2 : 0.8, spec.kind === 'rifle' ? 1.2 : 0.6),
        spec.kind === 'rifle' ? pal.plate : pal.steel, D(g) + 0.8);
      if (spec.kind === 'sword') push(hull(discPoly(add(g, dir, 2), dir, 4, 12)), pal.steel, D(g) + 0.81);
      break;
    }
    case 'glove': {
      const g = implementPoint(s, spec.at === 'R' ? 'R' : 'L');
      push(circlePts(P(g), 5.4, 16), pal.wood, D(g) + 0.9);
      break;
    }
    case 'board': {
      const l = s.L, r = s.R;
      const mid = scale(add(add(l.ankle, r.ankle), [0, 0, 0]), 0.5);
      const along = norm(sub(r.ankle, l.ankle));
      const a = add(add(mid, along, 38), [0, -2, 0]), b = add(add(mid, along, -38), [0, -2, 0]);
      push(capsule2(P(a), P(b), 2.2, 2.2), pal.implementRed, Math.min(D(l.ankle), D(r.ankle)) - 0.5);
      break;
    }
    case 'band': case 'cable': {
      const color = spec.kind === 'band' ? pal.implementRed : pal.steel;
      if (!spec.to) {
        // Stretched between the two hands (pull-aparts, dislocates).
        const a = implementPoint(s, 'L'), b = implementPoint(s, 'R');
        out.push(...segmented(a, b, 0.9, 0.9, color, 0, 8));
        break;
      }
      // Anchored: `to` is [forward, up, left] from the feet, in the body's own axes.
      const base = scale(add(s.L.ankle, s.R.ankle), 0.5);
      const ax = norm([apply(s.root, [1, 0, 0])[0], 0, apply(s.root, [1, 0, 0])[2]]);
      const az = norm([apply(s.root, [0, 0, 1])[0], 0, apply(s.root, [0, 0, 1])[2]]);
      const to = add(add(add([base[0], 0, base[2]], ax, spec.to[0]), [0, spec.to[1], 0]), az, spec.to[2] ?? 0);
      out.push(...segmented(at, to, 0.8, 0.8, color, 0, 10));
      if (spec.kind === 'cable') push(circlePts(P(to), 3, 10), pal.steel, D(to) - 0.3);
      break;
    }
    case 'landmine': {
      const g = implementPoint(s, spec.at ?? 'L');
      const ax = norm([apply(s.root, [1, 0, 0])[0], 0, apply(s.root, [1, 0, 0])[2]]);
      const pivot = add([g[0], 0, g[2]], ax, 95);
      out.push(...segmented(g, pivot, 1.3, 1.1, pal.steel, 0, 10));
      push(hull(discPoly(add(g, norm(sub(g, pivot)), -6), norm(sub(g, pivot)), 10, 16)), pal.plate, D(g) + 0.49);
      break;
    }
    case 'hockeystick': {
      // Shaft through both hands (top hand R, bottom hand L: a left shot),
      // continuing to the blade; the blade lies along the ice when it's down.
      // leftTop: field-hockey grip (left hand on top, ball on the right).
      const top = implementPoint(s, spec.leftTop ? 'L' : 'R'), bottom = implementPoint(s, spec.leftTop ? 'R' : 'L');
      const dir = norm(sub(bottom, top));
      // The shaft runs until it meets the ice (or its full length in the air).
      const length = spec.length ?? 128;
      const toIce = dir[1] < -0.15 ? (top[1] - 1) / -dir[1] : Infinity;
      const heel = add(top, dir, Math.min(length - 10, toIce));
      out.push(...segmented(add(top, dir, -6), heel, 1.3, 1.1, pal.plate, 0, 10));
      const fw = norm([apply(s.root, [1, 0, 0])[0], 0, apply(s.root, [1, 0, 0])[2]]);
      const bladeDir = norm(sub(fw, scale(dir, dot(fw, dir))));
      const toe = add(heel, bladeDir, 16);
      push(capsule2(P(heel), P(toe), 1.6, 1.4), pal.plate, D(heel) + 0.6);
      if (spec.puck) {
        const puck = add(add(heel, bladeDir, 9), fw, 5);
        if (spec.ball) push(sphere([puck[0], 3.6, puck[2]], 3.6), pal.implementRed, D(puck) + 0.5);
        else push(hull(discPoly([puck[0], 1, puck[2]], [0, 1, 0], 3.4, 12)), pal.shoe, D(puck) + 0.5);
      }
      break;
    }
    case 'lacrosse2': {
      // Two-handed lacrosse stick: bottom hand L near the butt, top hand R,
      // the shaft running on past the top hand to the head (the pocket faces forward).
      const lo = implementPoint(s, 'L'), hi = implementPoint(s, 'R');
      const dir = norm(sub(hi, lo));
      const fw = norm([apply(s.root, [1, 0, 0])[0], 0, apply(s.root, [1, 0, 0])[2]]);
      const face = norm(sub(fw, scale(dir, dot(fw, dir))));
      // `head`: bottom hand to the head (choked up for a face-off); the shaft is 104 long.
      const reachHead = spec.head ?? LACROSSE_HEAD;
      out.push(...segmented(add(lo, dir, reachHead - 104), add(lo, dir, reachHead - 7), 1.2, 1.2, pal.plate, 0, 10));
      const head = add(lo, dir, reachHead);
      push(hull(discPoly(head, face, 7.5, 16)), pal.steel, D(head) + 0.4);
      push(hull(discPoly(add(head, face, 0.4), face, 5.8, 16)), pal.plate, D(head) + 0.41);
      break;
    }
    case 'bat2': {
      // A bat gripped in both hands: bottom hand (L, at the knob) and top hand (R).
      const lo = implementPoint(s, 'L'), hi = implementPoint(s, 'R');
      const dir = norm(sub(hi, lo));
      out.push(...segmented(add(lo, dir, -3), add(lo, dir, 62), 1.3, 2.9, pal.wood, 0, 8));
      break;
    }
    case 'wheel': {
      const c = add(implementPoint(s, 'hands'), [0, -3, 0]);
      const lat3 = apply(s.chest, [0, 0, 1]);
      push(hull(discPoly(c, lat3, 7, 18)), pal.plate, D(c) + 0.6);
      push(capsule2(P(add(c, lat3, 11)), P(add(c, lat3, -11)), 1.2, 1.2), pal.steel, D(c) + 0.61);
      break;
    }
    case 'towels': {
      // A towel (or gi fabric) in each hand, hanging from the bar above.
      for (const side of ['L', 'R']) {
        const g = implementPoint(s, side);
        push(capsule2(P(add(g, [0, -4, 0])), P(add(g, [0, 24, 0])), 2.6, 2.6), '#E8E6DF', D(g) + 0.7);
      }
      break;
    }
    case 'map': {
      // A folded map held up in the left hand to read.
      const g = implementPoint(s, 'L');
      const fw = norm(apply(s.chest, [1, 0, 0])), up = norm(apply(s.chest, [0, 1, 0])), lat = norm(apply(s.chest, [0, 0, 1]));
      const c = add(add(g, up, 5), lat, -5);
      const pts = [[-7, -9], [7, -9], [7, 9], [-7, 9]].map(([a, b]) => P(add(add(c, lat, a), up, b)));
      push(hull(pts), '#F2EFE6', D(add(c, fw, 2)) + 0.6);
      push(hull([[-5, 2], [4, 6], [4, 7.5], [-5, 3.5]].map(([a, b]) => P(add(add(c, lat, a), up, b - 4)))), pal.implementRed, D(add(c, fw, 2)) + 0.61);
      break;
    }
    case 'kickboard': {
      const g = implementPoint(s, 'hands');
      const fw = norm([apply(s.root, [1, 0, 0])[0], 0, apply(s.root, [1, 0, 0])[2]]);
      const lat3 = norm(apply(s.root, [0, 0, 1]));
      const c = add(g, fw, 12);
      const pts = [];
      for (const [a, b] of [[-12, -14], [14, -14], [14, 14], [-12, 14]]) pts.push(P(add(add(c, fw, a), lat3, b)));
      push(hull(pts), pal.implementRed, D(c) + 0.5);
      break;
    }
    case 'jumprope': {
      // The rope's loop passing under the feet: hands → floor → hands.
      const a = implementPoint(s, 'L'), b = implementPoint(s, 'R');
      const low = Math.min(s.L.toe[1], s.R.toe[1]) - 1;
      const fw = norm([apply(s.root, [1, 0, 0])[0], 0, apply(s.root, [1, 0, 0])[2]]);
      const pts = [];
      for (let i = 0; i <= 16; i++) {
        const t = i / 16;
        const lateral = add(scale(a, 1 - t), b, t);
        const sag = Math.sin(t * Math.PI);
        pts.push(add([lateral[0], lateral[1] + (low - lateral[1]) * sag, lateral[2]], fw, 6 * sag));
      }
      for (let i = 0; i < pts.length - 1; i++) push(capsule2(P(pts[i]), P(pts[i + 1]), 0.6, 0.6), pal.implementRed, (D(pts[i]) + D(pts[i + 1])) / 2);
      break;
    }
    case 'wristroller': {
      const a = implementPoint(s, 'L'), b = implementPoint(s, 'R');
      out.push(...segmented(add(a, sub(a, b), 0.2), add(b, sub(b, a), 0.2), 1.5, 1.5, pal.steel, 0, 6));
      const mid = scale(add(a, b), 0.5);
      const low = add(mid, [0, -(spec.drop ?? 30), 0]);
      push(capsule2(P(mid), P(low), 0.5, 0.5), pal.steel, D(mid) + 0.4);
      push(hull(discPoly(low, [1, 0, 0], 6, 12)), pal.plate, D(mid) + 0.41);
      break;
    }
    case 'rope': {
      const fwd = norm([apply(s.root, [1, 0, 0])[0], 0, apply(s.root, [1, 0, 0])[2]]);
      const pts = [];
      for (let i = 0; i <= 10; i++) {
        const p = add(add(at, fwd, i * 8), [0, -at[1] * (i / 10) * 0.9 + Math.sin(i * 1.3 + (spec.phase ?? 0)) * 4, 0]);
        pts.push(p);
      }
      for (let i = 0; i < pts.length - 1; i++) push(capsule2(P(pts[i]), P(pts[i + 1]), 1.3, 1.3), pal.implementRed, (D(pts[i]) + D(pts[i + 1])) / 2);
      break;
    }
    default: break;
  }
  return out;
}

// ── Fixtures (things in the world) ─────────────────────────────────────

/**
 * `place` is the fixture resolved once per pattern (from keyframe 0) so it
 * never moves with the body: { origin: [x,y,z] } plus kind-specific numbers.
 */
export function fixtureShapes(s, fx, place, pal) {
  const out = [];
  if (!place) return out;
  const push = (points, fill, depth, extra = {}) => out.push({ points, fill, depth, ...extra });
  // Fixtures are laid out in the body's own axes (x forward, z left) around
  // place.origin, then turned with the camera view like the body is.
  const ax = apply(rotY(place.view ?? 0), [1, 0, 0]), az = apply(rotY(place.view ?? 0), [0, 0, 1]);
  const o = place.origin ?? [0, 0, 0];
  // A bike pitches about its rear-wheel contact and lifts; on a path the whole
  // fixture travels (turned and moved) with the athlete.
  const pitch = ((s.fx?.pitch ?? 0) * Math.PI) / 180, lift = s.fx?.lift ?? 0, shift = s.fx?.shift ?? 0;
  const pivot = fx.kind === 'bike' && place.crank ? place.crank[0] - 38 : o[0];
  const W = (x, y, z) => {
    let bx = x, by = y;
    if (pitch) {
      const dx = x - pivot;
      bx = pivot + dx * Math.cos(pitch) - y * Math.sin(pitch);
      by = dx * Math.sin(pitch) + y * Math.cos(pitch);
    }
    const q = add(add(add([o[0], 0, o[2]], ax, bx + shift - o[0]), [0, by + lift, 0]), az, (z ?? o[2]) - o[2]);
    return s.fxMove ? add(apply(rotY(s.fxMove.heading), q), s.fxMove.v) : q;
  };
  const box = (x0, x1, y0, y1, z0, z1, fill, dz = 0) => {
    const pts = [];
    for (const x of [x0, x1]) for (const y of [y0, y1]) for (const z of [z0, z1]) pts.push(P(W(x, y, z)));
    push(hull(pts), fill, D(W((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)) + dz);
  };
  switch (fx.kind) {
    case 'bench': {
      const { x0, x1, top, z } = place;
      box(x0, x1, top - 5, top, z - 12, z + 12, pal.pad, -30);
      for (const x of [x0 + 6, x1 - 6]) box(x - 2, x + 2, 0, top - 5, z - 9, z + 9, pal.steel, -31);
      break;
    }
    case 'box': {
      const { x0, x1, top, z } = place;
      box(x0, x1, 0, top, z - 20, z + 20, pal.wood, -40);
      break;
    }
    case 'wall': {
      const { x } = place;
      box(x, x + 6, 0, 150, -40, 40, pal.ground, -60);
      break;
    }
    case 'bar': {
      const at = W(...place.at);
      out.push(...segmented(add(at, az, 45), add(at, az, -45), 1.6, 1.6, pal.steel, 0, 14));
      for (const σ of [1, -1]) {
        const foot = add([at[0], 0, at[2]], az, σ * 45);
        push(capsule2(P(foot), P(add(at, az, σ * 45)), 1.4, 1.4), pal.steel, -60);
      }
      break;
    }
    case 'water': {
      // The pool: water behind the swimmer, a clear layer over whatever is
      // under the surface, and the surface line. Wide enough for any framing;
      // left out of the camera framing itself.
      const { level } = place;
      const sheet = [[-4000, -level], [4000, -level], [4000, -level + 600], [-4000, -level + 600]];
      push(sheet, pal.water, -1e5, { opacity: 0.35 });
      push(sheet, pal.water, 1e5, { opacity: 0.3, isBall: true });
      push([[-4000, -level - 0.6], [4000, -level - 0.6], [4000, -level + 0.6], [-4000, -level + 0.6]], pal.water, 1e5 + 1, { opacity: 0.9, isBall: true });
      // The pool deck at the edge, to climb out onto.
      if (place.deckX != null) push([[place.deckX, -place.deckTop], [4000, -place.deckTop], [4000, 600], [place.deckX, 600]], pal.ground, 1e5 + 2, { isBall: true });
      break;
    }
    case 'bike': {
      const { r } = place;
      const crank = W(...place.crank), seat = W(...place.seat), bars = W(...place.bars);
      const wheelAt = (dx) => W(place.crank[0] + dx, 22, place.crank[2]);
      const wheel = (c) => push(hull(discPoly(c, az, 22, 24)), 'none', -50, { stroke: pal.steel, width: 2 });
      wheel(wheelAt(-38));
      wheel(wheelAt(40));
      push(capsule2(P(crank), P(seat), 1.3, 1.3), pal.steel, -40);
      push(capsule2(P(seat), P(bars), 1.3, 1.3), pal.steel, -40);
      push(capsule2(P(crank), P(wheelAt(40)), 1.3, 1.3), pal.steel, -40);
      push(hull(discPoly(crank, az, r, 16)), 'none', -39, { stroke: pal.steel, width: 1 });
      break;
    }
    case 'rower': {
      const { rail0, rail1, foot, fly, seatTop } = place;
      const oz = o[2];
      box(rail0, rail1, seatTop - 8, seatTop - 4, oz - 5, oz + 5, pal.steel, -45);
      for (const x of [rail0 + 3, rail1 - 3]) box(x - 1.5, x + 1.5, 0, seatTop - 8, oz - 5, oz + 5, pal.steel, -46);
      // The seat rides under the pelvis (its forward position in body axes).
      const seatX = o[0] + dot(sub(s.pelvis, o), ax);
      box(seatX - 8, seatX + 8, seatTop - 4, seatTop, oz - 9, oz + 9, pal.pad, -20);
      push(hull(discPoly(W(fly[0], fly[1], oz), az, 16, 20)), pal.plate, -44);
      box(foot[0] - 2, foot[0] + 2, foot[1] - 4, foot[1] + 14, oz - 12, oz + 12, pal.steel, -30);
      break;
    }
    case 'incline': {
      // Seat plus a back pad along keyframe 0's trunk line.
      const { seatX, seatTop, padFrom, padTo } = place;
      box(seatX - 14, seatX + 12, seatTop - 5, seatTop, o[2] - 12, o[2] + 12, pal.pad, -30);
      push(capsule2(P(W(padFrom[0], padFrom[1], o[2])), P(W(padTo[0], padTo[1], o[2])), 5, 5), pal.pad, D(W(padFrom[0], padFrom[1], o[2] - 12)) - 30);
      box(seatX - 2, seatX + 2, 0, seatTop - 5, o[2] - 9, o[2] + 9, pal.steel, -31);
      break;
    }
    case 'mat': {
      const { x0, x1 } = place;
      box(x0, x1, 0, 1.5, -25, 25, pal.ground, -1e5 + 1);
      break;
    }
    case 'net': {
      const { x, top } = place;
      box(x - 0.6, x + 0.6, top - 40, top, -60, 60, pal.ground, 0);
      box(x - 1.2, x + 1.2, 0, top, -61, -59, pal.steel, -60);
      break;
    }
    case 'wheelchair': {
      const { seat } = place;
      const c = [seat[0] - 2, 26, seat[2]];
      push(hull(discPoly(W(c[0], c[1], o[2] - 13), az, 26, 24)), 'none', -40, { stroke: pal.steel, width: 2.4 });
      push(hull(discPoly(W(c[0], c[1], o[2] + 13), az, 26, 24)), 'none', 40, { stroke: pal.steel, width: 2.4 });
      box(seat[0] - 14, seat[0] + 10, seat[1] - 4, seat[1], o[2] - 12, o[2] + 12, pal.pad, -1);
      break;
    }
    case 'blocks': {
      // Starting blocks: a pedal behind each foot on a rail.
      for (const side of ['L', 'R']) {
        const [x, z] = place[side];
        box(x - 10, x - 2, 0, 9, z - 5, z + 5, pal.plate, -2);
      }
      const x0 = Math.min(place.L[0], place.R[0]) - 16, x1 = Math.max(place.L[0], place.R[0]);
      box(x0, x1, 0, 2, o[2] - 2, o[2] + 2, pal.steel, -3);
      break;
    }
    case 'racingchair': {
      // A racing wheelchair: big cambered wheels with push rims, a low
      // kneeling seat, and a long frame out to a small front wheel.
      const { seat } = place;
      const c = [seat[0] + 2, 33];
      for (const sd of [-1, 1]) {
        push(hull(discPoly(W(c[0], c[1], o[2] + sd * 19), az, 33, 28)), 'none', sd * 40, { stroke: pal.steel, width: 2.2 });
        push(hull(discPoly(W(c[0], c[1], o[2] + sd * 21), az, 24, 24)), 'none', sd * 41, { stroke: pal.plate, width: 1.6 });
      }
      box(seat[0] - 16, seat[0] + 16, seat[1] - 8, seat[1], o[2] - 12, o[2] + 12, pal.pad, -1);
      const front = [seat[0] + 120, 9];
      push(capsule2(P(W(seat[0] + 10, seat[1] - 4)), P(W(front[0], front[1] + 4)), 1.6, 1.4), pal.steel, D(W(seat[0] + 60, 20)) - 1);
      push(hull(discPoly(W(front[0], front[1]), az, 9, 18)), 'none', D(W(front[0], front[1])), { stroke: pal.steel, width: 1.8 });
      break;
    }
    case 'sled': {
      const { x } = place;
      box(x, x + 30, 0, 8, -16, 16, pal.steel, -5);
      box(x + 8, x + 12, 8, 40, -14, -10, pal.steel, -8);
      box(x + 8, x + 12, 8, 40, 10, 14, pal.steel, 8);
      break;
    }
    case 'roller': {
      const at = W(...place.at);
      push(hull([...discPoly(add(at, az, 15), az, 7, 16), ...discPoly(add(at, az, -15), az, 7, 16)]), pal.implementRed, D(at) - 2);
      break;
    }
    case 'kickball': {
      const c = W(place.ball[0], place.ball[1], place.ball[2]);
      push(circlePts(P(c), 5.8, 20), pal.implementRed, D(c) + 0.2);
      break;
    }
    case 'ball': {
      const { r } = place;
      const at = W(...place.at);
      push(circlePts(P(at), r, 28), pal.implementRed, D(at) - 12, { opacity: 0.9 });
      break;
    }
    case 'control': {
      // An orienteering control: a post with the orange-and-white flag.
      const { x } = place;
      box(x - 1, x + 1, 0, 70, -1, 1, pal.steel, -2);
      push(hull([P(W(x - 7, 84, o[2])), P(W(x + 7, 84, o[2])), P(W(x + 7, 70, o[2]))]), '#E8762B', D(W(x, 77, o[2])));
      push(hull([P(W(x - 7, 84, o[2])), P(W(x - 7, 70, o[2])), P(W(x + 7, 70, o[2]))]), '#F4F4F2', D(W(x, 77, o[2])) + 0.01);
      break;
    }
    case 'hurdle': case 'cone': case 'ladder': {
      const { x } = place;
      if (fx.kind === 'cone') push([P([x - 5, 0, 0]), P([x + 5, 0, 0]), P([x, 14, 0])], pal.implementRed, -20);
      else if (fx.kind === 'hurdle') {
        box(x - 1, x + 1, 0, 26, -20, -18, pal.steel, -30);
        box(x - 1, x + 1, 0, 26, 18, 20, pal.steel, 30);
        box(x - 1.5, x + 1.5, 23, 27, -20, 20, pal.implementRed, 0);
      } else for (let i = 0; i < 4; i++) box(x + i * 18, x + i * 18 + 1.5, 0, 0.8, -18, 18, pal.implementRed, -1e5 + 2);
      break;
    }
    default: break;
  }
  return out;
}
