# CloudToLocalLLM – Node.js 24 LTS Upgrade Specification and Plan

## 1. Upgrade Rationale

Why move from Node.js 20 LTS to 24 LTS:

- Performance
  - Newer V8 engine with ongoing JIT and GC improvements that generally reduce startup time and improve throughput under load.
  - Web platform APIs (fetch/streams/URL) receive incremental performance and stability optimizations.
  - Expect modest improvements for I/O-heavy Express services and streaming workloads.
- Security
  - Aggregated security fixes since Node 20 (OpenSSL/CVE patches, ICU updates, core runtime hardening).
  - Reduced exposure window by being on the latest LTS maintenance line.
- Modern JavaScript features
  - First-class support for recent ECMAScript features (ES2023/ES2024), including standardized Array helpers (toSorted/toReversed/toSpliced/with), stable fetch/Streams/Web Crypto APIs, and improved ESM interoperability.
- LTS horizon
  - Node 20 LTS maintenance ends April 2026.
  - Node 24 LTS maintenance ends April 2029 — three additional years of security and stability updates.
- Ecosystem compatibility
  - Most mainstream libraries have validated support for >=18 and latest LTS lines. Moving earlier avoids "end-of-line catch‑up" later and aligns dev, CI, and container images on a single modern baseline.

## 2. Compatibility Analysis (Current Repository)

Confirmed from the codebase:

- Engines
  - services/api-backend/package.json: "node": ">=18.0.0" (compatible with 24 LTS)
  - services/streaming-proxy/package.json: "node": ">=18.0.0" (compatible with 24 LTS)
  - Root package.json: no engines field (no constraint)
- CI/CD
  - .github/workflows/cloudrun-deploy.yml uses actions/setup-node with node-version: '18' (needs update to '24').
  - .github/workflows/gke-deploy.yml sets node-version: '18' in validate-deployment job (needs update to '24').
- Dockerfiles (Node base images)
  - services/api-backend/Dockerfile: FROM node:18-alpine
  - services/api-backend/Dockerfile.prod: FROM node:18-alpine (base and production stages)
  - services/streaming-proxy/Dockerfile: FROM node:18-alpine
  - services/streaming-proxy/Dockerfile.prod: FROM node:18-alpine (base and production stages)
  - Dockerfile/api: FROM node:18-alpine (builder + final stages)
  - Dockerfile/streaming: FROM node:18-alpine
  - web/Dockerfile: nginx (no Node specific version)
