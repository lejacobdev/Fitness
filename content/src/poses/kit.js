/**
 * Authoring kit for pose patterns (see ../poses.js for the pattern format and
 * ../rig3d.js for every angle convention). Pattern files import from here.
 */
import { BONES, JOINTS as RIG_JOINTS, add, apply, len, norm, skeleton, sub } from '../rig3d.js';

export const JOINTS = RIG_JOINTS;

// ── Authoring helpers ────────────────────────────────────────────────────

const SIDED = ['shoulder', 'shoulderAbd', 'shoulderRot', 'elbow', 'wrist', 'hip', 'hipAbd', 'hipRot', 'knee', 'ankle'];

/** A full pose: every joint present (0 unless given). Arms rest slightly off the body. */
export function pose(angles = {}) {
  const out = Object.fromEntries(JOINTS.map((j) => [j, 0]));
  out.shoulderAbdL = 6; out.shoulderAbdR = 6; out.elbowL = 8; out.elbowR = 8;
  for (const [k, v] of Object.entries(angles)) {
    if (!(k in out)) throw new Error(`unknown joint ${JSON.stringify(k)}`);
    out[k] = v;
  }
  return out;
}

/** Same value on both sides: both({ hip: 90 }) → hipL, hipR. Other keys pass through. */
export function both(angles) {
  const out = {};
  for (const [k, v] of Object.entries(angles)) {
    if (SIDED.includes(k)) { out[`${k}L`] = v; out[`${k}R`] = v; } else out[k] = v;
  }
  return out;
}

/** Only the left (L) or right (R) side. */
export function side(s, angles) {
  const out = {};
  for (const [k, v] of Object.entries(angles)) out[SIDED.includes(k) ? `${k}${s}` : k] = v;
  return out;
}

export const P = (...parts) => pose(Object.assign({}, ...parts));

export function kf(p, contact = 'feet', opts = {}) {
  return { pose: settle(p, contact), contact, hold: opts.hold ?? 0, move: opts.move ?? 0.6, ...opts };
}

/**
 * Makes every planted foot/knee of `contact` touch the same floor: the
 * lowest planted point is the floor; each other planted flat foot, toe or
 * knee gets its leg re-solved (knee bend first, then hip) to reach it.
 * Poses that already agree are returned unchanged.
 */
export function settle(p, contact) {
  const t = new Set(contact.split('+'));
  if (t.has('feet')) { t.add('L'); t.add('R'); }
  if (t.has('knees')) { t.add('Lknee'); t.add('Rknee'); }
  const plants = [];
  for (const s of ['L', 'R']) {
    if (t.has(s)) plants.push([s, 'flat']);
    else if (t.has(`${s}toe`)) plants.push([s, 'toe']);
    else if (t.has(`${s}heel`)) plants.push([s, 'heel']);
    if (t.has(`${s}knee`)) plants.push([s, 'knee']);
  }
  if (plants.length < 2) return p;
  const height = (sk, [s, kind]) => kind === 'flat' ? sk[s].ankle[1] : kind === 'toe' ? sk[s].toe[1] : kind === 'heel' ? sk[s].heel[1] : sk[s].knee[1] - 5.2;
  let q = { ...p };
  const sk0 = skeleton(q);
  // The reference: a flat foot if there is one, else the lowest plant.
  const ref = plants.find(([, k]) => k === 'flat') ?? plants.reduce((a, b) => (height(sk0, a) <= height(sk0, b) ? a : b));
  for (const plant of plants) {
    if (plant === ref) continue;
    const err = (sk) => height(sk, plant) - height(sk, ref);
    if (Math.abs(err(skeleton(q))) < 1) continue;
    const [s, kind] = plant;
    if (plant[0] === ref[0]) continue; // same leg (e.g. knee + toe): leave as authored
    if (kind === 'toe') {
      const viaAnkle = solve(q, `ankle${s}`, err, -85, 40);
      if (Math.abs(err(skeleton(viaAnkle))) < 1) { q = viaAnkle; continue; }
    }
    const candidates = [solve(q, `knee${s}`, err, 0, 150), solve(q, `hip${s}`, err, -60, 150)];
    const good = candidates.filter((c) => Math.abs(err(skeleton(c))) < 1);
    const change = (c) => Math.abs(c[`knee${s}`] - q[`knee${s}`]) + Math.abs(c[`hip${s}`] - q[`hip${s}`]);
    q = (good.length ? good : candidates).sort((a, b) => (good.length ? change(a) - change(b) : Math.abs(err(skeleton(a))) - Math.abs(err(skeleton(b)))))[0];
    if (kind === 'toe') { const t2 = solve(q, `ankle${s}`, err, -85, 40); if (Math.abs(err(skeleton(t2))) < 1) q = t2; }
  }
  return q;
}

