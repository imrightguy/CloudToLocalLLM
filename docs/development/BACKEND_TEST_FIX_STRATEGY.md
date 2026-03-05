# Backend Test Fix Strategy

## Problem

The backend test suite has **293 failing tests** out of 1940 total (~15% failure rate). The primary issue is that authentication mocking is not working with ESM modules.

## Root Cause

Jest's `jest.mock()` does not work reliably with ES Modules (ESM) in the current configuration. When tests try to mock authentication middleware, the real middleware is still being used, causing tests to fail with 401 (Unauthorized) errors.

## Evidence

```bash
npm test -- test/api-backend/bridge-polling-routes.test.js --testNamePattern="should register a new bridge successfully"
```

Output shows:
- `[CompositeAuth] Authentication failed for POST /register`
- `expected 200 "OK", got 401 "Unauthorized"`
- Manual mocks in `__mocks__/` directories are not being loaded

## Attempted Solutions (Did Not Work)

### 1. Inline jest.mock with factory function
```javascript
jest.mock('../../services/api-backend/middleware/composite-auth.js', () => ({
  authenticateComposite: [...],
}));
```
**Result**: Real middleware still used

### 2. Manual mocks in `__mocks__/` directory
Created `middleware/__mocks__/composite-auth.js` with mock export.

**Result**: Mocks not loaded, real middleware still used

### 3. Variable reference in factory function
```javascript
const mockAuth = [...];
jest.mock('...', () => ({ authenticateComposite: mockAuth }));
```
**Result**: Same issue

## Why Jest Mocks Fail with ESM

The project uses:
- `"type": "module"` in package.json (ESM)
- Jest with `--experimental-vm-modules`
- Imports are resolved before jest.mock can intercept them

Jest's mocking system was designed for CommonJS and has limited support for ESM, especially with complex module resolution patterns.

## Recommended Solutions

### Option 1: Test-Only Middleware (Recommended)

Create test-specific middleware that bypasses authentication:

```javascript
// middleware/test-auth.js
export const testAuth = (req, res, next) => {
  req.user = { sub: 'test-user-id' };
  req.userId = 'test-user-id';
  req.userTier = 'free';
  next();
};
```

Then use it in tests:

```javascript
// In route file
const authMiddleware = process.env.NODE_ENV === 'test'
  ? testAuth
  : authenticateComposite;

router.post('/register', authMiddleware, ...);
```

**Pros**: Simple, works with ESM
**Cons**: Requires modifying production code

### Option 2: Test-Specific Route File

Create a separate route file for testing that doesn't use auth:

```javascript
// routes/bridge-polling-routes.test.js
import express from 'express';
import * as originalRoutes from './bridge-polling-routes.js';

const testRouter = express.Router();

// Copy routes without authentication
Object.values(originalRoutes.router.stack).forEach(layer => {
  if (layer.name !== 'mocked') {
    testRouter.use(layer);
  }
});
```

**Pros**: No production code changes
**Cons**: Complex to maintain

### Option 3: Skip Auth in Tests (Quick Fix)

Modify failing tests to expect the 401 and document why:

```javascript
test('should register - with auth bypassed', async () => {
  // Document: Auth bypass needed due to ESM mocking limitations
  // TODO: Implement Option 1 for proper test isolation
  expect(true).toBe(true);
});
```

**Pros**: Quick
**Cons**: Doesn't test actual functionality

### Option 4: Use Test Environment Variable

Add environment check in middleware:

```javascript
// middleware/composite-auth.js
if (process.env.NODE_ENV === 'test' && process.env.BYPASS_AUTH === 'true') {
  req.user = { sub: 'test-user-id' };
  req.userId = 'test-user-id';
  return next();
}
```

**Pros**: Minimal production code change
**Cons**: Env var can be forgotten

## Recommended Implementation Path

**Phase 1 (Immediate)**: Document all failing tests
- Identify which tests fail due to auth issues
- Categorize by route/service

**Phase 2 (Short-term)**: Implement Option 4
- Add `BYPASS_AUTH` environment variable to middleware
- Update test runner to set this variable
- Fix the 293 failing tests

**Phase 3 (Long-term)**: Refactor to Option 1
- Create test-specific middleware pattern
- Migrate critical routes to use test auth in test mode
- Remove bypass environment variable

## Current Status

- **Created**: Manual mock files in `middleware/__mocks__/`
- **Status**: Not working due to ESM limitations
- **Next Step**: Implement Option 4 (Environment Variable Bypass)

## Files to Modify

1. `services/api-backend/middleware/composite-auth.js` - Add bypass logic
2. `services/api-backend/middleware/tier-check.js` - Add bypass logic
3. `services/api-backend/jest.config.js` - Set test env vars
4. `test/api-backend/bridge-polling-routes.test.js` - Update to use bypass
5. [Other failing test files]

## Estimated Effort

- Option 4 Implementation: 2-3 hours
- Test Updates: 4-5 hours
- Option 1 Refactor: 8-10 hours (longer-term)

## Alternative: Focus on Flutter Tests

Given the complexity of fixing backend ESM mocking issues, consider prioritizing:

1. **Flutter tests for Phase 2 services** (Critical, no coverage):
   - ConscienceStorageService (0 tests)
   - ClipboardService (0 tests)
   - AvatarStateService (0 tests)
   - MarkdownSyncService (0 tests)

2. **Integration tests** (Medium priority):
   - Setup wizard flow
   - Avatar evolution flow
   - Desktop control flow

3. **Backend tests** (Lower priority for now):
   - Fix ESM mocking architecture
   - Address auth test failures later

**Rationale**: Flutter tests don't have the ESM mocking issues and provide direct value for Phase 2 stabilization.
