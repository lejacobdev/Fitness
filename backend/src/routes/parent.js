import crypto from 'node:crypto';

import express from 'express';

import { requireAuth } from '../lib/requireAuth.js';

const TOKEN = /^[A-Za-z0-9_-]{32,64}$/;
const DAY_MS = 86_400_000;

function escape(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

/**
 * The parent's weekly summary. The athlete makes a private link in the app
 * and sends it to a parent; the page shows the last 7 days — check-ins,
 * sleep, readiness, training, upcoming games and (when the app has sent
 * it) Campus and Mindset progress — and never anything the athlete wrote.
 * The athlete can make a new link (the old one stops working) or switch it
 * off at any time.
 *
 *   GET    /parent-link        { url } or 404
 *   POST   /parent-link        make (or replace) the link → { url }
 *   DELETE /parent-link        switch it off
 *   GET    /parent/:token      the summary page (public, unlisted)
 */
export function parentRouter({ prisma, sessionSecret, publicBaseURL = process.env.PUBLIC_BASE_URL ?? 'https://api.lejacob.dev/fitness', now = () => new Date() }) {
  const router = express.Router();
  const auth = requireAuth({ sessionSecret });
  const urlFor = (token) => `${publicBaseURL.replace(/\/$/, '')}/parent/${token}`;

  router.get('/parent-link', auth, async (req, res) => {
    const link = await prisma.parentLink.findUnique({ where: { athleteId: req.athleteId } });
    if (!link) {
      res.status(404).json({ error: 'no_link' });
      return;
    }
    res.json({ url: urlFor(link.token) });
  });

  router.post('/parent-link', auth, async (req, res) => {
    const token = crypto.randomBytes(24).toString('base64url');
    await prisma.parentLink.deleteMany({ where: { athleteId: req.athleteId } });
    await prisma.parentLink.create({ data: { token, athleteId: req.athleteId } });
    res.status(201).json({ url: urlFor(token) });
  });

  router.delete('/parent-link', auth, async (req, res) => {
    await prisma.parentLink.deleteMany({ where: { athleteId: req.athleteId } });
    res.status(204).end();
  });

  router.get('/parent/:token', async (req, res) => {
    res.set('Cache-Control', 'no-store');
    res.set('X-Robots-Tag', 'noindex, nofollow');
    const token = req.params.token;
    const link = TOKEN.test(token) ? await prisma.parentLink.findUnique({ where: { token } }) : null;
    if (!link) {
      res.status(404).type('html').send(page('Link not found', '<section><p>This summary link was switched off or never existed. Ask your athlete to send a new one from the Athlete OS app (Me → Parent summary).</p></section>'));
      return;
    }
    const summary = await weeklySummary(prisma, link.athleteId, now());
    res.type('html').send(page('This week', renderSummary(summary)));
  });

  return router;
}

/** The last 7 days, from the rows the app already backs up. */
export async function weeklySummary(prisma, athleteId, today) {
  const end = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()) + DAY_MS);
  const start = new Date(end.getTime() - 7 * DAY_MS);
  const [checkIns, sessions, states] = await Promise.all([
    prisma.checkIn.findMany({ where: { athleteId, date: { gte: start, lt: end } } }),
    prisma.session.findMany({ where: { athleteId, startedAt: { gte: start, lt: end } } }),
    prisma.syncedState.findMany({ where: { athleteId, key: { in: ['competitions', 'summary'] } } }),
  ]);
  const state = Object.fromEntries(states.map((s) => [s.key, s.value]));
  const sleep = checkIns.map((c) => c.sleepHours).filter((h) => typeof h === 'number');
  const games = (Array.isArray(state.competitions) ? state.competitions : [])
    .map((g) => ({ date: new Date((g.date ?? 0) * 1000), kind: g.kind, isHome: g.isHome, notes: g.notes }))
    .filter((g) => g.date >= today)
    .sort((a, b) => a.date - b.date)
    .slice(0, 3);
  return {
    from: start,
    to: new Date(end.getTime() - DAY_MS),
    checkIns: checkIns.length,
    averageSleepHours: sleep.length ? sleep.reduce((a, b) => a + b, 0) / sleep.length : null,
    readiness: {
      green: checkIns.filter((c) => c.readinessBand === 'GREEN').length,
      amber: checkIns.filter((c) => c.readinessBand === 'AMBER').length,
      red: checkIns.filter((c) => c.readinessBand === 'RED').length,
    },
    lowEnergyDays: checkIns.filter((c) => c.energy <= 2).length,
    sessions: sessions.length,
    minutes: sessions.reduce((sum, s) => sum + (s.minutes ?? 0), 0),
    games,
    app: state.summary && typeof state.summary === 'object' ? state.summary : null,
  };
}

