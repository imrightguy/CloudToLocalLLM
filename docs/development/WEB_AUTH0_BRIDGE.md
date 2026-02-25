# Web Auth0 Bridge Technical Documentation

## Overview

The Web Auth0 Bridge (`web/auth0-bridge.js`) is a JavaScript bridge that enables seamless authentication integration between Flutter web and the Auth0 SPA (Single Page Application) SDK. This bridge provides a standardized interface for authentication operations while handling the complexities of OAuth flows in a web environment.

## Architecture

### Bridge Pattern

The bridge uses a wrapper pattern to expose Auth0 functionality to Flutter web:

```javascript
// Global interface with function wrappers
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

### Why Function Wrappers?

The recent refactoring from direct function references to function wrappers provides several benefits:

1. **Better Flutter Interop**: Function wrappers ensure consistent behavior when called from Flutter's JavaScript interop
2. **Error Isolation**: Each wrapper can handle errors independently
3. **Future Extensibility**: Wrappers can be enhanced with additional logic without changing the interface
4. **Debugging**: Easier to debug and trace function calls

## Configuration

### Auth0 Settings

The bridge is configured with Auth0 tenant-specific settings:

```javascript
const AUTH0_DOMAIN = 'dev-vivn1fcgzi0c2czy.us.auth0.com';
const AUTH0_CLIENT_ID = 'FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A';
const AUTH0_AUDIENCE = 'https://dev-vivn1fcgzi0c2czy.us.auth0.com/api/v2/';
```

### Auth0 Client Initialization

```javascript
auth0 = new window.auth0.Auth0Client({
  domain: AUTH0_DOMAIN,
  clientId: AUTH0_CLIENT_ID,
  authorizationParams: {
    audience: AUTH0_AUDIENCE,
    redirect_uri: window.location.origin,
    scope: 'openid profile email offline_access',
  },
  cacheLocation: 'localstorage',
  useRefreshTokens: true,
});
```

## API Reference

### Authentication Methods

#### `login()`

Initiates the Auth0 login flow using redirect-based authentication.

**Behavior:**

1. Checks for existing valid session first
2. If valid session exists, notifies Flutter immediately
3. Otherwise, redirects to Auth0 login page

**Error Handling:**

- Catches and reports authentication errors to Flutter
- Provides error codes and messages for debugging

#### `logout()`

Logs out the current user and clears all session data.

**Behavior:**

1. Calls Auth0 logout with return URL
2. Clears local storage and session data
3. Redirects back to application origin

#### `handleRedirect()`

Processes the OAuth callback after successful authentication.

**Behavior:**

1. Handles Auth0 redirect callback
2. Extracts user information and access token
3. Cleans up URL parameters
4. Notifies Flutter of successful authentication
5. Redirects to intended destination

### User Information Methods

#### `getUser()`

Retrieves the current authenticated user's profile information.

**Returns:** User object with profile data or `null` if not authenticated

#### `getToken()`

Obtains a valid access token for API calls.

**Returns:** JWT access token string or `null` if not authenticated

**Features:**

- Automatically handles token refresh if needed
- Uses Auth0's silent authentication for seamless token renewal

#### `isAuthenticated()`

Checks if the user is currently authenticated.

**Returns:** Boolean indicating authentication status

## Flutter Integration

### JavaScript Interop Setup

Flutter web integrates with the bridge using JavaScript interop annotations:

```dart
@JS('Auth0Bridge.login')
external Future<void> auth0Login();

@JS('Auth0Bridge.logout')
external Future<void> auth0Logout();

@JS('Auth0Bridge.getUser')
external Future<dynamic> auth0GetUser();

@JS('Auth0Bridge.getToken')
external Future<String?> auth0GetToken();

@JS('Auth0Bridge.isAuthenticated')
external Future<bool> auth0IsAuthenticated();

