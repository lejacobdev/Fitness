// AthleteOS coach dashboard. No framework, no build step: the page talks to
// the same API as the app, with a 12-hour session from the QR sign-in.

const API = location.pathname.replace(/\/dashboard(\/.*)?$/, '');
const TOKEN_KEY = 'aos.dashboard.session';
const RTP_STEPS = [
  [1, "Everyday activity that doesn't make symptoms worse"],
  [2, 'Light exercise'],
  [3, 'Sport-specific exercise'],
  [4, 'Non-contact training drills'],
  [5, 'Full-contact practice — only after a doctor clears them'],
  [6, 'Back to games'],
];
const LOGO = '<svg viewBox="0 0 100 100" aria-hidden="true"><defs><linearGradient id="aos-g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#10131A"/><stop offset="1" stop-color="#1D2330"/></linearGradient></defs><rect width="100" height="100" rx="22" fill="url(#aos-g)"/><g fill="none" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"><path d="M28.5 47.3 50 32.3l21.5 15" stroke="#F5F7FA"/><path d="M28.5 67.8 50 52.8l21.5 15" stroke="#8B5CF6"/></g></svg>';

// ---------- Session ----------
const session = {
  read() {
    try {
      const saved = JSON.parse(localStorage.getItem(TOKEN_KEY) ?? 'null');
      return saved && saved.expiresAt > Date.now() ? saved : null;
    } catch { return null; }
  },
  save(token, expiresIn) {
    try { localStorage.setItem(TOKEN_KEY, JSON.stringify({ token, expiresAt: Date.now() + expiresIn * 1000 })); } catch { /* private window */ }
    memory = { token, expiresAt: Date.now() + expiresIn * 1000 };
  },
  clear() {
    try { localStorage.removeItem(TOKEN_KEY); } catch { /* ignore */ }
    memory = null;
  },
};
let memory = session.read();
const current = () => memory ?? session.read();

class ApiError extends Error {
  constructor(status, code) { super(code ?? `HTTP ${status}`); this.status = status; this.code = code; }
}

