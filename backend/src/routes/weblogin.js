import crypto from 'node:crypto';

import express from 'express';
import QRCode from 'qrcode';

import { requireAuth } from '../lib/requireAuth.js';
import { signSessionToken } from '../lib/sessionToken.js';

const TTL_MS = 5 * 60_000;
const WEB_SESSION_S = 12 * 60 * 60;
const ID = /^[A-Za-z0-9_-]{20,64}$/;
const PER_IP_PER_10_MIN = 30;

function sha256(value) {
  return crypto.createHash('sha256').update(value, 'utf8').digest('hex');
}

/** "Chrome on Mac" — enough for the athlete to recognise the computer. */
export function deviceName(userAgent = '') {
  const ua = String(userAgent);
  const browser = /Edg\//.test(ua) ? 'Edge'
    : /Firefox\//.test(ua) ? 'Firefox'
      : /Chrome\//.test(ua) ? 'Chrome'
        : /Safari\//.test(ua) ? 'Safari' : 'A browser';
  const os = /iPad/.test(ua) ? 'iPad'
    : /iPhone/.test(ua) ? 'iPhone'
      : /Android/.test(ua) ? 'Android'
        : /CrOS/.test(ua) ? 'Chromebook'
          : /Mac OS X|Macintosh/.test(ua) ? 'Mac'
            : /Windows/.test(ua) ? 'Windows'
              : /Linux/.test(ua) ? 'Linux' : null;
  return os ? `${browser} on ${os}` : browser;
}

/**
 * Signing in to the coach dashboard without a password.
 *
 *   POST /web-login                   browser: → { id, secret, qr (SVG), link, expiresAt }
 *   GET  /web-login/:id/poll          browser, header X-Login-Secret: → { status } and,
 *                                     once approved, a 12-hour session token (one time only)
 *   GET  /web-login/:id/info          app: → { status, device, createdAt }
 *   POST /web-login/:id/approve       app (signed in): sign the browser in as me
 *   POST /web-login/:id/deny          app: "That's not me"
 *
 * The QR code holds only the id (as https://api.lejacob.dev/fitness/login/<id>,
 * which opens the app); the secret never leaves the browser, so a photo of
 * the screen can't collect the session.
 */
export function webLoginRouter({ prisma, sessionSecret, now = () => new Date(), publicBase = 'https://api.lejacob.dev/fitness' }) {
  const router = express.Router();
  const auth = requireAuth({ sessionSecret });
  const created = new Map();

  function limited(ip) {
    const t = now().getTime();
    const recent = (created.get(ip) ?? []).filter((at) => t - at < 10 * 60_000);
    recent.push(t);
    created.set(ip, recent);
    if (created.size > 5000) created.clear();
    return recent.length > PER_IP_PER_10_MIN;
  }

  function statusOf(row) {
    if (!row) return 'expired';
    if (row.deniedAt) return 'denied';
    if (row.claimedAt) return 'used';
    if (row.approvedAt) return 'approved';
    if (row.expiresAt <= now()) return 'expired';
    return 'pending';
  }

  router.post('/web-login', async (req, res) => {
    if (limited(req.ip ?? 'unknown')) {
      res.status(429).json({ error: 'too_many' });
      return;
    }
    await prisma.webLogin.deleteMany({ where: { expiresAt: { lt: new Date(now().getTime() - 60 * 60_000) } } });
    const id = crypto.randomBytes(18).toString('base64url');
    const secret = crypto.randomBytes(24).toString('base64url');
    const expiresAt = new Date(now().getTime() + TTL_MS);
    await prisma.webLogin.create({
      data: { id, secretHash: sha256(secret), device: deviceName(req.get('user-agent')).slice(0, 60), expiresAt, approvedAt: null, deniedAt: null, claimedAt: null, athleteId: null },
    });
    const link = `${publicBase}/login/${id}`;
    const qr = await QRCode.toString(link, { type: 'svg', errorCorrectionLevel: 'M', margin: 1, color: { dark: '#050608', light: '#ffffff' } });
    res.set('Cache-Control', 'no-store');
    res.status(201).json({ id, secret, link, qr, expiresAt: expiresAt.toISOString() });
  });

  router.get('/web-login/:id/poll', async (req, res) => {
    res.set('Cache-Control', 'no-store');
    const id = String(req.params.id);
    const secret = req.get('x-login-secret') ?? '';
    const row = ID.test(id) ? await prisma.webLogin.findUnique({ where: { id } }) : null;
    if (!row || !secret || sha256(secret) !== row.secretHash) {
      res.status(404).json({ error: 'not_found' });
      return;
    }
    const status = statusOf(row);
    if (status !== 'approved') {
      res.json({ status });
      return;
    }
    // One time only: whoever claims first gets it.
    const claimed = await prisma.webLogin.updateMany({ where: { id, claimedAt: null }, data: { claimedAt: now() } });
    if (claimed.count !== 1) {
      res.json({ status: 'used' });
      return;
    }
    const token = signSessionToken(row.athleteId, { secret: sessionSecret, ttlSeconds: WEB_SESSION_S });
    res.json({ status: 'approved', token, expiresIn: WEB_SESSION_S });
  });

  router.get('/web-login/:id/info', auth, async (req, res) => {
    const id = String(req.params.id);
    const row = ID.test(id) ? await prisma.webLogin.findUnique({ where: { id } }) : null;
    if (!row) {
      res.status(404).json({ error: 'not_found' });
      return;
    }
    res.json({ status: statusOf(row), device: row.device, createdAt: row.createdAt.toISOString() });
  });

  for (const action of ['approve', 'deny']) {
    router.post(`/web-login/:id/${action}`, auth, async (req, res) => {
      const id = String(req.params.id);
      const row = ID.test(id) ? await prisma.webLogin.findUnique({ where: { id } }) : null;
      if (statusOf(row) !== 'pending') {
        res.status(404).json({ error: 'expired' });
        return;
      }
      await prisma.webLogin.update({
        where: { id },
        data: action === 'approve' ? { approvedAt: now(), athleteId: req.athleteId } : { deniedAt: now() },
      });
      res.json({ ok: true });
    });
  }

  // The QR link opened somewhere the app isn't (a computer, an Android phone).
  router.get('/login/:id', (_req, res) => {
    res.set('Cache-Control', 'no-store');
    res.type('html').send(`<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><title>AthleteOS</title>
<body style="margin:0;min-height:100vh;display:grid;place-items:center;background:#050608;color:#fff;font:16px/1.5 -apple-system,system-ui,sans-serif;padding:24px;box-sizing:border-box">
<main style="max-width:420px"><p style="letter-spacing:.2em;font-size:12px;color:#ef4444;font-weight:700">ATHLETEOS</p>
<h1 style="font-size:32px;line-height:1.1">Scan this code with the iPhone that has AthleteOS</h1>
<p style="color:rgba(255,255,255,.6)">Open the Camera app on your iPhone and point it at the code on your computer. AthleteOS opens and asks you to approve the sign-in.</p></main>`);
  });

  return router;
}
