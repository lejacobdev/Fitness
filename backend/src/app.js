import fs from 'node:fs';

import express from 'express';

import { createAppleKeyStore } from './lib/appleIdentity.js';
import { createAppStoreVerifier } from './lib/appStoreJws.js';
import { installAsyncRejectionForwarding } from './lib/asyncRejection.js';
import { athleteRouter } from './routes/athlete.js';
import { authRouter } from './routes/auth.js';
import { billingRouter } from './routes/billing.js';
import { communityRouter } from './routes/community.js';
import { leaguesRouter } from './routes/leagues.js';
import { legalRouter } from './routes/legal.js';
import { linksRouter } from './routes/links.js';
import { parentRouter } from './routes/parent.js';
import { knowledgeRouter } from './routes/knowledge.js';
import { partnerRouter } from './routes/partner.js';
import { stateRouter } from './routes/state.js';
import { syncRouter } from './routes/sync.js';
import { teamsRouter } from './routes/teams.js';
import { workoutsRouter } from './routes/workouts.js';
import { webLoginRouter } from './routes/weblogin.js';
import { createAppleRevoker } from './lib/appleRevoke.js';

// §19: this must run before any route is registered. Installing it here, at
// module scope and above every import that registers routes, is deliberate.
installAsyncRejectionForwarding();

export function createApp({
  prisma,
  appleBundleId = process.env.APPLE_BUNDLE_ID,
  sessionSecret = process.env.SESSION_SECRET,
  appleKeyStore = createAppleKeyStore(),
  packsDir = process.env.PACKS_DIR,
  appStoreVerifier = createAppStoreVerifier(),
  appleRevoker = createAppleRevoker(),
  webDir = process.env.WEB_DIR ?? new URL('../web', import.meta.url).pathname,
} = {}) {
  const app = express();

  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use(express.json({ limit: '1mb' }));

  // Liveness: no database. Answers "is the process up" for the container check.
  app.get('/health', (_req, res) => {
    res.json({ ok: true, service: 'student-athlete', version: process.env.APP_VERSION ?? 'dev' });
  });

  // Readiness: touches the database, so a redeploy against an unmigrated or
  // unreachable database fails the check instead of serving errors.
  app.get('/ready', async (_req, res) => {
    if (!prisma) {
      res.status(503).json({ ok: false, error: 'no_database' });
      return;
    }
    await prisma.$queryRaw`SELECT 1`;
    res.json({ ok: true });
  });

  app.use(legalRouter());

  if (prisma && appleBundleId && sessionSecret) {
    app.use('/auth', authRouter({ prisma, keyStore: appleKeyStore, appleBundleId, sessionSecret, appleRevoker }));
  }

  // §18: the only writer of proUntil. Mounted at the spec's path and at the
  // shorter one configured in App Store Connect.
  if (prisma) {
    const billing = billingRouter({ prisma, verifier: appStoreVerifier, bundleId: appleBundleId });
    app.use('/billing/appstore/notify', billing);
    app.use('/appstore/notifications', billing);
  }

  if (prisma && sessionSecret) {
    app.use('/sync', syncRouter({ prisma, sessionSecret }));
    app.use('/sync', stateRouter({ prisma, sessionSecret }));
    app.use('/athlete', athleteRouter({ prisma, sessionSecret, appleRevoker }));
    app.use('/leagues', leaguesRouter({ prisma, sessionSecret }));
    app.use('/teams', teamsRouter({ prisma, sessionSecret }));
    app.use('/workouts', workoutsRouter({ prisma, sessionSecret }));
    app.use(communityRouter({ prisma, sessionSecret }));
    app.use(parentRouter({ prisma, sessionSecret }));
    app.use(knowledgeRouter({ prisma }));
    app.use('/partner', partnerRouter({ prisma, sessionSecret }));
    app.use(webLoginRouter({ prisma, sessionSecret }));
  }

  // Codes as links: Apple's app-links file, the code lookup, and the pages a
  // link opens when the app isn't installed. Public; no sign-in.
  if (prisma) {
    app.use(linksRouter({ prisma, packsDir }));
  }

  // §3: "content packs, per-sport bundles, versioned and served over HTTPS
  // with an ETag" — express.static's conditional-GET support (ETag,
  // If-None-Match, 304) is exactly this, so there is no hand-rolled caching
  // logic here. packsDir is built by content/scripts/build.mjs; when it does
  // not exist (a dev environment that has never run `npm run build` in
  // content/) this route simply 404s every request rather than crashing the
  // whole app, since packs are one of four responsibilities, not a
  // precondition for the other three to work.
  if (packsDir && fs.existsSync(packsDir)) {
    app.use('/packs', express.static(packsDir, { etag: true, index: false }));
  }

  // The coach dashboard (a static page; it calls this API with a session
  // from the QR sign-in). /dashboard → /dashboard/ so relative paths work.
  if (webDir && fs.existsSync(webDir)) {
    app.get('/dashboard', (_req, res) => res.redirect(301, 'dashboard/'));
    app.use('/dashboard', express.static(`${webDir}/dashboard`, {
      etag: true,
      setHeaders: (res) => {
        res.set('Cache-Control', 'no-cache');
        res.set('X-Frame-Options', 'DENY');
        res.set('Referrer-Policy', 'no-referrer');
        res.set('Content-Security-Policy', "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; connect-src 'self'; frame-ancestors 'none'");
      },
    }));
  }

  app.use((_req, res) => {
    res.status(404).json({ error: 'not_found' });
  });

  // Error middleware is last and takes four arguments. The message is never
  // echoed to the client: a stack or a Prisma error can quote row contents, and
  // this database holds minors' wellness data (§20).
  app.use((err, _req, res, _next) => {
    const status = Number.isInteger(err?.status) ? err.status : 500;
    if (status >= 500) {
      console.error('[error]', err?.code ?? err?.name ?? 'unknown', err?.message ?? '');
    }
    res.status(status).json({ error: err?.publicCode ?? 'internal' });
  });

  return app;
}
