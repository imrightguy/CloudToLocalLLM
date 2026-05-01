# First-Time Setup Wizard Development Guide

> **Current orientation**: The setup wizard selects the runtime and secure device path. Do not assume a default runtime or a mandatory streaming-proxy container. Hermes is the first current test path, OpenClaw remains supported, and remote/cloud paths should prefer Tailscale with optional per-user connector containers.

## Overview

This guide provides comprehensive information for developers working on the first-time setup wizard feature. The wizard is a critical component that guides new users through downloading, installing, and configuring the CloudToLocalLLM desktop client.

## Architecture Overview

### Component Structure

```
lib/
├── screens/
│   └── setup/
│       ├── first_time_setup_wizard.dart
│       ├── setup_wizard_state.dart
│       └── steps/
│           ├── welcome_step.dart
│           ├── container_creation_step.dart
│           ├── platform_detection_step.dart
│           ├── download_step.dart
│           ├── installation_guide_step.dart
│           ├── tunnel_configuration_step.dart
│           ├── validation_step.dart
│           └── completion_step.dart
├── services/
│   ├── setup_status_service.dart
│   ├── user_container_service.dart
│   ├── platform_detection_service.dart
│   ├── download_management_service.dart
│   ├── tunnel_configuration_service.dart
│   └── connection_validation_service.dart
├── models/
│   ├── user_setup_status.dart
│   ├── container_creation_result.dart
│   ├── download_option.dart
│   ├── installation_step.dart
│   ├── tunnel_config.dart
│   └── validation_result.dart
└── widgets/
    └── setup/
        ├── setup_progress_bar.dart
        ├── platform_selector.dart
        ├── download_button.dart
        ├── installation_instructions.dart
        └── validation_test_widget.dart
```

### Service Layer Architecture

#### SetupStatusService

Manages user setup completion status and progress tracking.

```dart
class SetupStatusService {
  Future<bool> isFirstTimeUser(String userId);
  Future<void> markSetupComplete(String userId);
  Future<bool> hasActiveDesktopConnection(String userId);
  Future<void> resetSetupStatus(String userId);
  Future<SetupProgress> getSetupProgress(String userId);
  Future<void> saveSetupProgress(String userId, SetupProgress progress);
}
```

#### UserContainerService

Handles creation and management of user-specific streaming proxy containers.

```dart
class UserContainerService {
  Future<String> createUserContainer(String userId);
  Future<bool> configureContainer(String containerId, Map<String, String> config);
  Future<bool> startContainer(String containerId);
  Future<bool> validateContainerHealth(String containerId);
  Future<void> cleanupFailedContainer(String containerId);
}
```

#### PlatformDetectionService

Detects user's operating system and provides appropriate download options.

```dart
class PlatformDetectionService {
  PlatformType detectPlatform();
  List<DownloadOption> getDownloadOptions(PlatformType platform);
  String getInstallationInstructions(PlatformType platform, String downloadType);
}
```

### State Management

The wizard uses a centralized state management approach with `SetupWizardState`:

```dart
class SetupWizardState {
  int currentStep;
  String? userContainerId;
  bool isContainerCreated;
  PlatformType detectedPlatform;
  String? selectedDownloadOption;
  bool isDownloadComplete;
  bool isInstallationComplete;
  bool isTunnelConfigured;
  bool isValidationComplete;
  Map<String, dynamic> setupData;
  List<String> encounteredErrors;
}
```

## Implementation Details

### Step Implementation Pattern

Each wizard step follows a consistent pattern:

```dart
class ExampleStep extends StatefulWidget {
  final SetupWizardState wizardState;
  final Function(SetupWizardState) onStateUpdate;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  _ExampleStepState createState() => _ExampleStepState();
}

class _ExampleStepState extends State<ExampleStep> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Step content
        _buildStepContent(),
        
        // Error display
        if (_errorMessage != null) _buildErrorDisplay(),
        
        // Loading indicator
        if (_isLoading) _buildLoadingIndicator(),
        
        // Navigation buttons
        _buildNavigationButtons(),
      ],
    );
  }

  Widget _buildStepContent() {
    // Step-specific UI implementation
  }

  Future<void> _performStepAction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Step-specific logic
      await _executeStepLogic();
      
      // Update wizard state
      widget.onStateUpdate(updatedState);
      
      // Proceed to next step
      widget.onNext();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
```

