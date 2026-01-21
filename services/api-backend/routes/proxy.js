import logger from '../logger.js';
import { StreamingProxyManager } from '../streaming-proxy-manager.js';

const proxyManager = new StreamingProxyManager();

export const proxyStartHandler = async (req, res) => {
  try {
    const userId = req.user.sub;
    const userToken = req.headers.authorization;

    logger.info(`Starting streaming proxy for user: ${userId}`);

    // Pass the user object for tier checking
    const proxyMetadata = await proxyManager.provisionProxy(
      userId,
      userToken,
      req.user,
    );

    res.json({
      success: true,
      message: 'Streaming proxy started successfully',
      proxy: {
        proxyId: proxyMetadata.proxyId,
        status: proxyMetadata.status,
        createdAt: proxyMetadata.createdAt,
        directTunnel: proxyMetadata.directTunnel || false,
        endpoint: proxyMetadata.endpoint || null,
        userTier: proxyMetadata.userTier || 'free',
      },
    });
  } catch (error) {
    logger.error(`Failed to start proxy for user ${req.user.sub}:`, error);
    res.status(500).json({
      error: 'Failed to start streaming proxy',
      message: error.message,
    });
  }
};

export const proxyStopHandler = async (req, res) => {
  try {
    const userId = req.user.sub;

    logger.info(`Stopping streaming proxy for user: ${userId}`);

    const success = await proxyManager.terminateProxy(userId);

    if (success) {
      res.json({
        success: true,
        message: 'Streaming proxy stopped successfully',
      });
    } else {
      res.status(404).json({
        error: 'No active proxy found',
        message: 'No streaming proxy is currently running for this user',
      });
    }
  } catch (error) {
    logger.error(`Failed to stop proxy for user ${req.user.sub}:`, error);
    res.status(500).json({
      error: 'Failed to stop streaming proxy',
      message: error.message,
    });
  }
};

export const proxyProvisionHandler = async (req, res) => {
  try {
    const userId = req.user.sub;
    const userToken = req.headers.authorization;
    const { testMode = false } = req.body;

    logger.info(
      `Provisioning streaming proxy for user: ${userId}, testMode: ${testMode}`,
    );

    if (testMode) {
      // In test mode, simulate successful provisioning without creating actual containers
      logger.info(
        `Test mode: Simulating proxy provisioning for user ${userId}`,
      );

      res.json({
        success: true,
        message: 'Streaming proxy provisioned successfully (test mode)',
        testMode: true,

        proxy: {
          proxyId: `test-proxy-${userId}`,
          status: 'simulated',
          createdAt: new Date().toISOString(),
        },
      });
      return;
    }

    // Normal mode - provision actual proxy
    const proxyMetadata = await proxyManager.provisionProxy(
      userId,
      userToken,
      req.user,
    );

    res.json({
      success: true,
      message: 'Streaming proxy provisioned successfully',
      testMode: false,

      proxy: {
        proxyId: proxyMetadata.proxyId,
        status: proxyMetadata.status,
        createdAt: proxyMetadata.createdAt,
        directTunnel: proxyMetadata.directTunnel || false,
        endpoint: proxyMetadata.endpoint || null,
        userTier: proxyMetadata.userTier || 'free',
      },
    });
  } catch (error) {
    logger.error(`Failed to provision proxy for user ${req.user.sub}:`, error);
    res.status(500).json({
      error: 'Failed to provision streaming proxy',
      message: error.message,
      testMode: req.body.testMode || false,
    });
  }
};

export const proxyStatusHandler = async (req, res) => {
  try {
    const userId = req.user.sub;
    const status = await proxyManager.getProxyStatus(userId);

    // Update activity if proxy is running
    if (status.status === 'running') {
      proxyManager.updateProxyActivity(userId);
    }

    res.json(status);
  } catch (error) {
    logger.error(`Failed to get proxy status for user ${req.user.sub}:`, error);
    res.status(500).json({
      error: 'Failed to get proxy status',
      message: error.message,
    });
  }
};
