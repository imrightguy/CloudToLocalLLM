---
name: senior-qa
description: Testing for CloudToLocalLLM — Flutter frontend tests and Node.js backend tests. Use when generating tests, writing unit tests, analyzing coverage, or improving test quality for this Flutter+Node.js codebase.
---

# QA & Testing (Flutter + Node.js)

Testing patterns and tools for the CloudToLocalLLM codebase.

## Test Structure

| Area | Location | Runner | Pattern |
|------|----------|--------|---------|
| Flutter unit | `test/services/` | `flutter test` | `*_test.dart` |
| Flutter widget | `test/widgets/` | `flutter test` | `*_test.dart` |
| Flutter integration | `test/integration/` | `flutter test` | `*_test.dart` |
| Backend unit | `test/api-backend/` | `npm test` (Jest) | `*.test.js` |
| Backend security | `test/api-backend/security/` | `npm run test:security` | `*.test.js` |
| Backend tunnel | `test/api-backend/` | `npm run test:tunnel` | `*.test.js` |

## Flutter Tests

### Service Unit Test Pattern

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/my_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'my_service_test.mocks.dart';

@GenerateMocks([DependencyService])
void main() {
  late MyService service;
  late MockDependencyService mockDependency;

  setUp(() {
    mockDependency = MockDependencyService();
    service = MyService(dependency: mockDependency);
  });

  test('does something correctly', () async {
    when(mockDependency.getData()).thenAnswer((_) async => 'test');

    final result = await service.doSomething();

    expect(result, equals('expected'));
    verify(mockDependency.getData()).called(1);
  });
}
```

Generate mocks:
```
dart run build_runner build --delete-conflicting-outputs
```

### Widget Test Pattern

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/widgets/my_widget.dart';

void main() {
  testWidgets('renders correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MyWidget(),
        ),
      ),
    );

    expect(find.text('Expected'), findsOneWidget);
  });
}
```

### Running Flutter Tests

```bash
flutter test                                         # All tests
flutter test test/services/my_service_test.dart      # Single test
flutter test test/widgets/                            # Widget tests only
flutter test test/integration/                        # Integration tests only
flutter test --coverage                               # With coverage
```

## Node.js Backend Tests

### Test Pattern

```javascript
import { jest } from '@jest/globals';
import request from 'supertest';
import { app } from '../../services/api-backend/app.js';

describe('My Feature', () => {
  test('GET /api/feature returns data', async () => {
    const response = await request(app)
      .get('/api/feature')
      .set('Authorization', 'Bearer valid-token')
      .expect(200);

    expect(response.body).toHaveProperty('data');
  });
});
```

### Running Backend Tests

```bash
cd services/api-backend
npm test                                              # All tests
npm run test:unit                                     # Unit tests
npm run test:security                                 # Security tests
npm run test:tunnel                                   # Tunnel tests
npm test ../../test/api-backend/some.test.js          # Single test
```

All backend tests need `--experimental-vm-modules` (already in npm scripts).
Tests use `--forceExit` to ensure clean Jest shutdown.

### Root-level Tests

```bash
npm test                                              # Runs jest.config.js matching **/test/**/*.test.js
```

## Property-Based Testing

The project uses `fast-check` for property-based testing in backend:

```javascript
import { fc } from 'fast-check';

test('property: operation is idempotent', () => {
  fc.assert(
    fc.property(fc.string(), (input) => {
      const result1 = process(input);
      const result2 = process(result1);
      expect(result2).toEqual(result1);
    })
  );
});
```

## Test Fixtures & Config

- `test/flutter_test_config.dart` — Flutter test configuration
- `test/global-setup.js` / `test/global-teardown.js` — Jest global setup
- `test/helpers/` — Shared test utilities
- `test/test_config.dart` — Test configuration constants

## Verification Workflow

After writing tests, verify:

```
# 1. Format
flutter format .    # or npm run format

# 2. Lint
flutter analyze     # or npm run lint

# 3. Run tests
flutter test        # or npm test
```
