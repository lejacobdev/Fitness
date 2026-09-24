/**
 * Drills whose text has another person in them — a feeder, a setter, a
 * passer, a defender, a partner holding a pad or your ankles, a teammate
 * doing it beside you — shown with that person. Each is an authored drill
 * plus its partner, timed so a fed ball leaves the partner's hand or racket
 * exactly when the drill needs it (`sync`: [my keyframe, their keyframe]).
 */
import { STRENGTH } from './strength.js';
import { TEAM_SPORTS } from './teamSports.js';
import { INDIVIDUAL_SPORTS } from './individualSports.js';
import { MISC_SPORTS } from './miscSports.js';
import { HOCKEY } from './hockey.js';
import { SOCCER } from './soccer.js';
import { BASKETBALL } from './basketball.js';
import { VOLLEYBALL } from './volleyball.js';
import { RACKET } from './racket.js';
import { FIELD_SPORTS } from './fieldSports.js';
import { STICK_SPORTS } from './stickSports.js';
import { RUNNING } from './running.js';
import { ENDURANCE } from './endurance.js';
import { WATER_SPORTS } from './water.js';
import { COMBAT } from './combat.js';
import { ARTISTIC } from './artistic.js';
import { PRECISION } from './precision.js';
import { OUTDOOR } from './outdoor.js';
import { KEEPERS } from './keepers.js';
import { EQUIPMENT } from './equipment.js';
import { P, both, kf, library } from './kit.js';

const lib = library();
const def = lib.def;
const ALL = [...STRENGTH, ...TEAM_SPORTS, ...INDIVIDUAL_SPORTS, ...MISC_SPORTS, ...HOCKEY, ...SOCCER, ...BASKETBALL, ...VOLLEYBALL, ...RACKET,
  ...FIELD_SPORTS, ...STICK_SPORTS, ...RUNNING, ...ENDURANCE, ...WATER_SPORTS, ...COMBAT, ...ARTISTIC, ...PRECISION, ...OUTDOOR, ...KEEPERS, ...EQUIPMENT];
const find = (slug) => lib.patterns.find((p) => p.slug === slug) ?? ALL.find((p) => p.slug === slug);
const base = (slug) => { const { slug: _s, name: _n, ...spec } = find(slug); return spec; };

/** Cycle position (0–1) where keyframe i's hold starts. */
function timeOf(p, i) {
  const n = p.keyframes.length, moves = p.loop ? n : n - 1;
  let at = 0, total = 0;
  for (let k = 0; k < n; k++) {
    const d = (p.keyframes[k].hold ?? 0) + (k < moves ? p.keyframes[k].move ?? 0.6 : 0);
    if (k < i) at += d;
    total += d;
  }
  return at / total;
}

/**
 * `slug`: `baseSlug` with partners added. Each member: { pattern, at: [forward,
 * left], facing (default 180, facing the athlete), sync: [myKf, theirKf] or
 * phase, follow, tether }. `balls` / `arcs` replace the ball on given keyframes
 * (e.g. 'c0:hands' — in the first partner's hands), `extra` merges into the spec.
 */
function withPartners(slug, baseSlug, members, { balls = {}, arcs = {}, extra = {} } = {}) {
  const spec = { ...base(baseSlug), ...extra };
  const cast = [...(spec.cast ?? []), ...members.map(({ pattern, at, facing = 180, sync, phase = 0, follow, tether }) => {
    const them = find(pattern);
    const ph = sync ? (((timeOf(them, sync[1]) - timeOf(spec, sync[0])) % 1) + 1) % 1 : phase;
    return { pattern, at, facing, phase: ph, ...(follow ? { follow } : {}), ...(tether ? { tether } : {}) };
  })];
  const keyframes = spec.keyframes.map((k, i) => ({
    ...k, ...(i in balls ? { ball: balls[i] } : {}), ...(i in arcs ? { ballArc: arcs[i] } : {}),
  }));
  def(slug, `${find(baseSlug).name} (with partner)`, { ...spec, cast, keyframes });
}

