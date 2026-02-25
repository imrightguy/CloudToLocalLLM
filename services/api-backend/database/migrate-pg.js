/**
 * Database Migration System (PostgreSQL) for CloudToLocalLLM
 */

import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { createHash } from 'crypto';
import pg from 'pg';
import { TunnelLogger } from '../utils/logger.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

export class DatabaseMigratorPG {
  constructor(config = {}) {
    this.logger = new TunnelLogger('database-migrator-pg');

    // Build connection config from env with overrides
    this.config = {
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT || '5432', 10),
      database: process.env.DB_NAME || 'CloudToLocalLLM',
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      ssl:
        process.env.DB_SSL === 'true'
          ? { rejectUnauthorized: false }
          : undefined,
      max: parseInt(process.env.DB_POOL_MAX || '10', 10),
      idleTimeoutMillis: parseInt(process.env.DB_POOL_IDLE || '30000', 10),
      connectionTimeoutMillis: parseInt(
        process.env.DB_POOL_CONNECT_TIMEOUT || '30000',
        10,
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
      this.logger.info('PostgreSQL connection established', {
        host: this.config.host,
        database: this.config.database,
      });
      return true;
    } catch (error) {
      this.logger.error('Failed to connect to PostgreSQL', {
        error: error.message,
      });
      throw error;
    }
  }

  async createMigrationsTable() {
    try {
      // Check if table already exists
      const { rows } = await this.pool.query(`
        SELECT EXISTS (
          SELECT 1 FROM information_schema.tables
          WHERE table_schema = 'public'
          AND table_name = 'schema_migrations'
        ) as table_exists;
      `);

      if (rows[0].table_exists) {
        this.logger.info('Migrations table already exists (PG)');

        // Repair: Ensure ID column has a default value (sequence)
        // This fixes an issue where the sequence might have been dropped by previous error handling
        try {
          await this.pool.query(`
            DO $$
            BEGIN
              -- Check if id column has a default value
              IF (SELECT column_default FROM information_schema.columns WHERE table_name = 'schema_migrations' AND column_name = 'id') IS NULL THEN
                -- Create sequence if not exists
                CREATE SEQUENCE IF NOT EXISTS schema_migrations_id_seq;
                -- Set default
                ALTER TABLE schema_migrations ALTER COLUMN id SET DEFAULT nextval('schema_migrations_id_seq');
                -- Sync sequence
                PERFORM setval('schema_migrations_id_seq', COALESCE((SELECT MAX(id) FROM schema_migrations), 0) + 1, false);
              END IF;
            END $$;
          `);
        } catch (repairError) {
          this.logger.warn('Failed to repair schema_migrations sequence', {
            error: repairError.message,
          });
        }

        return;
      }

      // Table doesn't exist, create it with better error handling
      const sql = `
        CREATE TABLE IF NOT EXISTS schema_migrations (
          id SERIAL PRIMARY KEY,
          version TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          applied_at TIMESTAMPTZ DEFAULT NOW(),
          checksum TEXT NOT NULL,
          execution_time_ms INTEGER,
          success BOOLEAN DEFAULT TRUE
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_schema_migrations_version ON schema_migrations(version);
        CREATE INDEX IF NOT EXISTS idx_schema_migrations_applied_at ON schema_migrations(applied_at);
      `;
      await this.pool.query(sql);
      this.logger.info('Migrations table created/verified (PG)');
    } catch (error) {
      // If we get a type constraint error, it might be due to sequence conflicts
      // Try to clean up and retry
      if (error.message.includes('pg_type_typname_nsp_index')) {
        this.logger.warn(
          'Detected type constraint conflict, attempting cleanup...',
          { error: error.message },
        );
        try {
          // Drop any conflicting sequences that might exist
          // WARNING: This is dangerous if the table exists! It strips the default value from the ID column.
          // await this.pool.query(`
          //   DROP SEQUENCE IF EXISTS schema_migrations_id_seq CASCADE;
          // `);
          this.logger.info(
            'Cleaned up conflicting sequence, retrying table creation...',
          );

          // Retry table creation
          const sql = `
            CREATE TABLE IF NOT EXISTS schema_migrations (
              id SERIAL PRIMARY KEY,
              version TEXT UNIQUE NOT NULL,
              name TEXT NOT NULL,
              applied_at TIMESTAMPTZ DEFAULT NOW(),
              checksum TEXT NOT NULL,
              execution_time_ms INTEGER,
              success BOOLEAN DEFAULT TRUE
            );
            CREATE UNIQUE INDEX IF NOT EXISTS idx_schema_migrations_version ON schema_migrations(version);
            CREATE INDEX IF NOT EXISTS idx_schema_migrations_applied_at ON schema_migrations(applied_at);
          `;
          await this.pool.query(sql);
          this.logger.info('Migrations table created after cleanup (PG)');
          return;
        } catch (cleanupError) {
          this.logger.error(
            'Failed to create migrations table even after cleanup',
            {
              originalError: error.message,
              cleanupError: cleanupError.message,
            },
          );
          throw cleanupError;
        }
      }

      this.logger.error('Failed to create migrations table', {
        error: error.message,
      });
      throw error;
    }
  }

