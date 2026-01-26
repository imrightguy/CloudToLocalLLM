# Setting Up Personal Access Token (PAT)

## Why PAT is Needed

GitHub Actions workflows triggered by `GITHUB_TOKEN` cannot trigger other workflows (security feature).

To enable automatic cloud deployment when version tags are created, we need a Personal Access Token.

## Create PAT

1. **Go to GitHub Settings**:
   - https://github.com/settings/tokens?type=beta
   - Or: Settings → Developer settings → Personal access tokens → Fine-grained tokens

2. **Click "Generate new token"**

3. **Configure Token**:
   - **Name**: `CloudToLocalLLM Deployment Automation`
   - **Expiration**: 90 days (or longer)
   - **Repository access**: Only select repositories → `CloudToLocalLLM`
   - **Permissions**:
     - Repository permissions:
       - Contents: Read and write
       - Metadata: Read-only (auto-selected)
       - Workflows: Read and write

4. **Generate and Copy Token**

## Add to GitHub Secrets

```bash
cd /home/rightguy/development/CloudToLocalLLM
gh secret set PAT_TOKEN --body 'your_generated_token_here'
```

## Verify

```bash
gh secret list | grep PAT
# Should show: PAT_TOKEN
```

## How It Works

With PAT configured:

1. Push to main → Version-bump workflow runs
2. Gemini analyzes → Creates version tags
3. Tags pushed with PAT → **Triggers deploy-aks workflow automatically** ✅
4. Cloud deployment runs for new version

Without PAT:

- Tags pushed with GITHUB_TOKEN → No deployment trigger ❌
- Must manually run: `gh workflow run deploy-aks.yml -f version_tag=X.Y.Z-cloud-abc123`