// ── Partners who hold things ──────────────────────────────────────────────
const braced = P(both({ hip: 30, knee: 40, ankle: 18, hipAbd: 12, shoulder: 70, elbow: 80 }), { spine: 18, neck: -8 });
def('pad-holder', 'Partner holding a pad', {
  view: 'three-quarter', loop: true, thumb: 0, implement: { kind: 'pad', at: 'hands' },
  keyframes: [kf(braced, 'feet', { hold: 0.8, move: 0.4 }), kf(P(braced, { spine: 22, kneeL: 44, kneeR: 44 }), 'feet', { hold: 0.8, move: 0.4 })],
});
/** Kneeling behind, leaning forward, hands pinning the athlete's ankles to the floor. */
def('ankle-holder', 'Partner holding the ankles', {
  view: 'side', loop: true, thumb: 0,
  keyframes: [
    kf(P(both({ hip: 40, knee: 110, ankle: -40, shoulder: 70, elbow: 10, hipAbd: 10 }), { spine: 56, neck: -20 }), 'knees', { hold: 1, move: 0.6 }),
    kf(P(both({ hip: 42, knee: 110, ankle: -40, shoulder: 72, elbow: 12, hipAbd: 10 }), { spine: 58, neck: -20 }), 'knees', { hold: 1, move: 0.6 }),
  ],
});
/** Behind a resisted sprint: moving with the runner, arms out in front holding the band. */
def('band-resist-partner', 'Partner resisting with a band', {
  ...base('acceleration-start'),
  keyframes: base('acceleration-start').keyframes.map((k) => ({ ...k, pose: P(k.pose, both({ shoulder: 60, elbow: 30, shoulderAbd: 10 })) })),
});

// ── Racket sports: the partner or feeder hits the ball in ────────────────
withPartners('tennis-forehand-rally', 'tennis-forehand', [{ pattern: 'tennis-forehand', at: [520, -40], sync: [0, 2] }], { balls: { 0: 'c0:head', 3: { at: [480, 60, -40] } }, arcs: { 0: 30 } });
withPartners('tennis-backhand-fed', 'tennis-backhand', [{ pattern: 'tennis-forehand', at: [520, 40], sync: [0, 2] }], { balls: { 0: 'c0:head', 3: { at: [480, 60, 40] } }, arcs: { 0: 30 } });
withPartners('tennis-overhead-fed', 'tennis-overhead', [{ pattern: 'tennis-forehand', at: [520, 0], sync: [0, 2] }], { balls: { 0: 'c0:head' }, arcs: { 0: 170 } });
withPartners('tennis-serve-returned', 'tennis-serve', [{ pattern: 'tennis-forehand', at: [580, 0], sync: [4, 2] }], { balls: { 4: 'c0:head' } });
withPartners('low-forehand-fed', 'low-forehand', [{ pattern: 'low-forehand', at: [-60, 110], facing: 0, sync: [0, 2] }], { balls: { 0: 'c0:head' } });
withPartners('tt-forehand-loop-fed', 'tt-forehand-loop', [{ pattern: 'tt-forehand-loop', at: [300, 0], sync: [0, 2] }], { balls: { 0: 'c0:head', 3: { at: [260, 60, 0] } } });
withPartners('tt-backhand-flick-fed', 'tt-backhand-flick', [{ pattern: 'tt-serve', at: [300, 0], phase: 0.5 }]);
withPartners('pickleball-dink-rally', 'pickleball-dink', [{ pattern: 'pickleball-dink', at: [280, -20], sync: [0, 1] }], { balls: { 0: 'c0:head', 2: { at: [250, 30, -18] } }, arcs: { 0: 30 } });
withPartners('volley-rally', 'volley', [{ pattern: 'volley', at: [260, 0], sync: [0, 1] }], { balls: { 0: 'c0:head' } });

// ── Volleyball and roundnet ───────────────────────────────────────────────
withPartners('vb-spike-set', 'vb-spike', [{ pattern: 'vb-set', at: [120, 230], facing: 250, sync: [0, 1] }],
  { balls: { 0: 'c0:hands', 1: { at: [100, 190, -10] }, 2: { at: [90, 228, -10] }, 3: { at: [62, 212, -12] } } });
