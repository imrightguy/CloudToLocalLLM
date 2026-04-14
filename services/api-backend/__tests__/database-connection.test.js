const { connect, closeDatabase, pool, db } = require('../src/database/connection');

jest.mock('pg', () => {
  const mPool = {
    connect: jest.fn(),
    end: jest.fn(),
  };
  return { Pool: jest.fn(() => mPool) };
});

jest.mock('drizzle-orm/node-postgres', () => ({
  drizzle: jest.fn(() => ({ mockDrizzle: true })),
}));

describe('database/connection', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  describe('connect', () => {
    it('connects and releases a client on success', async () => {
      const mockClient = {
        query: jest.fn().mockResolvedValue({ rows: [{ '?column?': 1 }] }),
        release: jest.fn(),
      };
      pool.connect.mockResolvedValue(mockClient);

      const result = await connect();

      expect(result).toBe(true);
      expect(pool.connect).toHaveBeenCalledTimes(1);
      expect(mockClient.query).toHaveBeenCalledWith('SELECT 1');
      expect(mockClient.release).toHaveBeenCalledTimes(1);
    });

    it('releases client even if query throws', async () => {
      const mockClient = {
        query: jest.fn().mockRejectedValue(new Error('query failed')),
        release: jest.fn(),
      };
      pool.connect.mockResolvedValue(mockClient);

      await expect(connect()).rejects.toThrow('query failed');
      expect(mockClient.release).toHaveBeenCalledTimes(1);
    });

    it('propagates pool.connect errors', async () => {
      pool.connect.mockRejectedValue(new Error('no db'));

      await expect(connect()).rejects.toThrow('no db');
    });
  });

  describe('closeDatabase', () => {
    it('calls pool.end', async () => {
      pool.end.mockResolvedValue(undefined);
      await closeDatabase();
      expect(pool.end).toHaveBeenCalledTimes(1);
    });

    it('propagates pool.end errors', async () => {
      pool.end.mockRejectedValue(new Error('close failed'));
      await expect(closeDatabase()).rejects.toThrow('close failed');
    });
  });

  describe('exports', () => {
    it('exports db as a drizzle instance', () => {
      expect(db).toBeDefined();
    });

    it('exports pool', () => {
      expect(pool).toBeDefined();
      expect(typeof pool.connect).toBe('function');
    });

    it('exports connect function', () => {
      expect(typeof connect).toBe('function');
    });

    it('exports closeDatabase function', () => {
      expect(typeof closeDatabase).toBe('function');
    });
  });
});
