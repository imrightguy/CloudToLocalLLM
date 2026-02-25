# Auth0 Audience Mismatch Fix

## Problem Summary

After successful Auth0 login, the Flutter web app was making API calls that all failed with 401 (Unauthorized) errors:

- `POST /auth/sessions` → 400 (Bad Request)
- `GET /user/tier` → 401 (Unauthorized)
- `GET /ollama/bridge/status` → 401 (Unauthorized)
- `PUT /conversations/conv_*` → 401 (Unauthorized)

## Root Cause

**Audience Mismatch**: The frontend and backend were configured with different Auth0 audiences.

### Frontend Configuration (web/auth0-bridge.js)

```javascript
const AUTH0_AUDIENCE = 'https://dev-vivn1fcgzi0c2czy.us.auth0.com/api/v2/';
```

This is the Auth0 Management API audience, used for managing Auth0 resources.

### Backend Configuration (services/api-backend/middleware/auth.js)

```javascript
const DEFAULT_JWT_AUDIENCE = 'https://api.cloudtolocalllm.online';
const JWT_AUDIENCE = process.env.JWT_AUDIENCE || DEFAULT_JWT_AUDIENCE;
```

The backend expects the application's own API audience.

### What Happens

1. Frontend requests Auth0 token with audience: `https://dev-vivn1fcgzi0c2czy.us.auth0.com/api/v2/`
2. Auth0 issues token with this audience claim
3. Frontend sends token in Authorization header: `Bearer <token>`
4. Backend receives token and validates it
5. Backend checks audience claim: expects `https://api.cloudtolocalllm.online`
6. Token has audience: `https://dev-vivn1fcgzi0c2czy.us.auth0.com/api/v2/`
7. **Audience mismatch → Token rejected with 401**

## Solution

### 1. Fix Frontend Audience (web/auth0-bridge.js)

Change the Auth0 audience to match the backend configuration:

```javascript
// BEFORE (WRONG)
const AUTH0_AUDIENCE = 'https://dev-vivn1fcgzi0c2czy.us.auth0.com/api/v2/';

// AFTER (CORRECT)
const AUTH0_AUDIENCE = 'https://api.cloudtolocalllm.online';
```

### 2. Ensure Backend Environment Configuration

The backend needs to have the correct AUTH0_AUDIENCE environment variable set:

```bash
# In your deployment environment (.env or Kubernetes secrets)
AUTH0_AUDIENCE=https://api.cloudtolocalllm.online
```

Or use the default which is already set in the code:

```javascript
const DEFAULT_JWT_AUDIENCE = 'https://api.cloudtolocalllm.online';
```

### 3. Verify Auth0 Application Configuration

In Auth0 dashboard, ensure the application is configured with:

- **Identifier (Audience)**: `https://api.cloudtolocalllm.online`
- This tells Auth0 to include this audience in the token

## Implementation Details

### Frontend Changes

- **File**: `web/auth0-bridge.js`
- **Change**: Update `AUTH0_AUDIENCE` constant
- **Impact**: New tokens will have the correct audience claim

### Backend Changes

- **No code changes needed** - backend already expects the correct audience
- **Environment**: Ensure `AUTH0_AUDIENCE` environment variable is set (or use default)

### Token Flow After Fix

1. Frontend requests token with audience: `https://api.cloudtolocalllm.online`
2. Auth0 issues token with this audience claim
3. Frontend sends token in Authorization header
4. Backend validates token
5. Backend checks audience: expects `https://api.cloudtolocalllm.online`
6. Token has audience: `https://api.cloudtolocalllm.online`
7. **Audience matches → Token accepted ✓**

## Testing the Fix

### 1. Clear Browser Cache

- Clear all cookies and local storage for the app domain
- This ensures old tokens are not reused

### 2. Login Again

- The app will request a new token with the correct audience
- Auth0 will issue a token with the correct audience claim

### 3. Verify API Calls

- Check browser DevTools Network tab
- Verify Authorization header is present: `Authorization: Bearer <token>`
- Verify API calls return 200/201 instead of 401

### 4. Check Backend Logs

- Look for successful token validation messages
- Should see: `Token verification successful (Audience verified)`

## Related Files

- **Frontend**: `web/auth0-bridge.js` - Auth0 SPA SDK configuration
- **Backend Auth Middleware**: `services/api-backend/middleware/auth.js` - Token validation
- **Backend Auth Service**: `services/api-backend/auth/auth-service.js` - JWKS validation
- **Dart Auth Service**: `lib/services/auth_service.dart` - Token usage in API calls

## Additional Notes

### Why This Matters

The audience claim in a JWT token is a security feature that ensures:

1. The token is intended for a specific API/application
2. Tokens cannot be reused for different applications
3. Prevents token misuse across different services

### Auth0 Audience vs Management API

- **Application Audience** (what we use): Identifies the application's API
  - Example: `https://api.cloudtolocalllm.online`
  - Used for: Authenticating users to the application

- **Management API Audience** (what was wrong): Identifies Auth0's management API
  - Example: `https://dev-vivn1fcgzi0c2czy.us.auth0.com/api/v2/`
  - Used for: Managing Auth0 resources (users, applications, etc.)

### Future Considerations

1. **Environment-Specific Audiences**: Consider using different audiences for dev/staging/prod
2. **Auth0 Configuration**: Ensure Auth0 application is configured with the correct identifier
3. **Documentation**: Update deployment guides to include AUTH0_AUDIENCE configuration
