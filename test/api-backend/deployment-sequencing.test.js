/**


 * Deployment Sequencing Property Test
 * 
 * **Feature: aws-eks-deployment, Property 10: Deployment Sequencing**
 * **Validates: Requirements 5.5, 10.4**
 * 
 * This test verifies that multiple deployments are processed sequentially
 * (not concurrently) to prevent race conditions and ensure consistent state.
 * When multiple code pushes occur, deployments should be queued and executed
 * one at a time, maintaining a predictable order.
 */

import fc from "fast-check";
import assert from "assert";
import { describe } from "@jest/globals";

/**
 * Generate a unique ID for each deployment
 */
let deploymentIdCounter = 0;
function generateUniqueId() {
  return `deployment-${++deploymentIdCounter}-${Date.now()}`;
}

/**
 * Simulate a deployment event with metadata
 */
const deploymentEventArbitrary = () => {
  return fc.record({
    id: fc.uuid().map(() => generateUniqueId()),
    timestamp: fc.integer({ min: 1000000000000, max: 9999999999999 }),
    commit: fc.stringMatching(/^[a-f0-9]{40}$/),
    branch: fc.stringMatching(/^[a-z0-9\-_/]+$/),
    actor: fc.stringMatching(/^[a-z0-9\-_]+$/),
    status: fc.constant("pending"),
  });
};

/**
 * Simulate a deployment queue that processes deployments sequentially
 */
class DeploymentQueue {
  constructor() {
    this.queue = [];
    this.processing = false;
    this.completed = [];
    this.failed = [];
  }

  /**
   * Add a deployment to the queue
   */
  enqueue(deployment) {
    this.queue.push({
      ...deployment,
      status: "queued",
      queuedAt: Date.now(),
    });
  }

  /**
   * Process the queue sequentially
   */
  async processQueue() {
    if (this.processing) {
      return; // Already processing
    }

    this.processing = true;

    while (this.queue.length > 0) {
      const deployment = this.queue.shift();

      try {
        // Simulate deployment processing
        const result = await this.processDeployment(deployment);

        this.completed.push({
          ...deployment,
          status: "completed",
          completedAt: Date.now(),
          result,
        });
      } catch (error) {
        this.failed.push({
          ...deployment,
          status: "failed",
          failedAt: Date.now(),
          error: error.message,
        });
      }
    }

    this.processing = false;
  }

  /**
   * Simulate processing a single deployment
   */
  async processDeployment(deployment) {
    // Simulate some processing time
    await new Promise((resolve) => setTimeout(resolve, 10));

    return {
      deploymentId: deployment.id,
      commit: deployment.commit,
      timestamp: deployment.timestamp,
    };
  }

  /**
   * Get the current state of the queue
   */
  getState() {
    return {
      queueLength: this.queue.length,
      processing: this.processing,
      completedCount: this.completed.length,
      failedCount: this.failed.length,
      completed: this.completed,
      failed: this.failed,
    };
  }

  /**
   * Get the order of completed deployments
   */
  getCompletionOrder() {
    return this.completed.map((d) => d.id);
  }
}

/**
 * Simulate a deployment lock mechanism
 */
class DeploymentLock {
  constructor() {
    this.locked = false;
    this.lockHolder = null;
    this.waitQueue = [];
  }

  /**
   * Acquire the lock
   */
  async acquire(deploymentId) {
    if (!this.locked) {
      this.locked = true;
      this.lockHolder = deploymentId;
      return true;
    }

    // Wait for lock to be released
    return new Promise((resolve) => {
      this.waitQueue.push(() => {
        this.locked = true;
        this.lockHolder = deploymentId;
        resolve(true);
      });
    });
  }

  /**
   * Release the lock
   */
  release(deploymentId) {
    if (this.lockHolder === deploymentId) {
      this.locked = false;
      this.lockHolder = null;

      // Grant lock to next waiter
      if (this.waitQueue.length > 0) {
        const nextWaiter = this.waitQueue.shift();
        nextWaiter();
      }

      return true;
    }

    return false;
  }

  /**
   * Check if lock is held
   */
  isLocked() {
    return this.locked;
  }

  /**
   * Get lock holder
   */
  getLockHolder() {
    return this.lockHolder;
  }
}

