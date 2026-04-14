/**
 * Unit Tests for Transaction Manager
 *
 * Tests Transaction lifecycle (constructor, begin, query, savepoint,
 * commit, rollback, getMetadata) and TransactionManager static methods.
 *
 * Uses unstable_mockModule with dynamic imports to ensure mocks are
 * applied before the module under test is loaded.
 */

import { jest, describe, it, expect, beforeEach } from '@jest/globals';

// --- Set up mocks BEFORE importing the module under test ---

jest.unstable_mockModule(
  '../../services/api-backend/logger.js',
  () => ({
    default: {
      debug: jest.fn(),
      info: jest.fn(),
      warn: jest.fn(),
      error: jest.fn(),
    },
  }),
);

const mockRelease = jest.fn();
const mockClientQuery = jest.fn().mockResolvedValue({ rows: [], rowCount: 0 });
const mockClient = {
  query: mockClientQuery,
  release: mockRelease,
};

jest.unstable_mockModule(
  '../../services/api-backend/database/db-pool.js',
  () => ({
    getClient: jest.fn(() => Promise.resolve(mockClient)),
  }),
);

// Dynamic import AFTER mocks
const {
  Transaction,
  TransactionManager,
  IsolationLevel,
  TransactionState,
} = await import(
  '../../services/api-backend/services/transaction-manager.js'
);

// Helper: create a fresh mock client for Transaction (constructor-injected)
function createMockClient() {
  return {
    query: jest.fn().mockResolvedValue({ rows: [], rowCount: 0 }),
    release: jest.fn(),
  };
}

describe('IsolationLevel', () => {
  it('should define all PostgreSQL isolation levels', () => {
    expect(IsolationLevel.READ_UNCOMMITTED).toBe('READ UNCOMMITTED');
    expect(IsolationLevel.READ_COMMITTED).toBe('READ COMMITTED');
    expect(IsolationLevel.REPEATABLE_READ).toBe('REPEATABLE READ');
    expect(IsolationLevel.SERIALIZABLE).toBe('SERIALIZABLE');
  });
});

describe('TransactionState', () => {
  it('should define all transaction states', () => {
    expect(TransactionState.IDLE).toBe('idle');
    expect(TransactionState.ACTIVE).toBe('active');
    expect(TransactionState.COMMITTED).toBe('committed');
    expect(TransactionState.ROLLED_BACK).toBe('rolled_back');
    expect(TransactionState.FAILED).toBe('failed');
  });
});

