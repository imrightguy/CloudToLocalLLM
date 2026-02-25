# Kiro IDE Configuration Guide

## Overview

CloudToLocalLLM includes specialized configuration for Kiro IDE, providing custom AI assistant modes, MCP (Model Context Protocol) tool integration, and development workflow automation. This guide covers the setup and usage of Kiro IDE features for enhanced development productivity.

## Custom AI Assistant Modes

The project includes pre-configured custom modes in `temp_custom_modes.yaml` that provide specialized AI assistance for different development tasks.

### Available Custom Modes

#### 1. Documentation Specialist (`docs-specialist`)

**Purpose**: Technical writing expert for clear, comprehensive documentation

**Capabilities**:

- Explaining complex concepts simply
- Creating well-structured documentation
- Checking for broken links
- Ensuring consistency in tone and style

**File Access**: Restricted to documentation files only

- Markdown files (`.md`, `.mdx`)
- Text files (`.txt`, `.rst`, `.adoc`)
- README and CHANGELOG files

**Usage**: Ideal for writing and improving project documentation, API docs, and user guides.

#### 2. Code Reviewer (`code-reviewer`)

**Purpose**: Senior software engineer conducting thorough code reviews

**Capabilities**:

- Code quality analysis
- Security issue identification
- Performance optimization suggestions
- Maintainability improvements

**File Access**: Read-only access with browser tools for research

**Usage**: Perfect for reviewing pull requests, identifying code smells, and suggesting improvements.

#### 3. Test Engineer (`test-engineer`)

**Purpose**: QA engineer and testing specialist

**Capabilities**:

- Writing comprehensive tests
- Debugging test failures
- Improving code coverage
- Edge case identification

**File Access**: Restricted to test files only

- JavaScript/TypeScript test files (`.test.js`, `.spec.ts`, etc.)
- Test configuration files

**Usage**: Specialized for creating and maintaining test suites, debugging test failures.

#### 4. Code Simplifier (`code-simplifier`)

**Purpose**: Expert refactoring specialist (Gemini integration)

**Capabilities**:

- Code complexity reduction
- Redundancy elimination
- Naming improvements
- Method extraction
- Dead code removal
- Logic flow clarification

**File Access**: Full read/edit access with all tools available

**Refactoring Methodology**:

1. **Analyze Before Acting**: Understand code behavior and public interfaces
2. **Preserve Behavior**: Maintain all external contracts and side effects
3. **Simplification Techniques**: Apply systematic improvement patterns
4. **Quality Checks**: Verify improvements and test compatibility
5. **Clear Communication**: Explain changes and benefits

**Usage**: Ideal for refactoring legacy code, improving readability, and reducing technical debt.

## MCP Tool Integration

### Configured MCP Servers

The project includes MCP server configurations in `temp_mcp_settings.json`:

#### 1. Playwright Server

**Purpose**: Browser automation and end-to-end testing

- Navigate to URLs
- Take screenshots
- Interact with web elements
- Execute JavaScript
- Monitor console logs

#### 2. Context7 Server  

**Purpose**: Up-to-date library documentation

- Resolve library IDs
- Fetch current documentation
- Access API references

#### 3. N8N MCP Server

**Purpose**: Workflow automation

- API integrations
- Process automation
- Data transformations

#### 4. Sequential Thinking Server

**Purpose**: Structured problem-solving

- Step-by-step analysis
- Logical reasoning chains
- Complex problem breakdown

#### 5. Chrome DevTools Server

**Purpose**: Advanced browser debugging

- Network request monitoring
- Performance analysis
- DOM inspection

### MCP Configuration Setup

1. **Copy Configuration**: Move `temp_mcp_settings.json` to `.kiro/settings/mcp.json`
2. **Install Dependencies**: Ensure required npm packages are available
3. **Configure Environment**: Set up any required API keys or tokens
4. **Restart Kiro**: Reload IDE to apply MCP server configurations

## Development Workflow Integration

### Kiro Hooks

The project includes several automation hooks in `.kiro/hooks/`:

#### Auto-Commit Push Hook (`auto-commit-push.kiro.hook`)

- Automatically commits and pushes changes
- Integrates with CI/CD workflows
- Maintains clean git history

#### Flutter Lint Fix Hook (`flutter-lint-fix.kiro.hook`)  

- Automatically fixes Flutter linting issues
- Runs `dart fix --apply` on save
- Maintains code quality standards

#### Code Quality Analyzer Hook (`code-quality-analyzer.kiro.hook`)

- Analyzes code quality metrics
- Identifies potential improvements
- Integrates with custom modes

#### Source Documentation Sync Hook (`source-docs-sync.kiro.hook`)

- Synchronizes code documentation
- Updates API documentation
- Maintains documentation consistency

### Gemini CLI Integration

The project integrates with Gemini CLI for AI-powered development assistance:

**Features**:

- Semantic version analysis
- Platform detection for deployments
- Automated commit message generation
- Code change impact analysis

**Configuration**: See `GEMINI_CLI_INTEGRATION_ARCHITECTURE.md` for detailed setup

