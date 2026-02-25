# Documentation Style Guide

## Overview

This guide ensures consistent formatting and style across all CloudToLocalLLM documentation.

## File Naming Conventions

### Markdown Files

- Use `UPPERCASE_WITH_UNDERSCORES.md` for major documents (e.g., `README.md`, `SECURITY.md`)
- Use `lowercase-with-hyphens.md` for specific guides (e.g., `setup-guide.md`)
- Use descriptive names that indicate content purpose

### Directory Structure

- `UPPERCASE` for major categories (e.g., `DEPLOYMENT/`, `DEVELOPMENT/`)
- `lowercase` for specific subdirectories (e.g., `ops/`, `backend/`)

## Markdown Formatting Standards

### Headers

```markdown
# Main Title (H1) - One per document
## Section Title (H2)
### Subsection Title (H3)
#### Detail Title (H4) - Avoid deeper nesting
```

### Code Blocks

- Always specify language for syntax highlighting
- Use descriptive comments in code examples
- Prefer complete, runnable examples

```bash
# Good: Specific language and comments
flutter pub get  # Install dependencies
flutter run -d windows  # Run on Windows
```

### Links

- Use descriptive link text (not "click here")
- Prefer relative paths for internal links
- Include file extensions for clarity

```markdown
# Good
See the [Installation Guide](../INSTALLATION/README.md) for details.

# Avoid
Click [here](../INSTALLATION/README.md) for more info.
```

### Lists

- Use `-` for unordered lists (consistent with project style)
- Use `1.` for ordered lists
- Maintain consistent indentation (2 spaces)

### Emphasis

- Use `**bold**` for important terms and UI elements
- Use `*italic*` for emphasis and first-time term introduction
- Use `code` for file names, commands, and technical terms

## Content Organization

### Document Structure

1. **Title and Overview** - Clear purpose statement
2. **Prerequisites** - What users need before starting
3. **Main Content** - Step-by-step instructions or information
4. **Examples** - Practical demonstrations
5. **Troubleshooting** - Common issues and solutions
6. **Related Links** - Cross-references to other documentation

### Cross-References

- Link to related documentation
- Use consistent terminology across documents
- Maintain bidirectional links where appropriate

## Provider-Agnostic Language

### Infrastructure References

- Clearly indicate current deployment (Azure AKS)
- Mark alternative options (AWS EKS) as such
- Use generic Kubernetes terms when possible

```markdown
# Good
Currently deployed on Azure AKS. For AWS EKS deployment, see [AWS Guide](aws-guide.md).

# Avoid
Deployed on AWS EKS (when actually using Azure AKS)
```

### Authentication References

- Specify current provider (Auth0)
- Indicate provider-agnostic design
- Document alternative authentication options

## Version References

### Software Versions

- Use specific version numbers when critical
- Use `X.Y+` notation for minimum versions
- Update version references during releases

```markdown
# Good
- Flutter 3.5+ required
- Node.js 22+ recommended

# Avoid
- Latest Flutter version
- Recent Node.js
```

## Quality Checklist

Before publishing documentation:

- [ ] Headers follow hierarchy (H1 → H2 → H3)
- [ ] Code blocks specify language
- [ ] Links use descriptive text
- [ ] File paths are relative and correct
- [ ] Provider references are accurate
- [ ] Version numbers are current
- [ ] Cross-references are bidirectional
- [ ] Examples are complete and tested

## Maintenance

### Regular Updates

- Review documentation quarterly
- Update version references with releases
- Verify links after file moves
- Consolidate redundant content

### Style Consistency

- Use automated formatting tools when available
- Follow established patterns in existing docs
- Maintain consistent terminology across documents

This style guide ensures CloudToLocalLLM documentation remains professional, accessible, and maintainable.
