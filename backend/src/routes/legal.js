import express from 'express';

/**
 * §20/§21: the privacy policy, terms and support pages App Review requires
 * and the app's Me tab links to. Plain server-rendered HTML — no tracking, no
 * third-party scripts, no fonts from anywhere else, matching the app's own
 * "no third parties" rule.
 */

const UPDATED = '25 September 2026';

function page(title, body) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — AthleteOS</title>
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
<p>AthleteOS is a training app for athletes aged 13 and up. We collect the minimum needed to keep your training plan and history safe across devices. We never sell your data, never show ads, never use third-party analytics or trackers, and never share anything with anyone.</p></section>
<section><h2>What we store</h2>
<ul>
<li><strong>Your Apple sign-in identifier</strong> — the anonymous ID Apple gives us. We never request your name or email.</li>
<li><strong>Your date of birth</strong> — only to keep training age-appropriate and to confirm you are 13 or older.</li>
<li><strong>Your training data</strong> — your sport, position, season dates, equipment, games, logged sessions and sets, and effort ratings.</li>
<li><strong>Your daily check-ins</strong> — sleep, soreness, energy and stress scores, and the readiness result calculated from them.</li>
<li><strong>Your app progress and settings</strong> — Campus lessons, XP and badges, test results, season goals, evening reflections, day status, practice days, meals you logged and reminder times — so they come back on a new phone.</li>
<li><strong>Calendar links you connect</strong> — the link to a team or school calendar, so your phone can read games, practices and exams from it.</li>
<li><strong>Leagues and teams you join</strong> — the nickname you choose and which league or team you're in. League members see your nickname and weekly Campus XP; a coach whose team you join sees your nickname, whether you checked in, your readiness band and how many workouts and minutes you logged that week. Never anything you wrote.</li>
<li><strong>Workouts you share</strong> — when you share a workout with a code, its name and exercises are stored under that code, and anyone who has the code, link or QR code can open it. Nothing else about you is attached. Stop sharing it any time, or delete your account.</li>
<li><strong>A parent summary link</strong>, if you make one — a private link to a page with this week's numbers (training, sleep, check-ins, upcoming games, Campus and Mindset counts). You can switch it off at any time.</li>
</ul></section>
<section><h2>What we never collect</h2>
<ul><li>Your name, email address, phone number, contacts or photos. Jump-test videos are filmed and measured on your phone and never uploaded.</li>
<li>Your location.</li>
<li>Advertising identifiers, or any data for advertising or marketing.</li></ul></section>
<section><h2>Apple Health</h2>
<p>If you allow it, the app reads your sleep and resting heart rate from Apple Health to pre-fill your check-in, and writes your finished workouts back to Apple Health. Hours slept are stored with your check-in; heart rate is only used on your phone. Health data is used only inside the app to support your training. It is never used for advertising, never shared with third parties, and never sold.</p></section>
<section><h2>Using the app without an account</h2>
<p>If you continue without an account, everything stays on your device and nothing is sent to our server. Signing in with Apple later backs it up.</p></section>
<section><h2>Reports and messages</h2>
<p>If you report content, we store what you reported and when, linked to your account, to review it. Messages sent through the Support page are stored with the email address you give, only to answer you.</p></section>
<section><h2>Where your data lives</h2>
<p>Everything is stored on your device first and works offline. When you are online it is backed up to our own server so it survives a new phone. The server is operated by the developer; no third-party processors are used.</p></section>
<section><h2>Deleting your data</h2>
<p>You can delete your account at any time in the app: <strong>Me → Delete account</strong>. This permanently deletes your account and every check-in, session, set, plan, game, backup, league and team membership, shared workout and parent link stored on our server, revokes Sign in with Apple, and removes the copy on your device. It is free and never behind a subscription. <strong>Me → Log out</strong> backs everything up and removes it from the device without deleting your account.</p></section>
<section><h2>Not medical advice</h2>
<p>AthleteOS provides general training information. It never predicts injury, diagnoses anything, or clears anyone to return to play — its concussion page explains the usual steps and says a doctor decides. Always follow your coach, athletic trainer or doctor.</p></section>
<section><h2>Changes</h2><p>If this policy changes, the new version will be posted here with a new date.</p></section>
`);

const TERMS = page('Terms of Use', `
<section><h2>Who can use the app</h2><p>You must be at least 13 years old. If you are under 18, use the app with the knowledge of a parent or guardian.</p></section>
<section><h2>Training information, not medical advice</h2>
<p>Plans, readiness suggestions, coaching messages and fuelling guidance are general information. They are not medical advice and do not replace your coach, athletic trainer, doctor or a registered dietitian. Stop exercising and tell an adult if something hurts. You train at your own discretion.</p></section>
<section><h2>Subscriptions</h2>
<p>Some features require AthleteOS Pro (monthly or yearly). Prices are shown in the app in your currency before you buy. Payment is charged to your Apple ID at confirmation of purchase. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period; your account is charged for renewal within 24 hours before the end of the period. Manage or cancel any time in your App Store account settings. An introductory price, when offered, applies once to new subscribers and is followed by the regular price. The daily check-in, your plan and all three kinds of workout, logging, the Apple Watch app, fuelling, safety features, daily Campus lessons, sport guides, leagues and teams are free.</p></section>
<section><h2>Community rules</h2>
<p>Nicknames, league, team and workout names and coach notes can be seen by other people. There is no tolerance for objectionable content or abusive users: no insults, hate, harassment, sexual content, or anything you wouldn't say in front of your team. Names are checked when you save them. You can report a name, league, team or shared workout and block a player; reports are reviewed within 24 hours, objectionable content is removed and accounts that break these rules are closed.</p></section>
<section><h2>Your content</h2><p>Your training data belongs to you. You can export it from Me → Export my data, and delete it at any time.</p></section>
<section><h2>Acceptable use</h2><p>Don't attempt to access other people's data, interfere with the service, or reverse-engineer it for that purpose. Follow the community rules above.</p></section>
<section><h2>Contact</h2><p>Questions or problems: use the form on the <a href="support">Support page</a>.</p></section>
<section><h2>Availability</h2><p>The app is designed to work offline. The backup service is provided as-is and may occasionally be unavailable.</p></section>
`);

const SUPPORT = page('Support', `
<section><h2>Getting started</h2>
<p>Pick your sport and position, set your season and practice days, and do the two-tap morning check-in. Your workouts are built around your practices, games and exams — and you can change any of them.</p></section>
<section><h2>Common questions</h2>
<ul>
<li><strong>Do I need an account?</strong> No — tap "Continue without an account". Sign in with Apple any time in Me → Account to back up, join a team or league and share workouts.</li>
<li><strong>Where are my workouts?</strong> The Workout tab: after practice, gym day, and stretching &amp; mobility. "See it" shows a workout, "Change it" lets you swap exercises.</li>
<li><strong>My workout is lighter today.</strong> Your check-in was below your normal, so it was eased. You can switch back to the full version on the Workout tab.</li>
<li><strong>How do I add a game or practice?</strong> The Progress tab → Schedule &amp; events, or connect your team's calendar link.</li>
<li><strong>How do I join my coach's team?</strong> Me → My team → enter the code, or open the link or QR code your coach sent.</li>
<li><strong>How do I report or block someone?</strong> Long-press their name in a league to report or block them; shared workouts and teams have a Report button.</li>
<li><strong>Does it work offline?</strong> Yes. Everything is saved on your phone and backs up next time you're online.</li>
<li><strong>How do I delete my account?</strong> Me → Delete account. It deletes everything, immediately.</li>
<li><strong>How do I cancel Pro?</strong> iPhone Settings → your name → Subscriptions.</li>
</ul></section>
<section><h2>Contact us</h2>
<p>Write to us here — we read every message and reply within a few days if you leave your email address.</p>
<form method="post" action="support/messages">
<p><label>Your email (optional)<br><input type="email" name="email" autocomplete="email" style="width:100%;font:inherit;padding:10px;border-radius:12px;border:1px solid #999"></label></p>
<p><label>Message<br><textarea name="message" rows="6" required minlength="5" style="width:100%;font:inherit;padding:10px;border-radius:12px;border:1px solid #999"></textarea></label></p>
<p><button type="submit" style="font:inherit;font-weight:700;padding:12px 22px;border-radius:999px;border:0;background:#111;color:#fff">Send</button></p>
</form></section>
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
