const { drizzle } = require('drizzle-orm/node-postgres');
const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://localhost:5432/immogestion';

const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

const db = drizzle(pool);

const connect = async () => {
  const client = await pool.connect();
  await client.query('SELECT 1');
  client.release();
  return true;
};

const closeDatabase = async () => {
  await pool.end();
};

module.exports = {
  db, pool, connect, closeDatabase,
};
