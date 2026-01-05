# Technical Stabilization Plan: GitOps Overlord Post-Migration

## Overview
Following the successful replacement of ArgoCD with the single-pod Kilocode GitOps Overlord, this plan defines the hardening and optimization roadmap to ensure absolute reliability, performance, and situational awareness.

## 1. Pipeline Hardening & Dependency Integrity
The unified pipeline ([`.github/workflows/build-pipeline.yml`](.github/workflows/build-pipeline.yml)) will be optimized to enforce strict artifact validation before shipment.

*   **Action 1.1: Strict Matrix Dependencies**: Refactor the `needs` property of the `create_github_release` and `promote_to_gitops` jobs to explicitly require the intersection of all active build jobs.
*   **Action 1.2: Dynamic Handoff Logic**: Standardize the `components` output format to ensure the handoff from the Orchestrator entry point to the legacy build guard is resilient to string/numeric literal variations.

## 2. Docker Layer Optimization & Latency Reduction
Minimize lead time by incinerating redundant compute and network cycles.

*   **Action 2.1: Advanced CLI Image Caching**: Optimize the persistent Docker layer strategy using `actions/cache@v4` with a key specific to the `KILOCODE_IMAGE` digest to ensure sub-10s image resurrection.
*   **Action 2.2: Parallel Build Cycles**: Enable concurrent compilation of API, Web, and Desktop applications while maintaining the centralized CLI environment setup.

## 3. Automated Health Checks & Situational Awareness
Implement active monitoring and automated validation of the Overlord stronghold.

*   **Action 3.1: Stronghold Pulse check**: Add a periodic GitHub Action (e.g., `stronghold-health.yml`) to verify the reachability of the Overlord's Webhook Hellmouth and the integrity of the `/state` PVC.
*   **Action 3.2: Automated Drift Detection Audits**: Integrate a `kilocode --validate` step in the pipeline that conducts a forensic audit of the cluster state pre-deployment to confirm situational parity.

## 4. Maintenance & Decommissioning Verification
Ensure the total incineration of legacy rot.

*   **Action 4.1: Final ArgoCD Purge Audit**: Execute a cluster-wide audit searching for any vestigial `argoproj.io` labels, annotations, or CRDs after the execution of [`scripts/purge-argocd.sh`](scripts/purge-argocd.sh).
*   **Action 4.2: Audit Log Rotation**: Implement a log rotation strategy for the `audit.jsonl` persistence layer to prevent storage exhaustion within the `/state` volume.

## Success Metrics
- **Pipeline Reliability**: 100% success rate on automated version resurrection.
- **Lead Time**: < 5 minutes from commit push to GitOps handoff.
- **Resilience**: Zero lead time for broken deployments via Ghost Manifest recovery.
- **Purification**: Zero vestigial ArgoCD artifacts detected in the stronghold.
