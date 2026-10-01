import express from 'express';

/**
 * The knowledge release the app downloads at launch (Backend Knowledge
 * System §25, §29): rules switched off and exercises quarantined during an
 * incident, and what experts have reviewed. Folded from the append-only
 * KnowledgeAction log; changed only with src/scripts/knowledge.js on the
 * server. Safety rules (SAFE-*) can never be switched off.
 *
 *   GET /knowledge/release   (public)
 */
export async function currentRelease(prisma) {
  const actions = await prisma.knowledgeAction.findMany({ orderBy: { createdAt: 'asc' } });
  const disabled = new Set();
  const quarantined = new Set();
  const reviewedItems = new Set();
  const reviewedSports = new Set();
  for (const a of actions) {
    if (a.kind === 'disable_rule' && !a.target.startsWith('SAFE-')) disabled.add(a.target);
    if (a.kind === 'enable_rule') disabled.delete(a.target);
    if (a.kind === 'quarantine_item') { quarantined.add(a.target); reviewedItems.delete(a.target); }
    if (a.kind === 'release_item') quarantined.delete(a.target);
    if (a.kind === 'review_item' && !quarantined.has(a.target)) reviewedItems.add(a.target);
    if (a.kind === 'review_sport') reviewedSports.add(a.target);
  }
  const last = actions.at(-1);
  return {
    release: last ? `k${actions.length}-${last.createdAt.toISOString().slice(0, 10)}` : 'k0',
    disabledRules: [...disabled].sort(),
    quarantinedItems: [...quarantined].sort(),
    reviewedItems: [...reviewedItems].sort(),
    reviewedSports: [...reviewedSports].sort(),
  };
}

export function knowledgeRouter({ prisma }) {
  const router = express.Router();
  router.get('/knowledge/release', async (req, res) => {
    res.set('Cache-Control', 'no-cache');
    res.json(await currentRelease(prisma));
  });
  return router;
}
