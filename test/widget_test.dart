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
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CloudToLocalLLMApp());

    // Wait for a reasonable amount of time for initialization
    await tester.pump(const Duration(seconds: 1));

    // Verify that the app loads without crashing
    expect(find.byType(MaterialApp), findsWidgets);

    // Look for loading screen or main app content
    final loadingFinder = find.text('Initializing CloudToLocalLLM...');
    final appFinder = find.byType(MaterialApp);

    // Either loading screen or main app should be present
    expect(
      loadingFinder.evaluate().isNotEmpty || appFinder.evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('App handles plugin initialization gracefully', (
    WidgetTester tester,
  ) async {
    // This test verifies that the app doesn't crash when plugins are mocked
    await tester.pumpWidget(const CloudToLocalLLMApp());

    // Pump a few frames to allow for async initialization
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify no exceptions were thrown and app is still running
    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsWidgets);
  });
}
