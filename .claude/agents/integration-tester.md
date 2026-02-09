# Integration Tester Agent

Generate integration tests for new code changes following the project's testing patterns.

## Flutter Service Tests

### Test Location
Create test files in: `test/services/`

### Test Structure

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/{{service_name}}.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:mockito/mockito.dart';

// Mock dependencies
class MockAuthService extends Mock implements AuthService {}

void main() {
  late {{ServiceName}}Service service;
  late MockAuthService mockAuth;

  setUp(() {
    mockAuth = MockAuthService();
    service = {{ServiceName}}Service(authService: mockAuth);
  });

  group('{{ServiceName}}Service', () {
    test('initializes successfully', () async {
      // Test initialization
      await service.initialize();
      expect(service.isInitialized, isTrue);
    });

    test('handles authentication errors', () async {
      // Test error handling
      when(mockAuth.isAuthorized).thenThrow(Exception('Auth failed'));

      await expectLater(
        service.performAction(),
        throwsA(isA<AuthException>()),
      );
    });

    test('notifies listeners on state change', () async {
      // Test state management
      var notified = false;
      service.addListener(() => notified = true);

      await service.updateState();

      expect(notified, isTrue);
    });
  });
}
```

### Test Coverage Requirements

For each Flutter service:
- ✅ Initialization success/failure
- ✅ State changes trigger notifyListeners()
- ✅ Authentication dependency handling
- ✅ Network errors and timeouts
- ✅ Graceful degradation
- ✅ Memory cleanup in dispose()

## Express.js Endpoint Tests

### Test Location
Create test files in: `test/api-backend/integration/` or `test/api-backend/security/`

### Test Structure

```javascript
import request from 'supertest';
import { expressServer } from '../../services/api-backend/server.js';

describe('{{Feature}} API Integration Tests', () => {
  let authToken;

  beforeAll(async () => {
    // Setup: Get valid auth token
    const response = await request(expressServer)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'password' });
    authToken = response.body.token;
  });

  describe('POST /api/{{feature}}', () => {
    it('should authenticate requests', async () => {
      const response = await request(expressServer)
        .post('/api/{{feature}}')
        .send({ data: 'test' });

      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('error');
    });

    it('should validate request schema', async () => {
      const response = await request(expressServer)
        .post('/api/{{feature}}')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ invalid: 'data' });

      expect(response.status).toBe(400);
    });

    it('should handle successful requests', async () => {
      const response = await request(expressServer)
        .post('/api/{{feature}}')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ data: 'valid' });

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('success', true);
    });

    it('should handle server errors gracefully', async () => {
      // Test with data that triggers server error
      const response = await request(expressServer)
        .post('/api/{{feature}}')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ triggerError: true });

      expect(response.status).toBe(500);
      expect(response.body).toHaveProperty('error');
    });
  });
});
```

### Test Coverage Requirements

For each Express.js endpoint:
- ✅ Authentication required (401 without token)
- ✅ Input validation (400 with invalid data)
- ✅ Happy path (200 with valid data)
- ✅ Server errors (500 with proper error response)
- ✅ Rate limiting (if applicable)
- ✅ CORS headers
- ✅ Logging occurs

## Authentication Tests

For auth-related changes, test in: `test/api-backend/security/authentication-authorization.test.js`

```javascript
describe('Auth0 JWT Validation', () => {
  it('should reject expired tokens', async () => {
    const expiredToken = generateExpiredToken();
    const response = await request(expressServer)
      .get('/api/protected')
      .set('Authorization', `Bearer ${expiredToken}`);

    expect(response.status).toBe(401);
  });

  it('should reject invalid signatures', async () => {
    const invalidToken = 'invalid.jwt.token';
    const response = await request(expressServer)
      .get('/api/protected')
      .set('Authorization', `Bearer ${invalidToken}`);

    expect(response.status).toBe(401);
  });

  it('should extract user context from valid token', async () => {
    const response = await request(expressServer)
      .get('/api/protected')
      .set('Authorization', `Bearer ${validToken}`);

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('userId');
  });
});
```

## Test Patterns to Follow

### Existing Test Files
- `test/services/auth_service_test.dart`
- `test/api-backend/security/authentication-authorization.test.js`
- `test/api-backend/integration/`

### Common Patterns
- Use `describe` blocks for feature grouping
- Use `beforeAll`/`afterAll` for setup/teardown
- Mock external dependencies (auth, database, network)
- Test both success and failure cases
- Verify side effects (logs, state changes, database writes)

## Running Tests

```bash
# Flutter tests
flutter test test/services/

# Backend integration tests
cd services/api-backend && npm test

# Backend security tests
cd services/api-backend && npm run test:security

# Specific test file
flutter test test/services/{{service}}_test.dart
```
