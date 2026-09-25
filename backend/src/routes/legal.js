import express from 'express';

/**
 * §20/§21: the privacy policy, terms and support pages App Review requires
 * and the app's Me tab links to. Plain server-rendered HTML — no tracking, no
 * third-party scripts, no fonts from anywhere else, matching the app's own
 * "no third parties" rule.
 */

const UPDATED = '23 September 2026';

function page(title, body) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — Athlete OS</title>
<style>
  :root { color-scheme: light dark; --bg: #f4f4f6; --card: #fff; --ink: #111; --muted: #6e6e73; }
  @media (prefers-color-scheme: dark) { :root { --bg: #000; --card: #1c1c1e; --ink: #fff; --muted: #9a9aa0; } }
  body { margin: 0; background: var(--bg); color: var(--ink); font: 16px/1.55 -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif; }
  main { max-width: 720px; margin: 0 auto; padding: 32px 20px 64px; }
  h1 { font-size: 34px; margin: 0 0 4px; letter-spacing: -0.02em; }
  .updated { color: var(--muted); margin: 0 0 24px; }
  section { background: var(--card); border-radius: 24px; padding: 20px 22px; margin: 0 0 16px; box-shadow: 0 4px 12px rgba(0,0,0,.05); }
  h2 { font-size: 19px; margin: 0 0 8px; }
  p, li { color: var(--ink); opacity: .9; }
  ul { padding-left: 20px; margin: 8px 0; }
  a { color: var(--ink); }
  nav { display: flex; gap: 16px; margin-bottom: 28px; font-weight: 600; }
  nav a { text-decoration: none; color: var(--muted); }
</style>
</head>
<body><main>
<nav><a href="privacy">Privacy</a><a href="terms">Terms</a><a href="support">Support</a></nav>
<h1>${title}</h1>
<p class="updated">Last updated ${UPDATED}</p>
${body}
</main></body></html>`;
}

const PRIVACY = page('Privacy Policy', `
<section><h2>The short version</h2>
<p>Athlete OS is a training app for athletes aged 13 and up. We collect the minimum needed to keep your training plan and history safe across devices. We never sell your data, never show ads, never use third-party analytics or trackers, and never share anything with anyone.</p></section>
<section><h2>What we store</h2>
<ul>
<li><strong>Your Apple sign-in identifier</strong> — the anonymous ID Apple gives us. We never request your name or email.</li>
<li><strong>Your date of birth</strong> — only to keep training age-appropriate and to confirm you are 13 or older.</li>
<li><strong>Your training data</strong> — your sport, position, season dates, equipment, games, logged sessions and sets, and effort ratings.</li>
<li><strong>Your daily check-ins</strong> — sleep, soreness, energy and stress scores, and the readiness result calculated from them.</li>
</ul></section>
<section><h2>What we never collect</h2>
<ul><li>Your name, email address, phone number, contacts or photos.</li>
<li>Your location.</li>
<li>Advertising identifiers, or any data for advertising or marketing.</li></ul></section>
<section><h2>Apple Health</h2>
<p>If you allow it, the app reads your sleep from Apple Health to pre-fill your check-in, and writes your finished workouts back to Apple Health. Health data is used only inside the app to support your training. It is never used for advertising, never shared with third parties, and never sold.</p></section>
<section><h2>Where your data lives</h2>
<p>Everything is stored on your device first and works offline. When you are online it is backed up to our own server so it survives a new phone. The server is operated by the developer; no third-party processors are used.</p></section>
<section><h2>Deleting your data</h2>
<p>You can delete your account at any time in the app: <strong>Me → Delete account</strong>. This permanently deletes your account and every check-in, session, set, plan and game stored on our server, and removes the copy on your device. It is free and never behind a subscription.</p></section>
<section><h2>Not medical advice</h2>
<p>Athlete OS provides general training information. It never predicts injury, diagnoses anything, or advises on returning to play. Always follow your coach, athletic trainer or doctor.</p></section>
<section><h2>Changes</h2><p>If this policy changes, the new version will be posted here with a new date.</p></section>
`);

const TERMS = page('Terms of Use', `
<section><h2>Who can use the app</h2><p>You must be at least 13 years old. If you are under 18, use the app with the knowledge of a parent or guardian.</p></section>
<section><h2>Training information, not medical advice</h2>
<p>Plans, readiness suggestions, coaching messages and fuelling guidance are general information. They are not medical advice and do not replace your coach, athletic trainer, doctor or a registered dietitian. Stop exercising and tell an adult if something hurts. You train at your own discretion.</p></section>
<section><h2>Subscriptions</h2>
<p>Some features require Athlete OS Pro. Subscriptions are billed through your Apple ID, renew automatically unless cancelled at least 24 hours before the end of the current period, and can be managed or cancelled in your App Store account settings. The daily check-in, your training plan, logging and the Apple Watch app are free.</p></section>
<section><h2>Your content</h2><p>Your training data belongs to you. You can export it from Me → Export my data, and delete it at any time.</p></section>
<section><h2>Acceptable use</h2><p>Don't attempt to access other people's data, interfere with the service, or reverse-engineer it for that purpose.</p></section>
<section><h2>Availability</h2><p>The app is designed to work offline. The backup service is provided as-is and may occasionally be unavailable.</p></section>
`);

const SUPPORT = page('Support', `
<section><h2>Getting started</h2>
<p>Pick your sport, set your season dates and do the four-tap morning check-in. Your week is generated automatically and changes when you add a game on the Plan tab.</p></section>
<section><h2>Common questions</h2>
<ul>
<li><strong>My plan changed today.</strong> If your check-in was well below your normal, today's session is trimmed or swapped for mobility. Tap "Use the original session instead" to override.</li>
<li><strong>How do I add a game?</strong> Plan tab → Add a game, or the + button on Today.</li>
<li><strong>Does it work offline?</strong> Yes. Everything is saved on your phone and backs up next time you're online.</li>
<li><strong>How do I change my sport or equipment?</strong> Me → Training setup.</li>
<li><strong>How do I delete my account?</strong> Me → Delete account. It deletes everything, immediately.</li>
<li><strong>How do I cancel Pro?</strong> iPhone Settings → your name → Subscriptions.</li>
</ul></section>
<section><h2>Contact</h2>
<p>Use the "App Support" link on the Athlete OS App Store page to reach the developer.</p></section>
`);

export function legalRouter() {
  const router = express.Router();
  const send = (html) => (_req, res) => {
    res.set('Cache-Control', 'public, max-age=3600');
    res.type('html').send(html);
  };
  router.get('/privacy', send(PRIVACY));
  router.get('/terms', send(TERMS));
  router.get('/support', send(SUPPORT));
  return router;
}
