/** Soccer striking (a left-footed strike, so the kicking leg is the near one). */
import { P, kf, library, mirror, solve } from './kit.js';

/** Bends the kicking (L) knee so the toe skims `h` above the grass at contact. */
const skim = (p, h = 2.5) => solve(p, 'kneeL', (sk) => sk.L.toe[1] - sk.R.ankle[1] - h, 0, 140);

const lib = library();
const def = lib.def;

const plant = { spine: 6, neck: -18, hipR: 40, kneeR: 30, ankleR: 16, hipAbdR: 6 };
def('soccer-instep-kick', 'Instep drive', {
  thumb: 2, fixture: { kind: 'kickball', frame: 2, side: 'L' },
  keyframes: [
    kf(P({ spine: 10, neck: -14, hipL: 40, kneeL: 30, ankleL: 10, hipR: -24, kneeR: 50, ankleR: -30, shoulderL: -30, shoulderR: 40, elbowL: 60, elbowR: 60 }), 'L', { hold: 0.2, move: 0.28 }),
    kf(P(plant, { hipL: -36, kneeL: 112, ankleL: -40, shoulderL: -20, shoulderR: 30, shoulderAbdR: 70, elbowR: 20, twist: 18 }), 'R', { hold: 0.05, move: 0.16, travel: [42, 0] }),
    kf(skim(P(plant, { hipL: 22, kneeL: 24, ankleL: -46, shoulderL: 30, shoulderR: 10, shoulderAbdR: 60, elbowR: 20, twist: -6, spine: 10 })), 'R', { move: 0.2 }),
    kf(P(plant, { spine: -2, hipL: 96, kneeL: 22, ankleL: -40, shoulderL: 50, shoulderR: -10, shoulderAbdR: 50, twist: -24, kneeR: 16, ankleR: -24 }), 'Rtoe', { hold: 0.35, move: 0.4 }),
    kf(P({ hipL: 30, kneeL: 20, ankleL: 10, hipR: 10, kneeR: 16, shoulderL: 10, shoulderR: 10 }), 'L', { hold: 0.2, travel: [26, 0] }),
  ],
});
def('soccer-static-strike', 'Instep strike from a standing start', {
  thumb: 1, fixture: { kind: 'kickball', frame: 1, side: 'L' },
  keyframes: [
    kf(P(plant, { hipL: -34, kneeL: 108, ankleL: -40, shoulderR: 30, shoulderAbdR: 70, elbowR: 20, twist: 16 }), 'R', { hold: 0.3, move: 0.2 }),
    kf(skim(P(plant, { hipL: 22, kneeL: 24, ankleL: -46, shoulderL: 30, shoulderAbdR: 60, twist: -6, spine: 10 })), 'R', { move: 0.22 }),
    kf(P(plant, { spine: -2, hipL: 90, kneeL: 20, ankleL: -40, shoulderL: 50, shoulderAbdR: 50, twist: -24 }), 'R', { hold: 0.4, move: 0.5 }),
    kf(P(plant, { hipL: -34, kneeL: 108, ankleL: -40, shoulderR: 30, shoulderAbdR: 70, elbowR: 20, twist: 16 }), 'R', { hold: 0.1 }),
  ],
});
/** Side-foot pass: open hip, ankle locked, push through the ball's middle. */
def('soccer-side-foot-pass', 'Side-foot pass', {
  view: 'three-quarter', thumb: 1, fixture: { kind: 'kickball', frame: 1, side: 'L' },
  keyframes: [
    kf(skim(P(plant, { hipL: -20, kneeL: 40, hipRotL: -50, ankleL: 10, shoulderAbdL: 30, shoulderAbdR: 30 }), 4), 'R', { hold: 0.3, move: 0.26 }),
    kf(skim(P(plant, { hipL: 16, kneeL: 20, hipRotL: -60, hipAbdL: 10, ankleL: 14, shoulderAbdL: 30, shoulderAbdR: 30 }), 1.5), 'R', { move: 0.22 }),
    kf(P(plant, { hipL: 40, kneeL: 16, hipRotL: -60, hipAbdL: 12, ankleL: 14, shoulderAbdL: 30, shoulderAbdR: 30 }), 'R', { hold: 0.35, move: 0.4 }),
    kf(skim(P(plant, { hipL: -20, kneeL: 40, hipRotL: -50, ankleL: 10, shoulderAbdL: 30, shoulderAbdR: 30 }), 4), 'R', { hold: 0.1 }),
  ],
});

export const SOCCER = lib.patterns;
export { mirror };
