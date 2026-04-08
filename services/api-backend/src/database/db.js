import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import * as schema from './schema.js';

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'immogestion',
  password: process.env.DB_PASSWORD || 'password',
  database: process.env.DB_NAME || 'immogestion',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Create database connection
export const db = drizzle(pool, {
  schema,
});

// Health check function
export async function healthCheck() {
  try {
    await pool.query('SELECT 1');
    return { status: 'healthy', database: 'connected' };
  } catch (error) {
    return { 
      status: 'unhealthy', 
      database: 'disconnected',
      error: error.message 
    };
  }
}

// Close database connection
export async function closeConnection() {
  try {
    await pool.end();
    console.log('Database connection closed');
  } catch (error) {
    console.error('Error closing database connection:', error);
  }
}

// Database initialization script
export async function initializeDatabase() {
  try {
    // Check if database connection works
    const health = await healthCheck();
    if (health.status !== 'healthy') {
      throw new Error(`Database connection failed: ${health.error}`);
    }

    console.log('Database connected successfully');
    return true;
  } catch (error) {
    console.error('Database initialization failed:', error);
    throw error;
  }
}

// Example utility functions for common operations
export const databaseUtils = {
  // Soft delete by setting is_active to false
  async softDelete(table, id) {
    return db
      .update(table)
      .set({ isActive: false })
      .where({ id });
  },

  // Get active records only
  getActive(table) {
    return db.select().from(table).where({ isActive: true });
  },

  // Paginated query
  async getPaginated(table, { page = 1, limit = 10, filters = {} }) {
    const offset = (page - 1) * limit;
    
    let query = db.select().from(table).where({ isActive: true });
    
    // Apply filters
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== null) {
        query = query.where({ [key]: value });
      }
    });

    const items = await query.limit(limit).offset(offset);
    const [{ count }] = await db.select({ count: table.count() }).from(table);
    
    return {
      items,
      total: count,
      page,
      limit,
      totalPages: Math.ceil(count / limit),
    };
  },

  // Get statistics
  async getStats(table, field) {
    const result = await db
      .select({
        total: table.count(),
        active: table.count().where({ isActive: true }),
      })
      .from(table);

    return result[0];
  },
};

export { schema };