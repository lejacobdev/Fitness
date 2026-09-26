import assert from 'node:assert/strict';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { signSessionToken } from '../src/lib/sessionToken.js';
import { doseText } from '../src/routes/links.js';
import { cleanItems } from '../src/routes/workouts.js';

const SESSION_SECRET = 'test-session-secret';

/** Just the tables shared workouts and codes touch. */
function fakePrisma() {
  const db = { sharedWorkout: [], team: [], league: [] };
  const matches = (row, where = {}) => Object.entries(where).every(([k, v]) => row[k] === v);
  const client = { _db: db };
  for (const model of Object.keys(db)) {
    client[model] = {
      async findUnique({ where }) { return db[model].find((r) => matches(r, where)) ?? null; },
      async findMany({ where } = {}) { return db[model].filter((r) => matches(r, where)); },
      async count({ where } = {}) { return db[model].filter((r) => matches(r, where)).length; },
      async create({ data }) { const row = { createdAt: new Date(), ...data }; db[model].push(row); return row; },
      async deleteMany({ where }) {
        const before = db[model].length;
        db[model] = db[model].filter((r) => !matches(r, where));
        return { count: before - db[model].length };
      },
    };
  }
  return client;
}

async function serve(prisma) {
  const app = createApp({ prisma, sessionSecret: SESSION_SECRET, packsDir: undefined });
  const server = await new Promise((resolve) => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
  const url = `http://127.0.0.1:${server.address().port}`;
  const call = (athleteId, method, path, body) => fetch(`${url}${path}`, {
    method,
    headers: {
      ...(athleteId ? { authorization: `Bearer ${signSessionToken(athleteId, { secret: SESSION_SECRET })}` } : {}),
      'content-type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { url, call, close: () => new Promise((r) => server.close(r)) };
}

const legDay = {
  title: '  Leg   day ',
  sportSlug: 'soccer',
  items: [
    { itemSlug: 'nordic-hamstring-curl', dose: { kind: 'reps', sets: 3, reps: 5 }, restSec: 90 },
    { itemSlug: 'copenhagen-plank', dose: { kind: 'time', sets: 2, seconds: 20, perSide: true }, restSec: 45 },
  ],
};

test('shared workouts: share under a code, anyone opens it, only the owner stops sharing', async () => {
  const prisma = fakePrisma();
  const { call, close } = await serve(prisma);
  try {
    const created = await call('a1', 'POST', '/workouts/shared', legDay);
    assert.equal(created.status, 201);
    const { code, url } = await created.json();
    assert.match(code, /^[A-HJ-KM-NP-Z2-9]{6}$/);
    assert.equal(url, `https://api.lejacob.dev/fitness/workout/${code}`);

    // No account needed to open it; lower-case codes work.
    const opened = await (await call(null, 'GET', `/workouts/shared/${code.toLowerCase()}`)).json();
    assert.equal(opened.title, 'Leg day');
    assert.deepEqual(opened.items, legDay.items);
    assert.equal(opened.sportSlug, 'soccer');

    const mine = await (await call('a1', 'GET', '/workouts/shared')).json();
    assert.deepEqual(mine.workouts.map((w) => [w.code, w.itemCount]), [[code, 2]]);

    assert.equal((await call('a2', 'DELETE', `/workouts/shared/${code}`)).status, 404, 'not yours');
    assert.equal((await call('a1', 'DELETE', `/workouts/shared/${code}`)).status, 204);
    assert.equal((await call(null, 'GET', `/workouts/shared/${code}`)).status, 404);
  } finally {
    await close();
  }
});

test('shared workouts: sign-in required to share, and bad workouts are refused', async () => {
  const prisma = fakePrisma();
  const { call, close } = await serve(prisma);
  try {
    assert.equal((await call(null, 'POST', '/workouts/shared', legDay)).status, 401);
    assert.equal((await call('a1', 'POST', '/workouts/shared', { ...legDay, title: '' })).status, 400);
    assert.equal((await call('a1', 'POST', '/workouts/shared', { ...legDay, items: [] })).status, 400);
    const bad = [{ itemSlug: '../etc', dose: { kind: 'reps', sets: 3, reps: 5 }, restSec: 60 }];
    assert.equal((await call('a1', 'POST', '/workouts/shared', { ...legDay, items: bad })).status, 400);
    assert.equal(prisma._db.sharedWorkout.length, 0);
  } finally {
    await close();
  }
});

test('cleanItems keeps only known dose fields', () => {
  const items = cleanItems([{ itemSlug: 'push-up', dose: { kind: 'reps', sets: 3, reps: 10, evil: 'x' }, restSec: 60, extra: 1 }]);
  assert.deepEqual(items, [{ itemSlug: 'push-up', dose: { kind: 'reps', sets: 3, reps: 10 }, restSec: 60 }]);
  assert.equal(cleanItems([{ itemSlug: 'push-up', dose: { kind: 'reps', sets: 99 }, restSec: 60 }]), null);
  assert.equal(cleanItems([{ itemSlug: 'push-up', dose: { kind: 'swim', sets: 1 }, restSec: 60 }]), null);
});

test('codes: one lookup for teams, leagues and workouts', async () => {
  const prisma = fakePrisma();
  prisma._db.team.push({ id: 't1', code: 'TEAM22', name: 'Varsity' });
  prisma._db.league.push({ id: 'l1', code: 'GRPS22', name: 'U17 Girls' });
  const { call, close } = await serve(prisma);
  try {
    const { code } = await (await call('a1', 'POST', '/workouts/shared', legDay)).json();
    assert.deepEqual(await (await call(null, 'GET', '/codes/team22')).json(), { kind: 'team', name: 'Varsity' });
    assert.deepEqual(await (await call(null, 'GET', '/codes/GRPS22')).json(), { kind: 'league', name: 'U17 Girls' });
    assert.deepEqual(await (await call(null, 'GET', `/codes/${code}`)).json(), { kind: 'workout', name: 'Leg day' });
    assert.equal((await call(null, 'GET', '/codes/NOPE22')).status, 404);
    assert.equal((await call(null, 'GET', '/codes/0O1IL0')).status, 404, 'look-alike characters are never codes');
  } finally {
    await close();
  }
});

test('links: the page a link opens, and Apple\'s app-links file', async () => {
  const prisma = fakePrisma();
  prisma._db.team.push({ id: 't1', code: 'TEAM22', name: 'Varsity <b>' });
  const { call, close } = await serve(prisma);
  try {
    const { code } = await (await call('a1', 'POST', '/workouts/shared', legDay)).json();

    const teamPage = await call(null, 'GET', '/team/TEAM22');
    assert.equal(teamPage.status, 200);
    const html = await teamPage.text();
    assert.match(html, /aos:\/\/team\/TEAM22/, 'opens the app directly');
    assert.match(html, /Varsity &lt;b&gt;/, 'names are escaped');
    assert.match(html, /apple-itunes-app/);

    const workoutPage = await (await call(null, 'GET', `/workout/${code}`)).text();
    assert.match(workoutPage, /Nordic hamstring curl<\/b> — 3 sets of 5 reps/);
    assert.match(workoutPage, /2 sets of 20 seconds each side/);

    // A bare code link (…/c/CODE) opens whatever it is; a wrong kind is a 404.
    assert.equal((await call(null, 'GET', `/c/${code}`)).status, 200);
    assert.equal((await call(null, 'GET', `/league/${code}`)).status, 404);

    const aasa = await call(null, 'GET', '/.well-known/apple-app-site-association');
    assert.equal(aasa.status, 200);
    assert.match(aasa.headers.get('content-type'), /application\/json/);
    const body = await aasa.json();
    assert.deepEqual(body.applinks.details[0].appIDs, ['Y6QW849HK2.com.studentathlete.app']);
    assert.deepEqual(body.applinks.details[0].components.map((c) => c['/']),
      ['/fitness/team/*', '/fitness/league/*', '/fitness/workout/*', '/fitness/c/*']);
  } finally {
    await close();
  }
});

test('doseText reads like the app', () => {
  assert.equal(doseText({ kind: 'reps', sets: 3, reps: 8 }), '3 sets of 8 reps');
  assert.equal(doseText({ kind: 'time', sets: 1, seconds: 90, perSide: true }), '1 set of 1 min 30 s each side');
  assert.equal(doseText({ kind: 'distance', sets: 4, metres: 20 }), '4 times 20 m');
  assert.equal(doseText({ kind: 'contacts', sets: 2, contacts: 10 }), '2 sets of 10 jumps');
});
