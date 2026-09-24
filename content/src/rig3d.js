/**
 * The exercise rig — a 3D skeleton driven by joint angles, played through
 * authored keyframes, and projected for drawing. §9 job 2.
 *
 * This file is the single source of truth for the maths. RigPoseView.swift
 * implements exactly the same functions (and a unit test there checks its
 * joint positions against golden samples this file generates), and
 * content/tools/renderRig.mjs draws previews with it.
 *
 * World axes: x = the athlete's forward (at turn 0), y = up, z = the
 * athlete's left. The camera sits on +z (so in the side view the athlete
 * faces screen-right and their LEFT side is the near side), raised by a
 * small pitch so the floor reads as a floor.
 *
 * Angles, all in degrees (see JOINTS):
 *   spine      trunk lean from vertical, + forward (90 = prone, −90 = supine)
 *   bend       trunk side-bend, + toward the left side
 *   twist      chest rotation relative to the pelvis, + turning left
 *   turn       whole-body yaw, + turning left (90 = facing the camera in side view)
 *   neck       + chin down;  neckTurn + looking left
 *   shoulder   flexion, + forward/up (90 level, 180 overhead), − behind
 *   shoulderAbd  abduction, + out to the side (90 = T-pose)
 *   shoulderRot  humeral rotation, + internal
 *   elbow      0 straight, + bent;  wrist + flexed toward the palm
 *   hip        flexion relative to the trunk, + forward (90 = sitting)
 *   hipAbd     + out to the side;  hipRot + internal (knee turns in)
 *   knee       0 straight, + heel back;  ankle + shin over toes (dorsiflexion)
 *   lift       extra height off the support (jumps)
 * Joint names ending in L are the athlete's left, R the right.
 */

export const BONES = {
  torso: 42, neck: 7, headR: 9, upperArm: 27, forearm: 24, hand: 8,
  thigh: 40, shin: 39, foot: 15, heel: 3.5,
  shoulderHalf: 15, hipHalf: 8, hipDrop: 2,
};

export const SIDE_JOINTS = ['shoulder', 'shoulderAbd', 'shoulderRot', 'elbow', 'wrist', 'hip', 'hipAbd', 'hipRot', 'knee', 'ankle'];
export const CENTRE_JOINTS = ['spine', 'bend', 'twist', 'turn', 'neck', 'neckTurn', 'lift'];
export const JOINTS = [...CENTRE_JOINTS, ...SIDE_JOINTS.flatMap((j) => [`${j}L`, `${j}R`])];

/** Camera presets (degrees of yaw applied to the whole body). */
export const VIEWS = { side: 0, front: 90, 'three-quarter': 38, back: -90, 'rear-three-quarter': -142 };
export const CAMERA_PITCH = 8;

// ── Vector / matrix maths (3x3 matrices, column-major arrays of columns) ──

const rad = (d) => (d * Math.PI) / 180;
export const add = (a, b, k = 1) => [a[0] + b[0] * k, a[1] + b[1] * k, a[2] + b[2] * k];
export const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
export const scale = (a, k) => [a[0] * k, a[1] * k, a[2] * k];
export const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
export const len = (a) => Math.hypot(a[0], a[1], a[2]);
export const norm = (a) => { const l = len(a) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };

/** m = [col0, col1, col2]; apply to vector v. */
export const apply = (m, v) => [
  m[0][0] * v[0] + m[1][0] * v[1] + m[2][0] * v[2],
  m[0][1] * v[0] + m[1][1] * v[1] + m[2][1] * v[2],
  m[0][2] * v[0] + m[1][2] * v[1] + m[2][2] * v[2],
];
export const mul = (a, b) => [apply(a, b[0]), apply(a, b[1]), apply(a, b[2])];
export const IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]];

/** Rotation about local z: + turns "down" toward "forward" (and up toward back). */
export function rotZ(deg) {
  const c = Math.cos(rad(deg)), s = Math.sin(rad(deg));
  return [[c, s, 0], [-s, c, 0], [0, 0, 1]];
}
/** Rotation about local x: + turns "up" toward "left" (and down toward right). */
export function rotX(deg) {
  const c = Math.cos(rad(deg)), s = Math.sin(rad(deg));
  return [[1, 0, 0], [0, c, s], [0, -s, c]];
}
/** Rotation about local y: + turns "forward" toward "left" (a left turn). */
export function rotY(deg) {
  const c = Math.cos(rad(deg)), s = Math.sin(rad(deg));
  return [[c, 0, s], [0, 1, 0], [-s, 0, c]];
}

// ── Forward kinematics ────────────────────────────────────────────────────

/**
 * Joint positions for one pose, pelvis at the origin, before any contact or
 * ground placement. `view` is extra body yaw for the camera. Returns frames
 * too, because the renderer needs limb orientation for shading.
 */
