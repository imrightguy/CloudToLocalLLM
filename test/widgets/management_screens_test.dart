import 'dart:async';

import 'package:cloudtolocalllm/di/locator.dart' as di;
import 'package:cloudtolocalllm/models/cron_job.dart';
import 'package:cloudtolocalllm/screens/agents/agents_screen.dart';
import 'package:cloudtolocalllm/screens/cron/cron_jobs_screen.dart';
import 'package:cloudtolocalllm/screens/skills/skills_screen.dart';
import 'package:cloudtolocalllm/services/cron_management_service.dart';
import 'package:cloudtolocalllm/services/popout/popout_manager.dart';
import 'package:cloudtolocalllm/services/skill_catalog_service.dart';
import 'package:cloudtolocalllm/widgets/common/error_state.dart';
import 'package:cloudtolocalllm/widgets/common/loading_skeleton.dart';
import 'package:cloudtolocalllm/services/subagent_registry_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSubagentRegistryService extends SubagentRegistryService {
  FakeSubagentRegistryService(this._subagents)
      : super(apiBaseUrl: 'http://example.invalid');

  final List<Subagent> _subagents;

  @override
  Future<List<Subagent>> listSubagents(
      {String? status, String? agentId}) async {
    return _subagents;
  }

  @override
  Future<bool> updateStatus(
    String subagentId, {
    required SubagentStatus status,
    result,
    String? logs,
    String? error,
  }) async {
    return true;
  }

  @override
  Future<bool> deleteSubagent(String subagentId) async {
    return true;
  }
}

class FakeSkillCatalogService extends SkillCatalogService {
  FakeSkillCatalogService(this._skills) : super(scanRoots: const []);

  final List<ManagedSkill> _skills;

  @override
  Future<List<ManagedSkill>> listSkills() async => _skills;

  @override
  Future<void> setSkillEnabled(String skillId, bool enabled) async {
    for (var i = 0; i < _skills.length; i++) {
      if (_skills[i].id == skillId) {
        _skills[i] = _skills[i].copyWith(enabled: enabled);
      }
    }
  }
}

class FakeCronManagementService extends CronManagementService {
  FakeCronManagementService({
    List<CronJob> jobs = const [],
    this.listHandler,
    this.throwOnList = false,
  })  : _jobs = jobs.toList(growable: true),
        super(apiBaseUrl: 'http://example.invalid');

  final Future<List<CronJob>> Function()? listHandler;
  final bool throwOnList;
  final List<Map<String, dynamic>> enabledCalls = [];
  final List<String> deletedIds = [];
  final List<String> runIds = [];
  final List<CronJob> _jobs;

  @override
  Future<List<CronJob>> listCronJobs() async {
    if (listHandler != null) {
      return listHandler!();
    }

    if (throwOnList) {
      throw StateError('cron backend unavailable');
    }

    return List<CronJob>.unmodifiable(_jobs);
  }

  @override
  Future<bool> setCronJobEnabled(String cronJobId, bool enabled) async {
    enabledCalls.add({'id': cronJobId, 'enabled': enabled});
    for (var i = 0; i < _jobs.length; i++) {
      if (_jobs[i].id == cronJobId) {
        _jobs[i] = _jobs[i].copyWith(
          status: enabled ? CronJobStatus.active : CronJobStatus.inactive,
        );
      }
    }
    return true;
  }

  @override
  Future<bool> deleteCronJob(String cronJobId) async {
    deletedIds.add(cronJobId);
    _jobs.removeWhere((job) => job.id == cronJobId);
    return true;
  }

  @override
  Future<bool> runCronJob(String cronJobId) async {
    runIds.add(cronJobId);
    return true;
  }
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    if (di.serviceLocator.isRegistered<PopOutManager>()) {
      di.serviceLocator.unregister<PopOutManager>();
    }
    di.serviceLocator.registerSingleton<PopOutManager>(PopOutManager());
  });

  testWidgets('AgentsScreen renders the live subagent registry',
      (tester) async {
    final fakeService = FakeSubagentRegistryService([
      Subagent(
        subagentId: 'subagent-1',
        label: 'Planner',
        agentId: 'agent-42',
        task: 'Outline implementation plan',
        status: SubagentStatus.running,
        createdAt: DateTime(2026, 1, 2, 10, 15),
        startedAt: DateTime(2026, 1, 2, 10, 16),
        logs: 'Planner started successfully.',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: const AgentsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Planner'), findsOneWidget);
    expect(find.textContaining('agent-42'), findsOneWidget);
    expect(find.text('RUNNING'), findsOneWidget);
  });

  testWidgets('SkillsScreen renders discovered skills and toggles enablement',
      (tester) async {
    final service = FakeSkillCatalogService([
      ManagedSkill(
        id: 'writer-skill',
        name: 'Writer Skill',
        description: 'Drafts concise content.',
        category: 'Writing',
        version: '0.1.0',
        enabled: true,
        sourcePath: '/tmp/writer-skill',
        sourceScope: 'repository',
        lastModified: DateTime(2026, 1, 2),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: const SkillsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Writer Skill'), findsOneWidget);
    expect(find.text('Enabled'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Disable'));
    await tester.pumpAndSettle();

    expect(find.text('Writer Skill'), findsOneWidget);
    expect(find.text('Disabled'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Enable'), findsOneWidget);
  });

  testWidgets('CronJobsScreen shows loading, empty, error, and action states',
      (tester) async {
    final loadCompleter = Completer<List<CronJob>>();
    final loadingService = FakeCronManagementService(
      listHandler: () => loadCompleter.future,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: const CronJobsScreen(),
      ),
    );

    expect(find.byType(LoadingSkeleton), findsOneWidget);

    loadCompleter.complete([]);
    await tester.pumpAndSettle();

    expect(find.text('No scheduled tasks yet'), findsOneWidget);
    expect(
      find.textContaining('Connect a runtime with scheduled jobs'),
      findsOneWidget,
    );

    final emptyService = FakeCronManagementService();
    await tester.pumpWidget(
      MaterialApp(
        home: const CronJobsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No scheduled tasks yet'), findsOneWidget);

    final errorService = FakeCronManagementService(throwOnList: true);
    await tester.pumpWidget(
      MaterialApp(
        home: const CronJobsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);

    final actionService = FakeCronManagementService(
      jobs: [
        CronJob(
          id: 'daily-digest',
          name: 'Daily Digest',
          schedule: '0 8 * * *',
          scheduleDescription: 'Every morning at 8:00',
          command: 'python scripts/digest.py',
          status: CronJobStatus.active,
          nextRun: DateTime(2026, 1, 2, 8),
          lastRun: DateTime(2026, 1, 1, 8),
          lastRunOutput: 'Digest sent.',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: const CronJobsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily Digest'), findsOneWidget);
    expect(find.text('Disable'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Disable'));
    await tester.pumpAndSettle();

    expect(actionService.enabledCalls, isNotEmpty);
    expect(actionService.enabledCalls.last['id'], 'daily-digest');
    expect(actionService.enabledCalls.last['enabled'], isFalse);
    expect(find.text('Enable'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(actionService.deletedIds, contains('daily-digest'));
    expect(find.text('No scheduled tasks yet'), findsOneWidget);
  });
}
