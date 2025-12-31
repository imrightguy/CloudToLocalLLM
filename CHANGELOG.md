# Changelog

All notable changes to this project will be documented in this file.

## [10.1.0] - 2025-12-31
## v10.1.0

### Features
*   Migrate from Supabase to Auth0 PKCE auth pipeline (bc51953)
*   Migrate to Auth0 PKCE stateless JWT pipeline (remove Supabase, 50% LOC reduction, mutex races fixed, backend stubs) (43f1cb9)

### Bug Fixes
*   Resolve grep option error in build pipeline (485f36c)
*   Fix ArgoCD cloudflared configuration to use HTTP instead of HTTPS (61f673c)

### Security
*   Harden cors and disable debug endpoint (c4dcfe1)

### Refactoring
*   Remove legacy auth providers and fix test suite (04fa52a)
*   Secure refactor of cloudflared diagnostic and repair scripts, updated SOP v1.6.0 (71f00be)

### Documentation
*   Finalize cleanup of last remaining stray documentation files (3296194)
*   Update Auth0 tenant references to correct domain (95302fd)
*   Add remaining consolidated documentation files (4db9e92)
*   Consolidate agent context into Gemini.md and reorganize repository documentation (0df0d99)
*   Consolidate knowledge assets and enforce clean-root governance policy (d8a3c3e)

### Chore
*   Bump version to 10.0.0 (c9e2fab)
*   Add development environment configs, setup scripts, and minor cleanups (78c38d2)
*   Bump version to 8.1.0 (2452374)
*   Remove deprecated and unused aad_oauth package (ebd52df)
*   Sync remaining protocol, aws, and k8s configuration changes (c0f877e)
*   Finalize sync of all remaining local platform and infrastructure changes [no git] (939bf8d)
*   Push all pending local changes (Android, K8s, Gemini) [no git] (0f10b02)
*   Update Gemini rules, Android gradle wrapper, and Java boilerplate [no git] (bb8fea6)
*   Update Argo CD repository URLs to the correct organization and bootstrap clean sync (acd1f26)
*   Trigger deployment to apply updated auth0 secrets (693ef91)
*   Remove playwright e2e tests and configuration files (b3edfc7)
*   Bump version to 7.18.0 (4ba56e6)
*   Bump version to 7.17.1 (2891002)
*   Bump version to 7.17.0 (63e8389)
*   Bump version to 7.16.3 (9944368)
*   Bump version to 7.16.2 (65294f5)

## [10.0.0] - 2025-12-31
# Changelog

## 10.0.0

### Features
* **auth**: Migrated to Auth0 PKCE stateless JWT pipeline, removing Supabase, resulting in a 50% LOC reduction, fixing mutex races, and adding backend stubs.
* Migrated from Supabase to Auth0 PKCE auth pipeline.
* Updated cloudflared error 1033 SOP v1.5.0 and secure diagnostic script.
* Enhanced Cloudflare API integration for tunnel diagnostics, DNS automation, and implementation plan.

### Bug Fixes
* Fixed ArgoCD cloudflared configuration to use HTTP instead of HTTPS.
* Resolved grep option error in build pipeline.
* Ensured actions/checkout is executed before gh commands in orchestrator.
* Fixed ArgoCD 502 errors by enabling HA deployment, removing insecure mode, fixing Ingress host to cloudtolocalllm.online, and adding TLS configuration.

### Refactoring
* Removed legacy auth providers and fixed test suite.
* Secure refactor of cloudflared diagnostic and repair scripts, updated SOP v1.6.0.

### Documentation
* Finalized cleanup of last remaining stray documentation files.
* Updated Auth0 tenant references to correct domain.
* Added remaining consolidated documentation files.
* Consolidated agent context into Gemini.md and reorganized repository documentation.
* Consolidated knowledge assets and enforce clean-root governance policy.

