// The real coach dashboard (backend/web/dashboard) with sample data, for the website.
//   PLAYWRIGHT_CORE=/path/to/playwright-core/index.mjs node website/dashboard-shot.mjs out.png
import fs from 'node:fs';
import path from 'node:path';

const { chromium } = await import(process.env.PLAYWRIGHT_CORE ?? 'playwright-core');
const DIR = new URL('../backend/web/dashboard/', import.meta.url).pathname;
const OUT = process.argv[2];
const names = ['Maya','Alex','Jordan','Sam','Riley','Chris','Jamie','Drew','Kai','Noor','Eli','Taylor','Avery','Quinn','Rowan','Sage'];
const bands = ['GREEN','GREEN','RED','AMBER',null,'GREEN','GREEN','AMBER','GREEN','GREEN','GREEN','PAUSED','GREEN',null,'GREEN','AMBER'];
const members = names.map((n, i) => {
  const b = bands[i];
  return {
    memberId: 'm' + i, nickname: n, checkedInToday: b !== null && b !== 'PAUSED', readiness: b === 'PAUSED' ? null : b,
    health: b === 'PAUSED' ? { paused: true, rtpStep: 2 } : (n === 'Jordan' ? { pain: { areas: ['Knee'] } } : {}),
    sessionsThisWeek: [3,2,1,2,0,3,2,1,4,2,3,0,2,1,3,2][i], minutesThisWeek: [95,60,40,70,0,110,75,35,140,60,90,0,70,30,100,55][i],
    checkInsThisWeek: [3,3,2,3,1,3,3,2,3,3,3,1,3,1,3,2][i], missedThisWeek: 0, sharesHealth: i % 3 !== 1,
    trend: Array.from({ length: 14 }, (_, d) => ['GREEN','GREEN','AMBER','GREEN',null,'GREEN','RED'][(d + i) % 7]),
  };
});
const routes = {
  '/fitness/teams': { coaching: [{ id: 't1', name: 'Varsity Soccer', memberCount: 16, code: 'K7MP3Q' }, { id: 't2', name: 'JV Soccer', memberCount: 14, code: 'R2XW9D' }], trainer: [], member: [] },
  '/fitness/teams/t1/readiness': { members },
  '/fitness/athlete/me': { displayName: 'Coach Rivera' },
};
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 }, deviceScaleFactor: 2, colorScheme: 'dark' });
await page.addInitScript(() => localStorage.setItem('aos.dashboard.session', JSON.stringify({ token: 'demo', expiresAt: Date.now() + 3600e3 })));
await page.route('http://aos.test/**', async (route) => {
  const url = new URL(route.request().url());
  if (url.pathname.startsWith('/fitness/dashboard/')) {
    const file = path.join(DIR, url.pathname.replace('/fitness/dashboard/', '') || 'index.html');
    const type = file.endsWith('.js') ? 'text/javascript' : file.endsWith('.css') ? 'text/css' : file.endsWith('.svg') ? 'image/svg+xml' : file.endsWith('.woff2') ? 'font/woff2' : 'text/html';
    return route.fulfill({ status: 200, contentType: type, body: fs.readFileSync(fs.existsSync(file) && fs.statSync(file).isFile() ? file : path.join(DIR, 'index.html')) });
  }
  const data = routes[url.pathname];
  if (data) return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(data) });
  return route.fulfill({ status: 404, contentType: 'application/json', body: '{}' });
});
await page.goto('http://aos.test/fitness/dashboard/#/team/t1/today');
await page.waitForSelector('.tile');
await page.waitForTimeout(800);
await page.screenshot({ path: OUT });
await browser.close();
