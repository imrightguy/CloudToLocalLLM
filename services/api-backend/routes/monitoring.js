/**
 * @fileoverview Monitoring and performance dashboard routes
 * Provides real-time performance metrics and health monitoring for the tunnel system
 */

import express from 'express';
import {
  TunnelLogger,
  ERROR_CODES,
  ErrorResponseBuilder,
} from '../utils/logger.js';
import { adminAuth } from '../middleware/admin-auth.js';

const router = express.Router();

/**
 * Create monitoring routes
 * @param {Object} tunnelProxy - TunnelProxy instance
 * @param {winston.Logger} [logger] - Logger instance
 * @returns {express.Router} Express router with monitoring endpoints
 */
export function createMonitoringRoutes(tunnelProxy, logger) {
  const tunnelLogger =
    logger instanceof TunnelLogger ? logger : new TunnelLogger('monitoring');

  /**
   * Get comprehensive system performance metrics
   * Requires admin authentication
   */
  router.get('/performance', adminAuth(['view_system_metrics']), (req, res) => {
    try {
      const performanceMetrics = tunnelProxy.getPerformanceMetrics();

      res.json({
        success: true,
        data: performanceMetrics,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.INTERNAL_SERVER_ERROR,
        'Failed to get performance metrics',
        { error: error.message }
      );

      res
        .status(500)
        .json(
          ErrorResponseBuilder.internalServerError(
            'Failed to retrieve performance metrics',
            ERROR_CODES.INTERNAL_SERVER_ERROR
          )
        );
    }
  });

  /**
   * Get system health status
   * Requires admin authentication
   */
  router.get('/health', adminAuth(['view_system_metrics']), (req, res) => {
    try {
      const healthStatus = tunnelProxy.getHealthStatus();
      const statusCode = healthStatus.status === 'healthy' ? 200 : 503;

      res.status(statusCode).json({
        success: true,
        data: healthStatus,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.INTERNAL_SERVER_ERROR,
        'Failed to get health status',
        { error: error.message }
      );

      res
        .status(500)
        .json(
          ErrorResponseBuilder.internalServerError(
            'Failed to retrieve health status',
            ERROR_CODES.INTERNAL_SERVER_ERROR
          )
        );
    }
  });

  /**
   * Get performance alerts
   * Requires admin authentication
   */
  router.get('/alerts', adminAuth(['view_system_metrics']), (req, res) => {
    try {
      const alerts = tunnelProxy.performanceAlerts || [];
      const activeAlerts = alerts.filter((alert) => {
        // Filter alerts from last 5 minutes
        const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
        return new Date(alert.timestamp) > fiveMinutesAgo;
      });

      res.json({
        success: true,
        data: {
          alerts: activeAlerts,
          totalAlerts: alerts.length,
          activeAlerts: activeAlerts.length,
          lastCheck: tunnelProxy.lastPerformanceCheck,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.INTERNAL_SERVER_ERROR,
        'Failed to get performance alerts',
        { error: error.message }
      );

      res
        .status(500)
        .json(
          ErrorResponseBuilder.internalServerError(
            'Failed to retrieve performance alerts',
            ERROR_CODES.INTERNAL_SERVER_ERROR
          )
        );
    }
  });

  /**
   * Get connection statistics
   * Requires admin authentication
   */
  router.get('/connections', adminAuth(['view_system_metrics']), (req, res) => {
    try {
      const stats = tunnelProxy.getStats();
      const connectionDetails = [];

      // Get detailed connection information
      for (const [
        connectionId,
        connection,
      ] of tunnelProxy.connections.entries()) {
        connectionDetails.push({
          connectionId,
          userId: connection.userId,
          isConnected: connection.isConnected,
          connectedAt: connection.connectedAt,
          lastActivity: connection.lastActivity,
          lastPing: connection.lastPing,
          pendingRequests: connection.pendingRequests.size,
        });
      }

      res.json({
        success: true,
        data: {
          summary: stats.connections,
          connections: connectionDetails,
          userConnections: tunnelProxy.userConnections.size,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.INTERNAL_SERVER_ERROR,
        'Failed to get connection statistics',
        { error: error.message }
      );

      res
        .status(500)
        .json(
          ErrorResponseBuilder.internalServerError(
            'Failed to retrieve connection statistics',
            ERROR_CODES.INTERNAL_SERVER_ERROR
          )
        );
    }
  });

  /**
   * Get request statistics with optional filtering
   * Requires admin authentication
   */
  router.get('/requests', adminAuth(['view_system_metrics']), (req, res) => {
    try {
      const { timeframe = '1h' } = req.query;
      const stats = tunnelProxy.getStats();
      const performanceMetrics = tunnelProxy.getPerformanceMetrics();

      // Calculate timeframe-specific metrics
      let timeframeMs;
      switch (timeframe) {
        case '5m':
          timeframeMs = 5 * 60 * 1000;
          break;
        case '15m':
          timeframeMs = 15 * 60 * 1000;
          break;
        case '1h':
          timeframeMs = 60 * 60 * 1000;
          break;
        case '24h':
          timeframeMs = 24 * 60 * 60 * 1000;
          break;
        default:
          timeframeMs = 60 * 60 * 1000; // Default to 1 hour
      }

      const cutoff = new Date(Date.now() - timeframeMs);
      const recentRequests = tunnelProxy.metrics.requestTimestamps.filter(
        (timestamp) => timestamp > cutoff
      );

      res.json({
        success: true,
        data: {
          timeframe,
          summary: stats.requests,
          performance: performanceMetrics.performance,
          enhanced: performanceMetrics.enhanced,
          recentActivity: {
            requestCount: recentRequests.length,
            requestsPerMinute: recentRequests.length / (timeframeMs / 60000),
            timeframe: timeframe,
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.INTERNAL_SERVER_ERROR,
        'Failed to get request statistics',
        { error: error.message }
      );

      res
        .status(500)
        .json(
          ErrorResponseBuilder.internalServerError(
            'Failed to retrieve request statistics',
            ERROR_CODES.INTERNAL_SERVER_ERROR
          )
        );
    }
  });

  /**
   * Get memory and resource usage
   * Requires admin authentication
   */
  router.get('/resources', adminAuth(['view_system_metrics']), (req, res) => {
    try {
      const performanceMetrics = tunnelProxy.getPerformanceMetrics();
      const processMemory = process.memoryUsage();

      res.json({
        success: true,
        data: {
          tunnel: {
            memoryUsageMB: performanceMetrics.enhanced.memoryUsageMB,
            peakMemoryUsageMB: performanceMetrics.enhanced.peakMemoryUsageMB,
            connectionPoolStats:
              performanceMetrics.enhanced.connectionPoolStats,
            queueStats: performanceMetrics.enhanced.queueStats,
          },
          process: {
            rss: Math.round((processMemory.rss / 1024 / 1024) * 100) / 100,
            heapUsed:
              Math.round((processMemory.heapUsed / 1024 / 1024) * 100) / 100,
            heapTotal:
              Math.round((processMemory.heapTotal / 1024 / 1024) * 100) / 100,
            external:
              Math.round((processMemory.external / 1024 / 1024) * 100) / 100,
          },
          system: {
            uptime: process.uptime(),
            nodeVersion: process.version,
            platform: process.platform,
            arch: process.arch,
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.INTERNAL_SERVER_ERROR,
        'Failed to get resource usage',
        { error: error.message }
      );

      res
        .status(500)
        .json(
          ErrorResponseBuilder.internalServerError(
            'Failed to retrieve resource usage',
            ERROR_CODES.INTERNAL_SERVER_ERROR
          )
        );
    }
  });

  /**
   * Get dashboard summary with key metrics
   * Requires admin authentication
   */
  router.get('/dashboard', adminAuth(['view_system_metrics']), (req, res) => {
    try {
      const performanceMetrics = tunnelProxy.getPerformanceMetrics();
      const healthStatus = tunnelProxy.getHealthStatus();
      const alerts = tunnelProxy.performanceAlerts || [];

      // Calculate key performance indicators
      const kpis = {
        availability:
          healthStatus.status === 'healthy'
            ? 100
            : healthStatus.status === 'degraded'
              ? 75
              : 0,
        responseTime: performanceMetrics.performance.averageResponseTime,
        throughput: performanceMetrics.enhanced.throughputPerMinute,
        errorRate: 100 - performanceMetrics.requests.successRate,
        activeConnections: performanceMetrics.connections.total,
        alertCount: alerts.length,
      };

      // Recent trends (simplified)
      const trends = {
        responseTime: 'stable', // Would calculate from historical data
        throughput: 'stable',
        errorRate: 'stable',
        connections: 'stable',
      };

      res.json({
        success: true,
        data: {
          kpis,
          trends,
          health: {
            status: healthStatus.status,
            checks: healthStatus.checks,
          },
          alerts: alerts.slice(0, 5), // Latest 5 alerts
          performance: {
            p95ResponseTime: performanceMetrics.enhanced.p95ResponseTime,
            p99ResponseTime: performanceMetrics.enhanced.p99ResponseTime,
            memoryUsageMB: performanceMetrics.enhanced.memoryUsageMB,
            poolEfficiency:
              performanceMetrics.enhanced.connectionPoolStats.poolEfficiency,
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.INTERNAL_SERVER_ERROR,
        'Failed to get dashboard data',
        { error: error.message }
      );

      res
        .status(500)
        .json(
          ErrorResponseBuilder.internalServerError(
            'Failed to retrieve dashboard data',
            ERROR_CODES.INTERNAL_SERVER_ERROR
          )
        );
    }
  });

  /**
   * Force performance check (for testing/debugging)
   * Requires admin authentication
   */
  router.post('/check', adminAuth(['view_system_metrics']), (req, res) => {
    try {
      tunnelProxy.checkPerformanceAlerts();
      tunnelProxy.updateMemoryUsage();

      const alerts = tunnelProxy.performanceAlerts || [];

      res.json({
        success: true,
        message: 'Performance check completed',
        data: {
          alertsGenerated: alerts.length,
          alerts: alerts,
          lastCheck: tunnelProxy.lastPerformanceCheck,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.INTERNAL_SERVER_ERROR,
        'Failed to perform performance check',
        { error: error.message }
      );

      res
        .status(500)
        .json(
          ErrorResponseBuilder.internalServerError(
            'Failed to perform performance check',
            ERROR_CODES.INTERNAL_SERVER_ERROR
          )
        );
    }
  });

  return router;
}

export default router;
