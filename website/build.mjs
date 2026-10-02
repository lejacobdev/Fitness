// Builds the AthleteOS website into website/dist (plain static files).
//
//   node website/build.mjs            build
//   sudo website/deploy.sh            build and publish to /var/www/athleteos
//
// The legal pages come from the backend's own text (one source of truth).

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { PRIVACY_BODY, SUPPORT_BODY, TERMS_BODY, UPDATED } from '../backend/src/routes/legal.js';
import { SITE, layout } from './src/parts.mjs';
import * as pages from './src/pages.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = path.join(here, 'src');
const dist = path.join(here, 'dist');

fs.rmSync(dist, { recursive: true, force: true });
fs.mkdirSync(path.join(dist, 'assets'), { recursive: true });
fs.cpSync(path.join(src, 'assets'), path.join(dist, 'assets'), { recursive: true });
fs.copyFileSync(path.join(src, 'site.css'), path.join(dist, 'assets/site.css'));
fs.copyFileSync(path.join(src, 'site.js'), path.join(dist, 'assets/site.js'));
fs.copyFileSync(path.join(src, 'favicon.svg'), path.join(dist, 'favicon.svg'));
fs.copyFileSync(path.join(src, 'favicon.ico'), path.join(dist, 'favicon.ico'));

const version = crypto.createHash('sha256')
  .update(fs.readFileSync(path.join(src, 'site.css'))).update(fs.readFileSync(path.join(src, 'site.js')))
  .digest('hex').slice(0, 10);

// The backend's legal text links relatively ("support", "support/messages");
// on the site those live at /support/ and /fitness/support/messages.
const legalPage = (pathName, title, description, body) => ({
  path: pathName,
  title,
  description,
  body: `
<section class="page-hero"><div class="atmos"></div><div class="narrow">
  <p class="eyebrow">${title === 'Support' ? 'Help' : 'Legal'}</p>
  <h1 class="display" style="font-size:clamp(44px,6vw,80px)">${title}</h1>
  <p class="faint">Last updated ${UPDATED}</p>
</div></section>
<div class="narrow prose">${body
    .replace('action="support/messages"', 'action="/fitness/support/messages"')
    .replace('href="support"', 'href="/support/"')}</div>`,
});

const all = [
  pages.home, pages.features, pages.coaches, pages.parents, pages.safety, pages.pricing, pages.sports, pages.notFound,
  legalPage('/privacy/', 'Privacy Policy', 'How AthleteOS handles data: the minimum needed, no ads, no tracking, nothing sold, and deletion at any time.', PRIVACY_BODY),
  legalPage('/terms/', 'Terms of Use', 'The terms for using AthleteOS, its subscriptions and its community rules.', TERMS_BODY),
  legalPage('/support/', 'Support', 'Get help with AthleteOS: common questions and a form to contact us.', SUPPORT_BODY),
];

for (const page of all) {
  const html = layout(page).replaceAll('__V__', version);
  const file = page.path.endsWith('.html') ? page.path : `${page.path}index.html`;
  const target = path.join(dist, file);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, html);
}

const today = new Date().toISOString().slice(0, 10);
fs.writeFileSync(path.join(dist, 'sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${all.filter((p) => !p.path.endsWith('.html')).map((p) => `  <url><loc>${SITE}${p.path}</loc><lastmod>${today}</lastmod></url>`).join('\n')}
</urlset>
`);
fs.writeFileSync(path.join(dist, 'robots.txt'), `User-agent: *\nAllow: /\nDisallow: /fitness/\nDisallow: /coach/\nSitemap: ${SITE}/sitemap.xml\n`);
fs.writeFileSync(path.join(dist, 'site.webmanifest'), JSON.stringify({
  name: 'AthleteOS',
  short_name: 'AthleteOS',
  start_url: '/',
  display: 'standalone',
  background_color: '#050608',
  theme_color: '#050608',
  icons: [
    { src: '/assets/icon-192.png', sizes: '192x192', type: 'image/png' },
    { src: '/assets/icon-512.png', sizes: '512x512', type: 'image/png' },
  ],
}, null, 2));

console.log(`built ${all.length} pages into ${path.relative(process.cwd(), dist)} (assets v${version})`);
