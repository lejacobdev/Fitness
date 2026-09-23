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
      skill('throwing-velocity', 'Throwing velocity'), skill('route-running', 'Route running'),
      skill('open-field-tackling', 'Open-field tackling'), skill('block-drive', 'Block drive power'),
      skill('first-step-quickness', 'First-step quickness'), skill('hand-fighting', 'Hand fighting'),
      skill('ball-security', 'Ball security'), skill('lateral-agility', 'Lateral agility'),
      skill('catching-in-traffic', 'Catching in traffic'), skill('kicking-power', 'Kicking power'),
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
      skill('vertical-jump', 'Vertical jump'), skill('first-step', 'First step'),
      skill('shooting-mechanics', 'Shooting mechanics'), skill('ball-handling', 'Ball handling'),
      skill('lateral-quickness', 'Lateral quickness'), skill('finishing-at-rim', 'Finishing at the rim'),
      skill('box-out-strength', 'Box-out strength'), skill('free-throw-consistency', 'Free-throw consistency'),
      skill('change-of-pace', 'Change of pace'), skill('rebounding-timing', 'Rebounding timing'),
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
      skill('throwing-velocity', 'Throwing velocity'), skill('exit-velocity', 'Exit velocity'),
      skill('bat-speed', 'Bat speed'), skill('pitching-mechanics', 'Pitching mechanics'),
      skill('first-step-quickness', 'First-step quickness'), skill('arm-care', 'Arm care and durability'),
      skill('rotational-sequencing', 'Rotational sequencing'), skill('base-running-speed', 'Base-running speed'),
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
      skill('bat-speed', 'Bat speed'), skill('exit-velocity', 'Exit velocity'),
      skill('windmill-pitch-velocity', 'Windmill pitch velocity'), skill('throwing-velocity', 'Throwing velocity'),
      skill('first-step-quickness', 'First-step quickness'), skill('base-running-speed', 'Base-running speed'),
      skill('rotational-sequencing', 'Rotational sequencing'), skill('slap-hitting-speed', 'Slap-hitting speed'),
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
      skill('approach-jump-height', 'Approach jump height'), skill('spike-velocity', 'Spike velocity'),
      skill('blocking-timing', 'Blocking timing'), skill('serve-power', 'Serve power'),
      skill('passing-platform', 'Passing platform control'), skill('lateral-movement', 'Lateral movement'),
      skill('landing-control', 'Landing control'), skill('setting-hands', 'Setting hand quickness'),
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
      skill('aerobic-threshold-pace', 'Aerobic threshold pace'), skill('finishing-kick', 'Finishing kick'),
      skill('hill-running-economy', 'Hill running economy'), skill('running-economy', 'Running economy'),
      skill('pacing-discipline', 'Pacing discipline'), skill('race-tactics', 'Race tactics'),
      skill('recovery-between-hard-days', 'Recovery between hard days'), skill('cadence', 'Cadence and stride efficiency'),
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
      skill('block-start', 'Block start'), skill('max-velocity-mechanics', 'Max velocity mechanics'),
      skill('curve-running', 'Curve running'), skill('jump-takeoff-power', 'Jump takeoff power'),
      skill('throwing-release-speed', 'Throwing release speed'), skill('hurdle-clearance', 'Hurdle clearance'),
      skill('relay-exchange', 'Relay exchange'), skill('pacing-strategy', 'Pacing strategy'),
      skill('approach-consistency', 'Approach consistency'),
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
      skill('takedown-power', 'Takedown power'), skill('sprawl-speed', 'Sprawl speed'),
      skill('grip-strength', 'Grip strength'), skill('hip-explosiveness', 'Hip explosiveness'),
      skill('bridging-strength', 'Bridging strength'), skill('scrambling-endurance', 'Scrambling endurance'),
      skill('weight-cut-management', 'Weight management and fuelling'), skill('mat-awareness', 'Mat awareness'),
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
      skill('serve-velocity', 'Serve velocity'), skill('first-step-to-ball', 'First step to the ball'),
      skill('groundstroke-power', 'Groundstroke power'), skill('lateral-recovery', 'Lateral recovery'),
      skill('overhead-mechanics', 'Overhead mechanics'), skill('court-endurance', 'Court endurance'),
      skill('split-step-timing', 'Split-step timing'), skill('rotational-power-transfer', 'Rotational power transfer'),
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
      skill('clubhead-speed', 'Clubhead speed'), skill('rotational-mobility', 'Rotational mobility'),
      skill('swing-sequencing', 'Swing sequencing'), skill('balance-through-impact', 'Balance through impact'),
      skill('short-game-touch', 'Short-game touch'), skill('walking-endurance', '18-hole walking endurance'),
      skill('core-stability', 'Core stability under rotation'), skill('consistency', 'Swing consistency'),
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
      skill('start-power', 'Start power'), skill('turn-speed', 'Turn speed'),
      skill('stroke-rate', 'Stroke rate'), skill('shoulder-durability', 'Shoulder durability'),
      skill('underwater-dolphin-kick', 'Underwater dolphin kick'), skill('pacing-strategy', 'Pacing strategy'),
      skill('body-position', 'Body position and drag reduction'), skill('entry-technique', 'Diving entry technique'),
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
      skill('shooting-power', 'Shooting power'), skill('skating-speed', 'Skating speed'),
      skill('edge-work', 'Edge work'), skill('puck-handling', 'Puck handling'),
      skill('checking-strength', 'Checking strength'), skill('crossover-acceleration', 'Crossover acceleration'),
      skill('shot-release-quickness', 'Shot release quickness'), skill('shift-endurance', 'Shift endurance'),
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
      skill('drag-flick-power', 'Drag-flick power'), skill('sprint-speed', 'Sprint speed'),
      skill('stick-handling', 'Stick handling'), skill('passing-accuracy', 'Passing accuracy'),
      skill('low-athletic-stance', 'Low athletic stance endurance'), skill('agility', 'Agility and cutting'),
      skill('tackling-timing', 'Tackling timing'), skill('reverse-stick-control', 'Reverse-stick control'),
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
      skill('shot-velocity', 'Shot velocity'), skill('dodging-quickness', 'Dodging quickness'),
      skill('stick-protection', 'Stick protection strength'), skill('ground-ball-speed', 'Ground-ball reaction speed'),
      skill('face-off-power', 'Face-off power'), skill('field-vision', 'Field vision under speed'),
      skill('cradling-under-pressure', 'Cradling under pressure'), skill('transition-speed', 'Transition speed'),
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
      skill('tumbling-power', 'Tumbling power'), skill('stunt-stability', 'Stunt stability'),
      skill('jump-height', 'Jump height'), skill('landing-control', 'Landing control'),
      skill('base-strength', 'Base strength'), skill('flyer-core-control', 'Flyer core control'),
      skill('flexibility', 'Flexibility for kicks and scale positions'), skill('timing-synchronisation', 'Timing and synchronisation'),
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
      skill('sprint-speed', 'Sprint speed'), skill('route-running', 'Route running'),
      skill('flag-pull-reaction', 'Flag-pull reaction'), skill('throwing-accuracy', 'Throwing accuracy'),
      skill('lateral-agility', 'Lateral agility'), skill('change-of-pace', 'Change of pace'),
      skill('one-handed-catching', 'One-handed catching'), skill('deceleration-and-cut', 'Deceleration and cut'),
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
      skill('release-consistency', 'Release consistency'), skill('approach-timing', 'Approach timing'),
      skill('ball-speed-control', 'Ball speed control'), skill('balance-at-foul-line', 'Balance at the foul line'),
      skill('spare-conversion', 'Spare conversion'), skill('wrist-hand-strength', 'Wrist and hand strength'),
      skill('lane-reading', 'Lane reading'), skill('follow-through-consistency', 'Follow-through consistency'),
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
      skill('tumbling-power', 'Tumbling power'), skill('landing-control', 'Landing control'),
      skill('bar-swing-strength', 'Bar swing strength'), skill('beam-balance', 'Beam balance'),
      skill('flexibility', 'Flexibility and splits'), skill('vault-block-power', 'Vault block power'),
      skill('core-hollow-hold', 'Core hollow-body control'), skill('shoulder-durability', 'Shoulder durability'),
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
      skill('shot-velocity', 'Shot velocity'), skill('eggbeater-endurance', 'Eggbeater kick endurance'),
      skill('treading-power', 'Treading power'), skill('passing-accuracy', 'Passing accuracy'),
      skill('sprint-swim-speed', 'Sprint swim speed'), skill('shoulder-durability', 'Shoulder durability'),
      skill('vertical-power-out-of-water', 'Vertical power out of the water'), skill('defensive-positioning-strength', 'Defensive positioning strength'),
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
      skill('power-per-stroke', 'Power per stroke'), skill('stroke-rate-efficiency', 'Stroke-rate efficiency'),
      skill('2k-erg-pace', '2k erg pace'), skill('leg-drive-power', 'Leg-drive power'),
      skill('core-transfer', 'Core-to-oar power transfer'), skill('recovery-timing', 'Recovery-phase timing'),
      skill('boat-feel-timing', 'Boat feel and timing'), skill('sprint-finish-power', 'Sprint finish power'),
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
      skill('edge-control', 'Edge control'), skill('turn-power', 'Turn power'),
      skill('tuck-endurance', 'Aerodynamic tuck endurance'), skill('poling-power', 'Poling power (Nordic)'),
      skill('balance-recovery', 'Balance recovery'), skill('leg-endurance', 'Leg endurance on long runs'),
      skill('start-power', 'Start power'), skill('cornering-precision', 'Cornering precision'),
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
      skill('postural-stability', 'Postural stability'), skill('breath-control', 'Breath control'),
      skill('trigger-consistency', 'Trigger-pull consistency'), skill('positional-endurance', 'Positional endurance (prone/kneeling/standing)'),
      skill('focus-under-fatigue', 'Focus under fatigue'), skill('heart-rate-management', 'Heart-rate management between shots'),
      skill('natural-point-of-aim', 'Natural point of aim'), skill('recoil-management', 'Recoil management'),
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
      skill('lunge-power', 'Lunge power'), skill('advance-retreat-speed', 'Advance-retreat footwork speed'),
      skill('reaction-time', 'Reaction time'), skill('blade-hand-speed', 'Blade hand speed'),
      skill('lower-body-endurance', 'Lower-body endurance in en-garde stance'), skill('distance-judgement', 'Distance judgement'),
      skill('footwork-endurance', 'Footwork endurance'), skill('feint-timing', 'Feint timing'),
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
      skill('sprint-speed', 'Sprint speed'), skill('layout-explosiveness', 'Layout explosiveness'),
      skill('throwing-power', 'Throwing power'), skill('cutting-sharpness', 'Cutting sharpness'),
      skill('vertical-jump-for-discs', 'Vertical jump for contested discs'), skill('endurance-across-points', 'Endurance across points'),
      skill('pivoting-footwork', 'Pivoting footwork'), skill('marking-recovery', 'Marking recovery speed'),
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
    skills: [skill('smash-power', 'Smash power'), skill('footwork-speed', 'Footwork speed'), skill('net-control', 'Net control'), skill('deception', 'Shot deception'), skill('court-coverage-endurance', 'Court coverage endurance')],
    commonLoadAreas: ['shoulder', 'knees'], contactLevel: 'NONE', typicalSessionLength: 60,
  }),
  sport({
    slug: 'table-tennis', name: 'Table Tennis', governing: ['NCAA'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'reactive-strength': 0.7, 'rotational-power': 0.5, 'lateral-power': 0.5, 'grip': 0.4 },
    skills: [skill('paddle-speed', 'Paddle speed'), skill('footwork-quickness', 'Footwork quickness'), skill('spin-generation', 'Spin generation'), skill('reaction-time', 'Reaction time')],
    commonLoadAreas: ['wrist', 'shoulder'], contactLevel: 'NONE', typicalSessionLength: 50,
  }),
  sport({
    slug: 'squash', name: 'Squash', governing: ['NCAA'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'aerobic-base': 0.7, 'anaerobic-capacity': 0.7, 'lateral-power': 0.7, 'single-leg-stability': 0.5, 'change-of-direction': 0.8 },
    skills: [skill('lunge-power', 'Lunge power'), skill('court-speed', 'Court speed'), skill('shot-accuracy', 'Shot accuracy'), skill('recovery-speed', 'Recovery speed to the T')],
    commonLoadAreas: ['knees', 'hip-flexors'], contactLevel: 'LIMITED', typicalSessionLength: 60,
  }),
  sport({
    slug: 'pickleball', name: 'Pickleball', governing: ['NFHS'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'reactive-strength': 0.6, 'lateral-power': 0.6, 'single-leg-stability': 0.4, 'grip': 0.4 },
    skills: [skill('dink-touch', 'Dink touch'), skill('third-shot-drop', 'Third-shot drop consistency'), skill('lateral-quickness', 'Lateral quickness'), skill('reaction-time', 'Net reaction time')],
    commonLoadAreas: ['knees', 'shoulder'], contactLevel: 'NONE', typicalSessionLength: 50,
  }),
  sport({
    slug: 'team-handball', name: 'Team Handball', governing: ['NCAA'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'overhead-power': 0.8, 'acceleration': 0.7, 'rotational-power': 0.7, 'vertical-power': 0.6, 'anaerobic-capacity': 0.6 },
    skills: [skill('throwing-velocity', 'Throwing velocity'), skill('jump-shot-power', 'Jump-shot power'), skill('sprint-speed', 'Sprint speed'), skill('one-v-one-defending', '1v1 defending')],
    commonLoadAreas: ['shoulder', 'knees'], contactLevel: 'CONTACT', typicalSessionLength: 80,
  }),
  sport({
    slug: 'rugby', name: 'Rugby', governing: ['NCAA'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'horizontal-power': 0.9, 'lower-body-strength': 0.7, 'aerobic-base': 0.6, 'acceleration': 0.7, 'grip': 0.6, 'reactive-strength': 0.6 },
    skills: [skill('tackling-power', 'Tackling power'), skill('ruck-drive-strength', 'Ruck drive strength'), skill('sprint-speed', 'Sprint speed'), skill('passing-accuracy', 'Passing accuracy'), skill('repeat-effort-endurance', 'Repeat-effort endurance')],
    commonLoadAreas: ['neck', 'shoulders'], contactLevel: 'COLLISION', typicalSessionLength: 90,
  }),
  sport({
    slug: 'archery', name: 'Archery', governing: ['NFHS'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'shoulder-stability': 0.8, 'upper-body-pull': 0.6, 'trunk-anti-rotation': 0.5, 'single-leg-stability': 0.3 },
    skills: [skill('draw-strength', 'Draw strength'), skill('postural-hold', 'Postural hold endurance'), skill('release-consistency', 'Release consistency'), skill('focus-under-fatigue', 'Focus under fatigue')],
    commonLoadAreas: ['shoulder', 'upper-back'], contactLevel: 'NONE', typicalSessionLength: 60,
  }),
  sport({
    slug: 'cycling', name: 'Cycling', governing: ['NCAA'], season: 'SPRING', monthRange: [3, 6],
    qualityProfile: { 'aerobic-base': 1.0, 'anaerobic-capacity': 0.6, 'lower-body-strength': 0.5, 'single-leg-stability': 0.4 },
    skills: [skill('ftp-power', 'Functional threshold power'), skill('sprint-power', 'Sprint power'), skill('climbing-power-to-weight', 'Climbing power-to-weight'), skill('cadence-efficiency', 'Cadence efficiency')],
    commonLoadAreas: ['lower-back', 'knees'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'mountain-biking', name: 'Mountain Biking', governing: ['NFHS'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'aerobic-base': 0.8, 'single-leg-stability': 0.6, 'reactive-strength': 0.5, 'trunk-anti-rotation': 0.6, 'grip': 0.5 },
    skills: [skill('technical-descending', 'Technical descending control'), skill('climbing-power', 'Climbing power'), skill('bike-handling', 'Bike handling'), skill('endurance-pacing', 'Endurance pacing')],
    commonLoadAreas: ['lower-back', 'wrists'], contactLevel: 'LIMITED', typicalSessionLength: 90,
  }),
  sport({
    slug: 'sailing', name: 'Sailing', governing: ['NCAA'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'trunk-anti-rotation': 0.7, 'grip': 0.6, 'single-leg-stability': 0.5, 'aerobic-base': 0.5 },
    skills: [skill('hiking-endurance', 'Hiking endurance'), skill('grip-endurance', 'Grip and line-handling endurance'), skill('balance-in-motion', 'Balance in motion'), skill('quick-repositioning', 'Quick repositioning under tacks')],
    commonLoadAreas: ['lower-back', 'forearms'], contactLevel: 'NONE', typicalSessionLength: 120,
  }),
  sport({
    slug: 'surfing', name: 'Surfing', governing: ['NFHS'], season: 'SUMMER', monthRange: [6, 8],
    qualityProfile: { 'upper-body-pull': 0.6, 'single-leg-stability': 0.8, 'reactive-strength': 0.7, 'trunk-anti-rotation': 0.6, 'aerobic-base': 0.5 },
    skills: [skill('paddle-power', 'Paddle power'), skill('pop-up-speed', 'Pop-up speed'), skill('balance-on-unstable-surface', 'Balance on an unstable surface'), skill('rotational-turns', 'Rotational turn power')],
    commonLoadAreas: ['shoulders', 'lower-back'], contactLevel: 'LIMITED', typicalSessionLength: 90,
  }),
  sport({
    slug: 'judo', name: 'Judo', governing: ['NCAA'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'grip': 0.8, 'rotational-power': 0.7, 'trunk-anti-rotation': 0.7, 'reactive-strength': 0.6, 'anaerobic-capacity': 0.6 },
    skills: [skill('grip-strength', 'Grip strength'), skill('throw-power', 'Throw power'), skill('off-balancing-timing', 'Off-balancing timing'), skill('groundwork-transitions', 'Groundwork transitions'), skill('fall-safety', 'Fall safety and break-falls')],
    commonLoadAreas: ['neck', 'shoulders', 'lower-back'], contactLevel: 'COLLISION', typicalSessionLength: 90,
  }),
  sport({
    slug: 'weightlifting', name: 'Weightlifting', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'lower-body-strength': 1.0, 'upper-body-push': 0.6, 'hip-mobility': 0.7, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.5 },
    skills: [skill('squat-strength', 'Squat strength'), skill('hip-mobility', 'Hip and ankle mobility'), skill('bar-path-consistency', 'Bar-path consistency'), skill('overhead-stability', 'Overhead stability')],
    commonLoadAreas: ['lower-back', 'shoulders', 'wrists'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'powerlifting', name: 'Powerlifting', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'lower-body-strength': 1.0, 'upper-body-push': 0.8, 'grip': 0.6, 'trunk-anti-rotation': 0.6 },
    skills: [skill('squat-strength', 'Squat strength'), skill('bench-press-strength', 'Bench press strength'), skill('deadlift-strength', 'Deadlift strength'), skill('bracing-technique', 'Bracing technique')],
    commonLoadAreas: ['lower-back', 'shoulders'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'triathlon', name: 'Triathlon', governing: ['NFHS'], season: 'SUMMER', monthRange: [6, 8],
    qualityProfile: { 'aerobic-base': 1.0, 'anaerobic-capacity': 0.5, 'single-leg-stability': 0.4, 'shoulder-stability': 0.4 },
    skills: [skill('swim-to-bike-transition', 'Swim-to-bike transition speed'), skill('bike-to-run-transition', 'Bike-to-run transition legs'), skill('aerobic-pacing', 'Aerobic pacing across three disciplines'), skill('open-water-sighting', 'Open-water sighting')],
    commonLoadAreas: ['knees', 'lower-back'], contactLevel: 'NONE', typicalSessionLength: 100,
  }),
  sport({
    slug: 'equestrian', name: 'Equestrian', governing: ['NCAA'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'single-leg-stability': 0.5, 'trunk-anti-rotation': 0.7, 'hip-mobility': 0.6, 'grip': 0.5 },
    skills: [skill('core-stability-in-saddle', 'Core stability in the saddle'), skill('leg-independence', 'Leg independence'), skill('grip-endurance', 'Rein-hand grip endurance'), skill('balance-recovery', 'Balance recovery')],
    commonLoadAreas: ['lower-back', 'hips'], contactLevel: 'LIMITED', typicalSessionLength: 60,
  }),
  sport({
    slug: 'climbing', name: 'Climbing', governing: ['NFHS'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'grip': 1.0, 'upper-body-pull': 0.8, 'trunk-anti-rotation': 0.7, 'single-leg-stability': 0.6, 'hip-mobility': 0.6 },
    skills: [skill('grip-strength', 'Grip strength'), skill('pulling-power', 'Pulling power'), skill('footwork-precision', 'Footwork precision'), skill('route-reading', 'Route reading'), skill('core-tension', 'Core tension on overhangs')],
    commonLoadAreas: ['fingers', 'shoulders', 'elbows'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'boys-volleyball', name: "Boys' Volleyball", governing: ['NFHS'], season: 'SPRING', monthRange: [3, 6],
    qualityProfile: { 'vertical-power': 0.9, 'overhead-power': 0.8, 'reactive-strength': 0.8, 'lateral-power': 0.6, 'landing-mechanics': 0.8 },
    skills: [skill('approach-jump-height', 'Approach jump height'), skill('spike-velocity', 'Spike velocity'), skill('blocking-timing', 'Blocking timing'), skill('serve-power', 'Serve power')],
    commonLoadAreas: ['shoulder', 'knees'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'sand-volleyball', name: 'Beach / Sand Volleyball', governing: ['NCAA'], season: 'SPRING', monthRange: [3, 6],
    qualityProfile: { 'vertical-power': 0.8, 'aerobic-base': 0.6, 'lateral-power': 0.7, 'overhead-power': 0.7, 'single-leg-stability': 0.6 },
    skills: [skill('sand-jump-power', 'Sand jump power'), skill('lateral-movement-in-sand', 'Lateral movement in sand'), skill('serve-power', 'Serve power'), skill('defensive-range', 'Defensive range')],
    commonLoadAreas: ['ankles', 'shoulders'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'field-hockey-goalkeeping', name: 'Field Hockey Goalkeeping', governing: ['NFHS'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'reactive-strength': 0.9, 'lateral-power': 0.9, 'landing-mechanics': 0.7, 'hip-mobility': 0.6 },
    skills: [skill('reaction-save-speed', 'Reaction save speed'), skill('lateral-explosiveness', 'Lateral explosiveness'), skill('low-block-mobility', 'Low block mobility'), skill('recovery-to-feet', 'Recovery to feet')],
    commonLoadAreas: ['hips', 'knees'], contactLevel: 'LIMITED', typicalSessionLength: 80,
  }),
  sport({
    slug: 'esports-physical-conditioning', name: 'Esports (Physical Conditioning)', governing: ['NFHS'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'aerobic-base': 0.5, 'grip': 0.4, 'trunk-anti-rotation': 0.5, 'shoulder-stability': 0.4 },
    skills: [skill('wrist-forearm-endurance', 'Wrist and forearm endurance'), skill('postural-endurance', 'Postural endurance'), skill('reaction-time', 'Reaction time'), skill('general-conditioning', 'General conditioning for long sessions')],
    commonLoadAreas: ['wrists', 'neck', 'lower-back'], contactLevel: 'NONE', typicalSessionLength: 45,
  }),
  sport({
    slug: 'step-team', name: 'Step / Dance Team', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'reactive-strength': 0.7, 'trunk-anti-rotation': 0.6, 'aerobic-base': 0.6, 'single-leg-stability': 0.6, 'landing-mechanics': 0.6 },
    skills: [skill('rhythmic-precision', 'Rhythmic precision'), skill('jump-power', 'Jump power'), skill('routine-endurance', 'Routine endurance'), skill('flexibility', 'Flexibility')],
    commonLoadAreas: ['knees', 'ankles'], contactLevel: 'NONE', typicalSessionLength: 75,
  }),
  sport({
    slug: 'competitive-dance', name: 'Competitive Dance / Drill', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'reactive-strength': 0.7, 'hip-mobility': 0.7, 'single-leg-stability': 0.7, 'landing-mechanics': 0.7, 'aerobic-base': 0.5 },
    skills: [skill('leap-height', 'Leap height'), skill('turn-control', 'Turn control'), skill('flexibility', 'Flexibility'), skill('routine-stamina', 'Routine stamina'), skill('landing-control', 'Landing control')],
    commonLoadAreas: ['ankles', 'hips'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'marching-band-athletics', name: 'Marching Band (Physical Conditioning)', governing: ['NFHS'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'aerobic-base': 0.7, 'trunk-anti-rotation': 0.5, 'shoulder-stability': 0.5, 'single-leg-stability': 0.4 },
    skills: [skill('marching-endurance', 'Marching endurance'), skill('postural-control-while-playing', 'Postural control while playing'), skill('breath-support', 'Breath support'), skill('heat-tolerance-conditioning', 'Heat-tolerance conditioning')],
    commonLoadAreas: ['lower-back', 'shoulders', 'shins'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'color-guard', name: 'Color Guard', governing: ['NFHS'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'shoulder-stability': 0.7, 'grip': 0.6, 'single-leg-stability': 0.6, 'trunk-anti-rotation': 0.6 },
    skills: [skill('equipment-control', 'Equipment (flag/rifle/sabre) control'), skill('toss-catch-timing', 'Toss and catch timing'), skill('shoulder-endurance', 'Shoulder endurance'), skill('routine-precision', 'Routine precision')],
    commonLoadAreas: ['shoulders', 'wrists'], contactLevel: 'NONE', typicalSessionLength: 75,
  }),
  sport({
    slug: 'unified-basketball', name: 'Unified Basketball', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'vertical-power': 0.6, 'change-of-direction': 0.6, 'acceleration': 0.6, 'anaerobic-capacity': 0.5 },
    skills: [skill('shooting-mechanics', 'Shooting mechanics'), skill('ball-handling', 'Ball handling'), skill('teamwork-positioning', 'Teamwork and positioning'), skill('conditioning', 'General conditioning')],
    commonLoadAreas: ['knees', 'ankles'], contactLevel: 'CONTACT', typicalSessionLength: 75,
  }),
  sport({
    slug: 'unified-track', name: 'Unified Track and Field', governing: ['NFHS'], season: 'SPRING', monthRange: [3, 6],
    qualityProfile: { 'acceleration': 0.6, 'max-velocity': 0.6, 'aerobic-base': 0.5, 'horizontal-power': 0.5 },
    skills: [skill('sprint-technique', 'Sprint technique'), skill('jump-technique', 'Jump technique'), skill('throw-technique', 'Throw technique'), skill('pacing', 'Pacing')],
    commonLoadAreas: ['hamstrings', 'shins'], contactLevel: 'NONE', typicalSessionLength: 60,
  }),
  sport({
    slug: 'adapted-floor-hockey', name: 'Adapted Floor Hockey', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'upper-body-push': 0.5, 'trunk-anti-rotation': 0.5, 'aerobic-base': 0.5, 'grip': 0.5 },
    skills: [skill('stick-handling', 'Stick handling'), skill('shot-accuracy', 'Shot accuracy'), skill('positional-awareness', 'Positional awareness'), skill('endurance', 'Game endurance')],
    commonLoadAreas: ['shoulders', 'wrists'], contactLevel: 'LIMITED', typicalSessionLength: 60,
  }),
  sport({
    slug: 'adapted-swimming', name: 'Adapted Swimming', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 2],
    qualityProfile: { 'aerobic-base': 0.7, 'upper-body-pull': 0.6, 'shoulder-stability': 0.6 },
    skills: [skill('stroke-technique', 'Stroke technique'), skill('breathing-rhythm', 'Breathing rhythm'), skill('endurance', 'Endurance'), skill('start-technique', 'Start technique')],
    commonLoadAreas: ['shoulders'], contactLevel: 'NONE', typicalSessionLength: 60,
  }),
  sport({
    slug: 'wheelchair-basketball', name: 'Wheelchair Basketball', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'upper-body-push': 0.8, 'upper-body-pull': 0.7, 'trunk-anti-rotation': 0.7, 'anaerobic-capacity': 0.7, 'grip': 0.6 },
    skills: [skill('push-speed', 'Chair push speed'), skill('shooting-mechanics', 'Shooting mechanics'), skill('pivoting-control', 'Pivoting control'), skill('upper-body-endurance', 'Upper-body endurance')],
    commonLoadAreas: ['shoulders', 'wrists'], contactLevel: 'CONTACT', typicalSessionLength: 75,
  }),
  sport({
    slug: 'para-track', name: 'Para Track and Field', governing: ['NFHS'], season: 'SPRING', monthRange: [3, 6],
    qualityProfile: { 'acceleration': 0.6, 'upper-body-push': 0.5, 'trunk-anti-rotation': 0.5, 'aerobic-base': 0.5 },
    skills: [skill('start-technique', 'Start technique'), skill('technique-efficiency', 'Movement-specific technique efficiency'), skill('pacing', 'Pacing'), skill('upper-body-power', 'Upper-body power')],
    commonLoadAreas: ['shoulders', 'lower-back'], contactLevel: 'NONE', typicalSessionLength: 60,
  }),
  sport({
    slug: 'goalball', name: 'Goalball', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'reactive-strength': 0.7, 'lateral-power': 0.7, 'trunk-anti-rotation': 0.6, 'single-leg-stability': 0.5 },
    skills: [skill('throwing-power', 'Throwing power'), skill('blocking-reaction', 'Blocking reaction'), skill('spatial-tracking-by-sound', 'Spatial tracking by sound'), skill('lateral-coverage', 'Lateral coverage')],
    commonLoadAreas: ['hips', 'shoulders'], contactLevel: 'CONTACT', typicalSessionLength: 60,
  }),
  sport({
    slug: 'boccia', name: 'Boccia', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'grip': 0.5, 'trunk-anti-rotation': 0.5, 'shoulder-stability': 0.4 },
    skills: [skill('release-consistency', 'Release consistency'), skill('touch-control', 'Touch and distance control'), skill('focus-under-fatigue', 'Focus under fatigue'), skill('postural-endurance', 'Postural endurance')],
    commonLoadAreas: ['shoulder', 'wrist'], contactLevel: 'NONE', typicalSessionLength: 45,
  }),
  sport({
    slug: 'beep-baseball', name: 'Beep Baseball', governing: ['NFHS'], season: 'SUMMER', monthRange: [6, 8],
    qualityProfile: { 'rotational-power': 0.7, 'acceleration': 0.6, 'reactive-strength': 0.5, 'grip': 0.4 },
    skills: [skill('bat-speed', 'Bat speed'), skill('sprint-to-base', 'Sprint to base'), skill('auditory-tracking', 'Auditory tracking'), skill('diving-safety', 'Safe diving technique')],
    commonLoadAreas: ['shoulders', 'knees'], contactLevel: 'CONTACT', typicalSessionLength: 75,
  }),
  sport({
    slug: 'sitting-volleyball', name: 'Sitting Volleyball', governing: ['NFHS'], season: 'WINTER', monthRange: [11, 3],
    qualityProfile: { 'upper-body-push': 0.7, 'trunk-anti-rotation': 0.7, 'overhead-power': 0.6, 'grip': 0.5 },
    skills: [skill('seated-mobility', 'Seated mobility'), skill('spike-power', 'Spike power from seated'), skill('blocking-reach', 'Blocking reach'), skill('serve-power', 'Serve power')],
    commonLoadAreas: ['shoulders', 'lower-back'], contactLevel: 'NONE', typicalSessionLength: 75,
  }),
  sport({
    slug: 'racquetball', name: 'Racquetball', governing: ['NFHS'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'reactive-strength': 0.7, 'lateral-power': 0.7, 'anaerobic-capacity': 0.7, 'change-of-direction': 0.7 },
    skills: [skill('swing-power', 'Swing power'), skill('court-coverage', 'Court coverage'), skill('reaction-time', 'Reaction time'), skill('recovery-speed', 'Recovery speed to center court')],
    commonLoadAreas: ['shoulder', 'knees'], contactLevel: 'LIMITED', typicalSessionLength: 60,
  }),
  sport({
    slug: 'orienteering', name: 'Orienteering', governing: ['NFHS'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'aerobic-base': 0.9, 'single-leg-stability': 0.6, 'ankle-stiffness': 0.5, 'anaerobic-capacity': 0.4 },
    skills: [skill('trail-running-economy', 'Trail-running economy'), skill('uneven-terrain-stability', 'Uneven-terrain stability'), skill('pacing-under-navigation-load', 'Pacing under navigation load'), skill('endurance', 'Sustained endurance')],
    commonLoadAreas: ['ankles', 'shins'], contactLevel: 'NONE', typicalSessionLength: 75,
  }),
  sport({
    slug: 'disc-golf', name: 'Disc Golf', governing: ['NFHS'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'rotational-power': 0.7, 'hip-mobility': 0.6, 'single-leg-stability': 0.5, 'trunk-anti-rotation': 0.5 },
    skills: [skill('drive-distance', 'Drive distance'), skill('rotational-mechanics', 'Rotational mechanics'), skill('putting-consistency', 'Putting consistency'), skill('walking-endurance', 'Walking endurance across 18')],
    commonLoadAreas: ['lower-back', 'elbow'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'spikeball', name: 'Spikeball (Roundnet)', governing: ['NFHS'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'reactive-strength': 0.7, 'lateral-power': 0.6, 'single-leg-stability': 0.5, 'landing-mechanics': 0.5 },
    skills: [skill('hit-power', 'Hit power'), skill('reaction-time', 'Reaction time'), skill('lateral-diving', 'Lateral diving range'), skill('set-touch', 'Set touch')],
    commonLoadAreas: ['knees', 'shoulder'], contactLevel: 'LIMITED', typicalSessionLength: 45,
  }),
  sport({
    slug: 'skateboarding', name: 'Skateboarding', governing: ['NFHS'], season: 'SUMMER', monthRange: [6, 8],
    qualityProfile: { 'single-leg-stability': 0.8, 'reactive-strength': 0.7, 'landing-mechanics': 0.8, 'ankle-stiffness': 0.6 },
    skills: [skill('pop-height', 'Pop height'), skill('landing-control', 'Landing control'), skill('balance-on-unstable-surface', 'Balance on an unstable surface'), skill('rotational-air-awareness', 'Rotational air awareness')],
    commonLoadAreas: ['ankles', 'wrists'], contactLevel: 'LIMITED', typicalSessionLength: 90,
  }),
  sport({
    slug: 'bmx', name: 'BMX', governing: ['NFHS'], season: 'SUMMER', monthRange: [6, 8],
    qualityProfile: { 'reactive-strength': 0.7, 'horizontal-power': 0.6, 'single-leg-stability': 0.6, 'grip': 0.5 },
    skills: [skill('gate-start-power', 'Gate start power'), skill('jump-technique', 'Jump technique'), skill('bike-handling', 'Bike handling'), skill('sprint-power', 'Sprint power')],
    commonLoadAreas: ['wrists', 'shoulders'], contactLevel: 'CONTACT', typicalSessionLength: 60,
  }),
  sport({
    slug: 'inline-hockey', name: 'Inline Hockey', governing: ['NFHS'], season: 'SPRING', monthRange: [3, 6],
    qualityProfile: { 'acceleration': 0.8, 'change-of-direction': 0.8, 'anaerobic-capacity': 0.8, 'single-leg-stability': 0.7 },
    skills: [skill('skating-speed', 'Skating speed'), skill('stick-handling', 'Stick handling'), skill('shooting-power', 'Shooting power'), skill('edge-work', 'Edge work')],
    commonLoadAreas: ['hips', 'knees'], contactLevel: 'CONTACT', typicalSessionLength: 75,
  }),
  sport({
    slug: 'ultimate-beach', name: 'Beach Ultimate', governing: ['NCAA'], season: 'SUMMER', monthRange: [6, 8],
    qualityProfile: { 'max-velocity': 0.7, 'aerobic-base': 0.7, 'change-of-direction': 0.7, 'vertical-power': 0.5 },
    skills: [skill('sprint-speed-in-sand', 'Sprint speed in sand'), skill('throwing-power', 'Throwing power'), skill('layout-explosiveness', 'Layout explosiveness'), skill('endurance-in-heat', 'Endurance in heat')],
    commonLoadAreas: ['calves', 'hamstrings'], contactLevel: 'LIMITED', typicalSessionLength: 90,
  }),
  sport({
    slug: 'triathlon-duathlon', name: 'Duathlon', governing: ['NFHS'], season: 'SUMMER', monthRange: [6, 8],
    qualityProfile: { 'aerobic-base': 1.0, 'anaerobic-capacity': 0.5, 'single-leg-stability': 0.4 },
    skills: [skill('run-to-bike-transition', 'Run-to-bike transition'), skill('bike-to-run-transition', 'Bike-to-run transition legs'), skill('pacing', 'Two-discipline pacing'), skill('running-economy', 'Running economy')],
    commonLoadAreas: ['knees', 'lower-back'], contactLevel: 'NONE', typicalSessionLength: 90,
  }),
  sport({
    slug: 'crossfit-style-conditioning', name: 'Strength & Conditioning Team', governing: ['NFHS'], season: 'YEAR_ROUND', monthRange: [1, 12],
    qualityProfile: { 'lower-body-strength': 0.7, 'upper-body-push': 0.6, 'upper-body-pull': 0.6, 'aerobic-base': 0.6, 'anaerobic-capacity': 0.6, 'trunk-anti-rotation': 0.6 },
    skills: [skill('general-strength', 'General strength'), skill('work-capacity', 'Work capacity'), skill('movement-quality', 'Movement quality under fatigue'), skill('mixed-modal-conditioning', 'Mixed-modal conditioning')],
    commonLoadAreas: ['lower-back', 'shoulders'], contactLevel: 'NONE', typicalSessionLength: 60,
  }),
  sport({
    slug: 'cheerleading-sideline', name: 'Sideline Cheerleading', governing: ['NFHS'], season: 'FALL', monthRange: [8, 11],
    qualityProfile: { 'vertical-power': 0.6, 'trunk-anti-rotation': 0.6, 'shoulder-stability': 0.6, 'aerobic-base': 0.5 },
    skills: [skill('jump-height', 'Jump height'), skill('stunt-stability', 'Stunt stability'), skill('projection-and-voice-endurance', 'Projection and voice endurance'), skill('routine-stamina', 'Routine stamina')],
    commonLoadAreas: ['shoulders', 'wrists'], contactLevel: 'CONTACT', typicalSessionLength: 75,
  }),
  sport({
    slug: 'lacrosse-box', name: 'Box Lacrosse', governing: ['NCAA'], season: 'WINTER', monthRange: [11, 2],
    qualityProfile: { 'acceleration': 0.8, 'rotational-power': 0.8, 'anaerobic-capacity': 0.8, 'grip': 0.6 },
    skills: [skill('shot-velocity', 'Shot velocity'), skill('dodging-quickness', 'Dodging quickness'), skill('checking-strength', 'Checking strength'), skill('transition-speed', 'Transition speed')],
    commonLoadAreas: ['shoulders', 'wrists'], contactLevel: 'COLLISION', typicalSessionLength: 75,
  }),
  sport({
    slug: 'netball', name: 'Netball', governing: ['NFHS'], season: 'SPRING', monthRange: [3, 6],
    qualityProfile: { 'vertical-power': 0.7, 'acceleration': 0.7, 'change-of-direction': 0.7, 'landing-mechanics': 0.6 },
    skills: [skill('vertical-jump', 'Vertical jump'), skill('first-step', 'First step'), skill('passing-accuracy', 'Passing accuracy'), skill('marking-positioning', 'Marking and positioning')],
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
