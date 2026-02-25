# Auth0 Migration Guide

This guide documents the migration from Entra ID (Azure AD B2C) to Auth0 authentication for the CloudToLocalLLM application.

## Overview

The application has been migrated from Entra ID to Auth0 for improved authentication capabilities, better developer experience, and enhanced security features.

## Auth0 Setup Commands

### 1. Create Auth0 Tenant

```bash
auth0 tenants create --name "CloudToLocalLLM"
auth0 tenants list
```

### 2. Create Single Page Application

```bash
auth0 apps create --type spa --name "CloudToLocalLLM Frontend"
auth0 apps list
```

### 3. Configure SPA Settings

```bash
auth0 apps update <app-id> --callbacks "http://localhost:3000,https://yourapp.com"
auth0 apps update <app-id> --logout-urls "http://localhost:3000,https://yourapp.com"
auth0 apps update <app-id> --origins "http://localhost:3000,https://yourapp.com"
```

### 4. Create API Resource

```bash
auth0 apis create --name "CloudToLocalLLM API" --identifier "https://api.CloudToLocalLLM.com"
auth0 apis list
```

### 5. Configure Social Logins (Optional)

```bash
# Google OAuth
auth0 connections create --strategy google-oauth2 --name "google"

# GitHub
auth0 connections create --strategy github --name "github"
```

### 6. Create Test Users

```bash
auth0 users create --email "test@example.com" --password "TempPass123!"
auth0 users list
```

## Environment Variables

### Backend Environment Variables (.env)

Replace the Entra ID variables with Auth0 equivalents:

```bash
# Auth0 Configuration (replace Entra variables)
AUTH0_JWKS_URI=https://your-tenant.auth0.com/.well-known/jwks.json
AUTH0_AUDIENCE=https://api.CloudToLocalLLM.com

# Remove old Entra variables
# ENTRA_JWKS_URI=...
# ENTRA_AUDIENCE=...
```

### Frontend Environment Variables

Add these to your Flutter environment configuration:

```dart
// lib/config/auth_config.dart
class AuthConfig {
  static const String domain = 'your-tenant.auth0.com';
  static const String clientId = 'your-spa-client-id';
  static const String audience = 'https://api.CloudToLocalLLM.com';
  static const String scheme = 'CloudToLocalLLM';
}
```

## Code Changes

### Backend Changes

1. **Updated `services/api-backend/auth/auth-service.js`**:
   - Changed `ENTRA_JWKS_URI` to `AUTH0_JWKS_URI`
   - Changed `ENTRA_AUDIENCE` to `AUTH0_AUDIENCE`
   - Updated initialization message

### Frontend Changes

1. **Updated `pubspec.yaml`**:
   - Replaced `aad_oauth` with `auth0_flutter: ^1.4.0`

2. **New Auth0 Provider** (`lib/auth/providers/auth0_auth_provider.dart`):
   - Implements AuthProvider interface
   - Uses Auth0 Flutter SDK
   - Handles web authentication flows
   - Manages token storage and refresh

3. **Web Auth0 Bridge** (`web/auth0-bridge.js`):
   - JavaScript bridge for Flutter web Auth0 integration
   - Exposes Auth0Bridge global interface with proper function wrappers
   - Handles Auth0 SPA SDK initialization and authentication flows
   - Provides seamless interop between Flutter web and Auth0 JavaScript SDK
   - **Recent Update**: Refactored global interface to use function wrappers for improved Flutter web interop

## Migration Steps

### 1. Auth0 Infrastructure Setup

- [ ] Create Auth0 tenant
- [ ] Create SPA application
- [ ] Configure callback/logout URLs
- [ ] Create API resource
- [ ] Set up social connections (optional)

### 2. Backend Migration

- [ ] Update environment variables
- [ ] Deploy updated backend code
- [ ] Verify JWT validation works

### 3. Frontend Migration

- [ ] Update pubspec.yaml dependencies
- [ ] Replace AadOAuth provider with Auth0AuthProvider
- [ ] Update authentication configuration
- [ ] Test login/logout flows

### 4. Testing

- [ ] Test JWT token exchange
- [ ] Verify user authentication
- [ ] Test social logins (if enabled)
- [ ] Validate API access with new tokens

## Web Auth0 Bridge Implementation

### JavaScript Bridge Architecture

The `web/auth0-bridge.js` file provides a JavaScript bridge between Flutter web and the Auth0 SPA SDK:

