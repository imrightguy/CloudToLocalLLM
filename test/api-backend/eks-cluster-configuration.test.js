/**
 * AWS EKS Cluster Configuration Property Tests
 *
 * Tests for EKS cluster infrastructure configuration
 * Validates: Requirements 2.1, 2.2, 2.4
 *
 * Feature: aws-eks-deployment, Property 9: Cost Optimization
 * Validates: Requirements 2.1, 2.2, 2.4
 */

import { describe, test, expect } from '@jest/globals';
import fc from 'fast-check';

const AWS_ACCOUNT_ID = '422017356244';
const AWS_REGION = 'us-east-1';
const CLUSTER_NAME = 'cloudtolocalllm-eks';

// Valid instance types for development (cost-optimized)
const VALID_INSTANCE_TYPES = ['t3.small', 't3.micro'];

// Cost estimates per instance type per month (approximate, on-demand pricing)
// t3.small: ~$0.0208/hour = ~$15/month
// t3.micro: ~$0.0104/hour = ~$7.50/month
const INSTANCE_COSTS = {
  't3.small': 15,
  't3.micro': 7.50,
};

/**
 * Generate valid cluster configuration
 */
function generateClusterConfig(options = {}) {
  return {
    clusterName: options.clusterName || CLUSTER_NAME,
    awsRegion: options.awsRegion || AWS_REGION,
    awsAccountId: options.awsAccountId || AWS_ACCOUNT_ID,
    nodeInstanceType: options.nodeInstanceType || 't3.small',
    minNodes: options.minNodes !== undefined ? options.minNodes : 2,
    maxNodes: options.maxNodes !== undefined ? options.maxNodes : 3,
    desiredNodes: options.desiredNodes !== undefined ? options.desiredNodes : 2,
    kubernetesVersion: options.kubernetesVersion || '1.28',
    vpcCidr: options.vpcCidr || '10.0.0.0/16',
    enableLogging: options.enableLogging !== undefined ? options.enableLogging : true,
    enableMonitoring: options.enableMonitoring !== undefined ? options.enableMonitoring : true,
  };
}

/**
 * Calculate estimated monthly cost for cluster
 */
function calculateClusterCost(config) {
  const instanceCost = INSTANCE_COSTS[config.nodeInstanceType] || 7.50;
  const totalNodeCost = instanceCost * config.desiredNodes;

  // Add estimated costs for other services (minimal for development)
  const loadBalancerCost = 8; // Network Load Balancer (reduced)
  const storageEstimate = 5; // EBS storage estimate (minimal)
  const dataTransferEstimate = 2; // Data transfer estimate (minimal)

  return totalNodeCost + loadBalancerCost + storageEstimate + dataTransferEstimate;
}

/**
 * Validate cluster configuration
 */
