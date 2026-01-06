/**
 * Resource Management Utility Module
 *
 * Provides unified resource monitoring and management capabilities:
 * - Network connection pooling (undici)
 * - System metrics collection (systeminformation)
 * - File operations (fs-extra)
 * - Configuration validation (zod)
 *
 * @module resource-manager
 */

import { Pool } from 'undici';
import si from 'systeminformation';
import fs from 'fs-extra';
import { z } from 'zod';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Singleton HTTP pool
let httpPool = null;

/**
 * Initialize HTTP connection pool
 * @param {string} baseUrl - Base URL for requests
 * @param {Object} options - Pool options
 * @returns {Pool} Undici pool instance
 */
export function initHttpPool(baseUrl, options = {}) {
  if (httpPool) {
    return httpPool;
  }

  const poolSize = parseInt(process.env.UNDICI_POOL_SIZE || '100', 10);
  const keepAliveTimeout = parseInt(process.env.UNDICI_KEEP_ALIVE_TIMEOUT || '60000', 10);

  httpPool = new Pool(baseUrl, {
    connections: options.connections || poolSize,
    keepAliveTimeout: options.keepAliveTimeout || keepAliveTimeout,
    bodyTimeout: options.bodyTimeout || 30000,
  });

  return httpPool;
}

/**
 * Get HTTP pool instance
 * @returns {Pool} Undici pool instance
 */
export function getHttpPool() {
  if (!httpPool) {
    throw new Error('HTTP pool not initialized. Call initHttpPool() first.');
  }
  return httpPool;
}

/**
 * Close HTTP connection pool
 */
export async function closeHttpPool() {
  if (httpPool) {
    await httpPool.close();
    httpPool = null;
  }
}

/**
 * Resource metrics schema
 */
export const resourceMetricsSchema = z.object({
  timestamp: z.string(),
  cpu: z.object({
    cores: z.number(),
    load: z.number(),
    model: z.string().optional(),
  }),
  memory: z.object({
    total: z.number(),
    used: z.number(),
    free: z.number(),
    usagePercent: z.number(),
  }),
  disk: z.object({
    total: z.number(),
    used: z.number(),
    free: z.number(),
    usagePercent: z.number(),
  }),
  network: z.array(z.object({
    iface: z.string(),
    rx: z.number(),
    tx: z.number(),
  })),
});

/**
 * Collect system resource metrics
 * @returns {Promise<Object>} Resource metrics
 */
export async function collectResourceMetrics() {
  const [cpu, cpuLoad, mem, disk, network] = await Promise.all([
    si.cpu(),
    si.cpuLoad(),
    si.mem(),
    si.fsSize(),
    si.networkStats(),
  ]);

  const diskInfo = disk[0];
  const networkInfo = network[0];

  return {
    timestamp: new Date().toISOString(),
    cpu: {
      cores: cpu.cores,
      load: cpuLoad.currentLoad,
      model: cpu.model,
    },
    memory: {
      total: mem.total,
      used: mem.used,
      free: mem.free,
      usagePercent: (mem.used / mem.total) * 100,
    },
    disk: {
      total: diskInfo?.size || 0,
      used: diskInfo?.used || 0,
      free: diskInfo?.available || 0,
      usagePercent: diskInfo?.use || 0,
    },
    network: networkInfo ? [
      {
        iface: networkInfo.iface,
        rx: networkInfo.rx,
        tx: networkInfo.tx,
      },
    ] : [],
  };
}

/**
 * Validate resource metrics against schema
 * @param {Object} metrics - Metrics to validate
 * @returns {Object} Validation result
 */
export function validateResourceMetrics(metrics) {
  return resourceMetricsSchema.safeParse(metrics);
}

/**
 * File operation utilities
 */
