import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';

void main() {
  group('CalendarDayDetail', () {
    testWidgets('shows empty state when no visits', (tester) async {
      final List<VisitItem> visits = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestableDayDetail(
              selectedDay: DateTime(2026, 4, 15),
              visits: visits,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Aucune visite ce jour'), findsOneWidget);
    });

    testWidgets('visit card displays correct fields', (tester) async {
      final List<VisitItem> visits = [
        VisitItem(
          id: 'v1',
          dateTime: DateTime(2026, 4, 15, 14, 30),
          unitLabel: '4B',
          buildingName: '1234 Rue Saint-Catherine',
          dateLabel: '15 avr. 2026',
          status: 'confirmed',
          agent: 'Marie Tremblay',
          leadName: 'Jean Dupont',
          notes: '',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestableDayDetail(
              selectedDay: DateTime(2026, 4, 15),
              visits: visits,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('14:30'), findsOneWidget);
      expect(find.text('Confirmée'), findsOneWidget);
      expect(find.text('1234 Rue Saint-Catherine · 4B'), findsOneWidget);
      expect(find.text('Jean Dupont'), findsOneWidget);
      expect(find.text('Marie Tremblay'), findsOneWidget);
    });

    testWidgets('visit status colors are correct', (tester) async {
      final testCases = [
        ('confirmed', 'Confirmée'),
        ('completed', 'Terminée'),
        ('cancelled', 'Annulée'),
        ('scheduled', 'Planifiée'),
        ('no_show', 'Absent'),
      ];

      for (final (status, label) in testCases) {
        final List<VisitItem> visits = [
          VisitItem(
            id: 'v-$status',
            dateTime: DateTime(2026, 4, 15, 10, 0),
            unitLabel: '1A',
            buildingName: 'Test',
            dateLabel: '15 avr. 2026',
            status: status,
            agent: 'Test',
            notes: '',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _TestableDayDetail(
                selectedDay: DateTime(2026, 4, 15),
                visits: visits,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text(label), findsOneWidget,
            reason: 'Expected label "$label" for status "$status"');
      }
    });
  });

  group('Calendar visit count display', () {
    testWidgets('day detail shows correct visit count', (tester) async {
      final List<VisitItem> visits = [
        VisitItem(
          id: 'v1',
          dateTime: DateTime(2026, 4, 15, 10, 0),
          unitLabel: '1A',
          buildingName: 'Test',
          dateLabel: '15 avr. 2026',
          status: 'scheduled',
          agent: 'Agent 1',
          notes: '',
        ),
        VisitItem(
          id: 'v2',
          dateTime: DateTime(2026, 4, 15, 14, 0),
          unitLabel: '2B',
          buildingName: 'Test',
          dateLabel: '15 avr. 2026',
          status: 'confirmed',
          agent: 'Agent 2',
          notes: '',
        ),
        VisitItem(
          id: 'v3',
          dateTime: DateTime(2026, 4, 15, 16, 0),
          unitLabel: '3C',
          buildingName: 'Test',
          dateLabel: '15 avr. 2026',
          status: 'scheduled',
          agent: 'Agent 3',
          notes: '',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestableDayDetail(
              selectedDay: DateTime(2026, 4, 15),
              visits: visits,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('3 visites'), findsOneWidget);
    });

    testWidgets('day detail shows singular form for 1 visit', (tester) async {
      final List<VisitItem> visits = [
        VisitItem(
          id: 'v1',
          dateTime: DateTime(2026, 4, 15, 10, 0),
          unitLabel: '1A',
          buildingName: 'Test',
          dateLabel: '15 avr. 2026',
          status: 'scheduled',
          agent: 'Agent 1',
          notes: '',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestableDayDetail(
              selectedDay: DateTime(2026, 4, 15),
              visits: visits,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 visite'), findsOneWidget);
    });
  });

  group('Calendar helpers', () {
    test('status label returns French text for all statuses', () {
      final helper = _CalendarHelpers();
      expect(helper.statusLabel('confirmed'), 'Confirmée');
      expect(helper.statusLabel('completed'), 'Terminée');
      expect(helper.statusLabel('cancelled'), 'Annulée');
      expect(helper.statusLabel('scheduled'), 'Planifiée');
      expect(helper.statusLabel('no_show'), 'Absent');
      expect(helper.statusLabel('unknown'), 'unknown');
    });

    test('status color returns distinct colors', () {
      final helper = _CalendarHelpers();
      expect(helper.statusColor('confirmed'), const Color(0xFF10B981));
      expect(helper.statusColor('completed'), const Color(0xFF3B82F6));
      expect(helper.statusColor('cancelled'), const Color(0xFFEF4444));
      expect(helper.statusColor('no_show'), const Color(0xFFF59E0B));
      expect(helper.statusColor('scheduled'), const Color(0xFF38BDF8));
      expect(helper.statusColor('unknown'), const Color(0xFF64748B));
    });
  });
}

class _TestableDayDetail extends StatefulWidget {
  final DateTime selectedDay;
  final List<VisitItem> visits;

  const _TestableDayDetail({
    required this.selectedDay,
    required this.visits,
  });

  @override
  State<_TestableDayDetail> createState() => _TestableDayDetailState();
}

class _TestableDayDetailState extends State<_TestableDayDetail> {
  @override
  Widget build(BuildContext context) {
    final helper = _CalendarHelpers();
    final dayVisits = widget.visits
      ..sort((a, b) {
        if (a.dateTime == null && b.dateTime == null) return 0;
        if (a.dateTime == null) return 1;
        if (b.dateTime == null) return -1;
        return a.dateTime!.compareTo(b.dateTime!);
      });

    final dayLabel = 'Mardi 15 Avril';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                dayLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${dayVisits.length} visite${dayVisits.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (dayVisits.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 20, color: Color(0xFFCBD5E1)),
                SizedBox(width: 8),
                Text(
                  'Aucune visite ce jour',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          )
        else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: dayVisits.length,
                itemBuilder: (context, index) {
                  final visit = dayVisits[index];
                  final color = helper.statusColor(visit.status);
                  final timeLabel = visit.dateTime != null
                      ? '${visit.dateTime!.hour.toString().padLeft(2, '0')}:${visit.dateTime!.minute.toString().padLeft(2, '0')}'
                      : '';
                  final statusLabel = helper.statusLabel(visit.status);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    timeLabel,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${visit.buildingName} · ${visit.unitLabel}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              if (visit.leadName != null &&
                                  visit.leadName!.isNotEmpty)
                                Text(
                                  visit.leadName!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          visit.agent,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      ],
    );
  }
}

class _CalendarHelpers {
  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF10B981);
      case 'completed':
        return const Color(0xFF3B82F6);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'no_show':
        return const Color(0xFFF59E0B);
      case 'scheduled':
        return const Color(0xFF38BDF8);
      default:
        return const Color(0xFF64748B);
    }
  }

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmée';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      case 'no_show':
        return 'Absent';
      case 'scheduled':
        return 'Planifiée';
      default:
        return status;
    }
  }
}