describe('Transaction', () => {
  let client;

  beforeEach(() => {
    client = createMockClient();
  });

  describe('constructor', () => {
    it('should initialize with default isolation level READ_COMMITTED', () => {
      const txn = new Transaction(client);
      expect(txn.isolationLevel).toBe(IsolationLevel.READ_COMMITTED);
      expect(txn.state).toBe(TransactionState.IDLE);
      expect(txn.queries).toEqual([]);
      expect(txn.savepoints).toEqual([]);
      expect(txn.transactionId).toMatch(/^txn_\d+_/);
    });

    it('should accept custom isolation level', () => {
      const txn = new Transaction(client, IsolationLevel.SERIALIZABLE);
      expect(txn.isolationLevel).toBe(IsolationLevel.SERIALIZABLE);
    });

    it('should generate unique transaction IDs', () => {
      const txn1 = new Transaction(client);
      const txn2 = new Transaction(client);
      expect(txn1.transactionId).not.toBe(txn2.transactionId);
    });
  });

  describe('begin()', () => {
    it('should set state to ACTIVE and send BEGIN with isolation level', async () => {
      const txn = new Transaction(client, IsolationLevel.READ_COMMITTED);
      await txn.begin();

      expect(client.query).toHaveBeenCalledWith(
        'BEGIN ISOLATION LEVEL READ COMMITTED',
      );
      expect(txn.state).toBe(TransactionState.ACTIVE);
      expect(txn.startTime).toBeLessThanOrEqual(Date.now());
    });

    it('should use SERIALIZABLE isolation level when configured', async () => {
      const txn = new Transaction(client, IsolationLevel.SERIALIZABLE);
      await txn.begin();
      expect(client.query).toHaveBeenCalledWith(
        'BEGIN ISOLATION LEVEL SERIALIZABLE',
      );
    });

    it('should set state to FAILED on begin error', async () => {
      client.query.mockRejectedValue(new Error('Connection lost'));
      const txn = new Transaction(client);

      await expect(txn.begin()).rejects.toThrow('Connection lost');
      expect(txn.state).toBe(TransactionState.FAILED);
    });
  });

  describe('query()', () => {
    it('should execute query and record metadata', async () => {
      client.query.mockResolvedValue({ rows: [{ id: 1 }], rowCount: 1 });

      const txn = new Transaction(client);
      await txn.begin();
      const result = await txn.query('SELECT * FROM users WHERE id = $1', [1]);

      expect(result.rowCount).toBe(1);
      expect(txn.queries).toHaveLength(1);
      expect(txn.queries[0].text).toBe('SELECT * FROM users WHERE id = $1');
      expect(txn.queries[0].params).toEqual([1]);
      expect(txn.queries[0].rowCount).toBe(1);
      expect(txn.queries[0].timestamp).toBeDefined();
    });

    it('should throw if transaction is IDLE', async () => {
      const txn = new Transaction(client);
      await expect(txn.query('SELECT 1')).rejects.toThrow(
        'Cannot execute query in idle transaction',
      );
    });

    it('should throw if transaction is COMMITTED', async () => {
      const txn = new Transaction(client);
      await txn.begin();
      await txn.commit();
      await expect(txn.query('SELECT 1')).rejects.toThrow(
        'Cannot execute query in committed transaction',
      );
    });

    it('should throw if transaction is ROLLED_BACK', async () => {
      const txn = new Transaction(client);
      await txn.begin();
      await txn.rollback();
      await expect(txn.query('SELECT 1')).rejects.toThrow(
        'Cannot execute query in rolled_back transaction',
      );
    });

    it('should set state to FAILED on query error', async () => {
      client.query
        .mockResolvedValueOnce({ rows: [], rowCount: 0 })
        .mockRejectedValueOnce(new Error('Syntax error'));

      const txn = new Transaction(client);
      await txn.begin();
      await expect(txn.query('BAD SQL')).rejects.toThrow('Syntax error');
      expect(txn.state).toBe(TransactionState.FAILED);
    });

    it('should handle queries without params', async () => {
      client.query.mockResolvedValue({ rows: [], rowCount: 0 });

      const txn = new Transaction(client);
      await txn.begin();
      await txn.query('SELECT NOW()');

      expect(client.query).toHaveBeenCalledWith('SELECT NOW()', []);
      expect(txn.queries[0].params).toEqual([]);
    });
  });

  describe('savepoint()', () => {
    it('should create savepoint and track it', async () => {
      const txn = new Transaction(client);
      await txn.begin();
      await txn.savepoint('sp1');

      expect(client.query).toHaveBeenCalledWith('SAVEPOINT sp1');
      expect(txn.savepoints).toHaveLength(1);
      expect(txn.savepoints[0].name).toBe('sp1');
      expect(txn.savepoints[0].timestamp).toBeDefined();
    });

    it('should track multiple savepoints', async () => {
      const txn = new Transaction(client);
      await txn.begin();
      await txn.savepoint('sp1');
      await txn.savepoint('sp2');

      expect(txn.savepoints).toHaveLength(2);
      expect(txn.savepoints.map((s) => s.name)).toEqual(['sp1', 'sp2']);
    });

    it('should throw if transaction is not ACTIVE', async () => {
      const txn = new Transaction(client);
      await expect(txn.savepoint('sp1')).rejects.toThrow(
        'Cannot create savepoint in idle transaction',
      );
    });

    it('should propagate savepoint creation error', async () => {
      client.query
        .mockResolvedValueOnce({ rows: [], rowCount: 0 })
        .mockRejectedValueOnce(new Error('Savepoint failed'));

      const txn = new Transaction(client);
      await txn.begin();
      await expect(txn.savepoint('sp1')).rejects.toThrow('Savepoint failed');
    });
  });

  describe('rollbackToSavepoint()', () => {
    it('should rollback to savepoint in active transaction', async () => {
      const txn = new Transaction(client);
      await txn.begin();
      await txn.savepoint('sp1');
      await txn.rollbackToSavepoint('sp1');

      expect(client.query).toHaveBeenCalledWith('ROLLBACK TO SAVEPOINT sp1');
    });

    it('should throw if transaction is not ACTIVE', async () => {
      const txn = new Transaction(client);
      await expect(txn.rollbackToSavepoint('sp1')).rejects.toThrow(
        'Cannot rollback to savepoint in idle transaction',
      );
    });

    it('should propagate rollback error', async () => {
      client.query
        .mockResolvedValueOnce({ rows: [], rowCount: 0 })
        .mockResolvedValueOnce({ rows: [], rowCount: 0 })
        .mockRejectedValueOnce(new Error('Rollback failed'));

      const txn = new Transaction(client);
      await txn.begin();
      await txn.savepoint('sp1');
      await expect(txn.rollbackToSavepoint('sp1')).rejects.toThrow(
        'Rollback failed',
      );
    });
  });

  describe('commit()', () => {
    it('should commit active transaction', async () => {
      const txn = new Transaction(client);
      await txn.begin();
      await txn.query('SELECT 1');
      await txn.commit();

      expect(client.query).toHaveBeenCalledWith('COMMIT');
      expect(txn.state).toBe(TransactionState.COMMITTED);
      expect(txn.endTime).toBeDefined();
    });

    it('should throw if transaction is IDLE', async () => {
      const txn = new Transaction(client);
      await expect(txn.commit()).rejects.toThrow('Cannot commit idle transaction');
    });

    it('should throw if transaction already COMMITTED', async () => {
      const txn = new Transaction(client);
      await txn.begin();
      await txn.commit();
      await expect(txn.commit()).rejects.toThrow(
        'Cannot commit committed transaction',
      );
    });

    it('should set state to FAILED on commit error', async () => {
      client.query
        .mockResolvedValueOnce({ rows: [], rowCount: 0 })
        .mockRejectedValueOnce(new Error('Commit failed'));

      const txn = new Transaction(client);
      await txn.begin();
      await expect(txn.commit()).rejects.toThrow('Commit failed');
      expect(txn.state).toBe(TransactionState.FAILED);
    });
  });

  describe('rollback()', () => {
    it('should rollback active transaction', async () => {
      const txn = new Transaction(client);
      await txn.begin();
      await txn.rollback();

      expect(client.query).toHaveBeenCalledWith('ROLLBACK');
      expect(txn.state).toBe(TransactionState.ROLLED_BACK);
      expect(txn.endTime).toBeDefined();
    });

    it('should handle idle transaction without sending ROLLBACK', async () => {
      const txn = new Transaction(client);
      await txn.rollback();

      expect(client.query).not.toHaveBeenCalledWith('ROLLBACK');
      expect(txn.state).toBe(TransactionState.ROLLED_BACK);
    });

    it('should handle failed transaction rollback', async () => {
      const txn = new Transaction(client);
      await txn.begin();
      txn.state = TransactionState.FAILED;

      await txn.rollback();
      expect(txn.state).toBe(TransactionState.ROLLED_BACK);
    });

    it('should handle committed transaction rollback gracefully', async () => {
      const txn = new Transaction(client);
      await txn.begin();
      await txn.commit();

      await txn.rollback();
      expect(txn.state).toBe(TransactionState.COMMITTED);
    });

    it('should set state to FAILED on rollback error for active txn', async () => {
      client.query
        .mockResolvedValueOnce({ rows: [], rowCount: 0 })
        .mockRejectedValueOnce(new Error('Rollback error'));

      const txn = new Transaction(client);
      await txn.begin();
      await expect(txn.rollback()).rejects.toThrow('Rollback error');
      expect(txn.state).toBe(TransactionState.FAILED);
    });
  });

  describe('getMetadata()', () => {
    it('should return correct metadata for idle transaction', () => {
      const txn = new Transaction(client);
      const meta = txn.getMetadata();

      expect(meta.state).toBe(TransactionState.IDLE);
      expect(meta.isolationLevel).toBe(IsolationLevel.READ_COMMITTED);
      expect(meta.duration).toBeNull();
      expect(meta.queryCount).toBe(0);
      expect(meta.savepointCount).toBe(0);
      expect(meta.transactionId).toMatch(/^txn_/);
    });

    it('should return duration for committed transaction', async () => {
      const txn = new Transaction(client);
      await txn.begin();
      await txn.commit();

      const meta = txn.getMetadata();
      expect(meta.duration).toBeGreaterThanOrEqual(0);
      expect(meta.startTime).toBeLessThanOrEqual(meta.endTime);
    });

    it('should count queries and savepoints', async () => {
      client.query.mockResolvedValue({ rows: [], rowCount: 0 });

      const txn = new Transaction(client);
      await txn.begin();
      await txn.query('SELECT 1');
      await txn.query('SELECT 2');
      await txn.savepoint('sp1');

      const meta = txn.getMetadata();
      expect(meta.queryCount).toBe(2);
      expect(meta.savepointCount).toBe(1);
    });
  });

  describe('full lifecycle scenarios', () => {
    it('begin -> query -> savepoint -> query -> commit', async () => {
      client.query.mockResolvedValue({ rows: [], rowCount: 0 });

      const txn = new Transaction(client, IsolationLevel.SERIALIZABLE);
      await txn.begin();
      await txn.query('INSERT INTO users (name) VALUES ($1)', ['Alice']);
      await txn.savepoint('before_update');
      await txn.query('UPDATE users SET name = $2 WHERE name = $1', [
        'Alice',
        'Bob',
      ]);
      await txn.commit();

      expect(txn.state).toBe(TransactionState.COMMITTED);
      expect(txn.getMetadata().queryCount).toBe(2);
      expect(txn.getMetadata().savepointCount).toBe(1);
    });

    it('begin -> query -> savepoint -> rollbackToSavepoint -> rollback', async () => {
      client.query.mockResolvedValue({ rows: [], rowCount: 0 });

      const txn = new Transaction(client);
      await txn.begin();
      await txn.query('INSERT INTO users (name) VALUES ($1)', ['Alice']);
      await txn.savepoint('sp1');
      await txn.query('DELETE FROM users');
      await txn.rollbackToSavepoint('sp1');
      await txn.rollback();

      expect(txn.state).toBe(TransactionState.ROLLED_BACK);
    });

    it('begin -> commit (empty transaction)', async () => {
      const txn = new Transaction(client);
      await txn.begin();
      await txn.commit();

      expect(txn.state).toBe(TransactionState.COMMITTED);
      expect(txn.getMetadata().queryCount).toBe(0);
      expect(txn.getMetadata().duration).toBeGreaterThanOrEqual(0);
    });
  });
});

