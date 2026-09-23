/**
 * The rig and its canonical pose patterns — §9 job 2.
 *
 * "Rather than posing 1,500 items by hand, author one canonical pose pair per
 * movement pattern... and let each item inherit its pattern's pair." A pose is
 * a `[Joint: AngleDegrees]` dictionary. Every item references a pattern slug
 * rather than carrying its own angles; §7's expansion rules (unilateral mirror,
 * equipment swap) transform the inherited pair rather than requiring a new one.
 *
 * The figure is drawn in side view, facing right, and every angle is an
 * anatomical flexion measured the same way (RigPoseView.swift implements
 * exactly this):
 *   spine    torso lean from vertical — + forward, − back (−90 lying on the back)
 *   neck     head relative to the torso — + chin down
 *   shoulder arm from hanging along the torso — + forward/up (90 level, 180 overhead), − behind
 *   elbow    0 straight, + bent
 *   wrist    + flexed
 *   hip      thigh relative to the torso line — + forward (90 = sitting), − behind
 *   knee     0 straight, + heel back
 *   ankle    + shin over the toes (dorsiflexion), − up on the toes
 *   lift     height of the lowest point off the ground (jumps, hangs)
 * `L` is the near side of the figure, `R` the far side.
 */

export const POSE_MODEL_VERSION = 2;

/** Every joint the rig exposes, left and right where paired (§9). */
export const JOINTS = [
  'spine', 'neck',
  'shoulderL', 'shoulderR',
  'elbowL', 'elbowR',
  'wristL', 'wristR',
  'hipL', 'hipR',
  'kneeL', 'kneeR',
  'ankleL', 'ankleR',
  'lift',
];

function pose(angles) {
  const full = Object.fromEntries(JOINTS.map((j) => [j, angles[j] ?? 0]));
  for (const key of Object.keys(angles)) {
    if (!JOINTS.includes(key)) throw new Error(`unknown joint ${JSON.stringify(key)}`);
  }
  return full;
}

/** Both sides the same — most strength patterns are symmetrical. */
function both(angles) {
  const out = {};
  for (const [k, v] of Object.entries(angles)) {
    if (['shoulder', 'elbow', 'wrist', 'hip', 'knee', 'ankle'].includes(k)) {
      out[`${k}L`] = v;
      out[`${k}R`] = v;
    } else {
      out[k] = v;
    }
  }
  return out;
}

/**
 * Roughly 25–35 pairs once drills are included (§9). Each is named for the
 * movement pattern it represents, not for any one exercise — a trap-bar
 * deadlift and a kettlebell swing both inherit `hinge`.
 */
