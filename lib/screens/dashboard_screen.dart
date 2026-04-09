import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // Analytics data
  Map<String, dynamic> _pipeline = {};
  List<dynamic> _hotLeads = [];
  Map<String, dynamic> _visitStats = {};
  Map<String, dynamic> _conversionRates = {};
  // _leadSources and _weeklyStats stored for future use
  // ignore: unused_field
  Map<String, dynamic> _leadSources = {};
  // ignore: unused_field
  Map<String, dynamic> _weeklyStats = {};

  // Buildings for top buildings section
  List<BuildingItem> _buildings = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        ApiService.instance.get('/analytics/dashboard'),
        ApiService.instance.get('/buildings'),
      ]);

      final analyticsResponse = results[0];
      final buildingsResponse = results[1];

      final analyticsData = analyticsResponse['data'] as Map<String, dynamic>? ?? {};
      final buildingsData = buildingsResponse['data'] as List<dynamic>;

      setState(() {
        _pipeline =
            (analyticsData['pipeline'] as Map<String, dynamic>?) ?? {};
        _hotLeads = (analyticsData['hotLeads'] as List<dynamic>?) ?? [];
        _visitStats =
            (analyticsData['visitStats'] as Map<String, dynamic>?) ?? {};
        _conversionRates =
            (analyticsData['conversionRates'] as Map<String, dynamic>?) ?? {};
        _leadSources =
            (analyticsData['leadSources'] as Map<String, dynamic>?) ?? {};
        _weeklyStats =
            (analyticsData['weeklyStats'] as Map<String, dynamic>?) ?? {};

        _buildings = buildingsData
            .map((e) => BuildingItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  int _pipelineTotal() {
    return _pipeline.values.fold<int>(0, (sum, v) => sum + (v as num).toInt());
  }

  String _currentPeriodLabel() {
    final now = DateTime.now();
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Impossible de charger le tableau de bord',
                style: TextStyle(fontSize: 16, color: Color(0xFF1E293B)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchDashboard,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDashboard,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period selector
            Row(
              children: [
                const Text(
                  'Période:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        const Color((0xFF0F766E)).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _currentPeriodLabel(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0F766E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon:
                      const Icon(Icons.calendar_month_outlined, size: 16),
                  onPressed: () {},
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Revenue chart placeholder
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revenus mensuels',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 200,
                    color: const Color(0xFFF3F4F6),
                    child: const Center(
                      child: Text(
                        'Graphique des revenus',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Pipeline summary
            if (_pipeline.isNotEmpty) ...[
              const Text(
                'Pipeline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _pipeline.entries.map((entry) {
                  final stage = LeadStage.fromString(entry.key);
                  final count = (entry.value as num).toInt();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          stage.label,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Visit stats
            if (_visitStats.isNotEmpty) ...[
              const Text(
                'Statistiques des visites',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildVisitStatChip(
                    label: 'Total',
                    value: (_visitStats['total'] as num?)?.toInt() ?? 0,
                    color: const Color(0xFF1E293B),
                  ),
                  const SizedBox(width: 8),
                  _buildVisitStatChip(
                    label: 'Terminées',
                    value: (_visitStats['completed'] as num?)?.toInt() ?? 0,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  _buildVisitStatChip(
                    label: 'Annulées',
                    value: (_visitStats['cancelled'] as num?)?.toInt() ?? 0,
                    color: const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 8),
                  _buildVisitStatChip(
                    label: 'Absent',
                    value: (_visitStats['no_show'] as num?)?.toInt() ?? 0,
                    color: const Color(0xFFF59E0B),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Hot leads
            if (_hotLeads.isNotEmpty) ...[
              const Text(
                'Leads chauds',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              ..._hotLeads.map((lead) {
                final name = lead['fullName'] as String? ?? '';
                final stage = lead['stage'] as String? ?? '';
                final source = lead['source'] as String? ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFFFEE2E2),
                        child: Icon(Icons.local_fire_department,
                            color: Color(0xFFEF4444), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              '$stage · $source',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],

            // Performance metrics
            const Text(
              'Performance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _buildPerformanceMetrics(),
            ),

            const SizedBox(height: 24),

            // Top buildings
            const Text(
              'Meilleurs immeubles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 12),

            if (_buildings.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Aucun immeuble',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _buildings.length,
                itemBuilder: (context, index) {
                  final building = _buildings[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color((0xFF0F766E))
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.apartment,
                            color: Color(0xFF0F766E),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                building.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                '${building.occupiedUnits}/${building.totalUnits} unités',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${building.occupancyRate.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            Text(
                              '${building.monthlyRevenue}\$',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPerformanceMetrics() {
    // Compute occupancy from buildings data
    int totalUnits = 0;
    int occupiedUnits = 0;
    int totalRevenue = 0;
    for (final b in _buildings) {
      totalUnits += b.totalUnits;
      occupiedUnits += b.occupiedUnits;
      totalRevenue += b.monthlyRevenue;
    }
    final occupancy =
        totalUnits > 0 ? (occupiedUnits / totalUnits * 100) : 0.0;
    final vacancy = totalUnits > 0 ? (100.0 - occupancy) : 0.0;
    final avgRent =
        occupiedUnits > 0 ? totalRevenue ~/ occupiedUnits : 0;
    final pipelineCount = _pipelineTotal();

    // Use conversion rate if available
    final conversionRate = _conversionRates['overall'] as num?;
    final rotationRate = conversionRate != null
        ? (conversionRate.toDouble() * 100).toStringAsFixed(1)
        : '-';

    return [
      _buildMetricCard(
        title: "Taux d'occupation",
        value: '${occupancy.toStringAsFixed(1)}%',
        change: '$occupiedUnits / $totalUnits',
        isPositive: occupancy > 90,
        icon: Icons.home_work,
        color: const Color(0xFF10B981),
      ),
      _buildMetricCard(
        title: 'Revenu moyen',
        value: '$avgRent\$',
        change: '$totalRevenue\$ total',
        isPositive: true,
        icon: Icons.attach_money,
        color: const Color(0xFF3B82F6),
      ),
      _buildMetricCard(
        title: 'Taux de rotation',
        value: '$rotationRate%',
        change: '$pipelineCount dans le pipeline',
        isPositive: true,
        icon: Icons.swap_horiz,
        color: const Color(0xFFF59E0B),
      ),
      _buildMetricCard(
        title: 'Taux de vacance',
        value: '${vacancy.toStringAsFixed(1)}%',
        change: '${totalUnits - occupiedUnits} libres',
        isPositive: vacancy < 10,
        icon: Icons.hourglass_empty,
        color: const Color(0xFF6366F1),
      ),
    ];
  }

  Widget _buildVisitStatChip({
    required String label,
    required int value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String change,
    required bool isPositive,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: (MediaQuery.of(context).size.width - 40) / 2,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  change,
                  style: TextStyle(
                    fontSize: 12,
                    color: isPositive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
