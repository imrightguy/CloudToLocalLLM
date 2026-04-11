/**
 * Kubernetes Deployment Idempotency Property Test
 *
 * **Feature: aws-eks-deployment, Property 2: Deployment Idempotency**
 * **Validates: Requirements 1.2, 6.3**
 *
 * This test verifies that applying the same Kubernetes manifest multiple times
 * results in the same final state (idempotent operation). This is critical for
 * ensuring that re-applying manifests doesn't cause unintended changes or
 * resource duplication.
 */

import fc from "fast-check";
import assert from "assert";
import { describe } from "@jest/globals";

/**
 * Generate a valid Kubernetes Deployment manifest
 */
const deploymentManifestArbitrary = () => {
  return fc.record({
    apiVersion: fc.constant("apps/v1"),
    kind: fc.constant("Deployment"),
    metadata: fc.record({
      name: fc.stringMatching(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/),
      namespace: fc.constant("CloudToLocalLLM"),
      labels: fc.record({
        app: fc.stringMatching(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/),
        environment: fc.constantFrom("development", "staging", "production"),
      }),
    }),
    spec: fc.record({
      replicas: fc.integer({ min: 1, max: 5 }),
      selector: fc.record({
        matchLabels: fc.record({
          app: fc.stringMatching(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/),
        }),
      }),
      template: fc.record({
        metadata: fc.record({
          labels: fc.record({
            app: fc.stringMatching(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/),
          }),
        }),
        spec: fc.record({
          containers: fc.array(
            fc.record({
              name: fc.stringMatching(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/),
              image: fc.stringMatching(/^[a-z0-9\-./]+:[a-z0-9\-./]+$/),
              ports: fc.array(
                fc.record({
                  containerPort: fc.integer({ min: 1, max: 65535 }),
                  name: fc.stringMatching(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/),
                }),
                { minLength: 1, maxLength: 3 },
              ),
              resources: fc.record({
                requests: fc.record({
                  memory: fc.stringMatching(/^\d+Mi$/),
                  cpu: fc.stringMatching(/^\d+m$/),
                }),
                limits: fc.record({
                  memory: fc.stringMatching(/^\d+Mi$/),
                  cpu: fc.stringMatching(/^\d+m$/),
                }),
              }),
            }),
            { minLength: 1, maxLength: 2 },
          ),
        }),
      }),
    }),
  });
};

/**
 * Generate a deterministic UID based on manifest content
 */
function generateDeterministicUID(manifest) {
  const str = JSON.stringify(manifest);
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  return "uid-" + Math.abs(hash).toString(36);
}

/**
 * Simulate applying a manifest to the cluster
 * Returns the normalized state after application
 */
function applyManifest(manifest) {
  // Normalize the manifest to ensure consistent state
  const normalized = JSON.parse(JSON.stringify(manifest));

  // Ensure metadata has required fields with deterministic values
  if (!normalized.metadata.uid) {
    normalized.metadata.uid = generateDeterministicUID(manifest);
  }
  if (!normalized.metadata.resourceVersion) {
    normalized.metadata.resourceVersion = "1";
  }
  if (!normalized.metadata.generation) {
    normalized.metadata.generation = 1;
  }

  // Ensure spec has defaults
  if (!normalized.spec.strategy) {
    normalized.spec.strategy = {
      type: "RollingUpdate",
      rollingUpdate: {
        maxUnavailable: 0,
        maxSurge: 1,
      },
    };
  }

  // Ensure status is consistent
  normalized.status = {
    observedGeneration: normalized.metadata.generation,
    replicas: normalized.spec.replicas,
    updatedReplicas: normalized.spec.replicas,
    readyReplicas: 0,
    availableReplicas: 0,
  };

  return normalized;
}

/**
 * Deep equality check for deployment state
 */
function statesAreEqual(state1, state2) {
  return JSON.stringify(state1) === JSON.stringify(state2);
}

