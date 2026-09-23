// Dev-only mirror of RigPoseView.swift's kinematics + body shapes, used to
// preview pose patterns as images. Keep the constants and math identical to
// the Swift file.

export const BONES = {
  torso: 42, neck: 7, headRx: 8.4, headRy: 10, upperArm: 27, forearm: 24, hand: 8,
  thigh: 40, shin: 39, foot: 15, heel: 3.5,
};

export const rad = (d) => (d * Math.PI) / 180;
export function rotate([x, y], deg) {
  const c = Math.cos(rad(deg)), s = Math.sin(rad(deg));
  return [x * c - y * s, x * s + y * c];
}
const add = (p, v, k = 1) => [p[0] + v[0] * k, p[1] + v[1] * k];
const neg = (v) => [-v[0], -v[1]];

/** Facing +x. Angles: spine lean (+ forward), shoulder/hip flexion (+ forward),
 * elbow flexion (+ forearm toward front), knee flexion (+ heel back),
 * ankle dorsiflexion (+ shin over toes), lift = height off the ground. */
export function skeleton(pose) {
  const a = (j) => pose[j] ?? 0;
  const up = [0, -1];
  const pelvis = [0, 0];
  const torsoDir = rotate(up, a('spine'));
  const shoulder = add(pelvis, torsoDir, BONES.torso);
  const neckDir = rotate(torsoDir, a('neck'));
  const neckTop = add(shoulder, neckDir, BONES.neck);
  const headCenter = add(neckTop, neckDir, BONES.headRy * 0.85);
  const limb = (side) => {
    const armDir = rotate(neg(torsoDir), -a(`shoulder${side}`));
    const elbow = add(shoulder, armDir, BONES.upperArm);
    const foreDir = rotate(armDir, -a(`elbow${side}`));
    const wrist = add(elbow, foreDir, BONES.forearm);
    const handDir = rotate(foreDir, -a(`wrist${side}`));
    const handTip = add(wrist, handDir, BONES.hand);
    const thighDir = rotate(neg(torsoDir), -a(`hip${side}`));
    const knee = add(pelvis, thighDir, BONES.thigh);
    const shinDir = rotate(thighDir, a(`knee${side}`));
    const ankle = add(knee, shinDir, BONES.shin);
    const footDir = rotate(shinDir, -(90 + a(`ankle${side}`)));
    const toe = add(ankle, footDir, BONES.foot);
    const heel = add(ankle, footDir, -BONES.heel);
    return { armDir, elbow, foreDir, wrist, handDir, handTip, thighDir, knee, shinDir, ankle, footDir, toe, heel };
  };
  const s = { pelvis, torsoDir, shoulder, neckDir, neckTop, headCenter, L: limb('L'), R: limb('R') };
  // Ground: the lowest point touches y = 0, raised by `lift`.
  const pts = allPoints(s);
  const lowest = Math.max(...pts.map((p) => p[1]));
  const dy = -lowest - a('lift');
  return translate(s, [0, dy]);
}

function allPoints(s) {
  const pts = [s.pelvis, s.shoulder, s.neckTop, add(s.headCenter, [0, -BONES.headRy])];
  for (const l of [s.L, s.R]) pts.push(l.elbow, l.wrist, l.handTip, l.knee, l.ankle, l.toe, l.heel);
  return pts;
}

function translate(s, v) {
  const t = (p) => add(p, v);
  const limb = (l) => ({ ...l, elbow: t(l.elbow), wrist: t(l.wrist), handTip: t(l.handTip), knee: t(l.knee), ankle: t(l.ankle), toe: t(l.toe), heel: t(l.heel) });
  return { ...s, pelvis: t(s.pelvis), shoulder: t(s.shoulder), neckTop: t(s.neckTop), headCenter: t(s.headCenter), L: limb(s.L), R: limb(s.R) };
}

export function bounds(s) {
  const pts = allPoints(s);
  const pad = 11;
  return {
    minX: Math.min(...pts.map((p) => p[0])) - pad, maxX: Math.max(...pts.map((p) => p[0])) + pad,
    minY: Math.min(...pts.map((p) => p[1])) - pad, maxY: Math.max(...pts.map((p) => p[1])) + 2,
  };
}

export function lerpPose(a, b, t) {
  const out = {};
  for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) out[k] = (a[k] ?? 0) + ((b[k] ?? 0) - (a[k] ?? 0)) * t;
  return out;
}

// ── Body shapes ────────────────────────────────────────────────────────────

function capsule(a, b, ra, rb) {
  const dir = [b[0] - a[0], b[1] - a[1]];
  const len = Math.hypot(...dir) || 1;
  const n = [-dir[1] / len, dir[0] / len];
  const p = (pt, r, k) => add(pt, n, r * k);
  const circle = (c, r) => `M${c[0] - r},${c[1]} a${r},${r} 0 1,0 ${2 * r},0 a${r},${r} 0 1,0 ${-2 * r},0 Z`;
  return `M${p(a, ra, 1)} L${p(b, rb, 1)} L${p(b, rb, -1)} L${p(a, ra, -1)} Z ${circle(a, ra)} ${circle(b, rb)}`;
}

/** Torso profile: front/back half-thickness along the pelvis→shoulder axis. */
const TORSO_FRONT = [[0, 8.6], [0.18, 9.4], [0.45, 8.2], [0.72, 10.6], [0.9, 9.2], [1, 5.6]];
const TORSO_BACK = [[0, 10.4], [0.15, 8.6], [0.45, 7.6], [0.7, 9.2], [0.9, 9.6], [1, 6.2]];

