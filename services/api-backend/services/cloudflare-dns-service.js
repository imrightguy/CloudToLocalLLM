/**
 * Cloudflare DNS Configuration Service
 *
 * Handles DNS record management via Cloudflare API including:
 * - DNS record CRUD operations (create, read, update, delete)
 * - DNS record validation against Google Workspace requirements
 * - Record caching with 5-minute TTL
 * - Rate limiting handling for Cloudflare API
 * - Error handling and logging
 */

import logger from '../logger.js';
import { v4 as uuidv4 } from 'uuid';
import fetch from 'node-fetch';

class CloudflareDNSService {
  constructor(db) {
    this.db = db;
    this.apiToken = process.env.CLOUDFLARE_API_TOKEN;
    this.apiUrl = 'https://api.cloudflare.com/client/v4';
    this.zoneId = process.env.CLOUDFLARE_ZONE_ID;
    this.recordCache = new Map();
    this.cacheTTL = 5 * 60 * 1000; // 5 minutes
    this.rateLimitRetryAfter = 0;
    this.rateLimitResetTime = 0;
  }

  /**
   * Validate Cloudflare configuration
   *
   * @throws {Error} If configuration is missing
   */
  validateConfiguration() {
    if (!this.apiToken) {
      throw new Error('CLOUDFLARE_API_TOKEN not configured');
    }
    if (!this.zoneId) {
      throw new Error('CLOUDFLARE_ZONE_ID not configured');
    }
  }

