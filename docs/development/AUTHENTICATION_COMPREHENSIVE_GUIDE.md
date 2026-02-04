# Zoidbot Authentication Comprehensive Guide

**Last Updated**: December 15, 2025  
**Status**: ✅ ALL AUTHENTICATION SYSTEMS OPERATIONAL

---

## Quick Start

**New to authentication issues?** Start here:

1. **Problem**: Auth0 login succeeded but API calls failed with 401 errors
2. **Root Cause**: Token audience mismatch between frontend and backend
3. **Solution**: Updated frontend to request tokens with correct audience
4. **Status**: ✅ FIXED - All systems operational

---

## What Was Wrong

After successful Auth0 login, all API calls failed with 401 errors because:

- **Frontend** requested tokens with audience: `https://dev-vivn1fcgzi0c2czy.us.auth0.com/api/v2/` (Auth0 Management API)
- **Backend** expected tokens with audience: `https://api.zoidbot.online` (Application API)
- **Result**: Audience mismatch → Backend rejected tokens → 401 Unauthorized

## What Was Fixed

### Single Critical Change

**File**: `web/auth0-bridge.js`

```javascript
// BEFORE (WRONG)
const AUTH0_AUDIENCE = 'https://dev-vivn1fcgzi0c2czy.us.auth0.com/api/v2/';

// AFTER (CORRECT)  
const AUTH0_AUDIENCE = 'https://api.zoidbot.online';
```

**That's it.** This single change fixed all authentication issues.

### Service Worker Simplification

**Removed**: Unnecessary service worker patches
**Reason**: Flutter web automatically manages service workers - no manual intervention needed

---

## Current Architecture

### Token Flow

```
User Login
    ↓
Auth0 OAuth Flow  
    ↓
Auth0 Issues Token (Audience: https://api.zoidbot.online)
    ↓
Frontend Stores Token
    ↓
API Request with Authorization Header
    ↓
Backend Validates Token
    ├─ Signature: ✅ Valid
    ├─ Audience: ✅ Matches  
    └─ Expiry: ✅ Valid
    ↓
✅ API Response (200/201)
```

### Components

#### Frontend (web/auth0-bridge.js)

- **Auth0 Domain**: `dev-vivn1fcgzi0c2czy.us.auth0.com`
- **Client ID**: `FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A`
- **Audience**: `https://api.zoidbot.online` ✅
- **Scope**: `openid profile email offline_access`

#### Backend (services/api-backend/middleware/auth.js)

- **Expected Audience**: `https://api.zoidbot.online`
- **JWKS URI**: `https://dev-vivn1fcgzi0c2czy.us.auth0.com/.well-known/jwks.json`
- **Validation**: RS256 signature + audience verification

---

## Environment Configuration

### Backend Environment Variables

```bash
# Required (or uses default)
AUTH0_AUDIENCE=https://api.zoidbot.online
AUTH0_JWKS_URI=https://dev-vivn1fcgzi0c2czy.us.auth0.com/.well-known/jwks.json

# For HS256 fallback (internal tokens)
SUPABASE_JWT_SECRET=(configured)
```

### Frontend Configuration

- Configured in `web/auth0-bridge.js`
- No environment variables needed
- Uses Auth0 SPA SDK from CDN

---

## Testing & Verification

### Manual Testing Checklist

```
1. ✅ Clear browser cache
2. ✅ Navigate to app
3. ✅ Click login button
4. ✅ Complete Auth0 authentication  
5. ✅ Verify app loads without timeout warnings
6. ✅ Check API calls return 200/201 (not 401)
7. ✅ Verify user data loads correctly
```

### API Endpoints Verified

- ✅ `POST /auth/sessions` - Create authenticated session
- ✅ `GET /user/tier` - Get user tier information
- ✅ `GET /ollama/bridge/status` - Get Ollama bridge status
- ✅ `PUT /conversations/:id` - Update conversations
- ✅ All other protected endpoints

### Backend Log Verification

Look for: `Token verification successful (Audience verified)`

---

## Troubleshooting

### Still Getting 401 Errors?

1. **Clear browser cache completely**
   - DevTools → Application → Clear Storage
   - Close all browser tabs and reopen

2. **Verify backend configuration**
   - Check `AUTH0_AUDIENCE` environment variable
   - Restart backend service if needed

3. **Check Auth0 configuration**
   - Verify application identifier is `https://api.zoidbot.online`
   - Check Auth0 dashboard settings

### Token Validation Fails?

1. **Test JWKS endpoint**

   ```bash
   curl https://dev-vivn1fcgzi0c2czy.us.auth0.com/.well-known/jwks.json
   ```

2. **Check token expiration**
   - Decode token at jwt.io
   - Verify `exp` claim is not expired

3. **Verify audience claim**
   - Decode token and check `aud` field
   - Should be: `https://api.zoidbot.online`

---

## Deployment

### Build and Deploy

```bash
# Build web app
flutter build web --release

# Deploy to hosting
# (Deploy updated web/auth0-bridge.js)

# Users clear browser cache and re-login
# Done!
```

### Rollback Plan

If issues occur:

1. Revert `web/auth0-bridge.js` to previous version
2. Clear CDN cache
3. Notify users to clear browser cache
4. Investigate and fix root cause

---

## Files Modified

| File | Change | Status |
|------|--------|--------|
| `web/auth0-bridge.js` | Updated audience | ✅ FIXED |
| `web/service-worker-init.js` | Deleted | ✅ SIMPLIFIED |
| `web/index.html` | Removed SW patch | ✅ CLEANED |

---

## Related Documentation

### Technical Details

- `docs/DEVELOPMENT/AUTH0_AUDIENCE_FIX.md` - Technical deep dive
- `docs/DEVELOPMENT/WEB_AUTH0_BRIDGE.md` - Bridge implementation
- `services/api-backend/middleware/auth.js` - Backend authentication code

### External Resources

- [Auth0 Documentation](https://auth0.com/docs)
- [JWT.io](https://jwt.io) - JWT debugging
- [JWKS Specification](https://tools.ietf.org/html/rfc7517)

---

## Support & Escalation

### For Developers

1. Check browser console for error messages
2. Review backend logs for token validation details
3. Verify environment variables are set correctly
4. Test JWKS endpoint accessibility

### For Production Issues

1. Check monitoring dashboards
2. Review error logs and authentication success rates
3. Verify Auth0 service status
4. Escalate with logs and reproduction steps

---

## Status Summary

**✅ ALL SYSTEMS OPERATIONAL**

| Component | Status | Details |
|-----------|--------|---------|
| Frontend Auth0 Bridge | ✅ OPERATIONAL | Correct audience configured |
| Backend Token Validation | ✅ OPERATIONAL | Audience verification working |
| API Endpoints | ✅ PROTECTED | All endpoints properly secured |
| Service Workers | ✅ SIMPLIFIED | Flutter manages automatically |
| Error Handling | ✅ COMPREHENSIVE | Detailed error messages |
| Documentation | ✅ COMPLETE | Comprehensive guides available |

**Ready for Production**: ✅ YES  
**Confidence Level**: ✅ HIGH  
**Recommendation**: System is fully operational and ready for production use.

---

**Last Updated**: December 15, 2025  
**Status**: READY FOR PRODUCTION ✅
