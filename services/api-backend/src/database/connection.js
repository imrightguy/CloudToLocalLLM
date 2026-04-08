const { drizzle } = require('drizzle-orm/node-postgres');
const { Pool } = require('pg');
const { migrate } = require('drizzle-orm/postgres-js/migrator');
const postgres = require('postgres');

// Database connection configuration
const DATABASE_URL = process.env.DATABASE_URL || 'postgres://localhost:5432/immogestion';

// Connection pool configuration
const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Drizzle database instance
const db = drizzle(pool);

// Health check function
const checkDatabaseHealth = async () => {
  try {
    await db.execute(sql`SELECT 1`);
    return { status: 'connected', latency: Date.now() };
  } catch (error) {
    return { 
      status: 'error', 
      error: error.message,
      latency: Date.now()
    };
  }
};

// Get database info
const getDatabaseInfo = async () => {
  try {
    const [result] = await db.execute(sql`SELECT version()`);
    return { 
      version: result[0].version,
      connected: true,
      pool: {
        totalConnections: pool.totalCount,
        idleConnections: pool.idleCount,
        waitingClients: pool.waitingCount
      }
    };
  } catch (error) {
    return { 
      connected: false, 
      error: error.message 
    };
  }
};

// Cleanup function
const closeDatabaseConnection = async () => {
  try {
    await pool.end();
    console.log('Database connection closed');
  } catch (error) {
    console.error('Error closing database connection:', error);
  }
};

// Run migrations
const runMigrations = async () => {
  try {
    console.log('Running database migrations...');
    await migrate(db, { migrationsFolder: 'src/database/migrations' });
    console.log('Database migrations completed successfully');
  } catch (error) {
    console.error('Error running migrations:', error);
    throw error;
  }
};

// Execute raw SQL
const executeSql = (query, params = []) => {
  return new Promise((resolve, reject) => {
    pool.query(query, params, (err, result) => {
      if (err) {
        reject(err);
      } else {
        resolve(result);
      }
    });
  });
};

// Transaction helper
const transaction = async (callback) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

// Database performance monitoring
const queryStats = {
  queries: [],
  addQuery: (query, duration) => {
    queryStats.queries.push({
      query: query.substring(0, 100) + '...',
      duration,
      timestamp: new Date()
    });
    
    // Keep only last 100 queries
    if (queryStats.queries.length > 100) {
      queryStats.queries.shift();
    }
  },
  
  getStats: () => {
    const now = Date.now();
    const recentQueries = queryStats.queries.filter(
      q => now - q.timestamp.getTime() < 60000 // Last minute
    );
    
    const avgDuration = recentQueries.length > 0
      ? recentQueries.reduce((sum, q) => sum + q.duration, 0) / recentQueries.length
      : 0;
    
    return {
      totalQueries: queryStats.queries.length,
      recentQueries: recentQueries.length,
      averageQueryTime: avgDuration,
      slowQueries: recentQueries.filter(q => q.duration > 1000).length
    };
  },
  
  reset: () => {
    queryStats.queries = [];
  }
};

// Wrap pool.query with performance monitoring
const enhancedQuery = async (text, params) => {
  const start = Date.now();
  try {
    const result = await db.execute({ text, params });
    const duration = Date.now() - start;
    queryStats.addQuery(text, duration);
    return result;
  } catch (error) {
    const duration = Date.now() - start;
    queryStats.addQuery(text, duration);
    throw error;
  }
};

// Connect to database
const connect = async () => {
  try {
    // Test connection
    await checkDatabaseHealth();
    console.log('Database connected successfully');
    
    // Run migrations
    await runMigrations();
    
    return db;
  } catch (error) {
    console.error('Failed to connect to database:', error);
    throw error;
  }
};

module.exports = {
  db,
  pool,
  checkDatabaseHealth,
  getDatabaseInfo,
  closeDatabaseConnection,
  runMigrations,
  executeSql,
  transaction,
  enhancedQuery,
  queryStats,
  connect
};