  async getAppliedMigrations() {
    const { rows } = await this.pool.query(
      'SELECT version, name, applied_at FROM schema_migrations WHERE success = TRUE ORDER BY applied_at',
    );
    return rows;
  }

  async isMigrationApplied(version) {
    const { rows } = await this.pool.query(
      'SELECT 1 FROM schema_migrations WHERE version = $1 AND success = TRUE',
      [version],
    );
    return rows.length > 0;
  }

  calculateChecksum(content) {
    return createHash('sha256').update(content).digest('hex');
  }

  extractVersionFromFilename(filename) {
    const match = filename.match(/^(\d+)_/);
    return match ? match[1] : filename;
  }

  extractNameFromFilename(filename) {
    const match = filename.match(/^\d+_(.+)\.sql$/);
    return match ? match[1].replace(/_/g, ' ') : filename;
  }

  async applyInitialSchema() {
    const version = '001_initial_schema';
    if (await this.isMigrationApplied(version)) {
      this.logger.info('Initial schema already applied (PG)');
      return;
    }

    const start = Date.now();
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const schemaPathPG = join(__dirname, 'schema.pg.sql');
      const schemaSQL = readFileSync(schemaPathPG, 'utf8');
      const checksum = this.calculateChecksum(schemaSQL);

      try {
        await client.query(schemaSQL);
      } catch (sqlError) {
        // Ignore specific extension errors that might cause race conditions
        if (
          sqlError.code === '23505' &&
          sqlError.constraint === 'pg_extension_name_index'
        ) {
          this.logger.warn(
            'Ignored extension duplicate error during initial schema application',
            { error: sqlError.message },
          );
        } else if (
          sqlError.message &&
          sqlError.message.includes('already exists')
        ) {
          this.logger.warn(
            'Ignored "already exists" error during initial schema application',
            { error: sqlError.message },
          );
        } else {
          throw sqlError;
        }
      }

      const execMs = Date.now() - start;

      // Check if this version is already applied
      const existing = await client.query(
        'SELECT id FROM schema_migrations WHERE version = $1',
        [version],
      );

      if (existing.rows.length === 0) {
        await client.query(
          'INSERT INTO schema_migrations (version, name, checksum, execution_time_ms) VALUES ($1,$2,$3,$4)',
          [version, 'Initial tunnel system schema', checksum, execMs],
        );
        this.logger.info('Initial schema migration recorded (PG)', { version });
      } else {
        this.logger.info('Initial schema migration already recorded (PG)', {
          version,
        });
      }

      await client.query('COMMIT');
      this.logger.info('Initial schema applied successfully (PG)', {
        version,
        execMs,
      });
    } catch (error) {
      await client.query('ROLLBACK');
      this.logger.error('Failed to apply initial schema (PG)', {
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  async validateSchema() {
    const checks = [
      // user_sessions table moved to separate authentication database
      {
        name: 'tunnel_connections_table',
        query:
          "SELECT 1 FROM information_schema.tables WHERE table_name='tunnel_connections'",
      },
      {
        name: 'audit_logs_table',
        query:
          "SELECT 1 FROM information_schema.tables WHERE table_name='audit_logs'",
      },
      {
        name: 'schema_migrations_table',
        query:
          "SELECT 1 FROM information_schema.tables WHERE table_name='schema_migrations'",
      },
    ];

    const results = {};
    for (const c of checks) {
      try {
        const { rows } = await this.pool.query(c.query);
        results[c.name] = rows.length > 0;
      } catch (e) {
        results[c.name] = false;
        this.logger.warn('Schema validation failed (PG)', {
          validation: c.name,
          error: e.message,
        });
      }
    }

    const allValid = Object.values(results).every(Boolean);
    this.logger.info('Schema validation completed (PG)', { results, allValid });
    return { results, allValid };
  }

  async migrate() {
    const { readdirSync, existsSync, mkdirSync } = await import('fs');
    const migrationsDir = join(__dirname, 'migrations');

    // Ensure migrations directory exists
    if (!existsSync(migrationsDir)) {
      try {
        mkdirSync(migrationsDir, { recursive: true });
      } catch (error) {
        this.logger.warn('Failed to create migrations directory', {
          error: error.message,
        });
        return;
      }
      return;
    }

    // Get all migration files
    const files = readdirSync(migrationsDir)
      .filter((f) => f.endsWith('.sql'))
      .sort();

    this.logger.info(`Found ${files.length} migration files`);

    for (const file of files) {
      await this.applyMigration(file);
    }
  }

  async applyMigration(migrationFile) {
    const version = this.extractVersionFromFilename(migrationFile);
    const name = this.extractNameFromFilename(migrationFile);

    if (await this.isMigrationApplied(version)) {
      return;
    }

    this.logger.info(`Applying migration: ${migrationFile}`);
    const start = Date.now();
    const client = await this.pool.connect();

    try {
      await client.query('BEGIN');

      // Read migration file
      const migrationPath = join(__dirname, 'migrations', migrationFile);
      const migrationSQL = readFileSync(migrationPath, 'utf8');

      // Calculate checksum
      const checksum = this.calculateChecksum(migrationSQL);

      // Execute migration
      try {
        await client.query(migrationSQL);
      } catch (sqlError) {
        this.logger.error(`Failed to apply migration ${migrationFile}`, {
          error: sqlError.message,
          migrationFile,
          sqlPreview:
            migrationSQL.substring(0, 200) +
            (migrationSQL.length > 200 ? '...' : ''),
        });
        throw sqlError;
      }

      // Record migration
      const execMs = Date.now() - start;
      await client.query(
        'INSERT INTO schema_migrations (version, name, checksum, execution_time_ms) VALUES ($1, $2, $3, $4)',
        [version, name, checksum, execMs],
      );

      await client.query('COMMIT');

      this.logger.info('Migration applied successfully (PG)', {
        version,
        name,
        execMs,
      });
    } catch (error) {
      await client.query('ROLLBACK');

      // Record failed migration
      try {
        await client.query(
          'INSERT INTO schema_migrations (version, name, checksum, success) VALUES ($1, $2, $3, FALSE)',
          [version, name, 'failed'],
        );
      } catch (recError) {
        this.logger.warn('Failed to record migration failure', {
          error: recError.message,
        });
      }

      this.logger.error('Failed to apply migration (PG)', {
        version,
        name,
        error: error.message,
      });

      throw error;
    } finally {
      client.release();
    }
  }

  async close() {
    await this.pool.end();
    this.logger.info('PostgreSQL pool closed');
  }
}
