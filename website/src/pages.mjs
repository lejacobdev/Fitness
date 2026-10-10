import { APP_STORE, DASHBOARD, LOGO, appStoreButton, dashboardShot, icon, phoneShot, watchShot } from './parts.mjs';

export const SPORTS = ['Archery', 'Badminton', 'Baseball', 'Basketball', 'BMX', 'Boccia', 'Bowling', 'Climbing', 'Color Guard', 'Competitive Dance / Drill', 'Competitive Cheer / Spirit', 'Cross Country', 'Strength & Conditioning Team', 'Cycling', 'Disc Golf', 'Equestrian', 'Esports (Physical Conditioning)', 'Fencing', 'Field Hockey', 'Flag Football', 'Football', 'Goalball', 'Golf', 'Gymnastics', 'Ice Hockey', 'Indoor Track & Field', 'Judo', 'Lacrosse', 'Marching Band (Physical Conditioning)', 'Mountain Biking', 'Netball', 'Orienteering', 'Pickleball', 'Powerlifting', 'Racquetball', 'Rifle', 'Rowing / Crew', 'Rugby', 'Sailing', 'Skateboarding', 'Skiing', 'Snowboarding', 'Soccer', 'Softball', 'Spikeball (Roundnet)', 'Squash', 'Step / Dance Team', 'Surfing', 'Swimming', 'Table Tennis', 'Team Handball', 'Tennis', 'Track & Field', 'Triathlon', 'Ultimate (Frisbee)', 'Unified Sports', 'Volleyball', 'Water Polo', 'Weightlifting', 'Wrestling'];

const esc = (s) => s.replace(/&/g, '&amp;');
const half = Math.ceil(SPORTS.length / 2);
const marqueeRow = (list, reverse = false) => `<div class="marquee${reverse ? ' reverse' : ''}" aria-hidden="true"><div class="track">${[...list, ...list].map((s) => `<span class="tag">${esc(s)}</span>`).join('')}</div></div>`;

const feature = (_icon, title, text) => `<div class="reveal"><dt>${title}</dt><dd>${text}</dd></div>`;

const cta = (title = 'Your season, <em>planned around you.</em>', text = 'Free to download. The check-in, your plan, every kind of workout, the Watch app and daily lessons stay free.') => `
<section class="band tight"><div class="wrap"><div class="glass cta-band reveal">
  <div class="chevron-mark">${LOGO}</div>
  <h2 class="big">${title}</h2>
  <p class="lede" style="margin-inline:auto">${text}</p>
  <div class="ctas">${appStoreButton()}<a class="btn" href="/features/">See every feature <span class="arrow">→</span></a></div>
</div></div></section>`;

const faq = (items) => `<div class="faq">${items.map(([q, a]) => `<details class="reveal"><summary>${q}</summary><div>${a}</div></details>`).join('')}</div>`;

