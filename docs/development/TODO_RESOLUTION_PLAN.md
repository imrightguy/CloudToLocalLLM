# TODO Resolution Plan

This document outlines the plan to resolve all TODO comments found in the codebase.

## Summary

**Total TODOs Found:** 15  
**Categories:**

- Flutter/Dart UI: 4 TODOs
- Backend/API: 2 TODOs
- Streaming Proxy: 6 TODOs
- Web/Config: 1 TODO
- Build System: 2 TODOs

## Priority Classification

### High Priority (User-Facing Features)

1. Subscription tier retrieval (account_settings_category.dart)
2. Admin status check (account_settings_category.dart)
3. Premium tier check (platform_category_filter.dart)
4. Theme provider integration (general_settings_category.dart)

### Medium Priority (Infrastructure)

1. Window manager integration (desktop_settings_category.dart)
2. Alerting system integration (pool-monitor.js)
3. Cloud SQL migration (migrate-database.js)
4. TURN server credential security (web/config/config.js)

### Low Priority (Production Enhancements)

1. Connection acceptance blocking (graceful-shutdown-manager.ts)
2. In-flight request tracking (graceful-shutdown-manager.ts)
3. SSH disconnect messages (graceful-shutdown-manager.ts, ssh-connection-impl.ts)
4. Client notification (graceful-shutdown-manager.ts)
5. Custom shutdown metrics (shutdown-event-logger.ts)
6. Admin auth for diagnostics (health endpoints)
7. CMakeLists.txt refactoring (Windows/Linux)

---

## Detailed Implementation Plans

### 1. Subscription Tier Retrieval

**File:** `lib/widgets/settings/account_settings_category.dart`  
**Current:** Returns hardcoded 'Free'  
**Solution:**

- Use `EnhancedUserTierService` from service locator
- Access `currentTier` property
- Listen to tier changes via `ChangeNotifier`
- Display tier name (free/premium/enterprise)

**Dependencies:**

- `EnhancedUserTierService` (already exists)
- Service locator access

**Estimated Effort:** 1-2 hours

---

### 2. Admin Status Check

**File:** `lib/widgets/settings/account_settings_category.dart`  
**Current:** Returns hardcoded `false`  
**Solution:**

- Check user roles from `AuthService` or `AdminService`
- Look for 'admin' or 'super_admin' role in user profile
- Cache result to avoid repeated checks

**Dependencies:**

- User profile/roles from AuthService
- AdminService for role checking

**Estimated Effort:** 1-2 hours

---

### 3. Theme Provider Integration

**File:** `lib/widgets/settings/general_settings_category.dart`  
**Current:** Only logs theme changes  
**Solution:**

1. Create `ThemeProvider` service extending `ChangeNotifier`
2. Store theme preference in `SharedPreferences` or `AppConfig`
3. Update `MaterialApp.router` themeMode property
4. Listen to theme changes and rebuild app

**Implementation Steps:**

```dart
// Create ThemeProvider service
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _savePreference(mode);
    notifyListeners();
  }
}

// In main.dart
final themeProvider = ThemeProvider();
// Use in MaterialApp.router: themeMode: themeProvider.themeMode
```

**Dependencies:**

- SharedPreferences or AppConfig for persistence
- MaterialApp.router access

**Estimated Effort:** 3-4 hours

---

### 4. Premium Tier Check

**File:** `lib/services/platform_category_filter.dart`  
**Current:** Returns hardcoded `false`  
**Solution:**

- Use `EnhancedUserTierService.isPremiumTier` property
- Remove caching logic (service already handles this)
- Access service from service locator

**Dependencies:**

- `EnhancedUserTierService` (already exists)

**Estimated Effort:** 1 hour

---

### 5. Window Manager Integration

**File:** `lib/widgets/settings/desktop_settings_category.dart`  
**Current:** No implementation  
**Solution:**

1. Add `window_manager` package to `pubspec.yaml`
2. Import and initialize window manager
3. Implement:
   - `windowManager.setAlwaysOnTop(_alwaysOnTop)`
   - Launch on startup (platform-specific)
   - Minimize to tray (via `tray_manager` package)

**Implementation Steps:**

```dart
import 'package:window_manager/window_manager.dart';

Future<void> _applyWindowBehaviorChanges() async {
  await windowManager.setAlwaysOnTop(_alwaysOnTop);
  // Handle startup and tray integration
}
```

**Dependencies:**

- `window_manager` package
- `tray_manager` package (for minimize to tray)
- Platform-specific startup configuration

**Estimated Effort:** 4-6 hours

---

### 6. Alerting System Integration

**File:** `services/api-backend/database/pool-monitor.js`  
**Current:** Only logs alerts  
**Solution:**

1. Create alerting service abstraction
2. Support multiple backends (email, Slack, PagerDuty)
3. Configure via environment variables
4. Implement rate limiting for alerts

**Implementation Steps:**

