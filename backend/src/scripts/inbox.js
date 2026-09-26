// Reports and support-page messages from the last N days (default 14), newest first:
//   docker exec student-athlete-api-1 node src/scripts/inbox.js [days]
// App Store guideline 1.2 expects reported content to be looked at within 24 hours.
import { disconnectPrisma, prisma } from '../lib/prisma.js';

const since = new Date(Date.now() - Number(process.argv[2] ?? 14) * 86_400_000);
const reports = await prisma.report.findMany({ where: { createdAt: { gte: since } }, orderBy: { createdAt: 'desc' } });
const messages = await prisma.supportMessage.findMany({ where: { createdAt: { gte: since } }, orderBy: { createdAt: 'desc' } });
console.log(`Reports (${reports.length})`);
for (const r of reports) console.log(`  ${r.createdAt.toISOString()}  ${r.kind} ${r.target}${r.reason ? ` — ${r.reason}` : ''}`);
console.log(`\nSupport messages (${messages.length})`);
for (const m of messages) console.log(`  ${m.createdAt.toISOString()}  ${m.email ?? '(no email)'}\n    ${m.message.replace(/\n/g, '\n    ')}`);
await disconnectPrisma();
