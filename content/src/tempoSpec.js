/**
 * Tempo variants (slow lowering, held position, explosive lift) reuse their
 * base movement pattern with different timing: the same keyframes, only the
 * holds and move durations change. This file says which segments of each base
 * pattern are the lowering (`ecc`) and the lifting (`con`) and which keyframes
 * are the position to hold (`mid`). Segment `i` is the move from keyframe `i`
 * to keyframe `i + 1`. Pure data and arithmetic: no pose maths, so the
 * catalogue can use it without loading the pose library.
 */

export const TEMPO_PATTERN_SPEC = {
  'vertical-jump': { ecc: [0], con: [1, 2], mid: [1] },
  'deadlift-trapbar': { ecc: [4], con: [0, 1, 2, 3], mid: [2] },
  'goblet-squat': { ecc: [0], con: [1], mid: [1] },
  'back-squat': { ecc: [0], con: [1], mid: [1] },
  'front-squat': { ecc: [0], con: [1], mid: [1] },
  'bulgarian-split-squat': { ecc: [0], con: [1], mid: [1] },
  'split-squat': { ecc: [0], con: [1], mid: [1] },
  'squat-bodyweight': { ecc: [0], con: [1], mid: [1] },
  'push-up': { ecc: [0, 1, 2, 3], con: [4, 5, 6, 7], mid: [4] },
  'bench-press': { ecc: [0], con: [1], mid: [1] },
  'dumbbell-bench-press': { ecc: [0], con: [1], mid: [1] },
  'pull-up': { ecc: [1], con: [0], mid: [1] },
  'inverted-row': { ecc: [1], con: [0], mid: [1] },
  'prone-ytw': { ecc: [3], con: [0], mid: [1, 2, 3] },
  'pallof-press': { ecc: [1], con: [0], mid: [1] },
  'single-leg-rdl-bodyweight': { ecc: [0], con: [1], mid: [1] },
  rdl: { ecc: [0, 1, 2], con: [3, 4, 5], mid: [3] },
  'hip-thrust': { ecc: [3, 4, 5], con: [0, 1, 2], mid: [3] },
  'reverse-lunge-dumbbells': { ecc: [0, 1], con: [2, 3], mid: [2] },
  'hamstring-slider-curl': { ecc: [0], con: [1], mid: [1] },
  'overhead-press-dumbbells': { ecc: [1], con: [0], mid: [1] },
  'dumbbell-row': { ecc: [1], con: [0], mid: [1] },
  'biceps-curl': { ecc: [1], con: [0], mid: [1] },
  'calf-raise-step-straight': { ecc: [1], con: [0], mid: [1] },
};

export const SLOW_LOWERING_SECONDS = 3.5;
export const HELD_POSITION_SECONDS = 3;
const FAST_LIFT_FACTOR = 0.45;
const FASTEST_MOVE = 0.1;

export const tempoPatternSlug = (pattern, kind) => `${pattern}-${kind}`;

export const TEMPO_PATTERN_NAME = {
  eccentric: (name) => `${name} (slow lowering)`,
  isometric: (name) => `${name} (held position)`,
  explosive: (name) => `${name} (fast lift)`,
};

/** The keyframes of a base pattern retimed for one tempo kind. */
export function tempoKeyframes(frames, spec, kind) {
  const out = frames.map((k) => ({ ...k }));
  const move = (i) => out[i].move ?? 0.6;
  if (kind === 'eccentric') {
    const total = spec.ecc.reduce((a, i) => a + move(i), 0);
    const scale = Math.max(1, SLOW_LOWERING_SECONDS / total);
    for (const i of spec.ecc) out[i].move = move(i) * scale;
  } else if (kind === 'isometric') {
    const hold = spec.mid.length > 1 ? HELD_POSITION_SECONDS * 0.8 : HELD_POSITION_SECONDS;
    for (const i of spec.mid) out[i].hold = Math.max(out[i].hold ?? 0, hold);
  } else if (kind === 'explosive') {
    for (const i of spec.con) out[i].move = Math.max(FASTEST_MOVE, move(i) * FAST_LIFT_FACTOR);
    for (const i of spec.mid) out[i].hold = Math.min(out[i].hold ?? 0, 0.05);
  } else {
    throw new Error(`unknown tempo kind ${JSON.stringify(kind)}`);
  }
  return out;
}
