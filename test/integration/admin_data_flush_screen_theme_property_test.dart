import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/screens/admin/admin_data_flush_screen.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import '../helpers/mock_services.dart';
import '../helpers/test_app_wrapper.dart';
import '../helpers/test_utilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Admin Data Flush Screen Theme Application Property Tests', () {
    late ThemeProvider themeProvider;
    late PlatformDetectionService platformService;

    setUp(() async {
      await initializeMockPlugins();
      themeProvider = ThemeProvider();
      platformService = PlatformDetectionService();
    });

    testWidgets(
      'Property 1: Admin Data Flush screen applies light theme correctly',
      (WidgetTester tester) async {
        await themeProvider.setThemeMode(ThemeMode.light);

        await tester.pumpWidget(
          createFullTestApp(
            const AdminDataFlushScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);
        expectThemeMode(tester, Brightness.light);
        expect(find.byType(AdminDataFlushScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Property 1: Admin Data Flush screen applies dark theme correctly',
      (WidgetTester tester) async {
        await themeProvider.setThemeMode(ThemeMode.dark);

        await tester.pumpWidget(
          createFullTestApp(
            const AdminDataFlushScreen(),
            themeProvider: themeProvider,
            platformService: platformService,
          ),
        );

        await pumpAndSettleWithTimeout(tester);
        expectThemeMode(tester, Brightness.dark);
        expect(find.byType(AdminDataFlushScreen), findsOneWidget);
      },
    );
  });
}
