/**
 * Admin DNS Configuration API Routes
 *
 * Provides secure administrative endpoints for DNS record management:
 * - DNS record CRUD operations via Cloudflare API
 * - DNS record validation against Google Workspace requirements
 * - Google Workspace DNS recommendations
 * - One-click Google Workspace DNS setup
 *
 * Security Features:
 * - Admin authentication required
 * - Role-based permission checking
 * - Comprehensive audit logging
 * - Rate limiting for sensitive operations
 */

import express from 'express';
import { adminAuth } from '../../middleware/admin-auth.js';
import { logAdminAction } from '../../utils/audit-logger.js';
import logger from '../../logger.js';
import { getPool } from '../../database/db-pool.js';
import {
  adminReadOnlyLimiter,
  adminRateLimiter,
} from '../../middleware/admin-rate-limiter.js';
import CloudflareDNSService from '../../services/cloudflare-dns-service.js';

const router = express.Router();

// Initialize service (will be set up in route handlers)
let cloudflareDNSService;

/**
 * Initialize Cloudflare DNS service with database pool
 */
function initializeService(pool) {
  if (!cloudflareDNSService) {
    cloudflareDNSService = new CloudflareDNSService(pool);
  }
}

/**
 * POST /api/admin/dns/records
 * Create a new DNS record via Cloudflare
 *
 * Body:
 * - recordType: DNS record type (A, AAAA, CNAME, MX, TXT, SPF, DKIM, DMARC)
 * - name: Full domain name (e.g., mail.example.com)
 * - value: Record value
 * - ttl: Time to live (optional, default: 3600)
 * - priority: Priority for MX records (optional)
 *
 * Returns:
 * - Created record with provider ID
 */
