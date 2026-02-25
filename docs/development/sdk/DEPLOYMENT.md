# CloudToLocalLLM SDK - Deployment Guide

## Publishing to npm

### Prerequisites

- npm account at https://www.npmjs.com
- npm CLI installed and authenticated
- Node.js 18.0.0 or higher

### Authentication

```bash
npm login
```

Enter your npm credentials when prompted.

### Build

```bash
cd services/sdk
npm install
npm run build
```

This will:

- Install dependencies
- Compile TypeScript to JavaScript
- Generate type definitions
- Create source maps

### Verify Build

```bash
# Check that dist/ directory was created
ls -la dist/

# Verify type definitions
ls -la dist/*.d.ts
```

### Test Before Publishing

```bash
# Run tests
npm test

# Run linting
npm run lint

# Check what will be published
npm pack
```

### Publish to npm

```bash
npm publish
```

This will publish the package as `@CloudToLocalLLM/sdk` to the npm registry.

### Verify Publication

```bash
# Check npm registry
npm view @CloudToLocalLLM/sdk

# Install from npm
npm install @CloudToLocalLLM/sdk
```

## Version Management

### Update Version

Edit `package.json`:

```json
{
  "version": "2.0.1"
}
```

### Semantic Versioning

- **MAJOR** (X.0.0): Breaking changes
- **MINOR** (0.X.0): New features, backward compatible
- **PATCH** (0.0.X): Bug fixes, backward compatible

### Update Changelog

Edit `CHANGELOG.md` with new version and changes:

```markdown
## [2.0.1] - 2024-01-XX

### Fixed
- Fixed token refresh issue
- Improved error handling

### Added
- New webhook retry configuration
```

### Create Git Tag

```bash
git tag v2.0.1
git push origin v2.0.1
```

## Continuous Integration

### GitHub Actions

Create `.github/workflows/publish-sdk.yml`:

```yaml
name: Publish SDK to npm

on:
  push:
    tags:
      - 'sdk-v*'

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          registry-url: 'https://registry.npmjs.org'
      - run: cd services/sdk && npm install
      - run: cd services/sdk && npm run build
      - run: cd services/sdk && npm test
      - run: cd services/sdk && npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### Setup npm Token

1. Generate token at https://www.npmjs.com/settings/tokens
2. Add to GitHub Secrets as `NPM_TOKEN`

## Distribution Channels

### npm Registry

```bash
npm install @CloudToLocalLLM/sdk
```

### GitHub Releases

1. Create release on GitHub
2. Attach SDK tarball
3. Add release notes

### CDN (Optional)

For browser usage:

```html
<script src="https://cdn.jsdelivr.net/npm/@CloudToLocalLLM/sdk@2.0.0/dist/index.js"></script>
```

## Post-Publication

### Update Documentation

1. Update main project README
2. Add SDK to documentation site
3. Update API documentation

### Announce Release

1. GitHub release notes
2. Project changelog
3. Community channels

### Monitor Usage

1. Check npm download stats
2. Monitor GitHub issues
3. Collect user feedback

## Troubleshooting

### Authentication Failed

```bash
npm logout
npm login
```

### Version Already Published

```bash
# Check published versions
npm view @CloudToLocalLLM/sdk versions

# Use different version number
```

### Build Errors

```bash
# Clean build
rm -rf dist/
npm run build

# Check TypeScript errors
npx tsc --noEmit
```

### Test Failures

```bash
# Run tests with verbose output
npm test -- --verbose

# Run specific test
npm test -- client.test.ts
```

## Maintenance

### Regular Updates

- Update dependencies monthly
- Run security audits
- Update documentation
- Monitor issues

### Security

```bash
# Check for vulnerabilities
npm audit

# Fix vulnerabilities
npm audit fix
```

### Performance

```bash
# Check bundle size
npm pack
tar -tzf CloudToLocalLLM-sdk-*.tgz | wc -l

# Analyze dependencies
npm ls
```

## Support

For issues with publishing:

- Check npm documentation: https://docs.npmjs.com
- Review package.json configuration
- Verify authentication
- Check file permissions

## Checklist

Before publishing:

- [ ] Version updated in package.json
- [ ] CHANGELOG.md updated
- [ ] All tests passing
- [ ] Linting passes
- [ ] Build successful
- [ ] Type definitions generated
- [ ] README.md updated
- [ ] Examples tested
- [ ] npm authenticated
- [ ] No uncommitted changes

After publishing:

- [ ] Verify on npm registry
- [ ] Test installation
- [ ] Update main documentation
- [ ] Create GitHub release
- [ ] Announce release
- [ ] Monitor for issues
