---
name: flutter-service
description: Generate Flutter service with Provider pattern, GetIt DI, and two-phase initialization
disable-model-invocation: true
---

Create a new Flutter service for {{feature}}.

Include:
- ChangeNotifier base class
- GetIt registration in lib/di/locator.dart
- Constructor with AuthService dependency (if authenticated service)
- Proper initialization with timeout
- debugPrint logging
- Error handling with graceful degradation

Service placement:
- Core services (available before auth): Add to setupCoreServices()
- Authenticated services: Add to setupAuthenticatedServices()

Follow existing patterns in lib/services/auth_service.dart

Example structure:
```dart
import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';

class {{FeatureName}}Service extends ChangeNotifier {
  final AuthService _authService;

  // State
  bool _isLoading = false;
  String? _error;

  {{FeatureName}}Service({required AuthService authService})
      : _authService = authService {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.timeout(
        const Duration(seconds: 10),
        () async {
          // Initialization logic
        },
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('[{{Feature}}] Failed to initialize: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
}
```