export function skeleton(pose, { view = 0, mirrored = false } = {}) {
  const a = (j) => {
    const name = mirrored ? mirrorJoint(j) : j;
    return pose[name] ?? 0;
  };
  const root = rotY(view + (mirrored ? -a('turn') : a('turn')));
  const trunk = mul(mul(root, rotZ(-a('spine'))), rotX(mirrored ? -a('bend') : a('bend')));
  const chest = mul(trunk, rotY(mirrored ? -a('twist') : a('twist')));
  const pelvis = [0, 0, 0];
  const neckBase = apply(trunk, [0, BONES.torso, 0]);
  const headFrame = mul(mul(chest, rotZ(-a('neck'))), rotY(mirrored ? -a('neckTurn') : a('neckTurn')));
  const neckTop = add(neckBase, apply(headFrame, [0, BONES.neck, 0]));
  const head = add(neckTop, apply(headFrame, [0.8, BONES.headR * 0.85, 0]));

  const side = (s) => {
    const σ = s === 'L' ? 1 : -1;
    const shoulder = add(neckBase, apply(chest, [0, -3, σ * BONES.shoulderHalf]));
    const arm = mul(mul(mul(chest, rotZ(a(`shoulder${s}`))), rotX(-σ * a(`shoulderAbd${s}`))), rotY(-σ * a(`shoulderRot${s}`)));
    const elbow = add(shoulder, apply(arm, [0, -BONES.upperArm, 0]));
    const fore = mul(arm, rotZ(a(`elbow${s}`)));
    const wrist = add(elbow, apply(fore, [0, -BONES.forearm, 0]));
    const hand = mul(fore, rotZ(a(`wrist${s}`)));
    const handTip = add(wrist, apply(hand, [0, -BONES.hand, 0]));

    const hip = add(pelvis, apply(trunk, [0, -BONES.hipDrop, σ * BONES.hipHalf]));
    const thigh = mul(mul(mul(trunk, rotZ(a(`hip${s}`))), rotX(-σ * a(`hipAbd${s}`))), rotY(-σ * a(`hipRot${s}`)));
    const knee = add(hip, apply(thigh, [0, -BONES.thigh, 0]));
    const shin = mul(thigh, rotZ(-a(`knee${s}`)));
    const ankle = add(knee, apply(shin, [0, -BONES.shin, 0]));
    const foot = mul(shin, rotZ(a(`ankle${s}`)));
    return { shoulder, arm, elbow, fore, wrist, hand, handTip, hip, thigh, knee, shin, ankle, foot };
  };
  const L = side('L'), R = side('R');
  // A mirrored item swaps sides, so the camera still sees the athlete's
  // left as the near side: reflect z.
  return finishFeet({ root, trunk, chest, headFrame, pelvis, neckBase, neckTop, head, L, R, mirrored, twist: mirrored ? -a('twist') : a('twist') });
}

function finishFeet(s) {
  for (const k of ['L', 'R']) {
    const l = s[k];
    l.footDir = apply(l.foot, [1, 0, 0]);
    l.toe = add(l.ankle, l.footDir, BONES.foot);
    l.heel = add(l.ankle, l.footDir, -BONES.heel);
  }
  return s;
}

export function mirrorJoint(j) {
  if (j.endsWith('L')) return j.slice(0, -1) + 'R';
  if (j.endsWith('R')) return j.slice(0, -1) + 'L';
  return j;
}

/**
 * Every point that can touch the floor, with the body's thickness there:
 * [point, radius]. The torso and head carry surface points so a body lying
 * down rests on its back, not its spine.
 */
export function contactPoints(s) {
  const fwd = apply(s.trunk, [1, 0, 0]);
  const up = apply(s.trunk, [0, 1, 0]);
  const lat = apply(s.trunk, [0, 0, 1]);
  const chest = add(s.pelvis, up, BONES.torso * 0.75);
  const pts = [
    [add(s.pelvis, fwd, 8), 0], [add(s.pelvis, fwd, -9.5), 0], [add(s.pelvis, lat, 13), 0], [add(s.pelvis, lat, -13), 0],
    [add(chest, fwd, 10), 0], [add(chest, fwd, -9.2), 0], [add(chest, lat, 15), 0], [add(chest, lat, -15), 0],
    [s.head, BONES.headR], [s.neckTop, 4],
    // The sit bones, so a body sitting on the floor rests on them.
    [add(s.pelvis, up, -9), 0],
  ];
  for (const l of [s.L, s.R]) {
    pts.push([l.shoulder, 5], [l.elbow, 3.8], [l.wrist, 2.7], [l.handTip, 1.5], [l.knee, 5.2], [l.ankle, 0], [l.toe, 0], [l.heel, 0]);
  }
  return pts;
}

/** Points that bound the body (for framing). */
export function bodyPoints(s) {
  return contactPoints(s).map(([p, r]) => add(p, [0, -r, 0]));
}

/** The lowest surface of the body (its y). */
export function lowestY(s) {
  return Math.min(...contactPoints(s).map(([p, r]) => p[1] - r));
}

export function translate(s, v) {
  const t = (p) => add(p, v);
  const limb = (l) => ({ ...l, shoulder: t(l.shoulder), elbow: t(l.elbow), wrist: t(l.wrist), handTip: t(l.handTip), hip: t(l.hip), knee: t(l.knee), ankle: t(l.ankle), toe: t(l.toe), heel: t(l.heel) });
  return { ...s, pelvis: t(s.pelvis), neckBase: t(s.neckBase), neckTop: t(s.neckTop), head: t(s.head), L: limb(s.L), R: limb(s.R) };
}

/** Lays a foot flat on the floor (weight w, 0–1) keeping its heading. */
function flattenFoot(l, w) {
  if (w <= 0) return l;
  const heading = apply(l.shin, [1, 0, 0]);
  const flat = norm([heading[0], 0, heading[2]]);
  const dir = norm(add(scale(l.footDir, 1 - w), scale(flat, w)));
  return { ...l, footDir: dir, toe: add(l.ankle, dir, BONES.foot), heel: add(l.ankle, dir, -BONES.heel) };
}

// ── Contacts and playback ─────────────────────────────────────────────────

/**
 * What holds the body in place during a keyframe:
 *   feet   both feet flat on the floor         L / R   one foot flat
 *   hands  hands on the floor (push-ups)        grip    hanging from a bar
 *   seat   sitting on a fixture                 back    lying on the back
 *   front  lying face down                      air     nothing (jumps, strides)
 *   water  floating (swimming)                  box     feet flat on a box (see `surface`)
 */
/**
 * Contacts, joinable with '+': feet (both flat), L / R (one foot flat),
 * Ltoe / Rtoe (on the ball of that foot), hands, Lhand / Rhand, knees,
 * Lknee / Rknee, grip (hanging), seat (sitting on a fixture), back / front
 * (lying), air, water. e.g. 'L+Rtoe' is a split stance, 'hands+feet' a
 * bear crawl.
 */
export const CONTACT_TOKENS = ['feet', 'L', 'R', 'Ltoe', 'Rtoe', 'Lheel', 'Rheel', 'hands', 'Lhand', 'Rhand', 'knees', 'Lknee', 'Rknee',
  'grip', 'seat', 'back', 'front', 'air', 'water'];
export const CONTACTS = CONTACT_TOKENS;
export const isContact = (c) => typeof c === 'string' && c.split('+').every((t) => CONTACT_TOKENS.includes(t));

