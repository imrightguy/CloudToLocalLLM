import { jest, describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import stripeClient from '../../services/api-backend/services/stripe-client.js';

jest.mock('../../services/api-backend/logger.js', () => ({
  default: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
  },
}));

describe('StripeClient', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
    stripeClient.stripe = null;
    stripeClient.isTestMode = false;
    stripeClient.initialized = false;
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  describe('initialize', () => {
    it('throws if no API key is set in non-production', () => {
      process.env.NODE_ENV = 'development';
      delete process.env.STRIPE_SECRET_KEY_TEST;
      expect(() => stripeClient.initialize()).toThrow(
        'Stripe API key not configured. Please set STRIPE_SECRET_KEY_TEST environment variable.',
      );
    });

    it('throws if no API key is set in production', () => {
      process.env.NODE_ENV = 'production';
      delete process.env.STRIPE_SECRET_KEY_PROD;
      expect(() => stripeClient.initialize()).toThrow(
        'Stripe API key not configured. Please set STRIPE_SECRET_KEY_PROD environment variable.',
      );
    });

    it('initializes in test mode when NODE_ENV is not production', () => {
      process.env.NODE_ENV = 'development';
      process.env.STRIPE_SECRET_KEY_TEST = 'sk_test_123';
      stripeClient.initialize();
      expect(stripeClient.isTestMode).toBe(true);
      expect(stripeClient.initialized).toBe(true);
      expect(stripeClient.stripe).toBeDefined();
    });

    it('initializes in production mode when NODE_ENV is production', () => {
      process.env.NODE_ENV = 'production';
      process.env.STRIPE_SECRET_KEY_PROD = 'sk_live_123';
      stripeClient.initialize();
      expect(stripeClient.isTestMode).toBe(false);
      expect(stripeClient.initialized).toBe(true);
    });

    it('uses test key even without explicit NODE_ENV', () => {
      delete process.env.NODE_ENV;
      process.env.STRIPE_SECRET_KEY_TEST = 'sk_test_456';
      stripeClient.initialize();
      expect(stripeClient.isTestMode).toBe(true);
    });

    it('does not re-initialize if already initialized', () => {
      process.env.NODE_ENV = 'development';
      process.env.STRIPE_SECRET_KEY_TEST = 'sk_test_123';
      stripeClient.initialize();
      const firstStripe = stripeClient.stripe;
      stripeClient.initialize();
      expect(stripeClient.stripe).toBe(firstStripe);
    });
  });

  describe('getClient', () => {
    it('auto-initializes if not initialized', () => {
      process.env.NODE_ENV = 'development';
      process.env.STRIPE_SECRET_KEY_TEST = 'sk_test_auto';
      const client = stripeClient.getClient();
      expect(client).toBeDefined();
      expect(stripeClient.initialized).toBe(true);
    });

    it('returns the same stripe instance after initialization', () => {
      process.env.NODE_ENV = 'development';
      process.env.STRIPE_SECRET_KEY_TEST = 'sk_test_same';
      const client1 = stripeClient.getClient();
      const client2 = stripeClient.getClient();
      expect(client1).toBe(client2);
    });
  });

  describe('isTest', () => {
    it('returns true in test mode', () => {
      process.env.NODE_ENV = 'development';
      process.env.STRIPE_SECRET_KEY_TEST = 'sk_test_123';
      stripeClient.initialize();
      expect(stripeClient.isTest()).toBe(true);
    });

    it('returns false in production mode', () => {
      process.env.NODE_ENV = 'production';
      process.env.STRIPE_SECRET_KEY_PROD = 'sk_live_123';
      stripeClient.initialize();
      expect(stripeClient.isTest()).toBe(false);
    });
  });

  describe('handleStripeError', () => {
    it('maps StripeCardError to CARD_DECLINED with 402', () => {
      const error = new Error('Your card was declined.');
      error.type = 'StripeCardError';
      error.decline_code = 'insufficient_funds';
      error.param = 'amount';

      const result = stripeClient.handleStripeError(error);
      expect(result.code).toBe('CARD_DECLINED');
      expect(result.statusCode).toBe(402);
      expect(result.details.decline_code).toBe('insufficient_funds');
      expect(result.details.param).toBe('amount');
    });

    it('maps StripeInvalidRequestError to INVALID_REQUEST with 400', () => {
      const error = new Error('Invalid amount');
      error.type = 'StripeInvalidRequestError';
      error.param = 'amount';

      const result = stripeClient.handleStripeError(error);
      expect(result.code).toBe('INVALID_REQUEST');
      expect(result.statusCode).toBe(400);
      expect(result.details.param).toBe('amount');
    });

    it('maps StripeAPIError to PAYMENT_GATEWAY_ERROR with 502', () => {
      const error = new Error('API error');
      error.type = 'StripeAPIError';

      const result = stripeClient.handleStripeError(error);
      expect(result.code).toBe('PAYMENT_GATEWAY_ERROR');
      expect(result.statusCode).toBe(502);
    });

    it('maps StripeConnectionError to GATEWAY_CONNECTION_ERROR with 503', () => {
      const error = new Error('Connection error');
      error.type = 'StripeConnectionError';

      const result = stripeClient.handleStripeError(error);
      expect(result.code).toBe('GATEWAY_CONNECTION_ERROR');
      expect(result.statusCode).toBe(503);
    });

    it('maps StripeAuthenticationError to GATEWAY_AUTH_ERROR with 500', () => {
      const error = new Error('Auth failed');
      error.type = 'StripeAuthenticationError';

      const result = stripeClient.handleStripeError(error);
      expect(result.code).toBe('GATEWAY_AUTH_ERROR');
      expect(result.statusCode).toBe(500);
    });

    it('maps StripeRateLimitError to RATE_LIMIT_EXCEEDED with 429', () => {
      const error = new Error('Rate limited');
      error.type = 'StripeRateLimitError';

      const result = stripeClient.handleStripeError(error);
      expect(result.code).toBe('RATE_LIMIT_EXCEEDED');
      expect(result.statusCode).toBe(429);
    });

    it('maps unknown error types to UNKNOWN_ERROR with 500', () => {
      const error = new Error('Something weird');
      error.type = 'WeirdError';

      const result = stripeClient.handleStripeError(error);
      expect(result.code).toBe('UNKNOWN_ERROR');
      expect(result.statusCode).toBe(500);
      expect(result.details.type).toBe('WeirdError');
    });

    it('uses fallback message when error.message is undefined', () => {
      const error = { type: 'StripeCardError' };
      const result = stripeClient.handleStripeError(error);
      expect(result.message).toBe('Card was declined');
    });

    it('handles error with no type as UNKNOWN_ERROR', () => {
      const error = new Error('No type error');
      const result = stripeClient.handleStripeError(error);
      expect(result.code).toBe('UNKNOWN_ERROR');
      expect(result.statusCode).toBe(500);
    });
  });
});
