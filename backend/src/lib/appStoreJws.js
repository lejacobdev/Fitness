import crypto from 'node:crypto';

import { APPLE_ROOT_CA_G3_PEM } from './appleRootCerts.js';

/**
 * §18: App Store Server Notifications V2 arrive as a JWS `signedPayload`
 * whose header carries an `x5c` chain [leaf, intermediate, root]. This is
 * the only way to know a notification really came from Apple, and it is the
 * gate in front of the only code path that writes `proUntil`. No SDK.
 *
 * Checks, all load-bearing:
 *   - `alg` pinned to ES256 (Apple's only algorithm here).
 *   - the chain's root is byte-for-byte a trusted root (Apple Root CA - G3).
 *   - each certificate is signed by the next and is within its validity window.
 *   - the leaf and intermediate carry Apple's App Store receipt-signing OIDs.
 *   - the JWS signature verifies against the leaf's public key.
 */

export class AppStoreJwsError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'AppStoreJwsError';
    this.code = code;
  }
}

/** DER encodings of the marker OIDs Apple puts in its signing certificates. */
const LEAF_OID = Buffer.from('060a2a864886f76364060b01', 'hex'); // 1.2.840.113635.100.6.11.1
const INTERMEDIATE_OID = Buffer.from('060a2a864886f76364060201', 'hex'); // 1.2.840.113635.100.6.2.1

function decodeJson(part, what) {
  try {
    const value = JSON.parse(Buffer.from(part, 'base64url').toString('utf8'));
    if (value === null || typeof value !== 'object' || Array.isArray(value)) throw new Error('not an object');
    return value;
  } catch {
    throw new AppStoreJwsError('malformed', `${what} is not a JSON object`);
  }
}

function certFromBase64(der, index) {
  try {
    return new crypto.X509Certificate(Buffer.from(der, 'base64'));
  } catch {
    throw new AppStoreJwsError('bad_chain', `x5c[${index}] is not a certificate`);
  }
}

/**
 * Build a verifier. `rootCertificates` (PEM strings) and `requireAppleOids`
 * exist so tests can exercise the real chain logic with a locally generated
 * CA; production uses the defaults.
 */
export function createAppStoreVerifier({
  rootCertificates = [APPLE_ROOT_CA_G3_PEM],
  requireAppleOids = true,
  now = () => new Date(),
} = {}) {
  const roots = rootCertificates.map((pem) => new crypto.X509Certificate(pem));

  function verify(jws) {
    if (typeof jws !== 'string') throw new AppStoreJwsError('malformed', 'payload is not a string');
    const parts = jws.split('.');
    if (parts.length !== 3) throw new AppStoreJwsError('malformed', 'payload is not a compact JWS');
    const [headerPart, payloadPart, signaturePart] = parts;

    const header = decodeJson(headerPart, 'JWS header');
    if (header.alg !== 'ES256') throw new AppStoreJwsError('bad_alg', `alg ${JSON.stringify(header.alg)} is not ES256`);
    if (!Array.isArray(header.x5c) || header.x5c.length < 2) {
      throw new AppStoreJwsError('bad_chain', 'x5c chain is missing');
    }

    const chain = header.x5c.map(certFromBase64);
    const at = now();

    // The chain must terminate in a trusted root — compared by raw bytes, not name.
    const last = chain[chain.length - 1];
    const trustedRoot = roots.find((root) => root.raw.equals(last.raw))
      ?? roots.find((root) => last.checkIssued(root) && last.verify(root.publicKey));
    if (!trustedRoot) throw new AppStoreJwsError('untrusted_root', 'chain does not end at a trusted root');

    const full = trustedRoot.raw.equals(last.raw) ? chain : [...chain, trustedRoot];
    for (let i = 0; i < full.length; i += 1) {
      const cert = full[i];
      if (new Date(cert.validFrom) > at || new Date(cert.validTo) < at) {
        throw new AppStoreJwsError('expired_cert', `certificate ${i} is outside its validity window`);
      }
      const issuer = full[i + 1] ?? cert;
      if (!cert.verify(issuer.publicKey)) {
        throw new AppStoreJwsError('bad_chain', `certificate ${i} is not signed by its issuer`);
      }
    }

    if (requireAppleOids) {
      if (!chain[0].raw.includes(LEAF_OID)) throw new AppStoreJwsError('bad_chain', 'leaf is not an App Store signing certificate');
      if (!chain[1].raw.includes(INTERMEDIATE_OID)) throw new AppStoreJwsError('bad_chain', 'intermediate is not Apple\'s WWDR certificate');
    }

    const ok = crypto.verify(
      'sha256',
      Buffer.from(`${headerPart}.${payloadPart}`),
      { key: chain[0].publicKey, dsaEncoding: 'ieee-p1363' },
      Buffer.from(signaturePart, 'base64url'),
    );
    if (!ok) throw new AppStoreJwsError('bad_signature', 'JWS signature does not verify');

    return decodeJson(payloadPart, 'JWS payload');
  }

  return { verify };
}
