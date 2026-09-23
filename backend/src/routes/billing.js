import express from 'express';

import { AppStoreJwsError } from '../lib/appStoreJws.js';

/**
 * §18: "POST /billing/appstore/notify receives App Store Server
 * Notifications V2, verifies the JWS signedPayload against Apple's
 * certificate chain, and is the ONLY code path that writes proUntil."
 *
 * Unauthenticated by design — Apple calls it — so the signature check is
 * the whole of the security. Apple retries anything that isn't a 2xx, so a
 * notification that is genuine but not actionable (unknown athlete, another
 * app's bundle) answers 200 and is logged, never 5xx'd into a retry storm.
 */

const REVOKING = new Set(['REFUND', 'REVOKE']);
const ENDING = new Set(['EXPIRED', 'GRACE_PERIOD_EXPIRED']);

/**
 * Pure: given a decoded notification, its decoded transaction and renewal
 * info, and the athlete's current proUntil, return the new proUntil — or
 * `undefined` for "no change".
 */
export function nextProUntil({ notificationType, subtype }, transaction, renewal, current, now = new Date()) {
  if (!transaction) return undefined;

  if (REVOKING.has(notificationType)) {
    // A refund or Family Sharing revocation ends access now.
    return transaction.revocationDate ? new Date(transaction.revocationDate) : now;
  }

  const expires = transaction.expiresDate ? new Date(transaction.expiresDate) : null;

  if (ENDING.has(notificationType)) {
    return expires ?? now;
  }

  // §18: "Grace period and billing retry keep Pro active."
  let candidate = expires;
  if (notificationType === 'DID_FAIL_TO_RENEW' && subtype === 'GRACE_PERIOD' && renewal?.gracePeriodExpiresDate) {
    const grace = new Date(renewal.gracePeriodExpiresDate);
    if (!candidate || grace > candidate) candidate = grace;
  }
  if (!candidate) return undefined;

  // Notifications can arrive out of order: a stale renewal must never pull
  // an already-later entitlement backwards.
  if (current && new Date(current) >= candidate) return undefined;
  return candidate;
}

export function billingRouter({ prisma, verifier, bundleId, log = console }) {
  const router = express.Router();

  router.post('/', async (req, res) => {
    const signedPayload = req.body?.signedPayload;
    if (typeof signedPayload !== 'string') {
      res.status(400).json({ error: 'missing_signed_payload' });
      return;
    }

    let notification;
    let transaction = null;
    let renewal = null;
    try {
      notification = verifier.verify(signedPayload);
      const data = notification.data ?? {};
      if (data.signedTransactionInfo) transaction = verifier.verify(data.signedTransactionInfo);
      if (data.signedRenewalInfo) renewal = verifier.verify(data.signedRenewalInfo);
    } catch (err) {
      if (err instanceof AppStoreJwsError) {
        log.warn?.('[billing] rejected notification', err.code);
        res.status(400).json({ error: 'invalid_signature' });
        return;
      }
      throw err;
    }

    const data = notification.data ?? {};
    if (bundleId && data.bundleId && data.bundleId !== bundleId) {
      res.status(200).json({ ok: true, ignored: 'other_bundle' });
      return;
    }
    if (!transaction) {
      // TEST notifications and summary types carry no transaction.
      res.status(200).json({ ok: true, ignored: notification.notificationType ?? 'no_transaction' });
      return;
    }

    // appAccountToken is the athlete id the app set at purchase time; the
    // originalTransactionId covers restores and renewals from another device.
    let athlete = null;
    if (typeof transaction.appAccountToken === 'string') {
      athlete = await prisma.athlete.findUnique({ where: { id: transaction.appAccountToken.toLowerCase() } })
        ?? await prisma.athlete.findUnique({ where: { id: transaction.appAccountToken } });
    }
    if (!athlete && transaction.originalTransactionId) {
      athlete = await prisma.athlete.findUnique({ where: { originalTransactionId: String(transaction.originalTransactionId) } });
    }
    if (!athlete) {
      log.warn?.('[billing] notification for an unknown athlete', notification.notificationType);
      res.status(200).json({ ok: true, ignored: 'unknown_athlete' });
      return;
    }

    const proUntil = nextProUntil(notification, transaction, renewal, athlete.proUntil);
    const update = {};
    if (proUntil !== undefined) update.proUntil = proUntil;
    if (transaction.originalTransactionId && athlete.originalTransactionId !== String(transaction.originalTransactionId)) {
      update.originalTransactionId = String(transaction.originalTransactionId);
    }
    if (Object.keys(update).length > 0) {
      await prisma.athlete.update({ where: { id: athlete.id }, data: update });
    }
    res.status(200).json({ ok: true });
  });

  return router;
}
