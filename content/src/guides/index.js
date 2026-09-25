/**
 * The sport knowledge library: one guide per featured sport, written from
 * the studies and guidelines in sources.js. The app shows it as the sport's
 * "Know your sport" page (Campus and Workout) with a short quiz.
 *
 * A guide:
 *   slug       — a featured sport
 *   headline   — one sentence: what wins in this sport
 *   demands    — [{label, value}] what the sport asks of the body
 *   succeed    — [{title, body}] what the best athletes do
 *   season     — {off, pre, in} how training changes through the year
 *   gym        — {focus: [..], exercises: [catalogue slugs]}
 *   injuries   — [{area, body, exercises: [catalogue slugs]}]
 *   positions  — {positionSlug: tip} (only the sport's own positions)
 *   mindset    — [..], fuel — '..'
 *   sources    — keys of SOURCES
 *   quiz       — [{type:'choice', prompt, options, answer, explain}
 *                 | {type:'trueFalse', statement, answer, explain}]
 */
import { hasItem } from '../catalogue.js';
import { SPORTS } from '../sports.js';
import { COURT } from './court.js';
import { DIAMOND } from './diamond.js';
import { INDIVIDUAL } from './individual.js';
import { RUNNING } from './running.js';
import { SNOW_ICE } from './snowIce.js';
import { SOURCES } from './sources.js';
import { TEAM_FIELD } from './teamField.js';
import { WATER } from './water.js';

export { SOURCES };

export const GUIDES = [...TEAM_FIELD, ...COURT, ...DIAMOND, ...RUNNING, ...WATER, ...SNOW_ICE, ...INDIVIDUAL];

/** Every problem with the library, as readable strings (empty when it's fine). */
export function validateGuides(guides = GUIDES) {
  const problems = [];
  const featured = SPORTS.filter((s) => s.featured);
  const bySlug = new Map(SPORTS.map((s) => [s.slug, s]));
  const seen = new Set();
  const text = (v) => typeof v === 'string' && v.trim().length > 0;

  for (const g of guides) {
    const where = `guide ${g.slug}`;
    const sport = bySlug.get(g.slug);
    if (!sport) { problems.push(`${where}: not a sport`); continue; }
    if (!sport.featured) problems.push(`${where}: not a featured sport`);
    if (seen.has(g.slug)) problems.push(`${where}: duplicate`);
    seen.add(g.slug);

    if (!text(g.headline)) problems.push(`${where}: headline missing`);
    if (!(g.demands?.length >= 3) || !g.demands.every((d) => text(d.label) && text(d.value))) problems.push(`${where}: needs 3+ demands`);
    if (!(g.succeed?.length >= 3) || !g.succeed.every((s) => text(s.title) && text(s.body))) problems.push(`${where}: needs 3+ succeed tips`);
    for (const phase of ['off', 'pre', 'in']) if (!text(g.season?.[phase])) problems.push(`${where}: season.${phase} missing`);
    if (!(g.gym?.focus?.length >= 3)) problems.push(`${where}: needs 3+ gym focus points`);
    if (!(g.gym?.exercises?.length >= 4)) problems.push(`${where}: needs 4+ gym exercises`);
    for (const slug of g.gym?.exercises ?? []) if (!hasItem(slug)) problems.push(`${where}: unknown exercise ${slug}`);
    if (!(g.injuries?.length >= 2)) problems.push(`${where}: needs 2+ injury areas`);
    for (const inj of g.injuries ?? []) {
      if (!text(inj.area) || !text(inj.body)) problems.push(`${where}: injury needs area and body`);
      for (const slug of inj.exercises ?? []) if (!hasItem(slug)) problems.push(`${where}: unknown exercise ${slug} (${inj.area})`);
    }

    const positionSlugs = new Set((sport.positions ?? []).map((p) => p.slug ?? p));
    for (const [pos, tip] of Object.entries(g.positions ?? {})) {
      if (!positionSlugs.has(pos)) problems.push(`${where}: ${pos} is not one of its positions`);
      if (!text(tip)) problems.push(`${where}: empty tip for ${pos}`);
    }
    for (const pos of positionSlugs) if (!(g.positions ?? {})[pos]) problems.push(`${where}: no tip for position ${pos}`);

    if (!(g.mindset?.length >= 1)) problems.push(`${where}: needs mindset`);
    if (!text(g.fuel)) problems.push(`${where}: needs fuel`);
    if (!(g.sources?.length >= 1)) problems.push(`${where}: needs at least one source`);
    for (const key of g.sources ?? []) if (!SOURCES[key]) problems.push(`${where}: unknown source ${key}`);

    if (!(g.quiz?.length >= 4)) problems.push(`${where}: needs 4+ quiz questions`);
    for (const [i, q] of (g.quiz ?? []).entries()) {
      const at = `${where} quiz ${i + 1}`;
      if (!text(q.explain)) problems.push(`${at}: explain missing`);
      if (q.type === 'choice') {
        if (!text(q.prompt) || !(q.options?.length >= 2) || !q.options.every(text)) problems.push(`${at}: needs a prompt and 2+ options`);
        else if (!Number.isInteger(q.answer) || q.answer < 0 || q.answer >= q.options.length) problems.push(`${at}: answer out of range`);
      } else if (q.type === 'trueFalse') {
        if (!text(q.statement) || typeof q.answer !== 'boolean') problems.push(`${at}: needs a statement and a true/false answer`);
      } else {
        problems.push(`${at}: unknown type ${q.type}`);
      }
    }
  }

  for (const s of featured) if (!seen.has(s.slug)) problems.push(`featured sport ${s.slug} has no guide`);
  for (const [key, s] of Object.entries(SOURCES)) {
    if (!text(s.title) || !text(s.detail) || !/^https:\/\//.test(s.url ?? '')) problems.push(`source ${key}: needs title, detail and an https url`);
  }
  return problems;
}
