import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/communication_service.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'visits_screen.dart';
import 'buildings_screen.dart';
import 'settings_screen.dart';
import 'employees_screen.dart';
import 'leases_screen.dart';
import 'payments_screen.dart';
import 'communications_screen.dart';
import 'leads_screen.dart';
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

  static const _navigationEntries = [
    _NavigationEntry(
      screen: _HomeTab(),
      label: 'Accueil',
      icon: Icons.home,
    ),
    _NavigationEntry(
      screen: DashboardScreen(),
      label: 'Tableau',
      icon: Icons.dashboard_outlined,
    ),
    _NavigationEntry(
      screen: CommunicationsScreen(),
      label: 'Messages',
      icon: Icons.message_outlined,
    ),
    _NavigationEntry(
      screen: CalendarScreen(),
      label: 'Calendrier',
      icon: Icons.calendar_month_outlined,
    ),
    _NavigationEntry(
      screen: _MoreScreen(),
      label: 'Plus',
      icon: Icons.more_horiz,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopShell = constraints.maxWidth >= 1024;
        final isExtendedRail = constraints.maxWidth >= 1280;
        final screens = _navigationEntries.map((entry) => entry.screen).toList();

        if (isDesktopShell) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    extended: isExtendedRail,
                    labelType: isExtendedRail
                        ? null
                        : NavigationRailLabelType.all,
                    backgroundColor: AppColors.surface,
                    selectedIconTheme: const IconThemeData(
                      color: AppColors.primary,
                    ),
                    selectedLabelTextStyle: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedIconTheme: const IconThemeData(
                      color: AppColors.textMuted,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: AppColors.textMuted,
                    ),
                    indicatorColor: AppColors.primary.withValues(alpha: 0.12),
                    destinations: [
                      for (final entry in _navigationEntries)
                        NavigationRailDestination(
                          icon: Tooltip(
                            message: entry.label,
                            child: Icon(entry.icon),
                          ),
                          selectedIcon: Tooltip(
                            message: entry.label,
                            child: Icon(entry.icon),
                          ),
                          label: Text(entry.label),
                        ),
                    ],
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.apartment_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          if (isExtendedRail) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'ImmoGestion',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: screens,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
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
              for (final entry in _navigationEntries)
                BottomNavigationBarItem(
                  icon: Icon(entry.icon),
                  label: entry.label,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NavigationEntry {
  final Widget screen;
  final String label;
  final IconData icon;
  const _NavigationEntry({
    required this.screen,
    required this.label,
    required this.icon,
  });
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
            icon: Icons.people_alt_outlined,
            label: 'Pistes',
            onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LeadsScreen()),
                ),
          ),
          _MoreTile(
            icon: Icons.message_outlined,
            label: 'Communications',
            onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CommunicationsScreen()),
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
            icon: Icons.construction_outlined,
            label: 'Rénovation Ops',
            onTap: () => Navigator.of(context).pushNamed('/renovation-ops'),
          ),
          _MoreTile(
            icon: Icons.build_outlined,
            label: 'Centre de maintenance',
            onTap: () => Navigator.of(context).pushNamed('/maintenance'),
          ),
          _MoreTile(
            icon: Icons.confirmation_number_outlined,
            label: 'Tickets de maintenance',
            onTap: () => Navigator.of(context).pushNamed('/maintenance-tickets'),
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

class _PrimaryFlowCard extends StatelessWidget {
  const _PrimaryFlowCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: accentColor.withValues(alpha: 0.15)),
              boxShadow: [AppSpacing.elevationCard],
              color: AppColors.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyAccessMissingState extends StatelessWidget {
  const _CompanyAccessMissingState({
    required this.userName,
    required this.onRefresh,
    required this.onLogout,
  });

  final String userName;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.apartment_outlined,
                      size: 42,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Accès à une compagnie requis',
                    style: AppTypography.sectionHeader.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$userName a bien un compte, mais aucun accès à une compagnie n\'est encore configuré. Demandez à un administrateur de vous ajouter à une compagnie ou complétez la configuration initiale pour continuer.',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => onRefresh(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Réessayer'),
                      ),
                      TextButton.icon(
                        onPressed: () => onLogout(),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Se déconnecter'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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
  bool _missingCompanyAccess = false;

  // User profile
  String _userName = 'Utilisateur';
  String _occupancyPct = '--';

  // Weekly summary
  Map<String, dynamic> _weeklySummary = {};

  // Primary operator flow
  List<CommunicationItem> _recentCommunications = [];
  List<VisitItem> _upcomingVisits = [];

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
      _missingCompanyAccess = false;
    });
    try {
      final profileResult = await ApiService.instance.get('/auth/profile');
      final profile = UserItem.fromJson(
        (profileResult['data'] as Map<String, dynamic>?) ?? {},
      );

      // The live backend is single-company and /auth/profile does not expose a
      // `company` field. Treat successful authenticated data fetches as the real
      // access signal instead of blocking the entire app on a null/empty company
      // string from the profile payload.
      List<CommunicationItem> communications = [];
      try {
        communications = await CommunicationService.instance.getCommunications(
          limit: 5,
        );
      } catch (_) {
        communications = [];
      }
      final results = await Future.wait([
        ApiService.instance.get('/analytics/weekly-summary'),
        ApiService.instance.get('/leads'),
        ApiService.instance.get('/visits'),
        ApiService.instance.get('/buildings'),
      ]);

      _userName = profile.fullName;

      // Parse weekly summary
      _weeklySummary = (results[0]['data'] as Map<String, dynamic>?) ?? {};

      // Parse buildings for occupancy
      final buildingsData = results[3]['data'] as List<dynamic>;
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

      // Build inbox and visit flow snapshots.
      final visitsData = results[2]['data'] as List<dynamic>;
      final visits = visitsData
          .map((visit) => VisitItem.fromJson(visit as Map<String, dynamic>))
          .toList();
      final now = DateTime.now();
      final upcomingVisits = [...visits]
        ..sort((a, b) {
          final aTime = a.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aTime.compareTo(bTime);
        });
      final futureVisits = upcomingVisits.where((visit) {
        final dateTime = visit.dateTime;
        return dateTime != null && !dateTime.isBefore(now);
      }).take(3).toList();

      // Build activity feed from recent leads + visits
      final leadsData = results[1]['data'] as List<dynamic>;

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
        final status = (visit['status'] as String? ?? '').toLowerCase();
        final createdAt = visit['createdAt'] as String?;
        final buildingName = visit['buildingName'] as String? ?? '';
        final unitLabel = visit['unitLabel'] as String? ?? '';
        final leadName = visit['leadName'] as String? ?? '';
        final outcome = visit['outcome'] as String?;
        final reasonCode = visit['reasonCode'] as String? ?? visit['failureReasonCode'] as String?;
        final lifecycleTimestamp =
            status == 'completed'
                ? (visit['completedAt'] as String? ?? visit['updatedAt'] as String? ?? createdAt)
                : status == 'cancelled'
                    ? (visit['cancelledAt'] as String? ?? visit['updatedAt'] as String? ?? createdAt)
                    : status == 'no_show'
                        ? (visit['noShowAt'] as String? ?? visit['updatedAt'] as String? ?? createdAt)
                        : status == 'scheduled' && visit['rescheduledAt'] != null
                            ? (visit['rescheduledAt'] as String?)
                            : (visit['updatedAt'] as String? ?? createdAt);
        final isRescheduled = visit['rescheduledAt'] != null;

        String title;
        String detail = '$unitLabel${leadName.isNotEmpty ? ' · $leadName' : ''}';
        if (status == 'completed') {
          title = 'Visite terminée: $buildingName';
          if (outcome != null && outcome.isNotEmpty) {
            detail = '$detail · ${_visitOutcomeLabel(outcome)}';
          }
        } else if (status == 'cancelled') {
          title = 'Visite annulée: $buildingName';
          if (reasonCode != null && reasonCode.isNotEmpty) {
            detail = '$detail · ${_reasonCodeLabel(reasonCode)}';
          }
        } else if (status == 'no_show') {
          title = 'Visite manquée: $buildingName';
          if (reasonCode != null && reasonCode.isNotEmpty) {
            detail = '$detail · ${_reasonCodeLabel(reasonCode)}';
          }
        } else if (isRescheduled) {
          title = 'Visite reprogrammée: $buildingName';
        } else if (status == 'confirmed') {
          title = 'Visite confirmée: $buildingName';
        } else {
          title = 'Visite planifiée: $buildingName';
        }

        activities.add(_ActivityEntry(
          title: title,
          detail: detail,
          createdAt: lifecycleTimestamp,
          color: status == 'completed'
              ? AppColors.success
              : status == 'cancelled' || status == 'no_show'
                  ? AppColors.error
                  : status == 'confirmed'
                      ? AppColors.success
                      : isRescheduled
                          ? AppColors.info
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
        _recentCommunications = communications.take(3).toList();
        _upcomingVisits = futureVisits;
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

  Widget _buildPrimaryOperatorFlow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Flux opérateur principal',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Commencez ici pour traiter les messages SMS et verrouiller les visites.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _PrimaryFlowCard(
              icon: Icons.inbox_outlined,
              accentColor: AppColors.primary,
              title: 'Boîte de réception',
              subtitle: _recentCommunications.isEmpty
                  ? 'Vos conversations SMS regroupées au même endroit.'
                  : '${_recentCommunications.first.contactName} · ${_shortPreview(_recentCommunications.first.body)}',
              actionLabel: 'Ouvrir les messages',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CommunicationsScreen()),
              ),
            ),
            _PrimaryFlowCard(
              icon: Icons.calendar_month_outlined,
              accentColor: AppColors.skyBlue,
              title: 'Planifier une visite',
              subtitle: _upcomingVisits.isEmpty
                  ? 'Créez la prochaine visite dès qu’un lead est prêt.'
                  : _nextVisitSummary(_upcomingVisits.first),
              actionLabel: 'Voir les visites',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VisitsScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _shortPreview(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return 'Nouveau message';
    if (cleaned.length <= 64) return cleaned;
    return '${cleaned.substring(0, 61)}…';
  }

  String _nextVisitSummary(VisitItem visit) {
    final dateTime = visit.dateTime;
    final timeLabel = dateTime != null ? DateFormat('HH:mm', 'fr').format(dateTime) : visit.dateLabel;
    final location = [visit.buildingName, visit.unitLabel]
        .where((value) => value.trim().isNotEmpty)
        .join(' · ');
    return location.isEmpty
        ? 'Prochaine visite à $timeLabel'
        : 'Prochaine visite à $timeLabel · $location';
  }

  String _visitOutcomeLabel(String outcome) {
    switch (outcome.toLowerCase()) {
      case 'interesse':
        return 'Intéressé';
      case 'pas_interesse':
        return 'Pas intéressé';
      case 'no_show':
        return 'Absent';
      default:
        return outcome;
    }
  }

  String _reasonCodeLabel(String reasonCode) {
    switch (reasonCode) {
      case 'tenant_request':
        return 'À la demande du locataire';
      case 'tenant_conflict':
        return 'Conflit d’horaire du locataire';
      case 'host_unavailable':
        return 'Hôte / employé indisponible';
      case 'access_issue':
        return 'Problème d’accès';
      case 'weather':
        return 'Météo';
      case 'tenant_no_show':
        return 'Locataire absent';
      case 'other':
        return 'Autre';
      default:
        return reasonCode;
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
    if (_missingCompanyAccess) {
      return _CompanyAccessMissingState(
        userName: _userName,
        onRefresh: _fetchHomeData,
        onLogout: () => AuthNotifier.instance.logout(),
      );
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
                    color: AppColors.success.withValues(alpha: 0.1),
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

            _buildPrimaryOperatorFlow(),

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
                            color: activity.color.withValues(alpha: 0.1),
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