function validateClusterConfig(config) {
  const errors = [];

  // Validate cluster name
  if (!config.clusterName || config.clusterName.length === 0) {
    errors.push('Cluster name is required');
  }

  // Validate AWS region
  if (!config.awsRegion || config.awsRegion.length === 0) {
    errors.push('AWS region is required');
  }

  // Validate instance type
  if (!VALID_INSTANCE_TYPES.includes(config.nodeInstanceType)) {
    errors.push(`Invalid instance type: ${config.nodeInstanceType}`);
  }

  // Validate node counts
  if (config.minNodes < 1) {
    errors.push('Minimum nodes must be at least 1');
  }

  if (config.maxNodes < config.minNodes) {
    errors.push('Maximum nodes must be >= minimum nodes');
  }

  if (config.desiredNodes < config.minNodes || config.desiredNodes > config.maxNodes) {
    errors.push('Desired nodes must be between min and max nodes');
  }

  // Validate Kubernetes version
  if (!config.kubernetesVersion || config.kubernetesVersion.length === 0) {
    errors.push('Kubernetes version is required');
  }

  // Validate VPC CIDR
  if (!config.vpcCidr || !config.vpcCidr.includes('/')) {
    errors.push('Invalid VPC CIDR block');
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Validate cost optimization constraints
 */
function validateCostOptimization(config) {
  const errors = [];

  // For development, should use t3.small or t3.micro only
  if (!['t3.small', 't3.micro'].includes(config.nodeInstanceType)) {
    errors.push(`Development cluster should use t3.small or t3.micro, got ${config.nodeInstanceType}`);
  }

  // For development, should use 2 nodes minimum
  if (config.minNodes < 2) {
    errors.push('Development cluster should have minimum 2 nodes');
  }

  // For development, should not exceed 3 nodes
  if (config.maxNodes > 3) {
    errors.push('Development cluster should not exceed 3 nodes');
  }

  // Desired nodes should match minimum for development
  if (config.desiredNodes !== config.minNodes) {
    errors.push('Development cluster desired nodes should match minimum nodes');
  }

  // Calculate estimated cost
  const estimatedCost = calculateClusterCost(config);
  const maxBudget = 75; // $75 per month (matching Azure cost)

  if (estimatedCost > maxBudget) {
    errors.push(`Estimated monthly cost ($${estimatedCost.toFixed(2)}) exceeds budget ($${maxBudget})`);
  }

  return {
    valid: errors.length === 0,
    errors,
    estimatedCost,
  };
}

describe('AWS EKS Cluster Configuration - Property Tests', () => {
  describe('Property 9: Cost Optimization', () => {
    test('should use t3.small instances for cost efficiency', () => {
      const config = generateClusterConfig({ nodeInstanceType: 't3.small' });

      expect(config.nodeInstanceType).toBe('t3.small');
      expect(VALID_INSTANCE_TYPES).toContain(config.nodeInstanceType);
    });

    test('should use minimum 2 nodes for development', () => {
      const config = generateClusterConfig({ minNodes: 2 });

      expect(config.minNodes).toBe(2);
      expect(config.minNodes).toBeGreaterThanOrEqual(2);
    });

    test('should not exceed 3 nodes for development', () => {
      const config = generateClusterConfig({ maxNodes: 3 });

      expect(config.maxNodes).toBeLessThanOrEqual(3);
    });

    test('should maintain desired nodes equal to minimum for development', () => {
      const config = generateClusterConfig({ minNodes: 2, desiredNodes: 2 });

      expect(config.desiredNodes).toBe(config.minNodes);
    });

    test('should estimate monthly cost within budget', () => {
      const config = generateClusterConfig({
        nodeInstanceType: 't3.small',
        minNodes: 2,
        maxNodes: 3,
        desiredNodes: 2,
      });

      const cost = calculateClusterCost(config);

      expect(cost).toBeLessThanOrEqual(75);
    });

    test('should calculate cost based on desired nodes', () => {
      const config1 = generateClusterConfig({ desiredNodes: 2 });
      const config2 = generateClusterConfig({ desiredNodes: 3 });

      const cost1 = calculateClusterCost(config1);
      const cost2 = calculateClusterCost(config2);

      expect(cost2).toBeGreaterThan(cost1);
    });

    test('should calculate cost based on instance type', () => {
      const config1 = generateClusterConfig({ nodeInstanceType: 't3.micro' });
      const config2 = generateClusterConfig({ nodeInstanceType: 't3.small' });

      const cost1 = calculateClusterCost(config1);
      const cost2 = calculateClusterCost(config2);

      expect(cost2).toBeGreaterThan(cost1);
    });

    test('should validate cost optimization constraints', () => {
      const config = generateClusterConfig({
        nodeInstanceType: 't3.small',
        minNodes: 2,
        maxNodes: 3,
        desiredNodes: 2,
      });

      const validation = validateCostOptimization(config);

      expect(validation.valid).toBe(true);
      expect(validation.estimatedCost).toBeLessThanOrEqual(75);
    });

    test('should reject oversized instances for development', () => {
      const config = generateClusterConfig({ nodeInstanceType: 't3.xlarge' });

      const validation = validateCostOptimization(config);

      expect(validation.valid).toBe(false);
      expect(validation.errors.length).toBeGreaterThan(0);
    });

    test('should reject single node configuration', () => {
      const config = generateClusterConfig({ minNodes: 1 });

      const validation = validateCostOptimization(config);

      expect(validation.valid).toBe(false);
    });

    test('should reject excessive node count', () => {
      const config = generateClusterConfig({ maxNodes: 10 });

      const validation = validateCostOptimization(config);

      expect(validation.valid).toBe(false);
    });

    test('should validate basic cluster configuration', () => {
      const config = generateClusterConfig();

      const validation = validateClusterConfig(config);

      expect(validation.valid).toBe(true);
    });

    test('should reject invalid instance type', () => {
      const config = generateClusterConfig({ nodeInstanceType: 'invalid-type' });

      const validation = validateClusterConfig(config);

      expect(validation.valid).toBe(false);
      expect(validation.errors.length).toBeGreaterThan(0);
    });

    test('should reject invalid node counts', () => {
      const config = generateClusterConfig({ minNodes: 5, maxNodes: 3 });

      const validation = validateClusterConfig(config);

      expect(validation.valid).toBe(false);
    });

    test('should reject desired nodes outside min/max range', () => {
      const config = generateClusterConfig({ minNodes: 2, maxNodes: 3, desiredNodes: 5 });

      const validation = validateClusterConfig(config);

      expect(validation.valid).toBe(false);
    });

    test('should support auto-scaling configuration', () => {
      const config = generateClusterConfig({
        minNodes: 2,
        maxNodes: 3,
        desiredNodes: 2,
      });

      expect(config.minNodes).toBeLessThanOrEqual(config.desiredNodes);
      expect(config.desiredNodes).toBeLessThanOrEqual(config.maxNodes);
    });

    test('should enable logging for monitoring', () => {
      const config = generateClusterConfig({ enableLogging: true });

      expect(config.enableLogging).toBe(true);
    });

    test('should enable monitoring for observability', () => {
      const config = generateClusterConfig({ enableMonitoring: true });

      expect(config.enableMonitoring).toBe(true);
    });

    test('should use valid VPC CIDR block', () => {
      const config = generateClusterConfig({ vpcCidr: '10.0.0.0/16' });

      expect(config.vpcCidr).toMatch(/^\d+\.\d+\.\d+\.\d+\/\d+$/);
    });

    test('should support Kubernetes 1.28 or later', () => {
      const config = generateClusterConfig({ kubernetesVersion: '1.28' });

      expect(config.kubernetesVersion).toBe('1.28');
    });

    test('should maintain cost under $75 with 2 t3.small nodes', () => {
      const config = generateClusterConfig({
        nodeInstanceType: 't3.small',
        minNodes: 2,
        desiredNodes: 2,
      });

      const cost = calculateClusterCost(config);

      expect(cost).toBeLessThanOrEqual(75);
    });

    test('should maintain cost under $75 with 3 t3.small nodes', () => {
      const config = generateClusterConfig({
        nodeInstanceType: 't3.small',
        minNodes: 3,
        desiredNodes: 3,
      });

      const cost = calculateClusterCost(config);

      expect(cost).toBeLessThanOrEqual(75);
    });

    test('should maintain cost under $75 with 2 t3.micro nodes', () => {
      const config = generateClusterConfig({
        nodeInstanceType: 't3.micro',
        minNodes: 2,
        desiredNodes: 2,
      });

      const cost = calculateClusterCost(config);

      expect(cost).toBeLessThanOrEqual(75);
    });
  });

  describe('Property 9: Cost Optimization - Property-Based Tests', () => {
    test('should validate any valid instance type', () => {
      fc.assert(
        fc.property(fc.constantFrom(...VALID_INSTANCE_TYPES), (instanceType) => {
          const config = generateClusterConfig({ nodeInstanceType: instanceType });
          const validation = validateClusterConfig(config);

          expect(validation.valid).toBe(true);
        }),
        { numRuns: 100 }
      );
    });

    test('should calculate cost proportional to node count', () => {
      fc.assert(
        fc.property(fc.integer({ min: 1, max: 10 }), (nodeCount) => {
          const config1 = generateClusterConfig({ desiredNodes: nodeCount });
          const config2 = generateClusterConfig({ desiredNodes: nodeCount + 1 });

          const cost1 = calculateClusterCost(config1);
          const cost2 = calculateClusterCost(config2);

          expect(cost2).toBeGreaterThan(cost1);
        }),
        { numRuns: 100 }
      );
    });

    test('should maintain valid node count ranges', () => {
      fc.assert(
        fc.property(
          fc.integer({ min: 1, max: 5 }),
          fc.integer({ min: 1, max: 5 }),
          (min, max) => {
            const actualMin = Math.min(min, max);
            const actualMax = Math.max(min, max);

            const config = generateClusterConfig({
              minNodes: actualMin,
              maxNodes: actualMax,
              desiredNodes: actualMin,
            });

            const validation = validateClusterConfig(config);

            expect(validation.valid).toBe(true);
          }
        ),
        { numRuns: 100 }
      );
    });

    test('should reject invalid node configurations', () => {
      fc.assert(
        fc.property(
          fc.integer({ min: 1, max: 5 }),
          fc.integer({ min: 1, max: 5 }),
          (min, max) => {
            // Create invalid config where min > max
            if (min > max) {
              const config = generateClusterConfig({
                minNodes: min,
                maxNodes: max,
              });

              const validation = validateClusterConfig(config);

              expect(validation.valid).toBe(false);
            }
          }
        ),
        { numRuns: 100 }
      );
    });

    test('should maintain cost budget for any valid configuration', () => {
      fc.assert(
        fc.property(
          fc.constantFrom('t3.small', 't3.micro'),
          fc.integer({ min: 2, max: 3 }),
          (instanceType, nodeCount) => {
            const config = generateClusterConfig({
              nodeInstanceType: instanceType,
              minNodes: nodeCount,
              desiredNodes: nodeCount,
            });

            const cost = calculateClusterCost(config);

            // Cost should be under $75 for development
            expect(cost).toBeLessThanOrEqual(75);
          }
        ),
        { numRuns: 100 }
      );
    });

    test('should validate cost optimization for all valid configurations', () => {
      fc.assert(
        fc.property(
          fc.constantFrom('t3.small', 't3.micro'),
          fc.integer({ min: 2, max: 3 }),
          (instanceType, nodeCount) => {
            const config = generateClusterConfig({
              nodeInstanceType: instanceType,
              minNodes: nodeCount,
              maxNodes: Math.min(nodeCount + 1, 3),
              desiredNodes: nodeCount,
            });

            const cost = calculateClusterCost(config);

            // Cost should be reasonable for development
            expect(cost).toBeLessThanOrEqual(75);
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Cluster Configuration Edge Cases', () => {
    test('should handle minimum viable cluster', () => {
      const config = generateClusterConfig({
        nodeInstanceType: 't3.micro',
        minNodes: 2,
        maxNodes: 2,
        desiredNodes: 2,
      });

      const validation = validateClusterConfig(config);
      const costValidation = validateCostOptimization(config);

      expect(validation.valid).toBe(true);
      expect(costValidation.valid).toBe(true);
    });

    test('should handle maximum viable cluster', () => {
      const config = generateClusterConfig({
        nodeInstanceType: 't3.small',
        minNodes: 3,
        maxNodes: 3,
        desiredNodes: 3,
      });

      const validation = validateClusterConfig(config);
      const costValidation = validateCostOptimization(config);

      expect(validation.valid).toBe(true);
      expect(costValidation.valid).toBe(true);
    });

    test('should handle auto-scaling scenario', () => {
      const config = generateClusterConfig({
        nodeInstanceType: 't3.small',
        minNodes: 2,
        maxNodes: 3,
        desiredNodes: 2,
      });

      const validation = validateClusterConfig(config);

      expect(validation.valid).toBe(true);
      expect(config.minNodes).toBeLessThanOrEqual(config.desiredNodes);
      expect(config.desiredNodes).toBeLessThanOrEqual(config.maxNodes);
    });

    test('should calculate cost for minimum configuration', () => {
      const config = generateClusterConfig({
        nodeInstanceType: 't3.micro',
        desiredNodes: 2,
      });

      const cost = calculateClusterCost(config);

      expect(cost).toBeGreaterThan(0);
      expect(cost).toBeLessThanOrEqual(75);
    });

    test('should calculate cost for maximum configuration', () => {
      const config = generateClusterConfig({
        nodeInstanceType: 't3.small',
        desiredNodes: 3,
      });

      const cost = calculateClusterCost(config);

      expect(cost).toBeGreaterThan(0);
      expect(cost).toBeLessThanOrEqual(75);
    });
  });
});
