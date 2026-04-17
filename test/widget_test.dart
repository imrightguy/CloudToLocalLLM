// CloudToLocalLLM Widget Tests
//
// Basic widget tests for the CloudToLocalLLM application.
// Tests the main app initialization and basic functionality.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloudtolocalllm/main.dart';
import 'test_config.dart';

void main() {
  setUpAll(TestConfig.initialize);

  tearDownAll(TestConfig.cleanup);

  testWidgets('CloudToLocalLLM app initialization test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CloudToLocalLLMApp());

    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(MaterialApp), findsWidgets);

    final appFinder = find.byType(MaterialApp);
    expect(appFinder.evaluate().isNotEmpty, isTrue);
  }, timeout: const Timeout(Duration(minutes: 1)));

  testWidgets('App handles plugin initialization gracefully', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CloudToLocalLLMApp());

    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsWidgets);
  }, timeout: const Timeout(Duration(minutes: 1)));
}
