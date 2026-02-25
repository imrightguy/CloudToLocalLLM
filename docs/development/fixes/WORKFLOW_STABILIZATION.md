# Workflow Stabilization Fixes

## Issue Description

The GitHub Actions workflows were failing due to inconsistent usage of the `kilocode` CLI tool and brittle JSON parsing logic. The workflows were passing unsupported flags (`--yolo`, `--model`) to the local `scripts/kilocode-cli.cjs` script, and some workflows were expecting a JSON structure (`{ "response": ... }`) that the local script does not produce.

## Root Causes

1. **CLI Flag Mismatch:** The `main-orchestrator.yml`, `ai-review.yml`, `ai-triage.yml`, and `ai-task.yml` workflows were calling `gemini` with flags that `scripts/gemini-cli.cjs` interpreted as part of the prompt text.
2. **Inconsistent Tooling:** `ai-triage.yml` and `ai-task.yml` were missing the step to symlink the local `scripts/gemini-cli.cjs` to `/usr/local/bin/gemini`, potentially relying on a different system-installed tool with different output behavior.
3. **Brittle Parsing:** The workflows used fragile `sed` and `jq` logic that failed when the output format didn't match the expectation (e.g., missing `.response` wrapper or presence of Markdown code blocks).
4. **Azure OIDC Risk:** (Observation) The recent repository rename might cause Azure OIDC login failures if the Federated Credentials in Azure AD were not updated to match the new repository path (`CloudToLocalLLM-online/CloudToLocalLLM`).

## Applied Fixes

### 1. Standardized `kilocode` CLI Usage

- **Updated `scripts/kilocode-cli.cjs`:** Modified the script to filter out arguments starting with `-` to prevent flags from polluting the LLM prompt.
- **Updated Workflows:** Removed unsupported flags (`--yolo`, `--model`, `-o json`) from `kilocode` command calls in all workflows (`main-orchestrator.yml`, `ai-review.yml`, `ai-triage.yml`, `ai-task.yml`).
- **Enforced Local Script:** Added the `kilocode-cli.cjs` symlink step to `ai-triage.yml` and `ai-task.yml` to ensure consistent behavior across all jobs.

### 2. Robust JSON Parsing

- **Updated `main-orchestrator.yml` & `ai-triage.yml`:**
  - Removed dependency on the `.response` wrapper field (which the local script doesn't output).
  - Improved `sed` logic to strip Markdown code blocks (` ```json `) before parsing.
  - Added fallback logic to handle raw JSON output.

## Verification

- Verified that `scripts/kilocode-cli.cjs` exists and is executable.
- Verified that the new JSON extraction logic works with raw JSON output.

## Remaining Actions (User Required)

- **Azure OIDC:** Verify that Azure Federated Credentials are updated for the new repository name `CloudToLocalLLM-online/CloudToLocalLLM`.
- **Secrets:** Ensure `KILOCODE_TOKEN` and `PAT_TOKEN` are set in GitHub Secrets.
