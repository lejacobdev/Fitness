// Parent emails, run by the host's cron (backend/deploy/parent-emails.sh):
//   docker exec student-athlete-api-1 node src/scripts/parentEmails.js due
//     → one JSON message per line (to, subject, text, html)
//   docker exec student-athlete-api-1 node src/scripts/parentEmails.js sent <kind> <athleteId>
// The host sends with its own sendmail (DKIM-signed), then marks it sent.
import { dueParentEmails, markParentEmailSent } from '../lib/parentMail.js';
import { disconnectPrisma, prisma } from '../lib/prisma.js';

const [command, kind, athleteId] = process.argv.slice(2);
if (command === 'due') {
  for (const message of await dueParentEmails(prisma)) console.log(JSON.stringify(message));
} else if (command === 'sent' && (kind === 'confirm' || kind === 'weekly') && athleteId) {
  await markParentEmailSent(prisma, kind, athleteId);
} else {
  console.error('usage: parentEmails.js due | sent <confirm|weekly> <athleteId>');
  process.exitCode = 2;
}
await disconnectPrisma();