function tokens(contact) {
  const set = new Set(contact.split('+'));
  if (set.has('feet')) { set.add('L'); set.add('R'); }
  if (set.has('hands')) { set.add('Lhand'); set.add('Rhand'); }
  if (set.has('knees')) { set.add('Lknee'); set.add('Rknee'); }
  return set;
}
const footFlat = (contact, side) => tokens(contact).has(side);
const footPlant = (t, side) => (t.has(side) ? 'ankle' : t.has(`${side}toe`) ? 'toe' : t.has(`${side}heel`) ? 'heel' : null);

/**
 * What two consecutive keyframes both hold still — the anchor for the move
 * between them: { kind, parts: [[side, point], ...] } or null.
 */
function sharedContact(a, b) {
  const ta = tokens(a), tb = tokens(b);
  const parts = [];
  for (const side of ['L', 'R']) {
    const pa = footPlant(ta, side), pb = footPlant(tb, side);
    if (pa && pb) parts.push([side, pa === pb ? pa : pa === 'ankle' ? pb : pb === 'ankle' ? pa : 'ankle']);
  }
  for (const side of ['L', 'R']) {
    if (ta.has(`${side}hand`) && tb.has(`${side}hand`)) parts.push([side, 'wrist']);
    if (ta.has(`${side}knee`) && tb.has(`${side}knee`)) parts.push([side, 'knee']);
  }
  // Grip, seat and water hold the body's height themselves; any planted
  // feet/hands still pin where it sits (e.g. a rower's feet on the foot plate).
  for (const pin of ['grip', 'seat', 'water']) if (ta.has(pin) && tb.has(pin)) return { kind: pin, parts };
  return parts.length ? { kind: 'parts', parts } : null;
}

/** The world point a shared contact pins in place. */
function anchorPoint(s, shared) {
  if (shared.parts.length) {
    const pts = shared.parts.map(([side, point]) => s[side][point]);
    return scale(pts.reduce((acc, p) => add(acc, p), [0, 0, 0]), 1 / pts.length);
  }
  if (shared.kind === 'grip') return scale(add(s.L.wrist, s.R.wrist), 0.5);
  return s.pelvis;
}

/** The point whose height a self-pinning contact holds. */
function heightPoint(s, shared) {
  return shared.kind === 'grip' ? scale(add(s.L.wrist, s.R.wrist), 0.5) : s.pelvis;
}

/** Does this contact fix the body's height itself (not via the floor)? */
const pinsHeight = (shared) => !!shared && (shared.kind === 'grip' || shared.kind === 'seat' || shared.kind === 'water');
const selfPinned = (contact) => { const t = tokens(contact); return t.has('grip') || t.has('seat') || t.has('water'); };

export const lerp = (a, b, t) => a + (b - a) * t;
export function lerpPose(a, b, t) {
  const out = {};
  for (const j of JOINTS) out[j] = lerp(a[j] ?? 0, b[j] ?? 0, t);
  return out;
}
export const smooth = (t) => t * t * (3 - 2 * t);

/**
 * Easing for the move that starts at keyframe k. A run of solved in-between
 * keyframes shares one smooth curve: k.chain = [index, count] maps this
 * segment onto its slice of that curve, so the body never stops mid-move.
 */
export function ease(k, u) {
  const [index, count] = k.chain ?? [0, 1];
  return smooth((index + u) / count) * count - index;
}

/**
 * A pattern's keyframes placed in the world: each keyframe's offset so that
 * whatever a contact pins stays pinned from one keyframe to the next.
 */
export function placeKeyframes(pattern, opts = {}) {
  const view = opts.view ?? VIEWS[pattern.view ?? 'side'] ?? 0;
  const frames = pattern.keyframes;
  const raw = frames.map((k) => skeleton(k.pose, { view, mirrored: opts.mirrored }));
  const offsets = [];
  for (let i = 0; i < frames.length; i++) {
    const s = flattenBoth(raw[i], frames[i].contact, frames[i].contact);
    const surface = frames[i].surface ?? 0;
    if (i === 0) {
      offsets.push([0, contactY(s, frames[i].contact, surface, frames[i].pose.lift ?? 0), 0]);
      continue;
    }
    const prev = frames[i - 1];
    const shared = sharedContact(prev.contact, frames[i].contact);
    let x, z;
    if (shared) {
      const prevS = flattenBoth(raw[i - 1], prev.contact, prev.contact);
      const pinned = add(anchorPoint(prevS, shared), offsets[i - 1]);
      const here = anchorPoint(s, shared);
      x = pinned[0] - here[0];
      z = pinned[2] - here[2];
    } else {
      // Travel is authored in the body's own axes (forward, left) and turned
      // with the camera view like everything else.
      const t = frames[i].travel ?? [0, 0];
      const w = apply(rotY(view), [t[0], 0, t[1] ?? 0]);
      x = offsets[i - 1][0] + w[0];
      z = offsets[i - 1][2] + w[2];
    }
    const pinnedHeight = pinsHeight(shared) ? heightPin(raw[i - 1], raw[i], prev, frames[i], offsets[i - 1], shared) : null;
    offsets.push([x, pinnedHeight ?? contactY(s, frames[i].contact, surface, frames[i].pose.lift ?? 0), z]);
  }
  return { view, raw, offsets };
}

function heightPin(prevRaw, raw, prev, cur, prevOffset, shared) {
  const a = heightPoint(flattenBoth(prevRaw, prev.contact, prev.contact), shared);
  const b = heightPoint(flattenBoth(raw, cur.contact, cur.contact), shared);
  // In water, `surface` sets how much deeper the body goes (a flip turn).
  const deeper = shared.kind === 'water' ? (cur.surface ?? 0) - (prev.surface ?? 0) : 0;
  return a[1] + prevOffset[1] - b[1] + deeper;
}


function flattenBoth(s, c0, c1, u = 0) {
  const w = (side) => lerp(footFlat(c0, side) ? 1 : 0, footFlat(c1, side) ? 1 : 0, u);
  return { ...s, L: flattenFoot(s.L, w('L')), R: flattenFoot(s.R, w('R')) };
}

/**
 * y offset from a keyframe's contact: a planted foot, the hands or the knees
 * set the body's height themselves (so a swinging limb can never lift or
 * drop it); otherwise the lowest body point rests on the surface.
 */
