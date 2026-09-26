import fs from 'node:fs';
import path from 'node:path';

import express from 'express';

import { CODE } from '../lib/codes.js';

function escape(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

/** "3 sets of 8 reps", as the app says it (DoseFormatter.text). */
export function doseText(dose = {}) {
  const side = dose.perSide ? ' each side' : '';
  const sets = dose.sets === 1 ? '1 set' : `${dose.sets} sets`;
  const duration = (s) => (s < 60 ? `${s} seconds` : (s % 60 === 0 ? `${s / 60} min` : `${Math.floor(s / 60)} min ${s % 60} s`));
  switch (dose.kind) {
    case 'reps': return `${sets} of ${dose.reps ?? 0} reps${side}`;
    case 'time': return `${sets} of ${duration(dose.seconds ?? 0)}${side}`;
    case 'distance': return `${dose.sets === 1 ? '1 time' : `${dose.sets} times`} ${Math.round(dose.metres ?? 0)} m`;
    case 'contacts': return `${sets} of ${dose.contacts ?? 0} jumps`;
    default: return sets;
  }
}

/** Exercise names from the content packs (slug → name), read once. */
function nameLookup(packsDir) {
  let names = null;
  return (slug) => {
    if (!names) {
      names = new Map();
      try {
        for (const file of fs.readdirSync(packsDir ?? '')) {
          if (!file.endsWith('.json') || file === 'manifest.json') continue;
          const pack = JSON.parse(fs.readFileSync(path.join(packsDir, file), 'utf8'));
          for (const item of pack.items ?? []) names.set(item.slug, item.name);
        }
      } catch {
        // No packs (tests, a fresh checkout): names fall back to the slug.
      }
    }
    return names.get(slug) ?? slug.split('-').map((w, i) => (i === 0 ? w[0].toUpperCase() + w.slice(1) : w)).join(' ');
  };
}

/**
 * Every code is also a link. These are the public pieces behind that:
 *
 *   GET /.well-known/apple-app-site-association
 *       Apple's list of the app's links, so https://api.lejacob.dev/fitness/
 *       team|league|workout|c/<code> opens the app when it's installed.
 *       Apache serves it at the domain root (deploy/apache/aasa-location.conf).
 *   GET /codes/:code          → { kind: team|league|workout, name }
 *   GET /team|league|workout|c/:code
 *       The page a link opens when the app isn't installed (or the link was
 *       typed into Safari): the code, "Open in AthleteOS" and the App Store.
 */
export function linksRouter({
  prisma,
  packsDir = process.env.PACKS_DIR,
  appIDs = (process.env.APPLE_APP_IDS ?? 'Y6QW849HK2.com.studentathlete.app').split(',').map((s) => s.trim()).filter(Boolean),
  appStoreId = process.env.APP_STORE_ID ?? '6814844837',
}) {
  const router = express.Router();
  const nameOf = nameLookup(packsDir);

  const aasa = {
    applinks: {
      details: [{
        appIDs,
        components: ['team', 'league', 'workout', 'c'].map((kind) => ({ '/': `/fitness/${kind}/*`, comment: `${kind} codes` })),
      }],
    },
  };
  const sendAASA = (_req, res) => {
    res.set('Cache-Control', 'public, max-age=3600');
    res.type('application/json').send(JSON.stringify(aasa));
  };
  router.get('/.well-known/apple-app-site-association', sendAASA);
  router.get('/apple-app-site-association', sendAASA);

  async function lookUp(code) {
    if (!CODE.test(code)) return null;
    const workout = await prisma.sharedWorkout.findUnique({ where: { code } });
    if (workout) return { kind: 'workout', name: workout.title, workout };
    const team = await prisma.team.findUnique({ where: { code } });
    if (team) return { kind: 'team', name: team.name };
    const league = await prisma.league.findUnique({ where: { code } });
    if (league) return { kind: 'league', name: league.name };
    return null;
  }

  router.get('/codes/:code', async (req, res) => {
    const found = await lookUp(String(req.params.code).toUpperCase());
    if (!found) {
      res.status(404).json({ error: 'not_found' });
      return;
    }
    res.json({ kind: found.kind, name: found.name });
  });

  for (const kind of ['team', 'league', 'workout', 'c']) {
    router.get(`/${kind}/:code`, async (req, res) => {
      res.set('Cache-Control', 'no-store');
      res.set('X-Robots-Tag', 'noindex, nofollow');
      const code = String(req.params.code).toUpperCase();
      const found = await lookUp(code);
      if (!found || (kind !== 'c' && found.kind !== kind)) {
        res.status(404).type('html').send(page({
          title: 'Code not found',
          body: '<section><p>No team, league or workout has this code. Check it with whoever sent it — codes are 6 letters and numbers.</p></section>',
          appStoreId,
        }));
        return;
      }
      const appLink = `aos://${found.kind}/${code}`;
      const heading = {
        team: `Join the team “${escape(found.name)}”`,
        league: `Join the league “${escape(found.name)}”`,
        workout: `Workout: “${escape(found.name)}”`,
      }[found.kind];
      const how = {
        team: 'In the app: Me → My team → enter the code.',
        league: 'In the app: Campus → trophy → Join → enter the code.',
        workout: 'In the app: Workout → My workouts → Add with a code.',
      }[found.kind];
      const exercises = found.kind === 'workout'
        ? `<section><h2>${found.workout.items.length} exercises</h2><ol>${found.workout.items
          .map((item) => `<li><b>${escape(nameOf(item.itemSlug))}</b> — ${escape(doseText(item.dose))}</li>`).join('')}</ol></section>`
        : '';
      res.type('html').send(page({
        title: heading,
        appStoreId,
        appArgument: `https://api.lejacob.dev/fitness/${found.kind}/${code}`,
        body: `<section class="code"><div class="big">${code}</div>
<a class="button" href="${appLink}">Open in AthleteOS</a>
<p>${how}</p></section>
${exercises}
<section><p>Don't have AthleteOS yet? <a href="https://apps.apple.com/app/id${escape(appStoreId)}">Get it on the App Store</a>, then open this link again or enter the code.</p></section>`,
      }));
    });
  }

  return router;
}

function page({ title, body, appStoreId, appArgument }) {
  const banner = appStoreId
    ? `<meta name="apple-itunes-app" content="app-id=${escape(appStoreId)}${appArgument ? `, app-argument=${escape(appArgument)}` : ''}">`
    : '';
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
${banner}
<title>${title.replace(/<[^>]+>/g, '')} — AthleteOS</title>
<style>
  :root { color-scheme: light dark; --bg: #fff; --card: #f5f5f5; --ink: #111; --muted: #6e6e73; --red: #E5383B; }
  @media (prefers-color-scheme: dark) { :root { --bg: #000; --card: #141414; --ink: #fff; --muted: #9a9aa0; } }
  body { margin: 0; background: var(--bg); color: var(--ink); font: 17px/1.5 -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif; }
  main { max-width: 640px; margin: 0 auto; padding: 28px 18px 60px; }
  .brand { font-weight: 800; letter-spacing: -0.01em; } .brand span { color: var(--red); }
  h1 { font-size: 32px; margin: 8px 0 18px; letter-spacing: -0.02em; line-height: 1.15; }
  section { background: var(--card); border-radius: 24px; padding: 18px 20px; margin: 0 0 14px; }
  section.code { text-align: center; }
  .big { font: 800 48px/1.1 ui-monospace, SFMono-Regular, Menlo, monospace; letter-spacing: 0.12em; margin: 6px 0 16px; }
  .button { display: block; background: var(--ink); color: var(--bg); text-decoration: none; font-weight: 700; padding: 16px; border-radius: 999px; }
  h2 { font-size: 20px; margin: 0 0 10px; }
  ol { margin: 0; padding-left: 22px; } li { margin: 4px 0; }
  p { margin: 12px 0 0; color: var(--muted); }
  a { color: inherit; }
</style>
</head>
<body><main>
<div class="brand">Athlete <span>OS</span></div>
<h1>${title}</h1>
${body}
</main></body>
</html>`;
}