// ---------------------------------------------------------------- Home
export const home = {
  path: '/',
  title: 'AthleteOS — Training built around your real life',
  description: 'AthleteOS is the training app for student athletes 13+: workouts built around your practices, games, exams and sleep, a two-tap check-in, 1,000+ exercises and drills for 60 sports, and bite-size lessons.',
  body: `
<section class="hero">
  <div class="atmos"></div><div class="grid-lines"></div>
  <div class="wrap">
    <div>
      <p class="eyebrow">For student athletes 13+</p>
      <h1 class="display">Train around your <em>real life.</em></h1>
      <p class="lede">Practices, games, exams, a short night. AthleteOS builds today's training around all of it — and tells you why it looks the way it does.</p>
      <div class="ctas">${appStoreButton()}<a class="btn" href="#how">How it works <span class="arrow">→</span></a></div>
      <p class="hero-note">iPhone, iPad and Apple Watch · Free to start · No ads, no tracking</p>
    </div>
    <div class="device-stage">${phoneShot('workout', 'AthleteOS Workout tab: today\'s session, how long it takes and why', 'back')}${phoneShot('home', 'AthleteOS Home: the day, what is done and what is next', 'tilt')}</div>
  </div>
</section>

<section class="band tight"><div class="wrap">
  <div class="section-head reveal"><p class="eyebrow">Three things, every day</p><h2 class="big">Build the athlete. <em>Teach the athlete.</em> Adapt.</h2></div>
  <div class="pillars">
    <div class="pillar reveal"><span class="n">01</span><h3>Workout</h3><p class="q">What should I physically do today?</p><p>A session built around your practice, games, season and how you feel — with the reason it looks the way it does.</p></div>
    <div class="pillar reveal"><span class="n">02</span><h3>Campus</h3><p class="q">What should I understand?</p><p>About 100 short lessons in nine areas, from training science to sleep, psychology and supplements — picked for your day.</p></div>
    <div class="pillar reveal"><span class="n">03</span><h3>Reflection</h3><p class="q">How should tomorrow adapt?</p><p>Forty-five seconds in the evening. How it felt shapes tomorrow's plan.</p></div>
  </div>
</div></section>

<section class="band tight" id="how"><div class="wrap">
  <p class="quote-line reveal">Prepare in the morning. Perform at practice and in the gym. Reflect in the evening. <span>Tomorrow adapts.</span></p>
  <div class="loop reveal" style="margin-top:48px">
    <div style="--seg:var(--water)"><b>Prepare</b><p>A two-tap check-in — pre-filled from Apple Watch or any band that writes to Apple Health.</p></div>
    <div style="--seg:var(--red)"><b>Perform</b><p>After-practice strength, a gym development day, conditioning or mobility — whatever today calls for.</p></div>
    <div style="--seg:#a78bfa"><b>Reflect</b><p>Three to five quick questions. Sometimes one small insight back.</p></div>
    <div style="--seg:var(--green)"><b>Adapt</b><p>Hard practice, a game tomorrow, a short night: the next plan already knows.</p></div>
  </div>
</div></section>

<section class="wrap"><div class="stats reveal">
  <div class="stat"><b>60</b><span>sports, with their formats and positions</span></div>
  <div class="stat"><b>1,000+</b><span>exercises and drills with how-tos</span></div>
  <div class="stat"><b>~100</b><span>Campus lessons in nine areas</span></div>
  <div class="stat"><b>45 s</b><span>for the evening reflection</span></div>
</div></section>

<section class="band"><div class="wrap split">
  <div class="reveal">
    <p class="eyebrow">Built around your schedule</p>
    <h2 class="big">Your calendar <em>writes the plan.</em></h2>
    <p class="lede">Connect your team or school calendar and games, practices and exams come in by themselves.</p>
    <ul class="checks">
      <li><span><b>Practice cancelled?</b> It becomes a gym day.</span></li>
      <li><span><b>Exam week?</b> Training gets lighter, automatically.</span></li>
      <li><span><b>Game Saturday?</b> Heavy legs stay early in the week; game-day warm-up is ready.</span></li>
      <li><span><b>Sick, travelling, on holiday?</b> One tap and the plan backs off — then eases you back in.</span></li>
    </ul>
    <a class="btn" href="/features/#schedule">More about scheduling <span class="arrow">→</span></a>
  </div>
  <div class="device-stage reveal">${phoneShot('schedule', 'AthleteOS schedule: team and school calendars, practice days, exam weeks and school hours')}</div>
</div></section>

<section class="band tight" aria-label="Sports">
  <div class="wrap section-head center reveal" style="margin-bottom:36px"><p class="eyebrow">60 sports</p><h2 class="big">Your sport. <em>Your position.</em></h2><p class="lede">Drills only from your sport, position drills only for your position. Plus a researched guide for 29 of them.</p></div>
  ${marqueeRow(SPORTS.slice(0, half))}<div style="height:12px"></div>${marqueeRow(SPORTS.slice(half), true)}
  <div class="wrap" style="text-align:center;margin-top:32px"><a class="btn" href="/sports/">See all 60 sports <span class="arrow">→</span></a></div>
</section>

<section class="band"><div class="wrap">
  <div class="section-head reveal"><p class="eyebrow">Around the three pillars</p><h2 class="big">The rest of <em>the system.</em></h2></div>
  <dl class="flat">
    ${feature('dumbbell', 'Three kinds of workout', 'After practice, gym day, stretching &amp; mobility. Swap any exercise; Pro edits every set and rep.')}
    ${feature('book', 'Off-season programs', 'Six-week blocks for speed, strength, power or conditioning when your season ends.')}
    ${feature('watch', 'Apple Watch', 'Train from your wrist: heart rate live, rep counting, rest timers. Log without your phone.')}
    ${feature('brain', 'Mindset', 'Season goals, guided breathing, reset routines and game-day visualization.')}
    ${feature('plane', 'Tournament mode', 'Between games, sleep in a new time zone, food on the road and a hotel-room workout.')}
    ${feature('team', 'Train together', 'Same workout, each on your own phone — see how far your teammates are.')}
    ${feature('mic', 'Siri &amp; Shortcuts', '"Start my workout", "Check in", "What\'s my plan today?" — hands-free.')}
  </dl>
</div></section>

<section class="band"><div class="wrap split flip">
  <div class="reveal">
    <p class="eyebrow">Apple Watch</p>
    <h2 class="big">Leave the phone <em>in the bag.</em></h2>
    <p class="lede">Your workout on your wrist: the exercise, the set, the rest timer and your heart rate. Tap “Count my reps” and the Watch counts them for you — you can always correct the number.</p>
    <ul class="checks"><li><span>Pre-fills your check-in from sleep and resting heart rate</span></li><li><span>Workouts go back to Apple Health</span></li><li><span>Your emergency card, one tap away</span></li></ul>
  </div>
  <div class="device-stage reveal" style="min-height:440px">${watchShot('watch', 'AthleteOS on Apple Watch: today at a glance')}</div>
</div></section>

<section class="band"><div class="wrap split">
  <div class="reveal">
    <p class="eyebrow">For coaches &amp; athletic trainers</p>
    <h2 class="big">The whole team, <em>at a glance.</em></h2>
    <p class="lede">Who's ready, who's tired, who didn't check in — before practice starts. On the phone, on an iPad on the sideline, or on a computer.</p>
    <ul class="checks">
      <li><span><b>Readiness board</b> from morning check-ins, free</span></li>
      <li><span><b>Return-to-play log</b> for the athletic trainer</span></li>
      <li><span><b>Announcements, private notes and workouts</b> sent to the team</span></li>
    </ul>
    <div class="ctas"><a class="btn primary" href="/coaches/">For coaches <span class="arrow">→</span></a><a class="btn" href="${DASHBOARD}">Open the dashboard</a></div>
  </div>
  <div class="reveal">${dashboardShot()}</div>
</div></section>

<section class="band"><div class="wrap">
  <div class="section-head center reveal"><p class="eyebrow">Safety first. Private by design.</p><h2 class="big">Built for <em>teenagers.</em> Not for ad money.</h2></div>
  <dl class="flat">
    ${feature('shield', 'It never plays doctor', 'Head knock? Training pauses and the return-to-play steps are explained. Your doctor decides — the app never clears anyone.')}
    ${feature('heart', 'Fuel, don\'t diet', 'No calorie counting, no weight-loss goals, no body-shaming numbers. Eat enough to train and grow.')}
    ${feature('lock', 'No ads. No tracking.', 'No ad SDKs, no analytics companies, nothing sold. Use it without an account at all.')}
  </dl>
  <div style="text-align:center;margin-top:36px" class="reveal"><a class="btn" href="/safety/">How we keep athletes safe <span class="arrow">→</span></a></div>
</div></section>

<section class="band tight"><div class="narrow">
  <div class="section-head center reveal"><p class="eyebrow">Questions</p><h2 class="big">Good to know.</h2></div>
  ${faq([
    ['Is AthleteOS free?', 'Yes. The check-in, your plan and all three kinds of workout, logging, the Apple Watch app, safety features, three new Campus lessons a day, sport guides, leagues and teams are free. <a href="/pricing/">AthleteOS Pro</a> adds the workout editor, unlimited lessons, full history and more.'],
    ['Who is it for?', 'Middle school, high school and college athletes from 13 up, in any of 60 sports — whether you train in a gym or have nothing but a park.'],
    ['Do I need an account?', 'No. Everything works on your phone without one. Sign in with Apple when you want a backup, a team, a league or the parent summary.'],
    ['Does it replace my coach?', 'No — it works with your coach. It fills the gap between practices, and your coach can see your readiness and send you workouts if you join their team.'],
    ['Does it work with Strava, TeamSnap or GameChanger?', 'Team and school calendars connect with a calendar link — TeamSnap, GameChanger, school sites and Google Calendar all offer one. Runs and rides from other apps arrive through Apple Health.'],
  ])}
</div></section>
${cta()}`,
};

