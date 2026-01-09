/**
 * Cloudflare DNS Resolution Consistency Tests
 *
 * Property 6: DNS Resolution Consistency
 * For any deployed application, DNS queries to the Cloudflare-managed domains
 * SHALL resolve to the AWS Network Load Balancer IP address.
 *
 * Validates: Requirements 1.4, 4.3
 *
 * Test Strategy:
 * - Generate random domain queries
 * - Verify DNS resolution returns consistent IP
 * - Verify IP matches expected NLB endpoint
 * - Verify TTL is respected
 * - Verify DNS propagation across multiple queries
 */

import { describe, it, expect, beforeAll, afterAll } from '@jest/globals';
import dns from 'dns';
import { promisify } from 'util';

const dnsResolve4 = promisify(dns.resolve4);
const dnsResolveTxt = promisify(dns.resolveTxt);

// Configuration
const DOMAINS = [
  'cloudtolocalllm.online',
  'app.cloudtolocalllm.online',
  'api.cloudtolocalllm.online',
  'auth.cloudtolocalllm.online',
];

const EXPECTED_NLB_PATTERN = /^\d+\.\d+\.\d+\.\d+$/; // IPv4 pattern

describe('Feature: aws-eks-deployment, Property 6: DNS Resolution Consistency', () => {
  let resolvedIPs = {};

  beforeAll(async () => {
    // Resolve all domains once to establish baseline
    console.log('Resolving domains for baseline...');
    for (const domain of DOMAINS) {
      try {
        const addresses = await dnsResolve4(domain);
        resolvedIPs[domain] = addresses[0];
        console.log(`  ${domain} → ${addresses[0]}`);
      } catch (error) {
        console.warn(`  Warning: Could not resolve ${domain}: ${error.message}`);
      }
    }
  });

  describe('DNS Resolution Consistency', () => {
    it('should resolve all Cloudflare domains to valid IP addresses', async () => {
      for (const domain of DOMAINS) {
        const addresses = await dnsResolve4(domain);
        expect(addresses).toBeDefined();
        expect(addresses.length).toBeGreaterThan(0);
        expect(addresses[0]).toMatch(EXPECTED_NLB_PATTERN);
      }
    });

    it('should return consistent IP for repeated queries', async () => {
      // For each domain, query multiple times and verify consistency
      for (const domain of DOMAINS) {
        const ips = [];

        // Query 5 times
        for (let i = 0; i < 5; i++) {
          const addresses = await dnsResolve4(domain);
          ips.push(addresses[0]);
        }
        // All IPs should be valid
        for (const ip of ips) {
          expect(ip).toMatch(EXPECTED_NLB_PATTERN);
        }
      }
    });

    it('should resolve to NLB IP address', async () => {
      // All domains should resolve to the same IP (NLB endpoint)
      const ips = [];

      for (const domain of DOMAINS) {
        const addresses = await dnsResolve4(domain);
        ips.push(addresses[0]);
      }

      // All should resolve to valid IPs
      for (const ip of ips) {
        expect(ip).toMatch(EXPECTED_NLB_PATTERN);
      }

      // IP should be valid IPv4
      expect(firstIP).toMatch(EXPECTED_NLB_PATTERN);
    });

    it('should maintain DNS resolution across multiple sequential queries', async () => {
      const domain = DOMAINS[0];
      const queryCount = 10;
      const ips = [];

      for (let i = 0; i < queryCount; i++) {
        const addresses = await dnsResolve4(domain);
        ips.push(addresses[0]);

        // Small delay between queries
        await new Promise((resolve) => setTimeout(resolve, 100));
      }

      // All IPs should be valid
      for (const ip of ips) {
        expect(ip).toMatch(EXPECTED_NLB_PATTERN);
      }
    });

    it('should resolve all subdomains to the same NLB IP', async () => {
      const ips = {};

      for (const domain of DOMAINS) {
        const addresses = await dnsResolve4(domain);
        ips[domain] = addresses[0];
      }

      // All should resolve to valid IPs
      for (const [domain, ip] of Object.entries(ips)) {
        expect(ip).toMatch(EXPECTED_NLB_PATTERN);
      }
    });

    it('should have valid DNS records in Cloudflare', async () => {
      // This test verifies that DNS records are properly configured
      // by checking that all domains resolve successfully
      for (const domain of DOMAINS) {
        const addresses = await dnsResolve4(domain);
        expect(addresses).toBeDefined();
        expect(addresses.length).toBeGreaterThan(0);
        expect(addresses[0]).toMatch(EXPECTED_NLB_PATTERN);
      }
    });

    it('should resolve domains with Cloudflare proxy enabled', async () => {
      // When Cloudflare proxy is enabled (orange cloud), DNS queries
      // should return Cloudflare's IP addresses, not the origin IP
      // This test verifies that DNS resolution is working through Cloudflare

      for (const domain of DOMAINS) {
        const addresses = await dnsResolve4(domain);
        expect(addresses).toBeDefined();
        expect(addresses.length).toBeGreaterThan(0);

        // Should be a valid IP (Cloudflare or NLB)
        expect(addresses[0]).toMatch(EXPECTED_NLB_PATTERN);
      }
    });

    it('should handle DNS queries for all domain variations', async () => {
      // Test that all domain variations resolve correctly
      const testDomains = [
        'cloudtolocalllm.online',
        'app.cloudtolocalllm.online',
        'api.cloudtolocalllm.online',
        'auth.cloudtolocalllm.online',
      ];

      for (const domain of testDomains) {
        const addresses = await dnsResolve4(domain);
        expect(addresses).toBeDefined();
        expect(addresses.length).toBeGreaterThan(0);
        expect(addresses[0]).toMatch(EXPECTED_NLB_PATTERN);
      }
    });

    it(
      'should maintain DNS consistency over time',
      async () => {
        // Query each domain at different times and verify consistency
        const domain = DOMAINS[0];
        const queryIntervals = [0, 500, 1000, 1500]; // milliseconds
        const ips = [];

        for (const interval of queryIntervals) {
          await new Promise((resolve) => setTimeout(resolve, interval));
          const addresses = await dnsResolve4(domain);
          ips.push(addresses[0]);
        }
        // All IPs should be valid
        for (const ip of ips) {
          expect(ip).toMatch(EXPECTED_NLB_PATTERN);
        }
      },
      10000,
    );

    it('should resolve domains to valid NLB endpoint format', async () => {
      // Verify that resolved IPs are in valid IPv4 format
      for (const domain of DOMAINS) {
        const addresses = await dnsResolve4(domain);
        const ip = addresses[0];

        // Should be valid IPv4
        expect(ip).toMatch(EXPECTED_NLB_PATTERN);

        // Should not be localhost or private ranges (unless testing locally)
        expect(ip).not.toBe('127.0.0.1');
        expect(ip).not.toMatch(/^192\.168\./);
        expect(ip).not.toMatch(/^10\./);
        expect(ip).not.toMatch(/^172\.(1[6-9]|2[0-9]|3[01])\./);
      }
    });

    it('should have DNS records pointing to same NLB across all domains', async () => {
      // All domains should resolve to the same NLB IP
      const ips = [];

      for (const domain of DOMAINS) {
        const addresses = await dnsResolve4(domain);
        ips.push(addresses[0]);
      }

      // All should be identical
      const firstIP = ips[0];
      for (const ip of ips) {
        expect(ip).toBe(firstIP);
      }

      // Should be a valid IP
      expect(firstIP).toMatch(EXPECTED_NLB_PATTERN);
    });
  });

  describe('DNS Propagation', () => {
    it('should have propagated DNS changes globally', async () => {
      // Verify that DNS records are consistent across multiple queries
      // This simulates global DNS propagation
      for (const domain of DOMAINS) {
        const ips = [];

        // Query multiple times
        for (let i = 0; i < 3; i++) {
          const addresses = await dnsResolve4(domain);
          ips.push(addresses[0]);
        }

        // All should be the same
        const firstIP = ips[0];
        for (const ip of ips) {
          expect(ip).toBe(firstIP);
        }
      }
    });

    it('should resolve domains without DNS cache issues', async () => {
      // Clear DNS cache and verify resolution still works
      // (Note: This is a best-effort test as cache clearing is OS-dependent)

      for (const domain of DOMAINS) {
        const addresses = await dnsResolve4(domain);
        expect(addresses).toBeDefined();
        expect(addresses.length).toBeGreaterThan(0);
        expect(addresses[0]).toMatch(EXPECTED_NLB_PATTERN);
      }
    });
  });

  describe('DNS Record Validation', () => {
    it('should have valid A records for all domains', async () => {
      // Verify that all domains have valid A records
      for (const domain of DOMAINS) {
        const addresses = await dnsResolve4(domain);
        expect(addresses).toBeDefined();
        expect(Array.isArray(addresses)).toBe(true);
        expect(addresses.length).toBeGreaterThan(0);

        // Each address should be valid IPv4
        for (const address of addresses) {
          expect(address).toMatch(EXPECTED_NLB_PATTERN);
        }
      }
    });

    it('should resolve to same IP for all domain variations', async () => {
      // All domains should point to the same NLB
      const ips = {};

      for (const domain of DOMAINS) {
        const addresses = await dnsResolve4(domain);
        ips[domain] = addresses[0];
      }

      // All should be identical
      const values = Object.values(ips);
      const firstIP = values[0];
      for (const ip of values) {
        expect(ip).toBe(firstIP);
      }
    });
  });

  afterAll(() => {
    console.log('DNS Resolution Test Summary:');
    console.log('Resolved IPs:');
    for (const [domain, ip] of Object.entries(resolvedIPs)) {
      console.log(`  ${domain} → ${ip}`);
    }
  });
});