export const POSE_PATTERNS = [
  { slug: 'squat', name: 'Squat',
    start: pose(both({ shoulder: 35, elbow: 115, knee: 4 })),
    end: pose(both({ spine: 38, hip: 108, knee: 118, ankle: 44, shoulder: 60, elbow: 115 })) },
  { slug: 'hinge', name: 'Hip hinge',
    start: pose(both({ knee: 8, shoulder: 4 })),
    end: pose(both({ spine: 72, hip: 76, knee: 18, ankle: 6, shoulder: 70 })) },
  { slug: 'lunge', name: 'Lunge',
    start: pose({ ...both({ shoulder: 4 }), hipL: 8, hipR: -6, kneeR: 6 }),
    end: pose({ ...both({ shoulder: 8 }), spine: 4, hipL: 92, kneeL: 94, ankleL: 22, hipR: -18, kneeR: 104, ankleR: -32 }) },
  { slug: 'split-squat', name: 'Split squat',
    start: pose({ ...both({ shoulder: 4 }), hipL: 32, kneeL: 26, ankleL: 8, hipR: -22, kneeR: 34, ankleR: -36 }),
    end: pose({ ...both({ shoulder: 8 }), spine: 6, hipL: 90, kneeL: 96, ankleL: 22, hipR: -8, kneeR: 102, ankleR: -40 }) },
  { slug: 'single-leg-rdl', name: 'Single-leg RDL',
    start: pose({ ...both({ shoulder: 4 }), hipL: 2, kneeL: 10, hipR: 4, kneeR: 12 }),
    end: pose({ ...both({ shoulder: 84 }), spine: 84, hipL: 82, kneeL: 16, ankleL: 8, hipR: 2, kneeR: 4 }) },
  { slug: 'horizontal-push', name: 'Push-up',
    start: pose(both({ spine: 72, shoulder: 78, elbow: 0, hip: 0, knee: 0, ankle: 14 })),
    end: pose(both({ spine: 82, shoulder: 38, elbow: 86, hip: 0, knee: 0, ankle: 8 })) },
  { slug: 'horizontal-pull', name: 'Row',
    start: pose(both({ spine: 55, hip: 62, knee: 22, ankle: 12, shoulder: 55, elbow: 4 })),
    end: pose(both({ spine: 55, hip: 62, knee: 22, ankle: 12, shoulder: -8, elbow: 98 })) },
  { slug: 'vertical-push', name: 'Overhead press',
    start: pose(both({ shoulder: 32, elbow: 138 })),
    end: pose(both({ shoulder: 176, elbow: 4 })) },
  { slug: 'vertical-pull', name: 'Pull-up',
    start: pose(both({ shoulder: 176, elbow: 6, hip: 8, knee: 30, lift: 8 })),
    end: pose(both({ shoulder: 24, elbow: 140, hip: 20, knee: 40, lift: 34 })) },
  { slug: 'anti-rotation-press', name: 'Anti-rotation press',
    start: pose(both({ spine: 8, hip: 16, knee: 18, ankle: 10, shoulder: 28, elbow: 112 })),
    end: pose(both({ spine: 8, hip: 16, knee: 18, ankle: 10, shoulder: 88, elbow: 2 })) },
  { slug: 'trunk-flexion', name: 'Crunch',
    start: pose(both({ spine: -90, hip: 48, knee: 94, ankle: 10, shoulder: 150, elbow: 140 })),
    end: pose(both({ spine: -58, hip: 42, knee: 94, ankle: 10, shoulder: 150, elbow: 140, neck: 18 })) },
  { slug: 'trunk-rotation', name: 'Trunk rotation',
    start: pose({ ...both({ spine: -32, hip: 72, knee: 88, ankle: 6 }), shoulderL: 70, elbowL: 30, shoulderR: 60, elbowR: 30 }),
    end: pose({ ...both({ spine: -28, hip: 72, knee: 88, ankle: 6 }), shoulderL: 40, elbowL: 20, shoulderR: 96, elbowR: 30 }) },
  { slug: 'carry', name: 'Loaded carry',
    start: pose({ ...both({ shoulder: 2 }), hipL: 24, kneeL: 12, ankleL: 4, hipR: -12, kneeR: 16, ankleR: -10 }),
    end: pose({ ...both({ shoulder: 2 }), hipL: -12, kneeL: 16, ankleL: -10, hipR: 24, kneeR: 12, ankleR: 4 }) },
  { slug: 'pogo', name: 'Pogo hops',
    start: pose(both({ knee: 12, ankle: 14, shoulder: 14, elbow: 70 })),
    end: pose(both({ knee: 4, ankle: -26, shoulder: 14, elbow: 70, lift: 7 })) },
  { slug: 'vertical-jump', name: 'Vertical jump',
    start: pose(both({ spine: 42, hip: 92, knee: 96, ankle: 32, shoulder: -48, elbow: 10 })),
    end: pose(both({ spine: -2, hip: -4, knee: 4, ankle: -36, shoulder: 170, elbow: 6, lift: 26 })) },
  { slug: 'broad-jump', name: 'Broad jump',
    start: pose(both({ spine: 50, hip: 96, knee: 90, ankle: 30, shoulder: -52, elbow: 10 })),
    end: pose(both({ spine: 24, hip: 74, knee: 64, ankle: 8, shoulder: 126, elbow: 12, lift: 16 })) },
  { slug: 'bound', name: 'Bounding',
    start: pose({ spine: 10, hipL: -18, kneeL: 22, ankleL: -24, hipR: 78, kneeR: 86, ankleR: 10, shoulderL: 64, elbowL: 86, shoulderR: -46, elbowR: 70 }),
    end: pose({ spine: 10, hipL: 80, kneeL: 84, ankleL: 10, hipR: -24, kneeR: 40, ankleR: -24, shoulderL: -46, elbowL: 70, shoulderR: 64, elbowR: 86, lift: 14 }) },
  { slug: 'lateral-bound', name: 'Lateral bound',
    start: pose(both({ spine: 34, hip: 78, knee: 78, ankle: 26, shoulder: -20, elbow: 40 })),
    end: pose(both({ spine: 12, hip: 22, knee: 24, ankle: -18, shoulder: 70, elbow: 40, lift: 14 })) },
  { slug: 'sprint-start', name: 'Sprint start',
    start: pose({ spine: 74, hipL: 118, kneeL: 104, ankleL: 20, hipR: 62, kneeR: 118, ankleR: 20, shoulderL: 74, shoulderR: 74 }),
    end: pose({ spine: 48, hipL: -12, kneeL: 18, ankleL: -30, hipR: 96, kneeR: 104, ankleR: 12, shoulderL: -52, elbowL: 84, shoulderR: 84, elbowR: 84 }) },
  { slug: 'sprint-cycle', name: 'Sprinting',
    start: pose({ spine: 8, hipL: 84, kneeL: 104, ankleL: 12, hipR: -22, kneeR: 46, ankleR: -24, shoulderL: -48, elbowL: 84, shoulderR: 66, elbowR: 84, lift: 5 }),
    end: pose({ spine: 8, hipL: -22, kneeL: 46, ankleL: -24, hipR: 84, kneeR: 104, ankleR: 12, shoulderL: 66, elbowL: 84, shoulderR: -48, elbowR: 84, lift: 5 }) },
  { slug: 'deceleration-plant', name: 'Deceleration',
    start: pose({ spine: 14, hipL: 52, kneeL: 34, ankleL: 8, hipR: -18, kneeR: 44, ankleR: -20, shoulderL: -30, elbowL: 80, shoulderR: 50, elbowR: 80, lift: 3 }),
    end: pose({ spine: 4, hipL: 70, kneeL: 72, ankleL: 22, hipR: 22, kneeR: 70, ankleR: 14, shoulderL: 40, elbowL: 70, shoulderR: 30, elbowR: 70 }) },
  { slug: 'cut', name: 'Cut',
    start: pose({ spine: 24, hipL: 74, kneeL: 76, ankleL: 24, hipR: 30, kneeR: 64, ankleR: 10, shoulderL: 30, elbowL: 80, shoulderR: 20, elbowR: 80 }),
    end: pose({ spine: 34, hipL: 98, kneeL: 86, ankleL: 20, hipR: -14, kneeR: 22, ankleR: -30, shoulderL: -40, elbowL: 84, shoulderR: 64, elbowR: 84 }) },
  { slug: 'lateral-shuffle', name: 'Athletic stance shuffle',
    start: pose(both({ spine: 30, hip: 58, knee: 60, ankle: 26, shoulder: 26, elbow: 60 })),
    end: pose(both({ spine: 30, hip: 52, knee: 50, ankle: 18, shoulder: 26, elbow: 60, lift: 3 })) },
  { slug: 'crossover-stride', name: 'Crossover stride',
    start: pose({ spine: 22, hipL: 70, kneeL: 84, ankleL: 14, hipR: -12, kneeR: 30, ankleR: -22, shoulderL: -34, elbowL: 84, shoulderR: 54, elbowR: 84, lift: 2 }),
    end: pose({ spine: 22, hipL: -12, kneeL: 30, ankleL: -22, hipR: 70, kneeR: 84, ankleR: 14, shoulderL: 54, elbowL: 84, shoulderR: -34, elbowR: 84, lift: 2 }) },
  { slug: 'single-leg-balance', name: 'Single-leg balance',
    start: pose({ spine: 2, hipL: 4, kneeL: 8, hipR: 72, kneeR: 86, shoulderL: 20, shoulderR: 20 }),
    end: pose({ spine: 6, hipL: 10, kneeL: 16, ankleL: 8, hipR: 88, kneeR: 90, shoulderL: 40, shoulderR: 34 }) },
  { slug: 'landing', name: 'Landing',
    start: pose(both({ spine: 6, hip: 26, knee: 22, ankle: -24, shoulder: 60, elbow: 20, lift: 16 })),
    end: pose(both({ spine: 36, hip: 84, knee: 88, ankle: 30, shoulder: 50, elbow: 30 })) },
  { slug: 'overhead-throw', name: 'Overhead throw',
    start: pose({ ...both({ shoulder: 196, elbow: 64 }), spine: -14, hipL: 30, kneeL: 14, ankleL: 6, hipR: -18, kneeR: 16, ankleR: -18 }),
    end: pose({ ...both({ shoulder: 96, elbow: 4 }), spine: 22, hipL: 38, kneeL: 22, ankleL: 12, hipR: -8, kneeR: 12, ankleR: -30 }) },
  { slug: 'rotational-throw', name: 'Rotational throw',
    start: pose({ ...both({ shoulder: -34, elbow: 18 }), spine: 16, hipL: 32, kneeL: 30, ankleL: 12, hipR: 12, kneeR: 36, ankleR: 8 }),
    end: pose({ ...both({ shoulder: 104, elbow: 8 }), spine: 12, hipL: 24, kneeL: 16, ankleL: 8, hipR: -10, kneeR: 20, ankleR: -32 }) },
  { slug: 'instep-strike', name: 'Instep strike',
    start: pose({ spine: -4, hipL: -44, kneeL: 104, ankleL: -30, hipR: 22, kneeR: 28, ankleR: 14, shoulderL: -30, elbowL: 30, shoulderR: 64, elbowR: 30 }),
    end: pose({ spine: -16, hipL: 96, kneeL: 10, ankleL: -26, hipR: 12, kneeR: 22, ankleR: 10, shoulderL: 54, elbowL: 30, shoulderR: -24, elbowR: 30 }) },
  { slug: 'skating-stride', name: 'Skating stride',
    start: pose({ spine: 46, hipL: 86, kneeL: 78, ankleL: 26, hipR: 30, kneeR: 58, ankleR: 16, shoulderL: 38, elbowL: 40, shoulderR: -26, elbowR: 30 }),
    end: pose({ spine: 46, hipL: 88, kneeL: 82, ankleL: 28, hipR: -16, kneeR: 8, ankleR: -12, shoulderL: -26, elbowL: 30, shoulderR: 38, elbowR: 40 }) },
  { slug: 'swing-stride', name: 'Swing',
    start: pose({ ...both({ shoulder: -18, elbow: 72 }), spine: 26, hipL: 30, kneeL: 22, ankleL: 12, hipR: 24, kneeR: 26, ankleR: 10 }),
    end: pose({ ...both({ shoulder: 112, elbow: 22 }), spine: 16, hipL: 22, kneeL: 12, ankleL: 8, hipR: 6, kneeR: 24, ankleR: -30 }) },
  { slug: 'isometric-hold', name: 'Plank',
    start: pose(both({ spine: 80, shoulder: 92, elbow: 92, hip: 0, knee: 0, ankle: 14 })),
    end: pose(both({ spine: 82, shoulder: 92, elbow: 92, hip: 4, knee: 0, ankle: 12 })) },
  { slug: 'mobility-flow', name: 'Lunge with reach',
    start: pose({ spine: 10, hipL: 96, kneeL: 96, ankleL: 24, hipR: -30, kneeR: 20, ankleR: -30, shoulderL: 20, shoulderR: 20 }),
    end: pose({ spine: -8, hipL: 100, kneeL: 98, ankleL: 26, hipR: -36, kneeR: 16, ankleR: -30, shoulderL: 176, shoulderR: 40 }) },
];