```javascript
// Create alerting service
class AlertingService {
  async sendAlert(type, data) {
    // Send to configured channels
    if (process.env.ALERT_EMAIL_ENABLED) {
      await this.sendEmail(type, data);
    }
    if (process.env.ALERT_SLACK_ENABLED) {
      await this.sendSlack(type, data);
    }
    // etc.
  }
}
```

**Dependencies:**

- Email service (nodemailer)
- Slack webhook integration
- PagerDuty API integration

**Estimated Effort:** 6-8 hours

---

### 7. Cloud SQL Migration

**File:** `config/cloudrun/migrate-database.js`  
**Current:** Falls back to SQLite  
**Solution:**

1. Add Cloud SQL connection using `pg` package
2. Use Cloud SQL Proxy or direct connection
3. Implement migration logic similar to SQLite
4. Handle connection pooling

**Implementation Steps:**

```javascript
async function initializeCloudSQL() {
  const pool = new Pool({
    host: config.dbHost,
    port: config.dbPort,
    database: config.dbName,
    user: config.dbUser,
    password: config.dbPassword,
    ssl: config.dbSsl,
  });
  // Run migrations
}
```

**Dependencies:**

- `pg` package
- Cloud SQL credentials
- Migration scripts

**Estimated Effort:** 4-6 hours

---

### 8. TURN Server Credential Security

**File:** `web/config/config.js`  
**Current:** Empty credential string  
**Solution:**

1. Fetch credentials from API endpoint (authenticated)
2. Or inject via environment variable at build time
3. Never expose in client-side code

**Implementation Steps:**

```javascript
// Option 1: Fetch from API
async function loadTurnCredentials() {
  const response = await fetch('/api/turn/credentials');
  const data = await response.json();
  window.cloudToLocalLLMConfig.turnServer.credential = data.credential;
}

// Option 2: Inject at build time
// Use environment variable: TURN_CREDENTIAL
```

**Dependencies:**

- API endpoint for credential retrieval
- Authentication for credential endpoint

**Estimated Effort:** 2-3 hours

---

### 9. Connection Acceptance Blocking

**File:** `services/streaming-proxy/src/connection-pool/graceful-shutdown-manager.ts`  
**Current:** No implementation  
**Solution:**

1. Add `isShuttingDown` flag to WebSocket server
2. Check flag before accepting new connections
3. Return appropriate error to rejected connections

**Implementation Steps:**

```typescript
// In WebSocket server
private isShuttingDown = false;

on('connection', (ws) => {
  if (this.isShuttingDown) {
    ws.close(1001, 'Server shutting down');
    return;
  }
  // Accept connection
});
```

**Dependencies:**

- WebSocket server instance access
- Shutdown state management

**Estimated Effort:** 2-3 hours

---

### 10. In-Flight Request Tracking

**File:** `services/streaming-proxy/src/connection-pool/graceful-shutdown-manager.ts`  
**Current:** Uses connection count as proxy  
**Solution:**

1. Track active requests per connection
2. Maintain request counter
3. Wait for counter to reach zero

**Implementation Steps:**

```typescript
private activeRequests = new Map<string, number>();

incrementRequest(connectionId: string) {
  const count = this.activeRequests.get(connectionId) || 0;
  this.activeRequests.set(connectionId, count + 1);
}

decrementRequest(connectionId: string) {
  const count = this.activeRequests.get(connectionId) || 0;
  if (count > 0) {
    this.activeRequests.set(connectionId, count - 1);
  }
}
```

**Dependencies:**

- Request lifecycle hooks
- Connection ID tracking

**Estimated Effort:** 3-4 hours

---

### 11. SSH Disconnect Messages

**Files:**

- `services/streaming-proxy/src/connection-pool/graceful-shutdown-manager.ts`
- `services/streaming-proxy/src/connection-pool/ssh-connection-impl.ts`

**Current:** No implementation  
**Solution:**

1. Use SSH2 library's `end()` method
2. Send proper disconnect message
3. Handle errors gracefully

**Implementation Steps:**

```typescript
async sendSSHDisconnect(userId: string, reason?: string) {
  const connection = await this.pool.getConnection(userId);
  if (connection && connection.sshClient) {
    await connection.sshClient.end();
  }
}
```

**Dependencies:**

- SSH2 library
- Connection pool access

**Estimated Effort:** 2-3 hours

---

### 12. Client Notification

**File:** `services/streaming-proxy/src/connection-pool/graceful-shutdown-manager.ts`  
**Current:** No implementation  
**Solution:**

1. Access WebSocket server instance
2. Iterate through all connected clients
3. Send close frame with code 1001

**Implementation Steps:**

```typescript
private async notifyClientsOfShutdown(): Promise<void> {
  for (const client of this.wss.clients) {
    if (client.readyState === WebSocket.OPEN) {
      client.close(1001, 'Server shutting down');
    }
  }
}
```

**Dependencies:**

- WebSocket server instance
- Client iteration

**Estimated Effort:** 1-2 hours

---

### 13. Custom Shutdown Metrics

