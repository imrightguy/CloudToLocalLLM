/**
 * Centralized Database Connection Pool Configuration
 *
 * Provides a singleton PostgreSQL connection pool with:
 * - Maximum pool size of 50 connections
 * - Connection timeout of 30 seconds
 * - Idle connection timeout of 10 minutes
 * - Connection reuse and health monitoring
 * - Comprehensive error handling and logging
 *
 * Requirements: 17 (Data Persistence and Storage)
 */

import pg from 'pg';
import logger from '../logger.js';
import { wrapPool } from './query-wrapper.js';
import { initializeQueryTracking } from './query-performance-tracker.js';

const { Pool } = pg;

// Singleton pool instance
let pool = null;
let poolMetrics = {
  totalConnections: 0,
  idleConnections: 0,
  waitingClients: 0,
  errors: 0,
  lastHealthCheck: null,
  healthCheckStatus: 'unknown',
};

/**
 * Database pool configuration
 * All values can be overridden via environment variables
 */
const getPoolConfig = () => ({
  // Connection settings
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'CloudToLocalLLM',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,

  // SSL configuration
  ssl:
    process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,

  // Pool settings (Requirement 17)
  max: parseInt(process.env.DB_POOL_MAX || '50', 10), // Maximum pool size: 50 connections
  min: parseInt(process.env.DB_POOL_MIN || '5', 10), // Minimum pool size: 5 connections

  // Timeout settings (Requirement 17)
  connectionTimeoutMillis: parseInt(
    process.env.DB_POOL_CONNECT_TIMEOUT || '30000',
    10,
  ), // 30 seconds
  idleTimeoutMillis: parseInt(process.env.DB_POOL_IDLE || '600000', 10), // 10 minutes

  // Connection reuse settings
  allowExitOnIdle: false, // Keep pool alive even when idle

  // Statement timeout (prevent long-running queries)
  statement_timeout: parseInt(process.env.DB_STATEMENT_TIMEOUT || '60000', 10), // 60 seconds
});

/**
 * Initialize the database connection pool
 * Creates a singleton pool instance with health monitoring
 *
 * @returns {Pool} PostgreSQL connection pool
 */
