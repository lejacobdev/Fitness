import { renderSummary, weeklySummary } from '../routes/parent.js';

const BASE = (process.env.PUBLIC_BASE_URL ?? 'https://api.lejacob.dev/fitness').replace(/\/$/, '');
const DAY_MS = 86_400_000;

/**
 * Which parent emails are due now: a confirmation for every address not yet
 * asked (within 3 days of being added), and on Sundays from 16:00 UTC the
 * weekly summary for every confirmed address not mailed in the last 6 days.
 */
export async function dueParentEmails(prisma, now = new Date()) {
  const out = [];
  const unconfirmed = await prisma.parentEmail.findMany({
    where: { confirmed: false, confirmMailed: null, createdAt: { gte: new Date(now.getTime() - 3 * DAY_MS) } },
  });
  for (const row of unconfirmed) {
    out.push({
      kind: 'confirm',
      athleteId: row.athleteId,
      to: row.email,
      subject: 'Your athlete wants to send you a weekly summary',
      text: [
        'Hi,',
        '',
        'Your athlete added this address in the AthleteOS training app, to send you a short weekly summary every Sunday:',
        'workouts, sleep, morning check-ins and upcoming games. Only numbers — never anything they wrote.',
        '',
        `Yes, send it to me: ${BASE}/parent-email/confirm/${row.token}`,
        '',
        "If you don't know what this is, ignore this email. Nothing else will be sent.",
      ].join('\n'),
    });
  }
  const isSunday = now.getUTCDay() === 0 && now.getUTCHours() >= 16;
  if (isSunday) {
    const confirmed = await prisma.parentEmail.findMany({ where: { confirmed: true } });
    for (const row of confirmed) {
      if (row.lastSentAt && now - row.lastSentAt < 6 * DAY_MS) continue;
      const summary = await weeklySummary(prisma, row.athleteId, now);
      const stop = `${BASE}/parent-email/stop/${row.token}`;
      out.push({
        kind: 'weekly',
        athleteId: row.athleteId,
        to: row.email,
        subject: `This week: ${summary.sessions} workouts, ${summary.checkIns}/7 check-ins`,
        text: [
          `Training: ${summary.sessions} workouts, ${summary.minutes} minutes, ${summary.checkIns}/7 morning check-ins.`,
          summary.averageSleepHours == null ? 'Sleep: not recorded.' : `Average sleep: ${summary.averageSleepHours.toFixed(1)} hours (teenage athletes need about 8–10).`,
          `Ready days: ${summary.readiness.green}, tired days: ${summary.readiness.amber + summary.readiness.red}.`,
          '',
          'Shared from the AthleteOS app. Only numbers — never anything your athlete wrote.',
          `Stop these emails: ${stop}`,
        ].join('\n'),
        html: `<!doctype html><html><body style="font:16px/1.5 -apple-system,Helvetica,Arial,sans-serif;max-width:600px;margin:0 auto;padding:16px;color:#111">
<h1 style="font-size:22px">This week</h1>
${renderSummary(summary).replace(/<p class="foot">[\s\S]*?<\/p>/, '')}
<p style="color:#666;font-size:13px">Shared from the AthleteOS app. Only numbers — never anything your athlete wrote.<br><a href="${stop}">Stop these emails</a></p>
</body></html>`,
        stop,
      });
    }
  }
  return out;
}

/** Records that an email went out, so it isn't sent twice. */
export async function markParentEmailSent(prisma, kind, athleteId, now = new Date()) {
  const data = kind === 'confirm' ? { confirmMailed: now } : { lastSentAt: now };
  await prisma.parentEmail.update({ where: { athleteId }, data });
}