- Scripts directory
  - No hardcoded Node major versions found in scripts/* that require changes, but validation scripts compare against >=18 (acceptable). Consider updating informational messages to recommend 24.
- Dependencies (risk notes)
  - services/api-backend depends on sqlite3 and pg. For Node 24 on Alpine (musl), prebuilt binaries may be unavailable for some combinations; npm may compile from source. Ensure Docker builder stages include build tools if needed (python3, make, g++), or pin to images that provide prebuilds.

Recommended verification during implementation:

- Run npm ci && npm ls in root and both services on Node 24 to surface peer/deprecation warnings.
- Build all service images with node:24-alpine locally and in CI to validate native module builds.

## 3. Detailed Change Specification

Documentation and developer setup

1) Manjaro setup plan (developer guide) – update Node version recommendations and examples

- Change text: "Node.js (20 LTS recommended; engines accept >=18)" → "Node.js (24 LTS recommended; engines accept >=18)"
- asdf example: `asdf install nodejs latest:20` → `asdf install nodejs latest:24`
- Volta example: `volta install node@20` → `volta install node@24`
- Validation section: version checks should expect Node 24.x (e.g., `node -v` prints v24.*)
- If we maintain this setup plan inside docs, apply the above to the appropriate document(s) (e.g., docs/DEVELOPMENT/DEVELOPER_ONBOARDING.md or a new Linux/Manjaro setup doc).

1) docs/DEVELOPMENT/DEVELOPER_ONBOARDING.md

- Replace "Node.js: 18+ (for API backend development)" with "Node.js: 24 LTS recommended (>=18 supported)".

CI/CD workflows
3) .github/workflows/cloudrun-deploy.yml

- Setup Node.js step: change `node-version: '18'` → `node-version: '24'`.

1) .github/workflows/gke-deploy.yml

- validate-deployment job: change `node-version: '18'` → `node-version: '24'`.

Containers (Node runtime)
5) services/api-backend/Dockerfile

- `FROM node:18-alpine` → `FROM node:24-alpine`.

1) services/api-backend/Dockerfile.prod

- `FROM node:18-alpine AS base` → `FROM node:24-alpine AS base`
- `FROM node:18-alpine AS production` → `FROM node:24-alpine AS production`
- If sqlite3 builds from source under Node 24: add build tools in the base stage (example):
  - `RUN apk add --no-cache python3 make g++`

1) services/streaming-proxy/Dockerfile

- `FROM node:18-alpine` → `FROM node:24-alpine`.

1) services/streaming-proxy/Dockerfile.prod

- `FROM node:18-alpine AS base` → `FROM node:24-alpine AS base`
- `FROM node:18-alpine AS production` → `FROM node:24-alpine AS production`

1) Dockerfile/api

- `FROM node:18-alpine AS builder` → `FROM node:24-alpine AS builder`
- `FROM node:18-alpine` → `FROM node:24-alpine`
- If native module builds arise, add in builder stage: `RUN apk add --no-cache python3 make g++`

1) Dockerfile/streaming

- `FROM node:18-alpine` → `FROM node:24-alpine`

Validation commands (docs)
11) Update doc sections that check Node version to explicitly show v24.x expected output.

General search-and-replace
12) Search repository for textual references to "node:18" and "node-version: '18'" and update to 24 where applicable.

## 4. Risk Assessment

Categories and mitigations:

- Runtime breaking changes (20 → 24)
  - Risk: Subtle behavior changes in core libs, V8 engine, or deprecations. Mitigation: Run unit/integration/e2e tests under Node 24; monitor logs for deprecation warnings; audit change logs of Node 21–24 (notably OpenSSL, WHATWG URL, Fetch changes).
- Native modules on Alpine (sqlite3)
  - Risk: No prebuilt Node 24 musl binaries → compile from source; longer build times; potential failures without toolchain.
  - Mitigation: Install `python3 make g++` in builder stages; consider using Debian-based slim images if needed; verify successful module load at runtime.
- Developer environment divergence
  - Risk: Some developers remain on Node 20 leading to inconsistent behavior.
  - Mitigation: Recommend Volta/asdf pinning to Node 24; document transition period; keep engines as ">=18" to avoid blocking but promote 24.
- CI/CD pipeline compatibility
  - Risk: Failing steps after upgrading actions/setup-node and image builds.
  - Mitigation: Use a feature branch; run full CI; if failures, revert node-version in workflows quickly (rollback below).
- Cloud Run/GKE compatibility
  - Risk: No incompatibility expected; Node 24 images supported. Ensure container size/perf acceptable.
- Performance regressions
  - Risk: Unintended regressions due to runtime changes.
  - Mitigation: Run baseline k6 smoke/perf tests and compare; monitor latency/CPU after deploy.

Rollback procedures:

- Revert CI workflows: change `node-version: '24'` back to `'18'`.
- Revert Dockerfiles: `node:24-alpine` back to `node:18-alpine`.
- Rebuild and redeploy previous images; re-run validation.
- Communicate rollback in PR and release notes.

## 5. Testing Requirements

Local (Manjaro Linux):

- Tooling validation: `node -v` (v24.x), `npm -v`, `docker --version`, `docker compose version`.
- Install deps: `npm ci` (root and services), `npx playwright install`.
- Backend:
  - services/api-backend: `npm run test` / `npm run test:unit` / `npm run db:migrate` then `npm run dev`; `curl -f http://127.0.0.1:8080/health`.
  - services/streaming-proxy: `npm run dev` and health check endpoint if present.
- Flutter client smoke with web and desktop to validate end-to-end connection paths.

CI/CD:

- Update actions/setup-node to 24 and run full pipelines on PR.
- Validate Cloud Run deploy workflow builds/pushes images and passes health checks.
- Validate GKE workflow validate-deployment job under Node 24.

Containers:

- Build all Node images locally (or via CI): `docker build` for each Dockerfile.
- Run containers and check health endpoints.

E2E tests:

- Run Playwright suites: `npx playwright test`.

Performance baseline:

- Run k6 smoke test (`test/k6`) pre- and post-upgrade; compare P95 latency and error rates.

## 6. Communication & Transition Plan

- Announce upgrade intent and timeline in repository discussions and a GitHub Issue.
- Provide developer instructions to switch to Node 24 via Volta/asdf.
- Transition window: 1–2 sprints where Node >=18 continues to work; CI enforces 24 for pipelines and containers.
- Update docs (onboarding, setup guides) to recommend Node 24.

## 7. Implementation Checklist (High-Level)

- Create feature branch: `feat/node24-upgrade`.
- Update workflows to Node 24.
- Update Docker base images to `node:24-alpine`; add builder toolchains if needed.
- Update docs (onboarding/setup/Manjaro guide) and validation commands.
- Run local/CI tests, container builds, and deployment validations.
- Monitor for native module build issues; adjust builder stages as necessary.
- Prepare rollback plan in PR description.