### Error Handling Strategy

#### Error Categories

1. **Network Errors**: Connection failures, timeouts
2. **Platform Errors**: Unsupported OS, detection failures
3. **Download Errors**: File corruption, server unavailability
4. **Installation Errors**: Permission issues, missing dependencies
5. **Configuration Errors**: Invalid settings, connection failures
6. **Validation Errors**: Test failures, service unavailability

#### Error Handling Implementation

```dart
class SetupErrorHandler {
  static String getErrorMessage(SetupError error) {
    switch (error.type) {
      case SetupErrorType.network:
        return 'Network connection failed. Please check your internet connection and try again.';
      case SetupErrorType.platform:
        return 'Unable to detect your platform. Please select your operating system manually.';
      case SetupErrorType.download:
        return 'Download failed. Try using an alternative download link or check your network connection.';
      case SetupErrorType.installation:
        return 'Installation failed. Please check the troubleshooting guide for your platform.';
      case SetupErrorType.configuration:
        return 'Configuration failed. Please verify your settings and try again.';
      case SetupErrorType.validation:
        return 'Validation tests failed. Please check your local LLM setup and network connection.';
      default:
        return 'An unexpected error occurred. Please try again or contact support.';
    }
  }

  static List<String> getTroubleshootingSteps(SetupError error) {
    switch (error.type) {
      case SetupErrorType.network:
        return [
          'Check your internet connection',
          'Disable VPN temporarily',
          'Try a different network',
          'Check firewall settings',
        ];
      case SetupErrorType.download:
        return [
          'Try a different browser',
          'Clear browser cache',
          'Use alternative download link',
          'Check available disk space',
        ];
      // Add more cases as needed
      default:
        return ['Contact support for assistance'];
    }
  }
}
```

### Testing Strategy

#### Unit Tests

```dart
// test/services/setup_status_service_test.dart
void main() {
  group('SetupStatusService', () {
    late SetupStatusService service;
    late MockDatabase mockDatabase;

    setUp(() {
      mockDatabase = MockDatabase();
      service = SetupStatusService(database: mockDatabase);
    });

    test('should detect first-time user correctly', () async {
      // Arrange
      when(mockDatabase.getUserSetupStatus('user123'))
          .thenAnswer((_) async => null);

      // Act
      final isFirstTime = await service.isFirstTimeUser('user123');

      // Assert
      expect(isFirstTime, true);
    });

    test('should mark setup as complete', () async {
      // Arrange
      const userId = 'user123';

      // Act
      await service.markSetupComplete(userId);

      // Assert
      verify(mockDatabase.saveUserSetupStatus(
        userId,
        argThat(predicate<UserSetupStatus>((status) => status.isSetupComplete)),
      )).called(1);
    });
  });
}
```

#### Integration Tests

```dart
// test/integration/setup_wizard_flow_test.dart
void main() {
  group('Setup Wizard Integration', () {
    testWidgets('complete setup flow', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(MyApp());
      
      // Navigate to setup wizard
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Step 1: Welcome
      expect(find.text('Welcome to CloudToLocalLLM'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: Container Creation
      expect(find.text('Creating your container...'), findsOneWidget);
      await tester.pump(Duration(seconds: 2)); // Wait for container creation
      await tester.pumpAndSettle();

      // Continue through all steps...
      // Assert final completion
      expect(find.text('Setup Complete!'), findsOneWidget);
    });
  });
}
```

#### End-to-End Tests

```dart
// test/e2e/setup_wizard_e2e_test.dart
void main() {
  group('Setup Wizard E2E', () {
    test('complete setup with real services', () async {
      // This test runs against actual backend services
      final driver = await FlutterDriver.connect();
      
      try {
        // Navigate through complete setup flow
        await driver.tap(find.text('Get Started'));
        await driver.waitFor(find.text('Welcome to CloudToLocalLLM'));
        
        // Test each step with real API calls
        await _testContainerCreation(driver);
        await _testPlatformDetection(driver);
        await _testDownloadProcess(driver);
        await _testValidation(driver);
        
        // Verify completion
        await driver.waitFor(find.text('Setup Complete!'));
      } finally {
        await driver.close();
      }
    });
  });
}
```

