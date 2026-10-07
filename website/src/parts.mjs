// Shared pieces of the AthleteOS website: layout, icons and the frames for
// real screenshots of the app (no stock art, no drawn mockups).

export const SITE = 'https://athleteos.lejacob.dev';
export const APP_STORE = 'https://apps.apple.com/app/id6814844837';
export const DASHBOARD = '/coach/';

// The app icon: a doubled ascending chevron on a deep blue-black tile (tools/generate-app-icon.py).
export const LOGO = '<svg viewBox="0 0 100 100" aria-hidden="true"><defs><linearGradient id="aos-g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#10131A"/><stop offset="1" stop-color="#1D2330"/></linearGradient></defs><rect width="100" height="100" rx="22" fill="url(#aos-g)"/><g fill="none" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"><path d="M28.5 47.3 50 32.3l21.5 15" stroke="#F5F7FA"/><path d="M28.5 67.8 50 52.8l21.5 15" stroke="#8B5CF6"/></g></svg>';

const APPLE = '<svg viewBox="0 0 24 24" aria-hidden="true" fill="currentColor"><path d="M16.37 12.6c-.02-2.2 1.8-3.26 1.88-3.31-1.03-1.5-2.62-1.7-3.18-1.72-1.35-.14-2.64.8-3.33.8-.69 0-1.74-.78-2.87-.76-1.47.02-2.83.86-3.59 2.18-1.53 2.66-.39 6.59 1.1 8.75.73 1.05 1.6 2.24 2.73 2.2 1.1-.05 1.51-.71 2.84-.71 1.32 0 1.7.71 2.86.69 1.18-.02 1.93-1.07 2.65-2.13.84-1.22 1.18-2.4 1.2-2.46-.03-.01-2.3-.88-2.32-3.5zM14.2 6.16c.6-.73 1.01-1.75.9-2.76-.87.04-1.92.58-2.54 1.31-.56.65-1.05 1.69-.92 2.68.97.08 1.96-.49 2.56-1.23z"/></svg>';

export const ICON = {
  check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
  calendar: '<rect x="3.5" y="5" width="17" height="15.5" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
  bolt: '<path d="M13 2.5 4.5 13.5H12l-1 8 8.5-11H12z"/>',
  heart: '<path d="M12 20s-7.5-4.6-7.5-10.1A4.4 4.4 0 0 1 12 7a4.4 4.4 0 0 1 7.5 2.9C19.5 15.4 12 20 12 20z"/>',
  book: '<path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v15H6.5A2.5 2.5 0 0 0 4 20.5zM4 20.5A2.5 2.5 0 0 0 6.5 23H20"/>',
  shield: '<path d="M12 3 4.5 6v6c0 4.6 3.2 7.9 7.5 9 4.3-1.1 7.5-4.4 7.5-9V6z"/><path d="M8.5 12l2.5 2.5 4.5-5"/>',
  lock: '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
  team: '<circle cx="9" cy="8" r="3.2"/><circle cx="17" cy="9.5" r="2.5"/><path d="M3 20c.6-3.4 3-5.5 6-5.5s5.4 2.1 6 5.5M15.5 14.7c2.6.1 4.6 1.9 5.2 4.8"/>',
  watch: '<rect x="6.5" y="6" width="11" height="12" rx="3.5"/><path d="M9 6l.7-3h4.6L15 6M9 18l.7 3h4.6l.7-3M12 9.5V12l1.8 1.2"/>',
  dumbbell: '<path d="M3 9.5v5M6 7.5v9M18 7.5v9M21 9.5v5M6 12h12"/>',
  moon: '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>',
  brain: '<path d="M9 4.5a3 3 0 0 0-3 3 3 3 0 0 0-2 5 3 3 0 0 0 2 5 3 3 0 0 0 3 2.5V4.5zM15 4.5a3 3 0 0 1 3 3 3 3 0 0 1 2 5 3 3 0 0 1-2 5 3 3 0 0 1-3 2.5V4.5z"/>',
  plane: '<path d="M10.5 13.5 3 11l1.5-1.5 8 1L17 6a2.1 2.1 0 0 1 3 3l-4.5 4.5 1 8L15 23l-2.5-7.5L9 19v2.5L7.5 23 6 19l-4-1.5L3.5 16H6z"/>',
  chart: '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
  family: '<circle cx="8" cy="6.5" r="2.5"/><circle cx="16" cy="6.5" r="2.5"/><circle cx="12" cy="13" r="2"/><path d="M4 20v-4.5A3.5 3.5 0 0 1 7.5 12h1M20 20v-4.5a3.5 3.5 0 0 0-3.5-3.5h-1M9 21v-2.5a3 3 0 0 1 6 0V21"/>',
  cross: '<path d="M9 3.5h6v5.5h5.5v6H15v5.5H9V15H3.5V9H9z"/>',
  qr: '<rect x="3.5" y="3.5" width="6.5" height="6.5" rx="1.5"/><rect x="14" y="3.5" width="6.5" height="6.5" rx="1.5"/><rect x="3.5" y="14" width="6.5" height="6.5" rx="1.5"/><path d="M14 14h2.5v2.5H14zM18 18h2.5v2.5H18zM14 18.5v2M18.5 14h2"/>',
  route: '<circle cx="6" cy="18" r="2.5"/><circle cx="18" cy="6" r="2.5"/><path d="M8.5 18H15a3 3 0 0 0 0-6H9a3 3 0 0 1 0-6h6.5"/>',
  sparkle: '<path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M18 6l-2.5 2.5M8.5 15.5 6 18"/>',
  mic: '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21"/>',
};