function contactY(s, contact, surface, lift) {
  const t = tokens(contact);
  const heights = [];
  for (const side of ['L', 'R']) {
    if (t.has(side)) heights.push(s[side].ankle[1]);
    else if (t.has(`${side}toe`)) heights.push(s[side].toe[1]);
    else if (t.has(`${side}heel`)) heights.push(s[side].heel[1]);
    if (t.has(`${side}hand`)) heights.push(Math.min(s[side].wrist[1] - 2.7, s[side].handTip[1] - 1.5));
    if (t.has(`${side}knee`)) heights.push(s[side].knee[1] - 5.2);
  }
  return heights.length ? surface - Math.min(...heights) : groundY(s, surface, lift);
}

/** y offset that sets the lowest body point on the support surface. */
function groundY(s, surface, lift) {
  return surface - lowestY(s) + lift;
}

/**
 * The world skeleton at playback time `t` in [0, 1) of one cycle.
 * Rep patterns hold each keyframe, move between them, then cut back to the
 * first; loop patterns move continuously and wrap from the last to the first.
 */
export function frameAt(pattern, t, placed = placeKeyframes(pattern), cast = null) {
  const { segment, u } = timing(pattern, t);
  let s = bodyAt(pattern, segment, u, placed);
  // The fixture's own motion (a bike pitching up for a manual, lifting in a jump).
  if (pattern.fixture) {
    const k0 = pattern.keyframes[segment], k1 = pattern.keyframes[(segment + 1) % pattern.keyframes.length];
    const e = ease(k0, u);
    const fx = { pitch: lerp(k0.fx?.pitch ?? 0, k1.fx?.pitch ?? 0, e), lift: lerp(k0.fx?.lift ?? 0, k1.fx?.lift ?? 0, e), shift: lerp(k0.fx?.shift ?? 0, k1.fx?.shift ?? 0, e) };
    // The rider goes where the bike goes.
    if (fx.shift || fx.lift) s = translate(s, add(apply(rotY(placed.view), [fx.shift, 0, 0]), [0, fx.lift, 0]));
    s.fx = fx;
  }
  if (pattern.ball) s.ball = ballAt(pattern, segment, u, s, placed, cast ?? (pattern.cast ? castAt(pattern, t, placed) : null));
  return s;
}

/**
 * The ball, for patterns that have one: each keyframe says where it is —
 * in a hand ('L', 'R', 'hands', 'Ldown'/'Rdown' under the palm for a
 * dribble), at a foot ('footL'), on the floor under a hand
 * ({ floor: 'L', dx }), at a point relative to that keyframe's pelvis
 * ({ at: [forward, up, left] }), or 'none'. It moves between keyframes,
 * riding the hand when held, arcing when `ballArc` is set on the keyframe
 * it leaves from.
 */
export function ballAt(pattern, segment, u, s, placed, cast = null) {
  const n = pattern.keyframes.length;
  const i = segment, j = (segment + 1) % n;
  const k0 = pattern.keyframes[i], k1 = pattern.keyframes[j];
  const e = ease(k0, u);
  const b0 = ballPoint(pattern, i, s, placed, cast), b1 = ballPoint(pattern, j, s, placed, cast);
  if (!b0 && !b1) return null;
  if (!b0) return e > 0.5 ? b1 : null;
  if (!b1) return e < 0.5 ? b0 : null;
  const p = add(scale(b0, 1 - e), b1, e);
  return add(p, [0, (k0.ballArc ?? 0) * 4 * e * (1 - e), 0]);
}

function ballPoint(pattern, index, current, placed, cast = null) {
  let spec = pattern.keyframes[index].ball ?? 'hands';
  const r = pattern.ball.r ?? 6;
  if (spec === 'none') return null;
  const grip = (l) => add(l.wrist, apply(l.hand, [0, -1, 0]), 3.5);
  const inHand = (sk, side) => add(grip(sk[side]), apply(sk[side].hand, [1, 0, 0]), r * 0.9);
  const under = (sk, side) => add(grip(sk[side]), [0, -(r + 1.5), 0]);
  // 'c0:L' — with cast member 0 (in their hand, at their foot, their stick…).
  let sk = current, impl = pattern.implement;
  if (typeof spec === 'string' && /^c\d+:/.test(spec)) {
    const idx = Number(spec.slice(1, spec.indexOf(':')));
    const member = cast?.[idx];
    if (!member) return null;
    sk = member.s;
    impl = member.ref.implement;
    spec = spec.slice(spec.indexOf(':') + 1);
  }
  if (typeof spec === 'string') {
    if (spec === 'head') return implementHead(impl, sk, r);
    switch (spec) {
      case 'L': case 'R': return inHand(sk, spec);
      case 'Ldown': return under(sk, 'L');
      case 'Rdown': return under(sk, 'R');
      case 'footL': case 'footR': { const l = sk[spec.slice(-1)]; return add(add(l.toe, apply(sk.root, [1, 0, 0]), r * 0.6), [0, r - l.toe[1] + l.toe[1], 0]); }
      default: return add(scale(add(grip(sk.L), grip(sk.R)), 0.5), apply(sk.chest, [1, 0, 0]), r * 0.8);
    }
  }
  const k = keyframeAt(pattern, index, placed);
  const fw = apply(rotY(placed.view), [1, 0, 0]), lt = apply(rotY(placed.view), [0, 0, 1]);
  if (spec.floor) {
    const g = spec.floor === 'hands' ? scale(add(grip(k.L), grip(k.R)), 0.5) : grip(k[spec.floor]);
    return add(add([g[0], r + (pattern.keyframes[index].surface ?? 0), g[2]], fw, spec.dx ?? 0), lt, spec.dl ?? 0);
  }
  const [f, h, l] = spec.at;
  return add(add(add(k.pelvis, fw, f), [0, h, 0]), lt, l ?? 0);
}

/**
 * Where a held implement meets the ball: a racket or paddle's strings, a
 * bat's barrel, a club's face (same geometry rigDraw.js draws).
 */
