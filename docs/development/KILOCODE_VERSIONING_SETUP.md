# Setting Up Kilocode CLI for AI-Powered Versioning

## Get Your API Key

1. **Go to Kilocode Console**:
   - Visit: https://kilocode.ai/console
   - Or: https://api.kilocode.ai/console

2. **Create API Key**:
   - Navigate to API Keys section
   - Create a new JWT token
   - Copy the generated token

3. **Configure Kilocode**:
   Run the setup script to configure your environment:

   ```bash
   ./scripts/setup-kilocode.sh 'your_api_key_here'
   ```

   Or manually add to GitHub Secrets:

   ```bash
   gh secret set KILOCODE_TOKEN --body 'your_api_key_here'
   ```

4. **Verify**:

   ```bash
   gh secret list | grep KILOCODE
   # Should show: KILOCODE_TOKEN
   ```

## Test Locally (Optional)

```bash
# Export your key (if not using setup script)
export KILOCODE_TOKEN='your_key_here'

# Test version analysis
./scripts/analyze-version-bump.sh

# Test version update
./scripts/update-all-versions.sh 4.5.0 $(git rev-parse --short HEAD)
```

## Fallback Behavior

If `KILOCODE_TOKEN` is not set:

- ✅ Workflow still works
- ⚠️  Defaults to PATCH bump
- ⚠️  No intelligent analysis
- 📝 Warning shown in logs

## Cost

- **Kilocode API**: Free tier includes generous limits for `grok-code-fast-1`
- **Each version bump**: 1 API call
- **Typical usage**: ~10-50 calls/month
- **Cost**: $0 (within free tier)

## Privacy

Kilocode receives:

- ✅ Commit messages (public repo info)
- ✅ Current version number
- ❌ No source code
- ❌ No secrets
- ❌ No user data

## Alternative: Manual Versioning

If you prefer not to use Kilocode:

```bash
# Disable version-bump workflow
# Edit .github/workflows/version-bump.yml:
# Change: if: "!contains(...)"
# To: if: false

# Manual version tagging
git tag 4.5.0-cloud-$(git rev-parse --short HEAD)
git tag 4.5.0-desktop-$(git rev-parse --short HEAD)
git tag 4.5.0-mobile-$(git rev-parse --short HEAD)
git push origin --tags
```

## Quota Limits

Kilocode Free Tier:

- **Sufficient for**: 100+ deployments/day
- If you hit limits:
  - Workflow falls back to PATCH bump
  - No deployment failure
  - Consider upgrading to paid tier