// ---------------------------------------------------------------- Features
export const features = {
  path: '/features/',
  title: 'Features',
  description: 'Every AthleteOS feature: the daily check-in, workouts around practices and games, 1,000+ exercises and drills, schedule sync, Campus lessons, mindset tools, Apple Watch, teams and safety.',
  body: `
<section class="page-hero"><div class="atmos"></div><div class="wrap">
  <p class="eyebrow">Features</p>
  <h1 class="display">Everything between <em>practices.</em></h1>
  <p class="lede">A plan that adapts every day, the knowledge to understand it, and the tools to stay healthy for the whole season.</p>
</div></section>

<section class="band tight" id="today"><div class="wrap split">
  <div class="reveal">
    <p class="eyebrow">Home</p><h2 class="big">Your day <em>in one screen.</em></h2>
    <ul class="checks">
      <li><span><b>Two-tap morning check-in</b> — pre-filled from Apple Watch, WHOOP, Oura, Garmin or any band that writes to Apple Health</span></li>
      <li><span><b>Readiness in words</b>, never a fake percentage</span></li>
      <li><span><b>“Why it looks like this”</b> — every plan change explains itself</span></li>
      <li><span><b>Day status</b>: sick, travelling, holiday, campus visit or a head knock — one tap</span></li>
      <li><span><b>Back after illness</b>: a gentle five-day return instead of jumping straight back in</span></li>
      <li><span><b>Long school day?</b> Tell it when school ends and late days get shorter sessions</span></li>
    </ul>
  </div>
  <div class="device-stage reveal">${phoneShot('home', 'AthleteOS Home: the day, the check-in and the next session', 'tilt')}</div>
</div></section>

<div class="wrap divider"></div>

<section class="band tight" id="training"><div class="wrap">
  <div class="section-head reveal"><p class="eyebrow">Training</p><h2 class="big">Workouts that <em>fit the day.</em></h2></div>
  <dl class="flat">
    ${feature('bolt', 'After practice', 'Short strength and injury prevention when you\'ve already trained with the team.', '#ff8a3d')}
    ${feature('dumbbell', 'Gym day', 'The full session on days without practice — built for your sport\'s demands.')}
    ${feature('sparkle', 'Stretching &amp; mobility', 'A quick wake-up before practice, a calm wind-down in the evening.', '#22d3ee')}
  </dl>
  <dl class="flat" style="margin-top:18px">
    ${feature('chart', 'Experience levels', 'New lifters start with less; experienced lifters get more.')}
    ${feature('route', 'Off-season programs', 'Six-week blocks for acceleration, top speed, strength, power, conditioning or mobility.')}
    ${feature('team', 'Train together', 'Start a workout with a code; partners join on their phones and see each other\'s progress.')}
    ${feature('dumbbell', 'Muscle-picker routines', 'Pick the muscles, get a balanced routine — with advice when one side is getting neglected.')}
    ${feature('book', '1,000+ exercises', 'Every one with set-up, cues, common mistakes, easier and harder versions, and an animated how-to.')}
    ${feature('chart', 'Tests every 6–8 weeks', 'Jump, sprints, plank, push-ups and a test for your sport — progress you can see.')}
    ${feature('lock', 'Your own workouts', 'Build, save and share workouts with a code or QR. (Pro)')}
    ${feature('plane', 'Tournament mode', 'Time zones, sleep, food on the road and a hotel-room workout between games.')}
  </dl>
</div></section>

<div class="wrap divider"></div>

<section class="band tight" id="schedule"><div class="wrap split flip">
  <div class="reveal">
    <p class="eyebrow">Schedule</p><h2 class="big">Games, practices, <em>exams.</em></h2>
    <p class="lede">Paste the calendar link from your team app or school site once. Everything after that is automatic.</p>
    <ul class="checks">
      <li><span>Works with TeamSnap, GameChanger, SportsEngine, school calendars, Google and iCloud calendar links</span></li>
      <li><span>Cancelled practice → gym day. Exam week → lighter training.</span></li>
      <li><span>Season, off-season and pre-season phases change the plan</span></li>
      <li><span>Month view with every activity colour-coded</span></li>
    </ul>
  </div>
  <div class="device-stage reveal">${phoneShot('schedule', 'AthleteOS schedule: team and school calendars, practice days, exam weeks and school hours')}</div>
</div></section>

<div class="wrap divider"></div>

<section class="band tight" id="campus"><div class="wrap split">
  <div class="reveal">
    <p class="eyebrow">Campus</p><h2 class="big">Learn something <em>useful today.</em></h2>
    <p class="lede">About 100 short lessons in nine areas and five levels — from foundations to coaching yourself. Each one: a hook, the idea, an athlete's example and what it means for you.</p>
    <ul class="checks"><li><span><b>Recommended for your day</b> — a short night, a game tomorrow, a hard practice</span></li><li><span><b>Supplements, explained honestly</b> — evidence, risks and marketing; never "take this"</span></li><li><span><b>Phones, attention and sleep</b> — without the scare stories</span></li><li><span>Spaced review so it sticks; XP and badges stay in the background</span></li></ul>
  </div>
  <div class="device-stage reveal">${phoneShot('campus', 'AthleteOS Campus: short lessons in nine areas')}</div>
</div></section>

<div class="wrap divider"></div>

<section class="band tight" id="reflection"><div class="narrow">
  <p class="eyebrow">Reflection</p><h2 class="big">Forty-five seconds <em>that change tomorrow.</em></h2>
  <p class="lede">Three to five short questions in the evening — how hard today felt, how your body feels, how practice went, what went well, what to improve. It's how AthleteOS learns you.</p>
  <dl class="flat one">
    <div class="reveal"><dt>It adapts</dt><dd>“Practice felt harder than usual today. Tomorrow's supplemental session has been adjusted.”</dd></div>
    <div class="reveal"><dt>It notices</dt><dd>“You rated practice great three times this week. What did you do differently?”</dd></div>
    <div class="reveal"><dt>It never nags</dt><dd>Rest days ask less. “Nothing to review today” is always an answer.</dd></div>
  </dl>
</div></section>

<div class="wrap divider"></div>

<section class="band tight" id="more"><div class="wrap">
  <div class="section-head reveal"><p class="eyebrow">And</p><h2 class="big">The rest of <em>the season.</em></h2></div>
  <dl class="flat">
    ${feature('brain', 'Mindset', 'Evening reflection, season goals, breathing, game-day visualization and optional mental skills — with “did it help?”.')}
    ${feature('moon', 'Sleep &amp; wind-down', 'Plain sleep tips and a calm half-hour routine before bed.', '#1cb0f6')}
    ${feature('chart', 'Season review', 'At the end of a season: what went well, what you\'d change, and what\'s next.')}
    ${feature('heart', 'Fuel', 'Simple meals around training and games. No calorie counting, ever.')}
    ${feature('cross', 'Emergency card', 'Allergies, conditions and who to call — on your lock-screen widget and your Watch. Stays on your device.')}
    ${feature('watch', 'Apple Watch', 'Live heart rate, rep counting, rest timers and complications.')}
    ${feature('family', 'Parent summary', 'A weekly email or private link with numbers only — never what you wrote.')}
    ${feature('mic', 'Siri &amp; Shortcuts', 'Start a workout, check in or hear today\'s plan without opening the app.')}
  </dl>
</div></section>
${cta()}`,
};

