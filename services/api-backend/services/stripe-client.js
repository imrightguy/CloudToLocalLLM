/**
 * Stripe Client Wrapper
 *
 * Provides a configured Stripe client with error handling and logging.
 * Supports both test and production modes based on environment configuration.
 */

import Stripe from 'stripe';
import logger from '../logger.js';

class StripeClient {
  constructor() {
    this.stripe = null;
    this.isTestMode = false;
    this.initialized = false;
  }

  /**
   * Initialize Stripe client with API keys from environment
   * @throws {Error} If Stripe API key is not configured
   */
  initialize() {
    if (this.initialized) {
      return;
    }

    // Determine which API key to use based on environment
    const isProduction = process.env.NODE_ENV === 'production';
    const apiKey = isProduction
      ? process.env.STRIPE_SECRET_KEY_PROD
      : process.env.STRIPE_SECRET_KEY_TEST;

    if (!apiKey) {
      const envVar = isProduction
        ? 'STRIPE_SECRET_KEY_PROD'
        : 'STRIPE_SECRET_KEY_TEST';
      throw new Error(
        `Stripe API key not configured. Please set ${envVar} environment variable.`
      );
    }

    this.isTestMode = !isProduction;

    // Initialize Stripe with API version
    this.stripe = new Stripe(apiKey, {
      apiVersion: '2024-11-20.acacia',
      typescript: false,
    });

    this.initialized = true;

    logger.info('Stripe client initialized', {
      mode: this.isTestMode ? 'test' : 'production',
      apiVersion: '2024-11-20.acacia',
    });
  }

  /**
   * Get the Stripe client instance
   * @returns {Stripe} Configured Stripe client
   * @throws {Error} If client is not initialized
   */
  getClient() {
    if (!this.initialized) {
      this.initialize();
    }
    return this.stripe;
  }

  /**
   * Check if running in test mode
   * @returns {boolean} True if in test mode
   */
  isTest() {
    return this.isTestMode;
  }

  /**
   * Handle Stripe errors and convert to standardized format
   * @param {Error} error - Stripe error object
   * @returns {Object} Standardized error response
   */
  handleStripeError(error) {
    logger.error('Stripe error occurred', {
      type: error.type,
      code: error.code,
      message: error.message,
      statusCode: error.statusCode,
      requestId: error.requestId,
    });

    // Map Stripe error types to standardized error codes
    switch (error.type) {
      case 'StripeCardError':
        // Card was declined
        return {
          code: 'CARD_DECLINED',
          message: error.message || 'Card was declined',
          details: {
            decline_code: error.decline_code,
            param: error.param,
          },
          statusCode: 402,
        };

      case 'StripeInvalidRequestError':
        // Invalid parameters
        return {
          code: 'INVALID_REQUEST',
          message: error.message || 'Invalid payment request',
          details: {
            param: error.param,
          },
          statusCode: 400,
        };

      case 'StripeAPIError':
        // Stripe API error
        return {
          code: 'PAYMENT_GATEWAY_ERROR',
          message: 'Payment gateway error. Please try again.',
          details: {
            type: error.type,
          },
          statusCode: 502,
        };

      case 'StripeConnectionError':
        // Network communication error
        return {
          code: 'GATEWAY_CONNECTION_ERROR',
          message: 'Unable to connect to payment gateway',
          details: {},
          statusCode: 503,
        };

      case 'StripeAuthenticationError':
        // Authentication with Stripe failed
        return {
          code: 'GATEWAY_AUTH_ERROR',
          message: 'Payment gateway authentication failed',
          details: {},
          statusCode: 500,
        };

      case 'StripeRateLimitError':
        // Too many requests
        return {
          code: 'RATE_LIMIT_EXCEEDED',
          message: 'Too many requests. Please try again later.',
          details: {},
          statusCode: 429,
        };

      default:
        return {
          code: 'UNKNOWN_ERROR',
          message: error.message || 'An unknown error occurred',
          details: {
            type: error.type,
          },
          statusCode: 500,
        };
    }
  }
}

// Export singleton instance
const stripeClient = new StripeClient();
export default stripeClient;
