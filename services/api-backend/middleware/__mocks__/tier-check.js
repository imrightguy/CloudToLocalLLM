/**
 * Mock for tier-check middleware
 * Used in tests to bypass real tier checking
 */

export const addTierInfo = (req, res, next) => {
  req.userTier = 'free';
  next();
};
