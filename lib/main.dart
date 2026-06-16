import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/cache_service.dart';
import 'services/lead_service.dart';
import 'services/visit_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/lead_detail_screen.dart';
import 'screens/leads_screen.dart';
import 'screens/visit_detail_screen.dart';
import 'screens/visit_form_screen.dart';
import 'utils/browser_location.dart';
import 'utils/entrypoint_policy.dart';
import 'screens/calendar_screen.dart';
import 'screens/visits_screen.dart';
import 'screens/buildings_screen.dart';
import 'screens/leases_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/employees_screen.dart';
import 'screens/communications_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/renovation_ops_screen.dart';
import 'screens/maintenance_command_center_screen.dart';
import 'screens/maintenance_screen.dart';
import 'screens/unit_360_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_spacing.dart';
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

  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier(ThemeMode.system);

  @override
  State<ImmoGestionApp> createState() => _ImmoGestionAppState();
}

class _ImmoGestionAppState extends State<ImmoGestionApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // Date formatting is already initialized in main() before runApp().
    await ApiService.instance.init();
    await CacheService.instance.init();
    await AuthNotifier.instance.init();
    ImmoGestionApp.themeModeNotifier.value =
        await ApiService.instance.getThemeMode();
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
      case EntryPointDestination.loginWall:
        return const LoginScreen();
      case EntryPointDestination.appShell:
        return _buildAuthenticatedStartScreen(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ImmoGestionApp.themeModeNotifier,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'ImmoGestion',
        themeMode: themeMode,
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
        '/calendar': _protectedRoute((context) => const CalendarScreen()),
        '/visits': _protectedRoute((context) => const VisitsScreen()),
        '/leads': _protectedRoute((context) => const LeadsScreen()),
        '/buildings': _protectedRoute((context) => const BuildingsScreen()),
        '/leases': _protectedRoute((context) => const LeasesScreen()),
        '/payments': _protectedRoute((context) => const PaymentsScreen()),
        '/employees': _protectedRoute((context) => const EmployeesScreen()),
        '/renovation-ops':
            _protectedRoute((context) => const RenovationOpsScreen()),
        '/maintenance': _protectedRoute(
            (context) => const MaintenanceCommandCenterScreen()),
        '/maintenance-tickets':
            _protectedRoute((context) => const MaintenanceScreen()),
        '/communications':
            _protectedRoute((context) => const CommunicationsScreen()),
        '/messages':
            _protectedRoute((context) => const CommunicationsScreen()),
        '/settings': _protectedRoute((context) => const SettingsScreen()),
        },
        onGenerateRoute: _buildDynamicRoute,
      ),
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

    if (segments.length == 3 &&
        segments[0] == 'units' &&
        segments[2] == '360') {
      final unitId = Uri.decodeComponent(segments[1]);
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Unit360Screen(unitId: unitId),
      );
    }

    return null;
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      colorSchemeSeed: AppColors.primary,
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimaryLight,
        surfaceTintColor: AppColors.surfaceLight,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      colorSchemeSeed: AppColors.primary,
      brightness: Brightness.dark,
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
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
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
    return const AuthGate(child: CommunicationsScreen());
  }

  if (normalizedPath == '/visits') {
    return const AuthGate(child: VisitsScreen());
  }

  if (normalizedPath == '/leads' && segments.length <= 1) {
    return const AuthGate(child: LeadsScreen());
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
    case '/maintenance-tickets':
      return const AuthGate(child: MaintenanceScreen());
    case '/maintenance':
      return const AuthGate(child: MaintenanceCommandCenterScreen());
    case '/renovation-ops':
      return const AuthGate(child: RenovationOpsScreen());
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