withPartners('vb-forearm-pass-served', 'vb-forearm-pass', [{ pattern: 'throw-partner', at: [420, 0], sync: [0, 1] }], { balls: { 0: 'c0:hands' }, arcs: { 0: 60 } });
withPartners('vb-shuffle-dig-fed', 'vb-shuffle-dig', [{ pattern: 'throw-partner', at: [420, 0], sync: [0, 1] }], { balls: { 0: 'c0:hands' }, arcs: { 0: 30 }, extra: { view: 'three-quarter' } });
withPartners('vb-shuffle-dig-pair', 'vb-shuffle-dig', [{ pattern: 'throw-partner', at: [420, 0], sync: [0, 1] }, { pattern: 'vb-shuffle-dig', at: [0, -130], facing: 0, phase: 0.5 }], { balls: { 0: 'c0:hands' }, arcs: { 0: 30 }, extra: { view: 'three-quarter' } });
withPartners('vb-dive-fed', 'vb-dive', [{ pattern: 'throw-partner', at: [380, 0], sync: [0, 1] }], { balls: { 0: 'c0:hands' }, arcs: { 0: 50 } });
withPartners('vb-block-read', 'vb-block', [{ pattern: 'vb-spike', at: [230, 0], sync: [2, 5] }]);
withPartners('sit-vb-spike-set', 'sit-vb-spike', [{ pattern: 'throw-partner', at: [150, 60], facing: 200, phase: 0.2 }]);
withPartners('sit-vb-dig-fed', 'sit-vb-dig', [{ pattern: 'throw-partner', at: [400, 0], sync: [0, 1] }], { balls: { 0: 'c0:hands' }, arcs: { 0: 40 } });
withPartners('sit-vb-rotation-partner', 'sit-vb-rotation-throw', [{ pattern: 'chest-pass-partner', at: [0, -300], facing: 90 }]);
withPartners('roundnet-set-fed', 'roundnet-set', [{ pattern: 'roundnet-hit', at: [240, 0], sync: [0, 2] }], { balls: { 0: 'c0:R' } });
withPartners('roundnet-hit-set', 'roundnet-hit', [{ pattern: 'roundnet-set', at: [210, 60], facing: 200, sync: [0, 2] }]);
withPartners('roundnet-serve-received', 'roundnet-serve', [{ pattern: 'roundnet-set', at: [300, 0], phase: 0.3 }]);
withPartners('roundnet-dive-fed', 'roundnet-dive', [{ pattern: 'throw-partner', at: [260, -60], sync: [0, 1] }], { balls: { 0: 'c0:hands' }, extra: { view: 'three-quarter' } });

// ── Soccer ────────────────────────────────────────────────────────────────
withPartners('soccer-instep-kick-fed', 'soccer-instep-kick', [{ pattern: 'ball-roll-feed', at: [210, 260], facing: 240 }]);
withPartners('soccer-static-strike-partner', 'soccer-static-strike', [{ pattern: 'stand-watch', at: [520, 0] }]);
withPartners('soccer-side-foot-pass-keeper', 'soccer-side-foot-pass', [{ pattern: 'gk-set-shuffle', at: [480, 0] }]);
withPartners('soccer-header-tossed', 'soccer-header', [{ pattern: 'throw-partner', at: [360, 0], sync: [0, 1] }], { balls: { 0: 'c0:hands' }, arcs: { 0: 80 } });
withPartners('soccer-dribble-1v1', 'soccer-dribble', [{ pattern: 'bb-defensive-slide', at: [120, 20], follow: true }]);
withPartners('soccer-first-touch-wall', 'soccer-first-touch', [], { extra: { fixture: { kind: 'wall', at: 150 } } });