// ---------------------------------------------------------------- Coaches
export const coaches = {
  path: '/coaches/',
  title: 'For coaches & athletic trainers',
  description: 'AthleteOS for coaches and athletic trainers: a free readiness board from morning check-ins, a return-to-play log, announcements, private notes and workouts — on iPhone, iPad and the web.',
  body: `
<section class="page-hero"><div class="atmos"></div><div class="grid-lines"></div><div class="wrap">
  <p class="eyebrow">For coaches &amp; athletic trainers</p>
  <h1 class="display">Know your team <em>before practice.</em></h1>
  <p class="lede">Your athletes check in every morning. You see who's ready, who's tired and who needs a conversation — without a single group chat.</p>
  <div class="ctas"><a class="btn primary" href="${DASHBOARD}">Open the coach dashboard <span class="arrow">→</span></a>${appStoreButton()}</div>
</div></section>

<section class="wrap reveal">${dashboardShot()}</section>

<section class="band"><div class="wrap">
  <div class="section-head reveal"><p class="eyebrow">Set up in two minutes</p><h2 class="big">Code in. <em>Done.</em></h2></div>
  <div class="flow">
    <div class="glass card reveal"><h3>Create a team</h3><p>In the app: Me → Coach mode → New team. You get a six-character code, a link and a QR code.</p></div>
    <div class="glass card reveal"><h3>Athletes join</h3><p>They scan the QR or type the code and pick a nickname. No emails, no phone numbers, no rosters to import.</p></div>
    <div class="glass card reveal"><h3>Watch the board</h3><p>Morning check-ins fill the board. Open it on your phone, an iPad on the sideline, or the web dashboard.</p></div>
  </div>
</div></section>

<section class="band tight"><div class="wrap">
  <div class="section-head reveal"><p class="eyebrow">What you get</p><h2 class="big">Free for <em>every coach.</em></h2></div>
  <dl class="flat">
    ${feature('chart', 'Readiness board', 'Today\'s readiness in words, a 14-day trend, check-ins missed, and workouts and minutes this week.')}
    ${feature('qr', 'Sideline mode', 'Full-screen tiles on an iPad or laptop that refresh every minute and keep the screen on.')}
    ${feature('sparkle', 'Announcements', 'One-way messages on every athlete\'s Home for 14 days. No replies, no chat to moderate.')}
    ${feature('heart', 'Private notes', 'Specific, private notes to one athlete. Praise that lands, without a public ranking.')}
    ${feature('dumbbell', 'Send workouts', 'Pick exercises from the library and send them for a day — they appear ready to start. (Pro)')}
    ${feature('team', 'CSV export', 'Download the week from the web dashboard for your own records.')}
  </dl>
</div></section>

<section class="band" id="trainers"><div class="wrap split">
  <div class="reveal">
    <p class="eyebrow">For athletic trainers</p>
    <h2 class="big">A return-to-play log <em>that athletes see.</em></h2>
    <p class="lede">The coach makes an athletic-trainer code; you join with it. You see health — and only health — for athletes who chose to share it.</p>
    <ul class="checks">
      <li><span><b>Pain reports</b>: where, how much, and how many days in the last two weeks</span></li>
      <li><span><b>Training pauses</b> after a head injury, with the date</span></li>
      <li><span><b>Record the return-to-play step</b> (1–6) with a note — the athlete sees it in their app</span></li>
      <li><span><b>History</b> of every recorded step, newest first</span></li>
    </ul>
    <p class="faint">You decide the step. AthleteOS only records it — it never clears anyone to play.</p>
  </div>
  <div class="glass card lit reveal">
    <p class="eyebrow">Return to play</p>
    <h3 style="font-size:28px">Jordan</h3>
    <p class="muted">Paused since Mon, Sep 28</p>
    <div style="display:grid;gap:8px;margin-top:20px">
      ${[[1, "Everyday activity that doesn't make symptoms worse", 'done'], [2, 'Light exercise', 'done'], [3, 'Sport-specific exercise', 'on'], [4, 'Non-contact training drills', ''], [5, 'Full-contact practice — after a doctor clears them', ''], [6, 'Back to games', '']]
    .map(([n, t, s]) => `<div style="display:flex;gap:14px;align-items:center;padding:12px 14px;border-radius:14px;border:1px solid ${s === 'on' ? 'rgba(167,139,250,.6)' : 'var(--hair)'};background:${s === 'on' ? 'rgba(139,92,246,.12)' : 'var(--fill)'};${s === '' ? 'opacity:.55' : ''}"><b style="width:28px;height:28px;border-radius:50%;display:grid;place-items:center;flex:none;background:${s === 'on' ? '#fff' : 'rgba(255,255,255,.08)'};color:${s === 'on' ? '#050608' : '#fff'}">${n}</b><span>${t}</span></div>`).join('')}
    </div>
  </div>
</div></section>

<section class="band tight"><div class="wrap split flip">
  <div class="reveal">
    <p class="eyebrow">Privacy for your athletes</p>
    <h2 class="big">They share <em>what they choose.</em></h2>
    <ul class="checks">
      <li><span>By joining, an athlete shares their nickname, check-in status, readiness band and how much they trained.</span></li>
      <li><span>Health is <b>off by default</b> — each athlete turns it on per team.</span></li>
    </ul>
    <ul class="checks no">
      <li><span>Coaches never see notes, reflections, food or anything an athlete wrote.</span></li>
      <li><span>No ads, no data sold, no third-party trackers.</span></li>
    </ul>
  </div>
  <div class="glass card reveal">
    <p class="eyebrow">Web dashboard</p>
    <h3 style="font-size:28px">No password. Ever.</h3>
    <p class="muted">Open the dashboard on any computer, scan the QR code with your iPhone camera and approve it in AthleteOS. You're signed in for 12 hours, and a photo of the screen can't sign anyone else in.</p>
    <a class="btn primary" href="${DASHBOARD}" style="margin-top:12px">Open the dashboard <span class="arrow">→</span></a>
  </div>
</div></section>

<section class="band tight"><div class="narrow">
  <div class="section-head center reveal"><p class="eyebrow">Questions</p><h2 class="big">Coaches ask.</h2></div>
  ${faq([
    ['What does it cost a coach?', 'Nothing for the readiness board, sideline mode, the web dashboard, announcements, notes and the athletic-trainer log. Sending workouts to the team is part of AthleteOS Pro. For a whole program, <a href="/support/">ask us about team codes</a>.'],
    ['How many athletes and teams?', 'Up to 80 athletes per team and 10 teams per coach, with up to 5 staff.'],
    ['Can athletes see each other?', 'No. Only the coach and athletic trainer see the board. Athletes see announcements and their own private notes.'],
    ['Do my athletes need Pro?', 'No. Everything a team needs from an athlete — the check-in, the plan, workouts you send — is free for them.'],
    ['Is it a medical tool?', 'No. It shows what athletes report and what the athletic trainer records. It never diagnoses, predicts injury or clears anyone to return to play.'],
  ])}
</div></section>
${cta('Bring your team <em>onto one screen.</em>', 'Download AthleteOS, open Coach mode, and give your athletes the code.')}`,
};

