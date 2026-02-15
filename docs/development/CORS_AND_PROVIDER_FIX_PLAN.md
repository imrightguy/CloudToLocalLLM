# CORS and Provider Fix Plan

## Issues Identified

1. **CORS Preflight Failures**: Multiple endpoints failing with "No 'Access-Control-Allow-Origin' header is present on the requested resource"
   - `/auth/sessions` (POST)
   - `/api/user/tier` (GET)
   - `/ollama/bridge/status` (GET)
   - `/api/conversations/*` (PUT)
   - `/api/client-logs` (POST)

2. **Provider Not Found Error**: `Provider<minified:bmF> not found for minified:On` in `local_llm_providers_category.dart`

3. **AdminCenterService Not Registered**: Error when accessing in `UnifiedSettingsScreen`

## Root Causes

### 1. CORS Preflight Issues

- **Problem**: CORS middleware order might be incorrect
- **Issue**: `app.options('*', ...)` handler might be redundant or conflicting
- **Issue**: Helmet CSP might be interfering with CORS headers
- **Issue**: Rate limiting middleware might be blocking OPTIONS requests

### 2. Provider Not Found

- **Problem**: `context.read<ProviderConfigurationManager>()` called in `initState()` before provider is available
- **Location**: `lib/widgets/settings/local_llm_providers_category.dart:67`

### 3. AdminCenterService

- **Problem**: Service is registered in `setupAuthenticatedServices()` which is called after authentication
- **Issue**: `UnifiedSettingsScreen` tries to access it before authentication completes

## Fix Strategy

### Phase 1: Fix CORS Configuration (Priority: CRITICAL)

1. **Reorder Middleware**:
   - Move CORS middleware to be the FIRST middleware (before Helmet, rate limiting, body parsing)
   - Ensure `app.options('*', ...)` is placed correctly

2. **Fix CORS Options**:
   - Ensure `maxAge` is set for preflight caching
   - Verify `allowedHeaders` includes all necessary headers
   - Check that `credentials: true` is properly configured

3. **Helmet Configuration**:
   - Adjust Helmet CSP to not interfere with CORS
   - Ensure `crossOriginResourcePolicy` is set correctly

4. **Rate Limiting**:
   - Ensure rate limiting doesn't block OPTIONS requests
   - Add exception for preflight requests

### Phase 2: Fix Provider Access (Priority: HIGH)

1. **Safe Provider Access**:
   - Change `context.read<ProviderConfigurationManager>()` to use `Provider.of` with error handling
   - Or use `context.watch` with null safety
   - Add fallback if provider is not available

2. **Provider Availability Check**:
   - Add check before accessing provider
   - Show loading state if provider not available

### Phase 3: Fix AdminCenterService Registration (Priority: MEDIUM)

1. **Registration Timing**:
   - Ensure `AdminCenterService` is registered before `UnifiedSettingsScreen` tries to access it
   - Or make the access pattern more defensive

2. **Error Handling**:
   - The try-catch is already there, but improve error message

## Implementation Steps

### Step 1: Fix CORS Middleware Order and Configuration

```javascript
// Move CORS to be FIRST middleware (before Helmet)
// CORS configuration - must be before ALL other middleware
const corsOptions = {
  origin: function (origin, callback) {
    const allowedOrigins = [
      'https://app.zoidbot.online',
      'https://zoidbot.online',
      'https://docs.zoidbot.online'
    ];
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin || allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'Origin'],
  exposedHeaders: ['Content-Length', 'X-Requested-With'],
  maxAge: 86400, // Cache preflight for 24 hours
  preflightContinue: false,
  optionsSuccessStatus: 204
};

// Apply CORS FIRST
app.use(cors(corsOptions));

// Handle preflight requests explicitly BEFORE other routes
app.options('*', cors(corsOptions));
```

### Step 2: Adjust Helmet Configuration

```javascript
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ['\'self\''],
      connectSrc: ['\'self\'', 'https:'],
      scriptSrc: ['\'self\'', '\'unsafe-inline\''],
      styleSrc: ['\'self\'', '\'unsafe-inline\''],
      imgSrc: ['\'self\'', 'data:', 'https:'],
    },
  },
  crossOriginResourcePolicy: { policy: 'cross-origin' }, // Allow CORS
}));
```

### Step 3: Fix Rate Limiting for OPTIONS

```javascript
const createConditionalRateLimiter = () => {
  // ... existing code ...
  return (req, res, next) => {
    // Skip rate limiting for OPTIONS (preflight) requests
    if (req.method === 'OPTIONS') {
      return next();
    }
    // ... rest of rate limiting logic ...
  };
};
```

### Step 4: Fix Provider Access in local_llm_providers_category.dart

```dart
@override
void initState() {
  super.initState();
  // Use safer provider access pattern
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      try {
        _configManager = Provider.of<ProviderConfigurationManager>(context, listen: false);
        _loadProviders();
      } catch (e) {
        debugPrint('[LocalLLMProviders] ProviderConfigurationManager not available: $e');
        setState(() {
          _errorMessage = 'Provider configuration manager not available';
        });
      }
    }
  });
}
```

### Step 5: Ensure AdminCenterService is Available

The current code already has try-catch, but we should ensure it's registered early enough. The issue might be that it's only registered after authentication, but settings screen might be accessed before full auth completes.

## Testing Checklist

- [ ] Test CORS preflight for all failing endpoints
- [ ] Verify OPTIONS requests return 204 with proper headers
- [ ] Test actual requests (GET, POST, PUT) work after preflight
- [ ] Verify ProviderConfigurationManager is accessible in settings
- [ ] Test AdminCenterService access in UnifiedSettingsScreen
- [ ] Verify no console errors in browser
- [ ] Test authentication flow end-to-end

## Expected Outcomes

1. All CORS preflight requests succeed
2. All API endpoints accessible from web app
3. No provider not found errors
4. AdminCenterService accessible when needed
5. Clean browser console with no CORS errors