// ── Bat and ball, throwing ────────────────────────────────────────────────
withPartners('field-grounder-fed', 'field-grounder', [{ pattern: 'ball-roll-feed', at: [420, 0], sync: [0, 1] }], { balls: { 0: 'c0:R' } });
withPartners('baseball-swing-front-toss', 'baseball-swing', [{ pattern: 'throw-partner', at: [0, 330], facing: 270, sync: [0, 1] }], { balls: { 0: 'c0:hands' }, arcs: { 0: 20 } });
withPartners('baseball-swing-pitched', 'baseball-swing', [{ pattern: 'baseball-pitch', at: [0, 600], facing: 270, sync: [0, 3] }], { balls: { 0: 'c0:R' } });
withPartners('baseball-swing-coached', 'baseball-swing', [{ pattern: 'stand-watch', at: [60, -90], facing: 120 }]);
withPartners('long-toss-partner', 'long-toss', [{ pattern: 'throw-partner', at: [440, 0] }]);
withPartners('crow-hop-throw-partner', 'crow-hop-throw', [{ pattern: 'throw-partner', at: [460, 0] }]);
withPartners('softball-windmill-catcher', 'softball-windmill', [{ pattern: 'squat-hold', at: [420, 0] }]);
withPartners('point-and-track-rolled', 'point-and-track', [{ pattern: 'ball-roll-feed', at: [300, 0], sync: [0, 1] }],
  { balls: { 0: 'c0:R', 1: { floor: 'R', dx: 160, dl: 80 }, 2: { floor: 'R', dx: 80, dl: 160 }, 3: 'none' }, extra: { ball: { r: 5, color: 'white' } } });
withPartners('side-dive-coached', 'side-dive', [{ pattern: 'stand-watch', at: [60, 130] }]);
withPartners('side-fall-partner', 'side-fall', [{ pattern: 'stand-watch', at: [60, 110] }]);

// ── Football, rugby ───────────────────────────────────────────────────────
withPartners('football-tackle-shield', 'football-tackle', [{ pattern: 'pad-holder', at: [150, 0] }]);
withPartners('hand-strike-shield', 'hand-strike', [{ pattern: 'pad-holder', at: [66, 0] }]);
withPartners('ruck-drive', 'sled-push', [{ pattern: 'pad-holder', at: [62, 0] }],
  { extra: { fixture: undefined, ball: { r: 5.2, color: 'white' } }, balls: { 0: { floor: 'L', dx: 30 }, 1: { floor: 'L', dx: 30 }, 2: { floor: 'L', dx: 30 }, 3: { floor: 'L', dx: 30 } } });
withPartners('catch-high-thrown', 'catch-high', [{ pattern: 'throw-partner', at: [420, 60], facing: 190, sync: [0, 1] }], { balls: { 0: 'c0:hands' }, arcs: { 0: 40 } });
withPartners('catch-high-traffic', 'catch-high', [{ pattern: 'throw-partner', at: [420, 60], facing: 190, sync: [0, 1] }, { pattern: 'pad-holder', at: [30, -48], facing: 90 }],
  { balls: { 0: 'c0:hands' }, arcs: { 0: 40 } });
withPartners('qb-drop-throw-receiver', 'qb-drop-throw', [{ pattern: 'catch-high', at: [620, 0] }]);
withPartners('ball-carry-gauntlet', 'ball-carry-run', [
  { pattern: 'hand-strike', at: [140, 46], facing: 270 }, { pattern: 'hand-strike', at: [140, -46], facing: 90 },
  { pattern: 'hand-strike', at: [260, 46], facing: 270 }, { pattern: 'hand-strike', at: [260, -46], facing: 90 },
]);
withPartners('rugby-pass-receiver', 'rugby-pass', [{ pattern: 'throw-partner', at: [40, 320], facing: 270 }]);

