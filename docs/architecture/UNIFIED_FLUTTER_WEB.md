# Unified Flutter Web Architecture

## Overview

Zoidbot v3.10.3+ implements a unified Flutter-based web architecture that consolidates both marketing content and application functionality into a single codebase. This eliminates the need for separate static site containers while maintaining clear separation between marketing and application routes.

## Architecture Changes

### Before (Multi-Container)

```
zoidbot.online → static-site container (HTML/CSS)
app.zoidbot.online → flutter-app container (Flutter web)
docs.zoidbot.online → static-site container (VitePress docs)
```

### After (Unified Flutter)

```
zoidbot.online → flutter-app container (Flutter marketing pages)
app.zoidbot.online → flutter-app container (Flutter chat interface)
docs.zoidbot.online → static-site container (VitePress docs - unchanged)
```

## Domain Routing Strategy

### Main Domain (zoidbot.online)

- **Purpose**: Marketing homepage and download information
- **Routes**: `/` (homepage), `/download` (installation guide)
- **Platform**: Web-only (`kIsWeb` detection)
- **Authentication**: Not required for marketing content

### App Subdomain (app.zoidbot.online)

- **Purpose**: Main application interface
- **Routes**: `/chat`, `/settings`, `/login`, `/callback`
- **Platform**: Web and desktop
- **Authentication**: Required for application features
- **Redirect**: Root `/` redirects to `/chat`

### Docs Subdomain (docs.zoidbot.online)

- **Purpose**: Technical documentation
- **Technology**: VitePress (unchanged)
- **Container**: static-site (docs path only)

## Flutter Route Configuration

### Platform-Specific Routing with Lazy Loading

```dart
// Lazy load marketing screens
import '../screens/marketing/marketing_lazy.dart' deferred as marketing_lazy;

// Home route - platform-specific behavior
GoRoute(
  path: '/',
  name: 'home',
  builder: (context, state) {
    if (kIsWeb) {
      // Lazy load HomepageScreen
      return FutureBuilder<void>(
        future: marketing_lazy.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return marketing_lazy.HomepageScreen();
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    } else {
      return const HomeScreen(); // Desktop chat interface
    }
  },
),

// Lazy-loaded marketing routes
ShellRoute(
  builder: (context, state, child) {
    return FutureBuilder<void>(
      future: marketing_lazy.loadLibrary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return child;
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  },
  routes: marketing_lazy.marketingRoutes,
),
```

### Authentication Logic

```dart
redirect: (context, state) {
  final isHomepage = state.matchedLocation == '/' && kIsWeb;
  final isDownload = state.matchedLocation == '/download' && kIsWeb;
  
  // Allow marketing pages without authentication
  if (kIsWeb && (isHomepage || isDownload)) {
    return null;
  }
  
  // Require authentication for app routes
  if (!isAuthenticated) {
    return '/login';
  }
  
  return null;
},
```

### Web Authentication Bridge

For web platform authentication, the application uses a JavaScript bridge (`web/auth0-bridge.js`) that provides seamless integration between Flutter web and Auth0:

```javascript
// Auth0 Bridge provides standardized interface
window.Auth0Bridge = {
  login: function() { return window.auth0BridgeLogin(); },
  logout: function() { return window.auth0BridgeLogout(); },
  getUser: function() { return window.auth0BridgeGetUser(); },
  getToken: function() { return window.auth0BridgeGetToken(); },
  isAuthenticated: function() { return window.auth0BridgeIsAuthenticated(); },
  handleRedirect: function() { return window.auth0BridgeHandleRedirect(); },
};
```

**Key Features:**

- Function wrapper pattern for improved Flutter web interop
- Auth0 SPA SDK v2 compatibility
- Automatic session detection and token refresh
- OAuth callback handling with URL cleanup

## Implementation Details

### Marketing Screens

- **Location**: `lib/screens/marketing/`
- **Files**: `homepage_screen.dart`, `download_screen.dart`
- **Lazy Loading**: `marketing_lazy.dart` bundles screens for deferred loading
- **Design**: Material Design 3 with static site color scheme
- **Responsive**: Mobile-first responsive design
- **Content**: Replicates existing static site functionality

### Nginx Configuration

```nginx
# Main domain - Flutter marketing
server {
    server_name zoidbot.online;
    location / {
        proxy_pass http://flutter-app;
        # Flutter-specific headers
    }
}

# App subdomain - Flutter application
server {
    server_name app.zoidbot.online;
    location = / {
        return 302 /chat; # Redirect to chat interface
    }
    location / {
        proxy_pass http://flutter-app;
    }
}
```

## Benefits

### Unified Codebase

- Single Flutter application handles all web functionality
- Consistent theming and component library
- Shared authentication and state management
- Simplified deployment and maintenance

### Performance

- Single container for web functionality
- Shared Flutter assets and dependencies
- Reduced infrastructure complexity
- Faster build and deployment times
- **Optimized Loading**: Route-based code splitting reduces initial bundle size

### Developer Experience

- Single codebase for all web features
- Consistent development environment
- Shared tooling and testing infrastructure
- Simplified debugging and monitoring

## Migration Path

### Phase 1: Implementation ✅

- [x] Create Flutter marketing screens
- [x] Update router with platform detection
- [x] Configure nginx domain routing
- [x] Update Docker configuration
- [x] Implement route-based code splitting

### Phase 2: Testing

- [ ] Verify homepage functionality on main domain
- [ ] Test download page responsiveness
- [ ] Validate app subdomain chat access
- [ ] Confirm authentication flows

### Phase 3: Deployment

- [ ] Deploy updated nginx configuration
- [ ] Update DNS routing if needed
- [ ] Monitor traffic and performance
- [ ] Validate all domain endpoints

### Phase 4: Cleanup

- [ ] Remove static homepage files
- [ ] Deprecate static-site container (docs only)
- [ ] Update deployment scripts
- [ ] Archive legacy static content

## Verification Checklist

### Domain Access

- [ ] `zoidbot.online` → Flutter homepage
- [ ] `zoidbot.online/download` → Flutter download page
- [ ] `app.zoidbot.online` → Redirects to `/chat`
- [ ] `app.zoidbot.online/chat` → Flutter chat interface
- [ ] `docs.zoidbot.online` → VitePress documentation

### Platform Behavior

- [ ] Web: Marketing routes accessible without auth
- [ ] Web: App routes require authentication
- [ ] Desktop: Marketing routes excluded from build
- [ ] Desktop: Direct access to chat interface

### Responsive Design

- [ ] Homepage mobile responsiveness
- [ ] Download page code block formatting
- [ ] Navigation consistency
- [ ] Button and link functionality

## Future Considerations

### Static Site Container

The static-site container will be retained for documentation hosting but can be further optimized:

- Remove homepage-related configurations
- Focus solely on docs.zoidbot.online
- Consider migrating docs to Flutter in future versions

### Performance Optimization

- Optimize Flutter web bundle size
- Add progressive web app features
- Consider service worker caching
- **Completed**: Route-based code splitting

### SEO and Analytics

- Add meta tags for marketing pages
- Implement structured data
- Configure analytics tracking
- Optimize for search engines
