# Contributing to CloudToLocalLLM SDK

Thank you for your interest in contributing to the CloudToLocalLLM SDK! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful and constructive in all interactions.

## Getting Started

### Prerequisites

- Node.js 18.0.0 or higher
- npm, yarn, or pnpm

### Setup Development Environment

```bash
# Clone the repository
git clone https://github.com/CloudToLocalLLM/CloudToLocalLLM.git
cd CloudToLocalLLM/services/sdk

# Install dependencies
npm install

# Build the SDK
npm run build

# Run tests
npm test
```

## Development Workflow

### Making Changes

1. Create a new branch for your feature or fix:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following the code style guidelines

3. Add or update tests as needed

4. Run tests and linting:

   ```bash
   npm test
   npm run lint
   ```

5. Format your code:

   ```bash
   npm run format
   ```

### Code Style

- Use TypeScript for all new code
- Follow the existing code style
- Use meaningful variable and function names
- Add JSDoc comments for public APIs
- Keep functions focused and small

### Testing

- Write tests for new features
- Ensure all tests pass before submitting
- Aim for high code coverage
- Use descriptive test names

### Commit Messages

Use clear, descriptive commit messages:

```
feat: Add support for API key management
fix: Handle token refresh errors correctly
docs: Update SDK documentation
test: Add tests for webhook delivery
chore: Update dependencies
```

## Submitting Changes

### Pull Request Process

1. Ensure your code follows the style guidelines
2. Update documentation if needed
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request with a clear description

### Pull Request Description

Include:

- What changes were made
- Why the changes were made
- Any related issues or PRs
- Testing performed

## Reporting Issues

### Bug Reports

Include:

- SDK version
- Node.js version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Error messages or logs

### Feature Requests

Include:

- Use case description
- Proposed API design
- Examples of usage
- Any related issues

## Documentation

- Update README.md for user-facing changes
- Update SDK_DOCUMENTATION.md for API changes
- Add examples for new features
- Keep examples up to date

## Building and Publishing

### Build

```bash
npm run build
```

This generates TypeScript definitions and JavaScript output in the `dist/` directory.

### Testing

```bash
npm test
npm test:watch
```

### Linting

```bash
npm run lint
npm run format
```

### Publishing to npm

Publishing is handled by maintainers. Once your PR is merged, it will be published in the next release.

## Release Process

1. Update version in package.json
2. Update CHANGELOG.md
3. Create git tag
4. Push to GitHub
5. npm publish

## Questions?

- Check existing issues and discussions
- Review the documentation
- Ask in GitHub discussions
- Contact the maintainers

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

Thank you for contributing!
