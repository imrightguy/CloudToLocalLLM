# Changelog

All notable changes to this project will be documented in this file.

## [10.1.150] - 2026-01-19
* fix(cicd): prevent deployment if builds fail (6eb41c69)
* chore: automated version bump to 10.1.149 [skip ci] (f44e4c5f)
* fix(version): resolve dependency corruption caused by unsafe mass replacement (6791eaee)
* chore: automated version bump to 10.1.148 [skip ci] (15753d5c)
* feat(auth/version): comprehensive Auth0 fix and synchronized versioning 10.1.147 (2f73db97)
* chore: automated version bump to 10.1.148 [skip ci] (b0049296)
* chore(version): synchronize all version references to 10.1.147 (67c6bf6a)
* chore(version): synchronize all version references to 10.1.146 (8106c199)
* chore: automated version bump to 10.1.147 [skip ci] (92c648be)
* fix(auth): correct Auth0 integration for proper JWT authentication (e826cd01)
* chore: automated version bump to 10.1.146 [skip ci] (a237698b)
* chore: disable AI Triage workflow automation (50aafaf5)
* chore: automated version bump to 10.1.145 [skip ci] (4159d1f1)
* ai(OpenCode): finalize stabilization - decommission ArgoCD, enable HA scaling, and optimize tunnel routing (5aac5cea)
* ai(fix): test connectivity (971d830b)
* chore: automated version bump to 10.1.144 [skip ci] (ab06ff00)
* fix: resolve bad gateway and api crash by restoring full server.js with robust retry logic (ff7b1af5)
* chore: automated version bump to 10.1.143 [skip ci] (efda28b1)
* fix: resolve bad gateway via comprehensive database retry logic and standardized user context (e66c7ca5)
* chore: automated version bump to 10.1.142 [skip ci] (5ff20d9c)
* fix: resolve bad gateway via network simplfication, server retry logic, and standardized user context (93490949)
* chore: automated version bump to 10.1.141 [skip ci] (a1556ef0)
* fix: resolve bad gateway via server retry logic, simplified dns names, and aligned postgres user (16413b1f)
* chore: automated version bump to 10.1.140 [skip ci] (bb8b9fd7)
* fix: resolve Bad Gateway by standardizing container users (1001), fixing SQL boolean errors, and optimizing DNS aliases (6682e1f9)
* chore: automated version bump to 10.1.139 [skip ci] (746b704c)
* fix: resolve Bad Gateway by adding comprehensive DNS aliases and refining Docker builds (e8a4ef76)
* chore: automated version bump to 10.1.138 [skip ci] (0672b6b5)
* fix: resolve Bad Gateway by fixing duplicate dependencies and lockfile corruption in api-backend (fe11470e)
* fix: resolve api-backend crash by simplifying Dockerfile and ensuring clean dependency installation (4fad826c)
* fix: implement zero-downtime rolling updates and remove mandatory nuclear reset (85e702dc)
* chore: automated version bump to 10.1.137 [skip ci] (f12e7fde)
* fix: resolve bad gateway via DNS aliases and fix api-backend crash via uuid downgrade (202f7151)
* chore: automated version bump to 10.1.136 [skip ci] (a5b72fd0)
* fix: synchronize lockfiles to resolve Docker build failures (65079e8a)
* chore: automated version bump to 10.1.135 [skip ci] (2f139d7f)
* fix: resolve Bad Gateway by fixing uuid dependency, implementing Nuclear Reset deploy strategy, and robust Docker builds (c8eaeb1a)
* chore: automated version bump to 10.1.134 [skip ci] (a4011c7e)
* fix: resolve Bad Gateway by fixing Docker build pollution, aligning ports, and robust healthchecks (317b0e6f)
* chore: automated version bump to 10.1.133 [skip ci] (bc577aff)
* fix: resolve bad gateway by aligning ports, adding swarm healthchecks, and optimizing azure networking MTU (5eb1531f)
* chore: automated version bump to 10.1.132 [skip ci] (d2611370)
* fix: align service ports with Cloudflare expectations (8080) and fix internal proxy routing (e3637efb)
* chore: automated version bump to 10.1.131 [skip ci] (a7c7f6c1)
* fix: robustly pass environment variables via SSH using a safe env file and printf %q (76736f73)
* chore: automated version bump to 10.1.130 [skip ci] (2e5d963c)
* fix: move open-port inside creation block to avoid conflict on existing vm (48c8ef97)
* chore: automated version bump to 10.1.129 [skip ci] (809cc3c1)
* fix: use existing cloudtolocalllm-swarm VM in centralus as requested (ce3d562d)
* chore: automated version bump to 10.1.128 [skip ci] (5de225a3)
* fix: implement low-resource best practices and fix skipping logic for global changes (6a5ded7f)
* fix: stabilize deployment for 4GB VM in westus2 with unique naming and resource limits (0c3583cf)
* chore: automated version bump to 10.1.127 [skip ci] (6eb84ae2)
* fix: relocate to westus2 with unique naming to resolve capacity and resource conflicts (1fe721a7)
* chore: automated version bump to 10.1.126 [skip ci] (b9dd2b64)
* fix: relocate to eastus2 with unique naming to resolve capacity and resource conflicts (273c7aa8)
* chore: automated version bump to 10.1.125 [skip ci] (ac27bdac)
* fix: correctly update vm name to cloudtolocalllm-swarm-eastus to resolve nic collision (9f61f984)
* chore: automated version bump to 10.1.124 [skip ci] (547a9b30)
* fix: rename vm to cloudtolocalllm-swarm-eastus to resolve nic location conflict and update workflow references (3ccfd69b)
* chore: automated version bump to 10.1.123 [skip ci] (3b406b03)
* fix: explicit resource naming to avoid location conflict with centralus resources (e967d39a)
* chore: automated version bump to 10.1.122 [skip ci] (ab392e77)
* fix: deploy Standard_B2s in eastus within centralus RG to resolve capacity and auth issues (3141cfd2)
* chore: automated version bump to 10.1.121 [skip ci] (e1bea9e0)
* fix: use Standard_D2as_v4 Spot Instance to resolve centralus capacity issues while maintaining low cost (dcbd926a)
* chore: automated version bump to 10.1.120 [skip ci] (8ee0e02e)
* fix: downgrade to Standard_B1s due to capacity/policy constraints (3939ad02)
* chore: automated version bump to 10.1.119 [skip ci] (b917fb23)
* fix: revert to centralus RG and use Standard_B1ms with swap to resolve auth/capacity/cost issues (b4fea90f)
* chore: automated version bump to 10.1.118 [skip ci] (177b0b66)
* fix: revert to partial builds with smart retagging to ensure version consistency without rebuilding unchanged components (36acad80)
* chore: automated version bump to 10.1.117 [skip ci] (363b515e)
* fix: relocate to eastus and revert to free-tier Standard_B2s (a41b102a)
* chore: automated version bump to 10.1.116 [skip ci] (72bed6d0)
* fix: upgrade vm size to Standard_B2ms due to capacity limits (2257e7b5)
* chore: automated version bump to 10.1.115 [skip ci] (587e37bf)
* fix: inject derived ssh public key for azure vm provisioning (e9d44e3b)
* chore: automated version bump to 10.1.114 [skip ci] (4b848df2)
* fix: use az vm open-port instead of create argument (85dc694e)
* chore: automated version bump to 10.1.113 [skip ci] (cffc2171)
* fix: remove nsg-rule NONE to allow open-ports configuration (6639f216)
* chore: automated version bump to 10.1.112 [skip ci] (f3836965)
* fix: update azure resource group location to centralus (992c9eba)
* chore: automated version bump to 10.1.111 [skip ci] (c229b8f7)
* fix: update streaming proxy to use node:24-alpine generic image (1f8822f0)
* chore: automated version bump to 10.1.110 [skip ci] (b71372a6)
* fix: stabilize deployment with strict versioning and fixed test scripts (40843d30)
* chore: automated version bump to 10.1.109 [skip ci] (0e565b04)
* fix: add ai_change_analysis to job needs for output access (7c0895fa)
* chore: automated version bump to 10.1.108 [skip ci] (65533558)
* fix: update deployment workflow for docker swarm and fix ghcr image paths (fafc9d0f)
* chore: automated version bump to 10.1.107 [skip ci] (368afa48)
* chore: cleanup old aks config (5cf4e983)
* chore: migrate from aks to docker swarm on azure vm (b6e25923)
* chore: automated version bump to 10.1.106 [skip ci] (d6f05012)
* chore: migrate infrastructure from AWS to Azure (ab4c1876)
* chore: automated version bump to 10.1.105 [skip ci] (570f3a2e)
* fix: ai(OpenCode): update network policies for port 8080 (bcf02d02)
* chore: automated version bump to 10.1.104 [skip ci] (72e284ac)
* fix: ai(OpenCode): update api-backend service target port to 8080 (8ff156b4)
* chore: automated version bump to 10.1.103 [skip ci] (04aece52)
* fix: ai(OpenCode): simplify streaming build (a2916e4e)
* chore: automated version bump to 10.1.102 [skip ci] (1558420a)
* fix: ai(OpenCode): unblock deployment (18526ee2)
* chore: automated version bump to 10.1.101 [skip ci] (32c03d6c)
* chore: ai(OpenCode): reduce aws footprint (5612ef7d)
* chore: automated version bump to 10.1.100 [skip ci] (c901c2e4)
* fix: inject cloudtolocalllm-secrets into cluster from github secrets (cb152ba5)
* chore: automated version bump to 10.1.99 [skip ci] (45561dc9)
* fix: increase postgres rollout timeout to 10m to handle image pull time (29e3d438)
* chore: automated version bump to 10.1.98 [skip ci] (074020fe)
* refactor: build flutter web in runner and use lightweight nginx image (00b11d1e)
* chore: automated version bump to 10.1.97 [skip ci] (97f408cd)
* fix: include rbac.yaml in managed overlay to create required service accounts (ea6802cd)
* chore: automated version bump to 10.1.96 [skip ci] (975efcb4)
* fix: aggressive pod cleanup and enhanced debugging for postgres failure (88d8d7e6)
* chore: automated version bump to 10.1.95 [skip ci] (4bdb15bb)
* fix: fail workflow immediately if postgres rollout fails (c3178870)
* chore: automated version bump to 10.1.94 [skip ci] (867c0192)
* fix: kill zombie postgres-auth and disable rollback for debugging (b85224be)
* chore: automated version bump to 10.1.93 [skip ci] (ea4cf7f1)
* fix: switch redis to emptyDir storage for free tier stability (07a35f7f)
* chore: automated version bump to 10.1.92 [skip ci] (30f97204)
* fix: consolidate postgres instances to reduce pod count and use emptyDir for stability (29e0e4f6)
* chore: automated version bump to 10.1.91 [skip ci] (b217b2a9)
* chore: enforce single replica for all services in scaling patch (ae3fa695)
* chore: automated version bump to 10.1.90 [skip ci] (95d887af)
* fix: optimize resource usage to fit free tier limits (11 pods max) (576030cc)
* chore: automated version bump to 10.1.89 [skip ci] (185c86f6)
* fix: delete StatefulSets before applying PVC size changes (be02ab10)
* chore: automated version bump to 10.1.88 [skip ci] (1e77ead2)
* fix(infra): drastically reduce PVC sizes to 1Gi and force statefulset recreation during deploy (c1a11dd3)
* chore: automated version bump to 10.1.87 [skip ci] (5aa02486)
* fix(ci): rename workflow to deployment and remove desktop app builds (bd2d7833)
* fix(ci): add manual force build flag and bypass cache check when enabled (9eeecd61)
* fix(ci): force rebuild of all components when infrastructure changes (48071e5c)
* fix(ci): remove hard reset step as per requirement (1a04e980)
* chore: automated version bump to 10.1.86 [skip ci] (6235a087)
* fix(ci): wait for all deployments to be ready before verifying tunnel (6ec2fdd6)
* chore: automated version bump to 10.1.85 [skip ci] (d73744fb)
* fix(ci): refactor deployment to use direct GH Action logic and ensure hard reset (091dbdc5)
* chore: automated version bump to 10.1.84 [skip ci] (6e9e9d81)
* fix(k8s): disable heavy monitoring stack in base to prevent resource exhaustion (5df21292)
* chore: automated version bump to 10.1.83 [skip ci] (edb6e8b3)
* fix(ops): enhance hard reset to handle stuck namespaces (490b92f0)
* chore: automated version bump to 10.1.82 [skip ci] (6e5adc6a)
* fix(k8s): explicitly list resources to exclude heavy monitoring stack (7ce0bbcb)
* chore: automated version bump to 10.1.81 [skip ci] (ee641639)
* fix(k8s): define postgres storage pvc properly and patch managed resource requests (49a87fae)
* chore: automated version bump to 10.1.80 [skip ci] (e2d9d14d)
* fix(ops): add hard reset capability to nuke and rebuild namespace (9b896c33)
* chore: automated version bump to 10.1.79 [skip ci] (cdbc3295)
* fix(deploy): force cleanup of stuck pods and debug nodes (7288a632)
* chore: automated version bump to 10.1.78 [skip ci] (687ff096)
* fix(infra): drastically reduce resource requests to fit free tier limits (43ecc49a)
* chore: automated version bump to 10.1.77 [skip ci] (55d98e4d)
* fix(ci): add cluster debugging and stricter health checks (783b75b8)
* chore: automated version bump to 10.1.76 [skip ci] (cef4e723)
* fix(k8s): allow ingress/egress for cloudflared and web init to reach service port 8080 (471e4a30)
* chore: automated version bump to 10.1.75 [skip ci] (3e48953b)
* fix(k8s): allow cloudflared ingress in network policies and fix egress port (e1b3b79f)
* chore: automated version bump to 10.1.74 [skip ci] (8e44fdf8)
* fix(k8s): update api-backend service targetPort to 3000 (74b15973)
* chore: automated version bump to 10.1.73 [skip ci] (27292802)
* fix(web): configure nginx for non-root execution to resolve 502 (725774eb)
* chore: automated version bump to 10.1.72 [skip ci] (8fb41e44)
* fix(infra): update tunnel port and switch to ghcr images (7a0ddf34)
* chore: automated version bump to 10.1.71 [skip ci] (91d1d2c7)
* ai(OpenCode): implement core clean and fix postgres host in init (607a5b97)
* chore: automated version bump to 10.1.70 [skip ci] (ff06a1d9)
* ai(OpenCode): check secrets in get-logs.yml (7d34f46e)
* chore: automated version bump to 10.1.69 [skip ci] (d0af5dde)
* ai(OpenCode): optimize resources and implement nuclear pruning (85a24723)
* chore: automated version bump to 10.1.68 [skip ci] (0514a24b)
* ai(OpenCode): scale down and reduce resource requests for managed overlay (3ec1f06d)
* chore: automated version bump to 10.1.67 [skip ci] (317b1eda)
* ai(OpenCode): add checkout and preserve secrets in nuclear reset (70556773)
* chore: automated version bump to 10.1.66 [skip ci] (76e5251f)
* ai(OpenCode): implement nuclear reset in fix-backend.yml (4e3096ba)
* chore: automated version bump to 10.1.65 [skip ci] (5b50689a)
* ai(OpenCode): get more resource detail in get-logs.yml (6cb3ca70)
* chore: automated version bump to 10.1.64 [skip ci] (b174b0d8)
* ai(OpenCode): list all resources in get-logs.yml (1dd581fc)
* ai(OpenCode): standardize image placeholders in base manifests (2d743d23)
* ai(OpenCode): describe pods in get-logs.yml (ab60d0e4)
* chore: automated version bump to 10.1.63 [skip ci] (6f0e2952)
* ai(OpenCode): update fix-backend.yml to terminate all pods (2f2af3b3)
* ai(OpenCode): fetch api-backend logs in get-logs.yml (19605bf9)
* ai(OpenCode): check nodes in get-logs.yml (be900066)
* chore: automated version bump to 10.1.62 [skip ci] (8f77a35b)
* ai(OpenCode): list all pods in get-logs.yml (68c8961f)
* chore: automated version bump to 10.1.61 [skip ci] (12232559)
* ai(OpenCode): force http2 protocol for cloudflared (7189a471)
* ai(OpenCode): fix permissions in get-logs.yml (87a370cb)
* ai(OpenCode): add workflow to fetch tunnel logs (f7299f30)
* chore: automated version bump to 10.1.60 [skip ci] (316a189a)
* ai(OpenCode): revert Tunnel ID to 62da6c19-947b-4bf6-acad-100a73de4e0d and update token (e10cff96)
* chore: automated version bump to 10.1.59 [skip ci] (bf148ce4)
* ai(OpenCode): update fix-tunnel-credentials.sh to apply ConfigMap (a5c1448c)
* chore: automated version bump to 10.1.58 [skip ci] (48d24b02)
* ai(OpenCode): synchronize Cloudflare Tunnel ID to ee26f195-904b-4406-a8ae-9265c9971004 (bf67498a)
* chore: remove all documentation archives (7846370d)
* docs: refactor documentation to AWS/Auth0 and remove deprecated tech (eb600d52)
* chore: remove backup data (d39a78df)
* chore: clean repo artifacts (04a5f11d)
* chore: remove cursor rules (416d5094)
* chore: automated version bump to 10.1.57 [skip ci] (74af8d18)
* ai(Cursor): check GHCR tags before builds (0c79b524)
* fix(k8s): enforce string type for cloudflared config annotation (9cad70c1)
* chore: automated version bump to 10.1.56 [skip ci] (c79ee83b)
* chore(ci): temporarily disable desktop builds and release job (fbf54896)
* refactor(docker): enforce usage of custom base image for all services (b11edfca)
* chore: automated version bump to 10.1.55 [skip ci] (e66f2c5e)
* chore(ci): apply conditional build logic to all containers (cfc15f17)
* chore(ci): optimize build_base to run only on base changes (c12f8019)
* chore: automated version bump to 10.1.54 [skip ci] (2f67ace2)
* refactor(ci): scope release job to desktop builds (5debacb5)

