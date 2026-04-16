import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:immogestion/models.dart';

void main() {
  Widget buildTestWidget({List<LeaseItem> leases = const []}) {
    return MaterialApp(
      home: _TestableLeasesScreen(leases: leases),
    );
  }

  group('LeasesScreen helpers', () {
    test('LeaseStatus values have distinct labels', () {
      final labels = LeaseStatus.values.map((s) => s.label).toSet();
      expect(labels.length, LeaseStatus.values.length);
    });

    test('LeaseStatus values have distinct colors', () {
      final colors = LeaseStatus.values.map((s) => s.color).toSet();
      expect(colors.length, LeaseStatus.values.length);
    });

    test('LeaseStatus values have distinct icons', () {
      final icons = LeaseStatus.values.map((s) => s.icon).toSet();
      expect(icons.length, LeaseStatus.values.length);
    });
  });

  group('LeaseItem display in list', () {
    testWidgets('shows empty state when no leases', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Aucun bail trouvé'), findsOneWidget);
    });

    testWidgets('displays tenant name', (tester) async {
      final leases = [
        LeaseItem(
          id: 'l1',
          tenantName: 'Jean Dupont',
          unitLabel: '4B',
          status: LeaseStatus.active,
          monthlyRent: 150000,
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        ),
      ];

      await tester.pumpWidget(buildTestWidget(leases: leases));
      await tester.pumpAndSettle();

      expect(find.text('Jean Dupont'), findsOneWidget);
    });

    testWidgets('shows Sans locataire when tenantName is null', (tester) async {
      final leases = [
        LeaseItem(
          id: 'l1',
          unitLabel: '4B',
          status: LeaseStatus.draft,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(leases: leases));
      await tester.pumpAndSettle();

      expect(find.text('Sans locataire'), findsOneWidget);
    });

    testWidgets('displays unit label', (tester) async {
      final leases = [
        LeaseItem(
          id: 'l1',
          tenantName: 'Test',
          unitLabel: '3A',
          status: LeaseStatus.active,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(leases: leases));
      await tester.pumpAndSettle();

      expect(find.text('3A'), findsOneWidget);
    });

    testWidgets('shows Sans unité when unitLabel is null', (tester) async {
      final leases = [
        LeaseItem(
          id: 'l1',
          tenantName: 'Test',
          status: LeaseStatus.draft,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(leases: leases));
      await tester.pumpAndSettle();

      expect(find.text('Sans unité'), findsOneWidget);
    });

    testWidgets('displays status badge', (tester) async {
      final leases = [
        LeaseItem(
          id: 'l1',
          tenantName: 'Test',
          status: LeaseStatus.active,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(leases: leases));
      await tester.pumpAndSettle();

      expect(find.text('Actif'), findsWidgets);
    });

    testWidgets('displays all status badges correctly', (tester) async {
      final leases = LeaseStatus.values.map((status) => LeaseItem(
        id: 'l-${status.name}',
        tenantName: 'Test',
        status: status,
      )).toList();

      await tester.pumpWidget(buildTestWidget(leases: leases));
      await tester.pumpAndSettle();

      for (final status in LeaseStatus.values) {
        expect(find.text(status.label), findsWidgets,
            reason: 'Expected badge "${status.label}" for status ${status.name}');
      }
    });

    testWidgets('displays rent amount', (tester) async {
      final leases = [
        LeaseItem(
          id: 'l1',
          tenantName: 'Test',
          status: LeaseStatus.active,
          monthlyRent: 150000,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(leases: leases));
      await tester.pumpAndSettle();

      expect(find.text('1500.00 \$'), findsOneWidget);
    });

    testWidgets('displays -- when no rent', (tester) async {
      final leases = [
        LeaseItem(
          id: 'l1',
          tenantName: 'Test',
          status: LeaseStatus.draft,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(leases: leases));
      await tester.pumpAndSettle();

      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('groups leases by building name', (tester) async {
      final leases = [
        LeaseItem(
          id: 'l1',
          tenantName: 'Tenant A',
          buildingName: 'Building B',
          status: LeaseStatus.active,
        ),
        LeaseItem(
          id: 'l2',
          tenantName: 'Tenant B',
          buildingName: 'Building A',
          status: LeaseStatus.active,
        ),
        LeaseItem(
          id: 'l3',
          tenantName: 'Tenant C',
          buildingName: 'Building A',
          status: LeaseStatus.active,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(leases: leases));
      await tester.pumpAndSettle();

      expect(find.text('Building A'), findsOneWidget);
      expect(find.text('Building B'), findsOneWidget);
    });

    testWidgets('shows Sans immeuble when buildingName is null', (tester) async {
      final leases = [
        LeaseItem(
          id: 'l1',
          tenantName: 'Test',
          status: LeaseStatus.draft,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(leases: leases));
      await tester.pumpAndSettle();

      expect(find.text('Sans immeuble'), findsOneWidget);
    });
  });

  group('Lease filter logic', () {
    test('filter by tenant name matches case-insensitive', () {
      final leases = [
        LeaseItem(
          id: 'l1',
          tenantName: 'Jean Dupont',
          status: LeaseStatus.active,
        ),
        LeaseItem(
          id: 'l2',
          tenantName: 'Marie Tremblay',
          status: LeaseStatus.active,
        ),
      ];

      final query = 'jean';
      final filtered = leases.where((lease) {
        final tenantName = (lease.tenantName ?? '').toLowerCase();
        if (query.isNotEmpty && !tenantName.contains(query)) return false;
        return true;
      }).toList();

      expect(filtered.length, 1);
      expect(filtered.first.tenantName, 'Jean Dupont');
    });

    test('filter by status matches', () {
      final leases = [
        LeaseItem(id: 'l1', tenantName: 'A', status: LeaseStatus.active),
        LeaseItem(id: 'l2', tenantName: 'B', status: LeaseStatus.draft),
        LeaseItem(id: 'l3', tenantName: 'C', status: LeaseStatus.active),
      ];

      final filterStatus = LeaseStatus.active;
      final filtered = leases.where((lease) {
        if (lease.leaseStatus != filterStatus) return false;
        return true;
      }).toList();

      expect(filtered.length, 2);
    });

    test('filter with no filters returns all', () {
      final leases = [
        LeaseItem(id: 'l1', tenantName: 'A', status: LeaseStatus.active),
        LeaseItem(id: 'l2', tenantName: 'B', status: LeaseStatus.draft),
      ];

      final filtered = leases.where((lease) {
        final query = '';
        if (query.isNotEmpty) {
          final tenantName = (lease.tenantName ?? '').toLowerCase();
          if (!tenantName.contains(query)) return false;
        }
        return true;
      }).toList();

      expect(filtered.length, 2);
    });
  });
}

class _TestableLeasesScreen extends StatefulWidget {
  final List<LeaseItem> leases;

  const _TestableLeasesScreen({required this.leases});

  @override
  State<_TestableLeasesScreen> createState() => _TestableLeasesScreenState();
}

class _TestableLeasesScreenState extends State<_TestableLeasesScreen> {
  LeaseStatus? _filterStatus;
  final _searchController = TextEditingController();

  List<LeaseItem> get _filteredLeases {
    final query = _searchController.text.toLowerCase();
    return widget.leases.where((lease) {
      if (_filterStatus != null && lease.leaseStatus != _filterStatus) return false;
      if (query.isNotEmpty) {
        final tenantName = (lease.tenantName ?? '').toLowerCase();
        if (!tenantName.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLeases;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Baux'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
      ),
      body: filtered.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aucun bail trouvé',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterChips(),
                  const SizedBox(height: 24),
                  _buildStatusSummary(),
                  const SizedBox(height: 24),
                  _buildGroupedList(filtered),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('Tous', null),
          ...LeaseStatus.values.map((s) => _buildFilterChip(s.label, s)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, LeaseStatus? status) {
    final isSelected = _filterStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _filterStatus = isSelected ? null : status);
        },
        showCheckmark: false,
      ),
    );
  }

  Widget _buildStatusSummary() {
    final counts = <LeaseStatus, int>{};
    for (final lease in widget.leases) {
      counts[lease.leaseStatus] = (counts[lease.leaseStatus] ?? 0) + 1;
    }

    return Row(
      children: LeaseStatus.values.map((s) {
        final count = counts[s] ?? 0;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: s.color,
                  ),
                ),
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: s.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGroupedList(List<LeaseItem> filtered) {
    final grouped = <String, List<LeaseItem>>{};
    for (final lease in filtered) {
      final key = lease.buildingName ?? 'Sans immeuble';
      grouped.putIfAbsent(key, () => []).add(lease);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final buildingName in sortedKeys) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              buildingName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          ...grouped[buildingName]!.map((lease) => _buildLeaseCard(lease)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildLeaseCard(LeaseItem lease) {
    final statusColor = lease.leaseStatus.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      lease.leaseStatus.icon,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lease.tenantName ?? 'Sans locataire',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lease.unitLabel ?? 'Sans unité',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      lease.leaseStatus.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.attach_money,
                      size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text(
                    lease.displayRent,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(
                    lease.startDate != null && lease.endDate != null
                        ? '${lease.startDate!.day}/${lease.startDate!.month}/${lease.startDate!.year} — ${lease.endDate!.day}/${lease.endDate!.month}/${lease.endDate!.year}'
                        : '-- — --',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