// ---------------------------------------------------------------- Parents
export const parents = {
  path: '/parents/',
  title: 'For parents',
  description: 'AthleteOS for parents: age-appropriate training for athletes 13+, a weekly numbers-only summary, no ads, no tracking, no diet culture, and safety rules that never play doctor.',
  body: `
<section class="page-hero"><div class="atmos"></div><div class="wrap">
  <p class="eyebrow">For parents</p>
  <h1 class="display">Training that's <em>right for their age.</em></h1>
  <p class="lede">Your athlete gets a plan that respects school, sleep and growing bodies. You get a weekly summary — and peace of mind about what the app does and doesn't do.</p>
  <div class="ctas">${appStoreButton()}</div>
</div></section>

<section class="band tight"><div class="wrap">
  <dl class="flat">
    ${feature('shield', 'Age-appropriate', 'Exercises carry a minimum age and supervision level. New lifters start light; nothing is maxed out.')}
    ${feature('heart', 'No diet culture', 'No calorie counting, no weight-loss goals, no body measurements. The food guidance is about eating enough.')}
    ${feature('moon', 'School and sleep first', 'Exam weeks get lighter, short nights get easier days, and there\'s a wind-down routine for bedtime.', '#1cb0f6')}
    ${feature('cross', 'Head injury rules', 'A head knock pauses training. The return-to-play steps are explained, and a doctor decides — never the app.')}
    ${feature('lock', 'No ads, no tracking', 'No advertising, no analytics companies, no data sold. It works without an account at all.')}
    ${feature('family', 'Weekly summary', 'Sunday email or private link: training, sleep, check-ins and upcoming games. Numbers only — never what they wrote.')}
  </dl>
</div></section>

<section class="band tight"><div class="wrap split">
  <div class="reveal">
    <p class="eyebrow">The weekly summary</p>
    <h2 class="big">Stay in the loop, <em>not in their diary.</em></h2>
    <p class="lede">Your athlete adds your email in the app (Me → Parent summary). You confirm it once, then get a short email every Sunday. One link stops it.</p>
    <ul class="checks"><li><span>Workouts and minutes trained</span></li><li><span>Average sleep and check-ins</span></li><li><span>Upcoming games</span></li><li><span>Campus lessons and mindset sessions — as counts</span></li></ul>
    <ul class="checks no"><li><span>Reflections, notes, moods or anything they wrote</span></li></ul>
  </div>
  <div class="glass card lit reveal">
    <p class="faint" style="margin:0 0 6px;font-size:13px">Sunday 6:00 PM · from AthleteOS</p>
    <h3 style="font-size:26px">Maya's week</h3>
    <div style="display:grid;grid-template-columns:repeat(2,1fr);gap:12px;margin-top:20px">
      ${[['4', 'workouts · 140 min'], ['7h 50m', 'average sleep'], ['6 of 7', 'morning check-ins'], ['Sat', 'next game']].map(([n, l]) => `<div style="padding:16px;border-radius:16px;background:var(--fill)"><b style="font-size:28px;letter-spacing:-.03em">${n}</b><div class="muted" style="font-size:14px">${l}</div></div>`).join('')}
    </div>
  </div>
</div></section>

<section class="band tight"><div class="narrow">
  <div class="section-head center reveal"><p class="eyebrow">Questions</p><h2 class="big">Parents ask.</h2></div>
  ${faq([
    ['How old does my child need to be?', '13 or older. The app asks for a birth date at the start and keeps training age-appropriate.'],
    ['What data does it collect?', 'The minimum: an anonymous Apple sign-in ID (if they sign in), birth date, training and check-in data. Never their name, email, phone number, contacts, photos or location. <a href="/privacy/">Read the privacy policy</a>.'],
    ['Can strangers contact my child?', 'No. There is no chat and no messaging. Coaches can send one-way announcements and private notes to teams your child chose to join with a code.'],
    ['What does Pro cost?', '$2.99 a month or $24.99 a year, with an introductory offer for new subscribers. It\'s billed through Apple, so Family Sharing purchase approval (“Ask to Buy”) works. <a href="/pricing/">See what\'s free</a>.'],
    ['How do we delete everything?', 'In the app: Me → Delete account. It deletes everything on our server immediately. Free, and never behind a subscription.'],
  ])}
</div></section>
${cta('A healthier season <em>starts here.</em>', 'Free to download. No ads, no tracking, no diet culture.')}`,
};