// --- TransactionManager tests use the mocked db-pool.getClient ---

describe('TransactionManager', () => {
  beforeEach(() => {
    mockClientQuery.mockReset();
    mockClientQuery.mockResolvedValue({ rows: [], rowCount: 0 });
    mockRelease.mockReset();
    mockRelease.mockReturnValue(undefined);
  });

  describe('withTransaction()', () => {
    it('should execute callback and commit', async () => {
      const result = await TransactionManager.withTransaction(
        async (txn) => {
          await txn.query('SELECT 1');
          return 'success';
        },
        { maxRetries: 1 },
      );

      expect(result).toBe('success');
      expect(mockRelease).toHaveBeenCalled();
    });

    it('should rollback and throw on callback error', async () => {
      await expect(
        TransactionManager.withTransaction(
          async () => {
            throw new Error('Business logic failed');
          },
          { maxRetries: 1 },
        ),
      ).rejects.toThrow('Business logic failed');

      expect(mockRelease).toHaveBeenCalled();
    });

    it('should always release client even on error', async () => {
      mockClientQuery.mockRejectedValue(new Error('DB error'));

      await expect(
        TransactionManager.withTransaction(async () => 'ok', {
          maxRetries: 1,
        }),
      ).rejects.toThrow();

      expect(mockRelease).toHaveBeenCalled();
    });
  });

  describe('executeQueries()', () => {
    it('should execute queries in order and return results', async () => {
      const results = await TransactionManager.executeQueries(
        [
          { text: 'SELECT * FROM users' },
          { text: 'SELECT * FROM orders' },
        ],
        { maxRetries: 1 },
      );

      expect(results).toHaveLength(2);
      expect(mockRelease).toHaveBeenCalled();
    });
  });
});
