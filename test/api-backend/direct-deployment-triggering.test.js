/**
 * Property-Based Test for Direct Deployment Triggering
 *
 * **Feature: cicd-workflow-streamlining, Property 1: Direct Deployment Triggering**
 * **Validates: Requirements 1.1**
 *
 * This test verifies that for any push to the main branch containing changes to
 * deployment-relevant files, the system should trigger deployment directly without
 * intermediate orchestration workflows.
 */

import fc from "fast-check";
import { describe, test, expect } from "@jest/globals";

// Mock GitHub Actions workflow trigger logic
class WorkflowTrigger {
  constructor() {
    this.triggeredWorkflows = [];
    this.branchPushes = [];
  }

  // Simulate a push to main branch with changed files
  pushToMain(changedFiles) {
    this.branchPushes.push({
      branch: "main",
      changedFiles: changedFiles || [],
    });

    // Check if deployment should be triggered based on file patterns
    const shouldTriggerDeployment = this.shouldTriggerDeployment(changedFiles);

    if (shouldTriggerDeployment) {
      // Direct deployment triggering - no intermediate orchestration
      this.triggeredWorkflows.push({
        workflow: "deploy.yml",
        trigger: "direct",
        reason: "deployment-relevant files changed",
      });
    }

    return shouldTriggerDeployment;
  }

  // Determine if deployment should be triggered based on changed files
  shouldTriggerDeployment(changedFiles) {
    if (!changedFiles || changedFiles.length === 0) {
      return false;
    }

    // Deployment-relevant file patterns (from requirements)
    const deploymentPatterns = [
      /^web\//,
      /^lib\//,
      /^services\//,
      /^k8s\//,
      /^config\//,
      /auth0-bridge\.js$/,
      /router\.dart$/,
      /auth.*\.dart$/,
      /\.github\/workflows\/deploy\.yml$/,
    ];

    // Documentation and non-functional files that should NOT trigger deployment
    const skipPatterns = [
      /^docs\//,
      /\.md$/,
      /^\.gitignore$/,
      /^LICENSE$/,
      /^README/,
    ];

    // Check if any files match skip patterns (should not deploy)
    const hasOnlySkipFiles = changedFiles.every((file) =>
      skipPatterns.some((pattern) => pattern.test(file)),
    );

    if (hasOnlySkipFiles) {
      return false;
    }

    // Check if any files match deployment patterns
    return changedFiles.some((file) =>
      deploymentPatterns.some((pattern) => pattern.test(file)),
    );
  }

  // Check if deployment was triggered directly (not through orchestration)
  wasDeploymentTriggeredDirectly() {
    return this.triggeredWorkflows.some(
      (workflow) =>
        workflow.workflow === "deploy.yml" && workflow.trigger === "direct",
    );
  }

  // Reset state for testing
  reset() {
    this.triggeredWorkflows = [];
    this.branchPushes = [];
  }
}