/** Bottom hand to the centre of a lacrosse head. */
export const LACROSSE_HEAD = 96;
export const IMPLEMENT_LENGTHS = { bat: 48, club: 58, stick: 56, racket: 30, paddle: 20, lacrosse: 50 };
export function implementHead(spec, sk, r = 0) {
  const kind = spec?.kind ?? 'racket';
  const gripOf = (l) => add(l.wrist, apply(l.hand, [0, -1, 0]), 3.5);
  const fwFlat = () => { const f = apply(sk.root, [1, 0, 0]); return norm([f[0], 0, f[2]]); };
  if (kind === 'hockeystick') {
    // On the blade, on the ground (same geometry rigDraw.js draws).
    const top = gripOf(spec.leftTop ? sk.L : sk.R), dir = norm(sub(gripOf(spec.leftTop ? sk.R : sk.L), top));
    const length = spec.length ?? 128;
    const toIce = dir[1] < -0.15 ? (top[1] - 1) / -dir[1] : Infinity;
    const heel = add(top, dir, Math.min(length - 10, toIce));
    const fw = fwFlat();
    const blade = norm(sub(fw, scale(dir, dot(fw, dir))));
    const p = add(add(heel, blade, 9), fw, 5);
    return [p[0], Math.max(r, heel[1]), p[2]];
  }
  if (kind === 'lacrosse2') {
    // In the pocket of a two-handed stick (bottom hand L, top hand R).
    const lo = gripOf(sk.L), dir = norm(sub(gripOf(sk.R), lo));
    const fw = fwFlat();
    const face = norm(sub(fw, scale(dir, dot(fw, dir))));
    return add(add(lo, dir, spec.head ?? LACROSSE_HEAD), face, Math.max(0, r - 2));
  }
  if (kind === 'bat2') {
    // Two-handed bat: the sweet spot 48 along the line from the knob hand.
    const grip = (l) => add(l.wrist, apply(l.hand, [0, -1, 0]), 3.5);
    const lo = grip(sk.L), hi = grip(sk.R);
    return add(lo, norm(sub(hi, lo)), 48);
  }
  const h = sk[spec?.at === 'L' ? 'L' : 'R'];
  const grip = add(h.wrist, apply(h.hand, [0, -1, 0]), 3.5);
  const dir = norm(add(apply(h.hand, [0, -1, 0]), apply(h.fore, [0, -1, 0]), 0.6));
  const len = IMPLEMENT_LENGTHS[kind] ?? 30;
  const along = kind === 'racket' ? len + 9 : kind === 'paddle' ? len + 6 : kind === 'bat' ? len - 8 : len;
  const face = apply(h.hand, [1, 0, 0]);
  return add(add(grip, dir, along), face, r + 1);
}

function bodyAt(pattern, segment, u, placed) {
  const k0 = pattern.keyframes[segment], k1 = pattern.keyframes[(segment + 1) % pattern.keyframes.length];
  const base = lerpPose(k0.pose, k1.pose, ease(k0, u));
  let s = frameFor(pattern, segment, u, base, placed);
  // Swing-leg clearance: a foot that isn't planted bends its knee (as a
  // real swing leg does) rather than sweep through the floor.
  const shared = sharedContact(k0.contact, k1.contact);
  if (!shared || shared.kind !== 'parts') return s;
  const planted = new Set(shared.parts.filter(([, point]) => point === 'ankle' || point === 'toe' || point === 'heel').map(([side]) => side));
  const surface = Math.min(k0.surface ?? 0, k1.surface ?? 0);
  let pose = base;
  for (const side of ['L', 'R']) {
    if (planted.has(side)) continue;
    const low = (sk) => Math.min(sk[side].ankle[1], sk[side].toe[1], sk[side].heel[1]) - surface;
    for (let n = 0; n < 40 && low(s) < -0.5 && pose[`knee${side}`] < 150; n++) {
      pose = { ...pose, [`knee${side}`]: pose[`knee${side}`] + 3 };
      s = frameFor(pattern, segment, u, pose, placed);
    }
  }
  return s;
}

function frameFor(pattern, segment, u, pose, placed) {
  const frames = pattern.keyframes;
  const i = segment, j = (segment + 1) % frames.length;
  const k0 = frames[i], k1 = frames[j];
  const e = ease(k0, u);
  const view = placed.view;
  let s = skeleton(pose, { view, mirrored: false });
  s = flattenBoth(s, k0.contact, k1.contact, e);
  const shared = sharedContact(k0.contact, k1.contact);
  const o0 = placed.offsets[i];
  // Wrapping a loop: the last→first segment returns to keyframe 0's offset.
  const o1 = j === 0 ? placed.offsets[0] : placed.offsets[j];
  let x = lerp(o0[0], o1[0], e), z = lerp(o0[2], o1[2], e);
  if (shared) {
    const s0 = flattenBoth(placed.raw[i], k0.contact, k0.contact);
    const pinned = add(anchorPoint(s0, shared), o0);
    const here = anchorPoint(s, shared);
    x = pinned[0] - here[0];
    z = pinned[2] - here[2];
  }
  let y;
  const surface = lerp(k0.surface ?? 0, k1.surface ?? 0, e);
  if (shared && pinsHeight(shared)) {
    const s0 = flattenBoth(placed.raw[i], k0.contact, k0.contact);
    y = heightPoint(s0, shared)[1] + o0[1] - heightPoint(s, shared)[1];
    if (shared.kind === 'water') y += ((k1.surface ?? 0) - (k0.surface ?? 0)) * e;
  } else if (selfPinned(k0.contact) || selfPinned(k1.contact)) {
    y = lerp(o0[1], o1[1], e);
  } else if (shared) {
    y = contactY(s, shared.parts.map(([side, point]) => (point === 'ankle' ? side : point === 'toe' ? `${side}toe` : point === 'heel' ? `${side}heel` : point === 'wrist' ? `${side}hand` : `${side}knee`)).join('+'), surface, pose.lift ?? 0);
  } else {
    // Changing support (a step, a take-off, a landing): blend what each
    // keyframe's own contact says, so both ends match their keyframes.
    y = lerp(contactY(s, k0.contact, k0.surface ?? 0, pose.lift ?? 0), contactY(s, k1.contact, k1.surface ?? 0, pose.lift ?? 0), e);
    // …and never lets a swinging limb dip through the floor on the way.
    y = Math.max(y, groundY(s, Math.min(k0.surface ?? 0, k1.surface ?? 0), 0));
  }
  return translate(s, [x, y, z]);
}

