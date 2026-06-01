import 'package:cloudtolocalllm/screens/channels/channels_screen.dart';
import 'package:cloudtolocalllm/screens/instances/instances_screen.dart';
import 'package:cloudtolocalllm/screens/sessions/sessions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cockpit screens', () {
    testWidgets('ChannelsScreen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ChannelsScreen()),
      );
      await tester.pump();
      expect(find.byType(ChannelsScreen), findsOneWidget);
    });

    testWidgets('SessionsScreen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SessionsScreen()),
      );
      await tester.pump();
      expect(find.byType(SessionsScreen), findsOneWidget);
    });

    testWidgets('InstancesScreen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: InstancesScreen()),
      );
      await tester.pump();
      expect(find.byType(InstancesScreen), findsOneWidget);
    });
  });
}
