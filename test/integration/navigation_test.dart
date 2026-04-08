library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:cloudtolocalllm/screens/channels/channels_screen.dart';
import 'package:cloudtolocalllm/screens/instances/instances_screen.dart';
import 'package:cloudtolocalllm/screens/sessions/sessions_screen.dart';
import 'package:cloudtolocalllm/screens/usage/usage_screen.dart';
import 'package:cloudtolocalllm/screens/agents/agents_screen.dart';
import 'package:cloudtolocalllm/screens/skills/skills_screen.dart';
import 'package:cloudtolocalllm/screens/nodes/nodes_screen.dart';
import 'package:cloudtolocalllm/screens/debug/debug_screen.dart';
import 'package:cloudtolocalllm/screens/config/config_screen.dart';
import 'package:cloudtolocalllm/services/popout/popout_manager.dart';

/// Integration tests for Gateway screens.
///
/// Tests:
/// - All Gateway screens can be built
/// - Config screen does NOT have PopOutButton (per spec)
void main() {
  final serviceLocator = GetIt.instance;

  setUpAll(() {
    // Register minimal services needed for tests
    serviceLocator.registerSingleton<PopOutManager>(PopOutManager());
  });

  tearDownAll(serviceLocator.reset);

  group('Gateway screens render without crashing', () {
    testWidgets('Channels screen builds', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: ChannelsScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Instances screen builds', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: InstancesScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Sessions screen builds', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SessionsScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Usage screen builds', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: UsageScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Agents screen builds', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: AgentsScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Skills screen builds', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SkillsScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Nodes screen builds', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: NodesScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Debug screen builds', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: DebugScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Config screen builds', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: ConfigScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('Config screen specification', () {
    testWidgets('Config screen has no PopOutButton',
        (WidgetTester tester) async {
      // Per spec: Config section should NOT have pop-out functionality
      await tester.pumpWidget(const MaterialApp(home: ConfigScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      // Verify no open_in_new icon (PopOutButton indicator)
      expect(find.byIcon(Icons.open_in_new), findsNothing);
    });
  });
}
