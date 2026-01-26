# CI Configuration Guide for Kilocode CLI

This guide explains how to configure the Kilocode CLI (`scripts/kilocode-cli.cjs`) for Continuous Integration (CI) environments, specifically GitHub Actions.

## Configuration Precedence

The CLI loads configuration in the following order of precedence:

1. **CWD Config**: `kilocode.config.json` in the current working directory.
2. **Home Config**: `~/.kilocode/config.json` (useful for shared runner config).
3. **Environment Variables**: `KILOCODE_TOKEN`, `KILOCODE_MODEL`, etc.

## GitHub Actions Snippet

To ensure the Kilocode CLI works correctly in your workflows, you can either rely on environment variables directly, or use the built-in auto-configuration command to standardize the setup (Recommended).

### Option 1: Auto-Configuration (Recommended)

The CLI includes a helper flag `--configure-ci` that detects the CI environment and initializes the standard `~/.kilocode/config.json` file using available environment variables. This ensures subsequent tools or steps that rely on this file work correctly.

```yaml
- name: Configure Kilocode CLI
  env:
    KILOCODE_TOKEN: ${{ secrets.KILOCODE_TOKEN }}
    KILOCODE_MODEL: x-ai/grok-code-fast-1
    KILOCODE_POSTHOG_API_KEY: ${{ secrets.KILOCODE_POSTHOG_API_KEY }}
  run: node scripts/kilocode-cli.cjs --configure-ci

- name: Run Analysis
  run: node scripts/kilocode-cli.cjs "Your prompt here"
```

### Option 2: Direct Environment Variables

The CLI automatically picks up `KILOCODE_TOKEN` and related variables if they are set in the environment of the running step.

```yaml
- name: Run Kilocode Analysis
  env:
    KILOCODE_TOKEN: ${{ secrets.KILOCODE_TOKEN }}
    KILOCODE_MODEL: x-ai/grok-code-fast-1
    KILOCODE_POSTHOG_API_KEY: ${{ secrets.KILOCODE_POSTHOG_API_KEY }}
  run: |
    node scripts/kilocode-cli.cjs "Your prompt here"
```

### Option 3: Manual Config File Generation (Legacy)

If you prefer to manually generate a config file (e.g., for complex setups), you can write it to the CWD.

```yaml
- name: Configure Kilocode
  env:
    KILOCODE_TOKEN: ${{ secrets.KILOCODE_TOKEN }}
    KILOCODE_MODEL: x-ai/grok-code-fast-1
  run: |
    # Write config to CWD
    cat <<EOF > kilocode.config.json
    {
      "providers": [
        {
          "id": "default",
          "provider": "kilocode",
          "kilocodeToken": "\${KILOCODE_TOKEN}",
          "kilocodeModel": "\${KILOCODE_MODEL}"
        }
      ]
    }
    EOF

- name: Run Analysis
  run: node scripts/kilocode-cli.cjs "Your prompt here"
```

## Troubleshooting

If the CLI fails to find configuration:

1. Check if `KILOCODE_TOKEN` is set in the step's `env`.
2. In CI, the script logs `Loading configuration from: ...` if a config file is found. Check the logs.
3. Ensure `scripts/kilocode-cli.cjs` is executable or run with `node`.
