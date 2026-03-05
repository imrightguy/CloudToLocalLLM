/**
 * Mock for composite-auth middleware
 * Used in tests to bypass real authentication
 */

export const authenticateComposite = [
  (req, res, next) => {
    const authHeader = req.headers.authorization;
    const token = authHeader?.replace('Bearer ', '');

    // Accept valid-token for successful auth
    // Also accept tokens starting with 'valid-' for testing multiple requests
    if (token === 'valid-token' || token?.startsWith('valid-')) {
      req.user = { sub: 'test-user-id' };
      req.userId = 'test-user-id';
      return next();
    }

    // Reject invalid-token
    if (token === 'invalid-token') {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    // No auth header
    return res.status(401).json({ error: 'Unauthorized' });
  },
];
