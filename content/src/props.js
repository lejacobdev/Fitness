/**
 * Sport props — §9: "A ball, a puck, a bar, a net or a hurdle is a small named
 * shape positioned relative to a joint... Around a dozen props cover every
 * sport in the catalogue." A drill references a prop slug plus the joint and
 * offset it is drawn at; the rig itself never changes.
 *
 * `attachTo` is a joint from poses.js. `offset` is in rig-relative centimetres
 * at life-size scale (the rig is drawn at a fixed nominal height so offsets are
 * comparable across every item that uses the prop).
 */

export const PROPS = [
  {
    slug: 'ball-round',
    name: 'Ball (round)',
    covers: ['soccer', 'basketball', 'volleyball', 'water-polo', 'handball'],
    attachTo: 'ankleR',
    offset: { x: 12, y: 0 },
  },
  {
    slug: 'ball-oval',
    name: 'Ball (oval)',
    covers: ['football', 'flag-football', 'rugby'],
    attachTo: 'wristR',
    offset: { x: 8, y: -4 },
  },
  {
    slug: 'bat',
    name: 'Bat',
    covers: ['baseball', 'softball'],
    attachTo: 'wristR',
    offset: { x: 4, y: 0 },
  },
  {
    slug: 'racket',
    name: 'Racket',
    covers: ['tennis', 'badminton', 'table-tennis', 'squash', 'pickleball'],
    attachTo: 'wristR',
    offset: { x: 6, y: 2 },
  },
  {
    slug: 'stick-hockey',
    name: 'Hockey stick',
    covers: ['ice-hockey', 'field-hockey'],
    attachTo: 'wristR',
    offset: { x: 4, y: -20 },
  },
  {
    slug: 'stick-lacrosse',
    name: 'Lacrosse stick',
    covers: ['lacrosse'],
    attachTo: 'wristR',
    offset: { x: 4, y: -10 },
  },
  {
    slug: 'puck',
    name: 'Puck',
    covers: ['ice-hockey'],
    attachTo: 'ankleR',
    offset: { x: 10, y: 0 },
  },
  {
    slug: 'bar-barbell',
    name: 'Barbell',
    covers: ['weight-room'],
    attachTo: 'wristL',
    offset: { x: 0, y: -2 },
  },
  {
    slug: 'net-goal',
    name: 'Goal / net',
    covers: ['soccer', 'ice-hockey', 'field-hockey', 'water-polo', 'handball', 'lacrosse'],
    attachTo: 'spine',
    offset: { x: 60, y: 30 },
  },
  {
    slug: 'net-court',
    name: 'Net (court)',
    covers: ['volleyball', 'tennis', 'badminton', 'table-tennis', 'pickleball'],
    attachTo: 'spine',
    offset: { x: 80, y: 20 },
  },
  {
    slug: 'hurdle',
    name: 'Hurdle',
    covers: ['track-and-field', 'general'],
    attachTo: 'ankleL',
    offset: { x: 0, y: 25 },
  },
  {
    slug: 'blocks',
    name: 'Starting blocks',
    covers: ['track-and-field', 'swimming'],
    attachTo: 'ankleL',
    offset: { x: -5, y: -3 },
  },
  {
    slug: 'implement-throw',
    name: 'Throwing implement (shot / discus / javelin)',
    covers: ['track-and-field'],
    attachTo: 'wristR',
    offset: { x: 5, y: 0 },
  },
];

export const PROP_SLUGS = PROPS.map((p) => p.slug);

const BY_SLUG = new Map(PROPS.map((p) => [p.slug, p]));

export function prop(slug) {
  const found = BY_SLUG.get(slug);
  if (!found) throw new Error(`unknown prop ${JSON.stringify(slug)}`);
  return found;
}

export function isProp(slug) {
  return BY_SLUG.has(slug);
}
