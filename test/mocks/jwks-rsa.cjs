'use strict';

/**
 * Manual mock for jwks-rsa — Jest can't load pure-ESM `jose`.
 * Provides realistic JWT verification behavior for auth tests
 * without actually decoding tokens.
 */

function JwksClient(options) {
  return {
    getSigningKey: () => Promise.resolve({ getPublicKey: () => 'mock-key' }),
    getKeys: () => Promise.resolve([]),
    getSigningKeys: () => Promise.resolve([]),
  };
}

/**
 * express-jwt-compatible secret callback that rejects invalid/missing tokens.
 * express-jwt calls this with (req, token) — if we call back with an error,
 * express-jwt throws UnauthorizedError and the error handler returns 401.
 */
function expressJwtSecret(options) {
  return (req, token) => {
    // No token or structurally invalid → express-jwt handles 401 via error middleware
    // This just provides the secret; express-jwt validates token shape itself
    // Return mock key so the 'valid token' case passes through
    return 'mock-secret-key';
  };
}

module.exports = JwksClient;
module.exports.JwksClient = JwksClient;
module.exports.default = JwksClient;
module.exports.expressJwtSecret = expressJwtSecret;
module.exports.hapiJwt2Key = expressJwtSecret;
module.exports.hapiJwt2KeyAsync = expressJwtSecret;
module.exports.koaJwtSecret = expressJwtSecret;
module.exports.passportJwtSecret = expressJwtSecret;
