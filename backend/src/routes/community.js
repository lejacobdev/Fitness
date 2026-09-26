import express from 'express';

import { verifySessionToken } from '../lib/sessionToken.js';

const KINDS = new Set(['workout', 'leagueMember', 'league', 'team', 'assignment']);
const TARGET = /^[\p{L}\p{N} ._:@-]{1,80}$/u;
const EMAIL = /^[^\s@]{1,64}@[^\s@]{1,190}\.[^\s@]{2,20}$/;
/** A shared workout this many people reported stops being shared. */
const AUTO_HIDE_AT = 3;

/**
 * Community safety and contact (App Store guidelines 1.2 and 1.5).
 *
 *   POST /reports            { kind, target, reason? }  (anyone; signed-in reports count toward removal)
 *   POST /support/messages   { email?, message }        (the support page's form)
 */
export function communityRouter({ prisma, sessionSecret }) {
  const router = express.Router();
  /** Who is reporting, when signed in (guests can report too). */
  const optionalAuth = (req, _res, next) => {
    const match = /^Bearer (.+)$/.exec(req.get('authorization') ?? '');
    try {
      req.athleteId = match ? verifySessionToken(match[1], { secret: sessionSecret }).athleteId : null;
    } catch {
      req.athleteId = null;
    }
    next();
  };
  // Crude flood control per process: a few messages per address per hour.
  const recent = new Map();
  const limited = (key, max = 5) => {
    const now = Date.now();
    const times = (recent.get(key) ?? []).filter((t) => now - t < 3_600_000);
    if (times.length >= max) return true;
    recent.set(key, [...times, now]);
    return false;
  };

  router.post('/reports', optionalAuth, async (req, res) => {
    const kind = req.body?.kind;
    const target = typeof req.body?.target === 'string' ? req.body.target.trim() : '';
    const reason = typeof req.body?.reason === 'string' ? req.body.reason.trim().slice(0, 300) || null : null;
    if (!KINDS.has(kind) || !TARGET.test(target)) {
      res.status(400).json({ error: 'invalid_report' });
      return;
    }
    if (limited(`report:${req.athleteId ?? req.ip}`, 30)) {
      res.status(429).json({ error: 'too_many' });
      return;
    }
    await prisma.report.create({ data: { reporterId: req.athleteId, kind, target, reason } });
    if (kind === 'workout') {
      // Only signed-in people count, one vote each — anonymous reports are still reviewed by hand.
      const reporters = new Set((await prisma.report.findMany({ where: { kind, target } })).map((r) => r.reporterId).filter(Boolean));
      if (reporters.size >= AUTO_HIDE_AT) await prisma.sharedWorkout.deleteMany({ where: { code: target.toUpperCase() } });
    }
    res.status(201).json({ ok: true });
  });

  router.post('/support/messages', express.urlencoded({ extended: false, limit: '20kb' }), async (req, res) => {
    const message = typeof req.body?.message === 'string' ? req.body.message.trim().slice(0, 4000) : '';
    const email = typeof req.body?.email === 'string' && EMAIL.test(req.body.email.trim()) ? req.body.email.trim() : null;
    const wantsHtml = req.is('application/x-www-form-urlencoded');
    if (message.length < 5 || limited(`support:${req.ip}`)) {
      if (wantsHtml) res.status(400).type('html').send(thanks(false));
      else res.status(400).json({ error: message.length < 5 ? 'empty' : 'too_many' });
      return;
    }
    await prisma.supportMessage.create({ data: { email, message } });
    if (wantsHtml) res.status(201).type('html').send(thanks(true));
    else res.status(201).json({ ok: true });
  });

  return router;
}

function thanks(ok) {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Support — AthleteOS</title><style>body{font:17px/1.5 -apple-system,BlinkMacSystemFont,sans-serif;max-width:640px;margin:0 auto;padding:40px 18px;}
@media (prefers-color-scheme: dark){body{background:#000;color:#fff}}</style></head><body>
<h1>${ok ? 'Thanks — we got your message.' : 'That didn\'t send.'}</h1>
<p>${ok ? 'We read every message and reply within a few days if you left an email address.' : 'Write a few words in the message box and try again.'}</p>
<p><a href="support">Back to Support</a></p></body></html>`;
}