/** Keyframe `i` exactly as placed (for thumbnails and tests). */
export function keyframeAt(pattern, i, placed = placeKeyframes(pattern)) {
  const k = pattern.keyframes[i];
  const s = flattenBoth(placed.raw[i], k.contact, k.contact);
  return translate(s, placed.offsets[i]);
}

/**
 * Which segment and how far along it, for a cycle position t in [0, 1).
 * Each keyframe has a hold (seconds) and each move a duration (seconds).
 */
export function timing(pattern, t) {
  const frames = pattern.keyframes;
  const n = frames.length;
  const moves = pattern.loop ? n : n - 1;
  const spans = [];
  for (let i = 0; i < n; i++) {
    spans.push({ kind: 'hold', i, d: frames[i].hold ?? 0 });
    if (i < moves) spans.push({ kind: 'move', i, d: frames[i].move ?? 0.6 });
  }
  const total = spans.reduce((a, b) => a + b.d, 0);
  let at = ((t % 1) + 1) % 1 * total;
  for (const span of spans) {
    if (at <= span.d || span === spans[spans.length - 1]) {
      if (span.kind === 'hold') {
        // Holding keyframe i: as segment i at u = 0 (or the last keyframe at u = 1).
        if (span.i === n - 1 && !pattern.loop) return { segment: Math.max(0, n - 2), u: 1 };
        return { segment: span.i, u: 0 };
      }
      return { segment: span.i, u: span.d > 0 ? Math.min(1, at / span.d) : 1 };
    }
    at -= span.d;
  }
  return { segment: 0, u: 0 };
}

/** Seconds for one full cycle. */
export function cycleSeconds(pattern) {
  const frames = pattern.keyframes;
  const moves = pattern.loop ? frames.length : frames.length - 1;
  let total = 0;
  for (let i = 0; i < frames.length; i++) {
    total += frames[i].hold ?? 0;
    if (i < moves) total += frames[i].move ?? 0.6;
  }
  return total;
}

// ── Projection ────────────────────────────────────────────────────────────

/** World → screen (x right, y down) plus depth (bigger = nearer the camera). */
export function project(p, pitch = CAMERA_PITCH) {
  const c = Math.cos(rad(pitch)), s = Math.sin(rad(pitch));
  return { x: p[0], y: -(p[1] * c - p[2] * s), depth: p[2] * c + p[1] * s };
}

// ── Fixtures ─────────────────────────────────────────────────────────────

/**
 * Where a pattern's fixture stands, worked out once from its keyframes so it
 * never moves while the body does. Numbers in `pattern.fixture` are relative
 * to keyframe 0's pelvis (x, y) unless noted.
 */
export function placeFixture(pattern, placed = placeKeyframes(pattern)) {
  const fx = pattern.fixture;
  if (!fx) return null;
  // `placeFrom`: lay the fixture out from that keyframe on (a bike you run up to).
  const from = fx.placeFrom ?? 0;
  const k0 = keyframeAt(pattern, from, placed);
  // `placeTo`: …and only up to that keyframe (a bike you get off).
  const all = pattern.keyframes.map((_, i) => keyframeAt(pattern, i, placed)).slice(from, fx.placeTo ?? undefined);
  const pel = k0.pelvis;
  // Fixtures are laid out in the body's own axes (x forward, z left) around
  // keyframe 0's pelvis — the side view — and turned with the camera when
  // drawn. So every skeleton is first turned back into those axes.
  const back = rotY(-placed.view);
  const toBody = (p) => add(pel, apply(back, sub(p, pel)));
  const bodySkel = (sk) => {
    const limb = (l) => ({ ...l, ...Object.fromEntries(['shoulder', 'elbow', 'wrist', 'handTip', 'hip', 'knee', 'ankle', 'toe', 'heel'].map((k) => [k, toBody(l[k])])) });
    return { ...sk, trunk: mul(back, sk.trunk), pelvis: toBody(sk.pelvis), neckBase: toBody(sk.neckBase), L: limb(sk.L), R: limb(sk.R) };
  };
  const b0 = bodySkel(k0);
  if (fx.kind === 'kickball') {
    // The ball waits on the ground where the kicking foot meets it in keyframe `frame`.
    const k = bodySkel(keyframeAt(pattern, fx.frame ?? 1, placed));
    const foot = k[fx.side ?? 'L'].toe;
    return { origin: pel, view: placed.view, ball: [foot[0] + 5, 5.8, foot[2]] };
  }
  const o = placeFixtureRaw(fx, pel, b0, all.map(bodySkel));
  return o ? { origin: pel, view: placed.view, ...o } : o;
}

