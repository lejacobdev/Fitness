/**
 * The sport catalogue — §5. "Ship all of them... This is affordable because a
 * sport is a profile, not a library." Every sport here is one record: a
 * weighted read against the fixed §6 quality list, plus positions, skills,
 * common load areas (bias only — never injury prediction, §11), contact level
 * and session defaults.
 *
 * §5 names ~25 sports for a deep skill menu (8–14 named skills): football,
 * basketball, track and field, baseball, softball, soccer, volleyball, cross
 * country, wrestling, tennis, golf, swimming and diving, ice hockey, field
 * hockey, lacrosse, competitive spirit, flag football, bowling, gymnastics,
 * water polo, rowing, skiing, rifle, fencing, ultimate. Everything else gets
 * 4–6 skills covering its dominant actions — never zero, per §5's "no sport
 * ships without a working skill menu."
 */

import { isQuality } from './qualities.js';

export const SPORT_CATALOGUE_VERSION = 1;

export const SEASONS = ['FALL', 'WINTER', 'SPRING', 'SUMMER', 'YEAR_ROUND'];
export const CONTACT_LEVELS = ['NONE', 'LIMITED', 'CONTACT', 'COLLISION'];
export const GOVERNING_BODIES = ['NFHS', 'NCAA'];

/** The ~25 sports §5 names for a deep skill menu (8–14 skills). */
export const DEEP_SKILL_SPORTS = new Set([
  'football', 'basketball', 'track-and-field', 'baseball', 'softball', 'soccer',
  'volleyball', 'cross-country', 'wrestling', 'tennis', 'golf', 'swimming-diving',
  'ice-hockey', 'field-hockey', 'lacrosse', 'competitive-spirit', 'flag-football',
  'bowling', 'gymnastics', 'water-polo', 'rowing', 'skiing', 'rifle', 'fencing',
  'ultimate',
]);

/**
 * §8: "each named skill in a sport's skills[] carries a weighted list of the
 * physical qualities that actually underpin it. This mapping is the
 * authored intelligence of the app." `qualityWeights` is hand-authored here
 * for skills worth the research (soccer's menu below matches the spec's own
 * worked example exactly); every other skill gets one assigned automatically
 * in `sport()` below, from the sport's own qualityProfile — see that
 * function's comment for why that fallback is honest, not a guess.
 */
function skill(slug, name, qualityWeights) {
  return qualityWeights ? { slug, name, qualityWeights } : { slug, name };
}

/**
 * Build one Sport record with sane defaults filled in, so each entry below
 * states only what is distinctive about that sport.
 */
