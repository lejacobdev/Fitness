import fs from 'node:fs';

import express from 'express';

import { createAppleKeyStore } from './lib/appleIdentity.js';
import { installAsyncRejectionForwarding } from './lib/asyncRejection.js';
import { athleteRouter } from './routes/athlete.js';
import { authRouter } from './routes/auth.js';
import { legalRouter } from './routes/legal.js';
import { syncRouter } from './routes/sync.js';

// §19: this must run before any route is registered. Installing it here, at
// module scope and above every import that registers routes, is deliberate.
installAsyncRejectionForwarding();

export function createApp({
  prisma,
  appleBundleId = process.env.APPLE_BUNDLE_ID,
  sessionSecret = process.env.SESSION_SECRET,
  appleKeyStore = createAppleKeyStore(),
  packsDir = process.env.PACKS_DIR,
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
    app.use('/auth', authRouter({ prisma, keyStore: appleKeyStore, appleBundleId, sessionSecret }));
  }

  if (prisma && sessionSecret) {
    app.use('/sync', syncRouter({ prisma, sessionSecret }));
    app.use('/athlete', athleteRouter({ prisma, sessionSecret }));
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
