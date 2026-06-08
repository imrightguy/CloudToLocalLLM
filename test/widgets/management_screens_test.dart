import 'package:cloudtolocalllm/di/locator.dart' as di;
import 'package:cloudtolocalllm/screens/agents/agents_screen.dart';
import 'package:cloudtolocalllm/screens/cron/cron_jobs_screen.dart';
import 'package:cloudtolocalllm/screens/skills/skills_screen.dart';
import 'package:cloudtolocalllm/services/popout/popout_manager.dart';
import 'package:cloudtolocalllm/widgets/common/loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    if (di.serviceLocator.isRegistered<PopOutManager>()) {
      di.serviceLocator.unregister<PopOutManager>();
    }
    di.serviceLocator.registerSingleton<PopOutManager>(PopOutManager());
  });

  group('AgentsScreen', () {
    testWidgets('renders mock agent data after loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AgentsScreen(),
        ),
      );

      // Screen starts in loading state with LoadingSkeleton.
      expect(find.byType(LoadingSkeleton), findsWidgets);

      // Pump past the simulated 300ms data load.
      await tester.pump(const Duration(milliseconds: 400));

      // Mock data should now be rendered.
      expect(find.text('Code Review Agent'), findsOneWidget);
      expect(find.text('File Scanner Agent'), findsOneWidget);
      expect(find.text('Document Summarizer Agent'), findsOneWidget);

      // Tab controller should be present (3 tabs).
      expect(find.byType(Tab), findsNWidgets(3));
    });
  });

  group('SkillsScreen', () {
    testWidgets('renders skills list after loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SizedBox(
            width: 1200,
            height: 800,
            child: SkillsScreen(),
          ),
        ),
      );

      expect(find.byType(LoadingSkeleton), findsWidgets);
      await tester.pump(const Duration(milliseconds: 400));

      // Tab controller with 3 tabs.
      expect(find.byType(Tab), findsNWidgets(3));
    });
  });

  group('CronJobsScreen', () {
    testWidgets('shows scheduled tasks after loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CronJobsScreen(),
        ),
      );

      expect(find.byType(LoadingSkeleton), findsWidgets);
      await tester.pump(const Duration(milliseconds: 400));

      // CronJobsScreen loads mock jobs.
      expect(find.text('Cron Jobs'), findsOneWidget);
    });
  });
}