**File:** `services/streaming-proxy/src/utils/shutdown-event-logger.ts`  
**Current:** No implementation  
**Solution:**

1. Create metrics recording interface
2. Integrate with monitoring system (Prometheus, StatsD, etc.)
3. Record shutdown duration, connections closed, errors

**Implementation Steps:**

```typescript
recordShutdownMetrics(result: ShutdownResult) {
  metrics.gauge('shutdown.duration', result.duration);
  metrics.gauge('shutdown.connections_closed', result.connectionsClosed);
  metrics.counter('shutdown.errors', result.errors.length);
}
```

**Dependencies:**

- Metrics library (Prometheus client, StatsD, etc.)

**Estimated Effort:** 2-3 hours

---

### 14. Admin Auth for Diagnostics

**Files:**

- `services/streaming-proxy/src/health/README.md`
- `services/streaming-proxy/src/health/QUICK_START.md`
- `services/streaming-proxy/src/health/TASK_14_COMPLETION.md`

**Current:** Diagnostics endpoints are public  
**Solution:**

1. Add authentication middleware
2. Check for admin role/token
3. Return 403 for unauthorized requests

**Implementation Steps:**

```typescript
function requireAdminAuth(req: Request, res: Response, next: NextFunction) {
  const token = req.headers.authorization;
  if (!isAdminToken(token)) {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
}

app.use('/health/diagnostics', requireAdminAuth);
```

**Dependencies:**

- Authentication service
- Admin role checking

**Estimated Effort:** 2-3 hours

---

### 15. CMakeLists.txt Refactoring

**Files:**

- `windows/flutter/CMakeLists.txt`
- `linux/flutter/CMakeLists.txt`

**Current:** Configuration in main CMakeLists.txt  
**Solution:**

1. Move configuration to ephemeral directory
2. Generate files during build
3. Keep minimal configuration in main file

**Note:** This is a Flutter framework TODO, may not need immediate action unless causing issues.

**Estimated Effort:** 4-6 hours (if needed)

---

## Implementation Order

### Phase 1: High Priority (User-Facing)

1. Subscription tier retrieval (#1)
2. Admin status check (#2)
3. Premium tier check (#4)
4. Theme provider integration (#3)

### Phase 2: Medium Priority (Infrastructure)

1. Window manager integration (#5)
2. TURN server credential security (#8)
3. Alerting system integration (#6)
4. Cloud SQL migration (#7)

### Phase 3: Low Priority (Production Enhancements)

1. Connection acceptance blocking (#9)
2. In-flight request tracking (#10)
3. SSH disconnect messages (#11)
4. Client notification (#12)
5. Custom shutdown metrics (#13)
6. Admin auth for diagnostics (#14)
7. CMakeLists.txt refactoring (#15)

---

## Additional TODOs to Add

During implementation, consider adding these TODOs:

1. **Error Handling:** Add comprehensive error handling for all new implementations
2. **Testing:** Add unit tests for new features
3. **Documentation:** Update API documentation for new endpoints
4. **Migration Scripts:** Create migration scripts for database changes
5. **Monitoring:** Add monitoring/logging for new features
6. **Security Review:** Review security implications of new features

---

## Notes

- All implementations should follow existing code patterns and conventions
- Add appropriate error handling and logging
- Update tests where applicable
- Document new features in relevant documentation files
- Consider backward compatibility when making changes

---

## Completion Status

**All 15 TODOs have been completed!** ✅

### Completed Items

1. ✅ **Subscription tier retrieval** - Implemented using `EnhancedUserTierService`
2. ✅ **Admin status check** - Implemented using `AdminCenterService`
3. ✅ **Premium tier check** - Implemented using `EnhancedUserTierService` in `PlatformCategoryFilter`
4. ✅ **Theme provider integration** - Created `ThemeProvider` service and integrated with settings
5. ✅ **Window manager integration** - Integrated with `window_manager` package for desktop settings
6. ✅ **Alerting system integration** - Created `alerting-service.js` and integrated with `pool-monitor.js`
7. ✅ **Cloud SQL migration** - Implemented PostgreSQL migration in `migrate-database.js`
8. ✅ **TURN server credential security** - Created authenticated `/api/turn/credentials` endpoint
9. ✅ **Connection acceptance blocking** - Implemented in `graceful-shutdown-manager.ts`
10. ✅ **In-flight request tracking** - Implemented tracking in `graceful-shutdown-manager.ts`
11. ✅ **SSH disconnect messages** - Implemented in `ssh-connection-impl.ts`
12. ✅ **Client notification** - Implemented in `graceful-shutdown-manager.ts` (fixed sequence bug)
13. ✅ **Custom shutdown metrics** - Added Prometheus metrics in `prometheus-metrics.ts` and `shutdown-event-logger.ts`
14. ✅ **Admin auth for diagnostics** - Added `requireAdminAuth` middleware to diagnostics endpoint
15. ✅ **CMakeLists.txt refactoring** - Documented as Flutter framework TODO (not actionable by us)

**Last Updated:** 2025-01-19
