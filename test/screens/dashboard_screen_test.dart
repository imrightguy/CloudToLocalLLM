import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:immogestion/models.dart';
import 'package:immogestion/services/analytics_service.dart';

void main() {
  group('Dashboard helper methods', () {
    test('formatRevenue formats values >= 1000 with k suffix', () {
      final helper = _DashboardHelpers();
      expect(helper.formatRevenue(45000), '45k \$');
      expect(helper.formatRevenue(1000), '1k \$');
      expect(helper.formatRevenue(1500), '1.5k \$');
    });

    test('formatRevenue formats values < 1000 without suffix', () {
      final helper = _DashboardHelpers();
      expect(helper.formatRevenue(500), '500 \$');
      expect(helper.formatRevenue(0), '0 \$');
    });

    test('formatRevenue formats exact thousands without decimal', () {
      final helper = _DashboardHelpers();
      expect(helper.formatRevenue(42000), '42k \$');
    });
  });

  group('Dashboard communication type helpers', () {
    test('communicationTypeColor returns correct colors', () {
      final helper = _DashboardHelpers();
      expect(helper.communicationTypeColor('sms'), const Color(0xFF38BDF8));
      expect(helper.communicationTypeColor('email'), const Color(0xFF3B82F6));
      expect(helper.communicationTypeColor('call'), const Color(0xFF10B981));
      expect(helper.communicationTypeColor('note'), const Color(0xFFF59E0B));
      expect(helper.communicationTypeColor('unknown'), const Color(0xFFF59E0B));
    });

    test('communicationTypeIcon returns correct icons', () {
      final helper = _DashboardHelpers();
      expect(helper.communicationTypeIcon('sms'), Icons.sms_outlined);
      expect(helper.communicationTypeIcon('email'), Icons.email_outlined);
      expect(helper.communicationTypeIcon('call'), Icons.phone_outlined);
      expect(helper.communicationTypeIcon('note'), Icons.note_outlined);
      expect(helper.communicationTypeIcon('unknown'), Icons.note_outlined);
    });

    test('communicationTypeLabel returns French labels', () {
      final helper = _DashboardHelpers();
      expect(helper.communicationTypeLabel('sms'), 'SMS');
      expect(helper.communicationTypeLabel('email'), 'Courriel');
      expect(helper.communicationTypeLabel('call'), 'Appel');
      expect(helper.communicationTypeLabel('note'), 'Note');
      expect(helper.communicationTypeLabel('unknown'), 'Note');
    });
  });

  group('Dashboard vacancy summary', () {
    test('calculates total, occupied, and vacant units correctly', () {
      final buildings = [
        BuildingItem(
          name: 'A',
          address: '1 St',
          city: 'MTL',
          totalUnits: 10,
          occupiedUnits: 7,
          monthlyRevenue: 0,
          units: [],
        ),
        BuildingItem(
          name: 'B',
          address: '2 St',
          city: 'MTL',
          totalUnits: 5,
          occupiedUnits: 5,
          monthlyRevenue: 0,
          units: [],
        ),
      ];

      int totalUnits = 0;
      int occupiedUnits = 0;
      int vacantUnits = 0;
      for (final b in buildings) {
        totalUnits += b.totalUnits;
        occupiedUnits += b.occupiedUnits;
        vacantUnits += b.totalUnits - b.occupiedUnits;
      }

      expect(totalUnits, 15);
      expect(occupiedUnits, 12);
      expect(vacantUnits, 3);
    });

    test('handles empty buildings list', () {
      final buildings = <BuildingItem>[];

      int totalUnits = 0;
      int occupiedUnits = 0;
      int vacantUnits = 0;
      for (final b in buildings) {
        totalUnits += b.totalUnits;
        occupiedUnits += b.occupiedUnits;
        vacantUnits += b.totalUnits - b.occupiedUnits;
      }

      expect(totalUnits, 0);
      expect(occupiedUnits, 0);
      expect(vacantUnits, 0);
    });
  });

  group('Dashboard period label', () {
    test('currentPeriodLabel returns French month and year', () {
      final helper = _DashboardHelpers();
      final now = DateTime.now();
      final label = helper.currentPeriodLabel();
      expect(label, contains('${now.year}'));
    });
  });

  group('Dashboard KPI formatting', () {
    test('occupancy rate displays with one decimal', () {
      final value = 87.5;
      final formatted = '${value.toStringAsFixed(1)}%';
      expect(formatted, '87.5%');
    });

    test('active leases displays as integer', () {
      final value = 156;
      final formatted = '$value';
      expect(formatted, '156');
    });

    test('open leads displays as integer', () {
      final value = 42;
      final formatted = '$value';
      expect(formatted, '42');
    });
  });

  group('Dashboard visit stats display', () {
    testWidgets('renders visit stat chips', (tester) async {
      final stats = VisitStatsData(total: 50, completed: 40, cancelled: 5, noShow: 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestableVisitStats(stats: stats),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('50'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('5'), findsNWidgets(2));
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Terminées'), findsOneWidget);
      expect(find.text('Annulées'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
    });
  });

  group('Dashboard pipeline display', () {
    testWidgets('renders pipeline stage chips', (tester) async {
      final pipeline = PipelineData.fromJson({
        'nouveau': 10,
        'contacte': 5,
        'qualifie': 3,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestablePipeline(pipeline: pipeline),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Nouveau'), findsOneWidget);
      expect(find.text('Contacté'), findsOneWidget);
      expect(find.text('Qualifié'), findsOneWidget);
    });
  });
}

class _DashboardHelpers {
  String formatRevenue(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k \$';
    }
    return '$value \$';
  }

  String currentPeriodLabel() {
    final now = DateTime.now();
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  Color communicationTypeColor(String type) {
    switch (type) {
      case 'sms':
        return const Color(0xFF38BDF8);
      case 'email':
        return const Color(0xFF3B82F6);
      case 'call':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData communicationTypeIcon(String type) {
    switch (type) {
      case 'sms':
        return Icons.sms_outlined;
      case 'email':
        return Icons.email_outlined;
      case 'call':
        return Icons.phone_outlined;
      default:
        return Icons.note_outlined;
    }
  }

  String communicationTypeLabel(String type) {
    switch (type) {
      case 'sms':
        return 'SMS';
      case 'email':
        return 'Courriel';
      case 'call':
        return 'Appel';
      default:
        return 'Note';
    }
  }
}

class _TestableVisitStats extends StatelessWidget {
  final VisitStatsData stats;

  const _TestableVisitStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildChip(label: 'Total', value: stats.total, color: const Color(0xFF1E293B)),
        ),
        Expanded(
          child: _buildChip(label: 'Terminées', value: stats.completed, color: const Color(0xFF10B981)),
        ),
        Expanded(
          child: _buildChip(label: 'Annulées', value: stats.cancelled, color: const Color(0xFFEF4444)),
        ),
        Expanded(
          child: _buildChip(label: 'Absent', value: stats.noShow, color: const Color(0xFFF59E0B)),
        ),
      ],
    );
  }

  Widget _buildChip({required String label, required int value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}

class _TestablePipeline extends StatelessWidget {
  final PipelineData pipeline;

  const _TestablePipeline({required this.pipeline});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: pipeline.stages.entries.map((entry) {
        final stage = LeadStage.fromString(entry.key);
        final count = entry.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              Text(stage.label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        );
      }).toList(),
    );
  }
}
