/**
 * Road cycling, mountain biking and BMX: the bike travels with the rider
 * (along the road, up a climb, round a corner, over rollers), pitches up
 * for a wheel lift or a manual, and lifts off a jump.
 */
import { CRANK, pedal } from './strength.js';
import { P, kf, library } from './kit.js';

const lib = library();
const def = lib.def;
const BIKE = { kind: 'bike' };
const STAND_BIKE = { kind: 'bike', seatDrop: 24, seatBack: 12 };
const DEGS = [0, 45, 90, 135, 180, 225, 270, 315];
/** One full pedal revolution, seated. */
const spin = (opts = {}, move = 0.08, extra = () => ({})) =>
  DEGS.map((d, i) => kf({ ...pedal(-d, opts), ...extra(d) }, 'seat', { move, ...(i === 0 ? { surface: 28 } : {}) }));

def('road-ride', 'Riding on the road', {
  view: 'side', loop: true, thumb: 0, fixture: BIKE,
  path: { kind: 'line', length: 560, speed: 260 },
  keyframes: spin(),
});
def('ride-loop', 'Riding laps', {
  view: 'three-quarter', loop: true, thumb: 0, fixture: BIKE,
  path: { kind: 'circle', radius: 300, turn: 1, speed: 260 },
  keyframes: spin({ lean: 38 }, 0.08, () => ({ bend: 6 })),
});
def('high-cadence-spin', 'High-cadence spin-up', {
  view: 'side', loop: true, thumb: 0, fixture: BIKE,
  path: { kind: 'line', length: 560, speed: 300 },
  keyframes: spin({}, 0.045),
});
def('seated-climb', 'Seated climb', {
  view: 'side', loop: true, thumb: 0, fixture: BIKE,
  path: { kind: 'line', length: 420, speed: 110, grade: 0.12 },
  keyframes: spin({ lean: 44 }, 0.11),
});
def('seated-climb-low', 'Seated climb, chest low', {
  view: 'side', loop: true, thumb: 0, fixture: BIKE,
  path: { kind: 'line', length: 420, speed: 100, grade: 0.14 },
  keyframes: spin({ lean: 54 }, 0.12),
});
/** Out of the saddle: the bike rocks side to side under the rider. */
const standSpin = (move, rock = 6) => DEGS.map((d, i) => kf({ ...pedal(-d, { lean: 30, stand: true }), bend: Math.sin((d * Math.PI) / 180) * rock }, 'seat', { move, ...(i === 0 ? { surface: 28 } : {}) }));
def('standing-sprint', 'Standing sprint', {
  view: 'three-quarter', loop: true, thumb: 0, fixture: STAND_BIKE,
  path: { kind: 'line', length: 600, speed: 380 },
  keyframes: standSpin(0.07, 9),
});
def('standing-climb', 'Standing climb', {
  view: 'side', loop: true, thumb: 0, fixture: STAND_BIKE,
  path: { kind: 'line', length: 420, speed: 120, grade: 0.12 },
  keyframes: standSpin(0.12, 6),
});
/** One leg pedalling a full circle, the other unclipped and resting out to the side. */
def('single-leg-pedaling', 'Single-leg pedalling', {
  view: 'three-quarter', loop: true, thumb: 0, fixture: BIKE,
  path: { kind: 'line', length: 500, speed: 200 },
  keyframes: spin({}, 0.1, () => ({ hipR: 40, kneeR: 50, ankleR: 10, hipAbdR: 26 })),
});

