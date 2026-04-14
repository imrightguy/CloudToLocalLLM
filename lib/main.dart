import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pipeline_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/visits_screen.dart';
import 'screens/buildings_screen.dart';
import 'screens/employees_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/communications_screen.dart';

void main() {
  // Lock orientation to portrait for property management
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ImmoGestionApp());
}

class ImmoGestionApp extends StatefulWidget {
  const ImmoGestionApp({super.key});

  @override
  State<ImmoGestionApp> createState() => _ImmoGestionAppState();
}

class _ImmoGestionAppState extends State<ImmoGestionApp> {
  /// True once the initial auth check (loading tokens) is complete.
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await ApiService.instance.init();
    await AuthNotifier.instance.init();
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ImmoGestion',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.light,
        fontFamily: 'Inter',
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E293B),
          surfaceTintColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      // Auth gate – show splash while initialising, then branch on login state.
      home: _isInitialized
          ? ListenableBuilder(
              listenable: AuthNotifier.instance,
              builder: (context, _) {
                if (AuthNotifier.instance.isLoggedIn) {
                  return const AuthGate(child: HomeScreen());
                }
                return const AuthGate(child: LoginScreen());
              },
            )
          : const _SplashScreen(),
      routes: {
        '/dashboard': (context) => const DashboardScreen(),
        '/pipeline': (context) => const PipelineScreen(),
        '/calendar': (context) => const CalendarScreen(),
        '/visits': (context) => const VisitsScreen(),
        '/buildings': (context) => const BuildingsScreen(),
        '/employees': (context) => const EmployeesScreen(),
        '/documents': (context) => const DocumentsScreen(),
        '/communications': (context) => const CommunicationsScreen(),
      },
    );
  }
}

/// Lightweight wrapper that re-evaluates auth state so any screen can be
/// replaced when the user logs out mid-session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthNotifier.instance,
      builder: (context, _) {
        // If user logs out while inside the app, redirect to login.
        if (!AuthNotifier.instance.isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          });
        }
        return child;
      },
    );
  }
}

/// Simple splash shown while tokens are being loaded from SharedPreferences.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.apartment_rounded,
              size: 64,
              color: Color(0xFF0F766E),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Color(0xFF0F766E)),
          ],
        ),
      ),
    );
  }
}
