# Remediation Plan: Kilocode Analysis Failure

## Problem Summary
The CI/CD pipelines are failing at the "Kilocode analysis" step due to `OPENAI_API_KEY` missing errors. Additionally, the use of `blacksmith-4vcpu-ubuntu-2404` runners is causing queue bottlenecks.

## Root Cause Diagnosis
1.  **Configuration Mismatch**: `scripts/kilocode-cli.cjs` looks for `kilocode.config.json` in `process.cwd()`, but workflows write to `~/.kilocode/config.json`.
2.  **Execution Ambiguity**: Workflows rely on a global `kilocode` command which may default to OpenAI if not properly symlinked or configured.
3.  **Runner Bottleneck**: Specialized runners are scarce, causing delays.

## Proposed Changes

### 1. Switch to Standard Runners
Update all AI workflows to use `runs-on: ubuntu-latest`. This removes the dependency on Blacksmith runners and reduces queue times.

### 2. Standardized Configuration Step
Implement a uniform step in all workflows to inject configuration values from GitHub Secrets immediately before execution. This step will write `kilocode.config.json` to the current working directory (`.`).

### 3. Direct Script Execution
Replace `kilocode` command with `node scripts/kilocode-cli.cjs`. This ensures the local wrapper script is executed, which correctly reads the local config.

## Detailed YAML Updates

### Standard Job Structure
For each AI workflow (`ai-review.yml`, `ai-triage.yml`, `ai-task.yml`, `ai-scheduled-triage.yml`, `main-orchestrator.yml`), the structure will be:

```yaml
jobs:
  job_name:
    runs-on: ubuntu-latest  # Changed from blacksmith-*
    steps:
      - uses: actions/checkout@v4
      
      # ... (identity/checkout steps) ...

      - name: Configure Kilocode
        env:
          KILOCODE_TOKEN: ${{ secrets.KILOCODE_TOKEN || secrets.KILOCODE_API_KEY }}
          KILOCODE_MODEL: x-ai/grok-code-fast-1
          KILOCODE_POSTHOG_API_KEY: ${{ secrets.KILOCODE_POSTHOG_API_KEY }}
        run: |
          # Write config to CWD where the script looks for it
          cat <<EOF > kilocode.config.json
          {
            "providers": [
              {
                "id": "default",
                "provider": "kilocode",
                "kilocodeToken": "\${KILOCODE_TOKEN}",
                "kilocodeModel": "\${KILOCODE_MODEL}",
                "kilocodePosthogApiKey": "\${KILOCODE_POSTHOG_API_KEY}"
              }
            ]
          }
          EOF
          
          # Verify script exists
          if [ ! -f scripts/kilocode-cli.cjs ]; then
            echo "::error::scripts/kilocode-cli.cjs not found"
            exit 1
          fi

      - name: Run AI Analysis
        env:
          # Pass env vars just in case script uses them as fallback
          KILOCODE_TOKEN: ${{ secrets.KILOCODE_TOKEN || secrets.KILOCODE_API_KEY }}
        run: |
          # Execute local script directly
          if ! node scripts/kilocode-cli.cjs "PROMPT..." > raw_output.json 2>ai_error.log; then
            echo "::error::AI Agent failed"
            cat ai_error.log
            exit 1
          fi
```

## Affected Workflows
- `.github/workflows/main-orchestrator.yml`
- `.github/workflows/ai-review.yml`
- `.github/workflows/ai-triage.yml`
- `.github/workflows/ai-task.yml`
- `.github/workflows/ai-scheduled-triage.yml`

## Verification
1.  **Runner**: Verify job runs on `ubuntu-latest`.
2.  **Config**: Verify `kilocode.config.json` is created in workspace.
3.  **Execution**: Verify `node scripts/kilocode-cli.cjs` is called and succeeds without OpenAI errors.
