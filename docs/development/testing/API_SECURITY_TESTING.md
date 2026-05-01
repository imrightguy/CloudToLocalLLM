# Security Test Suite

> **Status**: These tests cover the older simplified tunnel system. Keep them for tunnel fallback and migration coverage. New security testing should also cover Tailscale-first device mesh behavior, per-user cloud connector isolation, agent runtime selection, and device-scoped desktop permissions.

This directory contains comprehensive security tests for the CloudToLocalLLM simplified tunnel system. The tests validate authentication, authorization, user isolation, rate limiting, and other security measures.

## Test Files

### `user-isolation.test.js`

Tests to ensure complete user isolation and prevent cross-user data leakage:

- Cross-user request prevention
- Connection isolation
- Request/response isolation
- Data leakage prevention
- Rate limiting isolation
- WebSocket connection isolation
- Security headers and metadata validation

### `authentication-authorization.test.js`

Comprehensive tests for JWT validation, rate limiting, and security measures:

- Valid token authentication
- Invalid token handling
- Authorization tests
- Rate limiting security
- Connection security
- Security integration tests
- Edge cases and malformed inputs

## Running Security Tests

### Run All Security Tests

```bash
npm run test:security
```

### Run Specific Test Suites

```bash
# User isolation tests
npm run test:user-isolation

# Authentication and authorization tests
npm run test:auth

# Verbose output for debugging
npm run test:security:verbose
```

### Run Individual Test Categories

```bash
# Run only authentication tests
npx jest tests/security/authentication-authorization.test.js --testNamePattern="Authentication Security Tests"

# Run only rate limiting tests
npx jest tests/security/authentication-authorization.test.js --testNamePattern="Rate Limiting Security Tests"

# Run only user isolation tests
npx jest tests/security/user-isolation.test.js --testNamePattern="User Isolation Security Tests"
```

## Test Coverage

### Authentication Security

- ✅ Valid JWT token authentication
- ✅ Token expiration handling
- ✅ Malformed token rejection
- ✅ Missing token handling
- ✅ Token refresh warnings
- ✅ Suspicious scope detection
- ✅ Security audit logging

### Authorization Security

- ✅ Role-based access control
- ✅ Cross-user access prevention
- ✅ Resource-level authorization
- ✅ Admin access validation
- ✅ Permission escalation prevention

### User Isolation

- ✅ Connection isolation between users
- ✅ Request/response correlation isolation
- ✅ Data leakage prevention
- ✅ WebSocket message isolation
- ✅ Connection cleanup isolation
- ✅ Error message sanitization

### Rate Limiting

- ✅ Per-user request rate limiting
- ✅ Burst protection
- ✅ Concurrent request limiting
- ✅ Rate limit header validation
- ✅ Independent user rate limits
- ✅ Rate limit violation logging

### Connection Security

- ✅ Security header validation
- ✅ IP tracking and blocking
- ✅ TLS/SSL validation (when available)
- ✅ Origin validation for WebSockets
- ✅ Certificate validation
- ✅ Connection attempt monitoring

### Edge Cases

- ✅ Malformed JWT tokens
- ✅ Special characters in tokens
- ✅ Extremely long headers
- ✅ Missing or malformed headers
- ✅ Concurrent request handling
- ✅ Load testing security measures

## Security Test Configuration

### Test Users

The tests use predefined test users with different roles and permissions:

- `validUser`: Standard user with valid token
- `expiredUser`: User with expired token
- `maliciousUser`: User with suspicious scopes
- `adminUser`: User with admin privileges

### Mock Configuration

- JWT tokens are mocked for consistent testing
- JWKS client is mocked to avoid external dependencies
- Audit logging is captured for verification
- Rate limits are set low for faster test execution

## Security Assertions

### Authentication Tests

- Verify successful authentication with valid tokens
- Ensure proper error responses for invalid tokens
- Validate security audit logging for auth events
- Check token refresh warning headers
- Confirm user information attachment to requests

### Authorization Tests

- Validate role-based access control
- Prevent unauthorized resource access
- Ensure proper error responses for authorization failures
- Verify cross-user access attempt logging

### User Isolation Tests

- Confirm complete separation of user data
- Prevent request correlation across users
- Validate connection isolation
- Ensure error messages don't leak user data
- Verify independent rate limiting per user

### Rate Limiting Tests

- Validate request rate limits per user
- Test burst protection mechanisms
- Confirm concurrent request limiting
- Verify rate limit headers in responses
- Ensure independent limits across users

### Connection Security Tests

- Validate security headers in responses
- Test IP tracking and blocking mechanisms
- Verify TLS/SSL validation when available
- Confirm WebSocket origin validation
- Test certificate validation processes

## Test Data Privacy

All test data follows privacy best practices:

- User IDs are hashed in logs
- IP addresses are anonymized
- Email addresses are partially masked
- Sensitive headers are redacted
- No real user data is used in tests

## Continuous Security Testing

### Pre-commit Hooks

Security tests should be run before each commit:

```bash
# Add to .git/hooks/pre-commit
npm run test:security
```

### CI/CD Integration

Include security tests in your CI/CD pipeline:

```yaml
# Example GitHub Actions step
- name: Run Security Tests
  run: npm run test:security:verbose
```

### Security Regression Testing

Run security tests after any changes to:

- Authentication middleware
- Authorization logic
- Rate limiting configuration
- User isolation mechanisms
- Security headers
- JWT validation
- WebSocket handling

## Security Test Maintenance

### Adding New Security Tests

1. Identify the security requirement
2. Create test cases for positive and negative scenarios
3. Include edge cases and malformed inputs
4. Verify audit logging for security events
5. Test under load conditions
6. Document the test purpose and assertions

### Updating Existing Tests

1. Review test coverage after code changes
2. Update mock data if authentication changes
3. Adjust rate limits if configuration changes
4. Verify all assertions still pass
5. Update documentation if test behavior changes

### Security Test Best Practices

- Test both positive and negative scenarios
- Include edge cases and malformed inputs
- Verify security audit logging
- Test under concurrent load
- Use realistic but safe test data
- Mock external dependencies
- Validate error messages don't leak data
- Test timeout and cleanup scenarios

## Troubleshooting Security Tests

### Common Issues

1. **Mock JWT verification failing**: Check token format and claims
2. **Rate limiting not working**: Verify middleware order and configuration
3. **User isolation failing**: Check user ID extraction and validation
4. **Audit logging not captured**: Verify audit middleware setup
5. **WebSocket tests failing**: Check mock WebSocket implementation

### Debug Commands

```bash
# Run with debug output
DEBUG=* npm run test:security

# Run specific test with verbose output
npx jest tests/security/user-isolation.test.js --verbose --no-cache

# Run tests with coverage
npx jest tests/security/ --coverage
```

## Security Compliance

These tests help validate compliance with:

- **OWASP Top 10**: Authentication, authorization, and security logging
- **SOC 2**: Access controls and monitoring
- **GDPR**: Data privacy and user isolation
- **ISO 27001**: Information security management

## Reporting Security Issues

If security tests reveal vulnerabilities:

1. Document the issue with test evidence
2. Assess the severity and impact
3. Create a security incident report
4. Implement fixes with additional tests
5. Verify the fix with regression testing
6. Update security documentation

## Security Test Metrics

Track these metrics from security tests:

- Authentication success/failure rates
- Authorization violation attempts
- Rate limiting effectiveness
- User isolation integrity
- Security audit log completeness
- Test coverage percentage
- Performance under security load