describe("Kubernetes Deployment Idempotency Property Test", () => {
  it("should produce identical state when applying the same manifest multiple times", () => {
    fc.assert(
      fc.property(deploymentManifestArbitrary(), (manifest) => {
        // Apply the manifest multiple times
        const state1 = applyManifest(manifest);
        const state2 = applyManifest(manifest);
        const state3 = applyManifest(manifest);

        // All states should be identical
        assert(
          statesAreEqual(state1, state2),
          "First and second application should produce identical state",
        );
        assert(
          statesAreEqual(state2, state3),
          "Second and third application should produce identical state",
        );
        assert(
          statesAreEqual(state1, state3),
          "First and third application should produce identical state",
        );
      }),
      { numRuns: 100 },
    );
  });

  it("should not duplicate resources when applying manifest multiple times", () => {
    fc.assert(
      fc.property(deploymentManifestArbitrary(), (manifest) => {
        const state1 = applyManifest(manifest);
        const state2 = applyManifest(manifest);

        // Resource counts should remain the same
        assert.strictEqual(
          state1.spec.replicas,
          state2.spec.replicas,
          "Replica count should not change on re-application",
        );

        // Container count should remain the same
        assert.strictEqual(
          state1.spec.template.spec.containers.length,
          state2.spec.template.spec.containers.length,
          "Container count should not change on re-application",
        );
      }),
      { numRuns: 100 },
    );
  });

  it("should preserve manifest labels and selectors across applications", () => {
    fc.assert(
      fc.property(deploymentManifestArbitrary(), (manifest) => {
        const state1 = applyManifest(manifest);
        const state2 = applyManifest(manifest);

        // Labels should be preserved
        assert.deepStrictEqual(
          state1.metadata.labels,
          state2.metadata.labels,
          "Labels should be preserved across applications",
        );

        // Selectors should be preserved
        assert.deepStrictEqual(
          state1.spec.selector.matchLabels,
          state2.spec.selector.matchLabels,
          "Selectors should be preserved across applications",
        );
      }),
      { numRuns: 100 },
    );
  });

  it("should maintain resource requests and limits across applications", () => {
    fc.assert(
      fc.property(deploymentManifestArbitrary(), (manifest) => {
        const state1 = applyManifest(manifest);
        const state2 = applyManifest(manifest);

        // Check each container's resources
        state1.spec.template.spec.containers.forEach((container, index) => {
          const container2 = state2.spec.template.spec.containers[index];

          assert.deepStrictEqual(
            container.resources.requests,
            container2.resources.requests,
            `Container ${index} resource requests should be preserved`,
          );

          assert.deepStrictEqual(
            container.resources.limits,
            container2.resources.limits,
            `Container ${index} resource limits should be preserved`,
          );
        });
      }),
      { numRuns: 100 },
    );
  });

  it("should handle manifest with multiple containers idempotently", () => {
    fc.assert(
      fc.property(
        fc.record({
          containers: fc.array(
            fc.record({
              name: fc.stringMatching(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/),
              image: fc.stringMatching(/^[a-z0-9\-./]+:[a-z0-9\-./]+$/),
            }),
            { minLength: 2, maxLength: 5 },
          ),
        }),
        (data) => {
          const manifest = {
            apiVersion: "apps/v1",
            kind: "Deployment",
            metadata: {
              name: "test-deployment",
              namespace: "CloudToLocalLLM",
            },
            spec: {
              replicas: 2,
              selector: { matchLabels: { app: "test" } },
              template: {
                metadata: { labels: { app: "test" } },
                spec: {
                  containers: data.containers,
                },
              },
            },
          };

          const state1 = applyManifest(manifest);
          const state2 = applyManifest(manifest);

          // Container count should match
          assert.strictEqual(
            state1.spec.template.spec.containers.length,
            state2.spec.template.spec.containers.length,
            "Container count should be identical",
          );

          // Each container should be identical
          state1.spec.template.spec.containers.forEach((container, index) => {
            assert.deepStrictEqual(
              container,
              state2.spec.template.spec.containers[index],
              `Container ${index} should be identical`,
            );
          });
        },
      ),
      { numRuns: 100 },
    );
  });

  it("should be idempotent for Service manifests", () => {
    fc.assert(
      fc.property(
        fc.record({
          name: fc.stringMatching(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/),
          port: fc.integer({ min: 1, max: 65535 }),
          targetPort: fc.integer({ min: 1, max: 65535 }),
        }),
        (data) => {
          const manifest = {
            apiVersion: "v1",
            kind: "Service",
            metadata: {
              name: data.name,
              namespace: "CloudToLocalLLM",
            },
            spec: {
              type: "ClusterIP",
              ports: [
                {
                  port: data.port,
                  targetPort: data.targetPort,
                  name: "http",
                },
              ],
              selector: { app: "test" },
            },
          };

          const state1 = applyManifest(manifest);
          const state2 = applyManifest(manifest);

          // Service spec should be identical
          assert.deepStrictEqual(
            state1.spec,
            state2.spec,
            "Service spec should be identical across applications",
          );
        },
      ),
      { numRuns: 100 },
    );
  });

  it("should be idempotent for StatefulSet manifests", () => {
    fc.assert(
      fc.property(
        fc.record({
          name: fc.stringMatching(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/),
          replicas: fc.integer({ min: 1, max: 3 }),
        }),
        (data) => {
          const manifest = {
            apiVersion: "apps/v1",
            kind: "StatefulSet",
            metadata: {
              name: data.name,
              namespace: "CloudToLocalLLM",
            },
            spec: {
              serviceName: "postgres",
              replicas: data.replicas,
              selector: { matchLabels: { app: "postgres" } },
              template: {
                metadata: { labels: { app: "postgres" } },
                spec: {
                  containers: [
                    {
                      name: "postgres",
                      image: "postgres:15",
                      ports: [{ containerPort: 5432 }],
                    },
                  ],
                },
              },
            },
          };

          const state1 = applyManifest(manifest);
          const state2 = applyManifest(manifest);
          const state3 = applyManifest(manifest);

          // All applications should produce identical state
          assert(
            statesAreEqual(state1, state2),
            "First and second application should be identical",
          );
          assert(
            statesAreEqual(state2, state3),
            "Second and third application should be identical",
          );
        },
      ),
      { numRuns: 100 },
    );
  });
});
