/**
 * Cloudflare Infrastructure Tunnel Service
 *
 * Manages the infrastructure Cloudflare tunnel for the CloudToLocalLLM deployment.
 * Provides operations for:
 * - Tunnel status and health monitoring
 * - Connector management
 * - Ingress configuration updates
 * - DNS record management for tunnel CNAMEs
 * - Docker service restart capability
 * - Cache purge operations
 *
 * Required Environment Variables:
 * - CLOUDFLARE_API_KEY: Global API Key (legacy auth)
 * - CLOUDFLARE_EMAIL: Account email
 * - CLOUDFLARE_ACCOUNT_ID: Account ID
 * - CLOUDFLARE_ZONE_ID: Zone ID for domain
 * - CLOUDFLARE_TUNNEL_ID: Tunnel UUID
 *
 * @fileoverview Infrastructure tunnel management service
 * @version 1.0.0
 */

import logger from '../logger.js';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

/**
 * Infrastructure Tunnel Service
 *
 * Manages Cloudflare tunnel operations for deployment automation
 */
class CloudflareInfrastructureTunnelService {
  constructor() {
    this.apiUrl = 'https://api.cloudflare.com/client/v4';
    this.apiKey = process.env.CLOUDFLARE_API_KEY;
    this.email = process.env.CLOUDFLARE_EMAIL;
    this.accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
    this.zoneId = process.env.CLOUDFLARE_ZONE_ID;
    this.tunnelId = process.env.CLOUDFLARE_TUNNEL_ID;
    this.domain = 'cloudtolocalllm.online';
  }

  /**
   * Validate required configuration
   * @throws {Error} If required environment variables are missing
   */
  validateConfiguration() {
    const missing = [];

    if (!this.apiKey) {
      missing.push('CLOUDFLARE_API_KEY');
    }
    if (!this.email) {
      missing.push('CLOUDFLARE_EMAIL');
    }
    if (!this.accountId) {
      missing.push('CLOUDFLARE_ACCOUNT_ID');
    }
    if (!this.zoneId) {
      missing.push('CLOUDFLARE_ZONE_ID');
    }
    if (!this.tunnelId) {
      missing.push('CLOUDFLARE_TUNNEL_ID');
    }

    if (missing.length > 0) {
      throw new Error(
        `Missing required environment variables: ${missing.join(', ')}`,
      );
    }
  }

