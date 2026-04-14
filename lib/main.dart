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
  bool _isInitialized = false;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await ApiService.instance.init();
    await AuthNotifier.instance.init();
    _themeMode = await ApiService.instance.getThemeMode();
    if (mounted) {
      setState(() => _isInitialized = true);
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

  ThemeData _buildLightTheme() {
    return ThemeData(
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
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      primarySwatch: Colors.teal,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Color(0xFFF1F5F9),
        surfaceTintColor: Color(0xFF1E293B),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF1E293B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF14B8A6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
      ),
    );
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