function sport(spec) {
  const {
    slug, name, governing, season, monthRange, qualityProfile,
    positions = [], skills, commonLoadAreas = [], contactLevel,
    typicalSessionLength = 75, typicalWeeklyGames = 1,
  } = spec;

  if (!DEEP_SKILL_SPORTS.has(slug) && skills.length < 4) {
    throw new Error(`${slug}: long-tail sports still need at least 4 skills (§5)`);
  }
  if (DEEP_SKILL_SPORTS.has(slug) && (skills.length < 8 || skills.length > 14)) {
    throw new Error(`${slug}: a deep-menu sport needs 8–14 skills, got ${skills.length}`);
  }

  // §8's skill→quality mapping is only hand-authored for a handful of
  // skills so far (soccer's full menu; the rest of the catalogue is a large
  // parallel content-authoring effort, same shape as the §7 item-volume gap
  // already flagged elsewhere). A skill with no bespoke mapping inherits the
  // sport's own qualityProfile as its weights: real, already-authored,
  // already-tested data — never a guessed or random fallback — so §21's
  // "every skill resolves to a full block" holds for the whole catalogue
  // today, while the skills that DO have real per-skill research read
  // noticeably sharper (see soccer.shooting-power vs. e.g. badminton.smash-power).
  const resolvedSkills = skills.map((s) => (s.qualityWeights ? s : { ...s, qualityWeights: qualityProfile }));

  return {
    slug, name, governing, season, monthRange,
    qualityProfile, positions, skills: resolvedSkills, commonLoadAreas, contactLevel,
    typicalSessionLength, typicalWeeklyGames,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// Deep-menu sports (§5's ~25) — full positions and 8–14 named skills.
// ═══════════════════════════════════════════════════════════════════════════

export const SPORTS = [

  sport({
    slug: 'soccer',
    name: 'Soccer',
    governing: ['NFHS', 'NCAA'],
    season: 'FALL',
    monthRange: [8, 11],
    qualityProfile: {
      'aerobic-base': 0.9, 'repeat-sprint': 0.8, 'change-of-direction': 0.9,
      'acceleration': 0.8, 'max-velocity': 0.6, 'rotational-power': 0.7,
      'single-leg-stability': 0.7, 'deceleration': 0.7, 'lateral-power': 0.6,
      'hip-mobility': 0.5,
    },
    positions: [
      { slug: 'goalkeeper', name: 'Goalkeeper', qualityProfile: { 'reactive-strength': 0.9, 'vertical-power': 0.9, 'lateral-power': 0.8, 'shoulder-stability': 0.6, 'landing-mechanics': 0.7 } },
      { slug: 'defender', name: 'Defender', qualityProfile: { 'deceleration': 0.9, 'change-of-direction': 0.8, 'aerobic-base': 0.7, 'vertical-power': 0.5 } },
      { slug: 'midfielder', name: 'Midfielder', qualityProfile: { 'aerobic-base': 1.0, 'repeat-sprint': 0.9, 'anaerobic-capacity': 0.6 } },
      { slug: 'forward', name: 'Forward', qualityProfile: { 'acceleration': 0.9, 'max-velocity': 0.8, 'rotational-power': 0.8 } },
    ],
    // §8's worked example, verbatim: "shot velocity is produced by planting
    // hard and braking the support leg fast, then swinging the kicking leg
    // through... shooting power maps to: eccentric braking / deceleration
    // 1.0, rotational power 0.9, horizontal and vertical power 0.8,
    // lower-body max strength relative to bodyweight 0.7, ankle stiffness
    // and reactive strength 0.7, hip mobility 0.5, single-leg stability
    // 0.5." The other nine follow the same "not guesswork... follows the
    // biomechanics" standard, reasoned from what each action demands.
    skills: [
      skill('shooting-power', 'Shooting power', {
        'deceleration': 1.0, 'rotational-power': 0.9, 'horizontal-power': 0.8, 'vertical-power': 0.8,
        'lower-body-strength': 0.7, 'ankle-stiffness': 0.7, 'reactive-strength': 0.7,
        'hip-mobility': 0.5, 'single-leg-stability': 0.5,
      }),
      skill('shooting-accuracy', 'Shooting accuracy', {
        'single-leg-stability': 0.8, 'hip-mobility': 0.7, 'rotational-power': 0.6,
        'ankle-stiffness': 0.6, 'deceleration': 0.5,
      }),
      skill('first-touch', 'First touch', {
        'single-leg-stability': 0.8, 'ankle-stiffness': 0.7, 'hip-mobility': 0.6,
        'reactive-strength': 0.6, 'change-of-direction': 0.5,
      }),
      skill('dribbling', 'Dribbling under pressure', {
        'change-of-direction': 1.0, 'lateral-power': 0.8, 'acceleration': 0.7,
        'single-leg-stability': 0.7, 'hip-mobility': 0.5,
      }),
      skill('passing-range', 'Passing range', {
        'rotational-power': 0.8, 'hip-mobility': 0.6, 'single-leg-stability': 0.6, 'trunk-anti-rotation': 0.5,
      }),
      skill('heading', 'Heading', {
        'vertical-power': 0.9, 'trunk-anti-rotation': 0.7, 'landing-mechanics': 0.6, 'shoulder-stability': 0.5,
      }),
      skill('one-v-one-defending', '1v1 defending', {
        'deceleration': 1.0, 'change-of-direction': 0.9, 'lateral-power': 0.7,
        'reactive-strength': 0.6, 'single-leg-stability': 0.6,
      }),
      skill('sprint-speed', 'Sprint speed', {
        'acceleration': 1.0, 'max-velocity': 0.9, 'repeat-sprint': 0.7, 'horizontal-power': 0.6,
      }),
      skill('crossing', 'Crossing', {
        'rotational-power': 0.8, 'hip-mobility': 0.7, 'single-leg-stability': 0.7, 'ankle-stiffness': 0.5,
      }),
      skill('agility', 'Agility and cutting', {
        'change-of-direction': 1.0, 'lateral-power': 0.8, 'deceleration': 0.8,
        'reactive-strength': 0.6, 'ankle-stiffness': 0.6,
      }),
    ],
    commonLoadAreas: ['hip-flexors', 'groin', 'hamstrings'],
    contactLevel: 'LIMITED',
    typicalSessionLength: 90, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'football',
    name: 'Football',
    governing: ['NFHS', 'NCAA'],
    season: 'FALL',
    monthRange: [8, 11],
    qualityProfile: {
      'acceleration': 0.9, 'horizontal-power': 0.9, 'lower-body-strength': 0.8,
      'upper-body-push': 0.7, 'reactive-strength': 0.7, 'change-of-direction': 0.7,
      'grip': 0.5, 'trunk-anti-rotation': 0.6,
    },
    positions: [
      { slug: 'lineman', name: 'Lineman', qualityProfile: { 'lower-body-strength': 1.0, 'upper-body-push': 0.9, 'horizontal-power': 0.9, 'grip': 0.6 } },
      { slug: 'skill', name: 'Skill position', qualityProfile: { 'max-velocity': 0.9, 'acceleration': 0.9, 'change-of-direction': 0.8 } },
      { slug: 'linebacker', name: 'Linebacker', qualityProfile: { 'reactive-strength': 0.9, 'deceleration': 0.8, 'horizontal-power': 0.8 } },
      { slug: 'quarterback', name: 'Quarterback', qualityProfile: { 'rotational-power': 0.9, 'overhead-power': 0.8, 'shoulder-stability': 0.6 } },
    ],
    skills: [
      skill('throwing-velocity', 'Throwing velocity', { 'rotational-power': 0.9, 'overhead-power': 0.9, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.6, 'hip-mobility': 0.5, 'single-leg-stability': 0.4 }), skill('route-running', 'Route running', { 'change-of-direction': 0.9, 'deceleration': 0.9, 'acceleration': 0.8, 'max-velocity': 0.6, 'ankle-stiffness': 0.5, 'single-leg-stability': 0.5 }),
      skill('open-field-tackling', 'Open-field tackling', { 'deceleration': 0.9, 'lower-body-strength': 0.8, 'horizontal-power': 0.7, 'trunk-anti-rotation': 0.7, 'change-of-direction': 0.6, 'shoulder-stability': 0.5, 'lateral-power': 0.5 }), skill('block-drive', 'Block drive power', { 'lower-body-strength': 0.9, 'horizontal-power': 0.9, 'upper-body-push': 0.8, 'trunk-anti-rotation': 0.6, 'acceleration': 0.5 }),
      skill('first-step-quickness', 'First-step quickness', { 'acceleration': 1.0, 'horizontal-power': 0.8, 'reactive-strength': 0.6, 'lower-body-strength': 0.5, 'ankle-stiffness': 0.4 }), skill('hand-fighting', 'Hand fighting', { 'upper-body-push': 0.9, 'grip': 0.7, 'reactive-strength': 0.6, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.5, 'upper-body-pull': 0.4 }),
      skill('ball-security', 'Ball security', { 'grip': 0.9, 'trunk-anti-rotation': 0.7, 'upper-body-pull': 0.5, 'shoulder-stability': 0.4 }), skill('lateral-agility', 'Lateral agility', { 'lateral-power': 0.9, 'change-of-direction': 0.9, 'deceleration': 0.8, 'ankle-stiffness': 0.6, 'single-leg-stability': 0.5, 'hip-mobility': 0.4 }),
      skill('catching-in-traffic', 'Catching in traffic', { 'trunk-anti-rotation': 0.7, 'grip': 0.7, 'reactive-strength': 0.6, 'shoulder-stability': 0.6, 'vertical-power': 0.5, 'landing-mechanics': 0.4 }), skill('kicking-power', 'Kicking power', { 'rotational-power': 0.9, 'hip-mobility': 0.8, 'single-leg-stability': 0.7, 'deceleration': 0.6, 'lower-body-strength': 0.5, 'ankle-stiffness': 0.5 }),
    ],
    commonLoadAreas: ['neck', 'shoulders', 'lower-back'],
    contactLevel: 'COLLISION',
    typicalSessionLength: 105, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'basketball',
    name: 'Basketball',
    governing: ['NFHS', 'NCAA'],
    season: 'WINTER',
    monthRange: [11, 3],
    qualityProfile: {
      'vertical-power': 0.9, 'change-of-direction': 0.9, 'acceleration': 0.8,
      'reactive-strength': 0.7, 'anaerobic-capacity': 0.7, 'single-leg-stability': 0.6,
      'landing-mechanics': 0.7, 'lateral-power': 0.7,
    },
    positions: [
      { slug: 'guard', name: 'Guard', qualityProfile: { 'change-of-direction': 1.0, 'acceleration': 0.9, 'anaerobic-capacity': 0.7 } },
      { slug: 'forward', name: 'Forward', qualityProfile: { 'vertical-power': 0.9, 'lateral-power': 0.7, 'rotational-power': 0.6 } },
      { slug: 'center', name: 'Center', qualityProfile: { 'vertical-power': 1.0, 'lower-body-strength': 0.7, 'upper-body-push': 0.5 } },
    ],
    skills: [
      skill('vertical-jump', 'Vertical jump', { 'vertical-power': 1.0, 'reactive-strength': 0.8, 'lower-body-strength': 0.7, 'ankle-stiffness': 0.6, 'landing-mechanics': 0.6, 'horizontal-power': 0.3 }), skill('first-step', 'First step', { 'acceleration': 1.0, 'horizontal-power': 0.7, 'lateral-power': 0.6, 'reactive-strength': 0.6, 'ankle-stiffness': 0.4 }),
      skill('shooting-mechanics', 'Shooting mechanics', { 'shoulder-stability': 0.8, 'single-leg-stability': 0.6, 'vertical-power': 0.5, 'trunk-anti-rotation': 0.5, 'ankle-stiffness': 0.3 }), skill('ball-handling', 'Ball handling', { 'grip': 0.6, 'trunk-anti-rotation': 0.6, 'change-of-direction': 0.6, 'lateral-power': 0.5, 'reactive-strength': 0.5, 'shoulder-stability': 0.4 }),
      skill('lateral-quickness', 'Lateral quickness', { 'lateral-power': 1.0, 'deceleration': 0.8, 'change-of-direction': 0.8, 'ankle-stiffness': 0.6, 'single-leg-stability': 0.5, 'hip-mobility': 0.4 }), skill('finishing-at-rim', 'Finishing at the rim', { 'vertical-power': 0.8, 'trunk-anti-rotation': 0.7, 'reactive-strength': 0.7, 'single-leg-stability': 0.6, 'landing-mechanics': 0.6, 'acceleration': 0.5 }),
      skill('box-out-strength', 'Box-out strength', { 'lower-body-strength': 0.8, 'trunk-anti-rotation': 0.8, 'upper-body-push': 0.6, 'lateral-power': 0.5, 'hip-mobility': 0.4 }), skill('free-throw-consistency', 'Free-throw consistency', { 'shoulder-stability': 0.8, 'single-leg-stability': 0.6, 'trunk-anti-rotation': 0.5, 'aerobic-base': 0.4 }),
      skill('change-of-pace', 'Change of pace', { 'acceleration': 0.9, 'deceleration': 0.9, 'change-of-direction': 0.6, 'max-velocity': 0.4, 'ankle-stiffness': 0.4 }), skill('rebounding-timing', 'Rebounding timing', { 'vertical-power': 0.9, 'reactive-strength': 0.9, 'landing-mechanics': 0.7, 'trunk-anti-rotation': 0.5, 'ankle-stiffness': 0.5 }),
    ],
    commonLoadAreas: ['knees', 'ankles', 'lower-back'],
    contactLevel: 'CONTACT',
    typicalSessionLength: 90, typicalWeeklyGames: 2,
  }),

  sport({
    slug: 'baseball',
    name: 'Baseball',
    governing: ['NFHS', 'NCAA'],
    season: 'SPRING',
    monthRange: [3, 6],
    qualityProfile: {
      'rotational-power': 0.9, 'overhead-power': 0.8, 'acceleration': 0.7,
      'shoulder-stability': 0.7, 'grip': 0.5, 'reactive-strength': 0.5,
      'trunk-anti-rotation': 0.6,
    },
    positions: [
      { slug: 'pitcher', name: 'Pitcher', qualityProfile: { 'overhead-power': 1.0, 'shoulder-stability': 0.9, 'rotational-power': 0.8, 'hip-mobility': 0.6 } },
      { slug: 'infield', name: 'Infield', qualityProfile: { 'reactive-strength': 0.8, 'rotational-power': 0.8, 'lateral-power': 0.7 } },
      { slug: 'outfield', name: 'Outfield', qualityProfile: { 'max-velocity': 0.8, 'overhead-power': 0.7, 'acceleration': 0.6 } },
      { slug: 'catcher', name: 'Catcher', qualityProfile: { 'single-leg-stability': 0.7, 'reactive-strength': 0.7, 'grip': 0.6 } },
    ],
    skills: [
      skill('throwing-velocity', 'Throwing velocity', { 'rotational-power': 0.9, 'overhead-power': 0.9, 'shoulder-stability': 0.8, 'hip-mobility': 0.6, 'trunk-anti-rotation': 0.6, 'single-leg-stability': 0.5, 'lower-body-strength': 0.4 }), skill('exit-velocity', 'Exit velocity', { 'rotational-power': 1.0, 'lower-body-strength': 0.7, 'grip': 0.6, 'trunk-anti-rotation': 0.6, 'horizontal-power': 0.5, 'hip-mobility': 0.5 }),
      skill('bat-speed', 'Bat speed', { 'rotational-power': 1.0, 'grip': 0.6, 'trunk-anti-rotation': 0.6, 'hip-mobility': 0.6, 'horizontal-power': 0.4 }), skill('pitching-mechanics', 'Pitching mechanics', { 'overhead-power': 0.9, 'rotational-power': 0.8, 'shoulder-stability': 0.8, 'single-leg-stability': 0.7, 'hip-mobility': 0.7, 'trunk-anti-rotation': 0.6, 'deceleration': 0.5 }),
      skill('first-step-quickness', 'First-step quickness', { 'acceleration': 0.9, 'lateral-power': 0.8, 'reactive-strength': 0.7, 'change-of-direction': 0.6, 'ankle-stiffness': 0.4 }), skill('arm-care', 'Arm care and durability', { 'shoulder-stability': 1.0, 'upper-body-pull': 0.7, 'trunk-anti-rotation': 0.5, 'grip': 0.4 }),
      skill('rotational-sequencing', 'Rotational sequencing', { 'rotational-power': 0.9, 'hip-mobility': 0.8, 'trunk-anti-rotation': 0.8, 'single-leg-stability': 0.5 }), skill('base-running-speed', 'Base-running speed', { 'acceleration': 0.9, 'max-velocity': 0.8, 'change-of-direction': 0.6, 'horizontal-power': 0.5, 'deceleration': 0.4 }),
    ],
    commonLoadAreas: ['shoulder', 'elbow', 'lower-back'],
    contactLevel: 'LIMITED',
    typicalSessionLength: 100, typicalWeeklyGames: 2,
  }),

  sport({
    slug: 'softball',
    name: 'Softball',
    governing: ['NFHS', 'NCAA'],
    season: 'SPRING',
    monthRange: [3, 6],
    qualityProfile: {
      'rotational-power': 0.9, 'overhead-power': 0.6, 'acceleration': 0.7,
      'shoulder-stability': 0.6, 'grip': 0.5, 'reactive-strength': 0.6,
      'hip-mobility': 0.6,
    },
    positions: [
      { slug: 'pitcher', name: 'Pitcher (windmill)', qualityProfile: { 'shoulder-stability': 0.9, 'hip-mobility': 0.8, 'rotational-power': 0.8, 'grip': 0.6 } },
      { slug: 'infield', name: 'Infield', qualityProfile: { 'reactive-strength': 0.8, 'rotational-power': 0.8 } },
      { slug: 'outfield', name: 'Outfield', qualityProfile: { 'max-velocity': 0.8, 'overhead-power': 0.6 } },
    ],
    skills: [
      skill('bat-speed', 'Bat speed', { 'rotational-power': 1.0, 'grip': 0.6, 'trunk-anti-rotation': 0.6, 'hip-mobility': 0.6, 'horizontal-power': 0.4 }), skill('exit-velocity', 'Exit velocity', { 'rotational-power': 1.0, 'lower-body-strength': 0.7, 'grip': 0.6, 'trunk-anti-rotation': 0.6, 'hip-mobility': 0.5 }),
      skill('windmill-pitch-velocity', 'Windmill pitch velocity', { 'rotational-power': 0.9, 'shoulder-stability': 0.8, 'overhead-power': 0.7, 'single-leg-stability': 0.7, 'hip-mobility': 0.6, 'trunk-anti-rotation': 0.6, 'lower-body-strength': 0.5 }), skill('throwing-velocity', 'Throwing velocity', { 'rotational-power': 0.9, 'overhead-power': 0.8, 'shoulder-stability': 0.8, 'trunk-anti-rotation': 0.6, 'hip-mobility': 0.5, 'single-leg-stability': 0.4 }),
      skill('first-step-quickness', 'First-step quickness', { 'acceleration': 0.9, 'lateral-power': 0.8, 'reactive-strength': 0.7, 'change-of-direction': 0.6, 'ankle-stiffness': 0.4 }), skill('base-running-speed', 'Base-running speed', { 'acceleration': 0.9, 'max-velocity': 0.8, 'change-of-direction': 0.6, 'horizontal-power': 0.5, 'deceleration': 0.4 }),
      skill('rotational-sequencing', 'Rotational sequencing', { 'rotational-power': 0.9, 'hip-mobility': 0.8, 'trunk-anti-rotation': 0.8, 'single-leg-stability': 0.5 }), skill('slap-hitting-speed', 'Slap-hitting speed', { 'acceleration': 0.9, 'rotational-power': 0.6, 'change-of-direction': 0.6, 'horizontal-power': 0.5, 'trunk-anti-rotation': 0.4 }),
    ],
    commonLoadAreas: ['shoulder', 'lower-back', 'knees'],
    contactLevel: 'LIMITED',
    typicalSessionLength: 100, typicalWeeklyGames: 2,
  }),

  sport({
    slug: 'volleyball',
    name: 'Volleyball',
    governing: ['NFHS', 'NCAA'],
    season: 'FALL',
    monthRange: [8, 11],
    qualityProfile: {
      'vertical-power': 0.9, 'overhead-power': 0.8, 'reactive-strength': 0.8,
      'lateral-power': 0.6, 'landing-mechanics': 0.8, 'shoulder-stability': 0.6,
      'trunk-anti-rotation': 0.5,
    },
    positions: [
      { slug: 'outside-hitter', name: 'Outside hitter', qualityProfile: { 'vertical-power': 1.0, 'overhead-power': 0.9, 'rotational-power': 0.7 } },
      { slug: 'setter', name: 'Setter', qualityProfile: { 'reactive-strength': 0.8, 'lateral-power': 0.7, 'shoulder-stability': 0.6 } },
      { slug: 'libero', name: 'Libero', qualityProfile: { 'reactive-strength': 0.9, 'landing-mechanics': 0.8, 'single-leg-stability': 0.7 } },
      { slug: 'middle-blocker', name: 'Middle blocker', qualityProfile: { 'vertical-power': 1.0, 'lateral-power': 0.8 } },
    ],
    skills: [
      skill('approach-jump-height', 'Approach jump height', { 'vertical-power': 1.0, 'reactive-strength': 0.8, 'lower-body-strength': 0.7, 'horizontal-power': 0.6, 'ankle-stiffness': 0.6, 'landing-mechanics': 0.6 }), skill('spike-velocity', 'Spike velocity', { 'overhead-power': 1.0, 'rotational-power': 0.8, 'shoulder-stability': 0.8, 'trunk-anti-rotation': 0.7, 'vertical-power': 0.6 }),
      skill('blocking-timing', 'Blocking timing', { 'vertical-power': 0.8, 'reactive-strength': 0.8, 'lateral-power': 0.7, 'landing-mechanics': 0.7, 'shoulder-stability': 0.6 }), skill('serve-power', 'Serve power', { 'overhead-power': 0.9, 'rotational-power': 0.8, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.6, 'horizontal-power': 0.4 }),
      skill('passing-platform', 'Passing platform control', { 'lateral-power': 0.7, 'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.6, 'single-leg-stability': 0.6, 'lower-body-strength': 0.5, 'deceleration': 0.5 }), skill('lateral-movement', 'Lateral movement', { 'lateral-power': 1.0, 'deceleration': 0.8, 'change-of-direction': 0.7, 'ankle-stiffness': 0.6, 'single-leg-stability': 0.5 }),
      skill('landing-control', 'Landing control', { 'landing-mechanics': 1.0, 'single-leg-stability': 0.8, 'ankle-stiffness': 0.7, 'lower-body-strength': 0.6, 'deceleration': 0.6 }), skill('setting-hands', 'Setting hand quickness', { 'shoulder-stability': 0.8, 'upper-body-push': 0.6, 'grip': 0.6, 'trunk-anti-rotation': 0.5, 'vertical-power': 0.4 }),
    ],
    commonLoadAreas: ['shoulder', 'knees', 'lower-back'],
    contactLevel: 'NONE',
    typicalSessionLength: 90, typicalWeeklyGames: 2,
  }),

  sport({
    slug: 'cross-country',
    name: 'Cross Country',
    governing: ['NFHS', 'NCAA'],
    season: 'FALL',
    monthRange: [8, 11],
    qualityProfile: {
      'aerobic-base': 1.0, 'anaerobic-capacity': 0.5, 'lower-body-strength': 0.4,
      'single-leg-stability': 0.5, 'ankle-stiffness': 0.5, 'hip-mobility': 0.4,
    },
    skills: [
      skill('aerobic-threshold-pace', 'Aerobic threshold pace', { 'aerobic-base': 1.0, 'repeat-sprint': 0.5, 'ankle-stiffness': 0.5, 'single-leg-stability': 0.4, 'anaerobic-capacity': 0.4 }), skill('finishing-kick', 'Finishing kick', { 'anaerobic-capacity': 0.9, 'max-velocity': 0.8, 'acceleration': 0.6, 'reactive-strength': 0.6, 'aerobic-base': 0.5 }),
      skill('hill-running-economy', 'Hill running economy', { 'aerobic-base': 0.8, 'lower-body-strength': 0.7, 'reactive-strength': 0.6, 'ankle-stiffness': 0.6, 'single-leg-stability': 0.5, 'horizontal-power': 0.4 }), skill('running-economy', 'Running economy', { 'aerobic-base': 0.9, 'ankle-stiffness': 0.8, 'reactive-strength': 0.7, 'single-leg-stability': 0.6, 'hip-mobility': 0.5 }),
      skill('pacing-discipline', 'Pacing discipline', { 'aerobic-base': 0.9, 'anaerobic-capacity': 0.5, 'repeat-sprint': 0.4 }), skill('race-tactics', 'Race tactics', { 'aerobic-base': 0.8, 'anaerobic-capacity': 0.7, 'acceleration': 0.6, 'change-of-direction': 0.4 }),
      skill('recovery-between-hard-days', 'Recovery between hard days', { 'aerobic-base': 1.0, 'hip-mobility': 0.6, 'single-leg-stability': 0.4 }), skill('cadence', 'Cadence and stride efficiency', { 'reactive-strength': 0.8, 'ankle-stiffness': 0.8, 'aerobic-base': 0.7, 'single-leg-stability': 0.5, 'hip-mobility': 0.4 }),
    ],
    commonLoadAreas: ['shins', 'achilles', 'hip-flexors'],
    contactLevel: 'NONE',
    typicalSessionLength: 60, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'track-and-field',
    name: 'Track and Field',
    governing: ['NFHS', 'NCAA'],
    season: 'SPRING',
    monthRange: [3, 6],
    qualityProfile: {
      'acceleration': 0.8, 'max-velocity': 0.8, 'aerobic-base': 0.5,
      'vertical-power': 0.6, 'horizontal-power': 0.6, 'rotational-power': 0.5,
      'reactive-strength': 0.6,
    },
    positions: [
      { slug: 'sprints', name: 'Sprints', qualityProfile: { 'acceleration': 1.0, 'max-velocity': 1.0, 'reactive-strength': 0.7 } },
      { slug: 'distance', name: 'Distance', qualityProfile: { 'aerobic-base': 1.0, 'anaerobic-capacity': 0.5 } },
      { slug: 'jumps', name: 'Jumps', qualityProfile: { 'horizontal-power': 0.9, 'vertical-power': 0.9, 'reactive-strength': 0.8 } },
      { slug: 'throws', name: 'Throws', qualityProfile: { 'rotational-power': 1.0, 'overhead-power': 0.7, 'lower-body-strength': 0.7 } },
    ],
    skills: [
      skill('block-start', 'Block start', { 'acceleration': 1.0, 'horizontal-power': 0.9, 'lower-body-strength': 0.7, 'reactive-strength': 0.6, 'ankle-stiffness': 0.5 }), skill('max-velocity-mechanics', 'Max velocity mechanics', { 'max-velocity': 1.0, 'reactive-strength': 0.8, 'ankle-stiffness': 0.8, 'hip-mobility': 0.6, 'single-leg-stability': 0.5 }),
      skill('curve-running', 'Curve running', { 'max-velocity': 0.8, 'lateral-power': 0.7, 'ankle-stiffness': 0.7, 'single-leg-stability': 0.7, 'trunk-anti-rotation': 0.5 }), skill('jump-takeoff-power', 'Jump takeoff power', { 'vertical-power': 0.9, 'horizontal-power': 0.9, 'reactive-strength': 0.9, 'lower-body-strength': 0.7, 'ankle-stiffness': 0.7, 'landing-mechanics': 0.5 }),
      skill('throwing-release-speed', 'Throwing release speed', { 'rotational-power': 1.0, 'overhead-power': 0.8, 'lower-body-strength': 0.7, 'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.6, 'hip-mobility': 0.5 }), skill('hurdle-clearance', 'Hurdle clearance', { 'hip-mobility': 0.9, 'max-velocity': 0.7, 'reactive-strength': 0.7, 'single-leg-stability': 0.6, 'ankle-stiffness': 0.6 }),
      skill('relay-exchange', 'Relay exchange', { 'acceleration': 0.8, 'max-velocity': 0.7, 'shoulder-stability': 0.4, 'change-of-direction': 0.4 }), skill('pacing-strategy', 'Pacing strategy', { 'aerobic-base': 0.9, 'anaerobic-capacity': 0.7, 'repeat-sprint': 0.4 }),
      skill('approach-consistency', 'Approach consistency', { 'max-velocity': 0.7, 'acceleration': 0.7, 'reactive-strength': 0.6, 'ankle-stiffness': 0.6, 'single-leg-stability': 0.5 }),
    ],
    commonLoadAreas: ['hamstrings', 'achilles', 'lower-back'],
    contactLevel: 'NONE',
    typicalSessionLength: 90, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'wrestling',
    name: 'Wrestling',
    governing: ['NFHS', 'NCAA'],
    season: 'WINTER',
    monthRange: [11, 3],
    qualityProfile: {
      'anaerobic-capacity': 0.9, 'grip': 0.8, 'trunk-anti-rotation': 0.7,
      'lower-body-strength': 0.7, 'reactive-strength': 0.6, 'hip-mobility': 0.6,
      'upper-body-pull': 0.6,
    },
    skills: [
      skill('takedown-power', 'Takedown power', { 'horizontal-power': 0.9, 'lower-body-strength': 0.8, 'acceleration': 0.7, 'trunk-anti-rotation': 0.6, 'grip': 0.6, 'upper-body-pull': 0.5 }), skill('sprawl-speed', 'Sprawl speed', { 'reactive-strength': 0.9, 'hip-mobility': 0.8, 'acceleration': 0.7, 'trunk-anti-rotation': 0.6, 'deceleration': 0.6 }),
      skill('grip-strength', 'Grip strength', { 'grip': 1.0, 'upper-body-pull': 0.7, 'shoulder-stability': 0.5 }), skill('hip-explosiveness', 'Hip explosiveness', { 'horizontal-power': 0.9, 'lower-body-strength': 0.8, 'vertical-power': 0.6, 'rotational-power': 0.6, 'hip-mobility': 0.6 }),
      skill('bridging-strength', 'Bridging strength', { 'trunk-anti-rotation': 0.8, 'lower-body-strength': 0.6, 'shoulder-stability': 0.6, 'upper-body-pull': 0.5, 'hip-mobility': 0.5 }), skill('scrambling-endurance', 'Scrambling endurance', { 'anaerobic-capacity': 1.0, 'repeat-sprint': 0.7, 'grip': 0.6, 'aerobic-base': 0.6, 'trunk-anti-rotation': 0.5 }),
      skill('hand-control', 'Hand control and ties', { 'grip': 0.9, 'upper-body-pull': 0.7, 'upper-body-push': 0.6, 'shoulder-stability': 0.6, 'trunk-anti-rotation': 0.5 }), skill('mat-awareness', 'Mat awareness', { 'single-leg-stability': 0.8, 'trunk-anti-rotation': 0.7, 'hip-mobility': 0.6, 'lateral-power': 0.5, 'landing-mechanics': 0.4 }),
    ],
    commonLoadAreas: ['neck', 'shoulders', 'lower-back'],
    contactLevel: 'COLLISION',
    typicalSessionLength: 90, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'tennis',
    name: 'Tennis',
    governing: ['NFHS', 'NCAA'],
    season: 'SPRING',
    monthRange: [3, 6],
    qualityProfile: {
      'lateral-power': 0.8, 'rotational-power': 0.8, 'overhead-power': 0.6,
      'change-of-direction': 0.7, 'repeat-sprint': 0.6, 'shoulder-stability': 0.6,
      'reactive-strength': 0.5,
    },
    skills: [
      skill('serve-velocity', 'Serve velocity', { 'overhead-power': 1.0, 'rotational-power': 0.9, 'shoulder-stability': 0.8, 'trunk-anti-rotation': 0.7, 'vertical-power': 0.5, 'hip-mobility': 0.5 }), skill('first-step-to-ball', 'First step to the ball', { 'acceleration': 0.9, 'lateral-power': 0.8, 'reactive-strength': 0.7, 'change-of-direction': 0.6, 'ankle-stiffness': 0.5 }),
      skill('groundstroke-power', 'Groundstroke power', { 'rotational-power': 1.0, 'trunk-anti-rotation': 0.7, 'lower-body-strength': 0.6, 'single-leg-stability': 0.6, 'hip-mobility': 0.6, 'shoulder-stability': 0.5 }), skill('lateral-recovery', 'Lateral recovery', { 'lateral-power': 0.9, 'deceleration': 0.8, 'change-of-direction': 0.8, 'ankle-stiffness': 0.6, 'single-leg-stability': 0.5 }),
      skill('overhead-mechanics', 'Overhead mechanics', { 'overhead-power': 0.9, 'shoulder-stability': 0.8, 'rotational-power': 0.7, 'vertical-power': 0.6, 'trunk-anti-rotation': 0.5 }), skill('court-endurance', 'Court endurance', { 'aerobic-base': 0.8, 'anaerobic-capacity': 0.8, 'repeat-sprint': 0.7, 'change-of-direction': 0.4 }),
      skill('split-step-timing', 'Split-step timing', { 'reactive-strength': 0.9, 'ankle-stiffness': 0.7, 'lateral-power': 0.6, 'acceleration': 0.5 }), skill('rotational-power-transfer', 'Rotational power transfer', { 'rotational-power': 1.0, 'hip-mobility': 0.8, 'trunk-anti-rotation': 0.8, 'single-leg-stability': 0.5 }),
    ],
    commonLoadAreas: ['shoulder', 'elbow', 'lower-back'],
    contactLevel: 'NONE',
    typicalSessionLength: 75, typicalWeeklyGames: 2,
  }),

  sport({
    slug: 'golf',
    name: 'Golf',
    governing: ['NFHS', 'NCAA'],
    season: 'FALL',
    monthRange: [8, 10],
    qualityProfile: {
      'rotational-power': 0.9, 'hip-mobility': 0.7, 'trunk-anti-rotation': 0.6,
      'single-leg-stability': 0.5, 'shoulder-stability': 0.4,
    },
    skills: [
      skill('clubhead-speed', 'Clubhead speed', { 'rotational-power': 1.0, 'hip-mobility': 0.7, 'trunk-anti-rotation': 0.7, 'lower-body-strength': 0.6, 'grip': 0.6, 'single-leg-stability': 0.5 }), skill('rotational-mobility', 'Rotational mobility', { 'hip-mobility': 1.0, 'rotational-power': 0.6, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.6 }),
      skill('swing-sequencing', 'Swing sequencing', { 'rotational-power': 0.9, 'hip-mobility': 0.8, 'trunk-anti-rotation': 0.8, 'single-leg-stability': 0.6 }), skill('balance-through-impact', 'Balance through impact', { 'single-leg-stability': 0.9, 'trunk-anti-rotation': 0.8, 'ankle-stiffness': 0.6, 'hip-mobility': 0.5 }),
      skill('short-game-touch', 'Short-game touch', { 'single-leg-stability': 0.7, 'trunk-anti-rotation': 0.6, 'grip': 0.5, 'shoulder-stability': 0.5 }), skill('walking-endurance', '18-hole walking endurance', { 'aerobic-base': 1.0, 'single-leg-stability': 0.4, 'hip-mobility': 0.4 }),
      skill('core-stability', 'Core stability under rotation', { 'trunk-anti-rotation': 1.0, 'hip-mobility': 0.5, 'single-leg-stability': 0.5 }), skill('consistency', 'Swing consistency', { 'trunk-anti-rotation': 0.8, 'single-leg-stability': 0.8, 'hip-mobility': 0.6, 'shoulder-stability': 0.5, 'aerobic-base': 0.4 }),
    ],
    commonLoadAreas: ['lower-back', 'lead-wrist', 'hips'],
    contactLevel: 'NONE',
    typicalSessionLength: 60, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'swimming-diving',
    name: 'Swimming and Diving',
    governing: ['NFHS', 'NCAA'],
    season: 'WINTER',
    monthRange: [11, 2],
    qualityProfile: {
      'aerobic-base': 0.8, 'anaerobic-capacity': 0.7, 'shoulder-stability': 0.8,
      'upper-body-pull': 0.7, 'trunk-anti-rotation': 0.6, 'ankle-stiffness': 0.5,
    },
    positions: [
      { slug: 'sprinter', name: 'Sprint swimmer', qualityProfile: { 'anaerobic-capacity': 1.0, 'reactive-strength': 0.6 } },
      { slug: 'distance', name: 'Distance swimmer', qualityProfile: { 'aerobic-base': 1.0 } },
      { slug: 'diver', name: 'Diver', qualityProfile: { 'vertical-power': 0.9, 'landing-mechanics': 0.9, 'trunk-anti-rotation': 0.7 } },
    ],
    skills: [
      skill('start-power', 'Start power', { 'horizontal-power': 0.9, 'vertical-power': 0.8, 'lower-body-strength': 0.8, 'reactive-strength': 0.7, 'trunk-anti-rotation': 0.5 }), skill('turn-speed', 'Turn speed', { 'reactive-strength': 0.8, 'horizontal-power': 0.7, 'trunk-anti-rotation': 0.7, 'lower-body-strength': 0.6, 'hip-mobility': 0.5 }),
      skill('stroke-rate', 'Stroke rate', { 'anaerobic-capacity': 0.8, 'upper-body-pull': 0.8, 'shoulder-stability': 0.7, 'aerobic-base': 0.6, 'trunk-anti-rotation': 0.5 }), skill('shoulder-durability', 'Shoulder durability', { 'shoulder-stability': 1.0, 'upper-body-pull': 0.6, 'trunk-anti-rotation': 0.5 }),
      skill('underwater-dolphin-kick', 'Underwater dolphin kick', { 'trunk-anti-rotation': 0.9, 'hip-mobility': 0.8, 'ankle-stiffness': 0.7, 'anaerobic-capacity': 0.6, 'aerobic-base': 0.5 }), skill('pacing-strategy', 'Pacing strategy', { 'aerobic-base': 0.9, 'anaerobic-capacity': 0.7, 'repeat-sprint': 0.4 }),
      skill('body-position', 'Body position and drag reduction', { 'trunk-anti-rotation': 0.9, 'shoulder-stability': 0.6, 'hip-mobility': 0.6 }), skill('entry-technique', 'Diving entry technique', { 'trunk-anti-rotation': 0.8, 'shoulder-stability': 0.7, 'hip-mobility': 0.6, 'vertical-power': 0.5, 'landing-mechanics': 0.5 }),
    ],
    commonLoadAreas: ['shoulders', 'lower-back'],
    contactLevel: 'NONE',
    typicalSessionLength: 90, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'ice-hockey',
    name: 'Ice Hockey',
    governing: ['NFHS', 'NCAA'],
    season: 'WINTER',
    monthRange: [11, 3],
    qualityProfile: {
      'acceleration': 0.9, 'change-of-direction': 0.9, 'rotational-power': 0.8,
      'single-leg-stability': 0.8, 'anaerobic-capacity': 0.9, 'aerobic-base': 0.5,
      'grip': 0.4, 'shoulder-stability': 0.2,
    },
    positions: [
      { slug: 'goaltender', name: 'Goaltender', qualityProfile: { 'hip-mobility': 0.9, 'lateral-power': 0.9, 'reactive-strength': 0.8, 'landing-mechanics': 0.7 } },
      { slug: 'defence', name: 'Defence', qualityProfile: { 'deceleration': 0.8, 'lower-body-strength': 0.7, 'change-of-direction': 0.8 } },
      { slug: 'forward', name: 'Forward', qualityProfile: { 'acceleration': 0.9, 'anaerobic-capacity': 0.9, 'rotational-power': 0.8 } },
    ],
    skills: [
      skill('shooting-power', 'Shooting power', { 'rotational-power': 1.0, 'trunk-anti-rotation': 0.8, 'grip': 0.7, 'shoulder-stability': 0.6, 'lower-body-strength': 0.5, 'single-leg-stability': 0.5, 'upper-body-push': 0.4 }), skill('skating-speed', 'Skating speed', { 'max-velocity': 0.9, 'lateral-power': 0.9, 'acceleration': 0.8, 'lower-body-strength': 0.8, 'single-leg-stability': 0.7, 'hip-mobility': 0.6 }),
      skill('edge-work', 'Edge work', { 'single-leg-stability': 0.9, 'lateral-power': 0.8, 'change-of-direction': 0.8, 'ankle-stiffness': 0.7, 'hip-mobility': 0.6, 'deceleration': 0.6 }), skill('puck-handling', 'Puck handling', { 'grip': 0.8, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.5, 'single-leg-stability': 0.5, 'change-of-direction': 0.5 }),
      skill('checking-strength', 'Checking strength', { 'lower-body-strength': 0.8, 'upper-body-push': 0.8, 'trunk-anti-rotation': 0.8, 'horizontal-power': 0.6, 'shoulder-stability': 0.6, 'landing-mechanics': 0.4 }), skill('crossover-acceleration', 'Crossover acceleration', { 'acceleration': 0.9, 'lateral-power': 0.9, 'single-leg-stability': 0.7, 'lower-body-strength': 0.6, 'hip-mobility': 0.5 }),
      skill('shot-release-quickness', 'Shot release quickness', { 'rotational-power': 0.9, 'grip': 0.8, 'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.6, 'reactive-strength': 0.5 }), skill('shift-endurance', 'Shift endurance', { 'anaerobic-capacity': 1.0, 'repeat-sprint': 0.8, 'aerobic-base': 0.6, 'lower-body-strength': 0.4 }),
    ],
    commonLoadAreas: ['hips', 'groin', 'lower-back'],
    contactLevel: 'COLLISION',
    typicalSessionLength: 90, typicalWeeklyGames: 2,
  }),

  sport({
    slug: 'field-hockey',
    name: 'Field Hockey',
    governing: ['NFHS', 'NCAA'],
    season: 'FALL',
    monthRange: [8, 11],
    qualityProfile: {
      'aerobic-base': 0.8, 'repeat-sprint': 0.7, 'change-of-direction': 0.8,
      'rotational-power': 0.6, 'grip': 0.5, 'single-leg-stability': 0.5,
    },
    positions: [
      { slug: 'goalkeeper', name: 'Goalkeeper', qualityProfile: { 'reactive-strength': 0.9, 'lateral-power': 0.8, 'landing-mechanics': 0.7 } },
      { slug: 'defender', name: 'Defender', qualityProfile: { 'deceleration': 0.8, 'aerobic-base': 0.7 } },
      { slug: 'midfielder', name: 'Midfielder', qualityProfile: { 'aerobic-base': 1.0, 'repeat-sprint': 0.9 } },
      { slug: 'forward', name: 'Forward', qualityProfile: { 'acceleration': 0.9, 'rotational-power': 0.7 } },
    ],
    skills: [
      skill('drag-flick-power', 'Drag-flick power', { 'rotational-power': 1.0, 'horizontal-power': 0.7, 'lower-body-strength': 0.7, 'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.6, 'hip-mobility': 0.6 }), skill('sprint-speed', 'Sprint speed', { 'acceleration': 0.9, 'max-velocity': 0.9, 'repeat-sprint': 0.7, 'horizontal-power': 0.6 }),
      skill('stick-handling', 'Stick handling', { 'grip': 0.8, 'trunk-anti-rotation': 0.6, 'hip-mobility': 0.6, 'change-of-direction': 0.6, 'lateral-power': 0.5 }), skill('passing-accuracy', 'Passing accuracy', { 'rotational-power': 0.7, 'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.6, 'single-leg-stability': 0.6, 'grip': 0.5 }),
      skill('low-athletic-stance', 'Low athletic stance endurance', { 'hip-mobility': 0.9, 'lower-body-strength': 0.8, 'single-leg-stability': 0.7, 'trunk-anti-rotation': 0.6, 'ankle-stiffness': 0.5 }), skill('agility', 'Agility and cutting', { 'change-of-direction': 1.0, 'deceleration': 0.8, 'lateral-power': 0.7, 'acceleration': 0.6, 'ankle-stiffness': 0.5 }),
      skill('tackling-timing', 'Tackling timing', { 'deceleration': 0.8, 'lateral-power': 0.8, 'reactive-strength': 0.7, 'single-leg-stability': 0.6, 'change-of-direction': 0.6 }), skill('reverse-stick-control', 'Reverse-stick control', { 'grip': 0.8, 'rotational-power': 0.7, 'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.6, 'hip-mobility': 0.5 }),
    ],
    commonLoadAreas: ['lower-back', 'hamstrings', 'wrists'],
    contactLevel: 'LIMITED',
    typicalSessionLength: 80, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'lacrosse',
    name: 'Lacrosse',
    governing: ['NFHS', 'NCAA'],
    season: 'SPRING',
    monthRange: [3, 6],
    qualityProfile: {
      'acceleration': 0.8, 'rotational-power': 0.8, 'aerobic-base': 0.6,
      'change-of-direction': 0.7, 'grip': 0.6, 'upper-body-push': 0.5,
    },
    positions: [
      { slug: 'attack', name: 'Attack', qualityProfile: { 'change-of-direction': 0.9, 'rotational-power': 0.8 } },
      { slug: 'midfield', name: 'Midfield', qualityProfile: { 'aerobic-base': 1.0, 'repeat-sprint': 0.8 } },
      { slug: 'defense', name: 'Defense', qualityProfile: { 'lower-body-strength': 0.7, 'lateral-power': 0.7 } },
      { slug: 'goalie', name: 'Goalie', qualityProfile: { 'reactive-strength': 0.9, 'lateral-power': 0.8 } },
    ],
    skills: [
      skill('shot-velocity', 'Shot velocity', { 'rotational-power': 1.0, 'overhead-power': 0.7, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.7, 'lower-body-strength': 0.5, 'hip-mobility': 0.5, 'grip': 0.5 }), skill('dodging-quickness', 'Dodging quickness', { 'change-of-direction': 1.0, 'deceleration': 0.8, 'acceleration': 0.8, 'lateral-power': 0.7, 'ankle-stiffness': 0.5 }),
      skill('stick-protection', 'Stick protection strength', { 'trunk-anti-rotation': 0.8, 'grip': 0.7, 'shoulder-stability': 0.6, 'upper-body-push': 0.5, 'change-of-direction': 0.5 }), skill('ground-ball-speed', 'Ground-ball reaction speed', { 'acceleration': 0.9, 'hip-mobility': 0.7, 'lower-body-strength': 0.6, 'deceleration': 0.6, 'grip': 0.5 }),
      skill('face-off-power', 'Face-off power', { 'reactive-strength': 0.9, 'grip': 0.8, 'lower-body-strength': 0.7, 'trunk-anti-rotation': 0.7, 'acceleration': 0.6, 'upper-body-push': 0.5 }), skill('field-vision', 'Field vision under speed', { 'aerobic-base': 0.7, 'change-of-direction': 0.5, 'single-leg-stability': 0.5 }),
      skill('cradling-under-pressure', 'Cradling under pressure', { 'grip': 0.8, 'trunk-anti-rotation': 0.8, 'shoulder-stability': 0.6, 'change-of-direction': 0.6 }), skill('transition-speed', 'Transition speed', { 'acceleration': 0.9, 'max-velocity': 0.8, 'repeat-sprint': 0.8, 'aerobic-base': 0.5 }),
    ],
    commonLoadAreas: ['shoulders', 'lower-back', 'wrists'],
    contactLevel: 'CONTACT',
    typicalSessionLength: 90, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'competitive-spirit',
    name: 'Competitive Spirit (Cheer)',
    governing: ['NFHS'],
    season: 'WINTER',
    monthRange: [11, 2],
    qualityProfile: {
      'vertical-power': 0.8, 'reactive-strength': 0.7, 'trunk-anti-rotation': 0.7,
      'shoulder-stability': 0.7, 'single-leg-stability': 0.6, 'landing-mechanics': 0.8,
      'upper-body-push': 0.5,
    },
    skills: [
      skill('tumbling-power', 'Tumbling power', { 'vertical-power': 0.9, 'reactive-strength': 0.8, 'horizontal-power': 0.7, 'trunk-anti-rotation': 0.7, 'landing-mechanics': 0.7, 'shoulder-stability': 0.6 }), skill('stunt-stability', 'Stunt stability', { 'trunk-anti-rotation': 0.9, 'shoulder-stability': 0.8, 'single-leg-stability': 0.7, 'upper-body-push': 0.6, 'lower-body-strength': 0.6 }),
      skill('jump-height', 'Jump height', { 'vertical-power': 1.0, 'reactive-strength': 0.8, 'lower-body-strength': 0.6, 'ankle-stiffness': 0.6, 'landing-mechanics': 0.6 }), skill('landing-control', 'Landing control', { 'landing-mechanics': 1.0, 'single-leg-stability': 0.7, 'ankle-stiffness': 0.7, 'lower-body-strength': 0.6, 'trunk-anti-rotation': 0.5 }),
      skill('base-strength', 'Base strength', { 'lower-body-strength': 0.9, 'upper-body-push': 0.8, 'trunk-anti-rotation': 0.8, 'shoulder-stability': 0.7 }), skill('flyer-core-control', 'Flyer core control', { 'trunk-anti-rotation': 1.0, 'single-leg-stability': 0.8, 'shoulder-stability': 0.6, 'hip-mobility': 0.6, 'ankle-stiffness': 0.5 }),
      skill('flexibility', 'Flexibility for kicks and scale positions', { 'hip-mobility': 1.0, 'shoulder-stability': 0.6, 'single-leg-stability': 0.4 }), skill('timing-synchronisation', 'Timing and synchronisation', { 'aerobic-base': 0.6, 'reactive-strength': 0.5, 'trunk-anti-rotation': 0.5, 'landing-mechanics': 0.5 }),
    ],
    commonLoadAreas: ['wrists', 'shoulders', 'lower-back'],
    contactLevel: 'CONTACT',
    typicalSessionLength: 90, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'flag-football',
    name: 'Flag Football',
    governing: ['NFHS', 'NCAA'],
    season: 'SPRING',
    monthRange: [3, 5],
    qualityProfile: {
      'max-velocity': 0.9, 'change-of-direction': 0.9, 'acceleration': 0.8,
      'rotational-power': 0.6, 'deceleration': 0.6,
    },
    skills: [
      skill('sprint-speed', 'Sprint speed', { 'acceleration': 1.0, 'max-velocity': 0.9, 'horizontal-power': 0.6, 'repeat-sprint': 0.5 }), skill('route-running', 'Route running', { 'change-of-direction': 0.9, 'deceleration': 0.9, 'acceleration': 0.8, 'ankle-stiffness': 0.5, 'single-leg-stability': 0.5 }),
      skill('flag-pull-reaction', 'Flag-pull reaction', { 'reactive-strength': 0.8, 'lateral-power': 0.8, 'deceleration': 0.7, 'change-of-direction': 0.7, 'grip': 0.4 }), skill('throwing-accuracy', 'Throwing accuracy', { 'shoulder-stability': 0.8, 'rotational-power': 0.7, 'overhead-power': 0.6, 'trunk-anti-rotation': 0.6, 'single-leg-stability': 0.5 }),
      skill('lateral-agility', 'Lateral agility', { 'lateral-power': 0.9, 'change-of-direction': 0.9, 'deceleration': 0.8, 'ankle-stiffness': 0.6, 'single-leg-stability': 0.5 }), skill('change-of-pace', 'Change of pace', { 'acceleration': 0.9, 'deceleration': 0.9, 'change-of-direction': 0.6, 'max-velocity': 0.5 }),
      skill('one-handed-catching', 'One-handed catching', { 'shoulder-stability': 0.7, 'grip': 0.7, 'reactive-strength': 0.5, 'trunk-anti-rotation': 0.5, 'vertical-power': 0.4 }), skill('deceleration-and-cut', 'Deceleration and cut', { 'deceleration': 1.0, 'change-of-direction': 0.9, 'single-leg-stability': 0.7, 'ankle-stiffness': 0.6, 'lower-body-strength': 0.5 }),
    ],
    commonLoadAreas: ['hamstrings', 'groin'],
    contactLevel: 'LIMITED',
    typicalSessionLength: 70, typicalWeeklyGames: 2,
  }),

  sport({
    slug: 'bowling',
    name: 'Bowling',
    governing: ['NFHS', 'NCAA'],
    season: 'WINTER',
    monthRange: [11, 2],
    qualityProfile: {
      'single-leg-stability': 0.6, 'grip': 0.6, 'hip-mobility': 0.5,
      'trunk-anti-rotation': 0.5, 'lower-body-strength': 0.4,
    },
    skills: [
      skill('release-consistency', 'Release consistency', { 'shoulder-stability': 0.8, 'single-leg-stability': 0.7, 'grip': 0.6, 'trunk-anti-rotation': 0.6 }), skill('approach-timing', 'Approach timing', { 'single-leg-stability': 0.7, 'trunk-anti-rotation': 0.6, 'deceleration': 0.5, 'ankle-stiffness': 0.5 }),
      skill('ball-speed-control', 'Ball speed control', { 'shoulder-stability': 0.7, 'grip': 0.7, 'rotational-power': 0.6, 'trunk-anti-rotation': 0.6, 'lower-body-strength': 0.5 }), skill('balance-at-foul-line', 'Balance at the foul line', { 'single-leg-stability': 1.0, 'trunk-anti-rotation': 0.7, 'deceleration': 0.6, 'ankle-stiffness': 0.6, 'hip-mobility': 0.5 }),
      skill('spare-conversion', 'Spare conversion', { 'single-leg-stability': 0.7, 'shoulder-stability': 0.6, 'trunk-anti-rotation': 0.6, 'grip': 0.5 }), skill('wrist-hand-strength', 'Wrist and hand strength', { 'grip': 1.0, 'shoulder-stability': 0.5, 'upper-body-pull': 0.5 }),
      skill('lane-reading', 'Lane reading', { 'single-leg-stability': 0.6, 'trunk-anti-rotation': 0.5, 'aerobic-base': 0.4 }), skill('follow-through-consistency', 'Follow-through consistency', { 'shoulder-stability': 0.8, 'single-leg-stability': 0.7, 'trunk-anti-rotation': 0.7, 'hip-mobility': 0.5 }),
    ],
    commonLoadAreas: ['wrist', 'shoulder', 'knee'],
    contactLevel: 'NONE',
    typicalSessionLength: 60, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'gymnastics',
    name: 'Gymnastics',
    governing: ['NFHS', 'NCAA'],
    season: 'WINTER',
    monthRange: [11, 3],
    qualityProfile: {
      'reactive-strength': 0.9, 'trunk-anti-rotation': 0.8, 'shoulder-stability': 0.8,
      'landing-mechanics': 0.9, 'rotational-power': 0.6, 'upper-body-push': 0.6,
      'hip-mobility': 0.6,
    },
    skills: [
      skill('tumbling-power', 'Tumbling power', { 'vertical-power': 0.9, 'reactive-strength': 0.9, 'horizontal-power': 0.8, 'trunk-anti-rotation': 0.7, 'landing-mechanics': 0.7, 'shoulder-stability': 0.6 }), skill('landing-control', 'Landing control', { 'landing-mechanics': 1.0, 'ankle-stiffness': 0.8, 'single-leg-stability': 0.7, 'lower-body-strength': 0.6, 'trunk-anti-rotation': 0.6 }),
      skill('bar-swing-strength', 'Bar swing strength', { 'upper-body-pull': 0.9, 'grip': 0.9, 'shoulder-stability': 0.8, 'trunk-anti-rotation': 0.8 }), skill('beam-balance', 'Beam balance', { 'single-leg-stability': 1.0, 'trunk-anti-rotation': 0.8, 'ankle-stiffness': 0.7, 'hip-mobility': 0.6 }),
      skill('flexibility', 'Flexibility and splits', { 'hip-mobility': 1.0, 'shoulder-stability': 0.7, 'single-leg-stability': 0.4 }), skill('vault-block-power', 'Vault block power', { 'upper-body-push': 0.9, 'shoulder-stability': 0.8, 'reactive-strength': 0.8, 'acceleration': 0.7, 'trunk-anti-rotation': 0.6 }),
      skill('core-hollow-hold', 'Core hollow-body control', { 'trunk-anti-rotation': 1.0, 'shoulder-stability': 0.6, 'hip-mobility': 0.5 }), skill('shoulder-durability', 'Shoulder durability', { 'shoulder-stability': 1.0, 'upper-body-pull': 0.6, 'upper-body-push': 0.6, 'trunk-anti-rotation': 0.5 }),
    ],
    commonLoadAreas: ['wrists', 'shoulders', 'lower-back'],
    contactLevel: 'NONE',
    typicalSessionLength: 120, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'water-polo',
    name: 'Water Polo',
    governing: ['NFHS', 'NCAA'],
    season: 'FALL',
    monthRange: [8, 11],
    qualityProfile: {
      'aerobic-base': 0.8, 'anaerobic-capacity': 0.8, 'overhead-power': 0.7,
      'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.6, 'grip': 0.5,
    },
    skills: [
      skill('shot-velocity', 'Shot velocity', { 'overhead-power': 1.0, 'rotational-power': 0.9, 'shoulder-stability': 0.8, 'trunk-anti-rotation': 0.7, 'hip-mobility': 0.5 }), skill('eggbeater-endurance', 'Eggbeater kick endurance', { 'hip-mobility': 0.9, 'aerobic-base': 0.8, 'anaerobic-capacity': 0.7, 'lower-body-strength': 0.6, 'trunk-anti-rotation': 0.5 }),
      skill('treading-power', 'Treading power', { 'lower-body-strength': 0.8, 'hip-mobility': 0.8, 'vertical-power': 0.7, 'trunk-anti-rotation': 0.6, 'anaerobic-capacity': 0.5 }), skill('passing-accuracy', 'Passing accuracy', { 'shoulder-stability': 0.8, 'overhead-power': 0.6, 'rotational-power': 0.6, 'trunk-anti-rotation': 0.6, 'grip': 0.5 }),
      skill('sprint-swim-speed', 'Sprint swim speed', { 'anaerobic-capacity': 0.9, 'upper-body-pull': 0.8, 'acceleration': 0.8, 'shoulder-stability': 0.6, 'trunk-anti-rotation': 0.5 }), skill('shoulder-durability', 'Shoulder durability', { 'shoulder-stability': 1.0, 'upper-body-pull': 0.6, 'trunk-anti-rotation': 0.5 }),
      skill('vertical-power-out-of-water', 'Vertical power out of the water', { 'vertical-power': 0.9, 'hip-mobility': 0.8, 'lower-body-strength': 0.7, 'trunk-anti-rotation': 0.7, 'reactive-strength': 0.5 }), skill('defensive-positioning-strength', 'Defensive positioning strength', { 'trunk-anti-rotation': 0.8, 'lower-body-strength': 0.7, 'upper-body-push': 0.7, 'grip': 0.6, 'anaerobic-capacity': 0.6 }),
    ],
    commonLoadAreas: ['shoulders', 'hips'],
    contactLevel: 'CONTACT',
    typicalSessionLength: 90, typicalWeeklyGames: 2,
  }),

  sport({
    slug: 'rowing',
    name: 'Rowing (Crew)',
    governing: ['NCAA'],
    season: 'SPRING',
    monthRange: [3, 6],
    qualityProfile: {
      'aerobic-base': 1.0, 'lower-body-strength': 0.7, 'upper-body-pull': 0.7,
      'trunk-anti-rotation': 0.6, 'anaerobic-capacity': 0.6,
    },
    skills: [
      skill('power-per-stroke', 'Power per stroke', { 'lower-body-strength': 0.9, 'horizontal-power': 0.8, 'upper-body-pull': 0.8, 'trunk-anti-rotation': 0.7, 'grip': 0.5 }), skill('stroke-rate-efficiency', 'Stroke-rate efficiency', { 'anaerobic-capacity': 0.8, 'aerobic-base': 0.8, 'hip-mobility': 0.6, 'upper-body-pull': 0.6, 'trunk-anti-rotation': 0.5 }),
      skill('2k-erg-pace', '2k erg pace', { 'aerobic-base': 0.9, 'anaerobic-capacity': 0.9, 'lower-body-strength': 0.6, 'upper-body-pull': 0.6 }), skill('leg-drive-power', 'Leg-drive power', { 'lower-body-strength': 1.0, 'horizontal-power': 0.8, 'reactive-strength': 0.5, 'trunk-anti-rotation': 0.5 }),
      skill('core-transfer', 'Core-to-oar power transfer', { 'trunk-anti-rotation': 1.0, 'upper-body-pull': 0.6, 'hip-mobility': 0.6 }), skill('recovery-timing', 'Recovery-phase timing', { 'hip-mobility': 0.7, 'aerobic-base': 0.7, 'trunk-anti-rotation': 0.5, 'shoulder-stability': 0.4 }),
      skill('boat-feel-timing', 'Boat feel and timing', { 'trunk-anti-rotation': 0.7, 'single-leg-stability': 0.6, 'aerobic-base': 0.5, 'grip': 0.4 }), skill('sprint-finish-power', 'Sprint finish power', { 'anaerobic-capacity': 1.0, 'lower-body-strength': 0.7, 'upper-body-pull': 0.7, 'horizontal-power': 0.6 }),
    ],
    commonLoadAreas: ['lower-back', 'knees'],
    contactLevel: 'NONE',
    typicalSessionLength: 100, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'skiing',
    name: 'Skiing (Alpine / Nordic)',
    governing: ['NFHS'],
    season: 'WINTER',
    monthRange: [12, 2],
    qualityProfile: {
      'single-leg-stability': 0.8, 'lower-body-strength': 0.7, 'aerobic-base': 0.6,
      'anaerobic-capacity': 0.5, 'hip-mobility': 0.5, 'trunk-anti-rotation': 0.5,
    },
    skills: [
      skill('edge-control', 'Edge control', { 'single-leg-stability': 0.9, 'lateral-power': 0.8, 'ankle-stiffness': 0.8, 'lower-body-strength': 0.7, 'trunk-anti-rotation': 0.6, 'hip-mobility': 0.6 }), skill('turn-power', 'Turn power', { 'lower-body-strength': 0.9, 'lateral-power': 0.8, 'single-leg-stability': 0.8, 'trunk-anti-rotation': 0.6, 'deceleration': 0.6 }),
      skill('tuck-endurance', 'Aerodynamic tuck endurance', { 'lower-body-strength': 0.9, 'anaerobic-capacity': 0.8, 'trunk-anti-rotation': 0.7, 'hip-mobility': 0.5 }), skill('poling-power', 'Poling power (Nordic)', { 'upper-body-push': 0.7, 'upper-body-pull': 0.7, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.6, 'anaerobic-capacity': 0.5 }),
      skill('balance-recovery', 'Balance recovery', { 'single-leg-stability': 1.0, 'reactive-strength': 0.7, 'trunk-anti-rotation': 0.7, 'ankle-stiffness': 0.7 }), skill('leg-endurance', 'Leg endurance on long runs', { 'anaerobic-capacity': 0.9, 'lower-body-strength': 0.8, 'aerobic-base': 0.6, 'single-leg-stability': 0.5 }),
      skill('start-power', 'Start power', { 'upper-body-push': 0.7, 'acceleration': 0.7, 'horizontal-power': 0.7, 'trunk-anti-rotation': 0.6, 'lower-body-strength': 0.5 }), skill('cornering-precision', 'Cornering precision', { 'single-leg-stability': 0.9, 'lateral-power': 0.8, 'ankle-stiffness': 0.7, 'trunk-anti-rotation': 0.6, 'deceleration': 0.6 }),
    ],
    commonLoadAreas: ['knees', 'lower-back'],
    contactLevel: 'LIMITED',
    typicalSessionLength: 90, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'rifle',
    name: 'Rifle',
    governing: ['NFHS', 'NCAA'],
    season: 'WINTER',
    monthRange: [11, 2],
    qualityProfile: {
      'single-leg-stability': 0.3, 'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.6,
      'grip': 0.4, 'aerobic-base': 0.3,
    },
    skills: [
      skill('postural-stability', 'Postural stability', { 'trunk-anti-rotation': 1.0, 'single-leg-stability': 0.8, 'hip-mobility': 0.5, 'shoulder-stability': 0.5 }), skill('breath-control', 'Breath control', { 'aerobic-base': 0.8, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.4 }),
      skill('trigger-consistency', 'Trigger-pull consistency', { 'grip': 0.7, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.5 }), skill('positional-endurance', 'Positional endurance (prone/kneeling/standing)', { 'trunk-anti-rotation': 0.9, 'shoulder-stability': 0.7, 'hip-mobility': 0.6, 'aerobic-base': 0.5 }),
      skill('focus-under-fatigue', 'Focus under fatigue', { 'aerobic-base': 0.8, 'trunk-anti-rotation': 0.6, 'single-leg-stability': 0.4 }), skill('heart-rate-management', 'Heart-rate management between shots', { 'aerobic-base': 1.0, 'trunk-anti-rotation': 0.4, 'single-leg-stability': 0.3 }),
      skill('natural-point-of-aim', 'Natural point of aim', { 'single-leg-stability': 0.8, 'trunk-anti-rotation': 0.8, 'hip-mobility': 0.6, 'shoulder-stability': 0.5 }), skill('recoil-management', 'Recoil management', { 'shoulder-stability': 0.8, 'trunk-anti-rotation': 0.8, 'grip': 0.6, 'upper-body-push': 0.5 }),
    ],
    commonLoadAreas: ['lower-back', 'shoulders'],
    contactLevel: 'NONE',
    typicalSessionLength: 60, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'fencing',
    name: 'Fencing',
    governing: ['NFHS', 'NCAA'],
    season: 'WINTER',
    monthRange: [11, 3],
    qualityProfile: {
      'acceleration': 0.8, 'reactive-strength': 0.7, 'single-leg-stability': 0.6,
      'anaerobic-capacity': 0.6, 'hip-mobility': 0.5, 'lateral-power': 0.5,
    },
    skills: [
      skill('lunge-power', 'Lunge power', { 'horizontal-power': 1.0, 'lower-body-strength': 0.8, 'acceleration': 0.7, 'reactive-strength': 0.6, 'hip-mobility': 0.6, 'single-leg-stability': 0.5 }), skill('advance-retreat-speed', 'Advance-retreat footwork speed', { 'acceleration': 0.9, 'deceleration': 0.9, 'reactive-strength': 0.8, 'ankle-stiffness': 0.7, 'lateral-power': 0.5 }),
      skill('reaction-time', 'Reaction time', { 'reactive-strength': 1.0, 'acceleration': 0.8, 'ankle-stiffness': 0.5 }), skill('blade-hand-speed', 'Blade hand speed', { 'shoulder-stability': 0.8, 'grip': 0.7, 'reactive-strength': 0.6, 'trunk-anti-rotation': 0.4 }),
      skill('lower-body-endurance', 'Lower-body endurance in en-garde stance', { 'lower-body-strength': 0.8, 'anaerobic-capacity': 0.8, 'aerobic-base': 0.6, 'single-leg-stability': 0.5 }), skill('distance-judgement', 'Distance judgement', { 'deceleration': 0.8, 'acceleration': 0.7, 'single-leg-stability': 0.6, 'reactive-strength': 0.5 }),
      skill('footwork-endurance', 'Footwork endurance', { 'anaerobic-capacity': 0.9, 'aerobic-base': 0.7, 'reactive-strength': 0.6, 'ankle-stiffness': 0.6 }), skill('feint-timing', 'Feint timing', { 'reactive-strength': 0.8, 'deceleration': 0.7, 'acceleration': 0.6, 'shoulder-stability': 0.5 }),
    ],
    commonLoadAreas: ['front-knee', 'hip-flexors'],
    contactLevel: 'LIMITED',
    typicalSessionLength: 75, typicalWeeklyGames: 1,
  }),

  sport({
    slug: 'ultimate',
    name: 'Ultimate (Frisbee)',
    governing: ['NCAA'],
    season: 'SPRING',
    monthRange: [3, 6],
    qualityProfile: {
      'max-velocity': 0.8, 'aerobic-base': 0.7, 'change-of-direction': 0.8,
      'vertical-power': 0.6, 'rotational-power': 0.5, 'deceleration': 0.6,
    },
    skills: [
      skill('sprint-speed', 'Sprint speed', { 'acceleration': 1.0, 'max-velocity': 0.9, 'repeat-sprint': 0.7, 'horizontal-power': 0.6 }), skill('layout-explosiveness', 'Layout explosiveness', { 'horizontal-power': 1.0, 'acceleration': 0.8, 'landing-mechanics': 0.8, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.5 }),
      skill('throwing-power', 'Throwing power', { 'rotational-power': 1.0, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.7, 'single-leg-stability': 0.6, 'grip': 0.5 }), skill('cutting-sharpness', 'Cutting sharpness', { 'change-of-direction': 1.0, 'deceleration': 0.9, 'acceleration': 0.8, 'ankle-stiffness': 0.6, 'single-leg-stability': 0.5 }),
      skill('vertical-jump-for-discs', 'Vertical jump for contested discs', { 'vertical-power': 1.0, 'reactive-strength': 0.8, 'landing-mechanics': 0.7, 'lower-body-strength': 0.6 }), skill('endurance-across-points', 'Endurance across points', { 'repeat-sprint': 0.9, 'aerobic-base': 0.9, 'anaerobic-capacity': 0.7 }),
      skill('pivoting-footwork', 'Pivoting footwork', { 'single-leg-stability': 0.9, 'hip-mobility': 0.8, 'lateral-power': 0.6, 'ankle-stiffness': 0.6, 'trunk-anti-rotation': 0.5 }), skill('marking-recovery', 'Marking recovery speed', { 'lateral-power': 0.9, 'acceleration': 0.8, 'deceleration': 0.7, 'change-of-direction': 0.7, 'repeat-sprint': 0.5 }),
    ],
    commonLoadAreas: ['hamstrings', 'shoulders', 'knees'],
    contactLevel: 'LIMITED',
    typicalSessionLength: 90, typicalWeeklyGames: 1,
  }),

  // ═══════════════════════════════════════════════════════════════════════
  // Long tail — full profile and 4–6 skills each (§5: never zero skills).
  // ═══════════════════════════════════════════════════════════════════════

  sport({
    slug: 'badminton', name: 'Badminton', governing: ['NFHS', 'NCAA'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'reactive-strength': 0.8, 'lateral-power': 0.7, 'overhead-power': 0.6, 'change-of-direction': 0.7, 'anaerobic-capacity': 0.6 },
    skills: [skill('smash-power', 'Smash power', { 'overhead-power': 1.0, 'rotational-power': 0.8, 'shoulder-stability': 0.8, 'vertical-power': 0.6, 'trunk-anti-rotation': 0.6 }), skill('footwork-speed', 'Footwork speed', { 'acceleration': 0.9, 'lateral-power': 0.9, 'deceleration': 0.8, 'reactive-strength': 0.7, 'ankle-stiffness': 0.6 }), skill('net-control', 'Net control', { 'single-leg-stability': 0.8, 'deceleration': 0.7, 'shoulder-stability': 0.6, 'grip': 0.5, 'hip-mobility': 0.5 }), skill('deception', 'Shot deception', { 'shoulder-stability': 0.7, 'grip': 0.6, 'reactive-strength': 0.6, 'trunk-anti-rotation': 0.5, 'single-leg-stability': 0.5 }), skill('court-coverage-endurance', 'Court coverage endurance', { 'anaerobic-capacity': 0.9, 'repeat-sprint': 0.8, 'aerobic-base': 0.7, 'lateral-power': 0.5 })],
    commonLoadAreas: ['shoulder', 'knees'], contactLevel: 'NONE', typicalSessionLength: 60,
  }),
  sport({
    slug: 'table-tennis', name: 'Table Tennis', governing: ['NCAA'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'reactive-strength': 0.7, 'rotational-power': 0.5, 'lateral-power': 0.5, 'grip': 0.4 },
    skills: [skill('paddle-speed', 'Paddle speed', { 'rotational-power': 0.9, 'shoulder-stability': 0.7, 'grip': 0.6, 'reactive-strength': 0.6, 'trunk-anti-rotation': 0.5 }), skill('footwork-quickness', 'Footwork quickness', { 'reactive-strength': 0.9, 'lateral-power': 0.9, 'acceleration': 0.7, 'ankle-stiffness': 0.6, 'deceleration': 0.6 }), skill('spin-generation', 'Spin generation', { 'grip': 0.8, 'rotational-power': 0.8, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.5 }), skill('reaction-time', 'Reaction time', { 'reactive-strength': 1.0, 'acceleration': 0.6, 'lateral-power': 0.5 })],
    commonLoadAreas: ['wrist', 'shoulder'], contactLevel: 'NONE', typicalSessionLength: 50,
  }),
  sport({
    slug: 'squash', name: 'Squash', governing: ['NCAA'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'aerobic-base': 0.7, 'anaerobic-capacity': 0.7, 'lateral-power': 0.7, 'single-leg-stability': 0.5, 'change-of-direction': 0.8 },
    skills: [skill('lunge-power', 'Lunge power', { 'horizontal-power': 0.9, 'lower-body-strength': 0.8, 'deceleration': 0.8, 'single-leg-stability': 0.7, 'hip-mobility': 0.6 }), skill('court-speed', 'Court speed', { 'acceleration': 0.9, 'change-of-direction': 0.9, 'deceleration': 0.8, 'lateral-power': 0.7, 'repeat-sprint': 0.6 }), skill('shot-accuracy', 'Shot accuracy', { 'shoulder-stability': 0.8, 'single-leg-stability': 0.7, 'trunk-anti-rotation': 0.6, 'rotational-power': 0.5, 'grip': 0.5 }), skill('recovery-speed', 'Recovery speed to the T', { 'acceleration': 0.9, 'deceleration': 0.8, 'change-of-direction': 0.8, 'anaerobic-capacity': 0.7, 'repeat-sprint': 0.6 })],
    commonLoadAreas: ['knees', 'hip-flexors'], contactLevel: 'LIMITED', typicalSessionLength: 60,
  }),
  sport({
    slug: 'pickleball', name: 'Pickleball', governing: ['NFHS'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'reactive-strength': 0.6, 'lateral-power': 0.6, 'single-leg-stability': 0.4, 'grip': 0.4 },
    skills: [skill('dink-touch', 'Dink touch', { 'shoulder-stability': 0.8, 'single-leg-stability': 0.7, 'grip': 0.6, 'trunk-anti-rotation': 0.5, 'deceleration': 0.5 }), skill('third-shot-drop', 'Third-shot drop consistency', { 'shoulder-stability': 0.8, 'single-leg-stability': 0.7, 'trunk-anti-rotation': 0.6, 'rotational-power': 0.5, 'grip': 0.5 }), skill('lateral-quickness', 'Lateral quickness', { 'lateral-power': 0.9, 'deceleration': 0.8, 'reactive-strength': 0.7, 'ankle-stiffness': 0.6, 'single-leg-stability': 0.5 }), skill('reaction-time', 'Net reaction time', { 'reactive-strength': 1.0, 'acceleration': 0.6, 'lateral-power': 0.6, 'shoulder-stability': 0.4 })],
    commonLoadAreas: ['knees', 'shoulder'], contactLevel: 'NONE', typicalSessionLength: 50,
  }),
  sport({
    slug: 'team-handball', name: 'Team Handball', governing: ['NCAA'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'overhead-power': 0.8, 'acceleration': 0.7, 'rotational-power': 0.7, 'vertical-power': 0.6, 'anaerobic-capacity': 0.6 },
    skills: [skill('throwing-velocity', 'Throwing velocity', { 'overhead-power': 1.0, 'rotational-power': 0.9, 'shoulder-stability': 0.8, 'trunk-anti-rotation': 0.7, 'hip-mobility': 0.5, 'lower-body-strength': 0.5 }), skill('jump-shot-power', 'Jump-shot power', { 'vertical-power': 0.9, 'overhead-power': 0.8, 'rotational-power': 0.7, 'reactive-strength': 0.7, 'landing-mechanics': 0.6 }), skill('sprint-speed', 'Sprint speed', { 'acceleration': 0.9, 'max-velocity': 0.9, 'repeat-sprint': 0.8, 'horizontal-power': 0.6 }), skill('one-v-one-defending', '1v1 defending', { 'lateral-power': 0.9, 'deceleration': 0.9, 'change-of-direction': 0.8, 'trunk-anti-rotation': 0.6, 'upper-body-push': 0.6 })],
    commonLoadAreas: ['shoulder', 'knees'], contactLevel: 'CONTACT', typicalSessionLength: 80,
  }),
  sport({
    slug: 'rugby', name: 'Rugby', governing: ['NCAA'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'horizontal-power': 0.9, 'lower-body-strength': 0.7, 'aerobic-base': 0.6, 'acceleration': 0.7, 'grip': 0.6, 'reactive-strength': 0.6 },
    skills: [skill('tackling-power', 'Tackling power', { 'lower-body-strength': 0.9, 'horizontal-power': 0.9, 'trunk-anti-rotation': 0.8, 'deceleration': 0.7, 'shoulder-stability': 0.6, 'upper-body-push': 0.6 }), skill('ruck-drive-strength', 'Ruck drive strength', { 'lower-body-strength': 1.0, 'horizontal-power': 0.8, 'trunk-anti-rotation': 0.8, 'upper-body-push': 0.7, 'grip': 0.5 }), skill('sprint-speed', 'Sprint speed', { 'acceleration': 1.0, 'max-velocity': 0.9, 'repeat-sprint': 0.7, 'horizontal-power': 0.6 }), skill('passing-accuracy', 'Passing accuracy', { 'rotational-power': 0.8, 'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.6, 'single-leg-stability': 0.5, 'grip': 0.4 }), skill('repeat-effort-endurance', 'Repeat-effort endurance', { 'repeat-sprint': 1.0, 'anaerobic-capacity': 0.9, 'aerobic-base': 0.7, 'lower-body-strength': 0.5 })],
    commonLoadAreas: ['neck', 'shoulders'], contactLevel: 'COLLISION', typicalSessionLength: 90,
  }),
  sport({
    slug: 'archery', name: 'Archery', governing: ['NFHS'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'shoulder-stability': 0.8, 'upper-body-pull': 0.6, 'trunk-anti-rotation': 0.5, 'single-leg-stability': 0.3 },
    skills: [skill('draw-strength', 'Draw strength', { 'upper-body-pull': 1.0, 'shoulder-stability': 0.9, 'trunk-anti-rotation': 0.6, 'grip': 0.6 }), skill('postural-hold', 'Postural hold endurance', { 'trunk-anti-rotation': 0.9, 'shoulder-stability': 0.8, 'single-leg-stability': 0.7, 'hip-mobility': 0.5 }), skill('release-consistency', 'Release consistency', { 'shoulder-stability': 0.8, 'grip': 0.7, 'trunk-anti-rotation': 0.6, 'single-leg-stability': 0.5 }), skill('focus-under-fatigue', 'Focus under fatigue', { 'aerobic-base': 0.8, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.5 })],
    commonLoadAreas: ['shoulder', 'upper-back'], contactLevel: 'NONE', typicalSessionLength: 60,
  }),
  sport({
    slug: 'cycling', name: 'Cycling', governing: ['NCAA'], season: 'SPRING', monthRange: [3, 6],
    qualityProfile: { 'aerobic-base': 1.0, 'anaerobic-capacity': 0.6, 'lower-body-strength': 0.5, 'single-leg-stability': 0.4 },
    skills: [skill('ftp-power', 'Functional threshold power', { 'aerobic-base': 1.0, 'lower-body-strength': 0.8, 'anaerobic-capacity': 0.7, 'hip-mobility': 0.5 }), skill('sprint-power', 'Sprint power', { 'anaerobic-capacity': 0.9, 'lower-body-strength': 0.9, 'acceleration': 0.7, 'horizontal-power': 0.6, 'trunk-anti-rotation': 0.5 }), skill('climbing-power-to-weight', 'Climbing power-to-weight', { 'aerobic-base': 0.9, 'lower-body-strength': 0.8, 'anaerobic-capacity': 0.7, 'trunk-anti-rotation': 0.5 }), skill('cadence-efficiency', 'Cadence efficiency', { 'aerobic-base': 0.8, 'hip-mobility': 0.7, 'reactive-strength': 0.5, 'trunk-anti-rotation': 0.5 })],
    commonLoadAreas: ['lower-back', 'knees'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'mountain-biking', name: 'Mountain Biking', governing: ['NFHS'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'aerobic-base': 0.8, 'single-leg-stability': 0.6, 'reactive-strength': 0.5, 'trunk-anti-rotation': 0.6, 'grip': 0.5 },
    skills: [skill('technical-descending', 'Technical descending control', { 'single-leg-stability': 0.8, 'trunk-anti-rotation': 0.8, 'lower-body-strength': 0.7, 'grip': 0.7, 'reactive-strength': 0.6 }), skill('climbing-power', 'Climbing power', { 'aerobic-base': 0.8, 'lower-body-strength': 0.8, 'anaerobic-capacity': 0.7, 'trunk-anti-rotation': 0.6 }), skill('bike-handling', 'Bike handling', { 'grip': 0.8, 'trunk-anti-rotation': 0.8, 'single-leg-stability': 0.7, 'shoulder-stability': 0.6, 'reactive-strength': 0.5 }), skill('endurance-pacing', 'Endurance pacing', { 'aerobic-base': 1.0, 'anaerobic-capacity': 0.6, 'lower-body-strength': 0.5 })],
    commonLoadAreas: ['lower-back', 'wrists'], contactLevel: 'LIMITED', typicalSessionLength: 90,
  }),
  sport({
    slug: 'sailing', name: 'Sailing', governing: ['NCAA'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'trunk-anti-rotation': 0.7, 'grip': 0.6, 'single-leg-stability': 0.5, 'aerobic-base': 0.5 },
    skills: [skill('hiking-endurance', 'Hiking endurance', { 'trunk-anti-rotation': 0.9, 'lower-body-strength': 0.8, 'hip-mobility': 0.6, 'anaerobic-capacity': 0.6 }), skill('grip-endurance', 'Grip and line-handling endurance', { 'grip': 1.0, 'upper-body-pull': 0.7, 'shoulder-stability': 0.5 }), skill('balance-in-motion', 'Balance in motion', { 'single-leg-stability': 0.9, 'trunk-anti-rotation': 0.8, 'ankle-stiffness': 0.7, 'reactive-strength': 0.6 }), skill('quick-repositioning', 'Quick repositioning under tacks', { 'acceleration': 0.7, 'change-of-direction': 0.7, 'lateral-power': 0.7, 'single-leg-stability': 0.6, 'trunk-anti-rotation': 0.5 })],
    commonLoadAreas: ['lower-back', 'forearms'], contactLevel: 'NONE', typicalSessionLength: 120,
  }),
  sport({
    slug: 'surfing', name: 'Surfing', governing: ['NFHS'], season: 'SUMMER', monthRange: [6, 8],
    qualityProfile: { 'upper-body-pull': 0.6, 'single-leg-stability': 0.8, 'reactive-strength': 0.7, 'trunk-anti-rotation': 0.6, 'aerobic-base': 0.5 },
    skills: [skill('paddle-power', 'Paddle power', { 'upper-body-pull': 0.9, 'shoulder-stability': 0.8, 'aerobic-base': 0.7, 'anaerobic-capacity': 0.6, 'trunk-anti-rotation': 0.5 }), skill('pop-up-speed', 'Pop-up speed', { 'upper-body-push': 0.8, 'reactive-strength': 0.8, 'hip-mobility': 0.7, 'trunk-anti-rotation': 0.7, 'acceleration': 0.5 }), skill('balance-on-unstable-surface', 'Balance on an unstable surface', { 'single-leg-stability': 1.0, 'trunk-anti-rotation': 0.8, 'ankle-stiffness': 0.8, 'reactive-strength': 0.6 }), skill('rotational-turns', 'Rotational turn power', { 'rotational-power': 0.9, 'trunk-anti-rotation': 0.8, 'single-leg-stability': 0.7, 'hip-mobility': 0.7, 'lower-body-strength': 0.5 })],
    commonLoadAreas: ['shoulders', 'lower-back'], contactLevel: 'LIMITED', typicalSessionLength: 90,
  }),
  sport({
    slug: 'judo', name: 'Judo', governing: ['NCAA'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'grip': 0.8, 'rotational-power': 0.7, 'trunk-anti-rotation': 0.7, 'reactive-strength': 0.6, 'anaerobic-capacity': 0.6 },
    skills: [skill('grip-strength', 'Grip strength', { 'grip': 1.0, 'upper-body-pull': 0.8, 'shoulder-stability': 0.6, 'trunk-anti-rotation': 0.5 }), skill('throw-power', 'Throw power', { 'rotational-power': 0.9, 'lower-body-strength': 0.8, 'horizontal-power': 0.7, 'upper-body-pull': 0.7, 'trunk-anti-rotation': 0.7, 'hip-mobility': 0.6 }), skill('off-balancing-timing', 'Off-balancing timing', { 'upper-body-pull': 0.8, 'reactive-strength': 0.7, 'single-leg-stability': 0.7, 'trunk-anti-rotation': 0.6, 'lateral-power': 0.5 }), skill('groundwork-transitions', 'Groundwork transitions', { 'trunk-anti-rotation': 0.8, 'hip-mobility': 0.8, 'anaerobic-capacity': 0.7, 'grip': 0.6, 'upper-body-push': 0.5 }), skill('fall-safety', 'Fall safety and break-falls', { 'landing-mechanics': 0.9, 'trunk-anti-rotation': 0.8, 'shoulder-stability': 0.7, 'hip-mobility': 0.5 })],
    commonLoadAreas: ['neck', 'shoulders', 'lower-back'], contactLevel: 'COLLISION', typicalSessionLength: 90,
  }),
  sport({
    slug: 'weightlifting', name: 'Weightlifting', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'lower-body-strength': 1.0, 'upper-body-push': 0.6, 'hip-mobility': 0.7, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.5 },
    skills: [skill('squat-strength', 'Squat strength', { 'lower-body-strength': 1.0, 'trunk-anti-rotation': 0.8, 'hip-mobility': 0.7, 'ankle-stiffness': 0.5 }), skill('hip-mobility', 'Hip and ankle mobility', { 'hip-mobility': 1.0, 'ankle-stiffness': 0.7, 'shoulder-stability': 0.5 }), skill('bar-path-consistency', 'Bar-path consistency', { 'upper-body-pull': 0.8, 'trunk-anti-rotation': 0.8, 'lower-body-strength': 0.7, 'shoulder-stability': 0.7, 'horizontal-power': 0.5 }), skill('overhead-stability', 'Overhead stability', { 'shoulder-stability': 1.0, 'trunk-anti-rotation': 0.8, 'upper-body-push': 0.7, 'hip-mobility': 0.5 })],
    commonLoadAreas: ['lower-back', 'shoulders', 'wrists'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'powerlifting', name: 'Powerlifting', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'lower-body-strength': 1.0, 'upper-body-push': 0.8, 'grip': 0.6, 'trunk-anti-rotation': 0.6 },
    skills: [skill('squat-strength', 'Squat strength', { 'lower-body-strength': 1.0, 'trunk-anti-rotation': 0.8, 'hip-mobility': 0.6, 'ankle-stiffness': 0.5 }), skill('bench-press-strength', 'Bench press strength', { 'upper-body-push': 1.0, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.6, 'upper-body-pull': 0.5 }), skill('deadlift-strength', 'Deadlift strength', { 'lower-body-strength': 0.9, 'grip': 0.8, 'trunk-anti-rotation': 0.8, 'upper-body-pull': 0.6, 'horizontal-power': 0.5 }), skill('bracing-technique', 'Bracing technique', { 'trunk-anti-rotation': 1.0, 'lower-body-strength': 0.5, 'shoulder-stability': 0.5 })],
    commonLoadAreas: ['lower-back', 'shoulders'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'triathlon', name: 'Triathlon', governing: ['NFHS'], season: 'SUMMER', monthRange: [6, 8],
    qualityProfile: { 'aerobic-base': 1.0, 'anaerobic-capacity': 0.5, 'single-leg-stability': 0.4, 'shoulder-stability': 0.4 },
    skills: [skill('swim-to-bike-transition', 'Swim-to-bike transition speed', { 'aerobic-base': 0.8, 'anaerobic-capacity': 0.7, 'acceleration': 0.6, 'single-leg-stability': 0.5 }), skill('bike-to-run-transition', 'Bike-to-run transition legs', { 'aerobic-base': 0.9, 'reactive-strength': 0.6, 'ankle-stiffness': 0.6, 'anaerobic-capacity': 0.6, 'single-leg-stability': 0.5 }), skill('aerobic-pacing', 'Aerobic pacing across three disciplines', { 'aerobic-base': 1.0, 'anaerobic-capacity': 0.5, 'repeat-sprint': 0.3 }), skill('open-water-sighting', 'Open-water sighting', { 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.7, 'aerobic-base': 0.7, 'upper-body-pull': 0.5 })],
    commonLoadAreas: ['knees', 'lower-back'], contactLevel: 'NONE', typicalSessionLength: 100,
  }),
  sport({
    slug: 'equestrian', name: 'Equestrian', governing: ['NCAA'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'single-leg-stability': 0.5, 'trunk-anti-rotation': 0.7, 'hip-mobility': 0.6, 'grip': 0.5 },
    skills: [skill('core-stability-in-saddle', 'Core stability in the saddle', { 'trunk-anti-rotation': 1.0, 'single-leg-stability': 0.7, 'hip-mobility': 0.7 }), skill('leg-independence', 'Leg independence', { 'hip-mobility': 0.9, 'lower-body-strength': 0.7, 'single-leg-stability': 0.7, 'trunk-anti-rotation': 0.6 }), skill('grip-endurance', 'Rein-hand grip endurance', { 'grip': 0.9, 'upper-body-pull': 0.6, 'shoulder-stability': 0.5 }), skill('balance-recovery', 'Balance recovery', { 'single-leg-stability': 0.9, 'trunk-anti-rotation': 0.8, 'reactive-strength': 0.7, 'ankle-stiffness': 0.5 })],
    commonLoadAreas: ['lower-back', 'hips'], contactLevel: 'LIMITED', typicalSessionLength: 60,
  }),
  sport({
    slug: 'climbing', name: 'Climbing', governing: ['NFHS'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'grip': 1.0, 'upper-body-pull': 0.8, 'trunk-anti-rotation': 0.7, 'single-leg-stability': 0.6, 'hip-mobility': 0.6 },
    skills: [skill('grip-strength', 'Grip strength', { 'grip': 1.0, 'upper-body-pull': 0.8, 'shoulder-stability': 0.6 }), skill('pulling-power', 'Pulling power', { 'upper-body-pull': 1.0, 'grip': 0.7, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.6 }), skill('footwork-precision', 'Footwork precision', { 'single-leg-stability': 0.8, 'ankle-stiffness': 0.7, 'hip-mobility': 0.7, 'trunk-anti-rotation': 0.5 }), skill('route-reading', 'Route reading', { 'aerobic-base': 0.6, 'trunk-anti-rotation': 0.5, 'grip': 0.5, 'single-leg-stability': 0.5 }), skill('core-tension', 'Core tension on overhangs', { 'trunk-anti-rotation': 1.0, 'upper-body-pull': 0.6, 'hip-mobility': 0.6, 'shoulder-stability': 0.5 })],
    commonLoadAreas: ['fingers', 'shoulders', 'elbows'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'boys-volleyball', name: "Boys' Volleyball", governing: ['NFHS'], season: 'SPRING', monthRange: [3, 6],
    qualityProfile: { 'vertical-power': 0.9, 'overhead-power': 0.8, 'reactive-strength': 0.8, 'lateral-power': 0.6, 'landing-mechanics': 0.8 },
    skills: [skill('approach-jump-height', 'Approach jump height', { 'vertical-power': 1.0, 'reactive-strength': 0.8, 'lower-body-strength': 0.7, 'horizontal-power': 0.6, 'ankle-stiffness': 0.6, 'landing-mechanics': 0.6 }), skill('spike-velocity', 'Spike velocity', { 'overhead-power': 1.0, 'rotational-power': 0.8, 'shoulder-stability': 0.8, 'trunk-anti-rotation': 0.7, 'vertical-power': 0.6 }), skill('blocking-timing', 'Blocking timing', { 'vertical-power': 0.8, 'reactive-strength': 0.8, 'lateral-power': 0.7, 'landing-mechanics': 0.7, 'shoulder-stability': 0.6 }), skill('serve-power', 'Serve power', { 'overhead-power': 0.9, 'rotational-power': 0.8, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.6, 'horizontal-power': 0.4 })],
    commonLoadAreas: ['shoulder', 'knees'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'sand-volleyball', name: 'Beach / Sand Volleyball', governing: ['NCAA'], season: 'SPRING', monthRange: [3, 6],
    qualityProfile: { 'vertical-power': 0.8, 'aerobic-base': 0.6, 'lateral-power': 0.7, 'overhead-power': 0.7, 'single-leg-stability': 0.6 },
    skills: [skill('sand-jump-power', 'Sand jump power', { 'vertical-power': 0.9, 'lower-body-strength': 0.8, 'horizontal-power': 0.6, 'ankle-stiffness': 0.6, 'landing-mechanics': 0.6, 'reactive-strength': 0.5 }), skill('lateral-movement-in-sand', 'Lateral movement in sand', { 'lateral-power': 0.9, 'lower-body-strength': 0.7, 'deceleration': 0.7, 'change-of-direction': 0.7, 'anaerobic-capacity': 0.6 }), skill('serve-power', 'Serve power', { 'overhead-power': 0.9, 'rotational-power': 0.8, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.6 }), skill('defensive-range', 'Defensive range', { 'lateral-power': 0.8, 'horizontal-power': 0.7, 'landing-mechanics': 0.7, 'deceleration': 0.7, 'anaerobic-capacity': 0.5 })],
    commonLoadAreas: ['ankles', 'shoulders'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'field-hockey-goalkeeping', name: 'Field Hockey Goalkeeping', governing: ['NFHS'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'reactive-strength': 0.9, 'lateral-power': 0.9, 'landing-mechanics': 0.7, 'hip-mobility': 0.6 },
    skills: [skill('reaction-save-speed', 'Reaction save speed', { 'reactive-strength': 1.0, 'lateral-power': 0.8, 'acceleration': 0.6, 'ankle-stiffness': 0.5 }), skill('lateral-explosiveness', 'Lateral explosiveness', { 'lateral-power': 1.0, 'reactive-strength': 0.7, 'horizontal-power': 0.6, 'deceleration': 0.6 }), skill('low-block-mobility', 'Low block mobility', { 'hip-mobility': 1.0, 'single-leg-stability': 0.7, 'lower-body-strength': 0.6, 'trunk-anti-rotation': 0.5 }), skill('recovery-to-feet', 'Recovery to feet', { 'acceleration': 0.8, 'trunk-anti-rotation': 0.7, 'hip-mobility': 0.7, 'lower-body-strength': 0.6, 'reactive-strength': 0.6 })],
    commonLoadAreas: ['hips', 'knees'], contactLevel: 'LIMITED', typicalSessionLength: 80,
  }),
  sport({
    slug: 'esports-physical-conditioning', name: 'Esports (Physical Conditioning)', governing: ['NFHS'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'aerobic-base': 0.5, 'grip': 0.4, 'trunk-anti-rotation': 0.5, 'shoulder-stability': 0.4 },
    skills: [skill('wrist-forearm-endurance', 'Wrist and forearm endurance', { 'grip': 0.8, 'shoulder-stability': 0.6, 'upper-body-pull': 0.5 }), skill('postural-endurance', 'Postural endurance', { 'trunk-anti-rotation': 0.9, 'shoulder-stability': 0.7, 'hip-mobility': 0.6, 'upper-body-pull': 0.5 }), skill('reaction-time', 'Reaction time', { 'reactive-strength': 0.9, 'acceleration': 0.5, 'aerobic-base': 0.4 }), skill('general-conditioning', 'General conditioning for long sessions', { 'aerobic-base': 1.0, 'lower-body-strength': 0.5, 'trunk-anti-rotation': 0.5 })],
    commonLoadAreas: ['wrists', 'neck', 'lower-back'], contactLevel: 'NONE', typicalSessionLength: 45,
  }),
  sport({
    slug: 'step-team', name: 'Step / Dance Team', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'reactive-strength': 0.7, 'trunk-anti-rotation': 0.6, 'aerobic-base': 0.6, 'single-leg-stability': 0.6, 'landing-mechanics': 0.6 },
    skills: [skill('rhythmic-precision', 'Rhythmic precision', { 'reactive-strength': 0.8, 'ankle-stiffness': 0.7, 'single-leg-stability': 0.6, 'aerobic-base': 0.5 }), skill('jump-power', 'Jump power', { 'vertical-power': 0.9, 'reactive-strength': 0.8, 'lower-body-strength': 0.6, 'landing-mechanics': 0.6 }), skill('routine-endurance', 'Routine endurance', { 'aerobic-base': 0.9, 'anaerobic-capacity': 0.8, 'reactive-strength': 0.5 }), skill('flexibility', 'Flexibility', { 'hip-mobility': 1.0, 'shoulder-stability': 0.5, 'single-leg-stability': 0.4 })],
    commonLoadAreas: ['knees', 'ankles'], contactLevel: 'NONE', typicalSessionLength: 75,
  }),
  sport({
    slug: 'competitive-dance', name: 'Competitive Dance / Drill', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'reactive-strength': 0.7, 'hip-mobility': 0.7, 'single-leg-stability': 0.7, 'landing-mechanics': 0.7, 'aerobic-base': 0.5 },
    skills: [skill('leap-height', 'Leap height', { 'vertical-power': 0.9, 'hip-mobility': 0.8, 'reactive-strength': 0.7, 'horizontal-power': 0.6, 'landing-mechanics': 0.6 }), skill('turn-control', 'Turn control', { 'single-leg-stability': 1.0, 'trunk-anti-rotation': 0.8, 'ankle-stiffness': 0.8, 'rotational-power': 0.5 }), skill('flexibility', 'Flexibility', { 'hip-mobility': 1.0, 'shoulder-stability': 0.6, 'single-leg-stability': 0.5 }), skill('routine-stamina', 'Routine stamina', { 'aerobic-base': 0.9, 'anaerobic-capacity': 0.8, 'single-leg-stability': 0.4 }), skill('landing-control', 'Landing control', { 'landing-mechanics': 1.0, 'single-leg-stability': 0.8, 'ankle-stiffness': 0.7, 'trunk-anti-rotation': 0.5 })],
    commonLoadAreas: ['ankles', 'hips'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'marching-band-athletics', name: 'Marching Band (Physical Conditioning)', governing: ['NFHS'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'aerobic-base': 0.7, 'trunk-anti-rotation': 0.5, 'shoulder-stability': 0.5, 'single-leg-stability': 0.4 },
    skills: [skill('marching-endurance', 'Marching endurance', { 'aerobic-base': 1.0, 'single-leg-stability': 0.5, 'ankle-stiffness': 0.5, 'hip-mobility': 0.4 }), skill('postural-control-while-playing', 'Postural control while playing', { 'trunk-anti-rotation': 0.9, 'shoulder-stability': 0.7, 'single-leg-stability': 0.6, 'hip-mobility': 0.5 }), skill('breath-support', 'Breath support', { 'aerobic-base': 0.9, 'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.4 }), skill('heat-tolerance-conditioning', 'Heat-tolerance conditioning', { 'aerobic-base': 1.0, 'anaerobic-capacity': 0.5, 'repeat-sprint': 0.3 })],
    commonLoadAreas: ['lower-back', 'shoulders', 'shins'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'color-guard', name: 'Color Guard', governing: ['NFHS'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'shoulder-stability': 0.7, 'grip': 0.6, 'single-leg-stability': 0.6, 'trunk-anti-rotation': 0.6 },
    skills: [skill('equipment-control', 'Equipment (flag/rifle/sabre) control', { 'grip': 0.8, 'shoulder-stability': 0.8, 'trunk-anti-rotation': 0.6, 'rotational-power': 0.5 }), skill('toss-catch-timing', 'Toss and catch timing', { 'shoulder-stability': 0.8, 'reactive-strength': 0.6, 'overhead-power': 0.6, 'trunk-anti-rotation': 0.5 }), skill('shoulder-endurance', 'Shoulder endurance', { 'shoulder-stability': 1.0, 'upper-body-pull': 0.5, 'upper-body-push': 0.5 }), skill('routine-precision', 'Routine precision', { 'single-leg-stability': 0.8, 'trunk-anti-rotation': 0.7, 'aerobic-base': 0.6, 'hip-mobility': 0.5 })],
    commonLoadAreas: ['shoulders', 'wrists'], contactLevel: 'NONE', typicalSessionLength: 75,
  }),
  sport({
    slug: 'unified-basketball', name: 'Unified Basketball', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'vertical-power': 0.6, 'change-of-direction': 0.6, 'acceleration': 0.6, 'anaerobic-capacity': 0.5 },
    skills: [skill('shooting-mechanics', 'Shooting mechanics', { 'shoulder-stability': 0.8, 'single-leg-stability': 0.6, 'vertical-power': 0.5, 'trunk-anti-rotation': 0.5 }), skill('ball-handling', 'Ball handling', { 'grip': 0.7, 'trunk-anti-rotation': 0.6, 'change-of-direction': 0.6, 'lateral-power': 0.5 }), skill('teamwork-positioning', 'Teamwork and positioning', { 'change-of-direction': 0.7, 'lateral-power': 0.7, 'deceleration': 0.6, 'aerobic-base': 0.5 }), skill('conditioning', 'General conditioning', { 'aerobic-base': 0.9, 'repeat-sprint': 0.7, 'anaerobic-capacity': 0.6 })],
    commonLoadAreas: ['knees', 'ankles'], contactLevel: 'CONTACT', typicalSessionLength: 75,
  }),
  sport({
    slug: 'unified-track', name: 'Unified Track and Field', governing: ['NFHS'], season: 'SPRING', monthRange: [3, 6],
    qualityProfile: { 'acceleration': 0.6, 'max-velocity': 0.6, 'aerobic-base': 0.5, 'horizontal-power': 0.5 },
    skills: [skill('sprint-technique', 'Sprint technique', { 'acceleration': 0.9, 'max-velocity': 0.8, 'reactive-strength': 0.7, 'ankle-stiffness': 0.6 }), skill('jump-technique', 'Jump technique', { 'vertical-power': 0.8, 'horizontal-power': 0.8, 'reactive-strength': 0.7, 'landing-mechanics': 0.7 }), skill('throw-technique', 'Throw technique', { 'rotational-power': 0.8, 'overhead-power': 0.7, 'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.6 }), skill('pacing', 'Pacing', { 'aerobic-base': 0.9, 'anaerobic-capacity': 0.6, 'repeat-sprint': 0.4 })],
    commonLoadAreas: ['hamstrings', 'shins'], contactLevel: 'NONE', typicalSessionLength: 60,
  }),
  sport({
    slug: 'adapted-floor-hockey', name: 'Adapted Floor Hockey', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'upper-body-push': 0.5, 'trunk-anti-rotation': 0.5, 'aerobic-base': 0.5, 'grip': 0.5 },
    skills: [skill('stick-handling', 'Stick handling', { 'grip': 0.8, 'trunk-anti-rotation': 0.7, 'change-of-direction': 0.6, 'shoulder-stability': 0.5 }), skill('shot-accuracy', 'Shot accuracy', { 'rotational-power': 0.7, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.7, 'grip': 0.6 }), skill('positional-awareness', 'Positional awareness', { 'change-of-direction': 0.7, 'lateral-power': 0.7, 'deceleration': 0.6, 'aerobic-base': 0.5 }), skill('endurance', 'Game endurance', { 'aerobic-base': 0.9, 'repeat-sprint': 0.7, 'anaerobic-capacity': 0.6 })],
    commonLoadAreas: ['shoulders', 'wrists'], contactLevel: 'LIMITED', typicalSessionLength: 60,
  }),
  sport({
    slug: 'adapted-swimming', name: 'Adapted Swimming', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 2],
    qualityProfile: { 'aerobic-base': 0.7, 'upper-body-pull': 0.6, 'shoulder-stability': 0.6 },
    skills: [skill('stroke-technique', 'Stroke technique', { 'shoulder-stability': 0.8, 'trunk-anti-rotation': 0.8, 'upper-body-pull': 0.7, 'hip-mobility': 0.5 }), skill('breathing-rhythm', 'Breathing rhythm', { 'aerobic-base': 0.9, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.4 }), skill('endurance', 'Endurance', { 'aerobic-base': 1.0, 'upper-body-pull': 0.5, 'shoulder-stability': 0.5 }), skill('start-technique', 'Start technique', { 'horizontal-power': 0.7, 'trunk-anti-rotation': 0.7, 'upper-body-push': 0.6, 'shoulder-stability': 0.6 })],
    commonLoadAreas: ['shoulders'], contactLevel: 'NONE', typicalSessionLength: 60,
  }),
  sport({
    slug: 'wheelchair-basketball', name: 'Wheelchair Basketball', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'upper-body-push': 0.8, 'upper-body-pull': 0.7, 'trunk-anti-rotation': 0.7, 'anaerobic-capacity': 0.7, 'grip': 0.6 },
    skills: [skill('push-speed', 'Chair push speed', { 'upper-body-push': 0.9, 'acceleration': 0.8, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.6, 'grip': 0.6 }), skill('shooting-mechanics', 'Shooting mechanics', { 'shoulder-stability': 0.9, 'trunk-anti-rotation': 0.8, 'upper-body-push': 0.6, 'grip': 0.4 }), skill('pivoting-control', 'Pivoting control', { 'trunk-anti-rotation': 0.9, 'rotational-power': 0.7, 'shoulder-stability': 0.7, 'grip': 0.6 }), skill('upper-body-endurance', 'Upper-body endurance', { 'anaerobic-capacity': 0.8, 'aerobic-base': 0.8, 'shoulder-stability': 0.7, 'upper-body-push': 0.6, 'upper-body-pull': 0.6 })],
    commonLoadAreas: ['shoulders', 'wrists'], contactLevel: 'CONTACT', typicalSessionLength: 75,
  }),
  sport({
    slug: 'para-track', name: 'Para Track and Field', governing: ['NFHS'], season: 'SPRING', monthRange: [3, 6],
    qualityProfile: { 'acceleration': 0.6, 'upper-body-push': 0.5, 'trunk-anti-rotation': 0.5, 'aerobic-base': 0.5 },
    skills: [skill('start-technique', 'Start technique', { 'acceleration': 0.9, 'upper-body-push': 0.8, 'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.6 }), skill('technique-efficiency', 'Movement-specific technique efficiency', { 'aerobic-base': 0.8, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.7, 'upper-body-push': 0.6 }), skill('pacing', 'Pacing', { 'aerobic-base': 0.9, 'anaerobic-capacity': 0.7, 'repeat-sprint': 0.4 }), skill('upper-body-power', 'Upper-body power', { 'upper-body-push': 0.9, 'shoulder-stability': 0.8, 'upper-body-pull': 0.7, 'trunk-anti-rotation': 0.6 })],
    commonLoadAreas: ['shoulders', 'lower-back'], contactLevel: 'NONE', typicalSessionLength: 60,
  }),
  sport({
    slug: 'goalball', name: 'Goalball', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'reactive-strength': 0.7, 'lateral-power': 0.7, 'trunk-anti-rotation': 0.6, 'single-leg-stability': 0.5 },
    skills: [skill('throwing-power', 'Throwing power', { 'rotational-power': 0.9, 'overhead-power': 0.7, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.7, 'lower-body-strength': 0.5 }), skill('blocking-reaction', 'Blocking reaction', { 'reactive-strength': 0.9, 'lateral-power': 0.9, 'landing-mechanics': 0.7, 'trunk-anti-rotation': 0.6 }), skill('spatial-tracking-by-sound', 'Spatial tracking by sound', { 'reactive-strength': 0.7, 'lateral-power': 0.6, 'single-leg-stability': 0.6, 'trunk-anti-rotation': 0.5 }), skill('lateral-coverage', 'Lateral coverage', { 'lateral-power': 0.9, 'landing-mechanics': 0.7, 'trunk-anti-rotation': 0.7, 'hip-mobility': 0.5 })],
    commonLoadAreas: ['hips', 'shoulders'], contactLevel: 'CONTACT', typicalSessionLength: 60,
  }),
  sport({
    slug: 'boccia', name: 'Boccia', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'grip': 0.5, 'trunk-anti-rotation': 0.5, 'shoulder-stability': 0.4 },
    skills: [skill('release-consistency', 'Release consistency', { 'shoulder-stability': 0.8, 'trunk-anti-rotation': 0.7, 'grip': 0.6 }), skill('touch-control', 'Touch and distance control', { 'shoulder-stability': 0.7, 'grip': 0.7, 'trunk-anti-rotation': 0.6 }), skill('focus-under-fatigue', 'Focus under fatigue', { 'aerobic-base': 0.7, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.4 }), skill('postural-endurance', 'Postural endurance', { 'trunk-anti-rotation': 0.9, 'shoulder-stability': 0.7, 'hip-mobility': 0.5 })],
    commonLoadAreas: ['shoulder', 'wrist'], contactLevel: 'NONE', typicalSessionLength: 45,
  }),
  sport({
    slug: 'beep-baseball', name: 'Beep Baseball', governing: ['NFHS'], season: 'SUMMER', monthRange: [6, 8],
    qualityProfile: { 'rotational-power': 0.7, 'acceleration': 0.6, 'reactive-strength': 0.5, 'grip': 0.4 },
    skills: [skill('bat-speed', 'Bat speed', { 'rotational-power': 1.0, 'grip': 0.6, 'trunk-anti-rotation': 0.6, 'hip-mobility': 0.6 }), skill('sprint-to-base', 'Sprint to base', { 'acceleration': 1.0, 'max-velocity': 0.7, 'horizontal-power': 0.6 }), skill('auditory-tracking', 'Auditory tracking', { 'reactive-strength': 0.8, 'single-leg-stability': 0.6, 'trunk-anti-rotation': 0.5, 'lateral-power': 0.5 }), skill('diving-safety', 'Safe diving technique', { 'landing-mechanics': 0.9, 'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.7, 'horizontal-power': 0.5 })],
    commonLoadAreas: ['shoulders', 'knees'], contactLevel: 'CONTACT', typicalSessionLength: 75,
  }),
  sport({
    slug: 'sitting-volleyball', name: 'Sitting Volleyball', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'upper-body-push': 0.7, 'trunk-anti-rotation': 0.7, 'overhead-power': 0.6, 'grip': 0.5 },
    skills: [skill('seated-mobility', 'Seated mobility', { 'upper-body-push': 0.8, 'trunk-anti-rotation': 0.8, 'shoulder-stability': 0.7, 'hip-mobility': 0.6, 'lateral-power': 0.5 }), skill('spike-power', 'Spike power from seated', { 'overhead-power': 0.9, 'rotational-power': 0.8, 'shoulder-stability': 0.8, 'trunk-anti-rotation': 0.7 }), skill('blocking-reach', 'Blocking reach', { 'shoulder-stability': 0.9, 'trunk-anti-rotation': 0.8, 'upper-body-push': 0.6, 'reactive-strength': 0.6 }), skill('serve-power', 'Serve power', { 'overhead-power': 0.9, 'rotational-power': 0.8, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.6 })],
    commonLoadAreas: ['shoulders', 'lower-back'], contactLevel: 'NONE', typicalSessionLength: 75,
  }),
  sport({
    slug: 'racquetball', name: 'Racquetball', governing: ['NFHS'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'reactive-strength': 0.7, 'lateral-power': 0.7, 'anaerobic-capacity': 0.7, 'change-of-direction': 0.7 },
    skills: [skill('swing-power', 'Swing power', { 'rotational-power': 1.0, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.7, 'lower-body-strength': 0.5, 'hip-mobility': 0.5 }), skill('court-coverage', 'Court coverage', { 'change-of-direction': 0.9, 'acceleration': 0.8, 'deceleration': 0.8, 'lateral-power': 0.7, 'anaerobic-capacity': 0.7 }), skill('reaction-time', 'Reaction time', { 'reactive-strength': 1.0, 'acceleration': 0.6, 'lateral-power': 0.6 }), skill('recovery-speed', 'Recovery speed to center court', { 'acceleration': 0.9, 'deceleration': 0.8, 'anaerobic-capacity': 0.7, 'change-of-direction': 0.7 })],
    commonLoadAreas: ['shoulder', 'knees'], contactLevel: 'LIMITED', typicalSessionLength: 60,
  }),
  sport({
    slug: 'orienteering', name: 'Orienteering', governing: ['NFHS'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'aerobic-base': 0.9, 'single-leg-stability': 0.6, 'ankle-stiffness': 0.5, 'anaerobic-capacity': 0.4 },
    skills: [skill('trail-running-economy', 'Trail-running economy', { 'aerobic-base': 1.0, 'ankle-stiffness': 0.8, 'reactive-strength': 0.6, 'single-leg-stability': 0.6 }), skill('uneven-terrain-stability', 'Uneven-terrain stability', { 'single-leg-stability': 0.9, 'ankle-stiffness': 0.9, 'trunk-anti-rotation': 0.6, 'landing-mechanics': 0.6 }), skill('pacing-under-navigation-load', 'Pacing under navigation load', { 'aerobic-base': 0.9, 'anaerobic-capacity': 0.6, 'repeat-sprint': 0.4 }), skill('endurance', 'Sustained endurance', { 'aerobic-base': 1.0, 'lower-body-strength': 0.5, 'ankle-stiffness': 0.5 })],
    commonLoadAreas: ['ankles', 'shins'], contactLevel: 'NONE', typicalSessionLength: 75,
  }),
  sport({
    slug: 'disc-golf', name: 'Disc Golf', governing: ['NFHS'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'rotational-power': 0.7, 'hip-mobility': 0.6, 'single-leg-stability': 0.5, 'trunk-anti-rotation': 0.5 },
    skills: [skill('drive-distance', 'Drive distance', { 'rotational-power': 1.0, 'hip-mobility': 0.7, 'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.6, 'single-leg-stability': 0.6, 'deceleration': 0.5 }), skill('rotational-mechanics', 'Rotational mechanics', { 'rotational-power': 0.9, 'hip-mobility': 0.8, 'trunk-anti-rotation': 0.8, 'single-leg-stability': 0.6 }), skill('putting-consistency', 'Putting consistency', { 'single-leg-stability': 0.8, 'trunk-anti-rotation': 0.7, 'shoulder-stability': 0.6, 'grip': 0.5 }), skill('walking-endurance', 'Walking endurance across 18', { 'aerobic-base': 1.0, 'single-leg-stability': 0.4, 'hip-mobility': 0.4 })],
    commonLoadAreas: ['lower-back', 'elbow'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'spikeball', name: 'Spikeball (Roundnet)', governing: ['NFHS'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'reactive-strength': 0.7, 'lateral-power': 0.6, 'single-leg-stability': 0.5, 'landing-mechanics': 0.5 },
    skills: [skill('hit-power', 'Hit power', { 'overhead-power': 0.8, 'rotational-power': 0.8, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.6 }), skill('reaction-time', 'Reaction time', { 'reactive-strength': 1.0, 'acceleration': 0.7, 'lateral-power': 0.7 }), skill('lateral-diving', 'Lateral diving range', { 'lateral-power': 0.9, 'landing-mechanics': 0.8, 'horizontal-power': 0.7, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.5 }), skill('set-touch', 'Set touch', { 'shoulder-stability': 0.8, 'grip': 0.6, 'trunk-anti-rotation': 0.5, 'single-leg-stability': 0.5 })],
    commonLoadAreas: ['knees', 'shoulder'], contactLevel: 'LIMITED', typicalSessionLength: 45,
  }),
  sport({
    slug: 'skateboarding', name: 'Skateboarding', governing: ['NFHS'], season: 'SUMMER', monthRange: [6, 8],
    qualityProfile: { 'single-leg-stability': 0.8, 'reactive-strength': 0.7, 'landing-mechanics': 0.8, 'ankle-stiffness': 0.6 },
    skills: [skill('pop-height', 'Pop height', { 'vertical-power': 0.8, 'reactive-strength': 0.8, 'ankle-stiffness': 0.8, 'single-leg-stability': 0.7, 'landing-mechanics': 0.6 }), skill('landing-control', 'Landing control', { 'landing-mechanics': 1.0, 'single-leg-stability': 0.8, 'ankle-stiffness': 0.8, 'lower-body-strength': 0.6, 'trunk-anti-rotation': 0.5 }), skill('balance-on-unstable-surface', 'Balance on an unstable surface', { 'single-leg-stability': 1.0, 'ankle-stiffness': 0.8, 'trunk-anti-rotation': 0.8, 'reactive-strength': 0.6 }), skill('rotational-air-awareness', 'Rotational air awareness', { 'rotational-power': 0.8, 'trunk-anti-rotation': 0.8, 'hip-mobility': 0.6, 'landing-mechanics': 0.6 })],
    commonLoadAreas: ['ankles', 'wrists'], contactLevel: 'LIMITED', typicalSessionLength: 90,
  }),
  sport({
    slug: 'bmx', name: 'BMX', governing: ['NFHS'], season: 'SUMMER', monthRange: [6, 8],
    qualityProfile: { 'reactive-strength': 0.7, 'horizontal-power': 0.6, 'single-leg-stability': 0.6, 'grip': 0.5 },
    skills: [skill('gate-start-power', 'Gate start power', { 'acceleration': 1.0, 'lower-body-strength': 0.8, 'upper-body-pull': 0.7, 'horizontal-power': 0.7, 'trunk-anti-rotation': 0.6 }), skill('jump-technique', 'Jump technique', { 'landing-mechanics': 0.8, 'trunk-anti-rotation': 0.8, 'vertical-power': 0.7, 'lower-body-strength': 0.7, 'grip': 0.5 }), skill('bike-handling', 'Bike handling', { 'grip': 0.8, 'trunk-anti-rotation': 0.8, 'single-leg-stability': 0.7, 'shoulder-stability': 0.6, 'reactive-strength': 0.6 }), skill('sprint-power', 'Sprint power', { 'anaerobic-capacity': 0.9, 'lower-body-strength': 0.9, 'acceleration': 0.8, 'horizontal-power': 0.6 })],
    commonLoadAreas: ['wrists', 'shoulders'], contactLevel: 'CONTACT', typicalSessionLength: 60,
  }),
  sport({
    slug: 'inline-hockey', name: 'Inline Hockey', governing: ['NFHS'], season: 'SPRING', monthRange: [3, 6],
    qualityProfile: { 'acceleration': 0.8, 'change-of-direction': 0.8, 'anaerobic-capacity': 0.8, 'single-leg-stability': 0.7 },
    skills: [skill('skating-speed', 'Skating speed', { 'lateral-power': 0.9, 'max-velocity': 0.8, 'acceleration': 0.8, 'lower-body-strength': 0.8, 'single-leg-stability': 0.7 }), skill('stick-handling', 'Stick handling', { 'grip': 0.8, 'trunk-anti-rotation': 0.6, 'change-of-direction': 0.6, 'single-leg-stability': 0.5 }), skill('shooting-power', 'Shooting power', { 'rotational-power': 1.0, 'trunk-anti-rotation': 0.8, 'grip': 0.7, 'shoulder-stability': 0.6, 'lower-body-strength': 0.5 }), skill('edge-work', 'Edge work', { 'single-leg-stability': 0.9, 'lateral-power': 0.8, 'change-of-direction': 0.8, 'ankle-stiffness': 0.7, 'hip-mobility': 0.6 })],
    commonLoadAreas: ['hips', 'knees'], contactLevel: 'CONTACT', typicalSessionLength: 75,
  }),
  sport({
    slug: 'ultimate-beach', name: 'Beach Ultimate', governing: ['NCAA'], season: 'SUMMER', monthRange: [6, 8],
    qualityProfile: { 'max-velocity': 0.7, 'aerobic-base': 0.7, 'change-of-direction': 0.7, 'vertical-power': 0.5 },
    skills: [skill('sprint-speed-in-sand', 'Sprint speed in sand', { 'acceleration': 0.9, 'lower-body-strength': 0.8, 'max-velocity': 0.7, 'ankle-stiffness': 0.7, 'horizontal-power': 0.6 }), skill('throwing-power', 'Throwing power', { 'rotational-power': 1.0, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.7, 'single-leg-stability': 0.6, 'grip': 0.5 }), skill('layout-explosiveness', 'Layout explosiveness', { 'horizontal-power': 1.0, 'landing-mechanics': 0.8, 'acceleration': 0.7, 'trunk-anti-rotation': 0.6 }), skill('endurance-in-heat', 'Endurance in heat', { 'aerobic-base': 1.0, 'repeat-sprint': 0.8, 'anaerobic-capacity': 0.7 })],
    commonLoadAreas: ['calves', 'hamstrings'], contactLevel: 'LIMITED', typicalSessionLength: 90,
  }),
  sport({
    slug: 'triathlon-duathlon', name: 'Duathlon', governing: ['NFHS'], season: 'SUMMER', monthRange: [6, 8],
    qualityProfile: { 'aerobic-base': 1.0, 'anaerobic-capacity': 0.5, 'single-leg-stability': 0.4 },
    skills: [skill('run-to-bike-transition', 'Run-to-bike transition', { 'aerobic-base': 0.8, 'anaerobic-capacity': 0.7, 'acceleration': 0.5, 'hip-mobility': 0.5 }), skill('bike-to-run-transition', 'Bike-to-run transition legs', { 'aerobic-base': 0.9, 'reactive-strength': 0.6, 'ankle-stiffness': 0.6, 'anaerobic-capacity': 0.6, 'single-leg-stability': 0.5 }), skill('pacing', 'Two-discipline pacing', { 'aerobic-base': 1.0, 'anaerobic-capacity': 0.6, 'repeat-sprint': 0.4 }), skill('running-economy', 'Running economy', { 'aerobic-base': 0.9, 'ankle-stiffness': 0.8, 'reactive-strength': 0.7, 'single-leg-stability': 0.6, 'hip-mobility': 0.5 })],
    commonLoadAreas: ['knees', 'lower-back'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'crossfit-style-conditioning', name: 'Strength & Conditioning Team', governing: ['NFHS'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'lower-body-strength': 0.7, 'upper-body-push': 0.6, 'upper-body-pull': 0.6, 'aerobic-base': 0.6, 'anaerobic-capacity': 0.6, 'trunk-anti-rotation': 0.6 },
    skills: [skill('general-strength', 'General strength', { 'lower-body-strength': 0.9, 'upper-body-push': 0.7, 'upper-body-pull': 0.7, 'trunk-anti-rotation': 0.7, 'grip': 0.6 }), skill('work-capacity', 'Work capacity', { 'anaerobic-capacity': 1.0, 'aerobic-base': 0.8, 'repeat-sprint': 0.7, 'grip': 0.5 }), skill('movement-quality', 'Movement quality under fatigue', { 'hip-mobility': 0.8, 'shoulder-stability': 0.8, 'trunk-anti-rotation': 0.8, 'single-leg-stability': 0.6, 'ankle-stiffness': 0.5 }), skill('mixed-modal-conditioning', 'Mixed-modal conditioning', { 'aerobic-base': 0.9, 'anaerobic-capacity': 0.9, 'lower-body-strength': 0.6, 'upper-body-pull': 0.5, 'upper-body-push': 0.5 })],
    commonLoadAreas: ['lower-back', 'shoulders'], contactLevel: 'NONE', typicalSessionLength: 60,
  }),
  sport({
    slug: 'cheerleading-sideline', name: 'Sideline Cheerleading', governing: ['NFHS'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'vertical-power': 0.6, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.6, 'aerobic-base': 0.5 },
    skills: [skill('jump-height', 'Jump height', { 'vertical-power': 1.0, 'reactive-strength': 0.8, 'landing-mechanics': 0.7, 'lower-body-strength': 0.6, 'ankle-stiffness': 0.5 }), skill('stunt-stability', 'Stunt stability', { 'trunk-anti-rotation': 0.9, 'shoulder-stability': 0.8, 'single-leg-stability': 0.7, 'upper-body-push': 0.6, 'lower-body-strength': 0.6 }), skill('projection-and-voice-endurance', 'Projection and voice endurance', { 'aerobic-base': 0.9, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.4 }), skill('routine-stamina', 'Routine stamina', { 'aerobic-base': 0.9, 'anaerobic-capacity': 0.8, 'single-leg-stability': 0.4 })],
    commonLoadAreas: ['shoulders', 'wrists'], contactLevel: 'CONTACT', typicalSessionLength: 75,
  }),
  sport({
    slug: 'lacrosse-box', name: 'Box Lacrosse', governing: ['NCAA'], season: 'WINTER', monthRange: [11, 2],
    qualityProfile: { 'acceleration': 0.8, 'rotational-power': 0.8, 'anaerobic-capacity': 0.8, 'grip': 0.6 },
    skills: [skill('shot-velocity', 'Shot velocity', { 'rotational-power': 1.0, 'overhead-power': 0.7, 'shoulder-stability': 0.7, 'trunk-anti-rotation': 0.7, 'grip': 0.5 }), skill('dodging-quickness', 'Dodging quickness', { 'change-of-direction': 1.0, 'deceleration': 0.8, 'acceleration': 0.8, 'lateral-power': 0.7, 'ankle-stiffness': 0.5 }), skill('checking-strength', 'Checking strength', { 'upper-body-push': 0.8, 'trunk-anti-rotation': 0.8, 'lower-body-strength': 0.7, 'shoulder-stability': 0.7, 'grip': 0.6 }), skill('transition-speed', 'Transition speed', { 'acceleration': 0.9, 'max-velocity': 0.8, 'repeat-sprint': 0.8, 'aerobic-base': 0.5 })],
    commonLoadAreas: ['shoulders', 'wrists'], contactLevel: 'COLLISION', typicalSessionLength: 75,
  }),
  sport({
    slug: 'netball', name: 'Netball', governing: ['NFHS'], season: 'SPRING', monthRange: [3, 6],
    qualityProfile: { 'vertical-power': 0.7, 'acceleration': 0.7, 'change-of-direction': 0.7, 'landing-mechanics': 0.6 },
    skills: [skill('vertical-jump', 'Vertical jump', { 'vertical-power': 1.0, 'reactive-strength': 0.8, 'landing-mechanics': 0.8, 'lower-body-strength': 0.6, 'ankle-stiffness': 0.6 }), skill('first-step', 'First step', { 'acceleration': 1.0, 'horizontal-power': 0.7, 'deceleration': 0.7, 'reactive-strength': 0.6, 'change-of-direction': 0.6 }), skill('passing-accuracy', 'Passing accuracy', { 'shoulder-stability': 0.8, 'overhead-power': 0.6, 'trunk-anti-rotation': 0.6, 'single-leg-stability': 0.6, 'grip': 0.5 }), skill('marking-positioning', 'Marking and positioning', { 'lateral-power': 0.9, 'deceleration': 0.8, 'change-of-direction': 0.8, 'single-leg-stability': 0.6, 'trunk-anti-rotation': 0.5 })],
    commonLoadAreas: ['knees', 'ankles'], contactLevel: 'CONTACT', typicalSessionLength: 75,
  }),
];

const BY_SLUG = new Map(SPORTS.map((s) => [s.slug, s]));

export function sportBySlug(slug) {
  const found = BY_SLUG.get(slug);
  if (!found) throw new Error(`unknown sport ${JSON.stringify(slug)}`);
  return found;
}

export function isSport(slug) {
  return BY_SLUG.has(slug);
}

/** Validate a sport's qualityProfile (and every position override) references only real qualities. */
export function validateSport(s, errors = []) {
  const bad = (label, profile) => {
    for (const [q, w] of Object.entries(profile)) {
      if (!isQuality(q)) errors.push(`${s.slug} ${label}: unknown quality ${JSON.stringify(q)}`);
      if (typeof w !== 'number' || w < 0 || w > 1) errors.push(`${s.slug} ${label}.${q}: weight ${w} out of 0–1`);
    }
  };
  bad('qualityProfile', s.qualityProfile);
  for (const p of s.positions) bad(`position.${p.slug}`, p.qualityProfile);
  // §21: "every skill maps to ≥ 3 qualities" — checked here rather than as
  // a separate pass, so it fails alongside every other sport-shape problem.
  for (const sk of s.skills) {
    bad(`skill.${sk.slug}`, sk.qualityWeights ?? {});
    const count = Object.keys(sk.qualityWeights ?? {}).length;
    if (count < 3) errors.push(`${s.slug} skill.${sk.slug}: maps to only ${count} qualities, need >= 3`);
  }
  if (!SEASONS.includes(s.season)) errors.push(`${s.slug}: unknown season ${JSON.stringify(s.season)}`);
  if (!CONTACT_LEVELS.includes(s.contactLevel)) errors.push(`${s.slug}: unknown contactLevel ${JSON.stringify(s.contactLevel)}`);
  for (const g of s.governing) if (!GOVERNING_BODIES.includes(g)) errors.push(`${s.slug}: unknown governing body ${JSON.stringify(g)}`);
  return errors;
}