## Best Practices

### Using Custom Modes Effectively

1. **Choose the Right Mode**: Select the mode that matches your current task
   - Use `docs-specialist` for documentation work
   - Use `code-reviewer` for PR reviews
   - Use `test-engineer` for testing tasks
   - Use `code-simplifier` for refactoring

2. **Leverage File Restrictions**: Custom modes with file restrictions help maintain focus
   - Documentation mode prevents accidental code changes
   - Test mode ensures test-specific improvements

3. **Combine with MCP Tools**: Use MCP tools within custom modes for enhanced capabilities
   - Browser automation for testing web features
   - Documentation lookup for accurate references

### MCP Tool Usage

1. **Browser Testing**: Use Playwright tools to test deployed applications

   ```javascript
   // Navigate to deployed app
   playwright_navigate({ url: "https://app.cloudtolocalllm.online" })
   
   // Take screenshot for verification
   playwright_screenshot({ name: "homepage-test" })
   ```

2. **Documentation Research**: Use Context7 for up-to-date library docs

   ```javascript
   // Get Flutter documentation
   resolve_library_id({ libraryName: "flutter" })
   get_library_docs({ context7CompatibleLibraryID: "/flutter/flutter" })
   ```

3. **Workflow Automation**: Leverage N8N for complex automation tasks

### Development Workflow

1. **Start with Analysis**: Use `code-reviewer` mode to understand existing code
2. **Plan Changes**: Switch to appropriate mode for implementation
3. **Test Thoroughly**: Use `test-engineer` mode for comprehensive testing
4. **Document Changes**: Use `docs-specialist` mode for documentation updates
5. **Refactor if Needed**: Use `code-simplifier` mode for cleanup

## Configuration Files

### Custom Modes Configuration (`temp_custom_modes.yaml`)

```yaml
customModes:
  - slug: mode-name
    name: Display Name
    roleDefinition: |
      Description of the AI assistant's role and expertise
    customInstructions: |
      Specific instructions for behavior and focus areas
    groups:
      - read          # File reading capabilities
      - edit          # File editing capabilities  
      - command       # Command execution
      - mcp          # MCP tool access
      - browser      # Browser automation
    source: global
```

### MCP Settings Configuration (`temp_mcp_settings.json`)

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "package-name"],
      "env": {
        "ENVIRONMENT_VAR": "value"
      },
      "alwaysAllow": ["tool1", "tool2"]
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **Custom Modes Not Loading**
   - Verify YAML syntax in `temp_custom_modes.yaml`
   - Check file permissions
   - Restart Kiro IDE

2. **MCP Servers Not Connecting**
   - Verify npm packages are installed
   - Check network connectivity
   - Review server logs in Kiro

3. **Hooks Not Executing**
   - Verify hook file permissions
   - Check hook configuration syntax
   - Review Kiro hook settings

### Debug Steps

1. **Check Configuration Files**: Validate YAML/JSON syntax
2. **Review Logs**: Check Kiro IDE logs for error messages
3. **Test Individually**: Test each component separately
4. **Restart IDE**: Reload Kiro to apply configuration changes

## Integration with CloudToLocalLLM

### CI/CD Integration

Custom modes and MCP tools integrate with the project's AI-powered CI/CD system:

- **Code Analysis**: Custom modes assist with code review in CI/CD
- **Documentation Updates**: Automated documentation generation
- **Testing Automation**: Enhanced test coverage and quality
- **Deployment Verification**: Browser automation for deployment testing

### Development Productivity

The Kiro IDE configuration enhances CloudToLocalLLM development through:

- **Specialized AI Assistance**: Task-specific AI modes for different development phases
- **Automated Workflows**: Hooks for common development tasks
- **Enhanced Testing**: Browser automation for comprehensive testing
- **Documentation Maintenance**: Automated documentation synchronization

## Future Enhancements

### Planned Improvements

1. **Additional Custom Modes**:
   - Database specialist for SQL and schema work
   - DevOps engineer for infrastructure tasks
   - Security auditor for security reviews

2. **Enhanced MCP Integration**:
   - AWS tools for cloud infrastructure
   - Kubernetes tools for container management
   - Grafana tools for monitoring and observability

3. **Workflow Automation**:
   - Automated PR creation and management
   - Intelligent code review assignment
   - Automated testing and deployment triggers

### Contributing

To contribute to Kiro IDE configuration:

1. **Test New Modes**: Create and test custom modes for specific use cases
2. **Add MCP Servers**: Integrate additional MCP servers for enhanced capabilities
3. **Improve Hooks**: Enhance existing hooks or create new automation
4. **Update Documentation**: Keep this guide current with new features

## Conclusion

The Kiro IDE configuration provides a powerful development environment tailored for CloudToLocalLLM development. By leveraging custom AI modes, MCP tool integration, and automated workflows, developers can achieve higher productivity and code quality while maintaining focus on their specific tasks.

For questions or issues with Kiro IDE configuration, refer to the project's GitHub issues or discussions.
