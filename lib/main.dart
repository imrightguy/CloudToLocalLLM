import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/cache_service.dart';
import 'services/lead_service.dart';
import 'services/visit_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/public_entry_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/lead_detail_screen.dart';
import 'screens/visit_detail_screen.dart';
import 'screens/visit_form_screen.dart';
import 'utils/browser_location.dart';
import 'utils/entrypoint_policy.dart';
import 'screens/pipeline_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/visits_screen.dart';
import 'screens/buildings_screen.dart';
import 'screens/leases_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/employees_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/communications_screen.dart';
import 'screens/marketplace_inbox_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/renovation_ops_screen.dart';
import 'screens/maintenance_command_center_screen.dart';
import 'screens/daily_task_tracker_screen.dart';
import 'screens/observation_review_inbox_screen.dart';
import 'screens/dossier_assistant_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_typography.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr', null);
  await initializeDateFormatting('fr_CA', null);

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(const ImmoGestionApp());
}

class ImmoGestionApp extends StatefulWidget {
  const ImmoGestionApp({super.key});

  @override
  State<ImmoGestionApp> createState() => _ImmoGestionAppState();
}

class _ImmoGestionAppState extends State<ImmoGestionApp> {
  bool _isInitialized = false;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await initializeDateFormatting('fr', null);
    await initializeDateFormatting('fr_CA', null);
    await ApiService.instance.init();
    await CacheService.instance.init();
    await AuthNotifier.instance.init();
    _themeMode = await ApiService.instance.getThemeMode();
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  WidgetBuilder _protectedRoute(WidgetBuilder builder) {
    return (context) {
      if (!AuthNotifier.instance.isLoggedIn) {
        return const LoginScreen();
      }
      return AuthGate(child: builder(context));
    };
  }

  Widget _buildAuthenticatedStartScreen(Uri location) {
    return buildAuthenticatedStartScreen(location);
  }

  Widget _buildStartScreen(Uri location) {
    switch (resolveEntryPointDestination(
      location: location,
      isLoggedIn: AuthNotifier.instance.isLoggedIn,
    )) {
      case EntryPointDestination.publicLanding:
        return PublicEntryScreen(location: location);
      case EntryPointDestination.loginWall:
        return const LoginScreen();
      case EntryPointDestination.appShell:
        return _buildAuthenticatedStartScreen(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ImmoGestion',
      themeMode: _themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      debugShowCheckedModeBanner: false,
      home: _isInitialized
          ? ListenableBuilder(
              listenable: AuthNotifier.instance,
              builder: (context, _) {
                return _buildStartScreen(currentBrowserLocation());
              },
            )
          : const _SplashScreen(),
      routes: {
        '/dashboard': _protectedRoute((context) => const DashboardScreen()),
        '/pipeline': _protectedRoute((context) => const PipelineScreen()),
        '/calendar': _protectedRoute((context) => const CalendarScreen()),
        '/visits': _protectedRoute((context) => const VisitsScreen()),
        '/buildings': _protectedRoute((context) => const BuildingsScreen()),
        '/leases': _protectedRoute((context) => const LeasesScreen()),
        '/payments': _protectedRoute((context) => const PaymentsScreen()),
        '/employees': _protectedRoute((context) => const EmployeesScreen()),
        '/documents': _protectedRoute((context) => const DocumentsScreen()),
        '/renovation-ops':
            _protectedRoute((context) => const RenovationOpsScreen()),
        '/maintenance': _protectedRoute(
            (context) => const MaintenanceCommandCenterScreen()),
        '/daily-tasks':
            _protectedRoute((context) => const DailyTaskTrackerScreen()),
        '/dossiers':
            _protectedRoute((context) => const DossierAssistantScreen()),
        '/observations': _protectedRoute((context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final findingId = args is Map<String, dynamic>
              ? args['findingId'] as String?
              : args is String
                  ? args
                  : null;
          return ObservationReviewInboxScreen(initialFindingId: findingId);
        }),
        '/communications':
            _protectedRoute((context) => const CommunicationsScreen()),
        '/messages':
            _protectedRoute((context) => const MarketplaceInboxScreen()),
        '/marketplace':
            _protectedRoute((context) => const MarketplaceInboxScreen()),
        '/settings': _protectedRoute((context) => const SettingsScreen()),
        '/onboarding': _protectedRoute((context) => const OnboardingScreen()),
      },
      onGenerateRoute: _buildDynamicRoute,
    );
  }

  Route<dynamic>? _buildDynamicRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name.isEmpty) {
      return null;
    }