### Performance Considerations

#### Lazy Loading

```dart
class SetupWizard extends StatefulWidget {
  @override
  _SetupWizardState createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  late PageController _pageController;
  final Map<int, Widget> _stepCache = {};

  Widget _buildStep(int stepIndex) {
    return _stepCache.putIfAbsent(stepIndex, () {
      switch (stepIndex) {
        case 0: return WelcomeStep();
        case 1: return ContainerCreationStep();
        // ... other steps
        default: return Container();
      }
    });
  }
}
```

#### Memory Management

```dart
class SetupWizardState extends State<SetupWizard> {
  @override
  void dispose() {
    // Clean up resources
    _pageController.dispose();
    _stepCache.clear();
    _cancelActiveOperations();
    super.dispose();
  }

  void _cancelActiveOperations() {
    _containerCreationCancellationToken?.cancel();
    _downloadCancellationToken?.cancel();
    _validationCancellationToken?.cancel();
  }
}
```

## API Integration

### Backend Endpoints

The setup wizard integrates with several backend endpoints:

```typescript
// Container Management
POST /api/containers/create
GET /api/containers/{containerId}/status
POST /api/containers/{containerId}/start
DELETE /api/containers/{containerId}

// Setup Status
GET /api/users/{userId}/setup-status
PUT /api/users/{userId}/setup-status
POST /api/users/{userId}/setup-progress

// Download Management
GET /api/downloads/options/{platform}
POST /api/downloads/track
GET /api/downloads/verify/{fileHash}

// Validation
POST /api/validation/test-connection
POST /api/validation/test-streaming
GET /api/validation/health-check
```

### API Client Implementation

```dart
class SetupApiClient {
  final Dio _dio;

  SetupApiClient(this._dio);

  Future<ContainerCreationResult> createUserContainer(String userId) async {
    try {
      final response = await _dio.post('/api/containers/create', data: {
        'userId': userId,
        'containerType': 'streaming-proxy',
      });
      
      return ContainerCreationResult.fromJson(response.data);
    } on DioError catch (e) {
      throw SetupException('Container creation failed: ${e.message}');
    }
  }

  Future<List<DownloadOption>> getDownloadOptions(PlatformType platform) async {
    try {
      final response = await _dio.get('/api/downloads/options/${platform.name}');
      
      return (response.data as List)
          .map((json) => DownloadOption.fromJson(json))
          .toList();
    } on DioError catch (e) {
      throw SetupException('Failed to get download options: ${e.message}');
    }
  }

  Future<ValidationResult> runValidationTests(String userId) async {
    try {
      final response = await _dio.post('/api/validation/test-connection', data: {
        'userId': userId,
        'tests': ['desktop-client', 'tunnel', 'streaming'],
      });
      
      return ValidationResult.fromJson(response.data);
    } on DioError catch (e) {
      throw SetupException('Validation failed: ${e.message}');
    }
  }
}
```

## Configuration Management

### Feature Flags

```dart
class SetupFeatureFlags {
  static const bool enableContainerCreation = true;
  static const bool enablePlatformDetection = true;
  static const bool enableDownloadTracking = true;
  static const bool enableValidationTests = true;
  static const bool enableSkipOptions = true;
  static const bool enableAnalytics = true;
  
  // Gradual rollout percentages
  static const int setupWizardRolloutPercentage = 100;
  static const int containerCreationRolloutPercentage = 100;
  static const int validationTestsRolloutPercentage = 100;
}
```

### Environment Configuration

```dart
class SetupConfig {
  static const String containerApiUrl = String.fromEnvironment(
    'CONTAINER_API_URL',
    defaultValue: 'https://cloudtolocalllm.online/api',
  );
  
  static const String downloadBaseUrl = String.fromEnvironment(
    'DOWNLOAD_BASE_URL',
    defaultValue: 'https://github.com/CloudToLocalLLM/releases',
  );
  
  static const int containerCreationTimeoutSeconds = int.fromEnvironment(
    'CONTAINER_TIMEOUT',
    defaultValue: 120,
  );
  
  static const int validationTimeoutSeconds = int.fromEnvironment(
    'VALIDATION_TIMEOUT',
    defaultValue: 60,
  );
}
```

