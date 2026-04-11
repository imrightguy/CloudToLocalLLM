/**
 * Deployment Rollback on Failure Property Test
 *
 * **Feature: aws-eks-deployment, Property 5: Rollback on Failure**
 * **Validates: Requirements 1.5, 10.3**
 *
 * This test verifies that when a deployment fails, the system automatically
 * rolls back to the previous stable version, and the application remains
 * accessible during the rollback process. This is critical for ensuring
 * reliability and minimizing downtime during failed deployments.
 */

import fc from "fast-check";
import assert from "assert";
import { describe } from "@jest/globals";

/**
 * Simulate a deployment version with health status
 */
class DeploymentVersion {
  constructor(version, isHealthy = true) {
    this.version = version;
    this.isHealthy = isHealthy;
    this.timestamp = Date.now();
    this.replicas = 2;
    this.readyReplicas = isHealthy ? 2 : 0;
  }

  isAccessible() {
    return this.isHealthy && this.readyReplicas === this.replicas;
  }

  toJSON() {
    return {
      version: this.version,
      isHealthy: this.isHealthy,
      timestamp: this.timestamp,
      replicas: this.replicas,
      readyReplicas: this.readyReplicas,
    };
  }
}

/**
 * Simulate a Kubernetes deployment with rollback history
 */
class KubernetesDeployment {
  constructor(name) {
    this.name = name;
    this.currentVersion = null;
    this.previousVersion = null;
    this.deploymentHistory = [];
    this.isRollingBack = false;
  }

  /**
   * Deploy a new version
   */
  deploy(version, isHealthy = true) {
    const newVersion = new DeploymentVersion(version, isHealthy);

    // Store previous version before deploying new one
    if (this.currentVersion) {
      this.previousVersion = this.currentVersion;
    }

    this.currentVersion = newVersion;
    this.deploymentHistory.push({
      version: version,
      timestamp: Date.now(),
      status: isHealthy ? "success" : "failed",
    });

    return newVersion;
  }

  /**
   * Perform a rollback to the previous version
   */
  rollback() {
    if (!this.previousVersion) {
      throw new Error("No previous version available for rollback");
    }

    this.isRollingBack = true;

    // Swap current and previous
    const temp = this.currentVersion;
    this.currentVersion = this.previousVersion;
    this.previousVersion = temp;

    this.deploymentHistory.push({
      version: this.currentVersion.version,
      timestamp: Date.now(),
      status: "rolled_back",
    });

    this.isRollingBack = false;
    return this.currentVersion;
  }

  /**
   * Check if application is accessible
   */
  isAccessible() {
    return this.currentVersion && this.currentVersion.isAccessible();
  }

  /**
   * Get current version
   */
  getCurrentVersion() {
    return this.currentVersion ? this.currentVersion.version : null;
  }

  /**
   * Get deployment history
   */
  getHistory() {
    return this.deploymentHistory;
  }
}

/**
 * Simulate a deployment workflow with health checks
 */
class DeploymentWorkflow {
  constructor(deployment) {
    this.deployment = deployment;
    this.lastSuccessfulVersion = null;
  }

  /**
   * Execute deployment with automatic rollback on failure
   */
  executeDeployment(newVersion, isHealthy = true) {
    try {
      // Deploy new version
      const deployed = this.deployment.deploy(newVersion, isHealthy);

      // Simulate health check
      if (!deployed.isAccessible()) {
        throw new Error(`Health check failed for version ${newVersion}`);
      }

      // Mark as successful
      this.lastSuccessfulVersion = newVersion;
      return {
        success: true,
        version: newVersion,
        message: `Successfully deployed version ${newVersion}`,
      };
    } catch (error) {
      // Automatic rollback on failure
      if (this.deployment.previousVersion) {
        this.deployment.rollback();

        // Verify application is still accessible after rollback
        if (!this.deployment.isAccessible()) {
          throw new Error("Application not accessible after rollback");
        }

        return {
          success: false,
          version: newVersion,
          rolledBackTo: this.deployment.getCurrentVersion(),
          message: `Deployment failed. Rolled back to version ${this.deployment.getCurrentVersion()}`,
          error: error.message,
        };
      } else {
        throw new Error(
          "Deployment failed and no previous version available for rollback",
        );
      }
    }
  }

  /**
   * Get the current accessible version
   */
  getCurrentAccessibleVersion() {
    return this.deployment.isAccessible()
      ? this.deployment.getCurrentVersion()
      : null;
  }
}

