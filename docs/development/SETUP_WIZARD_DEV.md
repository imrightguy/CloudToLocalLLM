# First-Time Setup Wizard Developer Guide

## Overview

This guide provides comprehensive information for developers working on the first-time setup wizard feature. It covers architecture, implementation details, testing strategies, and maintenance procedures.

## Architecture Overview

### Component Structure

The first-time setup wizard is built using Flutter and consists of several key components:

```
FirstTimeSetupWizard (StatefulWidget)
├── SetupWizardState (State Management)
├── WizardStepManager (Step Navigation)
├── SetupStatusService (Status Tracking)
├── UserContainerService (Container Management)
├── PlatformDetectionService (OS Detection)
├── DownloadManagementService (Download Handling)
├── TunnelConfigurationService (Connection Setup)
└── ConnectionValidationService (Testing)
```

### Key Services

#### SetupStatusService

- **Location**: `lib/services/setup_status_service.dart`
- **Purpose**: Tracks user setup completion status
- **Key Methods**:
  - `isFirstTimeUser(String userId)` - Check if user needs setup
  - `markSetupComplete(String userId)` - Mark setup as complete
  - `resetSetupStatus(String userId)` - Reset for re-setup

#### UserContainerService

- **Location**: `lib/services/user_container_service.dart`
- **Purpose**: Manages user-specific streaming proxy containers
- **Key Methods**:
  - `createUserContainer(String userId)` - Create isolated container
  - `validateContainerHealth(String containerId)` - Health checks
  - `cleanupFailedContainer(String containerId)` - Error cleanup

#### PlatformDetectionService

- **Location**: `lib/services/platform_detection_service.dart`
- **Purpose**: Detects user's operating system and provides download options
- **Key Methods**:
  - `detectPlatform()` - Auto-detect OS from user agent
  - `getDownloadOptions(PlatformType platform)` - Get platform-specific downloads

### Data Models

#### UserSetupStatus

```dart
class UserSetupStatus {
  final String userId;
  final bool isSetupComplete;
  final DateTime? setupCompletedAt;
  final String? lastConnectedClientVersion;
  final Map<String, dynamic>? setupPreferences;
}
```

#### SetupProgress

```dart
class SetupProgress {
  final String userId;
  final int currentStep;
  final Map<String, bool> completedSteps;
  final DateTime startedAt;
  final DateTime? lastUpdatedAt;
  final Map<String, dynamic> stepData;
}
```

## Implementation Details

### Wizard Flow Management

The wizard uses a state-based approach to manage the multi-step flow:

```dart
class SetupWizardState extends State<FirstTimeSetupWizard> {
  int currentStep = 0;
  Map<String, dynamic> setupData = {};
  
  void nextStep() {
    if (validateCurrentStep()) {
      setState(() {
        currentStep++;
      });
      saveProgress();
    }
  }
  
  void previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
    }
  }
}
```

### Step Validation

Each step implements validation logic:

```dart
bool validateCurrentStep() {
  switch (currentStep) {
    case 0: return true; // Welcome step
    case 1: return validateContainerCreation();
    case 2: return validatePlatformSelection();
    case 3: return validateDownloadCompletion();
    case 4: return validateInstallationConfirmation();
    case 5: return validateTunnelConfiguration();
    case 6: return validateConnectionTests();
    case 7: return true; // Completion step
    default: return false;
  }
}
```

### Error Handling Strategy

The wizard implements comprehensive error handling:

```dart
class SetupErrorHandler {
  static void handleError(SetupException error, BuildContext context) {
    switch (error.type) {
      case SetupErrorType.containerCreation:
        _showContainerErrorDialog(error, context);
        break;
      case SetupErrorType.download:
        _showDownloadErrorDialog(error, context);
        break;
      case SetupErrorType.connection:
        _showConnectionErrorDialog(error, context);
        break;
    }
  }
}
```

## Testing Strategy

### Unit Tests

Test individual services and components:

```dart
// test/services/setup_status_service_test.dart
void main() {
  group('SetupStatusService', () {
    test('should detect first-time user correctly', () async {
      final service = SetupStatusService();
      final isFirstTime = await service.isFirstTimeUser('test-user');
      expect(isFirstTime, true);
    });
  });
}
```

### Integration Tests

Test complete wizard flows:

```dart
// test/integration/setup_wizard_test.dart
void main() {
  testWidgets('complete setup wizard flow', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    
    // Navigate through each step
    for (int step = 0; step < 8; step++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    
    expect(find.text('Setup Complete'), findsOneWidget);
  });
}
```

### End-to-End Tests

Test with real backend services:

```dart
// test/e2e/setup_e2e_test.dart
void main() {
  group('Setup E2E Tests', () {
    test('should create container and establish connection', () async {
      final wizard = FirstTimeSetupWizard();
      final result = await wizard.runCompleteSetup('test-user');
      expect(result.success, true);
    });
  });
}
```

## Configuration Management

### Feature Flags

The setup wizard supports feature flags for gradual rollout:

```dart
class SetupFeatureFlags {
  static bool get isSetupWizardEnabled => 
    ConfigService.getBool('setup_wizard_enabled', defaultValue: false);
    
  static bool get isContainerCreationEnabled => 
    ConfigService.getBool('container_creation_enabled', defaultValue: true);
    
  static bool get isValidationEnabled => 
    ConfigService.getBool('setup_validation_enabled', defaultValue: true);
}
```

### Environment Configuration

Different configurations for different environments:

```dart
class SetupConfig {
  static String get apiBaseUrl {
    switch (Environment.current) {
      case Environment.development:
        return 'http://localhost:8080';
      case Environment.staging:
        return 'https://staging.cloudtolocalllm.online';
      case Environment.production:
        return 'https://cloudtolocalllm.online';
    }
  }
}
```

