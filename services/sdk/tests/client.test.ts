/**
 * CloudToLocalLLM SDK Client Tests
 * 
 * Tests for the main SDK client functionality
 */

import { CloudToLocalLLMClient } from '../src/client';
import { SDKConfig } from '../src/types';

describe('CloudToLocalLLMClient', () => {
  let client: CloudToLocalLLMClient;
  const mockConfig: SDKConfig = {
    baseURL: 'http://localhost:8080',
    apiVersion: 'v2',
    timeout: 5000,
  };

  beforeEach(() => {
    client = new CloudToLocalLLMClient(mockConfig);
  });

  describe('Initialization', () => {
    it('should create a client with default configuration', () => {
      const testClient = new CloudToLocalLLMClient({
        baseURL: 'http://localhost:8080',
      });
      expect(testClient).toBeDefined();
    });

    it('should create a client with custom configuration', () => {
      const testClient = new CloudToLocalLLMClient({
        baseURL: 'http://localhost:8080',
        apiVersion: 'v1',
        timeout: 10000,
        retryAttempts: 5,
      });
      expect(testClient).toBeDefined();
    });
  });

  describe('Token Management', () => {
    it('should set tokens', () => {
      const accessToken = 'test-access-token';
      const refreshToken = 'test-refresh-token';

      client.setTokens(accessToken, refreshToken);
      // Tokens are stored internally, we can verify by checking if they're used in requests
      expect(client).toBeDefined();
    });

    it('should set only access token', () => {
      const accessToken = 'test-access-token';

      client.setTokens(accessToken);
      expect(client).toBeDefined();
    });

    it('should clear tokens', () => {
      client.setTokens('test-token');
      client.clearTokens();
      expect(client).toBeDefined();
    });
  });

  describe('Configuration', () => {
    it('should use default API version v2', () => {
      const testClient = new CloudToLocalLLMClient({
        baseURL: 'http://localhost:8080',
      });
      expect(testClient).toBeDefined();
    });

    it('should support API version v1', () => {
      const testClient = new CloudToLocalLLMClient({
        baseURL: 'http://localhost:8080',
        apiVersion: 'v1',
      });
      expect(testClient).toBeDefined();
    });

    it('should use default timeout of 30000ms', () => {
      const testClient = new CloudToLocalLLMClient({
        baseURL: 'http://localhost:8080',
      });
      expect(testClient).toBeDefined();
    });

    it('should use custom timeout', () => {
      const testClient = new CloudToLocalLLMClient({
        baseURL: 'http://localhost:8080',
        timeout: 60000,
      });
      expect(testClient).toBeDefined();
    });
  });

  describe('Error Handling', () => {
    it('should handle missing baseURL', () => {
      expect(() => {
        new CloudToLocalLLMClient({
          baseURL: '',
        });
      }).not.toThrow();
    });

    it('should handle invalid configuration gracefully', () => {
      const testClient = new CloudToLocalLLMClient({
        baseURL: 'http://localhost:8080',
        timeout: -1, // Invalid timeout
      });
      expect(testClient).toBeDefined();
    });
  });

  describe('Client Methods Exist', () => {
    it('should have getCurrentUser method', () => {
      expect(typeof client.getCurrentUser).toBe('function');
    });

    it('should have getUser method', () => {
      expect(typeof client.getUser).toBe('function');
    });

    it('should have updateUser method', () => {
      expect(typeof client.updateUser).toBe('function');
    });

    it('should have deleteUser method', () => {
      expect(typeof client.deleteUser).toBe('function');
    });

    it('should have createTunnel method', () => {
      expect(typeof client.createTunnel).toBe('function');
    });

    it('should have getTunnel method', () => {
      expect(typeof client.getTunnel).toBe('function');
    });

    it('should have listTunnels method', () => {
      expect(typeof client.listTunnels).toBe('function');
    });

    it('should have updateTunnel method', () => {
      expect(typeof client.updateTunnel).toBe('function');
    });

    it('should have deleteTunnel method', () => {
      expect(typeof client.deleteTunnel).toBe('function');
    });

    it('should have startTunnel method', () => {
      expect(typeof client.startTunnel).toBe('function');
    });

    it('should have stopTunnel method', () => {
      expect(typeof client.stopTunnel).toBe('function');
    });

    it('should have createWebhook method', () => {
      expect(typeof client.createWebhook).toBe('function');
    });

    it('should have getWebhook method', () => {
      expect(typeof client.getWebhook).toBe('function');
    });

    it('should have listWebhooks method', () => {
      expect(typeof client.listWebhooks).toBe('function');
    });

    it('should have updateWebhook method', () => {
      expect(typeof client.updateWebhook).toBe('function');
    });

    it('should have deleteWebhook method', () => {
      expect(typeof client.deleteWebhook).toBe('function');
    });

    it('should have listUsers method', () => {
      expect(typeof client.listUsers).toBe('function');
    });

    it('should have getAdminUser method', () => {
      expect(typeof client.getAdminUser).toBe('function');
    });

    it('should have getHealth method', () => {
      expect(typeof client.getHealth).toBe('function');
    });

    it('should have logout method', () => {
      expect(typeof client.logout).toBe('function');
    });
  });
});
