/**
 * The rig and its canonical pose patterns — §9 job 2.
 *
 * "Rather than posing 1,500 items by hand, author one canonical pose pair per
 * movement pattern... and let each item inherit its pattern's pair." A pose is
 * a `[Joint: AngleDegrees]` dictionary. Every item references a pattern slug
 * rather than carrying its own angles; §7's expansion rules (unilateral mirror,
 * equipment swap) transform the inherited pair rather than requiring a new one.
 *
 * Angles are degrees of flexion from anatomical standing (0 = fully extended,
 * matching how a goniometer reads flexion). `null` means the joint is not
 * meaningfully posed for this pattern and the rig renders it at its rest angle.
 */

export const POSE_MODEL_VERSION = 1;

/** Every joint the rig exposes, left and right where paired (§9). */
export const JOINTS = [
  'spine', 'neck',
  'shoulderL', 'shoulderR',
  'elbowL', 'elbowR',
  'wristL', 'wristR',
  'hipL', 'hipR',
  'kneeL', 'kneeR',
  'ankleL', 'ankleR',
];

function pose(angles) {
  const full = Object.fromEntries(JOINTS.map((j) => [j, angles[j] ?? 0]));
  for (const key of Object.keys(angles)) {
    if (!JOINTS.includes(key)) throw new Error(`unknown joint ${JSON.stringify(key)}`);
  }
  return full;
}

/**
 * Roughly 25–35 pairs once drills are included (§9). Each is named for the
 * movement pattern it represents, not for any one exercise — a trap-bar
 * deadlift and a kettlebell swing both inherit `hinge`.
 */