## Analytics and Monitoring

### Setup Analytics

Track setup completion and failure rates:

```dart
class SetupAnalytics {
  static void trackSetupStarted(String userId) {
    AnalyticsService.track('setup_started', {
      'user_id': userId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  static void trackSetupCompleted(String userId, Duration duration) {
    AnalyticsService.track('setup_completed', {
      'user_id': userId,
      'duration_seconds': duration.inSeconds,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  static void trackSetupError(String userId, String errorType, String errorMessage) {
    AnalyticsService.track('setup_error', {
      'user_id': userId,
      'error_type': errorType,
      'error_message': errorMessage,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
```

### Performance Monitoring

Monitor setup performance and identify bottlenecks:

```dart
class SetupPerformanceMonitor {
  static final Map<String, Stopwatch> _timers = {};
  
  static void startTimer(String operation) {
    _timers[operation] = Stopwatch()..start();
  }
  
  static void endTimer(String operation) {
    final timer = _timers[operation];
    if (timer != null) {
      timer.stop();
      AnalyticsService.track('setup_performance', {
        'operation': operation,
        'duration_ms': timer.elapsedMilliseconds,
      });
    }
  }
}
```

## Deployment Considerations

### Database Migrations

Setup wizard requires database schema updates:

```sql
-- Add setup status tracking
ALTER TABLE users ADD COLUMN setup_completed_at TIMESTAMP NULL;
ALTER TABLE users ADD COLUMN setup_preferences JSON NULL;

-- Create setup progress table
CREATE TABLE setup_progress (
  user_id VARCHAR(255) PRIMARY KEY,
  current_step INT NOT NULL DEFAULT 0,
  completed_steps JSON NOT NULL,
  started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  step_data JSON NULL
);
```

### Container Orchestration

Ensure Docker environment supports user containers:

```yaml
# docker-compose.yml additions
services:
  streaming-proxy-template:
    image: ghcr.io/cloudtolocalllm-online/CloudToLocalLLM/streaming:latest
    deploy:
      replicas: 0  # Template only, scaled per user
    environment:
      - USER_ID=${USER_ID}
      - CONTAINER_ID=${CONTAINER_ID}
```

### Feature Flag Deployment

Deploy with feature flags disabled initially:

```json
{
  "feature_flags": {
    "setup_wizard_enabled": false,
    "setup_wizard_beta_users": ["user1", "user2"],
    "setup_wizard_rollout_percentage": 0
  }
}
```

## Maintenance and Monitoring

### Health Checks

Monitor setup wizard health:

```dart
class SetupHealthCheck {
  static Future<HealthStatus> checkHealth() async {
    final checks = [
      _checkDatabaseConnection(),
      _checkContainerService(),
      _checkDownloadService(),
    ];
    
    final results = await Future.wait(checks);
    return HealthStatus.fromChecks(results);
  }
}
```

### Error Monitoring

Set up alerts for setup failures:

```dart
class SetupErrorMonitoring {
  static void monitorSetupErrors() {
    // Alert if error rate > 5%
    if (getSetupErrorRate() > 0.05) {
      AlertService.sendAlert('High setup error rate detected');
    }
    
    // Alert if container creation fails
    if (getContainerCreationFailureRate() > 0.02) {
      AlertService.sendAlert('Container creation failures detected');
    }
  }
}
```

## Security Considerations

### Data Privacy

- No sensitive user data stored during setup
- Setup progress encrypted in database
- Container isolation enforced
- Secure token generation for connections

### Input Validation

```dart
class SetupInputValidator {
  static bool validateUserId(String userId) {
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(userId);
  }
  
  static bool validateContainerId(String containerId) {
    return RegExp(r'^[a-f0-9]{64}$').hasMatch(containerId);
  }
}
```

## Performance Optimization

### Lazy Loading

Load wizard steps on demand:

```dart
class WizardStepLoader {
  static Widget loadStep(int stepIndex) {
    switch (stepIndex) {
      case 0: return const WelcomeStep();
      case 1: return const ContainerCreationStep();
      // ... other steps loaded on demand
    }
  }
}
```

### Caching

Cache platform detection and download options:

```dart
class SetupCache {
  static final Map<String, PlatformType> _platformCache = {};
  static final Map<PlatformType, List<DownloadOption>> _downloadCache = {};
  
  static PlatformType? getCachedPlatform(String userAgent) {
    return _platformCache[userAgent];
  }
}
```

## Troubleshooting Guide

### Common Development Issues

1. **Wizard not appearing**: Check feature flags and user setup status
2. **Container creation failing**: Verify Docker service and permissions
3. **Download links broken**: Check GitHub releases and CDN status
4. **Validation failing**: Verify backend services are running

### Debug Tools

```dart
class SetupDebugTools {
  static void enableDebugMode() {
    SetupConfig.debugMode = true;
    Logger.level = Level.DEBUG;
  }
  
  static void dumpSetupState(SetupWizardState state) {
    print('Current Step: ${state.currentStep}');
    print('Setup Data: ${state.setupData}');
    print('Completed Steps: ${state.completedSteps}');
  }
}
```

## Contributing

### Code Style

Follow Flutter/Dart conventions:

- Use `snake_case` for file names
- Use `camelCase` for variables and methods
- Use `PascalCase` for classes
- Add comprehensive documentation

### Pull Request Process

1. Create feature branch from `main`
2. Implement changes with tests
3. Update documentation
4. Submit PR with detailed description
5. Address review feedback
6. Merge after approval

### Testing Requirements

- Unit tests for all services
- Integration tests for wizard flow
- E2E tests for critical paths
- Performance tests for bottlenecks

This guide should be updated as the setup wizard evolves and new features are added.
