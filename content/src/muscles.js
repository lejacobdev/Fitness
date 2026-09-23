/**
 * The muscle model — §6, deliberately kept alongside the quality model rather
 * than instead of it: "qualities drive selection, muscles drive the red
 * highlighting in §9 and the recovery spacing in §10. Both, not either."
 *
 * Every muscle carries a `plainName` because §12's writing register is "your
 * legs have done almost nothing explosive this week", not "insufficient
 * gastrocnemius stimulus". The anatomical `name` is what a coach or athletic
 * trainer reads; the `plainName` is what the app says.
 *
 * `region` groups muscles for the §10 recovery spacing (training the same region
 * hard on consecutive days is what the generator avoids) and for the body-map
 * picker in §15's Library tab.
 *
 * `views` says which side of the §9 figure the muscle is drawn on. Muscles
 * visible from both sides list both. Every entry needs a left and a right SVG
 * path per listed view, which is where §9's ~90 paths come from.
 */

export const MUSCLE_MODEL_VERSION = 1;

export const MUSCLE_REGIONS = [
  'neck',
  'shoulder',
  'chest',
  'upper-back',
  'lower-back',
  'arm',
  'forearm',
  'trunk',
  'hip',
  'quadriceps',
  'hamstrings',
  'calf',
  'foot',
];