export function initializePool() {
  if (pool) {
    return pool;
  }

  const poolConfig = getPoolConfig();

  // Support for testing without real database (Requirement: CI Stability)
  if (process.env.NODE_ENV === 'test' && !process.env.DB_HOST) {
    logger.info('🟡 [DB Pool] Using mock pool for test environment');

    // In-memory store keyed by table name — each table gets an array of row objects
    const mockStore = {};
    let mockIdCounter = 0;

    const generateId = () =>
      'mock-' + ++mockIdCounter + '-' + Math.random().toString(36).substr(2, 5);

    /**
     * Parse SQL to extract table name from INSERT or SELECT statements
     */
    const parseTableName = (sql) => {
      const insertMatch = sql.match(/INSERT\s+INTO\s+(\w+)/i);
      if (insertMatch) {
        return insertMatch[1];
      }
      const fromMatch = sql.match(/FROM\s+(\w+)/i);
      if (fromMatch) {
        return fromMatch[1];
      }
      const updateMatch = sql.match(/UPDATE\s+(\w+)/i);
      if (updateMatch) {
        return updateMatch[1];
      }
      const deleteMatch = sql.match(/DELETE\s+FROM\s+(\w+)/i);
      if (deleteMatch) {
        return deleteMatch[1];
      }
      return null;
    };

    /**
     * Parse RETURNING columns from an INSERT statement
     */
    const parseReturning = (sql) => {
      const match = sql.match(/RETURNING\s+(.+?)(?:\s*;?\s*$)/i);
      if (match) {
        return match[1].split(',').map((c) => c.trim());
      }
      return null;
    };

    /**
     * Parse SELECT columns (handles SELECT * and explicit column lists)
     */
    const parseSelectColumns = (sql) => {
      const match = sql.match(/SELECT\s+(.*?)\s+FROM/i);
      if (match) {
        if (match[1].trim() === '*') {
          return null;
        } // all columns
        return match[1].split(',').map((c) => {
          // Handle "col as alias" and table.col patterns
          const aliased = c.match(/(\w+)\s+as\s+(\w+)/i);
          if (aliased) {
            return { expr: aliased[1].trim(), alias: aliased[2].trim() };
          }
          const dotted = c.match(/(\w+)\.(\w+)/);
          if (dotted) {
            return { expr: dotted[2], alias: dotted[2] };
          }
          return { expr: c.trim(), alias: c.trim() };
        });
      }
      return null;
    };

    /**
     * Extract parameterized values from INSERT and bind them to column names
     */
    const parseInsertColumns = (sql) => {
      const colMatch = sql.match(/INSERT\s+INTO\s+\w+\s*\(([^)]+)\)/i);
      if (!colMatch) {
        return null;
      }
      return colMatch[1].split(',').map((c) => c.trim());
    };

    /**
     * Parse VALUES clause — returns array where each element is either
     * { type: 'param', index: N } or { type: 'literal', value: ... }
     */
    const parseValuesClause = (sql) => {
      const match = sql.match(/VALUES\s*\(([^)]+)\)/i);
      if (!match) {
        return null;
      }
      let remaining = match[1];
      // Split on commas, respecting parentheses and quotes
      const tokens = [];
      let depth = 0,
        current = '',
        inStr = false,
        strChar = '';
      for (let i = 0; i < remaining.length; i++) {
        const ch = remaining[i];
        if (inStr) {
          current += ch;
          if (ch === strChar) {
            inStr = false;
          }
          continue;
        }
        if (ch === "'" || ch === '"') {
          inStr = true;
          strChar = ch;
          current += ch;
          continue;
        }
        if (ch === '(') {
          depth++;
          current += ch;
          continue;
        }
        if (ch === ')') {
          depth--;
          current += ch;
          continue;
        }
        if (ch === ',' && depth === 0) {
          tokens.push(current.trim());
          current = '';
          continue;
        }
        current += ch;
      }
      if (current.trim()) {
        tokens.push(current.trim());
      }

      return tokens.map((token) => {
        const paramMatch = token.match(/^\$(\d+)$/);
        if (paramMatch) {
          return { type: 'param', index: parseInt(paramMatch[1]) - 1 };
        }
        // Handle literal values
        let val = token;
        if (val.startsWith("'") && val.endsWith("'")) {
          val = val.slice(1, -1);
        }
        if (val.toUpperCase() === 'NOW()') {
          val = new Date().toISOString();
        } else if (val.toUpperCase() === 'TRUE') {
          val = true;
        } else if (val.toUpperCase() === 'FALSE') {
          val = false;
        } else if (val.toUpperCase() === 'NULL') {
          val = null;
        } else if (/^-?\d+$/.test(val)) {
          val = parseInt(val, 10);
        } else if (/^-?\d+\.\d+$/.test(val)) {
          val = parseFloat(val);
        }
        return { type: 'literal', value: val };
      });
    };

    /**
     * Parse WHERE conditions for simple equality checks
     * Returns array of { column, paramIndex } for $N placeholders
     */
    const parseWhereConditions = (sql) => {
      const conditions = [];
      const whereMatch = sql.match(
        /WHERE\s+(.+?)(?:\s+ORDER|\s+LIMIT|\s+GROUP|\s+OFFSET|\s*;?\s*$)/i,
      );
      if (!whereMatch) {
        return conditions;
      }
      const whereClause = whereMatch[1];
      const regex = /(\w+)\s*=\s*\$(\d+)/g;
      let m;
      while ((m = regex.exec(whereClause)) !== null) {
        conditions.push({ column: m[1], paramIndex: parseInt(m[2]) - 1 });
      }
      return conditions;
    };

    /**
     * Check if query is a COUNT aggregate
     */
    const isCountQuery = (sql) => /SELECT\s+COUNT\(/i.test(sql);

    /**
     * Mock query handler — simulates a minimal PostgreSQL engine
     */
    const mockQuery = async (sql, params = []) => {
      const trimmed = sql.trim();

      // CREATE TABLE — just acknowledge
      if (/^CREATE\s+/i.test(trimmed)) {
        const table = parseTableName(trimmed);
        if (table && !mockStore[table]) {
          mockStore[table] = [];
        }
        return { rows: [], rowCount: 0 };
      }

      // INSERT — store row in mockStore, return requested columns
      if (/^INSERT\s+/i.test(trimmed)) {
        const table = parseTableName(trimmed);
        if (!mockStore[table]) {
          mockStore[table] = [];
        }

        const columns = parseInsertColumns(trimmed);
        const returning = parseReturning(trimmed);
        const values = parseValuesClause(trimmed);

        const row = {};
        if (columns && values) {
          columns.forEach((col, i) => {
            if (i < values.length) {
              const v = values[i];
              if (v.type === 'param' && v.index < params.length) {
                row[col] = params[v.index];
              } else if (v.type === 'literal') {
                row[col] = v.value;
              }
            }
          });
        } else if (columns && params.length > 0) {
          columns.forEach((col, i) => {
            if (i < params.length) {
              row[col] = params[i];
            }
          });
        }

        // Add generated id and created_at if not present
        if (!row.id) {
          row.id = generateId();
        }
        if (!row.created_at) {
          row.created_at = new Date().toISOString();
        }

        // Add common PostgreSQL-style defaults for columns not in INSERT
        const defaultColumns = {
          is_active: true,
          active: true,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          expires_at: null,
          last_used_at: null,
          status: 'active',
          severity: 'info',
        };
        for (const [col, defaultVal] of Object.entries(defaultColumns)) {
          if (!(col in row)) {
            row[col] = defaultVal;
          }
        }

        mockStore[table].push(row);

        // Build return object based on RETURNING clause
        if (returning) {
          const returnRow = {};
          returning.forEach((col) => {
            returnRow[col] = row[col] !== undefined ? row[col] : null;
          });
          return { rows: [returnRow], rowCount: 1 };
        }

        return { rows: [row], rowCount: 1 };
      }

      // SELECT COUNT — aggregate
      if (isCountQuery(trimmed)) {
        const table = parseTableName(trimmed);
        let rows = table ? mockStore[table] || [] : [];
        const conditions = parseWhereConditions(trimmed);
        conditions.forEach((cond) => {
          if (cond.paramIndex < params.length) {
            rows = rows.filter(
              (r) => r[cond.column] === params[cond.paramIndex],
            );
          }
        });
        return { rows: [{ count: rows.length.toString() }], rowCount: 1 };
      }

      // SELECT — return matching rows from mockStore
      if (/^SELECT\s+/i.test(trimmed)) {
        const table = parseTableName(trimmed);
        let rows = table ? [...(mockStore[table] || [])] : [];

        // Apply WHERE filters
        const conditions = parseWhereConditions(trimmed);
        conditions.forEach((cond) => {
          if (cond.paramIndex < params.length) {
            rows = rows.filter(
              (r) => r[cond.column] === params[cond.paramIndex],
            );
          }
        });

        // Apply ORDER BY — support created_at DESC for deterministic ordering
        const orderMatch = trimmed.match(
          /ORDER\s+BY\s+(\w+)(?:\.\w+)?\s+(ASC|DESC)/i,
        );
        if (orderMatch) {
          const orderCol = orderMatch[1];
          const orderDir = orderMatch[2].toUpperCase();
          rows.sort((a, b) => {
            const va = a[orderCol] || '';
            const vb = b[orderCol] || '';
            const cmp = va < vb ? -1 : va > vb ? 1 : 0;
            return orderDir === 'DESC' ? -cmp : cmp;
          });
        }

        // Deep clone and parse JSON-like strings back to objects (simulates JSONB)
        rows = rows.map((r) => {
          const cloned = { ...r };
          for (const key of Object.keys(cloned)) {
            if (typeof cloned[key] === 'string') {
              try {
                const parsed = JSON.parse(cloned[key]);
                if (typeof parsed === 'object' && parsed !== null) {
                  cloned[key] = parsed;
                }
              } catch {
                // Not JSON, keep as string
              }
            }
          }
          return cloned;
        });

        // Project columns if specified
        const selectCols = parseSelectColumns(trimmed);
        if (selectCols && rows.length > 0) {
          rows = rows.map((r) => {
            const projected = {};
            selectCols.forEach((col) => {
              projected[col.alias] =
                r[col.expr] !== undefined ? r[col.expr] : null;
            });
            return projected;
          });
        }

        // Parse LIMIT and OFFSET
        const limitMatch = trimmed.match(/LIMIT\s+\$(\d+)/i);
        const offsetMatch = trimmed.match(/OFFSET\s+\$(\d+)/i);
        if (offsetMatch && offsetMatch[1]) {
          const offsetIdx = parseInt(offsetMatch[1]) - 1;
          if (offsetIdx < params.length) {
            rows = rows.slice(params[offsetIdx]);
          }
        }
        if (limitMatch && limitMatch[1]) {
          const limitIdx = parseInt(limitMatch[1]) - 1;
          if (limitIdx < params.length) {
            rows = rows.slice(0, params[limitIdx]);
          }
        }

        return { rows, rowCount: rows.length };
      }

      // UPDATE — modify matching rows
      if (/^UPDATE\s+/i.test(trimmed)) {
        const table = parseTableName(trimmed);
        const store = table ? mockStore[table] || [] : [];
        const conditions = parseWhereConditions(trimmed);
        const returning = parseReturning(trimmed);
        let updated = 0;

        // Parse SET clause for simple assignments (col = expr)
        const setMatch = trimmed.match(
          /SET\s+(.+?)(?:\s+WHERE|\s+RETURNING|\s*;?\s*$)/i,
        );
        const setAssignments = [];
        if (setMatch) {
          const setClause = setMatch[1];
          const parts = setClause.split(',').map((s) => s.trim());
          parts.forEach((part) => {
            const assign = part.match(/(\w+)\s*=\s*(.+)/);
            if (assign) {
              setAssignments.push({
                column: assign[1],
                expression: assign[2].trim(),
              });
            }
          });
        }

        store.forEach((row) => {
          let match = true;
          conditions.forEach((cond) => {
            if (
              cond.paramIndex < params.length &&
              row[cond.column] !== params[cond.paramIndex]
            ) {
              match = false;
            }
          });
          if (match) {
            updated++;
            // Apply SET assignments
            setAssignments.forEach((sa) => {
              // Handle "col = col + N" pattern
              const incrementMatch =
                sa.expression.match(/^(\w+)\s*\+\s*(\d+)$/);
              if (incrementMatch) {
                const srcCol = incrementMatch[1];
                const inc = parseInt(incrementMatch[2], 10);
                row[sa.column] =
                  (typeof row[srcCol] === 'number' ? row[srcCol] : 0) + inc;
              } else {
                // Handle literal or param values
                const paramRef = sa.expression.match(/^\$(\d+)$/);
                if (paramRef) {
                  const idx = parseInt(paramRef[1]) - 1;
                  if (idx < params.length) {
                    row[sa.column] = params[idx];
                  }
                } else if (sa.expression.toUpperCase() === 'NOW()') {
                  row[sa.column] = new Date().toISOString();
                } else {
                  // Try to parse as literal
                  let val = sa.expression;
                  if (val.startsWith("'") && val.endsWith("'")) {
                    val = val.slice(1, -1);
                  } else if (val.toUpperCase() === 'TRUE') {
                    val = true;
                  } else if (val.toUpperCase() === 'FALSE') {
                    val = false;
                  } else if (val.toUpperCase() === 'NULL') {
                    val = null;
                  } else if (/^-?\d+$/.test(val)) {
                    val = parseInt(val, 10);
                  } else if (/^-?\d+\.\d+$/.test(val)) {
                    val = parseFloat(val);
                  }
                  row[sa.column] = val;
                }
              }
            });
          }
        });

        // Return updated rows if RETURNING clause
        if (returning) {
          const matchedRows = store.filter((row) => {
            let match = true;
            conditions.forEach((cond) => {
              if (
                cond.paramIndex < params.length &&
                row[cond.column] !== params[cond.paramIndex]
              ) {
                match = false;
              }
            });
            return match;
          });
          const returnRows = matchedRows.map((r) => {
            const projected = {};
            returning.forEach((col) => {
              projected[col] = r[col] !== undefined ? r[col] : null;
            });
            return projected;
          });
          return { rows: returnRows, rowCount: updated };
        }

        return { rows: [], rowCount: updated };
      }

      // DELETE — remove matching rows
      if (/^DELETE\s+/i.test(trimmed)) {
        const table = parseTableName(trimmed);
        if (table && mockStore[table]) {
          const conditions = parseWhereConditions(trimmed);
          if (conditions.length > 0) {
            mockStore[table] = mockStore[table].filter((row) => {
              return !conditions.every((cond) => {
                if (cond.paramIndex < params.length) {
                  return row[cond.column] === params[cond.paramIndex];
                }
                return true;
              });
            });
          } else {
            mockStore[table] = [];
          }
        }
        return { rows: [], rowCount: 0 };
      }

      // Fallback
      return { rows: [{ id: generateId() }], rowCount: 1 };
    };

    pool = {
      query: mockQuery,
      connect: async () => ({
        query: mockQuery,
        release: () => {},
        on: () => {},
      }),
      on: () => {},
      end: async () => {
        // Clear mock store
        Object.keys(mockStore).forEach((k) => delete mockStore[k]);
      },
      totalCount: 0,
      idleCount: 0,
      waitingCount: 0,
    };
    return pool;
  }

  logger.info('🔵 [DB Pool] Initializing PostgreSQL connection pool', {
    host: poolConfig.host,
    database: poolConfig.database,
    maxConnections: poolConfig.max,
    minConnections: poolConfig.min,
    connectionTimeout: `${poolConfig.connectionTimeoutMillis}ms`,
    idleTimeout: `${poolConfig.idleTimeoutMillis}ms`,
  });

  // Initialize query performance tracking
  initializeQueryTracking();

  logger.debug('Creating new Pool instance');
  pool = new Pool(poolConfig);
  logger.debug('Pool instance created successfully');

  // Wrap pool to track query performance
  logger.debug('Wrapping pool for query tracking');
  wrapPool(pool);
  logger.debug('Pool wrapped successfully');

  // Handle pool errors
  pool.on('error', (err, _client) => {
    poolMetrics.errors++;
    logger.error('🔴 [DB Pool] Unexpected error on idle client', {
      error: err.message,
      stack: err.stack,
      totalErrors: poolMetrics.errors,
    });
  });

  // Handle client connection
  pool.on('connect', (_client) => {
    poolMetrics.totalConnections++;
    logger.debug('🟢 [DB Pool] New client connected', {
      totalConnections: poolMetrics.totalConnections,
    });
  });

  // Handle client acquisition
  pool.on('acquire', (_client) => {
    logger.debug('🟡 [DB Pool] Client acquired from pool', {
      totalCount: pool.totalCount,
      idleCount: pool.idleCount,
      waitingCount: pool.waitingCount,
    });
  });

  // Handle client release
  pool.on('release', (err, _client) => {
    if (err) {
      logger.error('🔴 [DB Pool] Error releasing client', {
        error: err.message,
      });
    }
  });

  // Handle client removal
  pool.on('remove', (_client) => {
    logger.debug('🔴 [DB Pool] Client removed from pool', {
      totalCount: pool.totalCount,
      idleCount: pool.idleCount,
    });
  });

  logger.info(
    '✅ [DB Pool] PostgreSQL connection pool initialized successfully',
  );

  return pool;
}