/**
 * Bisection on one joint so that f(skeleton) crosses zero — used at
 * authoring time to land a foot or a hand exactly where it should be.
 */
export function solve(p, joint, f, lo, hi, iterations = 40) {
  const at = (v) => f(skeleton({ ...p, [joint]: v }));
  // Scan for the first sign change (closest to lo), then bisect; if there
  // is none, take the value with the smallest error.
  const n = 48;
  let prevV = lo, prevF = at(lo), best = lo, bestF = Math.abs(prevF);
  for (let i = 1; i <= n; i++) {
    const v = lo + ((hi - lo) * i) / n, fv = at(v);
    if (Math.abs(fv) < bestF) { best = v; bestF = Math.abs(fv); }
    if (Math.sign(fv) !== Math.sign(prevF)) {
      let a = prevV, b = v, fa = prevF;
      for (let k = 0; k < iterations; k++) {
        const m = (a + b) / 2, fm = at(m);
        if (Math.sign(fm) === Math.sign(fa)) { a = m; fa = fm; } else b = m;
      }
      return { ...p, [joint]: (a + b) / 2 };
    }
    prevV = v; prevF = fv;
  }
  return { ...p, [joint]: best };
}

/** Sets side `s`'s ankle so its toe tip rests on the same level as the other foot's sole. */
export function toeDown(p, s) {
  const o = s === 'L' ? 'R' : 'L';
  return solve(p, `ankle${s}`, (sk) => sk[s].toe[1] - sk[o].ankle[1], -80, 40);
}

/** Adjusts a joint so side `s`'s ankle is level with the other ankle (both feet flat). */
export function levelFeet(p, s, joint) {
  const o = s === 'L' ? 'R' : 'L';
  return solve(p, joint, (sk) => sk[s].ankle[1] - sk[o].ankle[1], joint.startsWith('knee') ? 0 : -60, 160);
}

/**
 * Arm IK: sets side `s`'s elbow, shoulder flexion and abduction so the
 * wrist lands on target(skeleton) — a point in the same pelvis-origin frame.
 * Used to put hands exactly on a bar, a ball, the floor or the other hand.
 */
export function reach(p, s, target, { rot = null, prefer = null } = {}) {
  // Optionally try several humeral rotations (the elbow's swivel) and keep
  // the one `prefer` scores lowest among exact solutions (e.g. elbows down).
  if (rot) {
    let best = null;
    for (const r of rot) {
      const q = reachOnce({ ...p, [`shoulderRot${s}`]: r }, s, target);
      const sk = skeleton(q);
      const err = len(sub(sk[s].wrist, target(sk)));
      const score = err * 10 + (prefer ? prefer(sk, s) : 0);
      if (!best || score < best.score) best = { q, score };
    }
    return best.q;
  }
  return reachOnce(p, s, target);
}