export const MUSCLES = [
  // ── Neck ────────────────────────────────────────────────────────────────
  { slug: 'sternocleidomastoid', name: 'Sternocleidomastoid', plainName: 'front of the neck', region: 'neck', views: ['front'] },
  { slug: 'neck-extensors', name: 'Cervical extensors', plainName: 'back of the neck', region: 'neck', views: ['back'] },

  // ── Shoulder ────────────────────────────────────────────────────────────
  { slug: 'deltoid-anterior', name: 'Anterior deltoid', plainName: 'front of the shoulder', region: 'shoulder', views: ['front'] },
  { slug: 'deltoid-lateral', name: 'Lateral deltoid', plainName: 'side of the shoulder', region: 'shoulder', views: ['front', 'back'] },
  { slug: 'deltoid-posterior', name: 'Posterior deltoid', plainName: 'back of the shoulder', region: 'shoulder', views: ['back'] },
  { slug: 'supraspinatus', name: 'Supraspinatus', plainName: 'rotator cuff', region: 'shoulder', views: ['back'] },
  { slug: 'infraspinatus', name: 'Infraspinatus', plainName: 'rotator cuff', region: 'shoulder', views: ['back'] },
  { slug: 'subscapularis', name: 'Subscapularis', plainName: 'rotator cuff', region: 'shoulder', views: ['front'], drawable: false, renderVia: 'deltoid-anterior' },
  { slug: 'teres-minor', name: 'Teres minor', plainName: 'rotator cuff', region: 'shoulder', views: ['back'] },
  { slug: 'teres-major', name: 'Teres major', plainName: 'under the armpit', region: 'upper-back', views: ['back'] },

  // ── Chest ───────────────────────────────────────────────────────────────
  { slug: 'pectoralis-major', name: 'Pectoralis major', plainName: 'chest', region: 'chest', views: ['front'] },
  { slug: 'pectoralis-minor', name: 'Pectoralis minor', plainName: 'under the chest', region: 'chest', views: ['front'], drawable: false, renderVia: 'pectoralis-major' },
  { slug: 'serratus-anterior', name: 'Serratus anterior', plainName: 'ribs at the side', region: 'chest', views: ['front'] },

  // ── Upper back ──────────────────────────────────────────────────────────
  { slug: 'trapezius-upper', name: 'Upper trapezius', plainName: 'top of the shoulders', region: 'upper-back', views: ['front', 'back'] },
  { slug: 'trapezius-middle', name: 'Middle trapezius', plainName: 'between the shoulder blades', region: 'upper-back', views: ['back'] },
  { slug: 'trapezius-lower', name: 'Lower trapezius', plainName: 'below the shoulder blades', region: 'upper-back', views: ['back'] },
  { slug: 'rhomboids', name: 'Rhomboids', plainName: 'between the shoulder blades', region: 'upper-back', views: ['back'] },
  { slug: 'latissimus-dorsi', name: 'Latissimus dorsi', plainName: 'sides of the back', region: 'upper-back', views: ['back'] },
  { slug: 'levator-scapulae', name: 'Levator scapulae', plainName: 'neck into the shoulder blade', region: 'upper-back', views: ['back'] },

  // ── Lower back ──────────────────────────────────────────────────────────
  { slug: 'erector-spinae', name: 'Erector spinae', plainName: 'lower back', region: 'lower-back', views: ['back'] },
  { slug: 'quadratus-lumborum', name: 'Quadratus lumborum', plainName: 'side of the lower back', region: 'lower-back', views: ['back'] },
  { slug: 'multifidus', name: 'Multifidus', plainName: 'deep in the lower back', region: 'lower-back', views: ['back'], drawable: false, renderVia: 'erector-spinae' },

  // ── Arm ─────────────────────────────────────────────────────────────────
  { slug: 'biceps-brachii', name: 'Biceps brachii', plainName: 'biceps', region: 'arm', views: ['front'] },
  { slug: 'brachialis', name: 'Brachialis', plainName: 'under the biceps', region: 'arm', views: ['front'] },
  { slug: 'triceps-brachii', name: 'Triceps brachii', plainName: 'triceps', region: 'arm', views: ['back'] },

  // ── Forearm ─────────────────────────────────────────────────────────────
  { slug: 'forearm-flexors', name: 'Wrist flexors', plainName: 'inside of the forearm', region: 'forearm', views: ['front'] },
  { slug: 'forearm-extensors', name: 'Wrist extensors', plainName: 'outside of the forearm', region: 'forearm', views: ['back'] },
  { slug: 'brachioradialis', name: 'Brachioradialis', plainName: 'top of the forearm', region: 'forearm', views: ['front', 'back'] },

  // ── Trunk ───────────────────────────────────────────────────────────────
  { slug: 'rectus-abdominis', name: 'Rectus abdominis', plainName: 'abs', region: 'trunk', views: ['front'] },
  { slug: 'obliques-external', name: 'External obliques', plainName: 'sides of the waist', region: 'trunk', views: ['front', 'back'] },
  { slug: 'obliques-internal', name: 'Internal obliques', plainName: 'deep at the waist', region: 'trunk', views: ['front'], drawable: false, renderVia: 'obliques-external' },
  { slug: 'transverse-abdominis', name: 'Transverse abdominis', plainName: 'deep stomach muscle', region: 'trunk', views: ['front'], drawable: false, renderVia: 'rectus-abdominis' },

  // ── Hip ─────────────────────────────────────────────────────────────────
  { slug: 'gluteus-maximus', name: 'Gluteus maximus', plainName: 'glutes', region: 'hip', views: ['back'] },
  { slug: 'gluteus-medius', name: 'Gluteus medius', plainName: 'side of the hip', region: 'hip', views: ['back'] },
  { slug: 'gluteus-minimus', name: 'Gluteus minimus', plainName: 'deep side of the hip', region: 'hip', views: ['back'], drawable: false, renderVia: 'gluteus-medius' },
  { slug: 'tensor-fasciae-latae', name: 'Tensor fasciae latae', plainName: 'front of the hip', region: 'hip', views: ['front'] },
  { slug: 'iliopsoas', name: 'Iliopsoas', plainName: 'hip flexors', region: 'hip', views: ['front'] },
  { slug: 'adductors', name: 'Hip adductors', plainName: 'groin', region: 'hip', views: ['front', 'back'] },
  { slug: 'deep-hip-rotators', name: 'Deep hip rotators', plainName: 'deep in the hip', region: 'hip', views: ['back'], drawable: false, renderVia: 'gluteus-maximus' },

  // ── Quadriceps ──────────────────────────────────────────────────────────
  { slug: 'rectus-femoris', name: 'Rectus femoris', plainName: 'front of the thigh', region: 'quadriceps', views: ['front'] },
  { slug: 'vastus-lateralis', name: 'Vastus lateralis', plainName: 'outer thigh', region: 'quadriceps', views: ['front'] },
  { slug: 'vastus-medialis', name: 'Vastus medialis', plainName: 'inner thigh above the knee', region: 'quadriceps', views: ['front'] },
  { slug: 'sartorius', name: 'Sartorius', plainName: 'inner thigh', region: 'quadriceps', views: ['front'] },

  // ── Hamstrings ──────────────────────────────────────────────────────────
  { slug: 'biceps-femoris', name: 'Biceps femoris', plainName: 'outer hamstring', region: 'hamstrings', views: ['back'] },
  { slug: 'semitendinosus', name: 'Semitendinosus', plainName: 'inner hamstring', region: 'hamstrings', views: ['back'] },
  { slug: 'semimembranosus', name: 'Semimembranosus', plainName: 'inner hamstring', region: 'hamstrings', views: ['back'] },

  // ── Calf ────────────────────────────────────────────────────────────────
  { slug: 'gastrocnemius', name: 'Gastrocnemius', plainName: 'calf', region: 'calf', views: ['front', 'back'] },
  { slug: 'soleus', name: 'Soleus', plainName: 'lower calf', region: 'calf', views: ['front', 'back'] },
  { slug: 'tibialis-anterior', name: 'Tibialis anterior', plainName: 'shin', region: 'calf', views: ['front'] },
  { slug: 'peroneals', name: 'Peroneals', plainName: 'outside of the shin', region: 'calf', views: ['front', 'back'] },

  // ── Foot ────────────────────────────────────────────────────────────────
  { slug: 'foot-intrinsics', name: 'Intrinsic foot muscles', plainName: 'arch of the foot', region: 'foot', views: ['front'] },
];