function placeFixtureRaw(fx, pel, k0, all) {
  switch (fx.kind) {
    case 'bench': case 'box': {
      if (fx.under === 'Lfoot' || fx.under === 'Rfoot') {
        const a = k0[fx.under[0]].ankle, w = (fx.width ?? 30) / 2;
        return { x0: a[0] - w, x1: a[0] + w, top: fx.top ?? a[1] - 3, z: a[2] };
      }
      if (fx.under === 'hands' || fx.under === 'feet') {
        const c = fx.under === 'hands' ? scale(add(k0.L.wrist, k0.R.wrist), 0.5) : scale(add(k0.L.ankle, k0.R.ankle), 0.5);
        const w = (fx.width ?? 36) / 2;
        return { x0: c[0] - w + (fx.shift ?? 0), x1: c[0] + w + (fx.shift ?? 0), top: fx.top ?? 34, z: pel[2] };
      }
      return { x0: pel[0] + fx.from, x1: pel[0] + fx.to, top: fx.top ?? pel[1] + (fx.below ?? -10), z: pel[2] };
    }
    case 'wall': return { x: pel[0] + fx.at };
    case 'incline': {
      // Pad along the back of keyframe 0's trunk, seat under the pelvis.
      const upv = apply(k0.trunk, [0, 1, 0]), fw = apply(k0.trunk, [1, 0, 0]);
      const from = add(add(pel, fw, -13), upv, 4), to = add(add(pel, fw, -13), upv, 44);
      return { seatX: pel[0], seatTop: pel[1] - 10, padFrom: [from[0], from[1]], padTo: [to[0], to[1]] };
    }
    case 'bar': {
      const grip = scale(add(k0.L.wrist, k0.R.wrist), 0.5);
      // `above`: how far over the hands (towels or a gi hang between).
      return { at: add(grip, [0, fx.above ?? 3, 0]) };
    }
    case 'water': return { level: pel[1] + (fx.level ?? 6), x0: pel[0] - 120, x1: pel[0] + 120, ...(fx.deck != null ? { deckX: pel[0] + fx.deck, deckTop: fx.deckTop ?? 30 } : {}) };
    case 'mat': {
      const xs = all.flatMap((s) => bodyPoints(s).map((p) => p[0]));
      return { x0: Math.min(...xs) - 8, x1: Math.max(...xs) + 8 };
    }
    case 'bike': {
      const ankles = all.flatMap((s) => [s.L.ankle, s.R.ankle]);
      const crank = scale(ankles.reduce((a, b) => add(a, b), [0, 0, 0]), 1 / ankles.length);
      const r = Math.max(...ankles.map((p) => Math.hypot(p[0] - crank[0], p[1] - crank[1])));
      return { crank: [crank[0], crank[1], -6], r, seat: [pel[0] - 2 - (fx.seatBack ?? 0), pel[1] - 6 - (fx.seatDrop ?? 0), -6], bars: [...scale(add(k0.L.wrist, k0.R.wrist), 0.5).slice(0, 2), -6] };
    }
    case 'rower': {
      const foot = scale(add(k0.L.ankle, k0.R.ankle), 0.5);
      const xs = all.map((s) => s.pelvis[0]);
      return { foot, seatTop: pel[1] - 10, fly: [foot[0] + 20, foot[1] + 2, 0], rail0: Math.min(...xs) - 20, rail1: foot[0] + 8 };
    }
    case 'hurdle': case 'cone': case 'ladder': case 'sled': case 'control': return { x: pel[0] + (fx.at ?? 30) };
    case 'net': return { x: pel[0] + (fx.at ?? 30), top: fx.top ?? 150 };
    case 'wheelchair': case 'racingchair': return { seat: [pel[0], pel[1] - 9, pel[2]] };
    case 'blocks': return { L: [k0.L.toe[0], k0.L.toe[2]], R: [k0.R.toe[0], k0.R.toe[2]] };
    case 'roller': {
      // Under a named body point of keyframe 0 (default: the thighs).
      const target = fx.under === 'back' ? add(pel, apply(k0.trunk, [0, 1, 0]), 25) : fx.under === 'calves' ? scale(add(k0.L.knee, k0.L.ankle), 0.5) : scale(add(k0.L.hip, k0.L.knee), 0.5);
      return { at: [target[0], 7, pel[2]] };
    }
    case 'ball': return { at: [pel[0] + (fx.dx ?? 0), fx.r ?? 30, pel[2]], r: fx.r ?? 30 };
    default: return null;
  }
}

// ── Paths: drills that travel ─────────────────────────────────────────────

/**
 * A travelling drill moves through the scene instead of running in place:
 *   path: { kind: 'line', length, dir }     straight across (dir: 'forward' | 'back' | 'left' | 'right')
 *   path: { kind: 'circle', radius, turn }  round a circle (turn: 1 = to the left, -1 = right)
 *   path: { kind: 'shuttle', length }       out, turn round, and back
 * Speed comes from the stride itself (how fast the planted foot moves back
 * under the body), so feet grip the ground instead of sliding.
 */
export function strideSpeed(pattern, placed = placeKeyframes(pattern), axis = [1, 0, 0]) {
  const n = 48, secs = cycleSeconds(pattern);
  const dir = apply(rotY(placed.view), axis);
  let dist = 0, time = 0;
  let prev = null;
  // Track the lowest point of the lower foot (ankle, toe or heel) while it
  // is on the ground: how fast it slides back is how fast the body travels.
  const low = (l) => [l.ankle, l.toe, l.heel].reduce((m, q) => (q[1] < m[1] ? q : m));
  for (let i = 0; i <= n; i++) {
    const s = frameAt(pattern, i / n, placed);
    const pl = low(s.L), pr = low(s.R);
    const foot = pl[1] <= pr[1] ? 'L' : 'R';
    const p = foot === 'L' ? pl : pr;
    if (prev && prev.foot === foot && Math.max(p[1], prev.p[1]) < 3) {
      dist += -dot(sub(p, prev.p), dir);
      time += secs / n;
    }
    prev = { foot, p };
  }
  return time > 0 ? Math.max(0, dist / time) : 0;
}

const PATH_AXIS = { forward: [1, 0, 0], back: [-1, 0, 0], left: [0, 0, 1], right: [0, 0, -1] };

/** Seconds for one full pass of the path (the animation's full cycle). */
export function pathSeconds(pattern, placed = placeKeyframes(pattern)) {
  const path = pattern.path;
  if (!path) return cycleSeconds(pattern);
  const speed = path.speed ?? Math.max(strideSpeed(pattern, placed, PATH_AXIS[path.dir ?? 'forward'] ?? [1, 0, 0]), 20);
  const length = path.kind === 'arc' ? (2 * Math.PI * path.radius * path.angle) / 180 : path.kind === 'circle' ? 2 * Math.PI * path.radius : path.kind === 'figure8' ? 4 * Math.PI * path.radius : path.kind === 'shuttle' ? path.length * 2 : path.length;
  return length / speed;
}

