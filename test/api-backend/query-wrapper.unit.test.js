/**
 * Query Wrapper Unit Tests
 *
 * Tests for database query wrapper — performance tracking wrappers
 * Validates query type detection, tracked execution, and pool/client wrapping
 */

import {
  jest,
  describe,
  it,
  expect,
  beforeEach,
} from '@jest/globals';

jest.unstable_mockModule(
  '../../services/api-backend/database/query-performance-tracker.js',
  () => ({
    trackQuery: jest.fn(),
  }),
);

jest.unstable_mockModule('../../services/api-backend/logger.js', () => ({
  default: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  },
}));

const { trackQuery } = await import(
  '../../services/api-backend/database/query-performance-tracker.js'
);
const {
  executeTrackedQuery,
  wrapPoolQuery,
  wrapClientQuery,
  wrapPool,
  wrapClient,
} = await import('../../services/api-backend/database/query-wrapper.js');
const queryWrapperDefault = (
  await import('../../services/api-backend/database/query-wrapper.js')
).default;

const { getQueryType } = queryWrapperDefault;

describe('getQueryType', () => {
  it('detects SELECT', () => {
    expect(getQueryType('SELECT * FROM users')).toBe('SELECT');
  });

  it('detects select case-insensitively', () => {
    expect(getQueryType('select * from users')).toBe('SELECT');
  });

  it('detects select with leading whitespace', () => {
    expect(getQueryType('  SELECT 1')).toBe('SELECT');
  });

  it('detects INSERT', () => {
    expect(getQueryType('INSERT INTO users VALUES (1)')).toBe('INSERT');
  });

  it('detects UPDATE', () => {
    expect(getQueryType('UPDATE users SET x=1')).toBe('UPDATE');
  });

  it('detects DELETE', () => {
    expect(getQueryType('DELETE FROM users')).toBe('DELETE');
  });

  it('detects BEGIN', () => {
    expect(getQueryType('BEGIN')).toBe('BEGIN');
  });

  it('detects COMMIT', () => {
    expect(getQueryType('COMMIT')).toBe('COMMIT');
  });

  it('detects ROLLBACK', () => {
    expect(getQueryType('ROLLBACK')).toBe('ROLLBACK');
  });

  it('detects CREATE', () => {
    expect(getQueryType('CREATE TABLE foo (id int)')).toBe('CREATE');
  });

  it('detects ALTER', () => {
    expect(getQueryType('ALTER TABLE foo ADD col int')).toBe('ALTER');
  });

  it('detects DROP', () => {
    expect(getQueryType('DROP TABLE foo')).toBe('DROP');
  });

  it('returns OTHER for unknown', () => {
    expect(getQueryType('EXPLAIN ANALYZE SELECT 1')).toBe('OTHER');
  });

  it('returns OTHER for empty string', () => {
    expect(getQueryType('')).toBe('OTHER');
  });

  it('returns OTHER for whitespace-only', () => {
    expect(getQueryType('   ')).toBe('OTHER');
  });
});

describe('executeTrackedQuery', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('calls queryFn and returns result on success', async () => {
    const queryFn = jest.fn().mockResolvedValue({ rows: [{ id: 1 }] });
    const result = await executeTrackedQuery(
      queryFn,
      'SELECT * FROM users WHERE id = $1',
      [1],
    );
    expect(result).toEqual({ rows: [{ id: 1 }] });
    expect(queryFn).toHaveBeenCalledTimes(1);
  });

  it('tracks successful query with correct params', async () => {
    const queryFn = jest.fn().mockResolvedValue({ rows: [] });
    await executeTrackedQuery(queryFn, 'SELECT 1', []);

    expect(trackQuery).toHaveBeenCalledTimes(1);
    const [queryText, duration, meta] = trackQuery.mock.calls[0];
    expect(queryText).toBe('SELECT 1');
    expect(typeof duration).toBe('number');
    expect(meta.success).toBe(true);
    expect(meta.queryType).toBe('SELECT');
    expect(meta.params).toEqual([]);
  });

  it('tracks failed query and rethrows error', async () => {
    const error = new Error('connection lost');
    const queryFn = jest.fn().mockRejectedValue(error);

    await expect(
      executeTrackedQuery(queryFn, 'INSERT INTO x VALUES (1)'),
    ).rejects.toThrow('connection lost');

    expect(trackQuery).toHaveBeenCalledTimes(1);
    const [, , meta] = trackQuery.mock.calls[0];
    expect(meta.success).toBe(false);
    expect(meta.error).toBe(error);
    expect(meta.queryType).toBe('INSERT');
  });

  it('defaults params to empty array', async () => {
    const queryFn = jest.fn().mockResolvedValue(undefined);
    await executeTrackedQuery(queryFn, 'SELECT 1');

    const [, , meta] = trackQuery.mock.calls[0];
    expect(meta.params).toEqual([]);
  });

  it('measures non-zero duration for slow query', async () => {
    const queryFn = jest.fn().mockImplementation(
      () => new Promise((r) => setTimeout(r, 10)),
    );
    await executeTrackedQuery(queryFn, 'SELECT pg_sleep(0.01)');

    const [, duration] = trackQuery.mock.calls[0];
    expect(duration).toBeGreaterThanOrEqual(8);
  });
});

