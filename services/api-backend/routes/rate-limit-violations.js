/**
 * @fileoverview Rate Limit Violations Routes
 * Endpoints for analyzing and retrieving rate limit violation data
 *
 * Validates: Requirements 6.8
 * - Provides violation analysis endpoints
 * - Includes violation context (user, IP, endpoint)
 * - Supports filtering and pagination
 */

import express from 'express';
import { RateLimitViolationsService } from '../services/rate-limit-violations-service.js';
import { authenticateJWT } from '../middleware/auth.js';
import { requireAdmin } from '../middleware/rbac.js';
import { TunnelLogger } from '../utils/logger.js';

const router = express.Router();
const logger = new TunnelLogger('rate-limit-violations-routes');
const violationsService = new RateLimitViolationsService();

/**
 * GET /violations/user/:userId
 * Get violations for a specific user
 * Admin only
 */
router.get(
  '/violations/user/:userId',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const { userId } = req.params;
      const { limit = 100, offset = 0, startTime, endTime } = req.query;

      const violations = await violationsService.getUserViolations(userId, {
        limit: Math.min(parseInt(limit, 10), 1000),
        offset: parseInt(offset, 10),
        startTime,
        endTime,
      });

      logger.info('Retrieved user violations', {
        correlationId: req.correlationId,
        userId,
        violationCount: violations.length,
      });

      res.json({
        success: true,
        data: violations,
        pagination: {
          limit: parseInt(limit, 10),
          offset: parseInt(offset, 10),
          count: violations.length,
        },
      });
    } catch (error) {
      logger.error('Failed to get user violations', {
        correlationId: req.correlationId,
        error: error.message,
      });

      res.status(500).json({
        success: false,
        error: 'Failed to retrieve violations',
        code: 'VIOLATIONS_RETRIEVAL_FAILED',
      });
    }
  },
);

/**
 * GET /violations/ip/:ipAddress
 * Get violations for a specific IP address
 * Admin only
 */
router.get(
  '/violations/ip/:ipAddress',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const { ipAddress } = req.params;
      const { limit = 100, offset = 0, startTime, endTime } = req.query;

      const violations = await violationsService.getIpViolations(ipAddress, {
        limit: Math.min(parseInt(limit, 10), 1000),
        offset: parseInt(offset, 10),
        startTime,
        endTime,
      });

      logger.info('Retrieved IP violations', {
        correlationId: req.correlationId,
        ipAddress,
        violationCount: violations.length,
      });

      res.json({
        success: true,
        data: violations,
        pagination: {
          limit: parseInt(limit, 10),
          offset: parseInt(offset, 10),
          count: violations.length,
        },
      });
    } catch (error) {
      logger.error('Failed to get IP violations', {
        correlationId: req.correlationId,
        error: error.message,
      });

      res.status(500).json({
        success: false,
        error: 'Failed to retrieve violations',
        code: 'VIOLATIONS_RETRIEVAL_FAILED',
      });
    }
  },
);

/**
 * GET /violations/stats/user/:userId
 * Get violation statistics for a user
 * Admin only
 */
router.get(
  '/violations/stats/user/:userId',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const { userId } = req.params;
      const { startTime, endTime } = req.query;

      const stats = await violationsService.getUserViolationStats(userId, {
        startTime,
        endTime,
      });

      logger.info('Retrieved user violation stats', {
        correlationId: req.correlationId,
        userId,
        totalViolations: stats.totalViolations,
      });

      res.json({
        success: true,
        data: stats,
      });
    } catch (error) {
      logger.error('Failed to get user violation stats', {
        correlationId: req.correlationId,
        error: error.message,
      });

      res.status(500).json({
        success: false,
        error: 'Failed to retrieve violation statistics',
        code: 'STATS_RETRIEVAL_FAILED',
      });
    }
  },
);

/**
 * GET /violations/stats/ip/:ipAddress
 * Get violation statistics for an IP address
 * Admin only
 */
router.get(
  '/violations/stats/ip/:ipAddress',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const { ipAddress } = req.params;
      const { startTime, endTime } = req.query;

      const stats = await violationsService.getIpViolationStats(ipAddress, {
        startTime,
        endTime,
      });

      logger.info('Retrieved IP violation stats', {
        correlationId: req.correlationId,
        ipAddress,
        totalViolations: stats.totalViolations,
      });

      res.json({
        success: true,
        data: stats,
      });
    } catch (error) {
      logger.error('Failed to get IP violation stats', {
        correlationId: req.correlationId,
        error: error.message,
      });

      res.status(500).json({
        success: false,
        error: 'Failed to retrieve violation statistics',
        code: 'STATS_RETRIEVAL_FAILED',
      });
    }
  },
);

/**
 * GET /violations/top-violators
 * Get top violating users
 * Admin only
 */
router.get(
  '/violations/top-violators',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const { limit = 10, startTime, endTime } = req.query;

      const topViolators = await violationsService.getTopViolators({
        limit: Math.min(parseInt(limit, 10), 100),
        startTime,
        endTime,
      });

      logger.info('Retrieved top violators', {
        correlationId: req.correlationId,
        count: topViolators.length,
      });

      res.json({
        success: true,
        data: topViolators,
      });
    } catch (error) {
      logger.error('Failed to get top violators', {
        correlationId: req.correlationId,
        error: error.message,
      });

      res.status(500).json({
        success: false,
        error: 'Failed to retrieve top violators',
        code: 'TOP_VIOLATORS_RETRIEVAL_FAILED',
      });
    }
  },
);

/**
 * GET /violations/top-ips
 * Get top violating IP addresses
 * Admin only
 */
router.get(
  '/violations/top-ips',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const { limit = 10, startTime, endTime } = req.query;

      const topIps = await violationsService.getTopViolatingIps({
        limit: Math.min(parseInt(limit, 10), 100),
        startTime,
        endTime,
      });

      logger.info('Retrieved top violating IPs', {
        correlationId: req.correlationId,
        count: topIps.length,
      });

      res.json({
        success: true,
        data: topIps,
      });
    } catch (error) {
      logger.error('Failed to get top violating IPs', {
        correlationId: req.correlationId,
        error: error.message,
      });

      res.status(500).json({
        success: false,
        error: 'Failed to retrieve top violating IPs',
        code: 'TOP_IPS_RETRIEVAL_FAILED',
      });
    }
  },
);

/**
 * GET /violations/endpoint/:endpoint
 * Get violations for a specific endpoint
 * Admin only
 */
router.get(
  '/violations/endpoint/:endpoint',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const { endpoint } = req.params;
      const { startTime, endTime } = req.query;

      const stats = await violationsService.getEndpointViolations(endpoint, {
        startTime,
        endTime,
      });

      logger.info('Retrieved endpoint violations', {
        correlationId: req.correlationId,
        endpoint,
        violationCount: stats.violationCount,
      });

      res.json({
        success: true,
        data: stats,
      });
    } catch (error) {
      logger.error('Failed to get endpoint violations', {
        correlationId: req.correlationId,
        error: error.message,
      });

      res.status(500).json({
        success: false,
        error: 'Failed to retrieve endpoint violations',
        code: 'ENDPOINT_VIOLATIONS_RETRIEVAL_FAILED',
      });
    }
  },
);

export default router;