### Chore
* Removed deprecated and unused aad_oauth package.
* Synced remaining protocol, aws, and k8s configuration changes.
* Finalized sync of all remaining local platform and infrastructure changes.
* Pushed all pending local changes (Android, K8s, Gemini).
* Updated Gemini rules, Android gradle wrapper, and Java boilerplate.
* Updated Argo CD repository URLs to the correct organization and bootstrap clean sync.
* Triggered deployment to apply updated auth0 secrets.
* Removed playwright e2e tests and configuration files.
* Aligned concurrency and use jq for secure secret injection.
* Added development environment configs, setup scripts, and minor cleanups.
* Update stabilization report with comprehensive findings.

## [9.0.0] - 2025-12-31
# Changelog

## 9.0.0 (Unreleased)

### Features
* **auth**: Migrated to Auth0 PKCE stateless JWT pipeline, removing Supabase, resulting in a 50% LOC reduction, fixing mutex races, and adding backend stubs.
* Updated cloudflared error 1033 SOP v1.5.0 and secure diagnostic script.

### Bug Fixes
* Fixed ArgoCD cloudflared configuration to use HTTP instead of HTTPS.
* Fixed ArgoCD 502 errors by enabling HA deployment, removing insecure mode, fixing Ingress host to cloudtolocalllm.online, and adding TLS configuration.
* Resolved grep option error in build pipeline.
* Ensured actions/checkout is executed before gh commands in orchestrator.

### Refactoring
* Removed legacy auth providers and fixed test suite.
* Secure refactor of cloudflared diagnostic and repair scripts, updated SOP v1.6.0.
* Used jq for secure secret injection in deployment pipeline.

### Documentation
* Finalized cleanup of last remaining stray documentation files.
* Updated Auth0 tenant references to correct domain.
* Added remaining consolidated documentation files.
* Consolidated agent context into Gemini.md and reorganized repository documentation.
* Consolidated knowledge assets and enforce clean-root governance policy.

### Chore
* Removed deprecated and unused aad_oauth package.
* Synced remaining protocol, aws, and k8s configuration changes.
* Finalized sync of all remaining local platform and infrastructure changes.
* Pushed all pending local changes (Android, K8s, Gemini).
* Updated Gemini rules, Android gradle wrapper, and Java boilerplate.
* Updated Argo CD repository URLs to the correct organization and bootstrap clean sync.
* Triggered deployment to apply updated auth0 secrets.
* Removed playwright e2e tests and configuration files.
* Added development environment configs, setup scripts, and minor cleanups.
* Aligned concurrency and use jq for secure secret injection.

## [8.1.0] - 2025-12-29
# Changelog

## 8.1.0 (Unreleased)

### Features

*   Enhanced Cloudflare API integration for tunnel diagnostics, DNS automation, and implementation plan.
*   Updated cloudflared error 1033 SOP v1.5.0 and secure diagnostic script.

### Bug Fixes

*   Fix ArgoCD cloudflared configuration to use HTTP instead of HTTPS.
*   Fix ArgoCD 502 errors: enable HA deployment, remove insecure mode, fix Ingress host to cloudtolocalllm.online, add TLS configuration.
*   Resolve ArgoCD 502 gateway and optimize cloudflared stability.
*   Resolve secrets deployment failure and optimize pipeline.
*   Resolve grep option error in build pipeline.
*   Ensure actions/checkout is executed before gh commands in orchestrator.

### Documentation

*   Consolidate agent context into Gemini.md and reorganize repository documentation.
*   Add remaining consolidated documentation files.
*   Consolidate knowledge assets and enforce clean-root governance policy.
*   Finalize cleanup of last remaining stray documentation files.
*   Update Auth0 tenant references to correct domain.

### Refactoring

*   Secure refactor of cloudflared diagnostic and repair scripts, updated SOP v1.6.0.
*   Remove legacy auth providers and fix test suite.
*   Use jq for secure secret injection in deployment pipeline.

### Chore

*   Align concurrency and use jq for secure secret injection.
*   Update Argo CD repository URLs to the correct organization and bootstrap clean sync.
*   Remove deprecated and unused aad_oauth package.
*   Remove playwright e2e tests and configuration files.
*   Sync remaining protocol, aws, and k8s configuration changes.
*   Finalize sync of all remaining local platform and infrastructure changes.
*   Push all pending local changes (Android, K8s, Gemini).
*   Update Gemini rules, Android gradle wrapper, and Java boilerplate.
*   Trigger deployment to apply updated auth0 secrets.
*   Update stabilization report with comprehensive findings.