export function icon(name, color = '#a78bfa') {
  return `<svg viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICON[name]}</svg>`;
}

export function appStoreButton(extra = '') {
  return `<a class="btn white appstore ${extra}" href="${APP_STORE}" rel="noopener">${APPLE}<span><small>Download on the</small><b>App Store</b></span></a>`;
}

const NAV = [
  ['/features/', 'Features'],
  ['/coaches/', 'Coaches'],
  ['/parents/', 'Parents'],
  ['/safety/', 'Safety'],
  ['/pricing/', 'Pricing'],
];

export function layout({ path, title, description, body, ogTitle }) {
  const fullTitle = path === '/' ? title : `${title} — AthleteOS`;
  const canonical = `${SITE}${path}`;
  const nav = NAV.map(([href, label]) => `<a href="${href}"${path === href ? ' aria-current="page"' : ''}>${label}</a>`).join('');
  return `<!doctype html>
<html lang="en" class="no-js">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${fullTitle}</title>
<meta name="description" content="${description}">
<link rel="canonical" href="${canonical}">
<meta name="theme-color" content="#050608">
<meta name="color-scheme" content="dark">
<meta name="apple-itunes-app" content="app-id=6814844837">
<meta property="og:type" content="website">
<meta property="og:site_name" content="AthleteOS">
<meta property="og:title" content="${ogTitle ?? fullTitle}">
<meta property="og:description" content="${description}">
<meta property="og:url" content="${canonical}">
<meta property="og:image" content="${SITE}/assets/og.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="/favicon.ico" sizes="any">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/assets/apple-touch-icon.png">
<link rel="manifest" href="/site.webmanifest">
<link rel="preload" href="/assets/fonts/inter-var.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="/assets/site.css?v=__V__">
<script>document.documentElement.classList.remove('no-js')</script>
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="site-head">
  <div class="wrap">
    <a class="logo" href="/" aria-label="AthleteOS home">${LOGO}<span>AthleteOS</span></a>
    <nav class="menu" aria-label="Main">${nav}</nav>
    <div class="head-cta">
      <a class="btn small" href="${DASHBOARD}">Coach dashboard</a>
      <a class="btn small primary" href="${APP_STORE}" rel="noopener">Get the app</a>
    </div>
    <button class="burger" type="button" aria-label="Menu" aria-expanded="false" aria-controls="mobile-nav"><span></span></button>
  </div>
</header>
<nav class="mobile-nav" id="mobile-nav" aria-label="Mobile">${nav}<a href="${DASHBOARD}">Coach dashboard</a><a class="btn primary" href="${APP_STORE}" rel="noopener">Get AthleteOS</a></nav>
<main id="main">
${body}
</main>
<footer class="site-foot">
  <div class="wrap">
    <div class="foot-grid">
      <div>
        <a class="logo" href="/">${LOGO}<span>AthleteOS</span></a>
        <p class="muted" style="margin-top:18px;max-width:340px">Training built around a student athlete's real life — practices, games, exams and sleep.</p>
        <div style="margin-top:22px">${appStoreButton()}</div>
      </div>
      <div><h4>Product</h4><ul><li><a href="/features/">Features</a></li><li><a href="/pricing/">Pricing</a></li><li><a href="/safety/">Safety &amp; privacy</a></li><li><a href="/sports/">All 60 sports</a></li></ul></div>
      <div><h4>For</h4><ul><li><a href="/coaches/">Coaches</a></li><li><a href="/coaches/#trainers">Athletic trainers</a></li><li><a href="/parents/">Parents</a></li><li><a href="${DASHBOARD}">Coach dashboard</a></li></ul></div>
      <div><h4>Help</h4><ul><li><a href="/support/">Support</a></li><li><a href="/privacy/">Privacy</a></li><li><a href="/terms/">Terms</a></li></ul></div>
    </div>
    <div class="fine">
      <p>AthleteOS gives general training information for athletes 13 and up. It is not medical advice, never predicts injury, never clears anyone to return to play, and never replaces a coach, athletic trainer or doctor.</p>
      <p>© ${new Date().getFullYear()} AthleteOS</p>
    </div>
  </div>
</footer>
<script src="/assets/site.js?v=__V__" defer></script>
</body>
</html>
`;
}

// ---------- Real screenshots ----------
// Taken from the app itself (the screenshots workflow, demo data) and the real
// coach dashboard; regenerate with website/screens.py after UI changes.

export function phoneShot(name, alt, extra = '') {
  return `<div class="phone${extra ? ` ${extra}` : ''}"><img src="/assets/screens/${name}.webp" alt="${alt}" width="660" height="1434" loading="lazy" decoding="async"></div>`;
}

export function watchShot(name, alt) {
  return `<div class="watch"><img src="/assets/screens/${name}.webp" alt="${alt}" loading="lazy" decoding="async"></div>`;
}

export function dashboardShot() {
  return `<div class="browser"><div class="bar"><i></i><i></i><i></i><span>athleteos.lejacob.dev/coach</span></div><img src="/assets/screens/dashboard.webp" alt="The AthleteOS coach dashboard: today's readiness for every athlete on the team" width="1600" height="1111" loading="lazy" decoding="async"></div>`;
}
