import assert from 'node:assert/strict';
import test from 'node:test';

import { createApp } from '../src/app.js';

test('privacy, terms and support pages are served as HTML without any database', async () => {
  const app = createApp({});
  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });
  const { port } = server.address();
  try {
    for (const [path, heading] of [['/privacy', 'Privacy Policy'], ['/terms', 'Terms of Use'], ['/support', 'Support']]) {
      const res = await fetch(`http://127.0.0.1:${port}${path}`);
      assert.equal(res.status, 200, path);
      assert.match(res.headers.get('content-type'), /text\/html/);
      const body = await res.text();
      assert.ok(body.includes(`<h1>${heading}</h1>`), path);
      assert.ok(!/<script/i.test(body), `${path} must not load any script`);
    }
  } finally {
    await new Promise((r) => server.close(r));
  }
});

test('the privacy policy states account deletion and no third parties', async () => {
  const app = createApp({});
  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });
  const { port } = server.address();
  try {
    const body = await (await fetch(`http://127.0.0.1:${port}/privacy`)).text();
    assert.ok(body.includes('Delete account'));
    assert.ok(body.includes('never shared with third parties'));
  } finally {
    await new Promise((r) => server.close(r));
  }
});