## [8.0.0] - 2025-12-29
markdown
## Changelog

### Version 8.0.0

#### Features
*   **Cloudflare API Integration:** Enhanced Cloudflare API integration for tunnel diagnostics, DNS automation, and implementation plan.
*   **Cloudflared Error SOP:** Updated cloudflared error 1033 SOP to v1.5.0 and implemented a secure diagnostic script.
*   **Secure Secret Injection:** Added secure secret injection to the deployment pipeline.

#### Bug Fixes
*   **ArgoCD 502 Errors:** Resolved ArgoCD 502 gateway errors and optimized cloudflared stability.
*   **ArgoCD Configuration:** Fixed ArgoCD cloudflared configuration to use HTTP instead of HTTPS.
*   **Build Pipeline Error:** Resolved a grep option error in the build pipeline.
*   **Orchestrator Checkout:** Ensured actions/checkout is executed before gh commands in the orchestrator.
*   **Secrets Deployment Failure:** Resolved secrets deployment failure and optimized the pipeline.

#### Refactoring
*   **Cloudflared Scripts:** Secure refactor of cloudflared diagnostic and repair scripts, updated SOP v1.6.0.
*   **Secure Secret Injection:** Used jq for secure secret injection in the deployment pipeline.

#### Documentation
*   **Documentation Consolidation:** Consolidated knowledge assets and enforced clean-root governance policy.
*   **Agent Context:** Consolidated agent context into Gemini.md and reorganized repository documentation.
*   **Consolidated Documentation:** Added remaining consolidated documentation files.
*   **Stray Documentation Cleanup:** Finalized cleanup of last remaining stray documentation files.
*   **Auth0 Tenant Update:** Updated Auth0 tenant references to the correct domain.

#### Chore
*   **Dependencies:** Bumped versions to 7.14.32, 7.15.0, 7.15.1, 7.15.2, 7.16.0, 7.16.1, 7.16.2, 7.16.3, 7.17.0, 7.17.1, 7.18.0.
*   **Deployment:** Multiple deployment promotions.
*   **Argo CD Repository URLs:** Updated Argo CD repository URLs to the correct organization and bootstrap clean sync.
*   **Auth0 Secrets:** Triggered deployment to apply updated auth0 secrets.
*   **Playwright Tests:** Removed playwright e2e tests and configuration files.
*   **Gemini Rules:** Updated Gemini rules, Android gradle wrapper, and Java boilerplate.
*   **Concurrency Alignment:** Aligned concurrency and use jq for secure secret injection.
*   **Protocol Sync:** Synced remaining protocol, aws, and k8s configuration changes.
*   **Platform Sync:** Finalized sync of all remaining local platform and infrastructure changes.
*   **Pending Changes:** Pushed all pending local changes (Android, K8s, Gemini).
*   **Credentials Sanitization:** Sanitize credentials and refine sync script.
*   **Stabilization Report:** Updated stabilization report with comprehensive findings.
*   **Deprecated Package Removal:** Removed deprecated and unused aad_oauth package.

## [7.18.0] - 2025-12-27
# Changelog

## 7.18.0 (2024-07-03)

### Features
*   Enhanced Cloudflare API integration for tunnel diagnostics, DNS automation, and implementation plan (19cd411)
*   Add secure secret injection to deployment pipeline (fe62dfb)
*   Updated cloudflared error 1033 SOP v1.5.0 and secure diagnostic script (2823e1e)
*   Add script to fix Azure OIDC subject mismatch (b92761b)

