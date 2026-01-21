/**
 * Authentication Database Migration System (PostgreSQL) for CloudToLocalLLM
 * Separate database instance for authentication data only
 */

import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import pg from 'pg';
import winston from 'winston';

const __dirname = dirname(fileURLToPath(import.meta.url));

export class AuthDatabaseMigratorPG {
  constructor(config = {}, logger = winston.createLogger()) {
    this.logger = logger;

    // Build connection config from env with overrides
    this.config = {
      host: process.env.AUTH_DB_HOST || config.host,
      port: parseInt(process.env.AUTH_DB_PORT || config.port || '5432', 10),
      database:
        process.env.AUTH_DB_NAME || config.database || 'cloudtolocalllm_auth',
      user: process.env.AUTH_DB_USER || config.user,
      password: process.env.AUTH_DB_PASSWORD || config.password,
      ssl:
        process.env.AUTH_DB_SSL === 'true'
          ? { rejectUnauthorized: false }
          : undefined,
      max: parseInt(process.env.AUTH_DB_POOL_MAX || '5', 10), // Smaller pool for auth DB
      idleTimeoutMillis: parseInt(process.env.AUTH_DB_POOL_IDLE || '30000', 10),
      connectionTimeoutMillis: parseInt(
        process.env.AUTH_DB_POOL_CONNECT_TIMEOUT || '30000',
        10
      ),
      ...config,
    };

    this.pool = new pg.Pool(this.config);
  }

  async initialize() {
    try {
      const client = await this.pool.connect();
      await client.query('SELECT 1');
      client.release();
      this.logger.info('Auth PostgreSQL connection established', {
        host: this.config.host,
        database: this.config.database,
      });
      return true;
    } catch (error) {
      this.logger.error('Failed to connect to Auth PostgreSQL', {
        error: error.message,
      });
      throw error;
    }
  }

  async migrate() {
    try {
      this.logger.info('Starting auth database migration...');

      const schemaPath = join(__dirname, 'schema-auth.pg.sql');
      const schemaSQL = readFileSync(schemaPath, 'utf-8');

      // Split SQL into individual statements
      const statements = schemaSQL
        .split(';')
        .map((s) => s.trim())
        .filter((s) => s.length > 0 && !s.startsWith('--'));

      const client = await this.pool.connect();

      try {
        for (const statement of statements) {
          if (statement.trim()) {
            try {
              await client.query(statement);
            } catch (error) {
              // Ignore "already exists" errors for CREATE IF NOT EXISTS
              if (!error.message.includes('already exists')) {
                this.logger.warn(
                  `Auth migration statement warning: ${error.message}`,
                  {
                    statement: statement.substring(0, 100),
                  }
                );
              }
            }
          }
        }

        this.logger.info('Auth database migration completed successfully');
      } finally {
        client.release();
      }
    } catch (error) {
      this.logger.error('Auth database migration failed', {
        error: error.message,
      });
      throw error;
    }
  }

  async query(text, params) {
    return await this.pool.query(text, params);
  }

  async getClient() {
    return await this.pool.connect();
  }

  get pool() {
    return this._pool;
  }

  set pool(value) {
    this._pool = value;
  }

  async close() {
    await this.pool.end();
    this.logger.info('Auth PostgreSQL pool closed');
  }
}
