// Test configuration for CloudToLocalLLM
// Provides mock implementations and test setup utilities

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/di/locator.dart' as di;
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';

/// Test configuration class that sets up mocks for plugins
class TestConfig {
  static bool _initialized = false;

  /// Initialize test environment with mock implementations
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    // Ensure Flutter test binding is initialized
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Setup service locator for tests
    _setupServiceLocator();

    // Mock window_manager plugin
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), (
      MethodCall methodCall,
    ) async {
      switch (methodCall.method) {
        case 'ensureInitialized':
          return null;
        case 'show':
          return null;
        case 'hide':
          return null;
        case 'close':
          return null;
        case 'isVisible':
          return true;
        case 'isMinimized':
          return false;
        case 'isMaximized':
          return false;
        case 'getPosition':
          return {'x': 100.0, 'y': 100.0};
        case 'getSize':
          return {'width': 800.0, 'height': 600.0};
        default:
          return null;
      }
    });

    // Mock tray_manager plugin
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('tray_manager'), (
      MethodCall methodCall,
    ) async {
      switch (methodCall.method) {
        case 'setIcon':
          return null;
        case 'setContextMenu':
          return null;
        case 'setToolTip':
          return null;
        case 'popUpContextMenu':
          return null;
        case 'destroy':
          return null;
        default:
          return null;
      }
    });

    // Mock package_info_plus plugin
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getAll':
            return {
              'appName': 'CloudToLocalLLM',
              'packageName': 'online.cloudtolocalllm.app',
              'version': '3.6.1',
              'buildNumber': '202506192205',
              'buildSignature': '',
              'installerStore': null,
            };
          default:
            return null;
        }
      },
    );

    // Mock flutter_secure_storage plugin
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'read':
            return null; // Return null for all reads (no stored data)
          case 'write':
            return null;
          case 'delete':
            return null;
          case 'deleteAll':
            return null;
          case 'readAll':
            return <String, String>{};
          case 'containsKey':
            return false;
          default:
            return null;
        }
      },
    );

    // Mock connectivity_plus plugin
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'check':
            return 'wifi';
          case 'wifiName':
            return 'TestNetwork';
          case 'wifiBSSID':
            return '00:00:00:00:00:00';
          case 'wifiIPAddress':
            return '192.168.1.100';
          default:
            return null;
        }
      },
    );

    // Mock url_launcher plugin
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'canLaunch':
            return true;
          case 'launch':
            return true;
          default:
            return null;
        }
      },
    );

    // Mock path_provider plugin
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getTemporaryDirectory':
            return '/tmp';
          case 'getApplicationDocumentsDirectory':
            return '/documents';
          case 'getApplicationSupportDirectory':
            return '/support';
          case 'getExternalStorageDirectory':
            return '/external';
          case 'getExternalCacheDirectories':
            return ['/cache'];
          case 'getExternalStorageDirectories':
            return ['/storage'];
          case 'getApplicationCacheDirectory':
            return '/app_cache';
          case 'getDownloadsDirectory':
            return '/downloads';
          default:
            return null;
        }
      },
    );
  }

  /// Setup service locator with test services
  static void _setupServiceLocator() {
    // Reset service locator if already initialized
    if (di.serviceLocator.isRegistered<ThemeProvider>()) {
      di.serviceLocator.reset();
    }

    // Register core services
    di.serviceLocator.registerLazySingleton<ThemeProvider>(
      ThemeProvider.new,
    );

    di.serviceLocator.registerLazySingleton<PlatformDetectionService>(
      PlatformDetectionService.new,
    );

    di.serviceLocator.registerLazySingleton<PlatformAdapter>(
      () => PlatformAdapter(
        di.serviceLocator.get<PlatformDetectionService>(),
      ),
    );
  }

  /// Clean up test environment
  static void cleanup() {
    if (!_initialized) return;

    try {
      // Reset service locator
      if (di.serviceLocator.isRegistered<ThemeProvider>()) {
        di.serviceLocator.reset();
      }

      // Clear all mock handlers to prevent state leakage between tests
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('window_manager'), null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('tray_manager'), null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/package_info'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
    } catch (e) {
      // Ignore cleanup errors - tests may have already cleaned up
    }

    _initialized = false;
  }

  /// Setup test environment (alias for initialize)
  static Future<void> setupTestEnvironment() async {
    initialize();
  }

  /// Teardown test environment (alias for cleanup)
  static Future<void> teardownTestEnvironment() async {
    cleanup();
  }
}

/// Test utilities for common test setup
class TestUtils {
  /// Create a test Dio client that returns mock responses
  static MockDioClient createMockDioClient() {
    return MockDioClient();
  }
}

/// Mock Dio client for testing
class MockDioClient {
  /// Mock response for Ollama API calls
  Map<String, dynamic> get ollamaResponse => {'version': '0.9.2', 'models': []};

  /// Mock response for JWT calls
  Map<String, dynamic> get jwtResponse => {
        'error': 'Test environment - no real auth',
      };
}