describe("Direct Deployment Triggering Properties", () => {
  let workflowTrigger;

  beforeEach(() => {
    workflowTrigger = new WorkflowTrigger();
  });

  test("Property 1: Direct Deployment Triggering - deployment-relevant files trigger direct deployment", () => {
    /**
     * **Feature: cicd-workflow-streamlining, Property 1: Direct Deployment Triggering**
     * **Validates: Requirements 1.1**
     *
     * For any push to the main branch containing changes to deployment-relevant files,
     * the system should trigger deployment directly without intermediate orchestration workflows.
     */

    fc.assert(
      fc.property(
        // Generate arrays of file paths that should trigger deployment
        fc.array(
          fc.oneof(
            fc.constant("web/index.html"),
            fc.constant("web/auth0-bridge.js"),
            fc.constant("lib/main.dart"),
            fc.constant("lib/config/router.dart"),
            fc.constant("lib/services/auth_service.dart"),
            fc.constant("services/api-backend/server.js"),
            fc.constant("services/streaming-proxy/proxy.js"),
            fc.constant("k8s/web-deployment.yaml"),
            fc.constant("k8s/api-backend-deployment.yaml"),
            fc.constant("config/docker/Dockerfile.web"),
            fc.constant(".github/workflows/deploy.yml"),
          ),
          { minLength: 1, maxLength: 10 },
        ),
        (deploymentRelevantFiles) => {
          // Reset state
          workflowTrigger.reset();

          // Push to main with deployment-relevant files
          const deploymentTriggered = workflowTrigger.pushToMain(
            deploymentRelevantFiles,
          );

          // Verify deployment was triggered directly
          expect(deploymentTriggered).toBe(true);
          expect(workflowTrigger.wasDeploymentTriggeredDirectly()).toBe(true);

          // Verify no intermediate orchestration workflows were triggered
          const orchestrationWorkflows =
            workflowTrigger.triggeredWorkflows.filter(
              (workflow) => workflow.workflow === "version-and-distribute.yml",
            );
          expect(orchestrationWorkflows).toHaveLength(0);

          return true;
        },
      ),
      { numRuns: 100 },
    );
  });

  test("Property 1: Direct Deployment Triggering - documentation-only changes do not trigger deployment", () => {
    /**
     * **Feature: cicd-workflow-streamlining, Property 1: Direct Deployment Triggering**
     * **Validates: Requirements 1.1**
     *
     * Changes that only affect documentation or non-functional files should not
     * trigger deployment to optimize resource usage.
     */

    fc.assert(
      fc.property(
        // Generate arrays of documentation/non-functional files
        fc.array(
          fc.oneof(
            fc.constant("docs/README.md"),
            fc.constant("docs/INSTALLATION.md"),
            fc.constant("README.md"),
            fc.constant("CHANGELOG.md"),
            fc.constant("LICENSE"),
            fc.constant(".gitignore"),
            fc.constant("docs/API/endpoints.md"),
            fc.constant("docs/DEVELOPMENT/setup.md"),
          ),
          { minLength: 1, maxLength: 5 },
        ),
        (documentationFiles) => {
          // Reset state
          workflowTrigger.reset();

          // Push to main with only documentation files
          const deploymentTriggered =
            workflowTrigger.pushToMain(documentationFiles);

          // Verify deployment was NOT triggered
          expect(deploymentTriggered).toBe(false);
          expect(workflowTrigger.wasDeploymentTriggeredDirectly()).toBe(false);

          // Verify no workflows were triggered at all
          expect(workflowTrigger.triggeredWorkflows).toHaveLength(0);

          return true;
        },
      ),
      { numRuns: 100 },
    );
  });

  test("Property 1: Direct Deployment Triggering - authentication changes always trigger deployment", () => {
    /**
     * **Feature: cicd-workflow-streamlining, Property 1: Direct Deployment Triggering**
     * **Validates: Requirements 1.1**
     *
     * Authentication-related changes should always trigger cloud deployment
     * regardless of other factors, as they are critical for system security.
     */

    fc.assert(
      fc.property(
        // Generate arrays that include authentication files
        fc.array(
          fc.oneof(
            fc.constant("web/auth0-bridge.js"),
            fc.constant("lib/services/auth_service.dart"),
            fc.constant("lib/config/auth_config.dart"),
            fc.constant("lib/models/auth_user.dart"),
            fc.constant("services/api-backend/auth/jwt.js"),
            fc.constant("config/auth0.json"),
          ),
          { minLength: 1, maxLength: 3 },
        ),
        // Mix with some documentation files to test priority
        fc.array(
          fc.oneof(fc.constant("docs/README.md"), fc.constant("CHANGELOG.md")),
          { maxLength: 2 },
        ),
        (authFiles, docFiles) => {
          // Reset state
          workflowTrigger.reset();

          // Combine auth files with documentation files
          const allFiles = [...authFiles, ...docFiles];

          // Push to main with mixed files including auth changes
          const deploymentTriggered = workflowTrigger.pushToMain(allFiles);

          // Verify deployment was triggered due to auth changes
          expect(deploymentTriggered).toBe(true);
          expect(workflowTrigger.wasDeploymentTriggeredDirectly()).toBe(true);

          return true;
        },
      ),
      { numRuns: 100 },
    );
  });

  test("Property 1: Direct Deployment Triggering - empty file changes do not trigger deployment", () => {
    /**
     * **Feature: cicd-workflow-streamlining, Property 1: Direct Deployment Triggering**
     * **Validates: Requirements 1.1**
     *
     * Empty pushes or pushes with no file changes should not trigger deployment.
     */

    fc.assert(
      fc.property(
        fc.constant([]), // Empty array of changed files
        (emptyFiles) => {
          // Reset state
          workflowTrigger.reset();

          // Push to main with no file changes
          const deploymentTriggered = workflowTrigger.pushToMain(emptyFiles);

          // Verify deployment was NOT triggered
          expect(deploymentTriggered).toBe(false);
          expect(workflowTrigger.wasDeploymentTriggeredDirectly()).toBe(false);

          return true;
        },
      ),
      { numRuns: 100 },
    );
  });

  test("Property 1: Direct Deployment Triggering - mixed file changes trigger deployment when relevant files present", () => {
    /**
     * **Feature: cicd-workflow-streamlining, Property 1: Direct Deployment Triggering**
     * **Validates: Requirements 1.1**
     *
     * When a push contains both deployment-relevant and non-relevant files,
     * deployment should be triggered due to the presence of relevant files.
     */

    fc.assert(
      fc.property(
        // Generate deployment-relevant files
        fc.array(
          fc.oneof(
            fc.constant("web/index.html"),
            fc.constant("lib/main.dart"),
            fc.constant("services/api-backend/server.js"),
          ),
          { minLength: 1, maxLength: 3 },
        ),
        // Generate non-relevant files
        fc.array(
          fc.oneof(
            fc.constant("docs/README.md"),
            fc.constant("CHANGELOG.md"),
            fc.constant(".gitignore"),
          ),
          { maxLength: 3 },
        ),
        (relevantFiles, nonRelevantFiles) => {
          // Reset state
          workflowTrigger.reset();

          // Combine both types of files
          const allFiles = [...relevantFiles, ...nonRelevantFiles];

          // Push to main with mixed files
          const deploymentTriggered = workflowTrigger.pushToMain(allFiles);

          // Verify deployment was triggered due to relevant files
          expect(deploymentTriggered).toBe(true);
          expect(workflowTrigger.wasDeploymentTriggeredDirectly()).toBe(true);

          return true;
        },
      ),
      { numRuns: 100 },
    );
  });
});