async function api(method, path, body) {
  const s = current();
  const res = await fetch(`${API}${path}`, {
    method,
    headers: { ...(body ? { 'content-type': 'application/json' } : {}), ...(s ? { authorization: `Bearer ${s.token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (res.status === 401) {
    session.clear();
    go('#/login');
    throw new ApiError(401, 'signed_out');
  }
  if (res.status === 204) return null;
  const data = await res.json().catch(() => null);
  if (!res.ok) throw new ApiError(res.status, data?.error);
  return data;
}

// ---------- DOM ----------
function h(tag, attrs = {}, ...children) {
  const [name, ...classes] = tag.split('.');
  const el = document.createElement(name || 'div');
  if (classes.length) el.className = classes.join(' ');
  for (const [key, value] of Object.entries(attrs ?? {})) {
    if (value == null || value === false) continue;
    if (key.startsWith('on')) el.addEventListener(key.slice(2), value);
    else if (key === 'html') el.innerHTML = value;
    else if (key === 'class') el.className += ` ${value}`;
    else el.setAttribute(key, value === true ? '' : value);
  }
  for (const child of children.flat(Infinity)) {
    if (child == null || child === false) continue;
    el.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
  return el;
}
const root = document.getElementById('app');
const go = (hash) => { if (location.hash !== hash) location.hash = hash; else render(); };

function toast(text) {
  document.querySelector('.toast')?.remove();
  const t = h('div.toast', { role: 'status' }, text);
  document.body.append(t);
  setTimeout(() => t.remove(), 3200);
}

function dialog(build, { wide = false } = {}) {
  const close = () => { scrim.remove(); document.removeEventListener('keydown', onKey); };
  const onKey = (e) => { if (e.key === 'Escape') close(); };
  const box = h(`div.dialog.glass${wide ? '.wide' : ''}`, { role: 'dialog', 'aria-modal': 'true' });
  const scrim = h('div.scrim', { onclick: (e) => { if (e.target === scrim) close(); } }, box);
  box.append(...[build(close)].flat());
  document.body.append(scrim);
  document.addEventListener('keydown', onKey);
  box.querySelector('input, textarea, button')?.focus();
  return close;
}

function confirmDialog({ title, text, action, danger = true, onConfirm }) {
  dialog((close) => [
    h('h2', {}, title),
    h('p.muted', {}, text),
    h('div.row.end', { style: 'margin-top:24px' },
      h('button.btn.ghost', { onclick: close }, 'Cancel'),
      h(`button.btn${danger ? '.danger' : '.primary'}`, { onclick: async () => { close(); await onConfirm(); } }, action)),
  ]);
}

const errorText = (err) => ({
  inappropriate: "That wording isn't allowed — try different words.",
  not_shared: "This athlete doesn't share health with the team any more.",
  invalid_title: 'Give it a title of 2–40 characters.',
  invalid_items: 'Pick at least one exercise (up to 20).',
  invalid_date: 'Pick a date.',
  too_many: 'Too many tries — wait a few minutes.',
}[err?.code] ?? (err?.status ? 'Something went wrong — try again.' : "Couldn't reach AthleteOS — check your connection."));

const dayKey = (d = new Date()) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const weekStart = (d = new Date()) => { const m = new Date(d); m.setDate(d.getDate() - ((d.getDay() + 6) % 7)); return dayKey(m); };
const fmtDate = (iso) => new Date(iso.length === 10 ? `${iso}T12:00:00` : iso).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' });
const fmtTime = (iso) => new Date(iso).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
const bandLabel = { GREEN: 'Ready', AMBER: 'A bit tired', RED: 'Go easy', NONE: 'Checked in' };

function bandOf(member) {
  if (member.health?.paused) return 'PAUSED';
  return member.checkedInToday ? (member.readiness ?? 'NONE') : null;
}
function bandView(member) {
  const band = bandOf(member);
  const text = band === 'PAUSED' ? 'Paused — head injury' : band ? bandLabel[band] : 'No check-in';
  return h(`span.band.${band ?? 'NONE'}`, {}, h('i'), text);
}
function trendView(trend = []) {
  return h('span.trend', { title: 'The last 14 days, oldest first' }, trend.map((b) => h(`i${b ? `.${b}` : ''}`)));
}
function rank(m) {
  const b = bandOf(m);
  return { PAUSED: 0, RED: 1, AMBER: 2, null: 3, NONE: 4, GREEN: 5 }[b] ?? 3;
}

// ---------- Data cache ----------
let teamsCache = null;
async function teams(force = false) {
  if (!teamsCache || force) teamsCache = await api('GET', '/teams');
  return teamsCache;
}
let catalogue = null;
async function exercises() {
  if (catalogue) return catalogue;
  const res = await fetch(`${API}/packs/core.json`);
  const pack = await res.json();
  catalogue = pack.items.map((i) => ({ slug: i.slug, name: i.name, dose: i.defaultDose ?? {}, equipment: i.equipment ?? [], qualities: Object.keys(i.qualities ?? {}) }));
  catalogue.sort((a, b) => a.name.localeCompare(b.name));
  return catalogue;
}

// ---------- Layout ----------
function shell(active, content) {
  const t = teamsCache;
  const teamLinks = [
    ...(t?.coaching ?? []).map((team) => ({ id: team.id, name: team.name })),
    ...(t?.trainer ?? []).map((team) => ({ id: team.id, name: `${team.name} · trainer` })),
  ];
  const s = current();
  const hoursLeft = s ? Math.max(0, Math.round((s.expiresAt - Date.now()) / 3_600_000)) : 0;
  return h('div.shell', {},
    h('aside.side', {},
      h('a.brand', { href: '#/teams', html: `${LOGO}<span><b>AthleteOS</b><small>COACH</small></span>` }),
      h('nav.nav', {},
        h(`a${active === 'teams' ? '.on' : ''}`, { href: '#/teams' }, 'All teams'),
        teamLinks.length ? h('div.nav-label', {}, 'Teams') : null,
        teamLinks.map((team) => h(`a${active === team.id ? '.on' : ''}`, { href: `#/team/${team.id}` }, h('span.dot'), team.name)),
        h('div.nav-label', {}, 'You'),
        h(`a${active === 'account' ? '.on' : ''}`, { href: '#/account' }, 'Account'),
        h('a', { href: `${API}/support`, target: '_blank', rel: 'noopener' }, 'Help')),
      h('div.grow'),
      h('div.who', {}, h('b', {}, 'Signed in'), hoursLeft < 1 ? 'For less than an hour more on this computer.' : `For about ${hoursLeft} more hour${hoursLeft === 1 ? '' : 's'} on this computer.`)),
    h('header.topbar', {},
      h('a.brand', { href: '#/teams', html: `${LOGO}<span><b>AthleteOS</b><small>COACH</small></span>` }),
      h('nav', {},
        h(`a${active === 'teams' ? '.on' : ''}`, { href: '#/teams' }, 'Teams'),
        h(`a${active === 'account' ? '.on' : ''}`, { href: '#/account' }, 'Account'))),
    h('main.main', { id: 'main' }, content));
}

function loading() { return h('div.grid.tiles', {}, [1, 2, 3, 4].map(() => h('div.skeleton'))); }
function failure(err, retry) {
  return h('div.glass.card.empty', {}, h('h3', {}, "Couldn't load this"), h('p', {}, errorText(err)),
    h('button.btn', { onclick: retry }, 'Try again'));
}

// ---------- Login ----------
let loginTimer = null;
function loginPage() {
  const qrBox = h('div.qr', { 'aria-label': 'QR code to sign in' });
  const status = h('p.status.muted', {}, 'Getting a code…');
  const expiry = h('p.small.faint', {});
  const page = h('div.login', {},
    h('section', {},
      h('a.brand', { href: '#/login', html: `${LOGO}<span><b>AthleteOS</b><small>COACH</small></span>` }),
      h('p.eyebrow', {}, 'Coach & athletic trainer dashboard'),
      h('h1.hero', {}, 'Your team, on the big screen.'),
      h('p.lede', {}, 'Readiness from morning check-ins, training this week, return-to-play steps, announcements and workouts — everything from coach mode, on a computer.'),
      h('div.trust', {}, h('span', {}, 'No password'), h('span', {}, 'Signed in for 12 hours'), h('span', {}, 'Only what athletes chose to share'))),
    h('section.glass.qr-card', {},
      h('p.eyebrow', { style: 'margin:0' }, 'Sign in'),
      h('h2', {}, 'Scan with your iPhone'),
      qrBox,
      h('ol.steps', { style: 'text-align:left' },
        h('li', {}, 'Open the Camera on the iPhone with AthleteOS.'),
        h('li', {}, 'Point it at this code and tap the link.'),
        h('li', {}, 'Approve the sign-in in AthleteOS.')),
      status, expiry));
  root.replaceChildren(page);

  let attempt = null;
  const start = async () => {
    clearInterval(loginTimer);
    try {
      attempt = await api('POST', '/web-login');
    } catch (err) {
      status.textContent = errorText(err);
      loginTimer = setTimeout(start, 15000);
      return;
    }
    qrBox.innerHTML = attempt.qr; // our own server's SVG
    status.replaceChildren(h('span.pulse'), 'Waiting for your phone…');
    const until = new Date(attempt.expiresAt).getTime();
    loginTimer = setInterval(async () => {
      const left = Math.max(0, Math.round((until - Date.now()) / 1000));
      expiry.textContent = `New code in ${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}`;
      if (left === 0) { start(); return; }
      try {
        const res = await fetch(`${API}/web-login/${attempt.id}/poll`, { headers: { 'x-login-secret': attempt.secret } });
        const data = await res.json();
        if (data.status === 'approved' && data.token) {
          clearInterval(loginTimer);
          session.save(data.token, data.expiresIn);
          status.textContent = 'Signed in.';
          teamsCache = null;
          go('#/teams');
        } else if (data.status === 'denied') {
          status.textContent = 'Sign-in was blocked on the phone. Here is a new code.';
          start();
        } else if (data.status === 'expired' || data.status === 'used') {
          start();
        }
      } catch { /* offline for a moment: keep polling */ }
    }, 2000);
  };
  start();
}

// ---------- Teams ----------
async function teamsPage() {
  root.replaceChildren(shell('teams', loading()));
  let data;
  try { data = await teams(true); } catch (err) { root.replaceChildren(shell('teams', failure(err, teamsPage))); return; }
  root.replaceChildren(shell('teams', []));
  const main = document.getElementById('main');
  const coached = data.coaching ?? [];
  const trainer = data.trainer ?? [];

  const nameInput = h('input.input', { placeholder: 'e.g. Varsity Soccer', maxlength: 40, 'aria-label': 'Team name' });
  const createError = h('p.error');
  const create = h('form.glass.card', {
    onsubmit: async (e) => {
      e.preventDefault();
      try {
        await api('POST', '/teams', { name: nameInput.value });
        toast('Team created.');
        teamsPage();
      } catch (err) { createError.textContent = err.code === 'invalid_name' ? 'Use 2–40 characters.' : errorText(err); }
    },
  }, h('h3', {}, 'New team'), h('p.muted.small', { style: 'margin:0 0 16px' }, 'Athletes join with the code it gets.'),
  h('div.row', {}, h('div', { style: 'flex:1;min-width:220px' }, nameInput), h('button.btn.primary', { type: 'submit' }, 'Create team')), createError);

  main.append(
    h('div.page-head', {}, h('div', {}, h('p.eyebrow', {}, 'Coach'), h('h1', {}, 'Teams'),
      h('p.lede', {}, coached.length + trainer.length ? 'Pick a team to see today.' : 'Create your first team, then give athletes the code.'))),
    coached.length + trainer.length
      ? h('div.grid.two', {},
        coached.map((t) => h('a.glass.card', { href: `#/team/${t.id}`, style: 'text-decoration:none;display:block' },
          h('p.eyebrow', {}, 'Coach'), h('h2', {}, t.name),
          h('p.muted', { style: 'margin:0' }, `${t.memberCount} athlete${t.memberCount === 1 ? '' : 's'} · code `, h('span.mono', {}, t.code)),
          h('div.row', { style: 'margin-top:20px' }, h('span.btn.small', {}, 'Open ', h('span.arrow', {}, '→'))))),
        trainer.map((t) => h('a.glass.card', { href: `#/team/${t.id}`, style: 'text-decoration:none;display:block' },
          h('p.eyebrow', {}, 'Athletic trainer'), h('h2', {}, t.name),
          h('p.muted', { style: 'margin:0' }, 'Health and return-to-play'),
          h('div.row', { style: 'margin-top:20px' }, h('span.btn.small', {}, 'Open ', h('span.arrow', {}, '→'))))))
      : h('div.glass.card.empty', {}, h('h3', {}, 'No teams yet'), h('p', {}, 'Create one below, or ask the coach for the athletic-trainer code (join it in the app: Me → My team).')),
    h('div.section', {}, create));
}

// ---------- Team ----------
const COACH_TABS = [['today', 'Today'], ['athletes', 'Athletes'], ['health', 'Health'], ['announcements', 'Announcements'], ['workouts', 'Workouts'], ['invite', 'Invite'], ['settings', 'Settings']];
const TRAINER_TABS = [['health', 'Health & return to play']];
let refreshTimer = null;

async function teamPage(id, tab) {
  let data;
  try { data = await teams(); } catch (err) { root.replaceChildren(shell(id, failure(err, () => teamPage(id, tab)))); return; }
  const coached = data.coaching.find((t) => t.id === id);
  const staffed = (data.trainer ?? []).find((t) => t.id === id);
  const team = coached ?? staffed;
  if (!team) { notFound(); return; }
  const role = coached ? 'coach' : 'trainer';
  const tabs = role === 'coach' ? COACH_TABS : TRAINER_TABS;
  const active = tabs.some(([k]) => k === tab) ? tab : tabs[0][0];
  const body = h('div');
  root.replaceChildren(shell(id, [
    h('div.page-head', {},
      h('div', {}, h('p.eyebrow', {}, role === 'coach' ? `Team · code ${team.code}` : 'Athletic trainer'), h('h1', {}, team.name)),
      role === 'coach' ? h('a.btn.primary', { href: `#/sideline/${id}` }, 'Sideline mode ', h('span.arrow', {}, '→')) : null),
    h('nav.tabs', { 'aria-label': 'Team sections' }, tabs.map(([k, label]) => h(`a${k === active ? '.on' : ''}`, { href: `#/team/${id}/${k}` }, label))),
    h('div', { style: 'margin-top:32px' }, body),
  ]));
  const views = { today: todayTab, athletes: athletesTab, health: healthTab, announcements: announcementsTab, workouts: workoutsTab, invite: inviteTab, settings: settingsTab };
  await views[active](body, team, role);
}

async function readiness(team) {
  return api('GET', `/teams/${team.id}/readiness?today=${dayKey()}&weekStart=${weekStart()}`);
}

function metrics(members) {
  const count = (fn) => members.filter(fn).length;
  return [
    ['Ready', count((m) => bandOf(m) === 'GREEN'), 'var(--green)'],
    ['A bit tired', count((m) => bandOf(m) === 'AMBER'), 'var(--amber)'],
    ['Go easy', count((m) => bandOf(m) === 'RED'), 'var(--danger)'],
    ['Paused', count((m) => bandOf(m) === 'PAUSED'), 'var(--danger)'],
    ['No check-in', count((m) => !m.checkedInToday), 'var(--faint)'],
  ].map(([label, n, color]) => h('div.glass.metric', {}, h('div.n', { style: `color:${n ? color : 'var(--faint)'}` }, n), h('div.l', {}, label)));
}

function tile(m) {
  const band = bandOf(m);
  return h(`div.glass.tile${band ? `.${band}` : ''}`, {},
    bandView(m),
    h('div.name', { title: m.nickname }, m.nickname),
    h('div.meta', {}, `${m.sessionsThisWeek} workout${m.sessionsThisWeek === 1 ? '' : 's'} · ${m.minutesThisWeek} min this week`),
    m.health?.pain ? h('div.flag', {}, `Pain: ${m.health.pain.areas.join(', ')}`) : null,
    m.health?.rtpStep ? h('div.flag.rtp', {}, `Return to play: step ${m.health.rtpStep}`) : null);
}

async function todayTab(body, team) {
  body.replaceChildren(loading());
  const draw = async () => {
    let board;
    try { board = await readiness(team); } catch (err) { body.replaceChildren(failure(err, () => todayTab(body, team))); return; }
    const members = [...board.members].sort((a, b) => rank(a) - rank(b) || a.nickname.localeCompare(b.nickname));
    body.replaceChildren(
      members.length ? h('div.grid.metrics', {}, metrics(members)) : null,
      h('div.section', { style: 'margin-top:40px' },
        h('div.section-head', {}, h('div', {}, h('h2', {}, 'Today'), h('p.muted', {}, 'From morning check-ins. The ones to look at first are at the top.')),
          h('span.small.faint', {}, `Updated ${new Date().toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })} · refreshes every minute`)),
        members.length ? h('div.grid.tiles', {}, members.map(tile))
          : h('div.glass.card.empty', {}, h('h3', {}, 'No athletes yet'), h('p', {}, 'Give them the team code — see Invite.'), h('a.btn', { href: `#/team/${team.id}/invite` }, 'Invite athletes'))));
  };
  await draw();
  clearInterval(refreshTimer);
  refreshTimer = setInterval(() => { if (document.body.contains(body)) draw(); else clearInterval(refreshTimer); }, 60_000);
}

async function athletesTab(body, team) {
  body.replaceChildren(loading());
  let board;
  try { board = await readiness(team); } catch (err) { body.replaceChildren(failure(err, () => athletesTab(body, team))); return; }
  const members = board.members;
  if (!members.length) {
    body.replaceChildren(h('div.glass.card.empty', {}, h('h3', {}, 'No athletes yet'), h('a.btn', { href: `#/team/${team.id}/invite` }, 'Invite athletes')));
    return;
  }
  const csv = () => {
    const rows = [['Athlete', 'Today', 'Check-ins this week', 'Missed this week', 'Workouts this week', 'Minutes this week', 'Shares health']]
      .concat(members.map((m) => [m.nickname, bandOf(m) ?? 'No check-in', m.checkInsThisWeek, m.missedThisWeek ?? '', m.sessionsThisWeek, m.minutesThisWeek, m.sharesHealth ? 'yes' : 'no']));
    const text = rows.map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n');
    const a = h('a', { href: URL.createObjectURL(new Blob([text], { type: 'text/csv' })), download: `${team.name} ${dayKey()}.csv` });
    document.body.append(a); a.click(); a.remove();
  };
  body.replaceChildren(
    h('div.section-head', {}, h('div', {}, h('h2', {}, `${members.length} athlete${members.length === 1 ? '' : 's'}`), h('p.muted', {}, 'Only what they agreed to share by joining. Never notes or anything they wrote.')),
      h('button.btn.small', { onclick: csv }, 'Download this week (CSV)')),
    h('div.glass.table-wrap', {}, h('table', {},
      h('thead', {}, h('tr', {}, ['Athlete', 'Today', 'Last 14 days', 'Check-ins', 'Missed', 'Workouts', 'Minutes', ''].map((t) => h('th', {}, t)))),
      h('tbody', {}, members.map((m) => h('tr', {},
        h('td', {}, h('b', {}, m.nickname), m.sharesHealth ? h('div.small.faint', {}, 'Shares health') : null),
        h('td', {}, bandView(m)),
        h('td', {}, trendView(m.trend)),
        h('td.num', {}, m.checkInsThisWeek),
        h('td.num', {}, m.missedThisWeek ?? '–'),
        h('td.num', {}, m.sessionsThisWeek),
        h('td.num', {}, m.minutesThisWeek),
        h('td', { style: 'text-align:right;white-space:nowrap' },
          m.memberId ? h('button.btn.small', { onclick: () => noteDialog(team, m) }, 'Send a note') : null, ' ',
          m.memberId ? h('button.btn.small.ghost', { onclick: () => removeMember(team, m, () => athletesTab(body, team)) }, 'Remove') : null)))))));
}

function noteDialog(team, member) {
  dialog((close) => {
    const text = h('textarea.input', { maxlength: 200, placeholder: 'e.g. Great effort at practice yesterday — your first step is getting quicker.' });
    const err = h('p.error');
    const count = h('span.small.faint', {}, '0/200');
    text.addEventListener('input', () => { count.textContent = `${text.value.length}/200`; });
    return [
      h('p.eyebrow', {}, 'Private note'), h('h2', {}, `To ${member.nickname}`),
      h('p.muted', {}, 'Only they see it, on their Home screen. Make it specific.'),
      h('div.field', { style: 'margin-top:16px' }, text, count), err,
      h('div.row.end', { style: 'margin-top:20px' }, h('button.btn.ghost', { onclick: close }, 'Cancel'),
        h('button.btn.primary', {
          onclick: async () => {
            try { await api('POST', `/teams/${team.id}/shoutouts`, { memberId: member.memberId, text: text.value }); close(); toast(`Sent to ${member.nickname}.`); } catch (e) { err.textContent = errorText(e); }
          },
        }, 'Send')),
    ];
  });
}

function removeMember(team, member, done) {
  confirmDialog({
    title: `Remove ${member.nickname}?`,
    text: 'They leave the team and stop sharing with you. Their own training data stays theirs. They can rejoin with the code.',
    action: 'Remove',
    onConfirm: async () => {
      try { await api('DELETE', `/teams/${team.id}/members/${encodeURIComponent(member.memberId)}`); toast(`${member.nickname} removed.`); done(); } catch (e) { toast(errorText(e)); }
    },
  });
}

async function healthTab(body, team, role) {
  body.replaceChildren(loading());
  let data;
  try { data = await api('GET', `/teams/${team.id}/health`); } catch (err) { body.replaceChildren(failure(err, () => healthTab(body, team, role))); return; }
  const members = data.members;
  const intro = h('div.section-head', {}, h('div', {},
    h('h2', {}, 'Health & return to play'),
    h('p.muted', {}, 'Pain reports and training pauses from athletes who chose to share them with this team. Never a diagnosis.')));
  if (!members.length) {
    body.replaceChildren(intro, h('div.glass.card.empty', {}, h('h3', {}, 'Nobody shares health yet'),
      h('p', {}, 'Athletes turn it on in the app: Me → My team → Share pain and pauses. It is off unless they choose it.')));
    return;
  }
  const sorted = [...members].sort((a, b) => Number(b.paused) - Number(a.paused) || (b.rtpStep ?? 0) - (a.rtpStep ?? 0) || b.painDays - a.painDays);
  body.replaceChildren(intro, h('div.list', {}, sorted.map((m) => h('div.glass.item', {},
    h('div.body', {},
      h('div.row', {}, h('span.title', { style: 'font-size:20px' }, m.nickname),
        m.paused ? h('span.pill.red', {}, `Paused since ${fmtDate(m.pausedSince)}`) : null,
        m.rtpStep ? h('span.pill', {}, `Step ${m.rtpStep} of 6`) : null),
      h('p.muted', { style: 'margin:6px 0 0' },
        m.pain ? `Pain: ${m.pain.areas.join(', ')}${m.pain.level ? ` (${{ little: 'a little', some: 'some', lot: 'a lot' }[m.pain.level] ?? m.pain.level})` : ''} · ${fmtDate(m.pain.day)}` : 'No pain reported',
        m.painDays > 1 ? ` · ${m.painDays} days in the last two weeks` : ''),
      m.rtpStep ? h('p.small.faint', { style: 'margin:4px 0 0' }, `${RTP_STEPS[m.rtpStep - 1][1]} · recorded ${fmtTime(m.rtpRecordedAt)}`) : null,
      m.painDays > 1 ? h('p.small', { style: 'margin:6px 0 0;color:var(--amber);font-weight:650' }, 'Pain on more than one day — worth a conversation, and a professional if it keeps up.') : null),
    h('div.row', {},
      m.memberId ? h('button.btn.small.ghost', { onclick: () => rtpHistory(team, m) }, 'History') : null,
      role === 'trainer' && m.memberId && (m.paused || m.rtpStep)
        ? h('button.btn.small.primary', { onclick: () => rtpDialog(team, m, () => healthTab(body, team, role)) }, 'Record a step') : null)))),
  role === 'coach' ? h('p.small.faint', { style: 'margin-top:20px' }, "Return-to-play steps are recorded by the team's athletic trainer (Invite → athletic trainer code).") : null);
}

function rtpDialog(team, member, done) {
  let step = member.rtpStep ?? 1;
  dialog((close) => {
    const list = h('div.rtp-steps');
    const warn = h('p.small', { style: 'color:var(--danger);font-weight:650;min-height:20px' });
    const draw = () => {
      list.replaceChildren(...RTP_STEPS.map(([n, label]) => h(`button${n === step ? '.on' : ''}`, { type: 'button', onclick: () => { step = n; draw(); } }, h('b', {}, n), label)));
      warn.textContent = step >= 5 ? "Step 5 and up need a doctor's clearance (in writing where your school requires it)." : '';
    };
    draw();
    const note = h('input.input', { maxlength: 200, placeholder: 'Note (optional), e.g. 15 min bike, no symptoms' });
    const err = h('p.error');
    return [
      h('p.eyebrow', {}, 'Return to play'), h('h2', {}, member.nickname),
      h('p.muted', {}, 'Which step are they on? You decide — AthleteOS only records it and shows it to them.'),
      list, h('div.field', { style: 'margin-top:14px' }, note), warn, err,
      h('div.row.end', {}, h('button.btn.ghost', { onclick: close }, 'Cancel'),
        h('button.btn.primary', {
          onclick: async () => {
            try { await api('POST', `/teams/${team.id}/rtp`, { memberId: member.memberId, step, note: note.value || null }); close(); toast(`Step ${step} recorded.`); done(); } catch (e) { err.textContent = errorText(e); }
          },
        }, 'Record step')),
    ];
  });
}

function rtpHistory(team, member) {
  dialog((close) => {
    const list = h('div.list', {}, h('div.skeleton', { style: 'min-height:60px' }));
    api('GET', `/teams/${team.id}/rtp?memberId=${encodeURIComponent(member.memberId)}`).then((data) => {
      list.replaceChildren(...(data.entries.length ? data.entries.map((e) => h('div.item.glass', {},
        h('span.pill', {}, `Step ${e.step}`),
        h('div.body', {}, h('div', {}, RTP_STEPS[e.step - 1][1]), e.note ? h('div.small.muted', {}, e.note) : null),
        h('span.small.faint', {}, fmtTime(e.recordedAt)))) : [h('p.muted', {}, 'No steps recorded yet.')]));
    }).catch((e) => list.replaceChildren(h('p.error', {}, errorText(e))));
    return [h('p.eyebrow', {}, 'Return-to-play log'), h('h2', {}, member.nickname), list,
      h('div.row.end', { style: 'margin-top:20px' }, h('button.btn', { onclick: close }, 'Close'))];
  });
}

async function announcementsTab(body, team) {
  body.replaceChildren(loading());
  let items;
  try { items = (await api('GET', `/teams/${team.id}/announcements`)).announcements; } catch (err) { body.replaceChildren(failure(err, () => announcementsTab(body, team))); return; }
  const text = h('textarea.input', { maxlength: 300, placeholder: 'e.g. Practice moves to 5 pm tomorrow — bring water.' });
  const err = h('p.error');
  body.replaceChildren(
    h('div.section-head', {}, h('div', {}, h('h2', {}, 'Announcements'), h('p.muted', {}, 'One-way: the team reads them on Home for 14 days. No replies, no chat.'))),
    h('form.glass.card', {
      onsubmit: async (e) => {
        e.preventDefault();
        try { await api('POST', `/teams/${team.id}/announcements`, { text: text.value }); toast('Sent to the team.'); announcementsTab(body, team); } catch (ex) { err.textContent = errorText(ex); }
      },
    }, h('div.field', {}, h('label', {}, 'New announcement'), text), err, h('div.row.end', { style: 'margin-top:14px' }, h('button.btn.primary', { type: 'submit' }, 'Send to the team'))),
    h('div.section', { style: 'margin-top:32px' }, items.length
      ? h('div.list', {}, items.map((a) => h('div.glass.item', {},
        h('div.body', {}, h('div', { style: 'white-space:pre-wrap' }, a.text), h('div.small.faint', { style: 'margin-top:6px' }, fmtTime(a.createdAt))),
        h('button.btn.small.ghost', {
          onclick: () => confirmDialog({
            title: 'Delete this announcement?', text: 'It disappears from every athlete\'s Home.', action: 'Delete',
            onConfirm: async () => { try { await api('DELETE', `/teams/${team.id}/announcements/${a.id}`); announcementsTab(body, team); } catch (e) { toast(errorText(e)); } },
          }),
        }, 'Delete'))))
      : h('p.muted', {}, 'Nothing in the last 14 days.')));
}

async function workoutsTab(body, team) {
  body.replaceChildren(loading());
  let list; let me;
  try {
    [list, me] = await Promise.all([api('GET', `/teams/${team.id}/assignments?from=${dayKey()}`), api('GET', '/athlete/me')]);
  } catch (err) { body.replaceChildren(failure(err, () => workoutsTab(body, team))); return; }
  const isPro = Boolean(me?.athlete?.isPro);
  const assignments = list.assignments ?? [];
  const names = new Map((await exercises().catch(() => [])).map((e) => [e.slug, e.name]));
  body.replaceChildren(
    h('div.section-head', {}, h('div', {}, h('h2', {}, 'Workouts you sent'), h('p.muted', {}, "They show on each athlete's Home on that day, ready to start.")),
      isPro ? h('button.btn.primary', { onclick: () => assignDialog(team, () => workoutsTab(body, team)) }, 'Send a workout') : null),
    isPro ? null : h('div.glass.card', { style: 'margin-bottom:20px' }, h('h3', {}, 'Sending workouts is part of AthleteOS Pro'),
      h('p.muted', { style: 'margin:0' }, 'The readiness board, health, announcements and notes stay free. Upgrade in the app (Me → AthleteOS Pro), then reload this page.')),
    assignments.length
      ? h('div.list', {}, assignments.map((a) => h('div.glass.item', {},
        h('div', { style: 'text-align:center;min-width:64px' }, h('div.small.faint', {}, new Date(`${a.date}T12:00:00`).toLocaleDateString(undefined, { weekday: 'short' }).toUpperCase()),
          h('div', { style: 'font-size:28px;font-weight:800;line-height:1' }, new Date(`${a.date}T12:00:00`).getDate())),
        h('div.body', {}, h('div.title', {}, a.title),
          h('div.small.muted', {}, a.items.map((i) => `${names.get(i.itemSlug) ?? i.itemSlug} ${i.sets}×${i.reps ?? `${i.seconds}s`}`).join(' · ')),
          a.note ? h('div.small.faint', { style: 'margin-top:4px' }, a.note) : null),
        h('button.btn.small.ghost', {
          onclick: () => confirmDialog({
            title: `Delete “${a.title}”?`, text: 'It disappears from the athletes\' Home.', action: 'Delete',
            onConfirm: async () => { try { await api('DELETE', `/teams/${team.id}/assignments/${a.id}`); workoutsTab(body, team); } catch (e) { toast(errorText(e)); } },
          }),
        }, 'Delete'))))
      : h('div.glass.card.empty', {}, h('h3', {}, 'No upcoming workouts'), h('p', {}, isPro ? 'Send one for practice days, the off-season or travel.' : '')));
}

async function assignDialog(team, done) {
  const all = await exercises().catch(() => []);
  const chosen = [];
  dialog((close) => {
    const date = h('input.input', { type: 'date', value: dayKey(), min: dayKey() });
    const title = h('input.input', { maxlength: 40, placeholder: 'e.g. Pre-season strength A' });
    const note = h('input.input', { maxlength: 300, placeholder: 'Note (optional)' });
    const search = h('input.input', { placeholder: `Search ${all.length} exercises` });
    const picker = h('div.picker');
    const picked = h('div.chosen');
    const err = h('p.error');
    const drawPicker = () => {
      const q = search.value.trim().toLowerCase();
      const hits = all.filter((e) => !q || e.name.toLowerCase().includes(q) || e.qualities.some((x) => x.includes(q))).slice(0, 80);
      picker.replaceChildren(...hits.map((e) => h('button', {
        type: 'button',
        onclick: () => {
          if (chosen.length >= 20) return;
          chosen.push({ slug: e.slug, name: e.name, sets: Math.min(10, e.dose.sets ?? 3), reps: e.dose.kind === 'time' ? null : (e.dose.reps ?? 8), seconds: e.dose.kind === 'time' ? (e.dose.seconds ?? 30) : null });
          drawChosen();
        },
      }, h('span', {}, e.name), h('span.small.faint', {}, e.dose.kind === 'time' ? `${e.dose.sets ?? 3}×${e.dose.seconds ?? 30}s` : `${e.dose.sets ?? 3}×${e.dose.reps ?? 8}`))));
    };
    const drawChosen = () => {
      picked.replaceChildren(...(chosen.length ? chosen.map((c, i) => h('div.ex', {},
        h('span', {}, h('b', {}, c.name)),
        h('input.input', { type: 'number', min: 1, max: 10, value: c.sets, 'aria-label': 'Sets', oninput: (e) => { c.sets = Number(e.target.value); } }),
        h('input.input', {
          type: 'number', min: 1, max: c.seconds ? 3600 : 100, value: c.seconds ?? c.reps, 'aria-label': c.seconds ? 'Seconds' : 'Reps',
          oninput: (e) => { if (c.seconds) c.seconds = Number(e.target.value); else c.reps = Number(e.target.value); },
        }),
        h('button.btn.small.ghost', { type: 'button', 'aria-label': `Remove ${c.name}`, onclick: () => { chosen.splice(i, 1); drawChosen(); } }, '×'))) : [h('p.muted.small', {}, 'Pick exercises on the left. Sets, then reps (or seconds).')]));
    };
    search.addEventListener('input', drawPicker);
    drawPicker(); drawChosen();
    return [
      h('p.eyebrow', {}, team.name), h('h2', {}, 'Send a workout'),
      h('div.grid.two', { style: 'margin-top:18px' },
        h('div.field', {}, h('label', {}, 'Day'), date),
        h('div.field', {}, h('label', {}, 'Title'), title)),
      h('div.field', { style: 'margin-top:12px' }, note),
      h('div.grid.two', { style: 'margin-top:20px;align-items:start' },
        h('div.field', {}, h('label', {}, 'Exercises'), search, picker),
        h('div.field', {}, h('label', {}, 'In this workout'), picked)),
      err,
      h('div.row.end', { style: 'margin-top:20px' }, h('button.btn.ghost', { onclick: close }, 'Cancel'),
        h('button.btn.primary', {
          onclick: async () => {
            try {
              await api('POST', `/teams/${team.id}/assignments`, {
                date: date.value, title: title.value, note: note.value || null,
                items: chosen.map((c) => ({ itemSlug: c.slug, sets: c.sets, reps: c.reps, seconds: c.seconds })),
              });
              close(); toast('Workout sent.'); done();
            } catch (e) { err.textContent = errorText(e); }
          },
        }, 'Send to the team')),
    ];
  }, { wide: true });
}

async function inviteTab(body, team) {
  const data = await teams(true).catch(() => teamsCache);
  const fresh = data?.coaching?.find((t) => t.id === team.id) ?? team;
  const link = `https://api.lejacob.dev/fitness/team/${fresh.code}`;
  const qr = h('div.qr');
  fetch(`${API}/qr/team/${fresh.code}.svg?v=1`).then((r) => r.text()).then((svg) => { if (svg.startsWith('<svg')) qr.innerHTML = svg; }).catch(() => {});
  const copy = async (text, what) => { try { await navigator.clipboard.writeText(text); toast(`${what} copied.`); } catch { toast(text); } };
  const trainer = fresh.trainerCode;
  body.replaceChildren(h('div.grid.two', {},
    h('div.glass.card', {},
      h('p.eyebrow', {}, 'Athletes'), h('h2', {}, 'Team code'),
      h('div.code-big', { style: 'margin:18px 0' }, fresh.code),
      h('p.muted', {}, 'Athletes scan the QR code, open the link, or enter the code in the app: Me → My team.'),
      h('div', { style: 'margin:20px 0' }, qr),
      h('div.row', {}, h('button.btn', { onclick: () => copy(link, 'Link') }, 'Copy link'), h('button.btn.ghost', { onclick: () => copy(fresh.code, 'Code') }, 'Copy code'))),
    h('div.glass.card', {},
      h('p.eyebrow', {}, 'Staff'), h('h2', {}, 'Athletic trainer code'),
      h('p.muted', {}, "Your athletic trainer joins with this code (Me → My team → I'm the athletic trainer). They see health and record return-to-play steps — nothing else."),
      trainer ? h('div.code-big', { style: 'margin:18px 0' }, trainer) : h('p.faint', { style: 'margin:18px 0' }, 'No trainer code yet.'),
      h('div.row', {},
        h('button.btn.primary', {
          onclick: async () => { try { await api('POST', `/teams/${team.id}/trainer-code`); toast(trainer ? 'New code — the old one stopped working.' : 'Code made.'); inviteTab(body, team); } catch (e) { toast(errorText(e)); } },
        }, trainer ? 'Make a new code' : 'Make a code'),
        trainer ? h('button.btn.danger', {
          onclick: () => confirmDialog({
            title: 'Switch the trainer code off?', text: 'Trainers who joined are removed from the team.', action: 'Switch off',
            onConfirm: async () => { try { await api('DELETE', `/teams/${team.id}/trainer-code`); inviteTab(body, team); } catch (e) { toast(errorText(e)); } },
          }),
        }, 'Switch off') : null))));
}

function settingsTab(body, team) {
  const confirmInput = h('input.input', { placeholder: team.name, 'aria-label': 'Type the team name to confirm' });
  const del = h('button.btn.danger', {
    disabled: true,
    onclick: async () => {
      try { await api('DELETE', `/teams/${team.id}`); teamsCache = null; toast('Team deleted.'); go('#/teams'); } catch (e) { toast(errorText(e)); }
    },
  }, 'Delete this team');
  confirmInput.addEventListener('input', () => { del.disabled = confirmInput.value.trim() !== team.name; });
  body.replaceChildren(h('div.glass.card', { style: 'max-width:640px' },
    h('h2', {}, 'Delete the team'),
    h('p.muted', {}, 'Athletes are removed from it, and its workouts, announcements and return-to-play log disappear. Their own data stays theirs. This cannot be undone.'),
    h('div.field', { style: 'margin:18px 0' }, h('label', {}, `Type “${team.name}” to confirm`), confirmInput),
    del));
}

// ---------- Sideline ----------
async function sidelinePage(id) {
  let data;
  try { data = await teams(); } catch { data = null; }
  const team = data?.coaching?.find((t) => t.id === id);
  if (!team) { notFound(); return; }
  const grid = h('div.grid.tiles', {}, loading());
  const sum = h('div.grid.metrics');
  const clock = h('span.small.faint');
  const exit = () => { if (document.fullscreenElement) document.exitFullscreen().catch(() => {}); go(`#/team/${id}`); };
  const view = h('div.sideline', {},
    h('div.page-head', { style: 'margin-bottom:24px' },
      h('div', {}, h('p.eyebrow', {}, 'Sideline'), h('h1.hero', { style: 'margin:0' }, team.name)),
      h('div.row', {}, clock,
        h('button.btn', { onclick: () => document.documentElement.requestFullscreen?.().catch(() => {}) }, 'Full screen'),
        h('button.btn.ghost', { onclick: exit }, 'Close'))),
    sum, h('div', { style: 'height:24px' }), grid);
  root.replaceChildren(view);
  const onKey = (e) => { if (e.key === 'Escape' && !document.fullscreenElement) { document.removeEventListener('keydown', onKey); exit(); } };
  document.addEventListener('keydown', onKey);
  const draw = async () => {
    try {
      const board = await readiness(team);
      const members = [...board.members].sort((a, b) => rank(a) - rank(b) || a.nickname.localeCompare(b.nickname));
      sum.replaceChildren(...metrics(members));
      grid.replaceChildren(...(members.length ? members.map(tile) : [h('p.muted', {}, 'No athletes yet.')]));
      clock.textContent = `Updated ${new Date().toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })} · every minute`;
    } catch { clock.textContent = "Couldn't refresh — trying again in a minute."; }
  };
  await draw();
  clearInterval(refreshTimer);
  refreshTimer = setInterval(() => { if (document.body.contains(view)) draw(); else clearInterval(refreshTimer); }, 60_000);
  try { await navigator.wakeLock?.request('screen'); } catch { /* not supported */ }
}

// ---------- Account ----------
async function accountPage() {
  root.replaceChildren(shell('account', loading()));
  let me = null;
  try { me = await api('GET', '/athlete/me'); } catch { /* shown below */ }
  const s = current();
  root.replaceChildren(shell('account', [
    h('div.page-head', {}, h('div', {}, h('p.eyebrow', {}, 'You'), h('h1', {}, 'Account'))),
    h('div.grid.two', {},
      h('div.glass.card', {},
        h('h3', {}, 'This computer'),
        h('p.muted', {}, `Signed in until ${s ? new Date(s.expiresAt).toLocaleString(undefined, { weekday: 'short', hour: 'numeric', minute: '2-digit' }) : '—'}. Sign out on shared computers.`),
        h('button.btn.primary', { onclick: () => { session.clear(); teamsCache = null; go('#/login'); } }, 'Sign out')),
      h('div.glass.card', {},
        h('h3', {}, 'AthleteOS Pro'),
        h('p.muted', {}, me ? (me.athlete.isPro ? `Active${me.athlete.proUntil ? ` until ${new Date(me.athlete.proUntil).toLocaleDateString()}` : ''}.` : 'Not active. Sending workouts to the team needs Pro; everything else here is free.') : "Couldn't load."),
        h('p.small.faint', {}, 'Manage it in the app: Me → AthleteOS Pro.')),
      h('div.glass.card', {},
        h('h3', {}, 'Your account'),
        h('p.muted', {}, 'It is the same account as in the app (Sign in with Apple). To delete it and everything in it, use the app: Me → Account → Delete account.')),
      h('div.glass.card', {},
        h('h3', {}, 'Privacy'),
        h('p.muted', {}, 'Coaches see only what athletes agreed to share by joining. Health is shared only when an athlete turns it on, and only with this team.'),
        h('div.row', {}, h('a.btn.small', { href: `${API}/privacy`, target: '_blank', rel: 'noopener' }, 'Privacy policy'), h('a.btn.small.ghost', { href: `${API}/terms`, target: '_blank', rel: 'noopener' }, 'Terms')))),
  ]));
}

function notFound() {
  const content = h('div.glass.card.empty', {}, h('p.eyebrow', {}, '404'), h('h3', {}, "This page doesn't exist"),
    h('p', {}, "Or it's a team you're not on any more."), h('a.btn', { href: '#/teams' }, 'All teams'));
  root.replaceChildren(current() ? shell('', content) : h('div.main', {}, content));
}

// ---------- Router ----------
async function render() {
  clearInterval(loginTimer);
  clearInterval(refreshTimer);
  const parts = location.hash.replace(/^#\/?/, '').split('/').filter(Boolean);
  const [page, id, tab] = parts;
  if (!current()) {
    if (page !== 'login') history.replaceState(null, '', '#/login');
    loginPage();
    return;
  }
  window.scrollTo(0, 0);
  switch (page ?? 'teams') {
    case 'login': go('#/teams'); break;
    case 'teams': await teamsPage(); break;
    case 'team': await teamPage(id, tab); break;
    case 'sideline': await sidelinePage(id); break;
    case 'account': await accountPage(); break;
    default: notFound();
  }
  document.title = `${document.querySelector('h1')?.textContent ?? 'AthleteOS'} · AthleteOS Coach`;
}

window.addEventListener('hashchange', render);
render();
