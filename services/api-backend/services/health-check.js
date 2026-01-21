import winston from 'winston';

/**
 * HealthCheckService
 * Provides comprehensive health checks for all system dependencies
 * Validates: Requirements 1.10
 */
export class HealthCheckService {
  constructor(logger = null) {
    this.logger =
      logger ||
      winston.createLogger({
        level: 'info',
        format: winston.format.json(),
        transports: [new winston.transports.Console()],
      });
    this.dependencies = {
      database: null,
      cache: null,
      services: [],
    };
  }

  /**
   * Register a database dependency for health checking
   */
  registerDatabase(dbMigrator) {
    this.dependencies.database = dbMigrator;
  }

  /**
   * Register a cache dependency for health checking
   */
  registerCache(cacheClient) {
    this.dependencies.cache = cacheClient;
  }

  /**
   * Register a service dependency for health checking
   */
  registerService(serviceName, healthCheckFn) {
    this.dependencies.services.push({
      name: serviceName,
      healthCheck: healthCheckFn,
    });
  }

  /**
   * Check database health
   */
  async checkDatabaseHealth() {
    try {
      if (!this.dependencies.database) {
        return {
          status: 'unknown',
          message: 'Database not registered',
        };
      }

      // Perform a simple ping (lightweight check) instead of full schema validation
      // Schema validation is too heavy for frequent liveness probes
      if (this.dependencies.database.pool) {
        // Postgres
        await this.dependencies.database.pool.query('SELECT 1');
      } else if (this.dependencies.database.db) {
        // SQLite
        await this.dependencies.database.db.get('SELECT 1');
      } else {
        throw new Error('Database connection not initialized');
      }

      return {
        status: 'healthy',
        message: 'Database is healthy',
      };
    } catch (error) {
      this.logger.error('Database health check failed:', error);
      return {
        status: 'unhealthy',
        message: 'Database health check failed',
        error: error.message,
      };
    }
  }

  /**
   * Check cache health
   */
  async checkCacheHealth() {
    try {
      if (!this.dependencies.cache) {
        return {
          status: 'unknown',
          message: 'Cache not registered',
        };
      }

      // Perform a simple ping
      if (typeof this.dependencies.cache.ping === 'function') {
        await this.dependencies.cache.ping();
        return {
          status: 'healthy',
          message: 'Cache is healthy',
        };
      }

      return {
        status: 'unknown',
        message: 'Cache health check not available',
      };
    } catch (error) {
      this.logger.error('Cache health check failed:', error);
      return {
        status: 'unhealthy',
        message: 'Cache health check failed',
        error: error.message,
      };
    }
  }

  /**
   * Check service dependencies health
   */
  async checkServicesHealth() {
    const results = {};

    for (const service of this.dependencies.services) {
      try {
        const result = await service.healthCheck();
        results[service.name] = result;
      } catch (error) {
        this.logger.error(
          `Service health check failed for ${service.name}:`,
          error,
        );
        results[service.name] = {
          status: 'unhealthy',
          message: `Service health check failed: ${error.message}`,
        };
      }
    }

    return results;
  }

  /**
   * Get overall health status
   */
  async getHealthStatus() {
    const timestamp = new Date().toISOString();

    try {
      const databaseHealth = await this.checkDatabaseHealth();
      const cacheHealth = await this.checkCacheHealth();
      const servicesHealth = await this.checkServicesHealth();

      // Determine overall status
      const allStatuses = [
        databaseHealth.status,
        cacheHealth.status,
        ...Object.values(servicesHealth).map((s) => s.status),
      ];

      let overallStatus = 'healthy';
      if (allStatuses.includes('unhealthy')) {
        overallStatus = 'unhealthy';
      } else if (allStatuses.includes('degraded')) {
        overallStatus = 'degraded';
      }

      return {
        status: overallStatus,
        timestamp,
        service: 'cloudtolocalllm-api',
        dependencies: {
          database: databaseHealth,
          cache: cacheHealth,
          services: servicesHealth,
        },
        uptime: process.uptime(),
      };
    } catch (error) {
      this.logger.error('Failed to get health status:', error);
      return {
        status: 'unhealthy',
        timestamp,
        service: 'cloudtolocalllm-api',
        error: error.message || 'Failed to determine health status',
      };
    }
  }
}
