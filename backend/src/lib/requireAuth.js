import { SessionTokenError, verifySessionToken } from './sessionToken.js';

/**
 * Every route under §3's "sync" responsibility needs this. Reads
 * `Authorization: Bearer <token>`, verifies it against SESSION_SECRET, and
 * sets `req.athleteId` — never trusts an athlete id supplied in the request
 * body, since that would let one athlete read or write another's data by
 * simply changing an id in the payload.
 */
export function requireAuth({ sessionSecret }) {
  return (req, res, next) => {
    const header = req.get('authorization') ?? '';
    const match = /^Bearer (.+)$/.exec(header);
    if (!match) {
      res.status(401).json({ error: 'missing_authorization' });
      return;
    }
    try {
      const { athleteId } = verifySessionToken(match[1], { secret: sessionSecret });
      req.athleteId = athleteId;
      next();
    } catch (err) {
      if (err instanceof SessionTokenError) {
        res.status(401).json({ error: err.code });
        return;
      }
      next(err);
    }
  };
}
