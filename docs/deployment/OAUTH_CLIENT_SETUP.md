# Google OAuth Client Setup for Zoidbot

This guide helps you set up Google OAuth Client IDs to fix the "401: invalid_client" error.

## Problem

You're seeing this error:

```
Error 401: invalid_client
Request details: flowName=GeneralOAuthFlow
```

This indicates that the Google OAuth Client ID in your configuration is invalid or missing.

## Solution

### Step 1: Access Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project: `zoidbot-468303`
3. Navigate to **APIs & Services** > **Credentials**

### Step 2: Create OAuth 2.0 Client IDs

You need to create separate client IDs for different platforms:

#### For Web Application (Flutter Web)

1. Click **+ CREATE CREDENTIALS** > **OAuth client ID**
2. Select **Web application**
3. Configure:
   - **Name**: `Zoidbot Web Client`
   - **Authorized JavaScript origins**:
     - `https://app.zoidbot.online`
     - `https://zoidbot.online`
     - `http://localhost:3000` (for development)
   - **Authorized redirect URIs**:
     - `https://app.zoidbot.online/callback`
     - `https://app.zoidbot.online`
     - `http://localhost:3000/callback` (for development)

#### For Desktop Application (Flutter Desktop)

1. Click **+ CREATE CREDENTIALS** > **OAuth client ID**
2. Select **Desktop application**
3. Configure:
   - **Name**: `Zoidbot Desktop Client`
   - No additional configuration needed for desktop apps

#### For Mobile Application (if needed)

1. Click **+ CREATE CREDENTIALS** > **OAuth client ID**
2. Select **Android** or **iOS**
3. Configure package name and signing certificate

### Step 3: Update Configuration

After creating the client IDs, update your configuration:

```dart
// In lib/config/app_config.dart

// For Web Application
static const String googleClientIdWeb = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

// For Desktop Application  
static const String googleClientIdDesktop = 'YOUR_DESKTOP_CLIENT_ID.apps.googleusercontent.com';

// Choose the appropriate one based on platform
static String get googleClientId {
  if (kIsWeb) {
    return googleClientIdWeb;
  } else {
    return googleClientIdDesktop;
  }
}
```

### Step 4: Platform-Specific Configuration

#### Web Configuration

For Flutter Web, you may also need to add the client ID to your `web/index.html`:

```html
<meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
```

#### Desktop Configuration

For desktop applications, ensure the redirect URI handling is properly configured in your OAuth flow.

### Step 5: Verify GCIP Configuration

Also verify your Google Cloud Identity Platform settings:

1. Go to **Identity and Access Management** > **Identity Platform**
2. Check **Providers** tab
3. Ensure Google is enabled as a provider
4. Verify the client ID matches what you're using in the app

### Step 6: Test the Configuration

1. Update the client ID in your code
2. Rebuild and redeploy your application
3. Test the OAuth flow
4. Check for any remaining authentication errors

## Common Issues and Solutions

### Issue: "redirect_uri_mismatch"

**Solution**: Ensure the redirect URI in your OAuth request exactly matches one of the authorized redirect URIs in your Google Cloud Console.

### Issue: "unauthorized_client"

**Solution**: Verify that the client ID is correct and that the OAuth client is configured for the correct application type (web, desktop, mobile).

### Issue: "access_denied"

**Solution**: Check that the user has permission to access the application and that the OAuth consent screen is properly configured.

## Security Best Practices

1. **Environment-Specific Client IDs**: Use different client IDs for development, staging, and production
2. **Restrict Origins**: Only add necessary origins to the authorized list
3. **Regular Rotation**: Consider rotating client secrets periodically
4. **Monitor Usage**: Monitor OAuth usage in Google Cloud Console

## Debugging Tips

1. **Check Browser Console**: Look for detailed error messages in the browser developer tools
2. **Network Tab**: Examine the OAuth requests and responses
3. **Google Cloud Logs**: Check logs in Google Cloud Console for authentication events
4. **Test with curl**: Test the OAuth endpoints directly to isolate issues

## Example Configuration

Here's an example of a properly configured OAuth client:

```dart
class AppConfig {
  // Production Web Client ID
  static const String googleClientIdWeb = '123456789-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com';
  
  // Production Desktop Client ID
  static const String googleClientIdDesktop = '123456789-zyxwvutsrqponmlkjihgfedcba.apps.googleusercontent.com';
  
  // Development Web Client ID
  static const String googleClientIdWebDev = '123456789-devwebclientid.apps.googleusercontent.com';
  
  // Choose appropriate client ID based on environment and platform
  static String get googleClientId {
    if (kDebugMode) {
      return kIsWeb ? googleClientIdWebDev : googleClientIdDesktop;
    } else {
      return kIsWeb ? googleClientIdWeb : googleClientIdDesktop;
    }
  }
}
```

## Next Steps

After fixing the OAuth configuration:

1. Test the authentication flow thoroughly
2. Verify that user sessions persist correctly
3. Check that all OAuth scopes are working
4. Monitor for any remaining authentication errors
5. Update your CI/CD pipeline to use the correct client IDs

For additional help, refer to:

- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [Google Cloud Identity Platform Documentation](https://cloud.google.com/identity-platform/docs)
- [Flutter Google Sign-In Documentation](https://pub.dev/packages/google_sign_in)