// ── Court sports ──────────────────────────────────────────────────────────
withPartners('bb-layup-fed', 'bb-layup', [{ pattern: 'chest-pass-partner', at: [0, -210], facing: 90 }]);
withPartners('bb-dribble-relay', 'bb-dribble-run', [{ pattern: 'stand-watch', at: [-60, 40], facing: 0 }]);
withPartners('bb-dribble-2v2', 'bb-dribble-run', [{ pattern: 'bb-defensive-slide', at: [110, 20], follow: true }, { pattern: 'jog', at: [0, 90], facing: 0, follow: true, phase: 0.5 }]);
withPartners('bb-defensive-slide-attacker', 'bb-defensive-slide', [{ pattern: 'handball-feint', at: [90, 0], follow: true }], { extra: { view: 'three-quarter', ball: { r: 7, color: 'blue' } }, balls: { 0: 'c0:R', 1: 'c0:R' } });
withPartners('bb-defensive-slide-dribbler', 'bb-defensive-slide', [{ pattern: 'bb-dribble-run', at: [90, 0], follow: true }], { extra: { view: 'three-quarter', ball: { r: 9, color: 'orange' } }, balls: { 0: 'c0:Rdown', 1: 'c0:Rdown' } });
withPartners('bb-set-shot-rebounder', 'bb-set-shot', [{ pattern: 'chest-pass-partner', at: [300, 80], facing: 195 }]);
withPartners('bb-rebound-thrown', 'bb-rebound', [{ pattern: 'throw-partner', at: [210, 110], facing: 210 }]);
withPartners('bb-first-step-defender', 'bb-first-step', [{ pattern: 'bb-defensive-slide', at: [100, 44], phase: 0.5 }]);
withPartners('bb-chest-pass-partner', 'bb-chest-pass', [{ pattern: 'chest-pass-partner', at: [320, 0] }]);
withPartners('netball-drive-catch-fed', 'netball-drive-catch', [{ pattern: 'chest-pass-partner', at: [440, 30], sync: [0, 1] }], { balls: { 0: 'c0:hands' } });
withPartners('netball-defend-thrower', 'netball-defend', [{ pattern: 'overarm-pass', at: [95, 0] }],
  { extra: { ball: { r: 8.6, color: 'yellow' } }, balls: { 0: 'c0:R', 1: 'c0:R', 2: 'c0:R' } });
withPartners('cut-45-feeder', 'cut-45', [{ pattern: 'chest-pass-partner', at: [300, 120], facing: 210 }], { extra: { ball: { r: 8.6, color: 'yellow' } }, balls: { 0: 'c0:hands', 1: 'c0:hands', 2: 'c0:hands' } });
withPartners('overarm-pass-receiver', 'overarm-pass', [{ pattern: 'throw-partner', at: [420, 0] }]);
withPartners('handball-jump-shot-keeper', 'handball-jump-shot', [{ pattern: 'gk-set-shuffle', at: [520, 0] }]);
withPartners('handball-feint-defender', 'handball-feint', [{ pattern: 'bb-defensive-slide', at: [100, 20] }]);

// ── Stick sports ──────────────────────────────────────────────────────────
withPartners('hockey-snap-shot-fed', 'hockey-snap-shot', [{ pattern: 'hockey-pass-partner', at: [60, -300], facing: 90 }]);
withPartners('hockey-slap-shot-fed', 'hockey-slap-shot', [{ pattern: 'hockey-pass-partner', at: [60, -300], facing: 90 }]);
withPartners('hockey-wrist-shot-partner', 'hockey-wrist-shot', [{ pattern: 'stand-watch', at: [0, 380], facing: 270 }]);
withPartners('hockey-walk-to-position-called', 'hockey-walk-to-position', [{ pattern: 'signal-partner', at: [300, 0] }]);
withPartners('hockey-board-battle-pair', 'hockey-board-battle', [{ pattern: 'hockey-board-battle', at: [0, -40], facing: 0, phase: 0.5 }],
  { extra: { ball: { r: 3.4, shape: 'puck', color: 'black' } }, balls: { 0: { floor: 'L', dx: 40, dl: -20 }, 1: { floor: 'L', dx: 40, dl: -20 } } });
withPartners('goalie-t-push-shooter', 'goalie-t-push', [{ pattern: 'hockey-stickhandling-walk', at: [420, 0] }], { extra: { view: 'three-quarter' } });
withPartners('fh-gk-block-get-up-shooter', 'fh-gk-block-get-up', [{ pattern: 'fh-hit', at: [420, 0] }], { extra: { view: 'three-quarter' } });
withPartners('fh-gk-angle-walk-shooter', 'fh-gk-angle-walk', [{ pattern: 'fh-dribble-walk', at: [420, 0] }]);
withPartners('lax-ground-ball-fed', 'lax-ground-ball', [{ pattern: 'ball-roll-feed', at: [140, -150], facing: 135, sync: [0, 1] }], { balls: { 0: 'c0:R' } });
withPartners('goalball-sound-tracking-partner', 'goalball-sound-tracking', [{ pattern: 'goalball-throw-partner', at: [360, 0] }]);
withPartners('goalball-slide-partner', 'goalball-slide', [{ pattern: 'goalball-throw-partner', at: [420, 0] }]);
withPartners('rotational-throw-wall-coached', 'rotational-throw-wall', [{ pattern: 'stand-watch', at: [-140, 120], facing: 20 }]);