## [10.1.149] - 2026-01-19
* fix(version): resolve dependency corruption caused by unsafe mass replacement (6791eaee)
* chore: automated version bump to 10.1.148 [skip ci] (15753d5c)
* feat(auth/version): comprehensive Auth0 fix and synchronized versioning 10.1.147 (2f73db97)
* chore: automated version bump to 10.1.148 [skip ci] (b0049296)
* chore(version): synchronize all version references to 10.1.147 (67c6bf6a)
* chore(version): synchronize all version references to 10.1.146 (8106c199)
* chore: automated version bump to 10.1.147 [skip ci] (92c648be)
* fix(auth): correct Auth0 integration for proper JWT authentication (e826cd01)
* chore: automated version bump to 10.1.146 [skip ci] (a237698b)
* chore: disable AI Triage workflow automation (50aafaf5)
* chore: automated version bump to 10.1.145 [skip ci] (4159d1f1)
* ai(OpenCode): finalize stabilization - decommission ArgoCD, enable HA scaling, and optimize tunnel routing (5aac5cea)
* ai(fix): test connectivity (971d830b)
* chore: automated version bump to 10.1.144 [skip ci] (ab06ff00)
* fix: resolve bad gateway and api crash by restoring full server.js with robust retry logic (ff7b1af5)
* chore: automated version bump to 10.1.143 [skip ci] (efda28b1)
* fix: resolve bad gateway via comprehensive database retry logic and standardized user context (e66c7ca5)
* chore: automated version bump to 10.1.142 [skip ci] (5ff20d9c)
* fix: resolve bad gateway via network simplfication, server retry logic, and standardized user context (93490949)
* chore: automated version bump to 10.1.141 [skip ci] (a1556ef0)
* fix: resolve bad gateway via server retry logic, simplified dns names, and aligned postgres user (16413b1f)
* chore: automated version bump to 10.1.140 [skip ci] (bb8b9fd7)
* fix: resolve Bad Gateway by standardizing container users (1001), fixing SQL boolean errors, and optimizing DNS aliases (6682e1f9)
* chore: automated version bump to 10.1.139 [skip ci] (746b704c)
* fix: resolve Bad Gateway by adding comprehensive DNS aliases and refining Docker builds (e8a4ef76)
* chore: automated version bump to 10.1.138 [skip ci] (0672b6b5)
* fix: resolve Bad Gateway by fixing duplicate dependencies and lockfile corruption in api-backend (fe11470e)
* fix: resolve api-backend crash by simplifying Dockerfile and ensuring clean dependency installation (4fad826c)
* fix: implement zero-downtime rolling updates and remove mandatory nuclear reset (85e702dc)
* chore: automated version bump to 10.1.137 [skip ci] (f12e7fde)
* fix: resolve bad gateway via DNS aliases and fix api-backend crash via uuid downgrade (202f7151)
* chore: automated version bump to 10.1.136 [skip ci] (a5b72fd0)
* fix: synchronize lockfiles to resolve Docker build failures (65079e8a)
* chore: automated version bump to 10.1.135 [skip ci] (2f139d7f)
* fix: resolve Bad Gateway by fixing uuid dependency, implementing Nuclear Reset deploy strategy, and robust Docker builds (c8eaeb1a)
* chore: automated version bump to 10.1.134 [skip ci] (a4011c7e)
* fix: resolve Bad Gateway by fixing Docker build pollution, aligning ports, and robust healthchecks (317b0e6f)
* chore: automated version bump to 10.1.133 [skip ci] (bc577aff)
* fix: resolve bad gateway by aligning ports, adding swarm healthchecks, and optimizing azure networking MTU (5eb1531f)
* chore: automated version bump to 10.1.132 [skip ci] (d2611370)
* fix: align service ports with Cloudflare expectations (8080) and fix internal proxy routing (e3637efb)
* chore: automated version bump to 10.1.131 [skip ci] (a7c7f6c1)
* fix: robustly pass environment variables via SSH using a safe env file and printf %q (76736f73)
* chore: automated version bump to 10.1.130 [skip ci] (2e5d963c)
* fix: move open-port inside creation block to avoid conflict on existing vm (48c8ef97)
* chore: automated version bump to 10.1.129 [skip ci] (809cc3c1)
* fix: use existing cloudtolocalllm-swarm VM in centralus as requested (ce3d562d)
* chore: automated version bump to 10.1.128 [skip ci] (5de225a3)
* fix: implement low-resource best practices and fix skipping logic for global changes (6a5ded7f)
* fix: stabilize deployment for 4GB VM in westus2 with unique naming and resource limits (0c3583cf)
* chore: automated version bump to 10.1.127 [skip ci] (6eb84ae2)
* fix: relocate to westus2 with unique naming to resolve capacity and resource conflicts (1fe721a7)
* chore: automated version bump to 10.1.126 [skip ci] (b9dd2b64)
* fix: relocate to eastus2 with unique naming to resolve capacity and resource conflicts (273c7aa8)
* chore: automated version bump to 10.1.125 [skip ci] (ac27bdac)
* fix: correctly update vm name to cloudtolocalllm-swarm-eastus to resolve nic collision (9f61f984)
* chore: automated version bump to 10.1.124 [skip ci] (547a9b30)
* fix: rename vm to cloudtolocalllm-swarm-eastus to resolve nic location conflict and update workflow references (3ccfd69b)
* chore: automated version bump to 10.1.123 [skip ci] (3b406b03)
* fix: explicit resource naming to avoid location conflict with centralus resources (e967d39a)
* chore: automated version bump to 10.1.122 [skip ci] (ab392e77)
* fix: deploy Standard_B2s in eastus within centralus RG to resolve capacity and auth issues (3141cfd2)
* chore: automated version bump to 10.1.121 [skip ci] (e1bea9e0)
* fix: use Standard_D2as_v4 Spot Instance to resolve centralus capacity issues while maintaining low cost (dcbd926a)
* chore: automated version bump to 10.1.120 [skip ci] (8ee0e02e)
* fix: downgrade to Standard_B1s due to capacity/policy constraints (3939ad02)
* chore: automated version bump to 10.1.119 [skip ci] (b917fb23)
* fix: revert to centralus RG and use Standard_B1ms with swap to resolve auth/capacity/cost issues (b4fea90f)
* chore: automated version bump to 10.1.118 [skip ci] (177b0b66)
* fix: revert to partial builds with smart retagging to ensure version consistency without rebuilding unchanged components (36acad80)
* chore: automated version bump to 10.1.117 [skip ci] (363b515e)
* fix: relocate to eastus and revert to free-tier Standard_B2s (a41b102a)
* chore: automated version bump to 10.1.116 [skip ci] (72bed6d0)
* fix: upgrade vm size to Standard_B2ms due to capacity limits (2257e7b5)
* chore: automated version bump to 10.1.115 [skip ci] (587e37bf)
* fix: inject derived ssh public key for azure vm provisioning (e9d44e3b)
* chore: automated version bump to 10.1.114 [skip ci] (4b848df2)
* fix: use az vm open-port instead of create argument (85dc694e)
* chore: automated version bump to 10.1.113 [skip ci] (cffc2171)
* fix: remove nsg-rule NONE to allow open-ports configuration (6639f216)
* chore: automated version bump to 10.1.112 [skip ci] (f3836965)
* fix: update azure resource group location to centralus (992c9eba)
* chore: automated version bump to 10.1.111 [skip ci] (c229b8f7)
* fix: update streaming proxy to use node:24-alpine generic image (1f8822f0)
* chore: automated version bump to 10.1.110 [skip ci] (b71372a6)
* fix: stabilize deployment with strict versioning and fixed test scripts (40843d30)
* chore: automated version bump to 10.1.109 [skip ci] (0e565b04)
* fix: add ai_change_analysis to job needs for output access (7c0895fa)
* chore: automated version bump to 10.1.108 [skip ci] (65533558)
* fix: update deployment workflow for docker swarm and fix ghcr image paths (fafc9d0f)
* chore: automated version bump to 10.1.107 [skip ci] (368afa48)
* chore: cleanup old aks config (5cf4e983)
* chore: migrate from aks to docker swarm on azure vm (b6e25923)
* chore: automated version bump to 10.1.106 [skip ci] (d6f05012)
* chore: migrate infrastructure from AWS to Azure (ab4c1876)
* chore: automated version bump to 10.1.105 [skip ci] (570f3a2e)
* fix: ai(OpenCode): update network policies for port 8080 (bcf02d02)
* chore: automated version bump to 10.1.104 [skip ci] (72e284ac)
* fix: ai(OpenCode): update api-backend service target port to 8080 (8ff156b4)
* chore: automated version bump to 10.1.103 [skip ci] (04aece52)
* fix: ai(OpenCode): simplify streaming build (a2916e4e)
* chore: automated version bump to 10.1.102 [skip ci] (1558420a)
* fix: ai(OpenCode): unblock deployment (18526ee2)
* chore: automated version bump to 10.1.101 [skip ci] (32c03d6c)
* chore: ai(OpenCode): reduce aws footprint (5612ef7d)
* chore: automated version bump to 10.1.100 [skip ci] (c901c2e4)
* fix: inject cloudtolocalllm-secrets into cluster from github secrets (cb152ba5)
* chore: automated version bump to 10.1.99 [skip ci] (45561dc9)
* fix: increase postgres rollout timeout to 10m to handle image pull time (29e3d438)
* chore: automated version bump to 10.1.98 [skip ci] (074020fe)
* refactor: build flutter web in runner and use lightweight nginx image (00b11d1e)
* chore: automated version bump to 10.1.97 [skip ci] (97f408cd)
* fix: include rbac.yaml in managed overlay to create required service accounts (ea6802cd)
* chore: automated version bump to 10.1.96 [skip ci] (975efcb4)
* fix: aggressive pod cleanup and enhanced debugging for postgres failure (88d8d7e6)
* chore: automated version bump to 10.1.95 [skip ci] (4bdb15bb)
* fix: fail workflow immediately if postgres rollout fails (c3178870)
* chore: automated version bump to 10.1.94 [skip ci] (867c0192)
* fix: kill zombie postgres-auth and disable rollback for debugging (b85224be)
* chore: automated version bump to 10.1.93 [skip ci] (ea4cf7f1)
* fix: switch redis to emptyDir storage for free tier stability (07a35f7f)
* chore: automated version bump to 10.1.92 [skip ci] (30f97204)
* fix: consolidate postgres instances to reduce pod count and use emptyDir for stability (29e0e4f6)
* chore: automated version bump to 10.1.91 [skip ci] (b217b2a9)
* chore: enforce single replica for all services in scaling patch (ae3fa695)
* chore: automated version bump to 10.1.90 [skip ci] (95d887af)
* fix: optimize resource usage to fit free tier limits (11 pods max) (576030cc)
* chore: automated version bump to 10.1.89 [skip ci] (185c86f6)
* fix: delete StatefulSets before applying PVC size changes (be02ab10)
* chore: automated version bump to 10.1.88 [skip ci] (1e77ead2)
* fix(infra): drastically reduce PVC sizes to 1Gi and force statefulset recreation during deploy (c1a11dd3)
* chore: automated version bump to 10.1.87 [skip ci] (5aa02486)
* fix(ci): rename workflow to deployment and remove desktop app builds (bd2d7833)
* fix(ci): add manual force build flag and bypass cache check when enabled (9eeecd61)
* fix(ci): force rebuild of all components when infrastructure changes (48071e5c)
* fix(ci): remove hard reset step as per requirement (1a04e980)
* chore: automated version bump to 10.1.86 [skip ci] (6235a087)
* fix(ci): wait for all deployments to be ready before verifying tunnel (6ec2fdd6)
* chore: automated version bump to 10.1.85 [skip ci] (d73744fb)
* fix(ci): refactor deployment to use direct GH Action logic and ensure hard reset (091dbdc5)
* chore: automated version bump to 10.1.84 [skip ci] (6e9e9d81)
* fix(k8s): disable heavy monitoring stack in base to prevent resource exhaustion (5df21292)
* chore: automated version bump to 10.1.83 [skip ci] (edb6e8b3)
* fix(ops): enhance hard reset to handle stuck namespaces (490b92f0)
* chore: automated version bump to 10.1.82 [skip ci] (6e5adc6a)
* fix(k8s): explicitly list resources to exclude heavy monitoring stack (7ce0bbcb)
* chore: automated version bump to 10.1.81 [skip ci] (ee641639)
* fix(k8s): define postgres storage pvc properly and patch managed resource requests (49a87fae)
* chore: automated version bump to 10.1.80 [skip ci] (e2d9d14d)
* fix(ops): add hard reset capability to nuke and rebuild namespace (9b896c33)
* chore: automated version bump to 10.1.79 [skip ci] (cdbc3295)
* fix(deploy): force cleanup of stuck pods and debug nodes (7288a632)
* chore: automated version bump to 10.1.78 [skip ci] (687ff096)
* fix(infra): drastically reduce resource requests to fit free tier limits (43ecc49a)
* chore: automated version bump to 10.1.77 [skip ci] (55d98e4d)
* fix(ci): add cluster debugging and stricter health checks (783b75b8)
* chore: automated version bump to 10.1.76 [skip ci] (cef4e723)
* fix(k8s): allow ingress/egress for cloudflared and web init to reach service port 8080 (471e4a30)
* chore: automated version bump to 10.1.75 [skip ci] (3e48953b)
* fix(k8s): allow cloudflared ingress in network policies and fix egress port (e1b3b79f)
* chore: automated version bump to 10.1.74 [skip ci] (8e44fdf8)
* fix(k8s): update api-backend service targetPort to 3000 (74b15973)
* chore: automated version bump to 10.1.73 [skip ci] (27292802)
* fix(web): configure nginx for non-root execution to resolve 502 (725774eb)
* chore: automated version bump to 10.1.72 [skip ci] (8fb41e44)
* fix(infra): update tunnel port and switch to ghcr images (7a0ddf34)
* chore: automated version bump to 10.1.71 [skip ci] (91d1d2c7)
* ai(OpenCode): implement core clean and fix postgres host in init (607a5b97)
* chore: automated version bump to 10.1.70 [skip ci] (ff06a1d9)
* ai(OpenCode): check secrets in get-logs.yml (7d34f46e)
* chore: automated version bump to 10.1.69 [skip ci] (d0af5dde)
* ai(OpenCode): optimize resources and implement nuclear pruning (85a24723)
* chore: automated version bump to 10.1.68 [skip ci] (0514a24b)
* ai(OpenCode): scale down and reduce resource requests for managed overlay (3ec1f06d)
* chore: automated version bump to 10.1.67 [skip ci] (317b1eda)
* ai(OpenCode): add checkout and preserve secrets in nuclear reset (70556773)
* chore: automated version bump to 10.1.66 [skip ci] (76e5251f)
* ai(OpenCode): implement nuclear reset in fix-backend.yml (4e3096ba)
* chore: automated version bump to 10.1.65 [skip ci] (5b50689a)
* ai(OpenCode): get more resource detail in get-logs.yml (6cb3ca70)
* chore: automated version bump to 10.1.64 [skip ci] (b174b0d8)
* ai(OpenCode): list all resources in get-logs.yml (1dd581fc)
* ai(OpenCode): standardize image placeholders in base manifests (2d743d23)
* ai(OpenCode): describe pods in get-logs.yml (ab60d0e4)
* chore: automated version bump to 10.1.63 [skip ci] (6f0e2952)
* ai(OpenCode): update fix-backend.yml to terminate all pods (2f2af3b3)
* ai(OpenCode): fetch api-backend logs in get-logs.yml (19605bf9)
* ai(OpenCode): check nodes in get-logs.yml (be900066)
* chore: automated version bump to 10.1.62 [skip ci] (8f77a35b)
* ai(OpenCode): list all pods in get-logs.yml (68c8961f)
* chore: automated version bump to 10.1.61 [skip ci] (12232559)
* ai(OpenCode): force http2 protocol for cloudflared (7189a471)
* ai(OpenCode): fix permissions in get-logs.yml (87a370cb)
* ai(OpenCode): add workflow to fetch tunnel logs (f7299f30)
* chore: automated version bump to 10.1.60 [skip ci] (316a189a)
* ai(OpenCode): revert Tunnel ID to 62da6c19-947b-4bf6-acad-100a73de4e0d and update token (e10cff96)
* chore: automated version bump to 10.1.59 [skip ci] (bf148ce4)
* ai(OpenCode): update fix-tunnel-credentials.sh to apply ConfigMap (a5c1448c)
* chore: automated version bump to 10.1.58 [skip ci] (48d24b02)
* ai(OpenCode): synchronize Cloudflare Tunnel ID to ee26f195-904b-4406-a8ae-9265c9971004 (bf67498a)
* chore: remove all documentation archives (7846370d)
* docs: refactor documentation to AWS/Auth0 and remove deprecated tech (eb600d52)
* chore: remove backup data (d39a78df)
* chore: clean repo artifacts (04a5f11d)
* chore: remove cursor rules (416d5094)
* chore: automated version bump to 10.1.57 [skip ci] (74af8d18)
* ai(Cursor): check GHCR tags before builds (0c79b524)
* fix(k8s): enforce string type for cloudflared config annotation (9cad70c1)
* chore: automated version bump to 10.1.56 [skip ci] (c79ee83b)
* chore(ci): temporarily disable desktop builds and release job (fbf54896)
* refactor(docker): enforce usage of custom base image for all services (b11edfca)
* chore: automated version bump to 10.1.55 [skip ci] (e66f2c5e)
* chore(ci): apply conditional build logic to all containers (cfc15f17)
* chore(ci): optimize build_base to run only on base changes (c12f8019)
* chore: automated version bump to 10.1.54 [skip ci] (2f67ace2)
* refactor(ci): scope release job to desktop builds (5debacb5)

