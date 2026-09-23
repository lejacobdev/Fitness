/**
 * Every catalogue item → the one movement pattern that shows it (poses.js).
 * Split by the item source files they cover. catalogue.js applies these, and
 * test/poseAssignments.test.js requires every base item to have one.
 */
import { EXERCISE_POSES } from './exercises.js';
import { TEAM_SPORT_POSES } from './teamSports.js';
import { INDIVIDUAL_SPORT_POSES } from './individualSports.js';
import { MISC_SPORT_POSES } from './miscSports.js';

export const POSE_ASSIGNMENTS = { ...EXERCISE_POSES, ...TEAM_SPORT_POSES, ...INDIVIDUAL_SPORT_POSES, ...MISC_SPORT_POSES };
