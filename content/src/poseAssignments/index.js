/**
 * Every catalogue item → the one movement pattern that shows it (poses.js).
 * Split by the item source files they cover. catalogue.js applies these, and
 * test/poseAssignments.test.js requires every base item to have one.
 */
import { EXERCISE_POSES } from './exercises.js';
import { TEAM_SPORT_POSES } from './teamSports.js';
import { INDIVIDUAL_SPORT_POSES } from './individualSports.js';
import { MISC_SPORT_POSES } from './miscSports.js';
import { COURT_SPORT_POSES } from './courtSports.js';
import { NET_SPORT_POSES } from './netSports.js';
import { RACKET_SPORT_POSES } from './racketSports.js';
import { FIELD_SPORT_POSES } from './fieldSports.js';
import { STICK_SPORT_POSES } from './stickSports.js';
import { RUNNING_POSES } from './running.js';
import { ENDURANCE_POSES } from './endurance.js';
import { BIKE_POSES } from './bikes.js';
import { WATER_POSES } from './water.js';
import { COMBAT_POSES } from './combat.js';
import { STRENGTH_SPORT_POSES } from './strengthSports.js';
import { ARTISTIC_POSES } from './artistic.js';
import { PRECISION_POSES } from './precision.js';
import { OUTDOOR_POSES } from './outdoor.js';

export const POSE_ASSIGNMENTS = { ...EXERCISE_POSES, ...TEAM_SPORT_POSES, ...INDIVIDUAL_SPORT_POSES, ...MISC_SPORT_POSES, ...COURT_SPORT_POSES, ...NET_SPORT_POSES, ...RACKET_SPORT_POSES, ...FIELD_SPORT_POSES, ...STICK_SPORT_POSES, ...RUNNING_POSES, ...ENDURANCE_POSES, ...BIKE_POSES, ...WATER_POSES, ...COMBAT_POSES, ...STRENGTH_SPORT_POSES, ...ARTISTIC_POSES, ...PRECISION_POSES, ...OUTDOOR_POSES };