export const MUSCLE_SLUGS = MUSCLES.map((m) => m.slug);

const BY_SLUG = new Map(MUSCLES.map((m) => [m.slug, m]));

export function muscle(slug) {
  const found = BY_SLUG.get(slug);
  if (!found) throw new Error(`unknown muscle ${JSON.stringify(slug)}`);
  return found;
}

export function isMuscle(slug) {
  return BY_SLUG.has(slug);
}

export function musclesInRegion(region) {
  return MUSCLES.filter((m) => m.region === region);
}

/**
 * §9 renders each muscle by role: primary solid, secondary at ~45% opacity,
 * stabiliser at ~18%. The thresholds live here so the Swift codegen and the
 * tests agree with the renderer.
 */
export const MUSCLE_ROLE_THRESHOLDS = {
  primary: 1.0,
  secondary: 0.5,
  stabiliser: 0.25,
};

/**
 * Every distinct (muscle, view, side) pair the §9 muscle map must provide.
 *
 * Deep muscles are excluded: a 2D figure has no silhouette to give
 * subscapularis or transverse abdominis that is distinguishable from the muscle
 * lying over it. They stay in the model because they still drive item selection
 * and §10's recovery spacing, and they highlight through `renderVia`.
 */
export function muscleMapPathKeys() {
  const keys = [];
  for (const m of MUSCLES) {
    if (m.drawable === false) continue;
    for (const view of m.views) {
      for (const side of ['left', 'right']) {
        keys.push(`${m.slug}.${view}.${side}`);
      }
    }
  }
  return keys;
}

export const DRAWABLE_MUSCLES = MUSCLES.filter((m) => m.drawable !== false);

/** The muscle whose path carries this muscle's highlight. */
export function renderTarget(slug) {
  const m = muscle(slug);
  return m.drawable === false ? m.renderVia : m.slug;
}
