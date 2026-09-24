// Dev-only: unassigned drills for the given sports (slug | name | eq | how).
import { RAW_BASE_ITEMS } from '../src/catalogue.js';
import { POSE_ASSIGNMENTS } from '../src/poseAssignments/index.js';
const sports = process.argv[2].split(',');
for (const i of RAW_BASE_ITEMS) {
  if (POSE_ASSIGNMENTS[i.slug] || !sports.includes(i.sport)) continue;
  console.log(`${i.slug} | ${i.name} | ${(i.equipment ?? []).join(',')} | ${(i.execution ?? []).slice(0, 2).join(' ').slice(0, 170)}`);
}