/** Where the path has the body at `seconds`: position (body axes) and heading (degrees). */
export function pathAt(pattern, seconds, placed = placeKeyframes(pattern)) {
  const path = pattern.path;
  const total = pathSeconds(pattern, placed);
  const u = (((seconds / total) % 1) + 1) % 1;
  if (path.kind === 'circle') {
    // Starts at the origin heading forward; the centre is on the turning side
    // (left = +z). Heading follows the tangent.
    const turn = path.turn ?? 1;
    const theta = 2 * Math.PI * u;
    return { pos: [path.radius * Math.sin(theta), 0, turn * path.radius * (1 - Math.cos(theta))], heading: (turn * theta * 180) / Math.PI };
  }
  if (path.kind === 'arc') {
    // Sideways back and forth along an arc of `angle` degrees round a centre
    // `radius` behind, always facing out from it (a keeper squaring up).
    const phi = (path.angle / 2) * Math.sin(2 * Math.PI * u) * (Math.PI / 180);
    return { pos: [path.radius * Math.cos(phi) - path.radius, 0, path.radius * Math.sin(phi)], heading: (phi * 180) / Math.PI };
  }
  if (path.kind === 'figure8') {
    // Round one circle to the left, then one to the right, through the origin.
    const half = u < 0.5 ? 1 : -1;
    const theta = 4 * Math.PI * (u < 0.5 ? u : u - 0.5);
    return { pos: [path.radius * Math.sin(theta), 0, half * path.radius * (1 - Math.cos(theta))], heading: (half * theta * 180) / Math.PI };
  }
  const axis = PATH_AXIS[path.dir ?? 'forward'] ?? [1, 0, 0];
  if (path.kind === 'shuttle') {
    const half = u < 0.5;
    const along = half ? -path.length / 2 + path.length * (u * 2) : path.length / 2 - path.length * ((u - 0.5) * 2);
    return { pos: scale(axis, along), heading: half ? 0 : 180 };
  }
  const along = -path.length / 2 + path.length * u;
  // grade: rise per unit along the path (a hill; negative runs downhill).
  // wave: rollers of height `amp` every `length` units (a pump track).
  const k = path.wave ? (2 * Math.PI) / path.wave.length : 0;
  const y = along * (path.grade ?? 0) + (path.wave ? path.wave.amp * Math.sin(k * along) : 0);
  const slope = (path.grade ?? 0) + (path.wave ? path.wave.amp * k * Math.cos(k * along) : 0);
  return { pos: add(scale(axis, along), [0, y, 0]), heading: 0, slope };
}

/** Turns a placed skeleton by `deg` about the vertical axis through the origin and moves it by `v`. */
export function moveSkeleton(s, deg, v) {
  const R = rotY(deg);
  const t = (p) => add(apply(R, p), v);
  const f = (m) => mul(R, m);
  const limb = (l) => ({
    ...l, arm: f(l.arm), fore: f(l.fore), hand: f(l.hand), thigh: f(l.thigh), shin: f(l.shin), foot: f(l.foot), footDir: apply(R, l.footDir),
    shoulder: t(l.shoulder), elbow: t(l.elbow), wrist: t(l.wrist), handTip: t(l.handTip), hip: t(l.hip), knee: t(l.knee), ankle: t(l.ankle), toe: t(l.toe), heel: t(l.heel),
  });
  return {
    ...s, root: f(s.root), trunk: f(s.trunk), chest: f(s.chest), headFrame: f(s.headFrame),
    pelvis: t(s.pelvis), neckBase: t(s.neckBase), neckTop: t(s.neckTop), head: t(s.head), L: limb(s.L), R: limb(s.R),
    ball: s.ball ? t(s.ball) : s.ball,
  };
}

/**
 * The skeleton at `seconds` of real time: the movement's own cycle, carried
 * along its path when it has one.
 */
export function frameAtTime(pattern, seconds, placed = placeKeyframes(pattern)) {
  const cycle = cycleSeconds(pattern);
  const t = (((seconds / cycle) % 1) + 1) % 1;
  const cast = pattern.cast ? castAt(pattern, t, placed) : null;
  let s = frameAt(pattern, t, placed, cast);
  if (pattern.path) {
    const { pos, heading } = pathAt(pattern, seconds, placed);
    // The path lives in the body's own axes; turn it with the camera view.
    const move = (sk) => moveSkeleton(sk, heading, apply(rotY(placed.view), pos));
    s = move(s);
    // The fixture (a bike, a chair) travels with the athlete.
    s.fxMove = { heading, v: apply(rotY(placed.view), pos) };
    // Where the ground is under the athlete (for the shadow on a hill).
    if (pattern.path.grade || pattern.path.wave) s.floor = pos[1];
    // On rollers the bike follows the slope.
    if (s.fx && pattern.path.wave) s.fx.pitch += (Math.atan(pathAt(pattern, seconds, placed).slope) * 180) / Math.PI;
    if (cast) for (const m of cast) if (m?.follow) m.s = move(m.s);
  }
  if (cast) s.cast = cast;
  return s;
}

// ── Cast: the other people in a drill ─────────────────────────────────────

/**
 * A drill with a partner, a passer, a defender or a whole line shows them:
 *   cast: [{ pattern: 'slug', at: [forward, left], facing: deg, phase: 0..1, follow }]
 * Each member plays their own pattern in step with the athlete (the same
 * cycle position, shifted by `phase`), standing at `at` in the athlete's
 * body axes and turned `facing` degrees (180 = facing the athlete).
 * `follow` carries them along the athlete's path. poses.js resolves the
 * slug into `ref` (the member's pattern).
 */
const castPlacements = new WeakMap();
export function castAt(pattern, t, placed) {
  return pattern.cast.map((c) => {
    const ref = c.ref;
    if (!ref) return null; // not resolved yet (while patterns are still being authored)
    let byView = castPlacements.get(ref);
    if (!byView) castPlacements.set(ref, (byView = new Map()));
    if (!byView.has(placed.view)) byView.set(placed.view, placeKeyframes(ref, { view: placed.view }));
    const mp = byView.get(placed.view);
    const s = frameAt(ref, (((t + (c.phase ?? 0)) % 1) + 1) % 1, mp);
    s.ball = null;
    // at: [forward, left, up] — `up` lowers a partner standing on the pool floor.
    const [f, l, up] = c.at ?? [0, 0, 0];
    return { s: moveSkeleton(s, c.facing ?? 0, apply(rotY(placed.view), [f, up ?? 0, l ?? 0])), ref, follow: !!c.follow, tether: !!c.tether };
  });
}