// ── Mountain bike ──────────────────────────────────────────────────────────
/** Attack position: standing, pedals level, knees and elbows bent, hips back. */
const attack = (sink = 0) => ({ ...pedal(0, { lean: 40 + sink, stand: true }), elbowL: 70 + sink, elbowR: 70 + sink });
def('mtb-attack-descent', 'Descending in the attack position', {
  view: 'side', loop: true, thumb: 0, fixture: STAND_BIKE,
  path: { kind: 'line', length: 560, speed: 280, grade: -0.12 },
  keyframes: [kf(attack(), 'seat', { move: 0.4, surface: 28 }), kf(attack(8), 'seat', { move: 0.4 })],
});
/** Switchback: the outside (right) pedal down with weight on it, looking through the turn. */
const outsideDown = () => ({ ...pedal(-90, { lean: 36, stand: true }), neckTurn: 20, turn: 6 });
def('mtb-switchback', 'Switchback corner', {
  view: 'three-quarter', loop: true, thumb: 0, fixture: STAND_BIKE,
  path: { kind: 'circle', radius: 130, turn: 1, speed: 110 },
  keyframes: [kf(outsideDown(), 'seat', { move: 0.6, surface: 28 }), kf({ ...outsideDown(), bend: 4 }, 'seat', { move: 0.6 })],
});
def('mtb-trackstand', 'Trackstand', {
  view: 'side', loop: true, thumb: 0, fixture: STAND_BIKE,
  keyframes: [
    kf({ ...attack(), bend: -3 }, 'seat', { move: 0.7, hold: 0.2, surface: 28 }),
    kf({ ...attack(2), bend: 3 }, 'seat', { move: 0.7, hold: 0.2 }),
  ],
});
/** Compress into the bike, then hips back and the front wheel comes up. */
def('mtb-wheel-lift', 'Front-wheel lift', {
  view: 'side', thumb: 2, fixture: STAND_BIKE,
  keyframes: [
    kf(attack(), 'seat', { hold: 0.3, move: 0.3, surface: 28 }),
    kf(attack(16), 'seat', { hold: 0.1, move: 0.2 }),
    kf({ ...attack(-18), elbowL: 10, elbowR: 10 }, 'seat', { hold: 0.4, move: 0.4, fx: { pitch: 10 } }),
    kf(attack(), 'seat', { hold: 0.3 }),
  ],
});
def('bmx-manual', 'Manual', {
  view: 'side', loop: true, thumb: 1, fixture: STAND_BIKE,
  path: { kind: 'line', length: 440, speed: 150 },
  keyframes: [
    kf(attack(), 'seat', { move: 0.4, surface: 28 }),
    kf({ ...attack(-20), elbowL: 6, elbowR: 6 }, 'seat', { hold: 1.2, move: 0.3, fx: { pitch: 18 } }),
    kf({ ...attack(-18), elbowL: 8, elbowR: 8 }, 'seat', { hold: 0.6, move: 0.5, fx: { pitch: 16 } }),
  ],
});

// ── BMX ────────────────────────────────────────────────────────────────────
/** On the gate: balanced back, then the hips snap forward into the first strokes. */
def('bmx-gate-start', 'Gate start', {
  view: 'side', thumb: 2, fixture: STAND_BIKE,
  keyframes: [
    kf({ ...pedal(-30, { lean: 26, stand: true }) }, 'seat', { hold: 0.5, move: 0.3, surface: 28 }),
    kf({ ...pedal(-30, { lean: 20, stand: true }), elbowL: 10, elbowR: 10 }, 'seat', { hold: 0.2, move: 0.14, fx: { shift: -4 } }),
    kf({ ...pedal(-80, { lean: 44, stand: true }), elbowL: 80, elbowR: 80 }, 'seat', { move: 0.14, fx: { shift: 12 } }),
    ...[1, 2, 3, 4].map((n) => kf({ ...pedal(-80 - n * 90, { lean: 40, stand: true }), bend: n % 2 ? 6 : -6 }, 'seat', { move: 0.12, fx: { shift: 12 + n * 45 } })),
  ],
});
def('bmx-sprint', 'Straight sprint', {
  view: 'side', loop: true, thumb: 0, fixture: STAND_BIKE,
  path: { kind: 'line', length: 620, speed: 400 },
  keyframes: standSpin(0.065, 8).map((k) => ({ ...k, pose: { ...k.pose, spine: (k.pose.spine ?? 0) + 8 } })),
});
/** Pump track: no pedalling — push the bike down each roller's back side, unweight it going up. */
def('bmx-pump-track', 'Pump-track laps', {
  view: 'side', loop: true, thumb: 0, fixture: STAND_BIKE,
  path: { kind: 'line', length: 600, speed: 240, wave: { amp: 14, length: 150 } },
  keyframes: [kf(attack(-6), 'seat', { move: 0.31, surface: 28 }), kf(attack(18), 'seat', { move: 0.31 })],
});
def('bmx-jump', 'Jump and absorb the landing', {
  view: 'side', thumb: 3, fixture: STAND_BIKE,
  keyframes: [
    kf(attack(), 'seat', { move: 0.3, surface: 28 }),
    kf(attack(18), 'seat', { move: 0.2, fx: { shift: 40, pitch: 8 } }),
    kf({ ...attack(-10), elbowL: 30, elbowR: 30 }, 'seat', { move: 0.3, fx: { shift: 100, lift: 32, pitch: 10 } }),
    kf(attack(-4), 'seat', { move: 0.3, fx: { shift: 160, lift: 42, pitch: 0 } }),
    kf(attack(22), 'seat', { hold: 0.3, move: 0.3, fx: { shift: 230, lift: 0, pitch: 0 } }),
  ],
});
def('bmx-berm', 'Berm corner', {
  view: 'three-quarter', loop: true, thumb: 0, fixture: STAND_BIKE,
  path: { kind: 'circle', radius: 160, turn: 1, speed: 220 },
  keyframes: [kf({ ...attack(), bend: 8, neckTurn: 20 }, 'seat', { move: 0.5, surface: 28 }), kf({ ...attack(12), bend: 10, neckTurn: 20 }, 'seat', { move: 0.5 })],
});

export const BIKES = lib.patterns;
void CRANK;