export function torsoPath(s) {
  const fwd = rotate(s.torsoDir, 90);
  const at = (t, off) => add(add(s.pelvis, s.torsoDir, BONES.torso * t), fwd, off);
  const front = TORSO_FRONT.map(([t, o]) => at(t, o));
  const back = TORSO_BACK.map(([t, o]) => at(t, -o)).reverse();
  return spline([...front, ...back]);
}

function spline(points) {
  const n = points.length;
  const p = (i) => points[(i + n) % n];
  let d = `M${p(0)}`;
  for (let i = 0; i < n; i += 1) {
    const p0 = p(i - 1), p1 = p(i), p2 = p(i + 1), p3 = p(i + 2);
    const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
    const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
    d += ` C${c1} ${c2} ${p2}`;
  }
  return `${d} Z`;
}

export function renderFigure(s, { highlight = {}, far = '#b07c56', near = '#d9a47a', shirt = '#2b2d33', shirtFar = '#1d1f24', shorts = '#3a3f4a', shortsFar = '#2a2e37', shoe = '#15161a' } = {}) {
  let out = '';
  const limbSVG = (l, isNear) => {
    const skin = isNear ? near : far;
    const sh = isNear ? shirt : shirtFar;
    const pants = isNear ? shorts : shortsFar;
    let g = '';
    // leg
    g += `<path d="${capsule(s.pelvis, l.knee, 8.2, 5.4)}" fill="${skin}"/>`;
    g += `<path d="${capsule(l.knee, l.ankle, 5.2, 3.2)}" fill="${skin}"/>`;
    const calf = add(add(l.knee, l.shinDir, BONES.shin * 0.33), rotate(l.shinDir, -90), -2.2);
    g += `<ellipse cx="${calf[0]}" cy="${calf[1]}" rx="4.8" ry="8.5" transform="rotate(${Math.atan2(l.shinDir[1], l.shinDir[0]) * 180 / Math.PI - 90} ${calf[0]} ${calf[1]})" fill="${skin}"/>`;
    // shorts over the upper thigh
    const shortsEnd = add(s.pelvis, l.thighDir, BONES.thigh * 0.58);
    g += `<path d="${capsule(s.pelvis, shortsEnd, 9.2, 6.9)}" fill="${pants}"/>`;
    // shoe
    const sole = [add(l.heel, rotate(l.footDir, 90), 0.5), add(l.toe, rotate(l.footDir, 90), 0.5)];
    const top = [add(l.heel, rotate(l.footDir, -90), 4.2), add(l.ankle, rotate(l.footDir, -90), 4.6), add(l.toe, rotate(l.footDir, -90), 1.8)];
    g += `<path d="M${sole[0]} L${sole[1]} Q${add(l.toe, l.footDir, 1.5)} ${top[2]} L${top[1]} L${top[0]} Z" fill="${shoe}"/>`;
    return g;
  };
  const armSVG = (l, isNear) => {
    const skin = isNear ? near : far;
    const sh = isNear ? shirt : shirtFar;
    let g = '';
    g += `<path d="${capsule(s.shoulder, l.elbow, 5, 3.9)}" fill="${skin}"/>`;
    g += `<path d="${capsule(l.elbow, l.wrist, 3.8, 2.7)}" fill="${skin}"/>`;
    const handC = add(l.wrist, l.handDir, BONES.hand * 0.5);
    g += `<ellipse cx="${handC[0]}" cy="${handC[1]}" rx="2.8" ry="4.6" transform="rotate(${Math.atan2(l.handDir[1], l.handDir[0]) * 180 / Math.PI - 90} ${handC[0]} ${handC[1]})" fill="${skin}"/>`;
    const sleeveEnd = add(s.shoulder, l.armDir, BONES.upperArm * 0.42);
    g += `<path d="${capsule(s.shoulder, sleeveEnd, 5.6, 4.7)}" fill="${sh}"/>`;
    return g;
  };
  out += limbSVG(s.R, false) + armSVG(s.R, false);
  // neck + head
  out += `<path d="${capsule(s.shoulder, s.neckTop, 4.3, 4)}" fill="${near}"/>`;
  const ang = Math.atan2(s.neckDir[1], s.neckDir[0]) * 180 / Math.PI + 90;
  out += `<ellipse cx="${s.headCenter[0]}" cy="${s.headCenter[1]}" rx="${BONES.headRx}" ry="${BONES.headRy}" transform="rotate(${ang} ${s.headCenter[0]} ${s.headCenter[1]})" fill="${near}"/>`;
  // hair: a cap over the back and top of the head, plus an ear
  const up = s.neckDir, fwd = rotate(s.neckDir, 90);
  const onHead = (phi, k, shift = 0) => add(add(s.headCenter, up, BONES.headRy * k * Math.cos(rad(phi)) + shift), fwd, BONES.headRx * k * Math.sin(rad(phi)));
  const outer = [], inner = [];
  for (let phi = -125; phi <= 45; phi += 10) outer.push(onHead(phi, 1.04));
  for (let phi = 45; phi >= -125; phi -= 10) inner.push(onHead(phi, 0.78, 1.6));
  out += `<path d="M${outer.join(' L')} L${inner.join(' L')} Z" fill="#2a1d15"/>`;
  const ear = add(s.headCenter, fwd, -BONES.headRx * 0.18);
  out += `<ellipse cx="${ear[0]}" cy="${ear[1]}" rx="1.7" ry="2.6" transform="rotate(${ang} ${ear[0]} ${ear[1]})" fill="#c48d63"/>`;
  out += limbSVG(s.L, true);
  out += `<path d="${torsoPath(s)}" fill="${shirt}"/>`;
  const shortsTop = add(s.pelvis, s.torsoDir, BONES.torso * 0.16);
  out += `<path d="${capsule(s.pelvis, shortsTop, 10.2, 9)}" fill="${shorts}"/>`;
  out += armSVG(s.L, true);
  return out;
}