```javascript
// Global interface with proper function wrappers
window.Auth0Bridge = {
  login: function() {
    return window.auth0BridgeLogin();
  },
  logout: function() {
    return window.auth0BridgeLogout();
  },
  getUser: function() {
    return window.auth0BridgeGetUser();
  },
  getToken: function() {
    return window.auth0BridgeGetToken();
  },
  isAuthenticated: function() {
    return window.auth0BridgeIsAuthenticated();
  },
  handleRedirect: function() {
    return window.auth0BridgeHandleRedirect();
  },
};
```

### Key Features

- **Function Wrappers**: Uses proper function wrappers instead of direct references for better Flutter web interop
- **Auth0 SPA SDK v2**: Compatible with Auth0 SPA JavaScript SDK v2.x
- **Automatic Initialization**: Initializes Auth0 client on first use
- **Session Management**: Handles existing session detection and token refresh
- **Error Handling**: Comprehensive error handling with Flutter callback notifications
- **Redirect Handling**: Manages OAuth callback flows and URL cleanup

### Configuration

The bridge is configured with Auth0 tenant settings:

```javascript
const AUTH0_DOMAIN = 'dev-vivn1fcgzi0c2czy.us.auth0.com';
const AUTH0_CLIENT_ID = 'FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A';
const AUTH0_AUDIENCE = 'https://dev-vivn1fcgzi0c2czy.us.auth0.com/api/v2/';
```

### Flutter Integration

Flutter web calls the bridge functions via JavaScript interop:

```dart
// Example Flutter web integration
@JS('Auth0Bridge.login')
external Future<void> auth0Login();

@JS('Auth0Bridge.getUser')
external Future<dynamic> auth0GetUser();
```

## Key Differences: Entra ID vs Auth0

| Feature | Entra ID (Azure AD B2C) | Auth0 |
|---------|------------------------|-------|
| JWKS URI | `https://tenant.b2clogin.com/.../discovery/v2.0/keys` | `https://tenant.auth0.com/.well-known/jwks.json` |
| Token Format | JWT with custom claims | Standard JWT with Auth0 claims |
| Social Logins | Limited Azure AD integrations | Extensive social provider support |
| Developer Tools | Azure CLI, Portal | Auth0 CLI, Dashboard, extensive APIs |
| Customization | Policy-based (complex) | Rules, Actions, Hooks (flexible) |
| Pricing | Azure subscription-based | Usage-based with generous free tier |

## Security Considerations

1. **Token Validation**: Auth0 uses RS256 by default, matching the existing setup
2. **Audience Validation**: Ensure API audience matches Auth0 API identifier
3. **Scopes**: Define appropriate scopes for API access
4. **Refresh Tokens**: Auth0 supports offline_access scope for refresh tokens

## Troubleshooting

### Common Issues

1. **Invalid Audience Error**:
   - Ensure `AUTH0_AUDIENCE` matches the API identifier in Auth0
   - Check that the SPA is configured with the correct audience

2. **Callback URL Mismatch**:
   - Verify callback URLs in Auth0 SPA settings
   - Ensure scheme matches Flutter app configuration

3. **Token Expiration**:
   - Auth0 tokens have configurable expiration
   - Implement proper token refresh logic

### Testing Commands

```bash
# Test login flow
auth0 test login --client-id <client-id> --domain <domain>

# List users
auth0 users list

# Check API configuration
auth0 apis list
```

## Deployment Checklist

- [ ] Auth0 tenant created and configured
- [ ] SPA application settings updated
- [ ] API resource created
- [ ] Environment variables updated
- [ ] Backend deployed with new configuration
- [ ] Frontend updated with Auth0 provider
- [ ] Dependencies updated and tested
- [ ] Authentication flows tested end-to-end
- [ ] Social logins configured (if needed)
- [ ] Documentation updated

## Next Steps

1. Monitor authentication logs in Auth0 dashboard
2. Set up Auth0 Actions for custom authentication logic
3. Configure multi-factor authentication if required
4. Set up Auth0 Organizations for multi-tenancy (if needed)
5. Implement user profile management features

## Support

For Auth0-specific issues:

- Auth0 Documentation: https://auth0.com/docs
- Auth0 Community: https://community.auth0.com
- Auth0 CLI Documentation: https://github.com/auth0/auth0-cli

For application-specific issues, refer to the main project documentation.