@JS('Auth0Bridge.handleRedirect')
external Future<dynamic> auth0HandleRedirect();
```

### Callback Handling

The bridge communicates with Flutter through a global callback function:

```javascript
// Bridge notifies Flutter of authentication events
if (window.flutterAuthCallback) {
  window.flutterAuthCallback({
    type: 'success',
    user: user,
    accessToken: token,
  });
}
```

Flutter sets up the callback to receive these notifications:

```dart
@JS('window.flutterAuthCallback')
external set flutterAuthCallback(Function callback);

// Setup callback in Flutter
flutterAuthCallback = allowInterop((dynamic result) {
  // Handle authentication result
});
```

## Error Handling

### Error Types

The bridge provides comprehensive error handling with specific error types:

- `unknown_error`: General authentication failures
- `redirect_error`: OAuth callback processing failures
- `logout_error`: Logout process failures

### Error Structure

```javascript
{
  type: 'error',
  error: 'Human-readable error message',
  code: 'machine_readable_error_code'
}
```

## Session Management

### Automatic Session Detection

The bridge automatically detects existing valid sessions on initialization:

```javascript
// Check for existing session before starting new login
try {
  const user = await client.getUser();
  const token = await client.getTokenSilently();
  if (user && token) {
    // Notify Flutter of existing session
    return;
  }
} catch (e) {
  // No valid session, proceed with login
}
```

### Token Refresh

The bridge uses Auth0's built-in token refresh capabilities:

- `useRefreshTokens: true` enables automatic token refresh
- `offline_access` scope allows refresh token usage
- Silent authentication handles token renewal seamlessly

## Security Considerations

### Secure Configuration

- Uses `localstorage` for token caching (secure in HTTPS context)
- Implements proper CSRF protection through Auth0's state parameter
- Validates redirect URIs to prevent open redirect attacks

### Token Security

- Access tokens are short-lived (configurable in Auth0)
- Refresh tokens are securely stored and rotated
- Tokens are only accessible within the same origin

## Debugging

### Console Logging

The bridge provides detailed console logging for debugging:

```javascript
console.log('[Auth0 Bridge] Bridge loaded and ready');
console.log('[Auth0 Bridge] Starting login process...');
console.error('[Auth0 Bridge] Login failed:', error);
```

### Common Issues

1. **Auth0 SDK Not Loaded**: Ensure Auth0 SPA SDK script is included before the bridge
2. **Configuration Mismatch**: Verify Auth0 domain, client ID, and audience settings
3. **Callback URL Issues**: Ensure callback URLs are configured in Auth0 dashboard
4. **CORS Errors**: Verify allowed origins in Auth0 application settings

## Testing

### Manual Testing

1. **Login Flow**: Navigate to login page and verify redirect to Auth0
2. **Callback Handling**: Complete login and verify successful callback processing
3. **Session Persistence**: Refresh page and verify session is maintained
4. **Logout**: Verify complete logout and session cleanup

### Automated Testing

The bridge can be tested using Playwright or similar tools:

```javascript
// Example Playwright test
await page.goto('https://app.cloudtolocalllm.online');
await page.click('#login-button');
await page.waitForURL('**/auth0.com/**');
// Complete Auth0 login flow
```

## Maintenance

### Updating Auth0 SDK

When updating the Auth0 SPA SDK:

1. Update the script tag in `web/index.html`
2. Review breaking changes in Auth0 SDK documentation
3. Test all authentication flows thoroughly
4. Update configuration if API changes

### Configuration Updates

To update Auth0 configuration:

1. Modify constants in `auth0-bridge.js`
2. Update corresponding Flutter configuration
3. Verify callback URLs in Auth0 dashboard
4. Test authentication flows

## Future Enhancements

### Planned Improvements

- **Multi-factor Authentication**: Support for MFA flows
- **Social Login Customization**: Enhanced social provider integration
- **Progressive Web App**: Service worker integration for offline support
- **Analytics Integration**: Authentication event tracking

### Migration Considerations

- The bridge is designed to be Auth0-specific but follows patterns that could be adapted for other providers
- Function wrapper pattern makes it easier to swap implementations
- Clear separation between bridge logic and Auth0-specific code