// ── Running, jumping, conditioning ────────────────────────────────────────
withPartners('lateral-shuffle-mirror', 'lateral-shuffle', [{ pattern: 'lateral-shuffle', at: [200, 0], follow: true }], { extra: { view: 'three-quarter' } });
withPartners('sprint-pursuit', 'sprint', [{ pattern: 'ball-carry-run', at: [80, -150], facing: 0, follow: true }]);
withPartners('sprint-from-keeper', 'sprint', [{ pattern: 'overarm-pass', at: [-80, 60], facing: 0 }], { extra: { ball: { r: 7, color: 'blue' } }, balls: Object.fromEntries([0, 1, 2, 3, 4, 5, 6, 7].map((i) => [i, 'c0:R'])) });
withPartners('sprint-to-base', 'sprint', [{ pattern: 'stand-watch', at: [470, 80] }]);
withPartners('acceleration-start-guided', 'acceleration-start', [{ pattern: 'acceleration-start', at: [0, 48], facing: 0, tether: true }]);
withPartners('acceleration-start-band', 'acceleration-start', [{ pattern: 'band-resist-partner', at: [-95, 0], facing: 0 }],
  { extra: { implement: { kind: 'band', at: 'hips', to: [-66, 92, 0] } } });
withPartners('burpee-called', 'burpee', [{ pattern: 'signal-partner', at: [220, 0] }]);
withPartners('single-leg-hop-stick-spotted', 'single-leg-hop-stick', [{ pattern: 'stand-watch', at: [30, 80] }]);
withPartners('toe-touch-jump-pair', 'toe-touch-jump', [{ pattern: 'toe-touch-jump', at: [0, 110], facing: 0 }]);
withPartners('herkie-drill-pair', 'herkie-drill', [{ pattern: 'herkie-drill', at: [0, 110], facing: 0 }]);
withPartners('cheer-motions-pair', 'cheer-motions', [{ pattern: 'cheer-motions', at: [0, 110], facing: 0 }]);
withPartners('swim-rhythmic-breathing-supported', 'swim-rhythmic-breathing', [{ pattern: 'water-support-partner', at: [30, 44] }]);
withPartners('star-excursion-foam-spotted', 'star-excursion-foam', [{ pattern: 'stand-watch', at: [30, 90] }]);

