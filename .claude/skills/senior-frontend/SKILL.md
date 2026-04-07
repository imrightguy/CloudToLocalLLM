---
name: senior-frontend
description: Flutter frontend development for CloudToLocalLLM. Use when building widgets, screens, services, providers, managing state, handling platform conditionals (web vs desktop), or reviewing Flutter code quality.
---

# Flutter Frontend Development

Patterns, conventions, and workflows for the CloudToLocalLLM Flutter app (Dart, Linux/Windows/Web targets).

## Project Structure

| Path | Purpose |
|------|---------|
| `lib/main.dart` | Entry point |
| `lib/di/locator.dart` | GetIt DI — two-phase (`setupCoreServices` → `setupAuthenticatedServices`) |
| `lib/services/` | Service classes (87+ files), singletons via GetIt |
| `lib/screens/` | Full-screen pages, organized by feature |
| `lib/widgets/` | Reusable UI components |
| `lib/features/` | Feature-scoped widgets (avatar, browser, system) |
| `lib/components/` | Shared UI components |
| `lib/models/` | Data models |
| `lib/config/` | App configuration |
| `lib/database/` | Drift/SQLite (LocalBrain) + generated `.g.dart` |

## Conventions

- **Files**: `snake_case.dart`, classes `PascalCase`
- **Quotes**: `prefer_single_quotes` (enforced in `analysis_options.yaml`)
- **Strong mode**: `implicit-casts: false`, `implicit-dynamic: false`
- **No `dart:io` in shared code** — use conditional imports with `_stub.dart` files
- **No direct service instantiation** — always `di.serviceLocator<T>()`
- **No comments** unless explicitly asked

## Widget Pattern

Follow existing widgets in `lib/widgets/` or `lib/features/`:

```dart
import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/di/locator.dart';
import 'package:cloudtolocalllm/services/some_service.dart';

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final SomeService _service = di.serviceLocator<SomeService>();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Content'),
      ),
    );
  }
}
```

## Screen Pattern

Screens live in `lib/screens/` organized by feature (e.g., `screens/admin/`, `screens/config/`, `screens/onboarding/`). Use `go_router` for navigation.

## Service Pattern

Services are singletons registered in `lib/di/locator.dart`. Use `ChangeNotifier` for reactive state:

```dart
import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/di/locator.dart';
import 'package:get_it/get_it.dart';

final di = GetIt.instance;

class MyService extends ChangeNotifier {
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    notifyListeners();
  }
}
```

Register in `locator.dart` depending on phase:
- **Core**: `di.registerSingleton<MyService>(MyService())`
- **Auth-dependent**: inside `setupAuthenticatedServices()`, may depend on auth services

## Platform Conditional Imports

Web vs desktop code splits use conditional imports:

```dart
import 'service.dart'
    if (dart.library.io) 'service_stub.dart'
    if (dart.library.js_interop) 'service_web.dart';
```

Files ending in `_stub.dart` are desktop stubs for web-only APIs (and vice versa). Never call `dart:io` directly in shared service code.

## Verification

After any Flutter changes:

```
flutter format .
flutter analyze
flutter test
```

If Drift tables/queries changed:
```
dart run build_runner build --delete-conflicting-outputs
```
