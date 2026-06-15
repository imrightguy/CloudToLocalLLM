const nodeCrypto = require('node:crypto');

/**
 * Constant-time comparison of a caller-provided webhook secret against the
 * expected value. Returns false (never throws) when either side is missing,
 * empty, or of a different length — so callers can fail closed safely.
 *
 * Using crypto.timingSafeEqual avoids leaking secret length/contents through
 * early-exit timing differences that `===`/`!==` would expose.
 *
 * @param {unknown} provided - value from the request header
 * @param {unknown} expected - configured secret
 * @returns {boolean}
 */
const safeSecretEqual = (provided, expected) => {
  if (typeof provided !== 'string' || typeof expected !== 'string') {
    return false;
  }
  if (provided.length === 0 || expected.length === 0) {
    return false;
  }
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  if (a.length !== b.length) {
    return false;
  }
  return nodeCrypto.timingSafeEqual(a, b);
};

module.exports = { safeSecretEqual };