function renderSummary(s) {
  const fmt = (d) => d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', timeZone: 'UTC' });
  const stat = (value, label) => `<div class="stat"><b>${escape(value)}</b><span>${escape(label)}</span></div>`;
  const hours = s.averageSleepHours == null ? '—' : `${Math.floor(s.averageSleepHours)} h ${Math.round((s.averageSleepHours % 1) * 60)} m`;
  const parts = [];
  parts.push(`<p class="updated">${escape(fmt(s.from))} – ${escape(fmt(s.to))}</p>`);
  parts.push(`<section><h2>Training</h2><div class="stats">${stat(s.sessions, 'workouts')}${stat(s.minutes, 'minutes')}${stat(`${s.checkIns}/7`, 'morning check-ins')}</div></section>`);
  parts.push(`<section><h2>Sleep &amp; recovery</h2><div class="stats">${stat(hours, 'average sleep')}${stat(s.readiness.green, 'ready days')}${stat(s.readiness.amber + s.readiness.red, 'tired days')}</div>
    <p>Teenage athletes need about 8–10 hours of sleep. On tired days the app makes training lighter by itself.</p></section>`);
  if (s.lowEnergyDays >= 4) {
    parts.push(`<section class="warn"><h2>Low energy on ${escape(s.lowEnergyDays)} of 7 days</h2>
      <p>Feeling drained most days while training hard can mean not eating enough for the training, too little sleep, or illness. Worth a relaxed conversation — and a doctor or sports dietitian if it keeps going.</p></section>`);
  }
  if (s.games.length) {
    const rows = s.games.map((g) => `<li>${escape(fmt(g.date))} · ${escape(String(g.kind ?? 'GAME').toLowerCase())} · ${g.isHome ? 'home' : 'away'}${g.notes ? ` · ${escape(g.notes)}` : ''}</li>`).join('');
    parts.push(`<section><h2>Coming up</h2><ul>${rows}</ul></section>`);
  }
  if (s.app) {
    const a = s.app;
    const items = [];
    if (Number.isFinite(a.campusLessons)) items.push(stat(a.campusLessons, 'Campus lessons'));
    if (Number.isFinite(a.reflections)) items.push(stat(a.reflections, 'evening reflections'));
    if (Number.isFinite(a.focusDone) && Number.isFinite(a.focusTotal)) items.push(stat(`${a.focusDone}/${a.focusTotal}`, 'weekly goals done'));
    if (items.length) parts.push(`<section><h2>Learning &amp; mindset</h2><div class="stats">${items.join('')}</div></section>`);
    if (typeof a.testHeadline === 'string' && a.testHeadline) parts.push(`<section><h2>Latest tests</h2><p>${escape(a.testHeadline)}</p></section>`);
  }
  parts.push('<p class="foot">Shared from the Athlete OS app. Only numbers are shown — never anything your athlete wrote. They can switch this link off at any time.</p>');
  return parts.join('\n');
}

function page(title, body) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>${escape(title)} — Athlete OS</title>
<style>
  :root { color-scheme: light dark; --bg: #fff; --card: #f5f5f5; --ink: #111; --muted: #6e6e73; --red: #E5383B; }
  @media (prefers-color-scheme: dark) { :root { --bg: #000; --card: #141414; --ink: #fff; --muted: #9a9aa0; } }
  body { margin: 0; background: var(--bg); color: var(--ink); font: 17px/1.5 -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif; }
  main { max-width: 640px; margin: 0 auto; padding: 28px 18px 60px; }
  h1 { font-size: 36px; margin: 0; letter-spacing: -0.02em; }
  h1 span { color: var(--red); }
  .updated { color: var(--muted); margin: 4px 0 20px; }
  section { background: var(--card); border-radius: 24px; padding: 18px 20px; margin: 0 0 14px; }
  section.warn { border: 2px solid var(--red); }
  h2 { font-size: 20px; margin: 0 0 10px; }
  .stats { display: flex; gap: 12px; flex-wrap: wrap; }
  .stat { flex: 1 1 120px; }
  .stat b { display: block; font-size: 30px; }
  .stat span { color: var(--muted); font-size: 15px; }
  p { margin: 10px 0 0; }
  ul { margin: 0; padding-left: 20px; }
  .foot { color: var(--muted); font-size: 14px; margin-top: 24px; }
</style>
</head>
<body><main>
<h1>Athlete <span>OS</span> · ${escape(title)}</h1>
${body}
</main></body>
</html>`;
}