export const POSE_PATTERNS = [
  {
    slug: 'squat',
    name: 'Squat',
    start: pose({ hipL: 15, hipR: 15, kneeL: 10, kneeR: 10, ankleL: 5, ankleR: 5, spine: 5 }),
    end: pose({ hipL: 95, hipR: 95, kneeL: 100, kneeR: 100, ankleL: 25, ankleR: 25, spine: 25 }),
  },
  {
    slug: 'hinge',
    name: 'Hip hinge',
    start: pose({ hipL: 10, hipR: 10, kneeL: 15, kneeR: 15, spine: 5 }),
    end: pose({ hipL: 80, hipR: 80, kneeL: 20, kneeR: 20, spine: 30 }),
  },
  {
    slug: 'lunge',
    name: 'Lunge',
    start: pose({ hipL: 10, hipR: 10, kneeL: 10, kneeR: 10, spine: 5 }),
    end: pose({ hipL: 80, hipR: 20, kneeL: 95, kneeR: 100, ankleR: 20, spine: 8 }),
  },
  {
    slug: 'split-squat',
    name: 'Split squat',
    start: pose({ hipL: 20, hipR: 10, kneeL: 30, kneeR: 15, ankleR: 10, spine: 5 }),
    end: pose({ hipL: 70, hipR: 15, kneeL: 100, kneeR: 90, ankleR: 25, spine: 8 }),
  },
  {
    slug: 'single-leg-rdl',
    name: 'Single-leg RDL',
    start: pose({ hipL: 10, hipR: 10, kneeL: 10, kneeR: 15, spine: 5 }),
    end: pose({ hipL: 90, hipR: 10, kneeL: 15, kneeR: 20, spine: 35, hipR: 40 }),
  },
  {
    slug: 'horizontal-push',
    name: 'Horizontal push',
    start: pose({ shoulderL: 90, shoulderR: 90, elbowL: 90, elbowR: 90, spine: 0 }),
    end: pose({ shoulderL: 90, shoulderR: 90, elbowL: 175, elbowR: 175, spine: 0 }),
  },
  {
    slug: 'horizontal-pull',
    name: 'Horizontal pull',
    start: pose({ shoulderL: 90, shoulderR: 90, elbowL: 175, elbowR: 175, spine: 5 }),
    end: pose({ shoulderL: 40, shoulderR: 40, elbowL: 60, elbowR: 60, spine: 5 }),
  },
  {
    slug: 'vertical-push',
    name: 'Overhead press',
    start: pose({ shoulderL: 90, shoulderR: 90, elbowL: 90, elbowR: 90 }),
    end: pose({ shoulderL: 175, shoulderR: 175, elbowL: 175, elbowR: 175 }),
  },
  {
    slug: 'vertical-pull',
    name: 'Vertical pull',
    start: pose({ shoulderL: 175, shoulderR: 175, elbowL: 170, elbowR: 170 }),
    end: pose({ shoulderL: 60, shoulderR: 60, elbowL: 40, elbowR: 40 }),
  },
  {
    slug: 'anti-rotation-press',
    name: 'Anti-rotation press',
    start: pose({ shoulderL: 70, shoulderR: 70, elbowL: 60, elbowR: 60, spine: 0, hipL: 10, hipR: 10 }),
    end: pose({ shoulderL: 90, shoulderR: 90, elbowL: 175, elbowR: 175, spine: 0, hipL: 10, hipR: 10 }),
  },
  {
    slug: 'trunk-flexion',
    name: 'Trunk flexion',
    start: pose({ spine: 0, hipL: 15, hipR: 15, kneeL: 90, kneeR: 90 }),
    end: pose({ spine: 45, hipL: 15, hipR: 15, kneeL: 90, kneeR: 90 }),
  },
  {
    slug: 'trunk-rotation',
    name: 'Trunk rotation',
    start: pose({ spine: 5, hipL: 10, hipR: 10 }),
    end: pose({ spine: 35, hipL: 25, hipR: 5 }),
  },
  {
    slug: 'carry',
    name: 'Loaded carry',
    start: pose({ shoulderL: 10, shoulderR: 10, elbowL: 5, elbowR: 5, spine: 0, hipL: 5, hipR: 20, kneeL: 5, kneeR: 15 }),
    end: pose({ shoulderL: 10, shoulderR: 10, elbowL: 5, elbowR: 5, spine: 0, hipL: 20, hipR: 5, kneeL: 15, kneeR: 5 }),
  },
  {
    slug: 'pogo',
    name: 'Pogo / ankle bounce',
    start: pose({ hipL: 10, hipR: 10, kneeL: 15, kneeR: 15, ankleL: 25, ankleR: 25 }),
    end: pose({ hipL: 5, hipR: 5, kneeL: 5, kneeR: 5, ankleL: 5, ankleR: 5 }),
  },
  {
    slug: 'vertical-jump',
    name: 'Vertical jump',
    start: pose({ hipL: 70, hipR: 70, kneeL: 90, kneeR: 90, ankleL: 20, ankleR: 20, spine: 15, shoulderL: 150, shoulderR: 150 }),
    end: pose({ hipL: 10, hipR: 10, kneeL: 10, kneeR: 10, ankleL: 45, ankleR: 45, spine: 0, shoulderL: 10, shoulderR: 10 }),
  },
  {
    slug: 'broad-jump',
    name: 'Broad jump',
    start: pose({ hipL: 75, hipR: 75, kneeL: 95, kneeR: 95, ankleL: 20, ankleR: 20, spine: 20 }),
    end: pose({ hipL: 20, hipR: 20, kneeL: 40, kneeR: 40, ankleL: 25, ankleR: 25, spine: 10 }),
  },
  {
    slug: 'bound',
    name: 'Single-leg bound',
    start: pose({ hipL: 60, kneeL: 80, ankleL: 20, hipR: 10, kneeR: 10, spine: 10 }),
    end: pose({ hipR: 60, kneeR: 80, ankleR: 20, hipL: 10, kneeL: 10, spine: 10 }),
  },
  {
    slug: 'lateral-bound',
    name: 'Lateral bound',
    start: pose({ hipL: 70, kneeL: 90, ankleL: 20, hipR: 15, kneeR: 15, spine: 10 }),
    end: pose({ hipR: 70, kneeR: 90, ankleR: 20, hipL: 15, kneeL: 15, spine: 10 }),
  },
  {
    slug: 'sprint-start',
    name: 'Sprint start',
    start: pose({ hipL: 90, kneeL: 110, ankleL: 30, hipR: 40, kneeR: 60, ankleR: 15, spine: 30, shoulderL: 60, shoulderR: 140 }),
    end: pose({ hipL: 20, kneeL: 30, ankleL: 10, hipR: 60, kneeR: 90, ankleR: 20, spine: 15, shoulderL: 140, shoulderR: 60 }),
  },
  {
    slug: 'sprint-cycle',
    name: 'Sprint drive cycle',
    start: pose({ hipL: 50, kneeL: 100, ankleL: 15, hipR: 10, kneeR: 15, ankleR: 5, spine: 10 }),
    end: pose({ hipR: 50, kneeR: 100, ankleR: 15, hipL: 10, kneeL: 15, ankleL: 5, spine: 10 }),
  },
  {
    slug: 'deceleration-plant',
    name: 'Deceleration plant',
    start: pose({ hipL: 20, kneeL: 25, ankleL: 10, hipR: 15, kneeR: 20, spine: 5 }),
    end: pose({ hipL: 90, kneeL: 105, ankleL: 30, hipR: 20, kneeR: 25, spine: 20 }),
  },
  {
    slug: 'cut',
    name: 'Change of direction cut',
    start: pose({ hipL: 85, kneeL: 100, ankleL: 25, spine: 20, hipR: 20, kneeR: 25 }),
    end: pose({ hipR: 30, kneeR: 40, ankleR: 15, spine: 10, hipL: 30, kneeL: 40 }),
  },
  {
    slug: 'lateral-shuffle',
    name: 'Lateral shuffle',
    start: pose({ hipL: 60, hipR: 60, kneeL: 75, kneeR: 75, ankleL: 15, ankleR: 15, spine: 10 }),
    end: pose({ hipL: 55, hipR: 65, kneeL: 70, kneeR: 80, ankleL: 15, ankleR: 15, spine: 10 }),
  },
  {
    slug: 'crossover-stride',
    name: 'Crossover stride',
    start: pose({ hipL: 40, kneeL: 50, ankleL: 30, hipR: 70, kneeR: 90, spine: 15 }),
    end: pose({ hipR: 20, kneeR: 25, ankleR: 15, hipL: 15, kneeL: 20, spine: 10 }),
  },
  {
    slug: 'single-leg-balance',
    name: 'Single-leg balance',
    start: pose({ hipL: 10, kneeL: 10, ankleL: 5, hipR: 60, kneeR: 90, spine: 5 }),
    end: pose({ hipL: 15, kneeL: 20, ankleL: 8, hipR: 55, kneeR: 85, spine: 8 }),
  },
  {
    slug: 'landing',
    name: 'Landing mechanics',
    start: pose({ hipL: 10, hipR: 10, kneeL: 10, kneeR: 10, ankleL: 20, ankleR: 20, spine: 10 }),
    end: pose({ hipL: 80, hipR: 80, kneeL: 95, kneeR: 95, ankleL: 30, ankleR: 30, spine: 25 }),
  },
  {
    slug: 'overhead-throw',
    name: 'Overhead throw',
    start: pose({ shoulderR: 150, elbowR: 100, spine: 20, hipR: 40, hipL: 10 }),
    end: pose({ shoulderR: 30, elbowR: 170, spine: 5, hipR: 10, hipL: 30 }),
  },
  {
    slug: 'rotational-throw',
    name: 'Rotational throw',
    start: pose({ shoulderR: 90, elbowR: 90, spine: 30, hipR: 30, hipL: 10 }),
    end: pose({ shoulderR: 40, elbowR: 160, spine: 5, hipR: 10, hipL: 30 }),
  },
  {
    slug: 'instep-strike',
    name: 'Instep strike',
    start: pose({ hipR: 70, kneeR: 30, ankleR: 20, hipL: 10, kneeL: 15, spine: 10 }),
    end: pose({ hipR: 10, kneeR: 170, ankleR: 40, hipL: 15, kneeL: 20, spine: 15 }),
  },
  {
    slug: 'skating-stride',
    name: 'Skating stride',
    start: pose({ hipL: 60, kneeL: 90, ankleL: 15, hipR: 30, kneeR: 60, ankleR: 10, spine: 20 }),
    end: pose({ hipR: 10, kneeR: 20, ankleR: 5, hipL: 40, kneeL: 70, spine: 15 }),
  },
  {
    slug: 'swing-stride',
    name: 'Batting / swing stride',
    start: pose({ hipR: 20, kneeR: 15, hipL: 15, kneeL: 10, spine: 10, shoulderR: 90 }),
    end: pose({ hipR: 15, kneeR: 20, hipL: 30, kneeL: 40, spine: 30, shoulderR: 40 }),
  },
  {
    slug: 'isometric-hold',
    name: 'Isometric hold',
    start: pose({ hipL: 45, hipR: 45, kneeL: 60, kneeR: 60, spine: 10 }),
    end: pose({ hipL: 45, hipR: 45, kneeL: 60, kneeR: 60, spine: 10 }),
  },
  {
    slug: 'mobility-flow',
    name: 'Mobility flow',
    start: pose({ hipL: 30, hipR: 90, kneeL: 20, kneeR: 90, spine: 10 }),
    end: pose({ hipL: 90, hipR: 30, kneeL: 90, kneeR: 20, spine: 10 }),
  },
];

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