function reachOnce(p, s, target) {
  const U = BONES.upperArm, F = BONES.forearm;
  let q = { ...p };
  for (let round = 0; round < 4; round++) {
    const sk = skeleton(q);
    const T = target(sk);
    const d = Math.min(Math.max(len(sub(T, sk[s].shoulder)), 6), U + F - 0.3);
    const cosE = (U * U + F * F - d * d) / (2 * U * F);
    q[`elbow${s}`] = 180 - (Math.acos(Math.max(-1, Math.min(1, cosE))) * 180) / Math.PI;
    const err = (flex, abd) => {
      const k = skeleton({ ...q, [`shoulder${s}`]: flex, [`shoulderAbd${s}`]: abd });
      return len(sub(k[s].wrist, target(k)));
    };
    let best = [q[`shoulder${s}`], q[`shoulderAbd${s}`]], bestErr = err(...best);
    // The coarse scan finds the right basin; later rounds (only the elbow
    // changed) just refine from there.
    if (round === 0) {
      for (let f = -70; f <= 200; f += 10) for (let a = -60; a <= 130; a += 10) {
        const e = err(f, a);
        if (e < bestErr) { bestErr = e; best = [f, a]; }
      }
    }
    for (const step of [5, 2.5, 1, 0.5, 0.25, 0.1]) {
      let improved = true;
      while (improved) {
        improved = false;
        for (const [df, da] of [[step, 0], [-step, 0], [0, step], [0, -step]]) {
          const c = [best[0] + df, best[1] + da];
          if (c[0] < -90 || c[0] > 250 || c[1] < -90 || c[1] > 175) continue; // stay inside the joint's range
          const e = err(...c);
          if (e < bestErr - 1e-9) { bestErr = e; best = c; improved = true; }
        }
      }
    }
    q[`shoulder${s}`] = best[0];
    q[`shoulderAbd${s}`] = best[1];
  }
  return q;
}

/** Sets each wrist so the hand lies flat, fingers pointing forward (hands on the floor). */
export function flatHands(p) {
  let q = { ...p };
  for (const s of ['L', 'R']) {
    let best = null;
    for (let w = -95; w <= 80; w += 1) {
      const sk = skeleton({ ...q, [`wrist${s}`]: w });
      const d = sub(sk[s].handTip, sk[s].wrist);
      const fwdX = apply(sk.root, [1, 0, 0]);
      const score = Math.abs(d[1]) - 0.2 * (d[0] * fwdX[0] + d[2] * fwdX[2]);
      if (!best || score < best.score) best = { w, score };
    }
    q = { ...q, [`wrist${s}`]: best.w };
  }
  return q;
}

/**
 * Keeps the free foot off the floor: bends its knee (more flexion only)
 * until its lowest point is at least `gap` above the planted foot's sole.
 */
export function clear(p, planted, gap = 1.5) {
  const free = planted === 'L' ? 'R' : 'L';
  const low = (sk) => Math.min(sk[free].ankle[1], sk[free].toe[1], sk[free].heel[1]) - sk[planted].ankle[1] - gap;
  if (low(skeleton(p)) >= 0) return p;
  for (let k = p[`knee${free}`]; k <= 150; k += 1) {
    const q = { ...p, [`knee${free}`]: k };
    if (low(skeleton(q)) >= 0) return q;
  }
  return p;
}

/** Elbows pointing down (for goblet holds, curls, front racks). */
export const elbowsDown = (sk, s) => sk[s].elbow[1];

/**
 * Leg IK: sets side `s`'s knee, hip flexion and abduction so its ankle lands
 * on target(skeleton) — e.g. a foot on a box or on a bench behind.
 */