/**
 * Continuous rhythms — the end pose flows straight back into the start (a
 * stride, a hop, a shuffle), so the animation loops back and forth. Every
 * other pattern is one rep: it plays start → end, holds, and cuts to the start.
 */
export const LOOPING_PATTERNS = new Set([
  'carry', 'pogo', 'bound', 'sprint-cycle', 'lateral-shuffle', 'crossover-stride', 'skating-stride', 'isometric-hold',
]);

export const POSE_PATTERN_SLUGS = POSE_PATTERNS.map((p) => p.slug);

const BY_SLUG = new Map(POSE_PATTERNS.map((p) => [p.slug, p]));

export function posePattern(slug) {
  const found = BY_SLUG.get(slug);
  if (!found) throw new Error(`unknown pose pattern ${JSON.stringify(slug)}`);
  return found;
}

export function isPosePattern(slug) {
  return BY_SLUG.has(slug);
}

/**
 * §7's unilateral expansion mirrors and dims one side. Mirroring swaps every
 * L/R joint pair and is its own inverse, which is what a test asserts.
 */
export function mirrorPose(angles) {
  const mirrored = {};
  for (const joint of JOINTS) {
    if (joint.endsWith('L')) mirrored[joint] = angles[joint.slice(0, -1) + 'R'];
    else if (joint.endsWith('R')) mirrored[joint] = angles[joint.slice(0, -1) + 'L'];
    else mirrored[joint] = angles[joint];
  }
  return mirrored;
}