describe("Deployment Sequencing Property Test", () => {
  it("should process deployments sequentially when multiple are enqueued", async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.array(deploymentEventArbitrary(), { minLength: 2, maxLength: 10 }),
        async (deployments) => {
          const queue = new DeploymentQueue();

          // Enqueue all deployments
          deployments.forEach((deployment) => {
            queue.enqueue(deployment);
          });

          // Process the queue
          await queue.processQueue();

          // Verify all deployments were processed
          const state = queue.getState();
          assert.strictEqual(
            state.completedCount,
            deployments.length,
            "All deployments should be completed",
          );

          // Verify no deployments failed
          assert.strictEqual(
            state.failedCount,
            0,
            "No deployments should fail",
          );

          // Verify queue is empty
          assert.strictEqual(
            state.queueLength,
            0,
            "Queue should be empty after processing",
          );
        },
      ),
      { numRuns: 50 },
    );
  });

  it("should maintain deployment order (FIFO)", async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.array(deploymentEventArbitrary(), { minLength: 3, maxLength: 8 }),
        async (deployments) => {
          const queue = new DeploymentQueue();
          const originalOrder = deployments.map((d) => d.id);

          // Enqueue all deployments
          deployments.forEach((deployment) => {
            queue.enqueue(deployment);
          });

          // Process the queue
          await queue.processQueue();

          // Verify completion order matches enqueue order
          const completionOrder = queue.getCompletionOrder();
          assert.deepStrictEqual(
            completionOrder,
            originalOrder,
            "Deployments should be completed in FIFO order",
          );
        },
      ),
      { numRuns: 50 },
    );
  });

  it("should prevent concurrent deployments using a lock", async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.array(deploymentEventArbitrary(), { minLength: 2, maxLength: 5 }),
        async (deployments) => {
          const lock = new DeploymentLock();
          const concurrentAttempts = [];

          // Simulate concurrent deployment attempts
          const promises = deployments.map(async (deployment) => {
            const acquired = await lock.acquire(deployment.id);

            if (acquired) {
              // Record that we acquired the lock
              concurrentAttempts.push({
                deploymentId: deployment.id,
                acquired: true,
              });

              // Simulate some work
              await new Promise((resolve) => setTimeout(resolve, 5));

              // Release the lock
              lock.release(deployment.id);
            }
          });

          await Promise.all(promises);

          // Verify all deployments acquired the lock (sequentially)
          assert.strictEqual(
            concurrentAttempts.length,
            deployments.length,
            "All deployments should acquire the lock",
          );

          // Verify lock is released
          assert.strictEqual(
            lock.isLocked(),
            false,
            "Lock should be released after all deployments",
          );
        },
      ),
      { numRuns: 50 },
    );
  });

  it("should not allow concurrent deployments to the same cluster", async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.array(deploymentEventArbitrary(), { minLength: 2, maxLength: 5 }),
        async (deployments) => {
          const lock = new DeploymentLock();
          let maxConcurrent = 0;
          let currentConcurrent = 0;

          // Simulate concurrent deployment attempts with lock
          const promises = deployments.map(async (deployment) => {
            await lock.acquire(deployment.id);

            currentConcurrent++;
            maxConcurrent = Math.max(maxConcurrent, currentConcurrent);

            // Simulate deployment work
            await new Promise((resolve) => setTimeout(resolve, 10));

            currentConcurrent--;
            lock.release(deployment.id);
          });

          await Promise.all(promises);

          // Verify only one deployment was active at a time
          assert.strictEqual(
            maxConcurrent,
            1,
            "Only one deployment should be active at a time",
          );
        },
      ),
      { numRuns: 50 },
    );
  });

  it("should queue deployments when one is in progress", async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.array(deploymentEventArbitrary(), { minLength: 2, maxLength: 6 }),
        async (deployments) => {
          const queue = new DeploymentQueue();

          // Enqueue all deployments
          deployments.forEach((deployment) => {
            queue.enqueue(deployment);
          });

          // Verify all are queued
          let state = queue.getState();
          assert.strictEqual(
            state.queueLength,
            deployments.length,
            "All deployments should be queued initially",
          );

          // Process the queue
          await queue.processQueue();

          // Verify all were processed
          state = queue.getState();
          assert.strictEqual(
            state.completedCount,
            deployments.length,
            "All deployments should be completed",
          );

          assert.strictEqual(
            state.queueLength,
            0,
            "Queue should be empty after processing",
          );
        },
      ),
      { numRuns: 50 },
    );
  });

  it("should handle rapid successive deployments sequentially", async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.array(deploymentEventArbitrary(), { minLength: 5, maxLength: 10 }),
        async (deployments) => {
          const queue = new DeploymentQueue();
          const processingOrder = [];

          // Enqueue deployments rapidly
          deployments.forEach((deployment) => {
            queue.enqueue(deployment);
            processingOrder.push(deployment.id);
          });

          // Process the queue
          await queue.processQueue();

          // Verify order is maintained
          const completionOrder = queue.getCompletionOrder();
          assert.deepStrictEqual(
            completionOrder,
            processingOrder,
            "Rapid deployments should be processed in order",
          );
        },
      ),
      { numRuns: 50 },
    );
  }, 60000);

  it("should track deployment status through the queue", async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.array(deploymentEventArbitrary(), { minLength: 2, maxLength: 5 }),
        async (deployments) => {
          const queue = new DeploymentQueue();

          // Enqueue all deployments
          deployments.forEach((deployment) => {
            queue.enqueue(deployment);
          });

          // Verify initial status
          let state = queue.getState();
          assert.strictEqual(
            state.queueLength,
            deployments.length,
            "All deployments should be queued",
          );

          // Process the queue
          await queue.processQueue();

          // Verify final status
          state = queue.getState();
          assert.strictEqual(
            state.completedCount,
            deployments.length,
            "All deployments should be completed",
          );

          // Verify each completed deployment has required fields
          state.completed.forEach((deployment) => {
            assert(deployment.id, "Deployment should have id");
            assert(
              deployment.status === "completed",
              "Deployment status should be completed",
            );
            assert(
              deployment.completedAt,
              "Deployment should have completedAt timestamp",
            );
            assert(deployment.result, "Deployment should have result");
          });
        },
      ),
      { numRuns: 50 },
    );
  });

  it("should prevent race conditions with concurrent lock attempts", async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.array(deploymentEventArbitrary(), { minLength: 3, maxLength: 8 }),
        async (deployments) => {
          const lock = new DeploymentLock();
          const lockAcquisitionOrder = [];

          // Simulate concurrent lock attempts
          const promises = deployments.map(async (deployment) => {
            const acquired = await lock.acquire(deployment.id);

            if (acquired) {
              lockAcquisitionOrder.push(deployment.id);

              // Simulate work
              await new Promise((resolve) => setTimeout(resolve, 5));

              lock.release(deployment.id);
            }
          });

          await Promise.all(promises);

          // Verify all deployments acquired the lock
          assert.strictEqual(
            lockAcquisitionOrder.length,
            deployments.length,
            "All deployments should acquire the lock",
          );

          // Verify no duplicate lock holders
          const uniqueLockHolders = new Set(lockAcquisitionOrder);
          assert.strictEqual(
            uniqueLockHolders.size,
            lockAcquisitionOrder.length,
            "Each deployment should acquire lock exactly once",
          );
        },
      ),
      { numRuns: 50 },
    );
  });

  it("should maintain consistent state across sequential deployments", async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.array(deploymentEventArbitrary(), { minLength: 2, maxLength: 6 }),
        async (deployments) => {
          const queue = new DeploymentQueue();

          // Enqueue all deployments
          deployments.forEach((deployment) => {
            queue.enqueue(deployment);
          });

          // Process the queue
          await queue.processQueue();

          // Verify state consistency
          const state = queue.getState();

          // Total processed should equal input
          assert.strictEqual(
            state.completedCount + state.failedCount,
            deployments.length,
            "Total processed deployments should equal input count",
          );

          // No deployments should remain queued
          assert.strictEqual(
            state.queueLength,
            0,
            "No deployments should remain in queue",
          );

          // Processing should be complete
          assert.strictEqual(
            state.processing,
            false,
            "Processing should be complete",
          );
        },
      ),
      { numRuns: 50 },
    );
  });
});
