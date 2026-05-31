import 'package:cloudtolocalllm/models/local_think_job.dart';
import 'package:cloudtolocalllm/widgets/hermes/local_think_train_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalThinkTrainCard', () {
    testWidgets('shows a compact local-think summary without raw paths', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LocalThinkTrainCard(
            jobs: <LocalThinkJob>[
              LocalThinkJob(
                taskId: 'job-1',
                name: 'summarize-project',
                status: LocalThinkJobStatus.completed,
                attempts: 1,
                maxAttempts: 2,
                finalPreview: 'Project summary ready.',
                finalFile: '/home/rightguy/.hermes/local-think/job-1/final.md',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Local-think train'), findsOneWidget);
      expect(find.text('1 job'), findsOneWidget);
      expect(find.text('Project summary ready.'), findsOneWidget);
      expect(find.text('final.md'), findsOneWidget);
      expect(
        find.textContaining('/home/rightguy/.hermes/local-think/job-1'),
        findsNothing,
      );
    });

    testWidgets('shows verbose metadata through the mixed timeline item', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LocalThinkTrainCard(
            showVerboseDetails: true,
            jobs: <LocalThinkJob>[
              LocalThinkJob(
                taskId: 'job-2',
                name: 'inspect-logs',
                status: LocalThinkJobStatus.failed,
                attempts: 2,
                maxAttempts: 3,
                dedupKey: 'inspect-logs',
                notify: 'telegram',
                wakeGate: 'open',
                parentTaskId: 'parent-1',
                contextFrom: 'parent-1',
                exitCode: 23,
                finalPreview: 'Preview-safe failure summary.',
                finalFile: '/tmp/job-2/final.md',
              ),
            ],
          ),
        ),
      );

      expect(find.text('job-2'), findsOneWidget);
      expect(find.text('Attempt 2/3'), findsOneWidget);
      expect(find.text('Dedup: inspect-logs'), findsOneWidget);
      expect(find.text('Notify: telegram'), findsOneWidget);
      expect(find.text('Wake gate: open'), findsOneWidget);
      expect(find.text('Parent: parent-1'), findsOneWidget);
      expect(find.text('Context: parent-1'), findsOneWidget);
      expect(find.text('Exit: 23'), findsOneWidget);
      expect(find.textContaining('/tmp/job-2/final.md'), findsNothing);
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}