// ---------------------------------------------------------------- Safety
export const safety = {
  path: '/safety/',
  title: 'Safety & privacy',
  description: 'How AthleteOS keeps student athletes safe: it never plays doctor, pauses training after a head knock, has no diet culture, and collects the minimum data with no ads or tracking.',
  body: `
<section class="page-hero"><div class="atmos"></div><div class="wrap">
  <p class="eyebrow">Safety &amp; privacy</p>
  <h1 class="display">The rules we <em>don't break.</em></h1>
  <p class="lede">An app for teenagers has to earn trust. These are built into how AthleteOS works — not settings you have to find.</p>
</div></section>

<section class="band tight"><div class="wrap">
  <div class="cards">
    <div class="glass card reveal"><span class="num">01</span><h3>It never plays doctor</h3><p>AthleteOS never diagnoses, never predicts injury and never clears anyone to return to play. When something sounds medical, it says who to talk to.</p></div>
    <div class="glass card reveal"><span class="num">02</span><h3>A head knock pauses training</h3><p>One tap pauses the plan. The standard return-to-play steps are explained, step 5 and up need a doctor's clearance, and the athletic trainer records the step.</p></div>
    <div class="glass card reveal"><span class="num">03</span><h3>Pain changes the plan</h3><p>Report where it hurts and the plan avoids that area. Pain on several days says: talk to a professional.</p></div>
    <div class="glass card reveal"><span class="num">04</span><h3>Fuel, don't diet</h3><p>No calorie counting, no weight-loss goals, no body measurements. The guidance is about eating enough to train and grow.</p></div>
    <div class="glass card reveal"><span class="num">05</span><h3>Rest is part of the plan</h3><p>Seven days in a row means a rest day. Sick days ease back in over five days. Exams and short nights lighten the load.</p></div>
    <div class="glass card reveal"><span class="num">06</span><h3>Honest about what it knows</h3><p>Every plan decision can be traced to a rule, and you can see them all (Me → How AthleteOS decides). Content not yet reviewed by an expert is labelled that way.</p></div>
  </div>
</div></section>

<section class="band tight"><div class="wrap split">
  <div class="reveal">
    <p class="eyebrow">Privacy</p>
    <h2 class="big">The minimum, <em>nothing more.</em></h2>
    <ul class="checks">
      <li><span><b>Works without an account.</b> Everything stays on the phone.</span></li>
      <li><span><b>Sign in with Apple</b> only for backup, teams and leagues — we never ask for a name or email.</span></li>
      <li><span><b>Our own server</b>, no third-party processors, encrypted backups.</span></li>
      <li><span><b>Delete everything</b> in the app, immediately and for free.</span></li>
    </ul>
    <ul class="checks no">
      <li><span>No ads or advertising IDs</span></li>
      <li><span>No analytics SDKs or trackers</span></li>
      <li><span>No location, contacts or photos</span></li>
      <li><span>No data sold or shared — ever</span></li>
    </ul>
    <a class="btn" href="/privacy/">Read the full privacy policy <span class="arrow">→</span></a>
  </div>
  <div class="glass card lit reveal">
    <p class="eyebrow">Community</p>
    <h3 style="font-size:28px">No chat. No strangers.</h3>
    <p class="muted">There are no direct messages. Teams and leagues are private and joined only with a code. Names are checked when they're saved; anything can be reported and is reviewed within 24 hours.</p>
    <p class="muted">Health is shared with a team only if the athlete turns it on — and turning it off deletes what was shared.</p>
  </div>
</div></section>
${cta()}`,
};

