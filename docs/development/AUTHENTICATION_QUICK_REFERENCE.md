# Authentication Quick Reference

## Current Status

✅ **All authentication issues have been fixed and verified**

## Key Configuration

### Frontend (web/auth0-bridge.js)

```javascript
const AUTH0_AUDIENCE = 'https://api.cloudtolocalllm.online';
```

### Backend (services/api-backend/middleware/auth.js)

```javascript
const DEFAULT_JWT_AUDIENCE = 'https://api.cloudtolocalllm.online';
const JWT_AUDIENCE = process.env.JWT_AUDIENCE || DEFAULT_JWT_AUDIENCE;
```

## Authentication Flow

```
User Login
    ↓
Auth0 OAuth Flow (web/auth0-bridge.js)
    ↓
Auth0 Issues Token with Audience: https://api.cloudtolocalllm.online
    ↓
Frontend Stores Token (flutter_secure_storage)
    ↓
API Request with Authorization Header
    ↓
Backend Validates Token (services/api-backend/middleware/auth.js)
    ├─ Check HS256 (fast path)
    └─ Check RS256 via JWKS (full path)
    ↓
Backend Verifies Audience Matches
    ↓
✅ Token Accepted → API Response
❌ Token Rejected → 401 Unauthorized
```

## Common Issues & Solutions

### 401 Unauthorized on API Calls

**Cause**: Token has wrong audience or is expired

**Solution**:

1. Clear browser cache: `DevTools → Application → Clear Storage`
2. Re-login to get new token with correct audience
3. Verify backend is running latest code

### Token Validation Fails in Backend

**Cause**: JWKS endpoint not accessible or Auth0 misconfigured

**Solution**:

1. Test JWKS endpoint: `curl https://dev-vivn1fcgzi0c2czy.us.auth0.com/.well-known/jwks.json`
2. Verify Auth0 application identifier is set correctly
3. Check backend logs for detailed error messages

## Testing Checklist

- [ ] Clear browser cache
- [ ] Login successfully
- [ ] App loads after login
- [ ] API calls return 200/201 (not 401)
- [ ] Authorization header present in requests
- [ ] Backend logs show successful token validation
- [ ] User tier and other data loads correctly

## Files to Know

| File | Purpose |
|------|---------|
| `web/auth0-bridge.js` | Frontend Auth0 configuration and OAuth flow |
| `services/api-backend/middleware/auth.js` | Backend JWT validation middleware |
| `services/api-backend/auth/auth-service.js` | Token validation and session management |
| `lib/services/auth_service.dart` | Flutter authentication service |

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `AUTH0_AUDIENCE` | `https://api.cloudtolocalllm.online` | Expected token audience |
| `AUTH0_JWKS_URI` | `https://dev-vivn1fcgzi0c2czy.us.auth0.com/.well-known/jwks.json` | JWKS endpoint for token validation |
| `SUPABASE_JWT_SECRET` | (required) | Secret for HS256 token validation |
| `JWT_AUDIENCE` | `https://api.cloudtolocalllm.online` | Alias for AUTH0_AUDIENCE |

## Debugging

### Enable Debug Logging

**Frontend** (browser console):

```javascript
// Already enabled - look for [Auth0 Bridge] messages
```

**Backend** (check logs):

```
[Auth] Token verification successful (Audience verified)
[Auth] User authenticated via RS256: <user-id>
```

### Inspect Token

**In Browser Console**:

```javascript
// Get token from storage
const token = localStorage.getItem('auth0.access_token');

// Decode token (without verification)
const decoded = JSON.parse(atob(token.split('.')[1]));
console.log(decoded);

// Check audience claim
console.log('Audience:', decoded.aud);
console.log('Expected:', 'https://api.cloudtolocalllm.online');
```

### Test Backend Token Validation

**Using curl**:

```bash
# Get token from browser first, then:
curl -H "Authorization: Bearer <token>" \
  https://api.cloudtolocalllm.online/user/tier
```

## Deployment

### Development

1. Update `web/auth0-bridge.js` with correct audience
2. Deploy web app
3. Test login flow
4. Verify API calls work

### Production

1. Ensure backend has correct `AUTH0_AUDIENCE` environment variable
2. Deploy web app with updated `auth0-bridge.js`
3. Deploy backend with token validation middleware
4. Monitor logs for successful token validation
5. Test end-to-end login flow

## Related Documentation

- `AUTHENTICATION_FIX_SUMMARY.md` - What was fixed
- `AUTHENTICATION_STATUS_REPORT.md` - Current status and verification
- `docs/DEVELOPMENT/AUTH0_AUDIENCE_FIX.md` - Technical details
- `docs/DEVELOPMENT/WEB_AUTH0_BRIDGE.md` - Auth0 bridge implementation

## Support

For authentication issues:

1. Check this quick reference
2. Review related documentation
3. Check browser console and backend logs
4. Verify environment variables are set correctly
5. Contact development team with logs