export const fileOps = {
  /**
   * Ensure directory exists
   * @param {string} dirPath - Directory path
   * @returns {Promise<void>}
   */
  async ensureDir(dirPath) {
    await fs.ensureDir(dirPath);
  },

  /**
   * Write JSON file with formatting
   * @param {string} filePath - File path
   * @param {Object} data - Data to write
   * @param {number} spaces - Indentation spaces
   * @returns {Promise<void>}
   */
  async writeJson(filePath, data, spaces = 2) {
    await fs.writeJson(filePath, data, { spaces });
  },

  /**
   * Read JSON file
   * @param {string} filePath - File path
   * @returns {Promise<Object>} Parsed JSON
   */
  async readJson(filePath) {
    return fs.readJson(filePath);
  },

  /**
   * Copy file with metadata preservation
   * @param {string} src - Source path
   * @param {string} dest - Destination path
   * @returns {Promise<void>}
   */
  async copy(src, dest) {
    await fs.copy(src, dest, { preserveTimestamps: true });
  },

  /**
   * Remove path safely
   * @param {string} path - Path to remove
   * @returns {Promise<void>}
   */
  async remove(path) {
    await fs.remove(path);
  },

  /**
   * Check if path exists
   * @param {string} path - Path to check
   * @returns {Promise<boolean>}
   */
  async exists(path) {
    return fs.pathExists(path);
  },
};

/**
 * Configuration validation utilities
 */
export const configValidation = {
  /**
   * Server configuration schema
   */
  serverConfig: z.object({
    host: z.string().default('0.0.0.0'),
    port: z.number().min(1).max(65535).default(8080),
    env: z.enum(['development', 'production', 'test']).default('development'),
    logLevel: z.enum(['error', 'warn', 'info', 'debug']).default('info'),
  }),

  /**
   * Database configuration schema
   */
  databaseConfig: z.object({
    host: z.string(),
    port: z.number().default(5432),
    name: z.string(),
    user: z.string(),
    password: z.string(),
    pool: z.object({
      min: z.number().min(0).default(5),
      max: z.number().min(1).default(50),
      idleTimeout: z.number().positive().default(600000),
    }).optional(),
  }),

  /**
   * Validate server configuration
   * @param {Object} config - Configuration to validate
   * @returns {Object} Validation result
   */
  validateServerConfig(config) {
    return this.serverConfig.safeParse(config);
  },

  /**
   * Validate database configuration
   * @param {Object} config - Configuration to validate
   * @returns {Object} Validation result
   */
  validateDatabaseConfig(config) {
    return this.databaseConfig.safeParse(config);
  },

  /**
   * Create custom schema
   * @param {Object} schemaDef - Schema definition
   * @returns {z.ZodSchema}
   */
  createSchema(schemaDef) {
    return z.object(schemaDef);
  },
};

/**
 * Resource monitor class for continuous monitoring
 */
export class ResourceMonitor {
  constructor(options = {}) {
    this.interval = options.interval || 10000; // Default 10 seconds
    this.metrics = [];
    this.maxMetrics = options.maxMetrics || 100; // Keep last 100 metrics
    this.isRunning = false;
    this.timer = null;
  }

  /**
   * Start monitoring
   */
  start() {
    if (this.isRunning) {
      return;
    }

    this.isRunning = true;
    this.timer = setInterval(async () => {
      try {
        const metrics = await collectResourceMetrics();
        this.metrics.push(metrics);

        // Trim old metrics
        if (this.metrics.length > this.maxMetrics) {
          this.metrics.shift();
        }
      } catch (error) {
        console.error('Error collecting metrics:', error.message);
      }
    }, this.interval);
  }

  /**
   * Stop monitoring
   */
  stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
    this.isRunning = false;
  }

  /**
   * Get current metrics
   * @returns {Object|null} Latest metrics
   */
  getCurrentMetrics() {
    return this.metrics.length > 0 ? this.metrics[this.metrics.length - 1] : null;
  }

  /**
   * Get all metrics history
   * @returns {Array} Metrics history
   */
  getMetricsHistory() {
    return [...this.metrics];
  }

  /**
   * Get average metrics over time
   * @returns {Object} Averaged metrics
   */
  getAverageMetrics() {
    if (this.metrics.length === 0) {
      return null;
    }

    const avg = {
      cpu: 0,
      memory: 0,
      disk: 0,
    };

    for (const m of this.metrics) {
      avg.cpu += m.cpu.load;
      avg.memory += m.memory.usagePercent;
      avg.disk += m.disk.usagePercent;
    }

    const count = this.metrics.length;
    return {
      cpu: avg.cpu / count,
      memory: avg.memory / count,
      disk: avg.disk / count,
      samples: count,
    };
  }
}

// Default export
export default {
  initHttpPool,
  getHttpPool,
  closeHttpPool,
  collectResourceMetrics,
  validateResourceMetrics,
  fileOps,
  configValidation,
  ResourceMonitor,
};
