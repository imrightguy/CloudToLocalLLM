# Changelog

All notable changes to the CloudToLocalLLM SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2024-01-XX

### Added

- Initial release of CloudToLocalLLM SDK
- Full TypeScript support with comprehensive type definitions
- User management endpoints
- Tunnel management endpoints
- Webhook management endpoints
- Admin operations endpoints
- API key management endpoints
- Health check endpoints
- Proxy management endpoints
- Automatic token refresh
- Retry logic with exponential backoff
- Comprehensive error handling
- Pagination support
- Rate limit awareness
- Complete API documentation
- Examples for common use cases
- Jest test suite
- ESLint and Prettier configuration

### Features

#### Authentication

- JWT token management
- Automatic token refresh
- Logout with token revocation

#### User Management

- Get current user profile
- Get user by ID
- Update user profile
- Delete user account
- Get user tier information
- Upgrade user tier

#### Tunnel Management

- Create tunnels
- Get tunnel details
- List tunnels with pagination
- Update tunnel configuration
- Delete tunnels
- Start/stop tunnels
- Get tunnel status
- Get tunnel metrics

#### Webhook Management

- Create webhooks
- Get webhook details
- List webhooks
- Update webhook configuration
- Delete webhooks
- Test webhooks
- Get webhook delivery history

#### Admin Operations

- List all users
- Get user details (admin)
- Update user (admin)
- Delete user (admin)
- Get audit logs
- Get system health status

#### API Key Management

- Create API keys
- List API keys
- Revoke API keys

#### Health & Status

- Get API health status
- Get API version information

#### Proxy Management

- Get proxy status
- Start/stop proxy
- Get proxy metrics
- Scale proxy instances

### Documentation

- Comprehensive README with quick start guide
- Full API reference documentation
- Multiple examples (basic usage, tunnel management, webhooks, admin operations)
- Contributing guidelines
- TypeScript support documentation

### Testing

- Unit tests for client initialization and configuration
- Test suite for all major functionality
- Jest configuration with TypeScript support

## [Unreleased]

### Planned Features

- React hooks for SDK integration
- Vue composables for SDK integration
- GraphQL client support
- WebSocket support for real-time updates
- Batch operations support
- Advanced filtering and search
- Custom interceptors support
- Request/response logging
- Performance monitoring
- Analytics integration

---

## Version History

### 2.0.0 (Initial Release)

- Complete SDK implementation
- Full API coverage
- TypeScript support
- Comprehensive documentation
- Test suite