  /**
   * Make HTTP request to Cloudflare API
   *
   * @private
   * @param {string} method - HTTP method
   * @param {string} endpoint - API endpoint path
   * @param {Object} [body] - Request body
   * @returns {Promise<Object>} API response
   */
  async _makeRequest(method, endpoint, body = null) {
    const url = `${this.apiUrl}${endpoint}`;
    const headers = {
      'X-Auth-Email': this.email,
      'X-Auth-Key': this.apiKey,
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
      const data = await response.json();

      if (!response.ok) {
        const errorMessage =
          data.errors?.[0]?.message || `HTTP ${response.status}`;
        throw new Error(`Cloudflare API error: ${errorMessage}`);
      }

      return data;
    } catch (error) {
      logger.error('[InfraTunnel] API request failed', {
        method,
        endpoint,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get tunnel status and information
   *
   * @returns {Promise<Object>} Tunnel status
   */
  async getTunnelStatus() {
    this.validateConfiguration();

    try {
      const response = await this._makeRequest(
        'GET',
        `/accounts/${this.accountId}/cfd_tunnel/${this.tunnelId}`,
      );

      const tunnel = response.result;

      logger.info('[InfraTunnel] Tunnel status retrieved', {
        status: tunnel.status,
        connections: tunnel.connections?.length || 0,
      });

      return {
        id: tunnel.id,
        name: tunnel.name,
        status: tunnel.status,
        createdAt: tunnel.created_at,
        remoteConfig: tunnel.remote_config,
        configSource: tunnel.config_src,
        connections: tunnel.connections || [],
        activeAt: tunnel.conns_active_at,
        inactiveAt: tunnel.conns_inactive_at,
      };
    } catch (error) {
      logger.error('[InfraTunnel] Failed to get tunnel status', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get active tunnel connectors
   *
   * @returns {Promise<Array>} List of active connectors
   */
  async getConnectors() {
    this.validateConfiguration();

    try {
      const response = await this._makeRequest(
        'GET',
        `/accounts/${this.accountId}/cfd_tunnel/${this.tunnelId}/connections`,
      );

      const connectors = response.result || [];

      logger.info('[InfraTunnel] Connectors retrieved', {
        count: connectors.length,
      });

      return connectors.map((connector) => ({
        id: connector.id,
        version: connector.version,
        arch: connector.arch,
        runAt: connector.run_at,
        features: connector.features,
        connections: (connector.conns || []).map((conn) => ({
          id: conn.id,
          coloName: conn.colo_name,
          originIp: conn.origin_ip,
          openedAt: conn.opened_at,
          isPendingReconnect: conn.is_pending_reconnect,
        })),
      }));
    } catch (error) {
      logger.error('[InfraTunnel] Failed to get connectors', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get current tunnel ingress configuration
   *
   * @returns {Promise<Object>} Ingress configuration
   */
  async getIngressConfig() {
    this.validateConfiguration();

    try {
      const response = await this._makeRequest(
        'GET',
        `/accounts/${this.accountId}/cfd_tunnel/${this.tunnelId}/configurations`,
      );

      const config = response.result;

      logger.info('[InfraTunnel] Ingress config retrieved', {
        version: config.version,
        ruleCount: config.config?.ingress?.length || 0,
      });

      return {
        tunnelId: config.tunnel_id,
        version: config.version,
        source: config.source,
        createdAt: config.created_at,
        ingress: config.config?.ingress || [],
        warpRouting: config.config?.['warp-routing'] || { enabled: false },
      };
    } catch (error) {
      logger.error('[InfraTunnel] Failed to get ingress config', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update tunnel ingress configuration
   *
   * @param {Array} ingress - Ingress rules
   * @param {Object} [options] - Additional options
   * @returns {Promise<Object>} Updated configuration
   */
  async updateIngressConfig(ingress, options = {}) {
    this.validateConfiguration();

    try {
      // Validate ingress rules
      if (!Array.isArray(ingress) || ingress.length === 0) {
        throw new Error('Ingress rules must be a non-empty array');
      }

      // Ensure catch-all rule exists at end
      const lastRule = ingress[ingress.length - 1];
      if (lastRule.hostname) {
        ingress.push({ service: 'http_status:404' });
      }

      const config = {
        config: {
          ingress,
          'warp-routing': options.warpRouting || { enabled: false },
        },
      };

      const response = await this._makeRequest(
        'PUT',
        `/accounts/${this.accountId}/cfd_tunnel/${this.tunnelId}/configurations`,
        config,
      );

      logger.info('[InfraTunnel] Ingress config updated', {
        version: response.result.version,
        ruleCount: ingress.length,
      });

      return {
        tunnelId: response.result.tunnel_id,
        version: response.result.version,
        ingress: response.result.config?.ingress || [],
      };
    } catch (error) {
      logger.error('[InfraTunnel] Failed to update ingress config', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get DNS records for the domain
   *
   * @param {Object} [filters] - Filter options
   * @returns {Promise<Array>} DNS records
   */
  async getDnsRecords(filters = {}) {
    this.validateConfiguration();

    try {
      let endpoint = `/zones/${this.zoneId}/dns_records`;
      const params = new URLSearchParams();

      if (filters.type) {
        params.append('type', filters.type);
      }
      if (filters.name) {
        params.append('name', filters.name);
      }

      if (params.toString()) {
        endpoint += `?${params.toString()}`;
      }

      const response = await this._makeRequest('GET', endpoint);

      logger.info('[InfraTunnel] DNS records retrieved', {
        count: response.result?.length || 0,
      });

      return (response.result || []).map((record) => ({
        id: record.id,
        name: record.name,
        type: record.type,
        content: record.content,
        proxied: record.proxied,
        ttl: record.ttl,
        createdOn: record.created_on,
        modifiedOn: record.modified_on,
      }));
    } catch (error) {
      logger.error('[InfraTunnel] Failed to get DNS records', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get DNS records pointing to the tunnel
   *
   * @returns {Promise<Array>} Tunnel DNS records
   */
  async getTunnelDnsRecords() {
    const allRecords = await this.getDnsRecords({ type: 'CNAME' });

    // Filter records pointing to this tunnel
    const tunnelDomain = `${this.tunnelId}.cfargotunnel.com`;

    return allRecords.filter(
      (record) =>
        record.content === tunnelDomain ||
        record.content.endsWith('.cfargotunnel.com'),
    );
  }

  /**
   * Create or update a DNS CNAME record pointing to the tunnel
   *
   * @param {string} subdomain - Subdomain (e.g., 'api', 'app', or '' for root)
   * @param {Object} [options] - Record options
   * @returns {Promise<Object>} Created/updated record
   */
  async syncTunnelDnsRecord(subdomain, options = {}) {
    this.validateConfiguration();

    const name = subdomain ? `${subdomain}.${this.domain}` : this.domain;
    const content = `${this.tunnelId}.cfargotunnel.com`;
    const proxied = options.proxied !== false; // Default to true

    try {
      // Check if record exists
      const existingRecords = await this.getDnsRecords({
        type: 'CNAME',
        name,
      });

      if (existingRecords.length > 0) {
        // Update existing record
        const recordId = existingRecords[0].id;

        const response = await this._makeRequest(
          'PATCH',
          `/zones/${this.zoneId}/dns_records/${recordId}`,
          { content, proxied },
        );

        logger.info('[InfraTunnel] DNS record updated', {
          name,
          content,
        });

        return response.result;
      } else {
        // Create new record
        const response = await this._makeRequest(
          'POST',
          `/zones/${this.zoneId}/dns_records`,
          {
            type: 'CNAME',
            name,
            content,
            proxied,
            ttl: 1, // Auto TTL when proxied
          },
        );

        logger.info('[InfraTunnel] DNS record created', {
          name,
          content,
        });

        return response.result;
      }
    } catch (error) {
      logger.error('[InfraTunnel] Failed to sync DNS record', {
        subdomain,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Sync all required DNS records for the tunnel
   *
   * @returns {Promise<Object>} Sync results
   */
  async syncAllDnsRecords() {
    const subdomains = ['', 'app', 'api', 'streaming'];
    const results = {
      synced: [],
      failed: [],
    };

    for (const subdomain of subdomains) {
      try {
        const result = await this.syncTunnelDnsRecord(subdomain);
        results.synced.push({
          subdomain: subdomain || '(root)',
          id: result.id,
          name: result.name,
        });
      } catch (error) {
        results.failed.push({
          subdomain: subdomain || '(root)',
          error: error.message,
        });
      }
    }

    logger.info('[InfraTunnel] DNS sync completed', {
      synced: results.synced.length,
      failed: results.failed.length,
    });

    return results;
  }

  /**
   * Purge Cloudflare cache
   *
   * @param {Object} [options] - Purge options
   * @returns {Promise<Object>} Purge result
   */
  async purgeCache(options = {}) {
    this.validateConfiguration();

    try {
      const body = options.urls
        ? { files: options.urls }
        : { purge_everything: true };

      const response = await this._makeRequest(
        'POST',
        `/zones/${this.zoneId}/purge_cache`,
        body,
      );

      logger.info('[InfraTunnel] Cache purged', {
        purgeEverything: !options.urls,
        urlCount: options.urls?.length || 0,
      });

      return {
        success: response.success,
        purgedAt: new Date().toISOString(),
      };
    } catch (error) {
      logger.error('[InfraTunnel] Failed to purge cache', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Restart cloudflared Docker service
   *
   * Requires Docker socket mount: /var/run/docker.sock
   *
   * @returns {Promise<Object>} Restart result
   */
  async restartCloudflaredService() {
    try {
      // Try Docker Swarm service update first
      try {
        const { stdout } = await execAsync(
          'docker service update --force cloudtolocalllm_cloudflared 2>&1',
          { timeout: 60000 },
        );

        logger.info('[InfraTunnel] Cloudflared service restarted (Swarm)', {
          output: stdout.trim(),
        });

        return {
          success: true,
          method: 'swarm',
          message: 'Service update initiated',
          output: stdout.trim(),
        };
      } catch (swarmError) {
        // Fall back to Docker Compose
        logger.warn('[InfraTunnel] Swarm restart failed, trying compose', {
          error: swarmError.message,
        });

        const { stdout } = await execAsync(
          'docker restart cloudflared 2>&1 || docker compose restart cloudflared 2>&1',
          { timeout: 60000 },
        );

        logger.info('[InfraTunnel] Cloudflared container restarted', {
          output: stdout.trim(),
        });

        return {
          success: true,
          method: 'container',
          message: 'Container restarted',
          output: stdout.trim(),
        };
      }
    } catch (error) {
      logger.error('[InfraTunnel] Failed to restart cloudflared', {
        error: error.message,
      });

      return {
        success: false,
        method: 'none',
        message: error.message,
        error: 'Docker socket may not be mounted or service not found',
      };
    }
  }

  /**
   * Get full diagnostics report
   *
   * @returns {Promise<Object>} Diagnostics report
   */
  async getDiagnostics() {
    const diagnostics = {
      timestamp: new Date().toISOString(),
      tunnel: null,
      connectors: null,
      config: null,
      dns: null,
      errors: [],
    };

    try {
      diagnostics.tunnel = await this.getTunnelStatus();
    } catch (error) {
      diagnostics.errors.push({ component: 'tunnel', error: error.message });
    }

    try {
      diagnostics.connectors = await this.getConnectors();
    } catch (error) {
      diagnostics.errors.push({
        component: 'connectors',
        error: error.message,
      });
    }

    try {
      diagnostics.config = await this.getIngressConfig();
    } catch (error) {
      diagnostics.errors.push({ component: 'config', error: error.message });
    }

    try {
      diagnostics.dns = await this.getTunnelDnsRecords();
    } catch (error) {
      diagnostics.errors.push({ component: 'dns', error: error.message });
    }

    // Add health assessment
    diagnostics.health = {
      tunnelHealthy: diagnostics.tunnel?.status === 'healthy',
      hasConnectors:
        (diagnostics.connectors?.[0]?.connections?.length || 0) > 0,
      configVersion: diagnostics.config?.version || 0,
      dnsRecordCount: diagnostics.dns?.length || 0,
      errorCount: diagnostics.errors.length,
    };

    diagnostics.health.overallStatus =
      diagnostics.health.tunnelHealthy &&
      diagnostics.health.hasConnectors &&
      diagnostics.health.errorCount === 0
        ? 'healthy'
        : 'degraded';

    logger.info('[InfraTunnel] Diagnostics collected', {
      status: diagnostics.health.overallStatus,
      errors: diagnostics.errors.length,
    });

    return diagnostics;
  }

  /**
   * Get default Docker Swarm ingress configuration
   *
   * @returns {Array} Default ingress rules for Docker Swarm
   */
  getDefaultSwarmIngress() {
    return [
      {
        hostname: 'app.cloudtolocalllm.online',
        path: '/ws',
        service: 'http://streaming-proxy:3001',
      },
      {
        hostname: 'app.cloudtolocalllm.online',
        path: '/api/tunnel',
        service: 'http://streaming-proxy:3001',
      },
      {
        hostname: 'app.cloudtolocalllm.online',
        path: '/health',
        service: 'http://api-backend:8080',
      },
      {
        hostname: 'app.cloudtolocalllm.online',
        path: '/api',
        service: 'http://api-backend:8080',
      },
      {
        hostname: 'app.cloudtolocalllm.online',
        service: 'http://web:8080',
      },
      {
        hostname: 'api.cloudtolocalllm.online',
        path: '/health',
        service: 'http://api-backend:8080',
      },
      {
        hostname: 'api.cloudtolocalllm.online',
        service: 'http://api-backend:8080',
      },
      {
        hostname: 'streaming.cloudtolocalllm.online',
        service: 'http://streaming-proxy:3001',
      },
      {
        hostname: 'cloudtolocalllm.online',
        service: 'http://web:8080',
      },
      {
        service: 'http_status:404',
      },
    ];
  }

  /**
   * Apply Docker Swarm ingress configuration
   *
   * @returns {Promise<Object>} Update result
   */
  async applySwarmConfig() {
    const ingress = this.getDefaultSwarmIngress();
    return this.updateIngressConfig(ingress);
  }
}

// Singleton instance
let instance = null;

/**
 * Get or create the infrastructure tunnel service instance
 *
 * @returns {CloudflareInfrastructureTunnelService} Service instance
 */
export function getInfrastructureTunnelService() {
  if (!instance) {
    instance = new CloudflareInfrastructureTunnelService();
  }
  return instance;
}

export { CloudflareInfrastructureTunnelService };
export default CloudflareInfrastructureTunnelService;