router.post(
  '/records',
  adminRateLimiter,
  adminAuth(['manage_dns_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeService(pool);

      const { recordType, name, value, ttl = 3600, priority = null } = req.body;

      // Validate required fields
      if (!recordType || !name || !value) {
        return res.status(400).json({
          error: 'Missing required fields: recordType, name, value',
          code: 'MISSING_FIELDS',
        });
      }

      // Validate record type
      const validRecordTypes = [
        'A',
        'AAAA',
        'CNAME',
        'MX',
        'TXT',
        'SPF',
        'DKIM',
        'DMARC',
        'NS',
        'SRV',
      ];
      if (!validRecordTypes.includes(recordType)) {
        return res.status(400).json({
          error: `Invalid record type. Valid types: ${validRecordTypes.join(', ')}`,
          code: 'INVALID_RECORD_TYPE',
        });
      }

      // Validate TTL
      if (ttl < 60 || ttl > 86400) {
        return res.status(400).json({
          error: 'TTL must be between 60 and 86400 seconds',
          code: 'INVALID_TTL',
        });
      }

      // Create DNS record
      const record = await cloudflareDNSService.createRecord({
        userId: req.adminUser.id,
        recordType,
        name,
        value,
        ttl,
        priority,
      });

      // Log admin action
      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'dns_record_created',
        resourceType: 'dns_record',
        resourceId: record.id,
        details: {
          recordType,
          name,
          ttl,
          priority,
        },
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      logger.info('✅ [AdminDNS] DNS record created successfully', {
        adminUserId: req.adminUser.id,
        recordId: record.id,
        recordType,
        name,
      });

      res.status(201).json({
        success: true,
        data: {
          id: record.id,
          recordType: record.record_type,
          name: record.name,
          value: record.value,
          ttl: record.ttl,
          priority: record.priority,
          status: record.status,
          createdAt: record.created_at,
        },
        message: 'DNS record created successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminDNS] Failed to create DNS record', {
        adminUserId: req.adminUser?.id,
        recordType: req.body?.recordType,
        name: req.body?.name,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to create DNS record',
        code: 'RECORD_CREATE_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * GET /api/admin/dns/records
 * List DNS records from Cloudflare
 *
 * Query Parameters:
 * - recordType: Filter by record type (optional)
 * - name: Filter by name (optional)
 *
 * Returns:
 * - Array of DNS records
 */
router.get(
  '/records',
  adminReadOnlyLimiter,
  adminAuth(['view_dns_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeService(pool);

      const { recordType = null, name = null } = req.query;

      // List DNS records
      const records = await cloudflareDNSService.listRecords({
        userId: req.adminUser.id,
        recordType,
        name,
      });

      logger.info('✅ [AdminDNS] DNS records retrieved', {
        adminUserId: req.adminUser.id,
        recordCount: records.length,
        recordType,
        name,
      });

      res.json({
        success: true,
        data: {
          records: records.map((record) => ({
            id: record.id,
            recordType: record.record_type,
            name: record.name,
            value: record.value,
            ttl: record.ttl,
            priority: record.priority,
            status: record.status,
            validationStatus: record.validation_status,
            createdAt: record.created_at,
            updatedAt: record.updated_at,
          })),
        },
        count: records.length,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminDNS] Failed to retrieve DNS records', {
        adminUserId: req.adminUser?.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to retrieve DNS records',
        code: 'RECORDS_RETRIEVAL_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * PUT /api/admin/dns/records/:id
 * Update a DNS record via Cloudflare
 *
 * URL Parameters:
 * - id: Record ID
 *
 * Body:
 * - value: New record value (optional)
 * - ttl: New TTL (optional)
 * - priority: New priority for MX records (optional)
 *
 * Returns:
 * - Updated record
 */
router.put(
  '/records/:id',
  adminRateLimiter,
  adminAuth(['manage_dns_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeService(pool);

      const { id } = req.params;
      const { value = null, ttl = null, priority = null } = req.body;

      // Validate at least one field is provided
      if (!value && !ttl && priority === null) {
        return res.status(400).json({
          error: 'At least one field must be provided: value, ttl, or priority',
          code: 'NO_UPDATE_FIELDS',
        });
      }

      // Validate TTL if provided
      if (ttl && (ttl < 60 || ttl > 86400)) {
        return res.status(400).json({
          error: 'TTL must be between 60 and 86400 seconds',
          code: 'INVALID_TTL',
        });
      }

      // Update DNS record
      const record = await cloudflareDNSService.updateRecord({
        recordId: id,
        userId: req.adminUser.id,
        value,
        ttl,
        priority,
      });

      // Log admin action
      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'dns_record_updated',
        resourceType: 'dns_record',
        resourceId: id,
        details: {
          updatedFields: {
            value: value ? 'changed' : 'unchanged',
            ttl: ttl ? 'changed' : 'unchanged',
            priority: priority !== null ? 'changed' : 'unchanged',
          },
        },
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      logger.info('✅ [AdminDNS] DNS record updated successfully', {
        adminUserId: req.adminUser.id,
        recordId: id,
      });

      res.json({
        success: true,
        data: {
          id: record.id,
          recordType: record.record_type,
          name: record.name,
          value: record.value,
          ttl: record.ttl,
          priority: record.priority,
          status: record.status,
          updatedAt: record.updated_at,
        },
        message: 'DNS record updated successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminDNS] Failed to update DNS record', {
        adminUserId: req.adminUser?.id,
        recordId: req.params.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to update DNS record',
        code: 'RECORD_UPDATE_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * DELETE /api/admin/dns/records/:id
 * Delete a DNS record via Cloudflare
 *
 * URL Parameters:
 * - id: Record ID
 *
 * Returns:
 * - Success status
 */
router.delete(
  '/records/:id',
  adminRateLimiter,
  adminAuth(['manage_dns_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeService(pool);

      const { id } = req.params;

      // Delete DNS record
      await cloudflareDNSService.deleteRecord({
        recordId: id,
        userId: req.adminUser.id,
      });

      // Log admin action
      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'dns_record_deleted',
        resourceType: 'dns_record',
        resourceId: id,
        details: {},
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      logger.info('✅ [AdminDNS] DNS record deleted successfully', {
        adminUserId: req.adminUser.id,
        recordId: id,
      });

      res.json({
        success: true,
        message: 'DNS record deleted successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminDNS] Failed to delete DNS record', {
        adminUserId: req.adminUser?.id,
        recordId: req.params.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to delete DNS record',
        code: 'RECORD_DELETE_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * POST /api/admin/dns/validate
 * Validate DNS configuration
 *
 * Query Parameters:
 * - recordId: Specific record to validate (optional)
 *
 * Returns:
 * - Validation results for all or specific records
 */
router.post(
  '/validate',
  adminReadOnlyLimiter,
  adminAuth(['view_dns_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeService(pool);

      const { recordId = null } = req.query;

      // Validate DNS records
      const validationResults = await cloudflareDNSService.validateRecords({
        userId: req.adminUser.id,
        recordId,
      });

      logger.info('✅ [AdminDNS] DNS records validated', {
        adminUserId: req.adminUser.id,
        recordId,
        valid: validationResults.valid,
        totalRecords: validationResults.records.length,
      });

      res.json({
        success: true,
        data: {
          valid: validationResults.valid,
          records: validationResults.records,
          errors: validationResults.errors,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminDNS] Failed to validate DNS records', {
        adminUserId: req.adminUser?.id,
        recordId: req.query?.recordId,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to validate DNS records',
        code: 'VALIDATION_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * GET /api/admin/dns/google-records
 * Get recommended DNS records for Google Workspace
 *
 * Query Parameters:
 * - domain: Domain name (optional, defaults to configured domain)
 *
 * Returns:
 * - Recommended MX, SPF, DKIM, DMARC records
 */
router.get(
  '/google-records',
  adminReadOnlyLimiter,
  adminAuth(['view_dns_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeService(pool);

      const domain =
        req.query.domain || process.env.DOMAIN || 'cloudtolocalllm.online';

      // Get recommended records
      const recommendedRecords =
        cloudflareDNSService.getRecommendedGoogleWorkspaceRecords(domain);

      logger.info(
        '✅ [AdminDNS] Google Workspace DNS recommendations retrieved',
        {
          adminUserId: req.adminUser.id,
          domain,
        },
      );

      res.json({
        success: true,
        data: {
          domain,
          recommendations: {
            mx: recommendedRecords.mx,
            spf: recommendedRecords.spf,
            dmarc: recommendedRecords.dmarc,
          },
          instructions: {
            mx: 'Add all three MX records with the specified priorities',
            spf: 'Add the SPF record to enable Google Workspace to send emails',
            dmarc: 'Add the DMARC record to enable email authentication',
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error(
        '🔴 [AdminDNS] Failed to retrieve Google Workspace DNS recommendations',
        {
          adminUserId: req.adminUser?.id,
          domain: req.query?.domain,
          error: error.message,
          stack: error.stack,
        },
      );

      res.status(500).json({
        error: 'Failed to retrieve DNS recommendations',
        code: 'RECOMMENDATIONS_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * POST /api/admin/dns/setup-google
 * One-click setup of Google Workspace DNS records
 *
 * Body:
 * - domain: Domain name (optional, defaults to configured domain)
 * - recordTypes: Array of record types to create (optional, defaults to all)
 *
 * Returns:
 * - Created records
 */
router.post(
  '/setup-google',
  adminRateLimiter,
  adminAuth(['manage_dns_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeService(pool);

      const domain =
        req.body.domain || process.env.DOMAIN || 'cloudtolocalllm.online';
      const recordTypes = req.body.recordTypes || ['mx', 'spf', 'dmarc'];

      // Get recommended records
      const recommendedRecords =
        cloudflareDNSService.getRecommendedGoogleWorkspaceRecords(domain);

      const createdRecords = [];
      const errors = [];

      // Create MX records
      if (recordTypes.includes('mx')) {
        for (const mxRecord of recommendedRecords.mx) {
          try {
            const record = await cloudflareDNSService.createRecord({
              userId: req.adminUser.id,
              recordType: mxRecord.type,
              name: mxRecord.name,
              value: mxRecord.value,
              ttl: mxRecord.ttl,
              priority: mxRecord.priority,
            });
            createdRecords.push(record);
          } catch (error) {
            errors.push({
              recordType: 'MX',
              error: error.message,
            });
          }
        }
      }

      // Create SPF record
      if (recordTypes.includes('spf')) {
        try {
          const record = await cloudflareDNSService.createRecord({
            userId: req.adminUser.id,
            recordType: recommendedRecords.spf.type,
            name: recommendedRecords.spf.name,
            value: recommendedRecords.spf.value,
            ttl: recommendedRecords.spf.ttl,
          });
          createdRecords.push(record);
        } catch (error) {
          errors.push({
            recordType: 'SPF',
            error: error.message,
          });
        }
      }

      // Create DMARC record
      if (recordTypes.includes('dmarc')) {
        try {
          const record = await cloudflareDNSService.createRecord({
            userId: req.adminUser.id,
            recordType: recommendedRecords.dmarc.type,
            name: recommendedRecords.dmarc.name,
            value: recommendedRecords.dmarc.value,
            ttl: recommendedRecords.dmarc.ttl,
          });
          createdRecords.push(record);
        } catch (error) {
          errors.push({
            recordType: 'DMARC',
            error: error.message,
          });
        }
      }

      // Log admin action
      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'google_workspace_dns_setup',
        resourceType: 'dns_setup',
        resourceId: `${req.adminUser.id}_google_setup`,
        details: {
          domain,
          recordTypesRequested: recordTypes,
          recordsCreated: createdRecords.length,
          errors: errors.length,
        },
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      logger.info('✅ [AdminDNS] Google Workspace DNS setup completed', {
        adminUserId: req.adminUser.id,
        domain,
        recordsCreated: createdRecords.length,
        errors: errors.length,
      });

      res.json({
        success: errors.length === 0,
        data: {
          domain,
          createdRecords: createdRecords.map((record) => ({
            id: record.id,
            recordType: record.record_type,
            name: record.name,
            value: record.value,
            ttl: record.ttl,
            priority: record.priority,
          })),
          errors,
        },
        message:
          errors.length === 0
            ? 'Google Workspace DNS records created successfully'
            : `Created ${createdRecords.length} records with ${errors.length} errors`,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminDNS] Failed to setup Google Workspace DNS', {
        adminUserId: req.adminUser?.id,
        domain: req.body?.domain,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to setup Google Workspace DNS',
        code: 'SETUP_FAILED',
        details: error.message,
      });
    }
  },
);

export default router;
