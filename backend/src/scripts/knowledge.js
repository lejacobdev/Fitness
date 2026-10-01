// The knowledge release kill switch and review log (run on the server):
//   docker exec student-athlete-api-1 node src/scripts/knowledge.js show
//   … disable-rule SCHED-CONGESTION-05 "reason" "who"     (SAFE-* rules can't be switched off)
//   … enable-rule SCHED-CONGESTION-05 "reason" "who"
//   … quarantine box-jump "reason" "who"                  (the app stops offering it)
//   … release box-jump "reason" "who"
//   … review-item goblet-squat "scope and date" "Name, role"
//   … review-sport basketball "scope and date" "Name, role"
// Every action is kept (append-only); the app picks the change up at its next launch.
import { currentRelease } from '../routes/knowledge.js';
import { disconnectPrisma, prisma } from '../lib/prisma.js';

const KINDS = {
  'disable-rule': 'disable_rule', 'enable-rule': 'enable_rule', quarantine: 'quarantine_item',
  release: 'release_item', 'review-item': 'review_item', 'review-sport': 'review_sport',
};
const [command, target, reason, actor] = process.argv.slice(2);
if (command === 'show') {
  console.log(JSON.stringify(await currentRelease(prisma), null, 2));
  for (const a of await prisma.knowledgeAction.findMany({ orderBy: { createdAt: 'desc' }, take: 20 })) {
    console.log(`${a.createdAt.toISOString()}  ${a.kind} ${a.target} — ${a.reason} (${a.actor})`);
  }
} else if (KINDS[command] && target && reason && actor) {
  if (command === 'disable-rule' && target.startsWith('SAFE-')) {
    console.error('Safety rules can never be switched off.');
    process.exitCode = 2;
  } else {
    await prisma.knowledgeAction.create({ data: { kind: KINDS[command], target, reason, actor } });
    console.log(JSON.stringify(await currentRelease(prisma), null, 2));
  }
} else {
  console.error('usage: knowledge.js show | <disable-rule|enable-rule|quarantine|release|review-item|review-sport> <target> "<reason>" "<who>"');
  process.exitCode = 2;
}
await disconnectPrisma();