  /**
   * Make HTTP request to Cloudflare API with rate limit handling
   *
   * @private
   * @param {string} method - HTTP method (GET, POST, PUT, DELETE)
   * @param {string} endpoint - API endpoint path
   * @param {Object} [body] - Request body for POST/PUT
   * @returns {Promise<Object>} API response
   */
  async _makeRequest(method, endpoint, body = null) {
    // Check if we're rate limited
    if (this.rateLimitResetTime > Date.now()) {
      const waitTime = Math.ceil((this.rateLimitResetTime - Date.now()) / 1000);
      logger.warn('Cloudflare API rate limit active, waiting', { waitTime });
      await new Promise((resolve) => setTimeout(resolve, waitTime * 1000));
    }

    const url = `${this.apiUrl}${endpoint}`;
    const headers = {
      Authorization: `Bearer ${this.apiToken}`,
      'Content-Type': 'application/json',
    };

    const options = {
      method,
      headers,
    };

    if (body) {
      options.body = JSON.stringify(body);
    }

    try {
      const response = await fetch(url, options);

      // Handle rate limiting
      if (response.status === 429) {
        const retryAfter = response.headers.get('Retry-After');
        this.rateLimitRetryAfter = parseInt(retryAfter || '60', 10);
        this.rateLimitResetTime = Date.now() + this.rateLimitRetryAfter * 1000;

        logger.warn('Cloudflare API rate limited', {
          retryAfter: this.rateLimitRetryAfter,
          endpoint,
        });

        // Retry after waiting
        await new Promise((resolve) =>
          setTimeout(resolve, this.rateLimitRetryAfter * 1000)
        );
        return this._makeRequest(method, endpoint, body);
      }

      const data = await response.json();

      if (!response.ok) {
        const errorMessage =
          data.errors?.[0]?.message || `HTTP ${response.status}`;
        throw new Error(`Cloudflare API error: ${errorMessage}`);
      }

      return data;
    } catch (error) {
      logger.error('Cloudflare API request failed', {
        method,
        endpoint,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Create a DNS record via Cloudflare API
   *
   * @param {Object} params - Record parameters
   * @param {string} params.userId - User ID creating the record
   * @param {string} params.recordType - DNS record type (A, AAAA, CNAME, MX, TXT, SPF, DKIM, DMARC)
   * @param {string} params.name - Full domain name (e.g., mail.example.com)
   * @param {string} params.value - Record value
   * @param {number} [params.ttl] - Time to live (default: 3600)
   * @param {number} [params.priority] - Priority for MX records
   * @returns {Promise<Object>} Created record with provider ID
   */
  async createRecord({
    userId,
    recordType,
    name,
    value,
    ttl = 3600,
    priority = null,
  }) {
    this.validateConfiguration();

    try {
      // Prepare Cloudflare API request
      const recordData = {
        type: recordType,
        name: name,
        content: value,
        ttl: ttl,
      };

      // Add priority for MX records
      if (recordType === 'MX' && priority) {
        recordData.priority = priority;
      }

      // Create record via Cloudflare API
      const response = await this._makeRequest(
        'POST',
        `/zones/${this.zoneId}/dns_records`,
        recordData
      );

      if (!response.success) {
        throw new Error('Failed to create DNS record in Cloudflare');
      }

      const record = response.result;

      // Store record in database
      const dbRecord = await this._storeRecord({
        userId,
        provider: 'cloudflare',
        providerRecordId: record.id,
        recordType,
        name,
        value,
        ttl,
        priority,
        status: 'active',
      });

      // Invalidate cache
      this._invalidateCache();

      logger.info('DNS record created successfully', {
        userId,
        recordType,
        name,
        providerId: record.id,
      });

      return dbRecord;
    } catch (error) {
      logger.error('Failed to create DNS record', {
        userId,
        recordType,
        name,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update a DNS record via Cloudflare API
   *
   * @param {Object} params - Update parameters
   * @param {string} params.recordId - Database record ID
   * @param {string} params.userId - User ID updating the record
   * @param {string} [params.value] - New record value
   * @param {number} [params.ttl] - New TTL
   * @param {number} [params.priority] - New priority for MX records
   * @returns {Promise<Object>} Updated record
   */
  async updateRecord({
    recordId,
    userId,
    value = null,
    ttl = null,
    priority = null,
  }) {
    this.validateConfiguration();

    try {
      // Get existing record from database
      const dbRecord = await this._getRecordFromDb(recordId);

      if (!dbRecord) {
        throw new Error('Record not found');
      }

      if (dbRecord.user_id !== userId) {
        throw new Error('Unauthorized to update this record');
      }

      // Prepare update data
      const updateData = {
        type: dbRecord.record_type,
        name: dbRecord.name,
        content: value || dbRecord.value,
        ttl: ttl || dbRecord.ttl,
      };

      if (dbRecord.record_type === 'MX' && (priority || dbRecord.priority)) {
        updateData.priority = priority || dbRecord.priority;
      }

      // Update record via Cloudflare API
      const response = await this._makeRequest(
        'PUT',
        `/zones/${this.zoneId}/dns_records/${dbRecord.provider_record_id}`,
        updateData
      );

      if (!response.success) {
        throw new Error('Failed to update DNS record in Cloudflare');
      }

      // Update record in database
      const query = `
        UPDATE dns_records
        SET value = $1, ttl = $2, priority = $3, updated_at = NOW()
        WHERE id = $4
        RETURNING *
      `;

      const result = await this.db.query(query, [
        value || dbRecord.value,
        ttl || dbRecord.ttl,
        priority || dbRecord.priority,
        recordId,
      ]);

      // Invalidate cache
      this._invalidateCache();

      logger.info('DNS record updated successfully', {
        userId,
        recordId,
        recordType: dbRecord.record_type,
      });

      return result.rows[0];
    } catch (error) {
      logger.error('Failed to update DNS record', {
        recordId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Delete a DNS record via Cloudflare API
   *
   * @param {Object} params - Delete parameters
   * @param {string} params.recordId - Database record ID
   * @param {string} params.userId - User ID deleting the record
   * @returns {Promise<void>}
   */
  async deleteRecord({ recordId, userId }) {
    this.validateConfiguration();

    try {
      // Get existing record from database
      const dbRecord = await this._getRecordFromDb(recordId);

      if (!dbRecord) {
        throw new Error('Record not found');
      }

      if (dbRecord.user_id !== userId) {
        throw new Error('Unauthorized to delete this record');
      }

      // Delete record via Cloudflare API
      const response = await this._makeRequest(
        'DELETE',
        `/zones/${this.zoneId}/dns_records/${dbRecord.provider_record_id}`
      );

      if (!response.success) {
        throw new Error('Failed to delete DNS record in Cloudflare');
      }

      // Delete record from database
      const query = `
        DELETE FROM dns_records
        WHERE id = $1
      `;

      await this.db.query(query, [recordId]);

      // Invalidate cache
      this._invalidateCache();

      logger.info('DNS record deleted successfully', {
        userId,
        recordId,
        recordType: dbRecord.record_type,
      });
    } catch (error) {
      logger.error('Failed to delete DNS record', {
        recordId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * List all DNS records for the zone
   *
   * @param {Object} params - Query parameters
   * @param {string} [params.userId] - Filter by user ID
   * @param {string} [params.recordType] - Filter by record type
   * @param {string} [params.name] - Filter by name
   * @returns {Promise<Array>} List of DNS records
   */
  async listRecords({ userId = null, recordType = null, name = null }) {
    this.validateConfiguration();

    try {
      // Check cache first
      const cacheKey = `records_${userId}_${recordType}_${name}`;
      const cached = this.recordCache.get(cacheKey);

      if (cached && Date.now() - cached.timestamp < this.cacheTTL) {
        logger.debug('Returning cached DNS records', { cacheKey });
        return cached.data;
      }

      // Build database query
      let query = 'SELECT * FROM dns_records WHERE 1=1';
      const params = [];

      if (userId) {
        query += ` AND user_id = $${params.length + 1}`;
        params.push(userId);
      }

      if (recordType) {
        query += ` AND record_type = $${params.length + 1}`;
        params.push(recordType);
      }

      if (name) {
        query += ` AND name = $${params.length + 1}`;
        params.push(name);
      }

      query += ' ORDER BY created_at DESC';

      const result = await this.db.query(query, params);
      const records = result.rows;

      // Cache the results
      this.recordCache.set(cacheKey, {
        data: records,
        timestamp: Date.now(),
      });

      logger.info('Retrieved DNS records', {
        count: records.length,
        userId,
        recordType,
      });

      return records;
    } catch (error) {
      logger.error('Failed to list DNS records', {
        userId,
        recordType,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Validate DNS records against Google Workspace requirements
   *
   * @param {Object} params - Validation parameters
   * @param {string} params.userId - User ID
   * @param {string} [params.recordId] - Specific record to validate
   * @returns {Promise<Object>} Validation results
   */
  async validateRecords({ userId, recordId = null }) {
    this.validateConfiguration();

    try {
      // Get records to validate
      let records;

      if (recordId) {
        const record = await this._getRecordFromDb(recordId);
        if (!record || record.user_id !== userId) {
          throw new Error('Record not found or unauthorized');
        }
        records = [record];
      } else {
        records = await this.listRecords({ userId });
      }

      const validationResults = {
        valid: true,
        records: [],
        errors: [],
      };

      // Validate each record
      for (const record of records) {
        const recordValidation = await this._validateSingleRecord(record);
        validationResults.records.push(recordValidation);

        if (!recordValidation.valid) {
          validationResults.valid = false;
          validationResults.errors.push({
            recordId: record.id,
            recordType: record.record_type,
            error: recordValidation.error,
          });
        }

        // Update validation status in database
        const query = `
          UPDATE dns_records
          SET validation_status = $1, validated_at = NOW(), validation_error = $2
          WHERE id = $3
        `;

        await this.db.query(query, [
          recordValidation.valid ? 'valid' : 'invalid',
          recordValidation.error || null,
          record.id,
        ]);
      }

      logger.info('DNS records validated', {
        userId,
        totalRecords: records.length,
        validRecords: validationResults.records.filter((r) => r.valid).length,
        invalidRecords: validationResults.records.filter((r) => !r.valid)
          .length,
      });

      return validationResults;
    } catch (error) {
      logger.error('Failed to validate DNS records', {
        userId,
        recordId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Validate a single DNS record
   *
   * @private
   * @param {Object} record - DNS record to validate
   * @returns {Promise<Object>} Validation result
   */
  async _validateSingleRecord(record) {
    try {
      // Validate based on record type
      switch (record.record_type) {
        case 'MX':
          return this._validateMXRecord(record);
        case 'SPF':
          return this._validateSPFRecord(record);
        case 'DKIM':
          return this._validateDKIMRecord(record);
        case 'DMARC':
          return this._validateDMARCRecord(record);
        default:
          return { valid: true, recordType: record.record_type };
      }
    } catch (error) {
      return {
        valid: false,
        recordType: record.record_type,
        error: error.message,
      };
    }
  }

  /**
   * Validate MX record format
   *
   * @private
   * @param {Object} record - MX record
   * @returns {Object} Validation result
   */
  _validateMXRecord(record) {
    // MX records should have format: priority hostname
    const mxRegex = /^\d+\s+[a-zA-Z0-9.-]+\.?$/;

    if (!mxRegex.test(record.value)) {
      return {
        valid: false,
        recordType: 'MX',
        error: 'Invalid MX record format. Expected: priority hostname',
      };
    }

    // Check if it's pointing to Google Workspace
    if (
      !record.value.includes('google.com') &&
      !record.value.includes('gmail.com')
    ) {
      return {
        valid: true,
        recordType: 'MX',
        warning: 'MX record does not point to Google Workspace',
      };
    }

    return { valid: true, recordType: 'MX' };
  }

  /**
   * Validate SPF record format
   *
   * @private
   * @param {Object} record - SPF record
   * @returns {Object} Validation result
   */
  _validateSPFRecord(record) {
    // SPF records should start with v=spf1
    if (!record.value.startsWith('v=spf1')) {
      return {
        valid: false,
        recordType: 'SPF',
        error: 'Invalid SPF record format. Must start with v=spf1',
      };
    }

    // Check if it includes Google Workspace
    if (
      !record.value.includes('google.com') &&
      !record.value.includes('_spf.google.com')
    ) {
      return {
        valid: true,
        recordType: 'SPF',
        warning: 'SPF record does not include Google Workspace',
      };
    }

    return { valid: true, recordType: 'SPF' };
  }

  /**
   * Validate DKIM record format
   *
   * @private
   * @param {Object} record - DKIM record
   * @returns {Object} Validation result
   */
  _validateDKIMRecord(record) {
    // DKIM records should contain v=DKIM1
    if (!record.value.includes('v=DKIM1')) {
      return {
        valid: false,
        recordType: 'DKIM',
        error: 'Invalid DKIM record format. Must contain v=DKIM1',
      };
    }

    return { valid: true, recordType: 'DKIM' };
  }

  /**
   * Validate DMARC record format
   *
   * @private
   * @param {Object} record - DMARC record
   * @returns {Object} Validation result
   */
  _validateDMARCRecord(record) {
    // DMARC records should start with v=DMARC1
    if (!record.value.startsWith('v=DMARC1')) {
      return {
        valid: false,
        recordType: 'DMARC',
        error: 'Invalid DMARC record format. Must start with v=DMARC1',
      };
    }

    return { valid: true, recordType: 'DMARC' };
  }

  /**
   * Store DNS record in database
   *
   * @private
   * @param {Object} params - Record parameters
   * @returns {Promise<Object>} Stored record
   */
  async _storeRecord({
    userId,
    provider,
    providerRecordId,
    recordType,
    name,
    value,
    ttl,
    priority,
    status,
  }) {
    const query = `
      INSERT INTO dns_records (
        id, user_id, provider, provider_record_id, record_type,
        name, value, ttl, priority, status, created_at, updated_at, created_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW(), NOW(), $11)
      RETURNING *
    `;

    const result = await this.db.query(query, [
      uuidv4(),
      userId,
      provider,
      providerRecordId,
      recordType,
      name,
      value,
      ttl,
      priority,
      status,
      userId,
    ]);

    return result.rows[0];
  }

  /**
   * Get record from database
   *
   * @private
   * @param {string} recordId - Record ID
   * @returns {Promise<Object|null>} Record or null if not found
   */
  async _getRecordFromDb(recordId) {
    const query = 'SELECT * FROM dns_records WHERE id = $1';
    const result = await this.db.query(query, [recordId]);
    return result.rows[0] || null;
  }

  /**
   * Invalidate DNS records cache
   *
   * @private
   */
  _invalidateCache() {
    this.recordCache.clear();
    logger.debug('DNS records cache invalidated');
  }

  /**
   * Get recommended DNS records for Google Workspace
   *
   * @param {string} domain - Domain name
   * @returns {Object} Recommended records
   */
  getRecommendedGoogleWorkspaceRecords(domain) {
    return {
      mx: [
        {
          type: 'MX',
          name: domain,
          value: '5 gmail-smtp-in.l.google.com',
          priority: 5,
          ttl: 3600,
          description: 'Primary Google Workspace mail server',
        },
        {
          type: 'MX',
          name: domain,
          value: '10 alt1.gmail-smtp-in.l.google.com',
          priority: 10,
          ttl: 3600,
          description: 'Secondary Google Workspace mail server',
        },
        {
          type: 'MX',
          name: domain,
          value: '20 alt2.gmail-smtp-in.l.google.com',
          priority: 20,
          ttl: 3600,
          description: 'Tertiary Google Workspace mail server',
        },
      ],
      spf: {
        type: 'TXT',
        name: domain,
        value: 'v=spf1 include:_spf.google.com ~all',
        ttl: 3600,
        description: 'SPF record for Google Workspace',
      },
      dmarc: {
        type: 'TXT',
        name: `_dmarc.${domain}`,
        value: `v=DMARC1; p=quarantine; rua=mailto:postmaster@${domain}`,
        ttl: 3600,
        description: 'DMARC policy record',
      },
    };
  }
}

export default CloudflareDNSService;