/**
 * Get the database connection pool
 * Initializes the pool if it doesn't exist
 *
 * @returns {Pool} PostgreSQL connection pool
 */
export function getPool() {
  if (!pool) {
    return initializePool();
  }
  return pool;
}

/**
 * Get current pool metrics
 *
 * @returns {Object} Pool metrics including connection counts and health status
 */
export function getPoolMetrics() {
  if (!pool) {
    return {
      ...poolMetrics,
      totalCount: 0,
      idleCount: 0,
      waitingCount: 0,
      status: 'not_initialized',
    };
  }

  return {
    ...poolMetrics,
    totalCount: pool.totalCount,
    idleCount: pool.idleCount,
    waitingCount: pool.waitingCount,
    status: 'active',
  };
}

/**
 * Perform a health check on the database connection
 * Tests connectivity and measures response time
 *
 * @returns {Promise<Object>} Health check result with status and response time
 */
export async function healthCheck() {
  const startTime = Date.now();

  try {
    if (!pool) {
      return {
        healthy: false,
        error: 'Pool not initialized',
        timestamp: new Date().toISOString(),
      };
    }

    // Execute a simple query to test connectivity
    const client = await pool.connect();
    try {
      await client.query('SELECT 1 as health_check');
      const responseTime = Date.now() - startTime;

      poolMetrics.lastHealthCheck = new Date().toISOString();
      poolMetrics.healthCheckStatus = 'healthy';

      return {
        healthy: true,
        responseTime,
        poolMetrics: getPoolMetrics(),
        timestamp: poolMetrics.lastHealthCheck,
      };
    } finally {
      client.release();
    }
  } catch (error) {
    const responseTime = Date.now() - startTime;
    poolMetrics.lastHealthCheck = new Date().toISOString();
    poolMetrics.healthCheckStatus = 'unhealthy';
    poolMetrics.errors++;

    logger.error('🔴 [DB Pool] Health check failed', {
      error: error.message,
      responseTime,
    });

    return {
      healthy: false,
      error: error.message,
      responseTime,
      timestamp: poolMetrics.lastHealthCheck,
    };
  }
}