// ---------------------------------------------------------------- Pricing
const yes = '<td class="y">✓</td>';
const no = '<td class="n">—</td>';
const row = (label, free, pro) => `<tr><td>${label}</td>${free ? yes : no}${pro ? yes : no}</tr>`;
export const pricing = {
  path: '/pricing/',
  title: 'Pricing',
  description: 'AthleteOS is free to start: the daily check-in, your plan, every kind of workout, the Apple Watch app and daily lessons. AthleteOS Pro is $2.99/month or $24.99/year.',
  body: `
<section class="page-hero"><div class="atmos"></div><div class="wrap" style="text-align:center">
  <p class="eyebrow">Pricing</p>
  <h1 class="display">The habit is <em>free.</em></h1>
  <p class="lede" style="margin-inline:auto">Check in, get your plan and train — every day, for free. Pro is for athletes who want to fine-tune everything.</p>
</div></section>

<section class="band tight" style="padding-top:0"><div class="wrap">
  <div class="plans">
    <div class="glass card plan reveal">
      <h3>Free</h3><p class="muted">Everything you need every day.</p>
      <div class="price">$0</div><p class="faint">Forever</p>
      <ul class="checks"><li><span>Check-in and daily plan</span></li><li><span>All three kinds of workout</span></li><li><span>Apple Watch app</span></li><li><span>3 new Campus lessons a day</span></li><li><span>Sport guides, leagues and teams</span></li><li><span>Safety, fuel and parent summary</span></li></ul>
      ${appStoreButton()}
    </div>
    <div class="glass card plan featured reveal">
      <div><span class="badge">MOST FLEXIBLE</span></div>
      <h3 style="margin-top:14px">Pro Monthly</h3><p class="muted">Everything, month to month.</p>
      <div class="price">$2.99<small> / month</small></div><p class="faint">New subscribers: $0.99/month for the first 3 months</p>
      <ul class="checks"><li><span>Everything in Free</span></li><li><span>Workout editor and your own workouts</span></li><li><span>Unlimited lessons</span></li><li><span>Full history, charts and insights</span></li><li><span>Season calendar and more calendars</span></li><li><span>Send workouts to your team</span></li></ul>
      <a class="btn primary" href="${APP_STORE}" rel="noopener">Start in the app <span class="arrow">→</span></a>
    </div>
    <div class="glass card plan reveal">
      <div><span class="badge">SAVE 30%</span></div>
      <h3 style="margin-top:14px">Pro Yearly</h3><p class="muted">A whole season and off-season.</p>
      <div class="price">$24.99<small> / year</small></div><p class="faint">1-week free trial</p>
      <ul class="checks"><li><span>Everything in Pro Monthly</span></li><li><span>About $2.08 a month</span></li><li><span>Covers a full year of seasons</span></li></ul>
      <a class="btn" href="${APP_STORE}" rel="noopener">Start in the app <span class="arrow">→</span></a>
    </div>
  </div>
  <p class="faint" style="text-align:center;margin-top:22px;font-size:14px">US prices. You see your local price in the app before you buy. Billed through your Apple ID; renews automatically unless cancelled at least 24 hours before the period ends. Manage it in your App Store settings.</p>
</div></section>

<section class="band tight"><div class="narrow">
  <div class="section-head center reveal"><p class="eyebrow">Compare</p><h2 class="big">Free vs Pro.</h2></div>
  <div class="glass table-wrap reveal"><table class="compare">
    <thead><tr><th>Feature</th><th>Free</th><th>Pro</th></tr></thead>
    <tbody>
      ${row('Morning check-in and daily plan', 1, 1)}
      ${row('After practice, gym day and mobility workouts', 1, 1)}
      ${row('Swap exercises', 1, 1)}
      ${row('Logging and the Apple Watch app', 1, 1)}
      ${row('Schedule, one connected calendar', 1, 1)}
      ${row('Campus: 3 new lessons a day, unlimited review', 1, 1)}
      ${row('Sport guides, leagues and teams', 1, 1)}
      ${row('Safety, fuel, emergency card and parent summary', 1, 1)}
      ${row('Coach readiness board and athletic-trainer log', 1, 1)}
      ${row('Edit every set and rep; build your own workouts', 0, 1)}
      ${row('Unlimited Campus lessons', 0, 1)}
      ${row('Full history beyond 30 days, detailed tracking', 0, 1)}
      ${row('Season and year calendar, more calendars', 0, 1)}
      ${row('Video jump test and game-day visualization', 0, 1)}
      ${row('Share workouts; send workouts to a team', 0, 1)}
      ${row('A second sport', 0, 1)}
    </tbody>
  </table></div>
</div></section>

<section class="band tight"><div class="narrow">
  ${faq([
    ['Can I cancel any time?', 'Yes — in iPhone Settings → your name → Subscriptions. You keep Pro until the end of the period you paid for.'],
    ['Does my child need my approval to buy?', 'If you use Family Sharing with “Ask to Buy”, yes — purchases go through Apple, so its parental controls apply.'],
    ['Is there a price for whole teams or schools?', 'Yes, with team codes. <a href="/support/">Get in touch</a> with how many athletes you have.'],
  ])}
</div></section>
${cta()}`,
};

