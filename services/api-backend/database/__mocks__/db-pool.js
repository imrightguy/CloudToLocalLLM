import { jest } from '@jest/globals';

export const getPool = jest.fn(() => ({
  query: jest.fn().mockResolvedValue({ rows: [], rowCount: 0 }),
  connect: jest.fn().mockResolvedValue({
    query: jest.fn().mockResolvedValue({ rows: [], rowCount: 0 }),
    release: jest.fn(),
    on: jest.fn(),
  }),
  on: jest.fn(),
  end: jest.fn().mockResolvedValue(),
}));

export const query = jest.fn().mockResolvedValue({ rows: [], rowCount: 0 });

export const getClient = jest.fn().mockResolvedValue({
  query: jest.fn().mockResolvedValue({ rows: [], rowCount: 0 }),
  release: jest.fn(),
});

export const initializePool = jest.fn().mockResolvedValue();
export const closePool = jest.fn().mockResolvedValue();
export const wrapPool = jest.fn((p) => p);
export const initializeQueryTracking = jest.fn();

export default {
  getPool,
  query,
  getClient,
  initializePool,
  closePool,
  wrapPool,
  initializeQueryTracking,
};
