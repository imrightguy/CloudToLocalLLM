# Zoidbot Authentication Guide

## Overview

This guide provides comprehensive documentation for authenticating with the Zoidbot API. The API uses OAuth2 with Auth0 for user authentication and JWT tokens for API access.

**Validates: Requirements 12.8**

- Create authentication documentation with OAuth2 flow
- Add JWT token examples and refresh token flow
- Implement authentication guides for different client types

## Table of Contents

1. [Authentication Methods](#authentication-methods)
2. [OAuth2 Flow](#oauth2-flow)
3. [JWT Token Management](#jwt-token-management)
4. [Client-Specific Guides](#client-specific-guides)
5. [Security Best Practices](#security-best-practices)
6. [Troubleshooting](#troubleshooting)

## Authentication Methods

The Zoidbot API supports two authentication methods:

### 1. JWT Bearer Token (User Authentication)

Used for user-initiated requests. Tokens are obtained through OAuth2 flow with Auth0.

```
Authorization: Bearer <JWT_TOKEN>
```

### 2. API Key (Service-to-Service)

Used for backend service communication and integrations.

```
X-API-Key: <API_KEY>
```

## OAuth2 Flow

### Overview

Zoidbot uses Auth0 for OAuth2 authentication. The flow follows the standard OAuth2 Authorization Code flow with PKCE (Proof Key for Code Exchange) for enhanced security.

### OAuth2 Configuration

```
Auth0 Domain: dev-v2f2p008x3dr74ww.us.auth0.com
Client ID: <YOUR_CLIENT_ID>
Audience: https://api.zoidbot.online
Redirect URI: https://app.zoidbot.online/callback
```

### Authorization Code Flow (Recommended)

The Authorization Code flow is the most secure method for user authentication.

#### Step 1: Redirect User to Auth0

Redirect the user to Auth0's authorization endpoint:

```
https://dev-v2f2p008x3dr74ww.us.auth0.com/authorize?
  client_id=YOUR_CLIENT_ID&
  response_type=code&
  redirect_uri=https://app.zoidbot.online/callback&
  scope=openid profile email&
  audience=https://api.zoidbot.online&
  state=STATE_VALUE&
  code_challenge=CODE_CHALLENGE&
  code_challenge_method=S256
```

**Parameters:**

- `client_id` - Your Auth0 application ID
- `response_type` - Must be `code` for Authorization Code flow
- `redirect_uri` - Where Auth0 redirects after authentication
- `scope` - Requested permissions (openid, profile, email)
- `audience` - API identifier
- `state` - Random string to prevent CSRF attacks
- `code_challenge` - PKCE code challenge (SHA256 hash of code_verifier)
- `code_challenge_method` - Must be `S256` for PKCE

#### Step 2: User Authenticates

The user logs in with their Auth0 credentials. Auth0 redirects back to your redirect_uri with an authorization code:

```
https://app.zoidbot.online/callback?
  code=AUTH_CODE&
  state=STATE_VALUE
```

#### Step 3: Exchange Code for Tokens

Exchange the authorization code for access and refresh tokens:

```bash
curl -X POST https://dev-v2f2p008x3dr74ww.us.auth0.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET",
    "code": "AUTH_CODE",
    "grant_type": "authorization_code",
    "redirect_uri": "https://app.zoidbot.online/callback",
    "code_verifier": "CODE_VERIFIER"
  }'
```

**Response:**

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IkpXVEtFWSJ9...",
  "refresh_token": "refresh_eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IkpXVEtFWSJ9...",
  "token_type": "Bearer",
  "expires_in": 86400
}
```

### PKCE Implementation

PKCE (Proof Key for Code Exchange) adds an extra layer of security for public clients.

#### Generate Code Verifier and Challenge

```javascript
// Generate random code verifier (43-128 characters)
function generateCodeVerifier() {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return btoa(String.fromCharCode.apply(null, array))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

// Generate code challenge from verifier
async function generateCodeChallenge(verifier) {
  const encoder = new TextEncoder();
  const data = encoder.encode(verifier);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return btoa(String.fromCharCode.apply(null, new Uint8Array(digest)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

// Usage
const codeVerifier = generateCodeVerifier();
const codeChallenge = await generateCodeChallenge(codeVerifier);
```

## JWT Token Management

### Token Structure

JWT tokens consist of three parts separated by dots: `header.payload.signature`

#### Example JWT Token

```
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IkpXVEtFWSJ9.
eyJpc3MiOiJodHRwczovL2Rldi12MmYycDAwOHgzZHI3NHd3LnVzLmF1dGgwLmNvbS8iLCJzdWIiOiJhdXRoMHw2MzQ1YTJmZjEyMzQ1Njc4OTBhYmNkZWYiLCJhdWQiOlsiaHR0cHM6Ly9hcGkuY2xvdWR0b2xvY2FsbGxtLm9ubGluZSIsImh0dHBzOi8vZGV2LXYyZjJwMDA4eDNkcjc0d3cudXMuYXV0aDAuY29tL3VzZXJpbmZvIl0sImlhdCI6MTY3MzgwNDAwMCwiZXhwIjoxNjczODkwNDAwLCJhenAiOiJZb3VyQ2xpZW50SWQiLCJzY29wZSI6Im9wZW5pZCBwcm9maWxlIGVtYWlsIn0.
SIGNATURE_HERE
```

#### Decoded Payload

```json
{
  "iss": "https://dev-v2f2p008x3dr74ww.us.auth0.com/",
  "sub": "auth0|6345a2ff123456789abcdef",
  "aud": [
    "https://api.zoidbot.online",
    "https://dev-v2f2p008x3dr74ww.us.auth0.com/userinfo"
  ],
  "iat": 1673804000,
  "exp": 1673890400,
  "azp": "YourClientId",
  "scope": "openid profile email"
}
```

### Token Expiry and Refresh

Tokens expire after 24 hours. Use the refresh token to obtain a new access token without requiring user re-authentication.

#### Check Token Expiry

```bash
curl -X POST https://api.zoidbot.online/auth/token/check-expiry \
  -H "Content-Type: application/json" \
  -d '{
    "token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
  }'
```

**Response:**

```json
{
  "shouldRefresh": true,
  "expiresIn": 240,
  "expiresAt": "2024-01-15T12:00:00Z"
}
```

#### Refresh Token

```bash
curl -X POST https://api.zoidbot.online/auth/token/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "refreshToken": "refresh_eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }'
```

**Response:**

```json
{
  "accessToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "tokenType": "Bearer",
  "expiresIn": 86400,
  "refreshToken": "refresh_eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Token Validation

Validate a token before using it:

```bash
curl -X POST https://api.zoidbot.online/auth/token/validate \
  -H "Content-Type: application/json" \
  -d '{
    "token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
  }'
```

**Response:**

```json
{
  "valid": true,
  "expired": false,
  "expiring": false,
  "expiresIn": 82400,
  "expiresAt": "2024-01-15T12:00:00Z",
  "userId": "auth0|6345a2ff123456789abcdef",
  "email": "user@example.com"
}
```

### Get Current User Info

```bash
curl -X GET https://api.zoidbot.online/auth/me \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

```json
{
  "userId": "auth0|6345a2ff123456789abcdef",
  "email": "user@example.com",
  "name": "John Doe",
  "picture": "https://s.gravatar.com/avatar/...",
  "emailVerified": true,
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

### Logout and Token Revocation

```bash
curl -X POST https://api.zoidbot.online/auth/logout \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

```json
{
  "success": true,
  "message": "Logged out successfully",
  "userId": "auth0|6345a2ff123456789abcdef"
}
```

## Client-Specific Guides

### Web Application (JavaScript/TypeScript)

#### Installation

```bash
npm install @auth0/auth0-spa-js
```

#### Configuration

```javascript
import { Auth0Client } from '@auth0/auth0-spa-js';

const auth0 = new Auth0Client({
  domain: 'dev-v2f2p008x3dr74ww.us.auth0.com',
  clientId: 'YOUR_CLIENT_ID',
  authorizationParams: {
    redirect_uri: window.location.origin + '/callback',
    audience: 'https://api.zoidbot.online',
    scope: 'openid profile email'
  }
});
```

#### Login

```javascript
// Initiate login
async function login() {
  await auth0.loginWithPopup();
  const user = await auth0.getUser();
  console.log('Logged in as:', user);
}

// Get access token
async function getAccessToken() {
  const token = await auth0.getTokenSilently();
  return token;
}
```

#### Making API Requests

```javascript
async function makeAuthenticatedRequest(endpoint) {
  const token = await auth0.getTokenSilently();
  
  const response = await fetch(`https://api.zoidbot.online${endpoint}`, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  });
  
  return response.json();
}

// Usage
const tunnels = await makeAuthenticatedRequest('/tunnels');
```

#### Logout

```javascript
async function logout() {
  await auth0.logout({
    logoutParams: {
      returnTo: window.location.origin
    }
  });
}
```

### Desktop Application (Flutter/Dart)

#### Installation

```yaml
dependencies:
  flutter_appauth: ^6.0.0
  flutter_secure_storage: ^9.0.0
  jwt_decoder: ^2.0.0
```

#### Configuration

```dart
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const FlutterAppAuth _appAuth = FlutterAppAuth();
const _secureStorage = FlutterSecureStorage();

const _auth0Domain = 'dev-v2f2p008x3dr74ww.us.auth0.com';
const _clientId = 'YOUR_CLIENT_ID';
const _redirectUrl = 'com.zoidbot://callback';
const _audience = 'https://api.zoidbot.online';
```

#### Login

```dart
Future<void> login() async {
  try {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _clientId,
        _redirectUrl,
        discoveryUrl: 'https://$_auth0Domain/.well-known/openid-configuration',
        scopes: ['openid', 'profile', 'email'],
        promptValues: ['login'],
        additionalParameters: {
          'audience': _audience,
        },
      ),
    );

    if (result != null) {
      // Store tokens securely
      await _secureStorage.write(
        key: 'access_token',
        value: result.accessToken,
      );
      await _secureStorage.write(
        key: 'refresh_token',
        value: result.refreshToken ?? '',
      );
      
      print('Login successful');
    }
  } catch (e) {
    print('Login failed: $e');
  }
}
```

#### Making API Requests

```dart
Future<Map<String, dynamic>> makeAuthenticatedRequest(String endpoint) async {
  final token = await _secureStorage.read(key: 'access_token');
  
  final response = await http.get(
    Uri.parse('https://api.zoidbot.online$endpoint'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );
  
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else if (response.statusCode == 401) {
    // Token expired, refresh it
    await refreshToken();
    return makeAuthenticatedRequest(endpoint);
  } else {
    throw Exception('API request failed: ${response.statusCode}');
  }
}
```

#### Token Refresh

```dart
Future<void> refreshToken() async {
  try {
    final refreshToken = await _secureStorage.read(key: 'refresh_token');
    
    final response = await http.post(
      Uri.parse('https://api.zoidbot.online/auth/token/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      await _secureStorage.write(
        key: 'access_token',
        value: data['accessToken'],
      );
      
      if (data['refreshToken'] != null) {
        await _secureStorage.write(
          key: 'refresh_token',
          value: data['refreshToken'],
        );
      }
    }
  } catch (e) {
    print('Token refresh failed: $e');
  }
}
```

#### Logout

```dart
Future<void> logout() async {
  try {
    await http.post(
      Uri.parse('https://api.zoidbot.online/auth/logout'),
      headers: {
        'Authorization': 'Bearer ${await _secureStorage.read(key: 'access_token')}',
      },
    );
    
    // Clear stored tokens
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
    
    print('Logout successful');
  } catch (e) {
    print('Logout failed: $e');
  }
}
```

### Mobile Application (React Native)

#### Installation

```bash
npm install @react-native-async-storage/async-storage react-native-app-auth
```

#### Configuration

```javascript
import * as SecureStore from 'expo-secure-store';
import * as AppAuth from 'expo-app-auth';

const config = {
  issuer: 'https://dev-v2f2p008x3dr74ww.us.auth0.com',
  clientId: 'YOUR_CLIENT_ID',
  redirectUrl: 'com.zoidbot://callback',
  scopes: ['openid', 'profile', 'email'],
  audience: 'https://api.zoidbot.online',
};
```

#### Login

```javascript
async function login() {
  try {
    const result = await AppAuth.authAsync(config);
    
    if (result) {
      // Store tokens securely
      await SecureStore.setItemAsync('access_token', result.accessToken);
      await SecureStore.setItemAsync('refresh_token', result.refreshToken);
      
      console.log('Login successful');
    }
  } catch (error) {
    console.error('Login failed:', error);
  }
}
```

#### Making API Requests

```javascript
async function makeAuthenticatedRequest(endpoint) {
  const token = await SecureStore.getItemAsync('access_token');
  
  const response = await fetch(`https://api.zoidbot.online${endpoint}`, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  });
  
  if (response.status === 401) {
    // Token expired, refresh it
    await refreshToken();
    return makeAuthenticatedRequest(endpoint);
  }
  
  return response.json();
}
```

### Backend Service (Node.js)

#### Installation

```bash
npm install jsonwebtoken axios
```

#### Configuration

```javascript
import jwt from 'jsonwebtoken';
import axios from 'axios';

const SUPABASE_AUTH_DOMAIN = 'dev-v2f2p008x3dr74ww.us.auth0.com';
const SUPABASE_AUTH_CLIENT_ID = process.env.SUPABASE_AUTH_CLIENT_ID;
const SUPABASE_AUTH_CLIENT_SECRET = process.env.SUPABASE_AUTH_CLIENT_SECRET;
const API_AUDIENCE = 'https://api.zoidbot.online';
```

#### Get Access Token (Machine-to-Machine)

```javascript
async function getAccessToken() {
  try {
    const response = await axios.post(
      `https://${SUPABASE_AUTH_DOMAIN}/oauth/token`,
      {
        client_id: SUPABASE_AUTH_CLIENT_ID,
        client_secret: SUPABASE_AUTH_CLIENT_SECRET,
        audience: API_AUDIENCE,
        grant_type: 'client_credentials',
      }
    );
    
    return response.data.access_token;
  } catch (error) {
    console.error('Failed to get access token:', error);
    throw error;
  }
}
```

#### Making API Requests

```javascript
async function makeAuthenticatedRequest(endpoint, method = 'GET', data = null) {
  const token = await getAccessToken();
  
  const config = {
    method,
    url: `https://api.zoidbot.online${endpoint}`,
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  };
  
  if (data) {
    config.data = data;
  }
  
  const response = await axios(config);
  return response.data;
}

// Usage
const tunnels = await makeAuthenticatedRequest('/tunnels');
```

#### Verify JWT Token

```javascript
function verifyToken(token) {
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    return decoded;
  } catch (error) {
    console.error('Token verification failed:', error);
    return null;
  }
}
```

## Security Best Practices

### 1. Token Storage

**Web Applications:**

- Store tokens in memory or session storage (not localStorage)
- Use httpOnly cookies for refresh tokens
- Never expose tokens in URLs

**Desktop/Mobile Applications:**

- Use secure storage (flutter_secure_storage, Keychain, Keystore)
- Never store tokens in plain text
- Encrypt tokens at rest

### 2. Token Transmission

- Always use HTTPS in production
- Include tokens in Authorization header: `Bearer <token>`
- Never include tokens in query parameters or request body

### 3. Token Refresh

- Refresh tokens proactively before expiry
- Implement automatic token refresh on 401 responses
- Store refresh tokens securely
- Rotate refresh tokens regularly

### 4. CORS Configuration

- Configure CORS to allow only trusted origins
- Use credentials: 'include' for cross-origin requests
- Validate origin headers on the server

### 5. PKCE for Public Clients

- Always use PKCE for public clients (web, mobile, desktop)
- Generate cryptographically secure code verifiers
- Use SHA256 for code challenge

### 6. Logout

- Always revoke tokens on logout
- Clear stored tokens from secure storage
- Invalidate sessions on the server

### 7. Error Handling

- Don't expose sensitive information in error messages
- Log authentication failures for security monitoring
- Implement rate limiting on authentication endpoints

### 8. Token Validation

- Validate token signature
- Check token expiry
- Verify token audience and issuer
- Validate token claims

## Troubleshooting

### Common Issues

#### 1. Invalid Token Error

**Error:** `Invalid token format` or `INVALID_TOKEN`

**Solution:**

- Ensure token is included in Authorization header
- Use format: `Authorization: Bearer <token>`
- Check token hasn't expired
- Verify token is not corrupted

#### 2. Token Expired

**Error:** `Token expired` or `exp claim is in the past`

**Solution:**

- Refresh token using `/auth/token/refresh` endpoint
- Implement automatic token refresh
- Check system clock is synchronized

#### 3. CORS Error

**Error:** `Access to XMLHttpRequest blocked by CORS policy`

**Solution:**

- Verify redirect_uri matches configured value
- Check CORS headers in API response
- Ensure request includes proper headers
- Verify origin is whitelisted

#### 4. Refresh Token Invalid

**Error:** `Invalid refresh token` or `INVALID_REFRESH_TOKEN`

**Solution:**

- Ensure refresh token is stored correctly
- Check refresh token hasn't expired (7 days)
- Verify refresh token format
- Re-authenticate if refresh token is invalid

#### 5. Unauthorized Access

**Error:** `401 Unauthorized` or `INVALID_TOKEN`

**Solution:**

- Verify token is valid and not expired
- Check user has required permissions
- Verify token includes correct audience
- Check Authorization header format

### Debug Mode

Enable debug logging to troubleshoot authentication issues:

```javascript
// JavaScript
localStorage.setItem('debug', 'auth0:*');

// Node.js
process.env.DEBUG = 'auth0:*';
```

### Support

For authentication issues:

- Check [API Documentation](./API_DOCUMENTATION_GUIDE.md)
- Review [Error Codes](./API_ERROR_CODES.md)
- Contact support@zoidbot.online
- Visit https://docs.zoidbot.online
