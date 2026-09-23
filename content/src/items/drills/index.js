/**
 * Every sport-drill file, one per group of sports. Each exports one array;
 * this is the only place they are combined.
 */
import { FIELD_AND_COURT_DRILLS } from './fieldAndCourt.js';

export const SPORT_DRILLS = [
  ...FIELD_AND_COURT_DRILLS,
];