## Monitoring and Analytics

### Analytics Events

```dart
class SetupAnalytics {
  static void trackSetupStarted(String userId, PlatformType platform) {
    AnalyticsService.track('setup_started', {
      'user_id': userId,
      'platform': platform.name,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackStepCompleted(String userId, int stepIndex, String stepName) {
    AnalyticsService.track('setup_step_completed', {
      'user_id': userId,
      'step_index': stepIndex,
      'step_name': stepName,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackSetupCompleted(String userId, Duration totalDuration) {
    AnalyticsService.track('setup_completed', {
      'user_id': userId,
      'duration_seconds': totalDuration.inSeconds,
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

```dart
class SetupPerformanceMonitor {
  static final Map<String, Stopwatch> _timers = {};

  static void startTimer(String operation) {
    _timers[operation] = Stopwatch()..start();
  }

  static void stopTimer(String operation) {
    final timer = _timers[operation];
    if (timer != null) {
      timer.stop();
      AnalyticsService.track('setup_performance', {
        'operation': operation,
        'duration_ms': timer.elapsedMilliseconds,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _timers.remove(operation);
    }
  }
}
```

## Deployment Considerations

### Database Migrations

```sql
-- Add setup status tracking
CREATE TABLE user_setup_status (
  user_id VARCHAR(255) PRIMARY KEY,
  is_setup_complete BOOLEAN DEFAULT FALSE,
  setup_completed_at TIMESTAMP NULL,
  last_connected_client_version VARCHAR(50) NULL,
  setup_preferences JSON NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Add setup progress tracking
CREATE TABLE user_setup_progress (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(255) NOT NULL,
  current_step INT DEFAULT 0,
  completed_steps JSON NULL,
  started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  step_data JSON NULL,
  encountered_errors JSON NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Add setup analytics
CREATE TABLE setup_analytics (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(255) NOT NULL,
  event_type VARCHAR(100) NOT NULL,
  event_data JSON NULL,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_event_type (event_type),
  INDEX idx_timestamp (timestamp)
);
```

### Environment Variables

```bash
# Setup Wizard Configuration
SETUP_WIZARD_ENABLED=true
SETUP_WIZARD_ROLLOUT_PERCENTAGE=100
CONTAINER_CREATION_ENABLED=true
PLATFORM_DETECTION_ENABLED=true
DOWNLOAD_TRACKING_ENABLED=true
VALIDATION_TESTS_ENABLED=true

# API Configuration
CONTAINER_API_URL=https://cloudtolocalllm.online/api
DOWNLOAD_BASE_URL=https://github.com/CloudToLocalLLM/releases
SETUP_API_TIMEOUT=120

# Feature Flags
ENABLE_SETUP_ANALYTICS=true
ENABLE_SETUP_SKIP_OPTIONS=true
ENABLE_SETUP_TROUBLESHOOTING=true
```

### Rollback Strategy

```dart
class SetupRollbackManager {
  static Future<void> rollbackSetupChanges(String userId) async {
    try {
      // Remove setup progress
      await SetupStatusService.resetSetupStatus(userId);
      
      // Clean up created containers
      await UserContainerService.cleanupUserContainers(userId);
      
      // Clear setup preferences
      await UserPreferencesService.clearSetupPreferences(userId);
      
      // Log rollback
      Logger.info('Setup rollback completed for user: $userId');
    } catch (e) {
      Logger.error('Setup rollback failed for user: $userId', error: e);
      rethrow;
    }
  }
}
```

## Security Considerations

### Input Validation

```dart
class SetupInputValidator {
  static bool isValidUserId(String userId) {
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(userId) && userId.length <= 255;
  }

  static bool isValidContainerId(String containerId) {
    return RegExp(r'^[a-f0-9]{64}$').hasMatch(containerId);
  }

  static bool isValidPlatform(String platform) {
    return ['windows', 'linux', 'macos'].contains(platform.toLowerCase());
  }

  static bool isValidDownloadUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isScheme('https') && 
             (uri.host == 'github.com' || uri.host == 'cloudtolocalllm.online');
    } catch (e) {
      return false;
    }
  }
}
```

### Authentication Integration

```dart
class SetupAuthGuard {
  static Future<bool> canAccessSetup(String userId) async {
    try {
      // Verify user is authenticated
      final isAuthenticated = await AuthService.isUserAuthenticated(userId);
      if (!isAuthenticated) return false;

      // Check if user has setup permissions
      final hasPermission = await AuthService.hasPermission(userId, 'setup:access');
      if (!hasPermission) return false;

      // Verify account is active
      final isActive = await UserService.isAccountActive(userId);
      return isActive;
    } catch (e) {
      Logger.error('Setup auth check failed', error: e);
      return false;
    }
  }
}
```

## Troubleshooting Guide for Developers

### Common Development Issues

#### Issue: Setup wizard doesn't appear for new users

**Cause**: Setup status detection not working correctly
**Solution**:

1. Check `SetupStatusService.isFirstTimeUser()` implementation
2. Verify database connection and user_setup_status table
3. Check authentication state before setup check
4. Review routing logic in main app

#### Issue: Container creation fails

**Cause**: Docker API connection or permissions
**Solution**:

1. Verify Docker daemon is running
2. Check API backend container management permissions
3. Review container creation logs
4. Test Docker API endpoints manually

#### Issue: Platform detection returns 'unknown'

**Cause**: User agent parsing or unsupported browser
**Solution**:

1. Check user agent string parsing logic
2. Add support for new browser/OS combinations
3. Implement fallback to manual selection
4. Test on different browsers and devices

#### Issue: Download links are broken

**Cause**: GitHub releases API or URL generation
**Solution**:

1. Verify GitHub releases exist and are public
2. Check download URL generation logic
3. Test alternative download mirrors
4. Review GitHub API rate limits

#### Issue: Validation tests fail

**Cause**: Network connectivity or service availability
**Solution**:

1. Check desktop client is running and accessible
2. Verify tunnel configuration is correct
3. Test local LLM connectivity manually
4. Review firewall and network settings

### Debugging Tools

#### Setup State Inspector

```dart
class SetupStateInspector {
  static void logSetupState(SetupWizardState state) {
    Logger.debug('Setup State:', data: {
      'currentStep': state.currentStep,
      'userContainerId': state.userContainerId,
      'isContainerCreated': state.isContainerCreated,
      'detectedPlatform': state.detectedPlatform.name,
      'selectedDownloadOption': state.selectedDownloadOption,
      'isDownloadComplete': state.isDownloadComplete,
      'isInstallationComplete': state.isInstallationComplete,
      'isTunnelConfigured': state.isTunnelConfigured,
      'isValidationComplete': state.isValidationComplete,
      'encounteredErrors': state.encounteredErrors,
    });
  }
}
```

#### API Request Logger

```dart
class SetupApiLogger extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    Logger.debug('Setup API Request:', data: {
      'method': options.method,
      'url': options.uri.toString(),
      'headers': options.headers,
      'data': options.data,
    });
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    Logger.debug('Setup API Response:', data: {
      'statusCode': response.statusCode,
      'data': response.data,
    });
    super.onResponse(response, handler);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    Logger.error('Setup API Error:', error: err, data: {
      'url': err.requestOptions.uri.toString(),
      'statusCode': err.response?.statusCode,
      'message': err.message,
    });
    super.onError(err, handler);
  }
}
```

## Contributing Guidelines

### Code Style

Follow the established Flutter/Dart conventions:

- Use `snake_case` for file names and variables
- Use `PascalCase` for class names
- Use `camelCase` for method names
- Add comprehensive documentation for public APIs
- Include unit tests for all new functionality

### Pull Request Process

1. Create feature branch from `main`
2. Implement changes with tests
3. Update documentation
4. Run full test suite
5. Submit PR with detailed description
6. Address code review feedback
7. Ensure CI/CD passes

### Testing Requirements

- Unit tests for all service methods
- Widget tests for UI components
- Integration tests for complete flows
- E2E tests for critical user journeys
- Performance tests for resource usage

This development guide provides the foundation for maintaining and extending the first-time setup wizard. Follow these patterns and guidelines to ensure consistency and reliability across the codebase.
