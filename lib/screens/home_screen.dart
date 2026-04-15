import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api_service.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'pipeline_screen.dart';
import 'visits_screen.dart';
import 'buildings_screen.dart';
import 'settings_screen.dart';
import 'employees_screen.dart';
import 'documents_screen.dart';
import 'leases_screen.dart';
import 'payments_screen.dart';
import 'communications_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/immo_app_bar.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _mainScreens = [
    _TabEntry(screen: _HomeTab(), label: 'Accueil'),
    _TabEntry(screen: DashboardScreen(), label: 'Tableau'),
    _TabEntry(screen: CommunicationsScreen(), label: 'Messages'),
    _TabEntry(screen: CalendarScreen(), label: 'Calendrier'),
    _TabEntry(screen: _MoreScreen(), label: 'Plus'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _mainScreens.map((e) => e.screen).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Tableau',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Calendrier',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.more_horiz),
            label: 'Plus',
          ),
        ],
      ),
    );
  }
}

class _TabEntry {
  final Widget screen;
  final String label;
  const _TabEntry({required this.screen, required this.label});
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ImmoAppBar(title: 'Plus'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _MoreTile(
            icon: Icons.trending_up,
            label: 'Pipeline',
            onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PipelineScreen()),
                ),
          ),
          _MoreTile(
            icon: Icons.calendar_today_outlined,
            label: 'Visites',
            onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VisitsScreen()),
                ),
          ),
          _MoreTile(
            icon: Icons.apartment_outlined,
            label: 'Immeubles',
            onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BuildingsScreen()),
                ),
          ),
          _MoreTile(
            icon: Icons.description_outlined,
            label: 'Baux',
            onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LeasesScreen()),
                ),
          ),
          _MoreTile(
            icon: Icons.receipt_long_outlined,
            label: 'Paiements',
            onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaymentsScreen()),
                ),
          ),
          _MoreTile(
            icon: Icons.people_outlined,
            label: 'Employés',
            onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EmployeesScreen()),
                ),
          ),
          _MoreTile(
            icon: Icons.folder_outlined,
            label: 'Documents',
            onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DocumentsScreen()),
                ),
          ),
          _MoreTile(
            icon: Icons.settings_outlined,
            label: 'Paramètres',
            onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: AppTypography.body),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
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
      final profile = UserItem.fromJson(
        (results[0]['data'] as Map<String, dynamic>?) ?? {},
      );
      _userName = profile.fullName;

      // Parse weekly summary
      _weeklySummary = (results[1]['data'] as Map<String, dynamic>?) ?? {};

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
          color: AppColors.indigo,
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
              ? AppColors.success
              : status.toLowerCase() == 'cancelled'
                  ? AppColors.error
                  : AppColors.skyBlue,
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
      appBar: ImmoAppBar(title: 'ImmoGestion', actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications — bientôt disponible'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ]),
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
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Impossible de charger les données',
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchHomeData,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
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
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      "Quel est votre objectif aujourd'hui?",
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity( 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$_occupancyPct%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      const Text(
                        'Occupation',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
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
                    color: AppColors.textPrimary,
                  ),
                ),
                Spacer(),
                Text(
                  'Voir tout',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
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
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
                    decoration: AppSpacing.cardDecoration(),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: activity.color.withOpacity( 0.1),
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
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activity.detail,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatTimeAgo(activity.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            delta,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.success,
              fontWeight: FontWeight.w500,
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