    final uri = Uri.parse(name);
    final segments = uri.pathSegments;

    if (segments.length == 2 && segments[0] == 'leads') {
      final leadId = Uri.decodeComponent(segments[1]);
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _LeadDetailRouteScreen(leadId: leadId),
      );
    }

    if (segments.length == 2 &&
        segments[0] == 'visits' &&
        segments[1] == 'new') {
      final leadId = uri.queryParameters['leadId'];
      final date = DateTime.tryParse(uri.queryParameters['date'] ?? '');
      return MaterialPageRoute<void>(
        settings: settings,
        fullscreenDialog: true,
        builder: (_) => VisitFormScreen(
          initialLeadId: leadId,
          initialDate: date,
        ),
      );
    }

    if (segments.length == 2 &&
        segments[0] == 'visits' &&
        segments[1] != 'new') {
      final visitId = Uri.decodeComponent(segments[1]);
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _VisitDetailRouteScreen(visitId: visitId),
      );
    }

    return null;
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      primarySwatch: Colors.teal,
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      primarySwatch: Colors.teal,
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.surfaceVariant,
        surfaceTintColor: AppColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
      ),
    );
  }
}

class _LeadDetailRouteScreen extends StatelessWidget {
  const _LeadDetailRouteScreen({required this.leadId});

  final String leadId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: LeadService.instance.getLead(leadId, forceRefresh: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Détails du prospect')),
            body: Center(
              child:
                  Text('Impossible de charger le prospect: ${snapshot.error}'),
            ),
          );
        }

        final lead = snapshot.data;
        if (lead == null) {
          return const Scaffold(
            body: Center(child: Text('Prospect introuvable')),
          );
        }

        return LeadDetailScreen(
          lead: lead,
          onStageChanged: () {},
        );
      },
    );
  }
}

class _VisitDetailRouteScreen extends StatelessWidget {
  const _VisitDetailRouteScreen({required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: VisitService.instance.getVisit(visitId, forceRefresh: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Détails de la visite')),
            body: Center(
              child: Text('Impossible de charger la visite: ${snapshot.error}'),
            ),
          );
        }

        final visit = snapshot.data;
        if (visit == null) {
          return const Scaffold(
            body: Center(child: Text('Visite introuvable')),
          );
        }

        return VisitDetailScreen(visit: visit);
      },
    );
  }
}

Widget buildAuthenticatedStartScreen(Uri location) {
  final normalizedPath = normalizeAppPath(location.path);
  final segments = location.pathSegments;

  if (normalizedPath == '/messages' || normalizedPath == '/marketplace') {
    return const AuthGate(child: MarketplaceInboxScreen());
  }

  if (normalizedPath == '/visits') {
    return const AuthGate(child: VisitsScreen());
  }

  if (segments.length == 2 && segments[0] == 'leads') {
    final leadId = Uri.decodeComponent(segments[1]);
    return AuthGate(child: _LeadDetailRouteScreen(leadId: leadId));
  }

  if (segments.length == 2 && segments[0] == 'visits' && segments[1] == 'new') {
    final leadId = location.queryParameters['leadId'];
    final date = DateTime.tryParse(location.queryParameters['date'] ?? '');
    return AuthGate(
      child: VisitFormScreen(
        initialLeadId: leadId,
        initialDate: date,
      ),
    );
  }

  if (segments.length == 2 &&
      segments[0] == 'visits' &&
      segments[1].isNotEmpty &&
      segments[1] != 'new') {
    final visitId = Uri.decodeComponent(segments[1]);
    return AuthGate(child: _VisitDetailRouteScreen(visitId: visitId));
  }

  switch (normalizedPath) {
    case '/maintenance':
      return const AuthGate(child: MaintenanceCommandCenterScreen());
    case '/daily-tasks':
      return const AuthGate(child: DailyTaskTrackerScreen());
    case '/renovation-ops':
      return const AuthGate(child: RenovationOpsScreen());
    case '/dossiers':
      return const AuthGate(child: DossierAssistantScreen());
    default:
      return const AuthGate(child: HomeScreen());
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthNotifier.instance,
      builder: (context, _) {
        if (!AuthNotifier.instance.isLoggedIn) {
          return const LoginScreen();
        }
        return child;
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.apartment_rounded,
              size: 64,
              color: AppColors.primary,
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
