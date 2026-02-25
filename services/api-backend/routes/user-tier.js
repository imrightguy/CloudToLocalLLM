import logger from '../logger.js';
import { getUserTier, getTierFeatures } from '../middleware/tier-check.js';

export const userTierHandler = [
  (req, res) => {
    try {
      const userTier = getUserTier(req.user);
      const features = getTierFeatures(userTier);

      res.json({
        tier: userTier,
        features: features,
        upgradeUrl:
          process.env.UPGRADE_URL ||
          'https://app.cloudtolocalllm.online/upgrade',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error getting user tier:', error);
      res.status(500).json({
        error: 'Failed to determine user tier',
        code: 'TIER_ERROR',
      });
    }
  },
];
