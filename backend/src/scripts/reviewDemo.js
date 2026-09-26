/**
 * App Review demo content, so a reviewer can try teams, leagues and shared
 * workouts without a second account: a demo coach with a team, a league
 * (with this week's XP) and a shared workout. Idempotent; prints the codes.
 *
 *   docker exec student-athlete-api-1 node src/scripts/reviewDemo.js
 */
import { uniqueCode } from '../lib/codes.js';
import { disconnectPrisma, prisma } from '../lib/prisma.js';

const COACH = 'app-review-demo-coach';

function weekKey(date = new Date()) {
  const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  d.setUTCDate(d.getUTCDate() - ((d.getUTCDay() + 6) % 7));
  return d.toISOString().slice(0, 10);
}

const coach = await prisma.athlete.upsert({
  where: { appleUserId: COACH },
  update: {},
  create: { appleUserId: COACH, birthDate: new Date('1985-01-01'), displayName: 'Coach Demo' },
});

let team = await prisma.team.findFirst({ where: { coachId: coach.id, name: 'App Review Demo Team' } });
team ??= await prisma.team.create({ data: { name: 'App Review Demo Team', code: await uniqueCode(prisma), coachId: coach.id } });

let league = await prisma.league.findFirst({ where: { name: 'App Review League', members: { some: { athleteId: coach.id } } } });
league ??= await prisma.league.create({
  data: { name: 'App Review League', code: await uniqueCode(prisma), members: { create: { athleteId: coach.id, nickname: 'Coach Demo' } } },
});
await prisma.weeklyXP.upsert({
  where: { athleteId_week: { athleteId: coach.id, week: weekKey() } },
  update: { xp: 120 },
  create: { athleteId: coach.id, week: weekKey(), xp: 120 },
});

let workout = await prisma.sharedWorkout.findFirst({ where: { ownerId: coach.id, title: 'Review demo: leg day' } });
workout ??= await prisma.sharedWorkout.create({
  data: {
    code: await uniqueCode(prisma), ownerId: coach.id, title: 'Review demo: leg day', sportSlug: 'soccer',
    items: [
      { itemSlug: 'goblet-squat', dose: { kind: 'reps', sets: 3, reps: 8 }, restSec: 90 },
      { itemSlug: 'split-squat', dose: { kind: 'reps', sets: 3, reps: 8, perSide: true }, restSec: 60 },
      { itemSlug: 'nordic-hamstring-curl', dose: { kind: 'reps', sets: 3, reps: 5 }, restSec: 90 },
      { itemSlug: 'copenhagen-plank', dose: { kind: 'time', sets: 2, seconds: 20, perSide: true }, restSec: 45 },
      { itemSlug: 'dead-bug', dose: { kind: 'reps', sets: 3, reps: 10 }, restSec: 45 },
    ],
  },
});

console.log(`team    ${team.code}  (${team.name})`);
console.log(`league  ${league.code}  (${league.name})`);
console.log(`workout ${workout.code}  (${workout.title})`);
await disconnectPrisma();
