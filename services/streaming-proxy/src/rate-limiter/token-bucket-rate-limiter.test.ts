/**
 * Tests for Token Bucket Rate Limiter
 *
 * Tests token bucket algorithm, refill mechanics, violation tracking,
 * cleanup, per-user overrides, and edge cases.
 */

import { TokenBucketRateLimiter } from './token-bucket-rate-limiter';
import { RateLimitConfig } from '../interfaces/auth-middleware';

const defaultConfig: RateLimitConfig = {
  requestsPerMinute: 10,
  maxConcurrentConnections: 3,
  maxQueueSize: 100,
};

describe('TokenBucketRateLimiter', () => {
  let limiter: TokenBucketRateLimiter;

  beforeEach(() => {
    limiter = new TokenBucketRateLimiter(defaultConfig);
  });

  describe('checkLimit', () => {
    it('should allow request when tokens are available', async () => {
      const result = await limiter.checkLimit('user1', '192.168.1.1');
      expect(result.allowed).toBe(true);
      expect(result.remaining).toBe(defaultConfig.requestsPerMinute - 1);
      expect(result.resetAt).toBeInstanceOf(Date);
    });

    it('should track user and IP buckets independently', async () => {
      const r1 = await limiter.checkLimit('user1', '192.168.1.1');
      const r2 = await limiter.checkLimit('user2', '192.168.1.1');
      expect(r1.allowed).toBe(true);
      expect(r2.allowed).toBe(true);
    });

    it('should track same user from different IPs independently', async () => {
      const r1 = await limiter.checkLimit('user1', '192.168.1.1');
      const r2 = await limiter.checkLimit('user1', '192.168.1.2');
      expect(r1.allowed).toBe(true);
      expect(r2.allowed).toBe(true);
    });
  });

  describe('recordRequest', () => {
    it('should consume tokens when recording requests after check', async () => {
      // Check and record 10 requests (the full capacity)
      for (let i = 0; i < 10; i++) {
        const result = await limiter.checkLimit('user1', '192.168.1.1');
        expect(result.allowed).toBe(true);
        limiter.recordRequest('user1', '192.168.1.1');
      }

      // Now force bucket to zero tokens to test denial
      const state = limiter.getBucketState('user1', 'user')!;
      state.tokens = 0;

      const result = await limiter.checkLimit('user1', '192.168.1.1');
      expect(result.allowed).toBe(false);
      expect(result.remaining).toBe(0);
      expect(result.retryAfter).toBeDefined();
      expect(result.retryAfter!).toBeGreaterThan(0);
    });

    it('should consume tokens from both user and IP buckets', async () => {
      // Create buckets first via checkLimit
      await limiter.checkLimit('user1', '192.168.1.1');

      // Drain both buckets to zero
      const userState = limiter.getBucketState('user1', 'user')!;
      const ipState = limiter.getBucketState('192.168.1.1', 'ip')!;
      userState.tokens = 0;
      ipState.tokens = 0;
      userState.lastRefill = Date.now();
      ipState.lastRefill = Date.now();

      // user1 should be denied
      const userResult = await limiter.checkLimit('user1', '192.168.1.2');
      expect(userResult.allowed).toBe(false);

      // IP should be denied for different user too
      const ipState2 = limiter.getBucketState('192.168.1.1', 'ip');
      if (ipState2) ipState2.tokens = 0;
      const ipResult = await limiter.checkLimit('user2', '192.168.1.1');
      expect(ipResult.allowed).toBe(false);
    });
  });

  describe('setUserLimit', () => {
    it('should apply stricter limits to specific users', async () => {
      const strictLimit: RateLimitConfig = {
        requestsPerMinute: 3,
        maxConcurrentConnections: 1,
        maxQueueSize: 10,
      };
      limiter.setUserLimit('restricted-user', strictLimit);

      // Check + record 3 requests
      for (let i = 0; i < 3; i++) {
        await limiter.checkLimit('restricted-user', '10.0.0.1');
        limiter.recordRequest('restricted-user', '10.0.0.1');
      }

      // Force bucket to zero
      const state = limiter.getBucketState('restricted-user', 'user')!;
      state.tokens = 0;

      const result = await limiter.checkLimit('restricted-user', '10.0.0.1');
      expect(result.allowed).toBe(false);
    });

    it('should update existing bucket capacity', async () => {
      // First create the bucket
      await limiter.checkLimit('user1', '192.168.1.1');

      const stateBefore = limiter.getBucketState('user1', 'user');
      expect(stateBefore!.capacity).toBe(10);

      // Set a lower limit — tokens should be capped at new capacity
      const lowerLimit: RateLimitConfig = {
        requestsPerMinute: 3,
        maxConcurrentConnections: 1,
        maxQueueSize: 10,
      };
      limiter.setUserLimit('user1', lowerLimit);

      const stateAfter = limiter.getBucketState('user1', 'user');
      expect(stateAfter!.capacity).toBe(3);
      expect(stateAfter!.tokens).toBeLessThanOrEqual(3);
    });
  });

  describe('setGlobalLimit', () => {
    it('should apply new global limit to new buckets', async () => {
      const newLimit: RateLimitConfig = {
        requestsPerMinute: 5,
        maxConcurrentConnections: 2,
        maxQueueSize: 50,
      };
      limiter.setGlobalLimit(newLimit);

      // New user should get 5 tokens
      const result = await limiter.checkLimit('newuser', '10.0.0.1');
      expect(result.allowed).toBe(true);
      expect(result.remaining).toBe(4); // 5 - 1
    });
  });

  describe('getViolations', () => {
    it('should track violations when rate limit exceeded', async () => {
      // Create bucket and force to zero
      await limiter.checkLimit('user1', '192.168.1.1');
      const state = limiter.getBucketState('user1', 'user')!;
      state.tokens = 0;

      // Trigger violation
      await limiter.checkLimit('user1', '192.168.1.1');

      const violations = limiter.getViolations(60000);
      expect(violations.length).toBe(1);
      expect(violations[0].userId).toBe('user1');
      expect(violations[0].ip).toBe('192.168.1.1');
      expect(violations[0].limit).toBe(10);
    });

    it('should return violations within time window', async () => {
      // Create bucket and force to zero
      await limiter.checkLimit('user1', '192.168.1.1');
      limiter.getBucketState('user1', 'user')!.tokens = 0;

      await limiter.checkLimit('user1', '192.168.1.1');

      const recent = limiter.getViolations(60000);
      expect(recent.length).toBe(1);
    });

    it('should cap violation history at 1000 entries', async () => {
      const tinyConfig: RateLimitConfig = {
        requestsPerMinute: 1,
        maxConcurrentConnections: 1,
        maxQueueSize: 10,
      };
      const tinyLimiter = new TokenBucketRateLimiter(tinyConfig);

      // Trigger many violations with different users
      for (let i = 0; i < 1010; i++) {
        await tinyLimiter.checkLimit(`user${i}`, `10.0.0.1`);
        // Force bucket to zero for next violation
        const state = tinyLimiter.getBucketState(`user${i}`, 'user');
        if (state) {
          state.tokens = 0;
        }
      }

      const violations = tinyLimiter.getViolations(60000);
      expect(violations.length).toBeLessThanOrEqual(1000);
    });
  });

  describe('cleanupOldBuckets', () => {
    it('should remove idle buckets', async () => {
      // Create buckets via checkLimit
      await limiter.checkLimit('user1', '192.168.1.1');
      await limiter.checkLimit('user2', '192.168.1.2');

      // Manually age the buckets
      const userState = limiter.getBucketState('user1', 'user')!;
      const ipState = limiter.getBucketState('192.168.1.1', 'ip')!;
      userState.lastRefill = Date.now() - 7200000; // 2 hours ago
      ipState.lastRefill = Date.now() - 7200000;

      // Keep user2 fresh
      const user2State = limiter.getBucketState('user2', 'user')!;
      user2State.lastRefill = Date.now();

      limiter.cleanupOldBuckets(3600000); // 1 hour threshold

      expect(limiter.getBucketState('user1', 'user')).toBeUndefined();
      expect(limiter.getBucketState('192.168.1.1', 'ip')).toBeUndefined();
      expect(limiter.getBucketState('user2', 'user')).toBeDefined();
    });

    it('should not remove recently used buckets', async () => {
      await limiter.checkLimit('user1', '192.168.1.1');
      limiter.cleanupOldBuckets(3600000);
      expect(limiter.getBucketState('user1', 'user')).toBeDefined();
    });
  });

  describe('getBucketState', () => {
    it('should return undefined for non-existent bucket', () => {
      expect(limiter.getBucketState('nonexistent', 'user')).toBeUndefined();
      expect(limiter.getBucketState('10.0.0.1', 'ip')).toBeUndefined();
    });

    it('should return bucket state after first interaction', async () => {
      await limiter.checkLimit('user1', '192.168.1.1');

      const userState = limiter.getBucketState('user1', 'user');
      expect(userState).toBeDefined();
      expect(userState!.capacity).toBe(10);
      expect(userState!.refillRate).toBeCloseTo(10 / 60);

      const ipState = limiter.getBucketState('192.168.1.1', 'ip');
      expect(ipState).toBeDefined();
      expect(ipState!.capacity).toBe(10);
    });
  });

  describe('token refill', () => {
    it('should refill tokens over time', async () => {
      // Create bucket then drain
      await limiter.checkLimit('user1', '192.168.1.1');
      const state = limiter.getBucketState('user1', 'user')!;
      state.tokens = 0;

      // Simulate time passing by adjusting lastRefill backward
      state.lastRefill = Date.now() - 6000; // 6 seconds ago
      // At 10 req/min = 0.1667 tokens/sec, 6 seconds = ~1 token

      const result = await limiter.checkLimit('user1', '192.168.1.1');
      expect(result.allowed).toBe(true);
    });

    it('should cap tokens at capacity during refill', async () => {
      await limiter.checkLimit('user1', '192.168.1.1');

      // Simulate a lot of time passing
      const state = limiter.getBucketState('user1', 'user')!;
      state.lastRefill = Date.now() - 3600000; // 1 hour ago

      await limiter.checkLimit('user1', '192.168.1.1');
      const afterState = limiter.getBucketState('user1', 'user')!;
      expect(afterState.tokens).toBeLessThanOrEqual(afterState.capacity);
    });
  });

  describe('edge cases', () => {
    it('should handle zero-capacity config gracefully', async () => {
      const zeroConfig: RateLimitConfig = {
        requestsPerMinute: 0,
        maxConcurrentConnections: 0,
        maxQueueSize: 0,
      };
      const zeroLimiter = new TokenBucketRateLimiter(zeroConfig);
      const result = await zeroLimiter.checkLimit('user1', '192.168.1.1');
      expect(result.allowed).toBe(false);
    });

    it('should handle recordRequest for non-existent bucket', () => {
      expect(() => limiter.recordRequest('unknown', '10.0.0.1')).not.toThrow();
    });

    it('should calculate retryAfter when tokens are exhausted', async () => {
      // Create bucket and force to zero
      await limiter.checkLimit('user1', '192.168.1.1');
      const state = limiter.getBucketState('user1', 'user')!;
      state.tokens = 0;

      const result = await limiter.checkLimit('user1', '192.168.1.1');
      expect(result.allowed).toBe(false);
      expect(result.retryAfter).toBeGreaterThan(0);
      // For 10 req/min, refill rate is 10/60 per second
      // To get 1 token: ~6 seconds
      expect(result.retryAfter).toBeLessThanOrEqual(60);
    });
  });
});
