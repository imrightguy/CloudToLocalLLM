import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'pipeline_screen.dart';
import 'visits_screen.dart';
import 'buildings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    const _HomeTab(),
    const DashboardScreen(),
    const PipelineScreen(),
    const VisitsScreen(),
    const BuildingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0F766E),
        unselectedItemColor: const Color(0xFF94A3B8),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Tableau',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Pipeline',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'Visites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment_outlined),
            label: 'Immeubles',
          ),
        ],
      ),
    );
  }
}

/// Extracted home tab content so it can live inside IndexedStack.
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  bool _isLoading = true;
  String? _errorMessage;

  // User profile
  String _userName = 'Utilisateur';
  String _occupancyPct = '--';

  // Weekly summary
  Map<String, dynamic> _weeklySummary = {};

  // Activity feed
  List<_ActivityEntry> _activityFeed = [];

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
  }

  Future<void> _fetchHomeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        ApiService.instance.get('/auth/profile'),
        ApiService.instance.get('/analytics/weekly-summary'),
        ApiService.instance.get('/leads'),
        ApiService.instance.get('/visits'),
        ApiService.instance.get('/buildings'),
      ]);

      // Parse user profile
      final profile = (results[0]['data'] as Map<String, dynamic>?) ?? {};
      final firstName = profile['firstName'] as String? ?? '';
      final lastName = profile['lastName'] as String? ?? '';
      _userName = '$firstName $lastName'.trim();
      if (_userName.isEmpty) _userName = 'Utilisateur';

      // Parse weekly summary
      _weeklySummary =
          (results[1]['data'] as Map<String, dynamic>?) ?? {};

      // Parse buildings for occupancy
      final buildingsData = results[4]['data'] as List<dynamic>;
      int totalUnits = 0;
      int occupiedUnits = 0;
      for (final b in buildingsData) {
        final building = BuildingItem.fromJson(b as Map<String, dynamic>);
        totalUnits += building.totalUnits;
        occupiedUnits += building.occupiedUnits;
      }
      _occupancyPct = totalUnits > 0
          ? (occupiedUnits / totalUnits * 100).toStringAsFixed(1)
          : '0.0';

      // Build activity feed from recent leads + visits
      final leadsData = results[2]['data'] as List<dynamic>;
      final visitsData = results[3]['data'] as List<dynamic>;

      final activities = <_ActivityEntry>[];

      for (final l in leadsData) {
        final lead = l as Map<String, dynamic>;
        final createdAt = lead['createdAt'] as String?;
        activities.add(_ActivityEntry(
          title: 'Nouveau prospect: ${lead['fullName'] ?? ''}',
          detail: '${lead['source'] ?? ''} · ${lead['email'] ?? ''}',
          createdAt: createdAt,
          color: const Color(0xFF6366F1),
          icon: Icons.person_add_outlined,
        ));
      }

      for (final v in visitsData) {
        final visit = v as Map<String, dynamic>;
        final createdAt = visit['createdAt'] as String?;
        final status = visit['status'] as String? ?? '';
        final buildingName = visit['buildingName'] as String? ?? '';
        final unitLabel = visit['unitLabel'] as String? ?? '';
        final leadName = visit['leadName'] as String? ?? '';

        String title;
        if (status.toLowerCase() == 'completed') {
          title = 'Visite terminée: $buildingName';
        } else if (status.toLowerCase() == 'confirmed') {
          title = 'Visite confirmée: $buildingName';
        } else if (status.toLowerCase() == 'cancelled') {
          title = 'Visite annulée: $buildingName';
        } else {
          title = 'Visite planifiée: $buildingName';
        }

        activities.add(_ActivityEntry(
          title: title,
          detail: '$unitLabel${leadName.isNotEmpty ? ' · $leadName' : ''}',
          createdAt: createdAt,
          color: status.toLowerCase() == 'confirmed'
              ? const Color(0xFF10B981)
              : status.toLowerCase() == 'cancelled'
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF38BDF8),
          icon: Icons.calendar_today_outlined,
        ));
      }

      // Sort by createdAt descending
      activities.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      setState(() {
        _activityFeed = activities.take(10).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatTimeAgo(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return "À l'instant";
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
      return DateFormat('d MMM').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ImmoGestion'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
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
                'Impossible de charger les données',
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
              onPressed: _fetchHomeData,
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
      onRefresh: _fetchHomeData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour $_userName',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Text(
                      "Quel est votre objectif aujourd'hui?",
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color((0xFF10B981)).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$_occupancyPct%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const Text(
                        'Occupation',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Quick stats from weekly summary
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _buildStatsCards(),
            ),

            const SizedBox(height: 24),

            // Recent activity
            const Row(
              children: [
                Text(
                  'Activité récente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Spacer(),
                Text(
                  'Voir tout',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_activityFeed.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Aucune activité récente',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activityFeed.length,
                itemBuilder: (context, index) {
                  final activity = _activityFeed[index];
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                activity.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            activity.icon,
                            color: activity.color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activity.detail,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatTimeAgo(activity.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
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

  List<Widget> _buildStatsCards() {
    final newLeads = (_weeklySummary['newLeads'] as num?)?.toInt() ?? 0;
    final visitsCompleted =
        (_weeklySummary['visitsCompleted'] as num?)?.toInt() ?? 0;
    final conversions = (_weeklySummary['conversions'] as num?)?.toInt() ?? 0;
    final hotLeadsCount =
        (_weeklySummary['hotLeadsCount'] as num?)?.toInt() ?? 0;

    return [
      _buildStatCard(
        title: 'Nouveaux leads',
        value: '$newLeads',
        delta: 'cette semaine',
        description: 'Prospects entrants',
      ),
      _buildStatCard(
        title: 'Visites complétées',
        value: '$visitsCompleted',
        delta: 'cette semaine',
        description: 'Visites terminées',
      ),
      _buildStatCard(
        title: 'Conversions',
        value: '$conversions',
        delta: 'cette semaine',
        description: 'Baux signés',
      ),
      _buildStatCard(
        title: 'Leads chauds',
        value: '$hotLeadsCount',
        delta: 'à suivre',
        description: 'Prêts à signer',
      ),
    ];
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String delta,
    required String description,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            delta,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF10B981),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityEntry {
  final String title;
  final String detail;
  final String? createdAt;
  final Color color;
  final IconData icon;

  const _ActivityEntry({
    required this.title,
    required this.detail,
    this.createdAt,
    required this.color,
    required this.icon,
  });
}