export function reachLeg(p, s, target) {
  const T0 = BONES.thigh, S0 = BONES.shin;
  let q = { ...p };
  for (let round = 0; round < 4; round++) {
    const sk = skeleton(q);
    const T = target(sk);
    const d = Math.min(Math.max(len(sub(T, sk[s].hip)), 8), T0 + S0 - 0.3);
    const cosK = (T0 * T0 + S0 * S0 - d * d) / (2 * T0 * S0);
    q[`knee${s}`] = 180 - (Math.acos(Math.max(-1, Math.min(1, cosK))) * 180) / Math.PI;
    const err = (flex, abd) => len(sub(skeleton({ ...q, [`hip${s}`]: flex, [`hipAbd${s}`]: abd })[s].ankle, target(skeleton({ ...q, [`hip${s}`]: flex, [`hipAbd${s}`]: abd }))));
    let best = [q[`hip${s}`], q[`hipAbd${s}`]], bestErr = err(...best);
    for (let f = -60; f <= 150; f += 10) for (let a = -20; a <= 60; a += 10) {
      const e = err(f, a);
      if (e < bestErr) { bestErr = e; best = [f, a]; }
    }
    for (const step of [5, 2.5, 1, 0.5, 0.25, 0.1]) {
      let improved = true;
      while (improved) {
        improved = false;
        for (const [df, da] of [[step, 0], [-step, 0], [0, step], [0, -step]]) {
          const c = [best[0] + df, best[1] + da];
          if (c[0] < -90 || c[0] > 250 || c[1] < -90 || c[1] > 175) continue; // stay inside the joint's range
          const e = err(...c);
          if (e < bestErr - 1e-9) { bestErr = e; best = c; improved = true; }
        }
      }
    }
    q[`hip${s}`] = best[0];
    q[`hipAbd${s}`] = best[1];
  }
  return q;
}

/** Both hands to targets. */
export const reachBoth = (p, targetL, targetR, opts) => reach(reach(p, 'L', targetL, opts), 'R', targetR, opts);

/** Points on the body for IK targets (pelvis-origin skeleton frame). */
export const on = {
  /** On a bar across the upper back, hands `w` either side of centre. */
  backBar: (w = 24) => [(sk) => add(add(add(sk.neckBase, apply(sk.trunk, [0, 1, 0]), -4), apply(sk.chest, [1, 0, 0]), -8.5), apply(sk.chest, [0, 0, 1]), w),
    (sk) => add(add(add(sk.neckBase, apply(sk.trunk, [0, 1, 0]), -4), apply(sk.chest, [1, 0, 0]), -8.5), apply(sk.chest, [0, 0, 1]), -w)],
  /** Front rack: bar resting on the front of the shoulders. */
  rackBar: (w = 18) => [(sk) => add(add(add(sk.neckBase, apply(sk.trunk, [0, 1, 0]), -5), apply(sk.chest, [1, 0, 0]), 9), apply(sk.chest, [0, 0, 1]), w),
    (sk) => add(add(add(sk.neckBase, apply(sk.trunk, [0, 1, 0]), -5), apply(sk.chest, [1, 0, 0]), 9), apply(sk.chest, [0, 0, 1]), -w)],
  /** A point in front of the chest at height h above the pelvis, distance d forward. */
  front: (d, h, w = 8) => [(sk) => add(add(add(sk.pelvis, apply(sk.root, [1, 0, 0]), d), [0, h, 0]), apply(sk.root, [0, 0, 1]), w),
    (sk) => add(add(add(sk.pelvis, apply(sk.root, [1, 0, 0]), d), [0, h, 0]), apply(sk.root, [0, 0, 1]), -w)],
};

/** Tilts the body (spine) until the hands, flat on the floor, level with the toes. */
export const handsToFloor = (p, lo = 40, hi = 100) => solve(p, 'spine', (sk) => Math.min(sk.L.wrist[1] - 2.7, sk.L.handTip[1] - 1.5) - sk.L.toe[1], lo, hi);

/**
 * A move from keyframe a to b through `steps` solved in-betweens: each
 * in-between pose is the straight blend passed through fix() (e.g. keep hands
 * and toes on the floor), and the whole run eases as one motion. Returns the
 * keyframes from a up to (not including) b; b's own hold/move are untouched.
 */
export function tween(a, b, steps, fix, move) {
  const total = move ?? a.move;
  const out = [];
  for (let i = 0; i <= steps; i++) {
    const t = i / (steps + 1);
    const blended = {};
    for (const j of Object.keys(a.pose)) blended[j] = a.pose[j] + (b.pose[j] - a.pose[j]) * t;
    const p = i === 0 ? a.pose : fix(blended);
    out.push({ ...a, pose: p, hold: i === 0 ? a.hold : 0, move: total / (steps + 1), chain: [i, steps + 1] });
  }
  return out;
}