// ---------------------------------------------------------------- Sports
export const sports = {
  path: '/sports/',
  title: 'All 60 sports',
  description: 'AthleteOS supports 60 sports with their formats and positions — from soccer, basketball and football to fencing, rowing and esports conditioning.',
  body: `
<section class="page-hero"><div class="atmos"></div><div class="wrap">
  <p class="eyebrow">Sports</p>
  <h1 class="display">60 sports. <em>Yours too.</em></h1>
  <p class="lede">Each with its drills, its formats and its positions — and a plan built around how that sport actually stresses the body. 29 also have a researched sport guide.</p>
</div></section>
<section class="band tight" style="padding-top:0"><div class="wrap">
  <div class="tags reveal" style="gap:12px">${SPORTS.map((s) => `<span class="tag" style="font-size:16px;padding:12px 20px;color:var(--ink)">${esc(s)}</span>`).join('')}</div>
  <p class="faint" style="margin-top:28px">Some sports are newer than others: their content is marked as a draft in the app until an expert has reviewed it.</p>
</div></section>
${cta()}`,
};

// ---------------------------------------------------------------- 404
export const notFound = {
  path: '/404.html',
  title: 'Page not found',
  description: 'This page does not exist.',
  body: `
<section class="page-hero" style="min-height:60vh;display:grid;align-items:center"><div class="atmos"></div><div class="wrap" style="text-align:center">
  <p class="eyebrow">404</p>
  <h1 class="display">Off the <em>field.</em></h1>
  <p class="lede" style="margin-inline:auto">This page doesn't exist. Maybe it moved — or the link has a typo.</p>
  <div class="ctas" style="justify-content:center"><a class="btn primary" href="/">Back home <span class="arrow">→</span></a><a class="btn" href="/support/">Support</a></div>
</div></section>`,
};
