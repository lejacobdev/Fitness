import assert from 'node:assert/strict';
import test from 'node:test';

import express from 'express';

import { installAsyncRejectionForwarding } from '../src/lib/asyncRejection.js';

installAsyncRejectionForwarding();

/** Start an app on an ephemeral port and return its base URL plus a closer. */
async function serve(app) {
  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });
  const { port } = server.address();
  return {
    url: `http://127.0.0.1:${port}`,
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

test('a rejected async handler reaches the error middleware instead of hanging', async () => {
  const app = express();
  app.get('/boom', async () => {
    throw new Error('rejected on purpose');
  });
  let sawError;
  app.use((err, _req, res, _next) => {
    sawError = err.message;
    res.status(500).json({ error: 'internal' });
  });

  const { url, close } = await serve(app);
  try {
    const res = await fetch(`${url}/boom`, { signal: AbortSignal.timeout(2000) });
    assert.equal(res.status, 500);
    assert.equal(sawError, 'rejected on purpose');
  } finally {
    await close();
  }
});

test('a rejected async handler inside a Router is forwarded too', async () => {
  const app = express();
  const router = express.Router();
  router.post('/nested', async () => {
    throw new Error('nested rejection');
  });
  app.use('/api', router);
  app.use((err, _req, res, _next) => res.status(503).json({ error: err.message }));

  const { url, close } = await serve(app);
  try {
    const res = await fetch(`${url}/api/nested`, {
      method: 'POST',
      signal: AbortSignal.timeout(2000),
    });
    assert.equal(res.status, 503);
    assert.deepEqual(await res.json(), { error: 'nested rejection' });
  } finally {
    await close();
  }
});

test('synchronous throws and normal responses are unaffected', async () => {
  const app = express();
  app.get('/sync-throw', () => {
    throw new Error('sync');
  });
  app.get('/fine', (_req, res) => res.json({ ok: true }));
  app.use((err, _req, res, _next) => res.status(500).json({ error: err.message }));

  const { url, close } = await serve(app);
  try {
    const thrown = await fetch(`${url}/sync-throw`, { signal: AbortSignal.timeout(2000) });
    assert.equal(thrown.status, 500);
    const fine = await fetch(`${url}/fine`, { signal: AbortSignal.timeout(2000) });
    assert.deepEqual(await fine.json(), { ok: true });
  } finally {
    await close();
  }
});

test('middleware arity is preserved, so error handlers stay error handlers', async () => {
  // A 4-arity handler wrapped down to 3 arity would silently stop being error
  // middleware and every failure would fall through to Express's default page.
  const app = express();
  app.get('/boom', async () => {
    throw new Error('arity');
  });
  app.use(async (err, _req, res, _next) => {
    // Async error middleware: only reachable if arity survived the wrap.
    await Promise.resolve();
    res.status(418).json({ error: err.message });
  });

  const { url, close } = await serve(app);
  try {
    const res = await fetch(`${url}/boom`, { signal: AbortSignal.timeout(2000) });
    assert.equal(res.status, 418);
    assert.deepEqual(await res.json(), { error: 'arity' });
  } finally {
    await close();
  }
});
