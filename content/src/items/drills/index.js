/**
 * Every sport-drill file, one per group of sports. Each exports one array;
 * this is the only place they are combined.
 */
import { ENDURANCE_DRILLS } from './endurance.js';
import { FIELD_AND_COURT_DRILLS } from './fieldAndCourt.js';
import { INDIVIDUAL_DRILLS } from './individual.js';
import { MISC_DRILLS } from './misc.js';
import { NET_COURT_DRILLS } from './netCourt.js';
import { STICK_DRILLS } from './stickSports.js';

export const SPORT_DRILLS = [
  ...FIELD_AND_COURT_DRILLS,
  ...STICK_DRILLS,
  ...NET_COURT_DRILLS,
  ...ENDURANCE_DRILLS,
  ...INDIVIDUAL_DRILLS,
  ...MISC_DRILLS,
];