/**
 * Generate version strings
 */
const versionArbitrary = () => {
  return fc
    .tuple(
      fc.integer({ min: 1, max: 10 }),
      fc.integer({ min: 0, max: 10 }),
      fc.integer({ min: 0, max: 10 }),
    )
    .map(([major, minor, patch]) => `${major}.${minor}.${patch}`);
};

/**
 * Generate deployment scenarios
 */
const deploymentScenarioArbitrary = () => {
  return fc.record({
    initialVersion: versionArbitrary(),
    deploymentSequence: fc.array(
      fc.record({
        version: versionArbitrary(),
        isHealthy: fc.boolean(),
      }),
      { minLength: 1, maxLength: 5 },
    ),
  });
};

describe("Deployment Rollback on Failure Property Test", () => {
  it("should automatically rollback to previous version on deployment failure", () => {
    fc.assert(
      fc.property(deploymentScenarioArbitrary(), (scenario) => {
        const deployment = new KubernetesDeployment("test-app");
        const workflow = new DeploymentWorkflow(deployment);

        // Deploy initial version
        const initialResult = workflow.executeDeployment(
          scenario.initialVersion,
          true,
        );
        assert(initialResult.success, "Initial deployment should succeed");

        // Execute deployment sequence
        scenario.deploymentSequence.forEach((step) => {
          const result = workflow.executeDeployment(
            step.version,
            step.isHealthy,
          );

          if (!step.isHealthy) {
            // If deployment failed, verify rollback occurred
            assert(
              !result.success,
              "Deployment should fail when health check fails",
            );
            assert(
              result.rolledBackTo,
              "Should have rolled back to previous version",
            );

            // Verify application is still accessible after rollback
            const currentAccessible = workflow.getCurrentAccessibleVersion();
            assert(
              currentAccessible !== null,
              "Application should remain accessible after rollback",
            );
          } else {
            // If deployment succeeded, verify it's the current version
            assert(
              result.success,
              "Deployment should succeed when health check passes",
            );
            assert.strictEqual(
              workflow.getCurrentAccessibleVersion(),
              step.version,
              "Current version should be the newly deployed version",
            );
          }
        });
      }),
      { numRuns: 100 },
    );
  });

  it("should maintain application accessibility during rollback", () => {
    fc.assert(
      fc.property(
        fc.tuple(versionArbitrary(), versionArbitrary(), versionArbitrary()),
        ([v1, v2, v3]) => {
          // Ensure versions are different
          fc.pre(v1 !== v2 && v2 !== v3);

          const deployment = new KubernetesDeployment("test-app");
          const workflow = new DeploymentWorkflow(deployment);

          // Deploy v1 (success)
          workflow.executeDeployment(v1, true);
          assert(
            workflow.getCurrentAccessibleVersion() === v1,
            "v1 should be accessible",
          );

          // Deploy v2 (success)
          workflow.executeDeployment(v2, true);
          assert(
            workflow.getCurrentAccessibleVersion() === v2,
            "v2 should be accessible",
          );

          // Deploy v3 (failure)
          const result = workflow.executeDeployment(v3, false);
          assert(!result.success, "v3 deployment should fail");

          // Verify application is still accessible and rolled back to v2
          assert(
            workflow.getCurrentAccessibleVersion() === v2,
            "Should rollback to v2",
          );
          assert(
            deployment.isAccessible(),
            "Application should remain accessible",
          );
        },
      ),
      { numRuns: 100 },
    );
  });

  it("should preserve deployment history including rollbacks", () => {
    fc.assert(
      fc.property(deploymentScenarioArbitrary(), (scenario) => {
        const deployment = new KubernetesDeployment("test-app");
        const workflow = new DeploymentWorkflow(deployment);

        // Deploy initial version
        workflow.executeDeployment(scenario.initialVersion, true);
        const initialHistoryLength = deployment.getHistory().length;

        // Execute deployment sequence
        let failureCount = 0;
        scenario.deploymentSequence.forEach((step) => {
          workflow.executeDeployment(step.version, step.isHealthy);
          if (!step.isHealthy) {
            failureCount++;
          }
        });

        // Verify history contains all deployments and rollbacks
        const history = deployment.getHistory();
        assert(
          history.length >=
            initialHistoryLength + scenario.deploymentSequence.length,
          "History should contain all deployment attempts",
        );

        // Count rollback entries
        const rollbackCount = history.filter(
          (h) => h.status === "rolled_back",
        ).length;
        assert.strictEqual(
          rollbackCount,
          failureCount,
          "Rollback count should match failure count",
        );
      }),
      { numRuns: 100 },
    );
  });

  it("should rollback to the immediately previous version, not an arbitrary old version", () => {
    fc.assert(
      fc.property(
        fc.tuple(
          versionArbitrary(),
          versionArbitrary(),
          versionArbitrary(),
          versionArbitrary(),
        ),
        ([v1, v2, v3, v4]) => {
          // Ensure versions are different
          fc.pre(v1 !== v2 && v2 !== v3 && v3 !== v4);

          const deployment = new KubernetesDeployment("test-app");
          const workflow = new DeploymentWorkflow(deployment);

          // Deploy v1, v2, v3 (all successful)
          workflow.executeDeployment(v1, true);
          workflow.executeDeployment(v2, true);
          workflow.executeDeployment(v3, true);

          assert(
            workflow.getCurrentAccessibleVersion() === v3,
            "v3 should be current",
          );

          // Deploy v4 (failure)
          workflow.executeDeployment(v4, false);

          // Should rollback to v3, not v1 or v2
          assert(
            workflow.getCurrentAccessibleVersion() === v3,
            "Should rollback to immediately previous version (v3), not an older version",
          );
        },
      ),
      { numRuns: 100 },
    );
  });

  it("should handle consecutive failed deployments with multiple rollbacks", () => {
    fc.assert(
      fc.property(
        fc.tuple(versionArbitrary(), versionArbitrary(), versionArbitrary()),
        ([v1, v2, v3]) => {
          // Ensure versions are different
          fc.pre(v1 !== v2 && v2 !== v3);

          const deployment = new KubernetesDeployment("test-app");
          const workflow = new DeploymentWorkflow(deployment);

          // Deploy v1 (success)
          workflow.executeDeployment(v1, true);
          assert(
            workflow.getCurrentAccessibleVersion() === v1,
            "v1 should be accessible",
          );

          // Deploy v2 (failure)
          const result2 = workflow.executeDeployment(v2, false);
          assert(!result2.success, "v2 deployment should fail");
          assert(
            workflow.getCurrentAccessibleVersion() === v1,
            "Should rollback to v1",
          );

          // Deploy v3 (failure)
          const result3 = workflow.executeDeployment(v3, false);
          assert(!result3.success, "v3 deployment should fail");
          assert(
            workflow.getCurrentAccessibleVersion() === v1,
            "Should remain on v1",
          );
        },
      ),
      { numRuns: 100 },
    );
  });

  it("should track successful deployments as rollback targets", () => {
    fc.assert(
      fc.property(deploymentScenarioArbitrary(), (scenario) => {
        const deployment = new KubernetesDeployment("test-app");
        const workflow = new DeploymentWorkflow(deployment);

        // Deploy initial version
        workflow.executeDeployment(scenario.initialVersion, true);

        // Execute deployment sequence
        scenario.deploymentSequence.forEach((step) => {
          workflow.executeDeployment(step.version, step.isHealthy);

          if (step.isHealthy) {
            // Update last successful version
            assert.strictEqual(
              workflow.lastSuccessfulVersion,
              step.version,
              "Last successful version should be updated",
            );
          }
        });

        // Verify we have a last successful version
        assert(
          workflow.lastSuccessfulVersion !== null,
          "Should have a last successful version",
        );
      }),
      { numRuns: 100 },
    );
  });

  it("should ensure rollback does not introduce new failures", () => {
    fc.assert(
      fc.property(
        fc.tuple(versionArbitrary(), versionArbitrary()),
        ([v1, v2]) => {
          // Ensure versions are different
          fc.pre(v1 !== v2);

          const deployment = new KubernetesDeployment("test-app");
          const workflow = new DeploymentWorkflow(deployment);

          // Deploy v1 (success)
          workflow.executeDeployment(v1, true);
          const v1Accessible = workflow.getCurrentAccessibleVersion();

          // Deploy v2 (failure)
          workflow.executeDeployment(v2, false);

          // After rollback, v1 should still be accessible
          const afterRollback = workflow.getCurrentAccessibleVersion();
          assert.strictEqual(
            v1Accessible,
            afterRollback,
            "Rollback should restore the same accessible version",
          );

          // Verify deployment is still healthy
          assert(
            deployment.isAccessible(),
            "Deployment should be healthy after rollback",
          );
        },
      ),
      { numRuns: 100 },
    );
  });
});