/**
 * Close the database connection pool
 * Gracefully shuts down all connections
 *
 * @returns {Promise<void>}
 */
export async function closePool() {
  if (!pool) {
    logger.warn('⚠️ [DB Pool] Pool already closed or not initialized');
    return;
  }

  logger.info('🔵 [DB Pool] Closing database connection pool');

  try {
    await pool.end();
    pool = null;

    logger.info('✅ [DB Pool] Database connection pool closed successfully');
  } catch (error) {
    logger.error('🔴 [DB Pool] Error closing database pool', {
      error: error.message,
    });
    throw error;
  }
}

/**
 * Execute a query with automatic connection management
 * Convenience method that handles connection acquisition and release
 *
 * @param {string} text - SQL query text
 * @param {Array} params - Query parameters
 * @returns {Promise<Object>} Query result
 */
export async function query(text, params) {
  const pool = getPool();
  return pool.query(text, params);
}

/**
 * Get a client from the pool for transaction management
 * Caller is responsible for releasing the client
 *
 * @returns {Promise<PoolClient>} Database client
 */
export async function getClient() {
  const pool = getPool();
  return pool.connect();
}

// Export pool configuration for reference
export const poolConfig = getPoolConfig();

// Default export
export default {
  initializePool,
  getPool,
  getPoolMetrics,
  healthCheck,
  closePool,
  query,
  getClient,
  poolConfig,
};