describe('wrapPoolQuery', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns a wrapped function that delegates to original', async () => {
    const original = jest.fn().mockResolvedValue({ rows: [{ ok: true }] });
    const wrapped = wrapPoolQuery(original);

    const result = await wrapped('SELECT 1', []);

    expect(result).toEqual({ rows: [{ ok: true }] });
    expect(trackQuery).toHaveBeenCalledTimes(1);
    expect(trackQuery.mock.calls[0][2].success).toBe(true);
  });

  it('preserves this context via call', async () => {
    const ctx = { id: 'pool' };
    const original = jest.fn().mockResolvedValue('ok');
    const wrapped = wrapPoolQuery(original);

    await wrapped.call(ctx, 'SELECT 1');
    expect(original.mock.instances[0]).toBe(ctx);
  });
});

describe('wrapClientQuery', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns a wrapped function that delegates to original', async () => {
    const original = jest.fn().mockResolvedValue({ rows: [] });
    const wrapped = wrapClientQuery(original);

    const result = await wrapped('UPDATE x SET y=1', [42]);
    expect(result).toEqual({ rows: [] });
    expect(trackQuery).toHaveBeenCalledTimes(1);
    expect(trackQuery.mock.calls[0][2].queryType).toBe('UPDATE');
  });
});

describe('wrapPool', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('wraps pool.query and returns same pool object', async () => {
    const pool = {
      query: jest.fn().mockResolvedValue({ rows: [{ count: 5 }] }),
    };

    const result = wrapPool(pool);

    expect(result).toBe(pool);
    await pool.query('SELECT COUNT(*) FROM users');
    expect(trackQuery).toHaveBeenCalledTimes(1);
    expect(trackQuery.mock.calls[0][2].success).toBe(true);
  });

  it('tracks errors through wrapped pool', async () => {
    const error = new Error('timeout');
    const pool = {
      query: jest.fn().mockRejectedValue(error),
    };

    wrapPool(pool);
    await expect(pool.query('DELETE FROM x')).rejects.toThrow('timeout');
    expect(trackQuery.mock.calls[0][2].success).toBe(false);
  });
});

describe('wrapClient', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('wraps client.query and returns same client object', async () => {
    const client = {
      query: jest.fn().mockResolvedValue({ rows: [] }),
    };

    const result = wrapClient(client);

    expect(result).toBe(client);
    await client.query('BEGIN');
    expect(trackQuery).toHaveBeenCalledTimes(1);
    expect(trackQuery.mock.calls[0][2].queryType).toBe('BEGIN');
  });

  it('tracks errors through wrapped client', async () => {
    const error = new Error('deadlock');
    const client = {
      query: jest.fn().mockRejectedValue(error),
    };

    wrapClient(client);
    await expect(client.query('ROLLBACK')).rejects.toThrow('deadlock');
    expect(trackQuery.mock.calls[0][2].success).toBe(false);
    expect(trackQuery.mock.calls[0][2].queryType).toBe('ROLLBACK');
  });
});