/** Swaps every left/right joint (the same move on the other side). */
export const mirror = (p) => {
  const out = {};
  for (const [k, v] of Object.entries(p)) {
    const o = k.endsWith('L') ? `${k.slice(0, -1)}R` : k.endsWith('R') ? `${k.slice(0, -1)}L` : k;
    out[o] = v;
  }
  return out;
};

// ── Common bodies ────────────────────────────────────────────────────────

export const STAND = P();
export const ATHLETIC = P(both({ hip: 40, knee: 50, ankle: 22, shoulder: 20, elbow: 70 }), { spine: 28, neck: -18 });


/** A pattern collection: lib.def(slug, name, spec); lib.patterns is the array. */
export function library() {
  const patterns = [];
  return {
    patterns,
    def(slug, name, spec) {
      patterns.push({ slug, name, view: 'side', loop: false, thumb: 1, ...spec });
    },
    /** A defined pattern's spec, to build a variant (e.g. the same drill with a partner). */
    get(slug) {
      const { slug: _s, name: _n, ...spec } = patterns.find((p) => p.slug === slug);
      return spec;
    },
  };
}

// ── Shared movement helpers (gaits, where things are, holding sticks) ──────

/** Arms swinging in a run: left shoulder forward `fwdL`, right `backR`. */
export const armsSwing = (fwdL, backR, elbow) => ({ shoulderL: fwdL, shoulderR: backR, elbowL: elbow, elbowR: elbow, shoulderAbdL: 8, shoulderAbdR: 8 });
/** A gait from its left-side phases: the right side mirrors them. */
export const gait = (phases, { lean = 0, neck = 0, move = 0.1, extra = {} } = {}) => {
  const left = phases.map((ph) => P({ spine: lean, neck, ...extra, ...ph }));
  return [...left, ...left.map(mirror)].map((p) => kf(p, 'air', { move }));
};
export const fwdOf = (sk) => apply(sk.root, [1, 0, 0]);
export const leftOf = (sk) => apply(sk.root, [0, 0, 1]);
export const floorY = (sk) => Math.min(sk.L.ankle[1], sk.R.ankle[1]);
/** A point on the ground `f` forward of the pelvis and `l` to its left. */
export const ground = (f, l, up = 1) => (sk) => add(add([sk.pelvis[0], floorY(sk) + up, sk.pelvis[2]], fwdOf(sk), f), leftOf(sk), l);
/** A point `h` above the pelvis, `f` forward, `l` to the left. */
export const air = (f, h, l) => (sk) => add(add(add(sk.pelvis, fwdOf(sk), f), [0, h, 0]), leftOf(sk), l);

/**
 * Both hands on a hockey-type stick: the top hand at `top(sk)`, the blade at
 * `blade(sk)`, the lower hand `share` of the way down. Ice hockey (left
 * shot) has the right hand on top; field hockey (`leftTop`) the left.
 */
export const holdStick = (p, blade, top, { share = 0.42, leftTop = false } = {}) => {
  const lower = (sk) => add(top(sk), sub(blade(sk), top(sk)), share);
  return leftTop
    ? reachBoth(p, top, lower, { rot: [-40, -20, 0, 20, 40], prefer: (sk, s) => sk[s].elbow[1] })
    : reachBoth(p, lower, top, { rot: [-40, -20, 0, 20, 40], prefer: (sk, s) => sk[s].elbow[1] });
};

/**
 * Both hands on a lacrosse stick (right-handed: bottom hand L at `bottom`,
 * top hand R `gap` further up the shaft towards `head`).
 */
export const holdLax = (p, bottom, head, gap = 36) => reachBoth(p, bottom,
  (sk) => add(bottom(sk), norm(sub(head(sk), bottom(sk))), gap), { rot: [-40, -20, 0, 20, 40], prefer: (sk, s) => sk[s].elbow[1] });