### Bug Fixes
*   Fix ArgoCD 502 errors: enable HA deployment, remove insecure mode, fix Ingress host to cloudtolocalllm.online, add TLS configuration (8d30de3)
*   Fix ArgoCD cloudflared configuration to use HTTP instead of HTTPS (61f673c)
*   Resolve grep option error in build pipeline (485f36c)
*   Ensure actions/checkout is executed before gh commands in orchestrator (cd36420)
*   Resolve secrets deployment failure and optimize pipeline (794c576)
*   Resolve ArgoCD 502 gateway and optimize cloudflared stability (7008d0c)
*   Correctly handle optional cloudflare token in validation script (dc2beb1)
*   Make Cloudflare DNS token optional in validation to prevent blocking (925898e)
*   Use standard azure/login@v2 action for authentication (027ae8f)
*   Fetch OIDC token manually for az login (4ae8ea7)
*   Correct az login flags and set subscription separately (22f4771)
*   Replace retry action with shell loop for az login to access OIDC token (578d2b5)
*   Join az login command to single line to fix retry action args (d48c2d5)
*   Fix incorrect action name for retry action (e857d69)

### Refactoring
*   Secure refactor of cloudflared diagnostic and repair scripts, updated SOP v1.6.0 (71f00be)
*   Use jq for secure secret injection in deployment pipeline (52d5cd8)

### Documentation
*   Consolidate knowledge assets and enforce clean-root governance policy (d8a3c3e)

### Chore
*   Bump version to 7.17.1 (2891002)
*   Bump version to 7.17.0 (63e8389)
*   Bump version to 7.16.3 (9944368)
*   Bump version to 7.16.2 (65294f5)
*   Bump version to 7.16.1 (cd171a8)
*   Bump version to 7.16.0 (58b074e)
*   Bump version to 7.15.2 (c0c4fed)
*   Bump version to 7.15.1 (670377e)
*   Bump version to 7.15.0 (29ea52f)
*   Bump version to 7.14.32 (1bf9012)
*   Bump version to 7.14.31 (3053fa7)
*   Bump version to 7.14.30 (ab60407)
*   Bump version to 7.14.29 (6396fa9)
*   Bump version to 7.14.28 (d295a6a)
*   Bump version to 7.14.27 (b7e7a0e)
*   Enforce LF line endings and normalize (59dab96)
*   Align concurrency and use jq for secure secret injection (71a0a9e)
*   Remove validation workflow and add emoji to build pipeline (f70d23c)
*   Exclude dependabot from main orchestrator (9e67bef)
*   Broaden dependabot commit exclusion in main orchestrator (d8f17bf)
*   Sanitize credentials and refine sync script (db3815e)

## [7.17.1] - 2025-12-27
# Changelog

## [7.17.1] - 2024-07-18 (Date is an example)

### Features
- Enhanced Cloudflare API integration for tunnel diagnostics, DNS automation, and implementation plan.
- Added script to fix Azure OIDC subject mismatch.
- Added secure secret injection to deployment pipeline.
- Updated cloudflared error 1033 SOP v1.5.0 and secure diagnostic script.

### Bug Fixes
- Resolved ArgoCD 502 gateway and optimized cloudflared stability.
- Resolved secrets deployment failure and optimized pipeline.
- Correctly handled optional cloudflare token in validation script.
- Made Cloudflare DNS token optional in validation to prevent blocking.
- Used standard azure/login@v2 action for authentication.
- Fetched OIDC token manually for az login.
- Corrected az login flags and set subscription separately.
- Replaced retry action with shell loop for az login to access OIDC token.
- Joined az login command to single line to fix retry action args.
- Migrated build pipeline to standard runners and updated tokens.
- Used GITHUB_TOKEN for checkout to enable push.
- Resolved grep option error in build pipeline.
- Ensured actions/checkout is executed before gh commands in orchestrator.
- Fixed ArgoCD cloudflared configuration to use HTTP instead of HTTPS.
- Fixed ArgoCD 502 errors: enable HA deployment, remove insecure mode, fix Ingress host to cloudtolocalllm.online, add TLS configuration.

### Documentation
- Consolidated knowledge assets and enforce clean-root governance policy.
- Updated stabilization report with comprehensive findings.

### Refactoring
- Used jq for secure secret injection in deployment pipeline.

### Chore
- Aligned concurrency and use jq for secure secret injection.
- Enforced LF line endings and normalize.
- Removed validation workflow and added emoji to build pipeline.
- Fixed incorrect action name for retry action.
- Excluded dependabot from main orchestrator.
- Broadened dependabot commit exclusion in main orchestrator.
- Force refresh build pipeline config.
- Sanitized credentials and refine sync script.