## [10.1.148] - 2026-01-19
* feat(auth/version): comprehensive Auth0 fix and synchronized versioning 10.1.147 (2f73db97)
* chore: automated version bump to 10.1.148 [skip ci] (b0049296)
* chore(version): synchronize all version references to 10.1.147 (67c6bf6a)
* chore(version): synchronize all version references to 10.1.146 (8106c199)
* chore: automated version bump to 10.1.147 [skip ci] (92c648be)
* fix(auth): correct Auth0 integration for proper JWT authentication (e826cd01)
* chore: automated version bump to 10.1.146 [skip ci] (a237698b)
* chore: disable AI Triage workflow automation (50aafaf5)
* chore: automated version bump to 10.1.145 [skip ci] (4159d1f1)
* ai(OpenCode): finalize stabilization - decommission ArgoCD, enable HA scaling, and optimize tunnel routing (5aac5cea)
* ai(fix): test connectivity (971d830b)
* chore: automated version bump to 10.1.144 [skip ci] (ab06ff00)
* fix: resolve bad gateway and api crash by restoring full server.js with robust retry logic (ff7b1af5)
* chore: automated version bump to 10.1.143 [skip ci] (efda28b1)
* fix: resolve bad gateway via comprehensive database retry logic and standardized user context (e66c7ca5)
* chore: automated version bump to 10.1.142 [skip ci] (5ff20d9c)
* fix: resolve bad gateway via network simplfication, server retry logic, and standardized user context (93490949)
* chore: automated version bump to 10.1.141 [skip ci] (a1556ef0)
* fix: resolve bad gateway via server retry logic, simplified dns names, and aligned postgres user (16413b1f)
* chore: automated version bump to 10.1.140 [skip ci] (bb8b9fd7)
* fix: resolve Bad Gateway by standardizing container users (1001), fixing SQL boolean errors, and optimizing DNS aliases (6682e1f9)
* chore: automated version bump to 10.1.139 [skip ci] (746b704c)
* fix: resolve Bad Gateway by adding comprehensive DNS aliases and refining Docker builds (e8a4ef76)
* chore: automated version bump to 10.1.138 [skip ci] (0672b6b5)
* fix: resolve Bad Gateway by fixing duplicate dependencies and lockfile corruption in api-backend (fe11470e)
* fix: resolve api-backend crash by simplifying Dockerfile and ensuring clean dependency installation (4fad826c)
* fix: implement zero-downtime rolling updates and remove mandatory nuclear reset (85e702dc)
* chore: automated version bump to 10.1.137 [skip ci] (f12e7fde)
* fix: resolve bad gateway via DNS aliases and fix api-backend crash via uuid downgrade (202f7151)
* chore: automated version bump to 10.1.136 [skip ci] (a5b72fd0)
* fix: synchronize lockfiles to resolve Docker build failures (65079e8a)
* chore: automated version bump to 10.1.135 [skip ci] (2f139d7f)
* fix: resolve Bad Gateway by fixing uuid dependency, implementing Nuclear Reset deploy strategy, and robust Docker builds (c8eaeb1a)
* chore: automated version bump to 10.1.134 [skip ci] (a4011c7e)
* fix: resolve Bad Gateway by fixing Docker build pollution, aligning ports, and robust healthchecks (317b0e6f)
* chore: automated version bump to 10.1.133 [skip ci] (bc577aff)
* fix: resolve bad gateway by aligning ports, adding swarm healthchecks, and optimizing azure networking MTU (5eb1531f)
* chore: automated version bump to 10.1.132 [skip ci] (d2611370)
* fix: align service ports with Cloudflare expectations (8080) and fix internal proxy routing (e3637efb)
* chore: automated version bump to 10.1.131 [skip ci] (a7c7f6c1)
* fix: robustly pass environment variables via SSH using a safe env file and printf %q (76736f73)
* chore: automated version bump to 10.1.130 [skip ci] (2e5d963c)
* fix: move open-port inside creation block to avoid conflict on existing vm (48c8ef97)
* chore: automated version bump to 10.1.129 [skip ci] (809cc3c1)
* fix: use existing cloudtolocalllm-swarm VM in centralus as requested (ce3d562d)
* chore: automated version bump to 10.1.128 [skip ci] (5de225a3)
* fix: implement low-resource best practices and fix skipping logic for global changes (6a5ded7f)
* fix: stabilize deployment for 4GB VM in westus2 with unique naming and resource limits (0c3583cf)
* chore: automated version bump to 10.1.127 [skip ci] (6eb84ae2)
* fix: relocate to westus2 with unique naming to resolve capacity and resource conflicts (1fe721a7)
* chore: automated version bump to 10.1.126 [skip ci] (b9dd2b64)
* fix: relocate to eastus2 with unique naming to resolve capacity and resource conflicts (273c7aa8)
* chore: automated version bump to 10.1.125 [skip ci] (ac27bdac)
* fix: correctly update vm name to cloudtolocalllm-swarm-eastus to resolve nic collision (9f61f984)
* chore: automated version bump to 10.1.124 [skip ci] (547a9b30)
* fix: rename vm to cloudtolocalllm-swarm-eastus to resolve nic location conflict and update workflow references (3ccfd69b)
* chore: automated version bump to 10.1.123 [skip ci] (3b406b03)
* fix: explicit resource naming to avoid location conflict with centralus resources (e967d39a)
* chore: automated version bump to 10.1.122 [skip ci] (ab392e77)
* fix: deploy Standard_B2s in eastus within centralus RG to resolve capacity and auth issues (3141cfd2)
* chore: automated version bump to 10.1.121 [skip ci] (e1bea9e0)
* fix: use Standard_D2as_v4 Spot Instance to resolve centralus capacity issues while maintaining low cost (dcbd926a)
* chore: automated version bump to 10.1.120 [skip ci] (8ee0e02e)
* fix: downgrade to Standard_B1s due to capacity/policy constraints (3939ad02)
* chore: automated version bump to 10.1.119 [skip ci] (b917fb23)
* fix: revert to centralus RG and use Standard_B1ms with swap to resolve auth/capacity/cost issues (b4fea90f)
* chore: automated version bump to 10.1.118 [skip ci] (177b0b66)
* fix: revert to partial builds with smart retagging to ensure version consistency without rebuilding unchanged components (36acad80)
* chore: automated version bump to 10.1.117 [skip ci] (363b515e)
* fix: relocate to eastus and revert to free-tier Standard_B2s (a41b102a)
* chore: automated version bump to 10.1.116 [skip ci] (72bed6d0)
* fix: upgrade vm size to Standard_B2ms due to capacity limits (2257e7b5)
* chore: automated version bump to 10.1.115 [skip ci] (587e37bf)
* fix: inject derived ssh public key for azure vm provisioning (e9d44e3b)
* chore: automated version bump to 10.1.114 [skip ci] (4b848df2)
* fix: use az vm open-port instead of create argument (85dc694e)
* chore: automated version bump to 10.1.113 [skip ci] (cffc2171)
* fix: remove nsg-rule NONE to allow open-ports configuration (6639f216)
* chore: automated version bump to 10.1.112 [skip ci] (f3836965)
* fix: update azure resource group location to centralus (992c9eba)
* chore: automated version bump to 10.1.111 [skip ci] (c229b8f7)
* fix: update streaming proxy to use node:24-alpine generic image (1f8822f0)
* chore: automated version bump to 10.1.110 [skip ci] (b71372a6)
* fix: stabilize deployment with strict versioning and fixed test scripts (40843d30)
* chore: automated version bump to 10.1.109 [skip ci] (0e565b04)
* fix: add ai_change_analysis to job needs for output access (7c0895fa)
* chore: automated version bump to 10.1.108 [skip ci] (65533558)
* fix: update deployment workflow for docker swarm and fix ghcr image paths (fafc9d0f)
* chore: automated version bump to 10.1.107 [skip ci] (368afa48)
* chore: cleanup old aks config (5cf4e983)
* chore: migrate from aks to docker swarm on azure vm (b6e25923)
* chore: automated version bump to 10.1.106 [skip ci] (d6f05012)
* chore: migrate infrastructure from AWS to Azure (ab4c1876)
* chore: automated version bump to 10.1.105 [skip ci] (570f3a2e)
* fix: ai(OpenCode): update network policies for port 8080 (bcf02d02)
* chore: automated version bump to 10.1.104 [skip ci] (72e284ac)
* fix: ai(OpenCode): update api-backend service target port to 8080 (8ff156b4)
* chore: automated version bump to 10.1.103 [skip ci] (04aece52)
* fix: ai(OpenCode): simplify streaming build (a2916e4e)
* chore: automated version bump to 10.1.102 [skip ci] (1558420a)
* fix: ai(OpenCode): unblock deployment (18526ee2)
* chore: automated version bump to 10.1.101 [skip ci] (32c03d6c)
* chore: ai(OpenCode): reduce aws footprint (5612ef7d)
* chore: automated version bump to 10.1.100 [skip ci] (c901c2e4)
* fix: inject cloudtolocalllm-secrets into cluster from github secrets (cb152ba5)
* chore: automated version bump to 10.1.99 [skip ci] (45561dc9)
* fix: increase postgres rollout timeout to 10m to handle image pull time (29e3d438)
* chore: automated version bump to 10.1.98 [skip ci] (074020fe)
* refactor: build flutter web in runner and use lightweight nginx image (00b11d1e)
* chore: automated version bump to 10.1.97 [skip ci] (97f408cd)
* fix: include rbac.yaml in managed overlay to create required service accounts (ea6802cd)
* chore: automated version bump to 10.1.96 [skip ci] (975efcb4)
* fix: aggressive pod cleanup and enhanced debugging for postgres failure (88d8d7e6)
* chore: automated version bump to 10.1.95 [skip ci] (4bdb15bb)
* fix: fail workflow immediately if postgres rollout fails (c3178870)
* chore: automated version bump to 10.1.94 [skip ci] (867c0192)
* fix: kill zombie postgres-auth and disable rollback for debugging (b85224be)
* chore: automated version bump to 10.1.93 [skip ci] (ea4cf7f1)
* fix: switch redis to emptyDir storage for free tier stability (07a35f7f)
* chore: automated version bump to 10.1.92 [skip ci] (30f97204)
* fix: consolidate postgres instances to reduce pod count and use emptyDir for stability (29e0e4f6)
* chore: automated version bump to 10.1.91 [skip ci] (b217b2a9)
* chore: enforce single replica for all services in scaling patch (ae3fa695)
* chore: automated version bump to 10.1.90 [skip ci] (95d887af)
* fix: optimize resource usage to fit free tier limits (11 pods max) (576030cc)
* chore: automated version bump to 10.1.89 [skip ci] (185c86f6)
* fix: delete StatefulSets before applying PVC size changes (be02ab10)
* chore: automated version bump to 10.1.88 [skip ci] (1e77ead2)
* fix(infra): drastically reduce PVC sizes to 1Gi and force statefulset recreation during deploy (c1a11dd3)
* chore: automated version bump to 10.1.87 [skip ci] (5aa02486)
* fix(ci): rename workflow to deployment and remove desktop app builds (bd2d7833)
* fix(ci): add manual force build flag and bypass cache check when enabled (9eeecd61)
* fix(ci): force rebuild of all components when infrastructure changes (48071e5c)
* fix(ci): remove hard reset step as per requirement (1a04e980)
* chore: automated version bump to 10.1.86 [skip ci] (6235a087)
* fix(ci): wait for all deployments to be ready before verifying tunnel (6ec2fdd6)
* chore: automated version bump to 10.1.85 [skip ci] (d73744fb)
* fix(ci): refactor deployment to use direct GH Action logic and ensure hard reset (091dbdc5)
* chore: automated version bump to 10.1.84 [skip ci] (6e9e9d81)
* fix(k8s): disable heavy monitoring stack in base to prevent resource exhaustion (5df21292)
* chore: automated version bump to 10.1.83 [skip ci] (edb6e8b3)
* fix(ops): enhance hard reset to handle stuck namespaces (490b92f0)
* chore: automated version bump to 10.1.82 [skip ci] (6e5adc6a)
* fix(k8s): explicitly list resources to exclude heavy monitoring stack (7ce0bbcb)
* chore: automated version bump to 10.1.81 [skip ci] (ee641639)
* fix(k8s): define postgres storage pvc properly and patch managed resource requests (49a87fae)
* chore: automated version bump to 10.1.80 [skip ci] (e2d9d14d)
* fix(ops): add hard reset capability to nuke and rebuild namespace (9b896c33)
* chore: automated version bump to 10.1.79 [skip ci] (cdbc3295)
* fix(deploy): force cleanup of stuck pods and debug nodes (7288a632)
* chore: automated version bump to 10.1.78 [skip ci] (687ff096)
* fix(infra): drastically reduce resource requests to fit free tier limits (43ecc49a)
* chore: automated version bump to 10.1.77 [skip ci] (55d98e4d)
* fix(ci): add cluster debugging and stricter health checks (783b75b8)
* chore: automated version bump to 10.1.76 [skip ci] (cef4e723)
* fix(k8s): allow ingress/egress for cloudflared and web init to reach service port 8080 (471e4a30)
* chore: automated version bump to 10.1.75 [skip ci] (3e48953b)
* fix(k8s): allow cloudflared ingress in network policies and fix egress port (e1b3b79f)
* chore: automated version bump to 10.1.74 [skip ci] (8e44fdf8)
* fix(k8s): update api-backend service targetPort to 3000 (74b15973)
* chore: automated version bump to 10.1.73 [skip ci] (27292802)
* fix(web): configure nginx for non-root execution to resolve 502 (725774eb)
* chore: automated version bump to 10.1.72 [skip ci] (8fb41e44)
* fix(infra): update tunnel port and switch to ghcr images (7a0ddf34)
* chore: automated version bump to 10.1.71 [skip ci] (91d1d2c7)
* ai(OpenCode): implement core clean and fix postgres host in init (607a5b97)
* chore: automated version bump to 10.1.70 [skip ci] (ff06a1d9)
* ai(OpenCode): check secrets in get-logs.yml (7d34f46e)
* chore: automated version bump to 10.1.69 [skip ci] (d0af5dde)
* ai(OpenCode): optimize resources and implement nuclear pruning (85a24723)
* chore: automated version bump to 10.1.68 [skip ci] (0514a24b)
* ai(OpenCode): scale down and reduce resource requests for managed overlay (3ec1f06d)
* chore: automated version bump to 10.1.67 [skip ci] (317b1eda)
* ai(OpenCode): add checkout and preserve secrets in nuclear reset (70556773)
* chore: automated version bump to 10.1.66 [skip ci] (76e5251f)
* ai(OpenCode): implement nuclear reset in fix-backend.yml (4e3096ba)
* chore: automated version bump to 10.1.65 [skip ci] (5b50689a)
* ai(OpenCode): get more resource detail in get-logs.yml (6cb3ca70)
* chore: automated version bump to 10.1.64 [skip ci] (b174b0d8)
* ai(OpenCode): list all resources in get-logs.yml (1dd581fc)
* ai(OpenCode): standardize image placeholders in base manifests (2d743d23)
* ai(OpenCode): describe pods in get-logs.yml (ab60d0e4)
* chore: automated version bump to 10.1.63 [skip ci] (6f0e2952)
* ai(OpenCode): update fix-backend.yml to terminate all pods (2f2af3b3)
* ai(OpenCode): fetch api-backend logs in get-logs.yml (19605bf9)
* ai(OpenCode): check nodes in get-logs.yml (be900066)
* chore: automated version bump to 10.1.62 [skip ci] (8f77a35b)
* ai(OpenCode): list all pods in get-logs.yml (68c8961f)
* chore: automated version bump to 10.1.61 [skip ci] (12232559)
* ai(OpenCode): force http2 protocol for cloudflared (7189a471)
* ai(OpenCode): fix permissions in get-logs.yml (87a370cb)
* ai(OpenCode): add workflow to fetch tunnel logs (f7299f30)
* chore: automated version bump to 10.1.60 [skip ci] (316a189a)
* ai(OpenCode): revert Tunnel ID to 62da6c19-947b-4bf6-acad-100a73de4e0d and update token (e10cff96)
* chore: automated version bump to 10.1.59 [skip ci] (bf148ce4)
* ai(OpenCode): update fix-tunnel-credentials.sh to apply ConfigMap (a5c1448c)
* chore: automated version bump to 10.1.58 [skip ci] (48d24b02)
* ai(OpenCode): synchronize Cloudflare Tunnel ID to ee26f195-904b-4406-a8ae-9265c9971004 (bf67498a)
* chore: remove all documentation archives (7846370d)
* docs: refactor documentation to AWS/Auth0 and remove deprecated tech (eb600d52)
* chore: remove backup data (d39a78df)
* chore: clean repo artifacts (04a5f11d)
* chore: remove cursor rules (416d5094)
* chore: automated version bump to 10.1.57 [skip ci] (74af8d18)
* ai(Cursor): check GHCR tags before builds (0c79b524)
* fix(k8s): enforce string type for cloudflared config annotation (9cad70c1)
* chore: automated version bump to 10.1.56 [skip ci] (c79ee83b)
* chore(ci): temporarily disable desktop builds and release job (fbf54896)
* refactor(docker): enforce usage of custom base image for all services (b11edfca)
* chore: automated version bump to 10.1.55 [skip ci] (e66f2c5e)
* chore(ci): apply conditional build logic to all containers (cfc15f17)
* chore(ci): optimize build_base to run only on base changes (c12f8019)
* chore: automated version bump to 10.1.54 [skip ci] (2f67ace2)
* refactor(ci): scope release job to desktop builds (5debacb5)

## [10.1.147] - 2026-01-18
* feat(auth/version): comprehensive Auth0 fix and synchronized versioning 10.1.147 (2f73db97)
* chore: automated version bump to 10.1.148 [skip ci] (b0049296)

## [10.1.147] - 2026-01-18
* chore: automated version bump to 10.1.148 [skip ci] (b004929)

## [10.1.147] - 2025-12-31
## v10.1.147

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