// ── Held, spotted, coached ────────────────────────────────────────────────
withPartners('nordic-curl-partner', 'nordic-curl', [{ pattern: 'ankle-holder', at: [-72, 0], facing: 0 }]);
withPartners('nordic-curl-partner-band', 'nordic-curl', [{ pattern: 'ankle-holder', at: [-72, 0], facing: 0 }], { extra: { implement: { kind: 'band', at: 'rack', to: [70, 10, 0] } } });
withPartners('lax-defend-carrier', 'lax-defend-shuffle', [{ pattern: 'lax-cradle-carrier', at: [120, 0], follow: true }]);
withPartners('sail-hiking-partner', 'sail-hiking', [{ pattern: 'ankle-holder', at: [70, 0] }]);
withPartners('sail-tack-crew', 'sail-tack', [{ pattern: 'stand-watch', at: [-60, 90], facing: 0 }]);
withPartners('seated-band-row-partner', 'seated-band-row', [{ pattern: 'chest-pass-partner', at: [118, 0] }]);
withPartners('rifle-wall-dot-partner', 'rifle-wall-dot', [{ pattern: 'stand-watch', at: [-50, -90], facing: 30 }]);
withPartners('ride-no-stirrups-coached', 'ride-no-stirrups', [{ pattern: 'stand-watch', at: [-210, 150], facing: 330 }]);
withPartners('bowling-approach-watched', 'bowling-approach', [{ pattern: 'stand-watch', at: [-160, 70], facing: 0 }]);
withPartners('bowling-follow-through-watched', 'bowling-follow-through', [{ pattern: 'stand-watch', at: [-160, 70], facing: 0 }]);
withPartners('archery-shot-coached', 'archery-shot', [{ pattern: 'stand-watch', at: [-130, -110], facing: 30 }]);
withPartners('wrestling-pen-step-opponent', 'wrestling-pen-step', [{ pattern: 'athletic-stance-hold', at: [95, 0] }]);
withPartners('disc-backhand-receiver', 'disc-backhand-standstill', [{ pattern: 'throw-partner', at: [0, -440], facing: 90 }]);
withPartners('ultimate-flick-receiver', 'ultimate-forehand-flick', [{ pattern: 'throw-partner', at: [500, 0] }]);
withPartners('ultimate-layout-thrower', 'ultimate-layout', [{ pattern: 'throw-partner', at: [320, 0] }]);
withPartners('ultimate-layout-knees-thrower', 'ultimate-layout-knees', [{ pattern: 'throw-partner', at: [320, 0] }]);
withPartners('split-step-signal', 'split-step', [{ pattern: 'signal-partner', at: [320, 0] }], { extra: { view: 'three-quarter' } });
withPartners('split-step-return', 'split-step', [{ pattern: 'tennis-serve', at: [600, 0] }], { extra: { implement: { kind: 'racket', at: 'R' }, view: 'three-quarter' } });
withPartners('split-step-pickleball', 'split-step', [{ pattern: 'pickleball-dink', at: [300, 0] }], { extra: { implement: { kind: 'paddle', at: 'R' }, view: 'three-quarter' } });

// ── Badminton, squash, racquetball: the shuttle or ball they are hitting ──
const SHUTTLE = { r: 1.6, color: 'white', shape: 'shuttle' };
withPartners('badminton-clear-rally', 'badminton-clear', [{ pattern: 'badminton-clear', at: [520, 0], sync: [0, 2] }],
  { extra: { ball: SHUTTLE }, balls: { 0: 'c0:head', 1: { at: [40, 250, -10] }, 2: 'head', 3: { at: [480, 140, 0] } }, arcs: { 0: 150, 2: 110 } });
withPartners('badminton-smash-fed', 'badminton-smash', [{ pattern: 'badminton-clear', at: [480, 0], sync: [0, 2] }],
  { extra: { ball: SHUTTLE }, balls: { 0: 'c0:head', 1: { at: [40, 250, -10] }, 2: 'head', 3: { at: [300, -60, 0] }, 4: 'none' }, arcs: { 0: 150 } });
withPartners('racket-net-lunge-fed', 'racket-net-lunge', [{ pattern: 'racket-net-lunge', at: [260, 0], sync: [0, 1] }],
  { extra: { ball: SHUTTLE }, balls: { 0: 'c0:head', 1: 'head', 2: { at: [250, 60, 0] } }, arcs: { 0: 30, 1: 30 } });
withPartners('racket-net-lunge-called', 'racket-net-lunge', [{ pattern: 'signal-partner', at: [240, 60], facing: 200 }]);
withPartners('squash-lunge-drop-fed', 'squash-lunge-drop', [{ pattern: 'low-forehand', at: [-80, 110], facing: 0, sync: [0, 2] }],
  { extra: { ball: { r: 2.2, color: 'black' } }, balls: { 0: 'c0:head', 1: 'head', 2: { at: [220, 10, 0] } }, arcs: { 1: 16 } });
withPartners('squash-lunge-drop-called', 'squash-lunge-drop', [{ pattern: 'signal-partner', at: [-60, 120], facing: 20 }]);
/** Racquetball ceiling ball: solo, the ball dropping from the back court into an overhead swing and sent up to the ceiling. */
def('racquetball-ceiling-ball', 'Racquetball ceiling ball', {
  ...base('badminton-clear'), ball: { r: 2.8, color: 'blue' },
  keyframes: base('badminton-clear').keyframes.map((k, i) => ({ ...k, ball: [{ at: [80, 320, -10] }, { at: [44, 230, -10] }, 'head', { at: [260, 420, 0] }][i] })),
});

export const PARTNERS = lib.patterns;
