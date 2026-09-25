import express from 'express';

import { AppleIdentityError, verifyAppleIdentityToken } from '../lib/appleIdentity.js';
import { signSessionToken } from '../lib/sessionToken.js';

/**
 * Sign in with Apple, end to end (§3, §14, M4). The only account creation
 * path in the whole app — no email, no password (§23). A returning athlete
 * (same Apple `sub`) is looked up, not re-created, so a reinstall or a new
 * phone restores the same account.
 */
export function authRouter({ prisma, keyStore, appleBundleId, sessionSecret, appleRevoker = null }) {
  const router = express.Router();

  router.post('/apple', async (req, res) => {
    const { identityToken, rawNonce, birthDate, authorizationCode } = req.body ?? {};
    if (typeof identityToken !== 'string' || identityToken.length === 0) {
      res.status(400).json({ error: 'missing_identity_token' });
      return;
    }

    let sub;
    try {
      ({ sub } = await verifyAppleIdentityToken(identityToken, {
        audience: appleBundleId,
        rawNonce,
        keyStore,
      }));
    } catch (err) {
      if (err instanceof AppleIdentityError) {
        res.status(401).json({ error: err.code });
        return;
      }
      throw err;
    }

    let athlete = await prisma.athlete.findUnique({ where: { appleUserId: sub } });

    if (!athlete) {
      // §2: the age gate happens client-side before an account is ever
      // created, so a first sign-in always carries the athlete's birth date.
      // A returning athlete's birth date is already on file and never
      // re-sent, so this branch is the only place it is required.
      if (typeof birthDate !== 'string' || Number.isNaN(Date.parse(birthDate))) {
        res.status(400).json({ error: 'missing_birth_date' });
        return;
      }
      const parsedBirthDate = new Date(birthDate);
      const age = ageInYears(parsedBirthDate);
      if (age < 13) {
        // §2/§23: under-13 has no account path in this app at all. The
        // client's own age gate should never let this request happen; this
        // is the server refusing to trust the client on a compliance-critical
        // check, not the primary enforcement point.
        res.status(403).json({ error: 'under_minimum_age' });
        return;
      }
      athlete = await prisma.athlete.create({
        data: { appleUserId: sub, birthDate: parsedBirthDate },
      });
    }

    // Keep Apple's refresh token so deleting the account can revoke the
    // Sign in with Apple grant. Best effort: sign-in never fails over it.
    if (appleRevoker && typeof authorizationCode === 'string' && authorizationCode.length > 0) {
      try {
        const refreshToken = await appleRevoker.refreshTokenFor(authorizationCode);
        if (refreshToken) {
          athlete = await prisma.athlete.update({ where: { id: athlete.id }, data: { appleRefreshToken: refreshToken } });
        }
      } catch (err) {
        console.error('[siwa] token exchange failed', err?.message ?? '');
      }
    }

    const token = signSessionToken(athlete.id, { secret: sessionSecret });
    res.json({
      sessionToken: token,
      // appleUserId + birthDate travel back too, not just id/createdAt: a
      // restore onto a brand-new device (§3) has no local Athlete row yet,
      // and both are required, non-optional fields on the client's SwiftData
      // model (AthleteModels.swift) -- the client cannot materialise that
      // row from `id`/`createdAt` alone.
      athlete: {
        id: athlete.id,
        appleUserId: athlete.appleUserId,
        birthDate: athlete.birthDate,
        createdAt: athlete.createdAt,
      },
    });
  });

  return router;
}

function ageInYears(birthDate) {
  const now = new Date();
  let age = now.getUTCFullYear() - birthDate.getUTCFullYear();
  const hasHadBirthdayThisYear = (
    now.getUTCMonth() > birthDate.getUTCMonth()
    || (now.getUTCMonth() === birthDate.getUTCMonth() && now.getUTCDate() >= birthDate.getUTCDate())
  );
  if (!hasHadBirthdayThisYear) age -= 1;
  return age;
}
