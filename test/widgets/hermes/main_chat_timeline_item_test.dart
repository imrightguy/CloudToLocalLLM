import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';
import 'package:cloudtolocalllm/widgets/hermes/main_chat_timeline_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('MainChatTimelineItem', () {
    testWidgets('compact mode keeps local-think metadata minimal',
        (tester) async {
      final timestamp = DateTime.utc(2026, 5, 2, 12, 34);
      final expectedTimestamp =
          DateFormat('MMM d, HH:mm').format(timestamp.toLocal());

      await tester.pumpWidget(
        _wrap(
          MainChatTimelineItem(
            event: MainChatTimelineEvent(
              id: 'local-think:job-1:completed',
              type: MainChatTimelineEventType.localThinkCompleted,
              title: 'Background work completed',
              summary: 'Indexed project notes.',
              timestamp: timestamp,
              sourceId: 'job-1',
              metadata: <String, Object?>{
                'attempts': 1,
                'maxAttempts': 3,
                'dedupKey': 'project-index',
                'notify': 'telegram',
                'wakeGate': 'open',
                'parentTaskId': 'parent-1',
                'contextFrom': 'chain-base',
              },
            ),
          ),
        ),
      );

      expect(find.text(expectedTimestamp), findsOneWidget);
      expect(find.text('job-1'), findsNothing);
      expect(find.text('Attempt 1/3'), findsNothing);
      expect(find.text('Dedup: project-index'), findsNothing);
      expect(find.text('Notify: telegram'), findsNothing);
      expect(find.text('Wake gate: open'), findsNothing);
      expect(find.text('Parent: parent-1'), findsNothing);
      expect(find.text('Context: chain-base'), findsNothing);
    });

    testWidgets('verbose mode shows safe local-think metadata labels',
        (tester) async {
      final timestamp = DateTime.utc(2026, 5, 2, 12, 34);
      final expectedTimestamp =
          DateFormat('MMM d, HH:mm').format(timestamp.toLocal());

      await tester.pumpWidget(
        _wrap(
          MainChatTimelineItem(
            showVerboseDetails: true,
            event: MainChatTimelineEvent(
              id: 'local-think:job-1:completed',
              type: MainChatTimelineEventType.localThinkCompleted,
              title: 'Background work completed',
              summary: 'Indexed project notes.',
              timestamp: timestamp,
              sourceId: 'job-1',
              metadata: <String, Object?>{
                'attempts': 1,
                'maxAttempts': 3,
                'dedupKey': 'project-index',
                'notify': 'telegram',
                'wakeGate': 'open',
                'parentTaskId': 'parent-1',
                'contextFrom': 'chain-base',
                'rawLog': 'secret-bearing raw log',
                'token': 'secret-token',
              },
            ),
          ),
        ),
      );

      expect(find.text('job-1'), findsOneWidget);
      expect(find.text(expectedTimestamp), findsOneWidget);
      expect(find.text('Attempt 1/3'), findsOneWidget);
      expect(find.text('Dedup: project-index'), findsOneWidget);
      expect(find.text('Notify: telegram'), findsOneWidget);
      expect(find.text('Wake gate: open'), findsOneWidget);
      expect(find.text('Parent: parent-1'), findsOneWidget);
      expect(find.text('Context: chain-base'), findsOneWidget);
      expect(find.textContaining('secret-bearing raw log'), findsNothing);
      expect(find.textContaining('secret-token'), findsNothing);
    });

    testWidgets('shows exit code chip only in verbose failed background work',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MainChatTimelineItem(
            event: MainChatTimelineEvent(
              id: 'local-think:job-failed:failed',
              type: MainChatTimelineEventType.localThinkFailed,
              title: 'Background work failed',
              summary: 'Preview-safe failure summary.',
              metadata: <String, Object?>{'exitCode': 23},
            ),
          ),
        ),
      );

      expect(find.text('Exit: 23'), findsNothing);
      expect(find.text('Failed'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          const MainChatTimelineItem(
            showVerboseDetails: true,
            event: MainChatTimelineEvent(
              id: 'local-think:job-failed:failed',
              type: MainChatTimelineEventType.localThinkFailed,
              title: 'Background work failed',
              summary: 'Preview-safe failure summary.',
              metadata: <String, Object?>{'exitCode': 23},
            ),
          ),
        ),
      );

      expect(find.text('Exit: 23'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('renders completed local-think title and preview',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MainChatTimelineItem(
            event: MainChatTimelineEvent(
              id: 'local-think:job-1:completed',
              type: MainChatTimelineEventType.localThinkCompleted,
              title: 'Background work completed',
              summary: 'Indexed project notes.',
              timestamp: DateTime.utc(2026, 5, 2, 12),
            ),
          ),
        ),
      );

      expect(find.text('Background work completed'), findsOneWidget);
      expect(find.text('Indexed project notes.'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('renders silent skips quietly', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MainChatTimelineItem(
            event: MainChatTimelineEvent(
              id: 'local-think:job-2:completed',
              type: MainChatTimelineEventType.localThinkCompleted,
              title: 'Background work completed',
              summary: 'Silent wake-gate skip.',
              metadata: <String, Object?>{'isSilent': true},
            ),
          ),
        ),
      );

      expect(find.text('Silent wake-gate skip.'), findsOneWidget);
      expect(find.text('Failed'), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
    });

    testWidgets('keeps raw verbose metadata hidden by default', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MainChatTimelineItem(
            event: MainChatTimelineEvent(
              id: 'local-think:job-3:completed',
              type: MainChatTimelineEventType.localThinkCompleted,
              title: 'Background work completed',
              summary: 'Safe summary.',
              sourceId: 'job-3',
              metadata: <String, Object?>{
                'rawLog': 'secret-bearing raw log',
                'dedupKey': 'safe-key',
                'attempts': 1,
                'maxAttempts': 2,
              },
            ),
          ),
        ),
      );

      expect(find.text('Safe summary.'), findsOneWidget);
      expect(find.textContaining('secret-bearing raw log'), findsNothing);
      expect(find.text('Dedup: safe-key'), findsNothing);
      expect(find.text('Attempt 1/2'), findsNothing);
    });

    testWidgets('shows expandable body only in verbose mode', (tester) async {
      const event = MainChatTimelineEvent(
        id: 'tool:job-1:finished',
        type: MainChatTimelineEventType.toolFinished,
        title: 'Tool finished',
        summary: 'Search completed.',
        body: 'Checked 4 files and summarized 2 relevant matches.',
        isExpandable: true,
      );

      await tester.pumpWidget(
        _wrap(
          const MainChatTimelineItem(event: event),
        ),
      );

      expect(find.text('Search completed.'), findsOneWidget);
      expect(
        find.text('Checked 4 files and summarized 2 relevant matches.'),
        findsNothing,
      );

      await tester.pumpWidget(
        _wrap(
          const MainChatTimelineItem(
            event: event,
            showVerboseDetails: true,
          ),
        ),
      );

      expect(find.text('Search completed.'), findsOneWidget);
      expect(
        find.text('Checked 4 files and summarized 2 relevant matches.'),
        findsOneWidget,
      );
    });

    testWidgets('compact mode does not fall back to body without summary',
        (tester) async {
      const body = 'Detailed tool trace with token=secret-token';
      const event = MainChatTimelineEvent(
        id: 'local-think:job-body-only:completed',
        type: MainChatTimelineEventType.localThinkCompleted,
        title: 'Background work completed',
        body: body,
        isExpandable: true,
      );

      await tester.pumpWidget(
        _wrap(
          const MainChatTimelineItem(event: event),
        ),
      );

      expect(find.text(body), findsNothing);

      await tester.pumpWidget(
        _wrap(
          const MainChatTimelineItem(
            event: event,
            showVerboseDetails: true,
          ),
        ),
      );

      expect(find.text(body), findsOneWidget);
    });

    testWidgets('shows artifact affordance without raw full path',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MainChatTimelineItem(
            event: MainChatTimelineEvent(
              id: 'local-think:job-4:completed',
              type: MainChatTimelineEventType.localThinkCompleted,
              title: 'Background work completed',
              summary: 'Safe final preview.',
              artifactPath:
                  '/home/rightguy/.hermes/local-think/job/job.final.md',
              metadata: <String, Object?>{
                'rawLog': 'secret-bearing raw log',
              },
            ),
          ),
        ),
      );

      expect(find.text('Artifact available'), findsOneWidget);
      expect(find.text('job.final.md'), findsOneWidget);
      expect(
        find.textContaining('/home/rightguy/.hermes/local-think'),
        findsNothing,
      );
      expect(find.textContaining('secret-bearing raw log'), findsNothing);
    });

    testWidgets('shows windows artifact affordance without raw full path',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MainChatTimelineItem(
            event: MainChatTimelineEvent(
              id: 'local-think:job-4b:completed',
              type: MainChatTimelineEventType.localThinkCompleted,
              title: 'Background work completed',
              summary: 'Safe final preview.',
              artifactPath:
                  'C:\\Users\\rightguy\\.hermes\\local-think\\job\\job.final.md',
              metadata: <String, Object?>{
                'rawLog': 'secret-bearing raw log',
              },
            ),
          ),
        ),
      );

      expect(find.text('Artifact available'), findsOneWidget);
      expect(find.text('job.final.md'), findsOneWidget);
      expect(
        find.textContaining('C:\\Users\\rightguy\\.hermes\\local-think'),
        findsNothing,
      );
      expect(find.textContaining('secret-bearing raw log'), findsNothing);
    });

    testWidgets('renders cancelled background work with cancelled label',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MainChatTimelineItem(
            event: MainChatTimelineEvent(
              id: 'local-think:job-5:cancelled',
              type: MainChatTimelineEventType.localThinkCancelled,
              title: 'Background work cancelled',
              summary: 'Cancelled before retry.',
            ),
          ),
        ),
      );

      expect(find.text('Background work cancelled'), findsOneWidget);
      expect(find.text('Cancelled before retry.'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
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
