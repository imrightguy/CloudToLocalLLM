import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/theme_provider.dart';
import 'helpers/mock_services.dart';
import 'helpers/test_utilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeMockPlugins();
  });

  group('Test group', () {
    testWidgets('Test exact setup mimic', (tester) async {
      final themeProvider = ThemeProvider();

      // ignore: avoid_print
      print('Step 1: Setting theme mode');
      await themeProvider.setThemeMode(ThemeMode.light);

      // ignore: avoid_print
      print('Step 2: Pumping widget');
      await tester.pumpWidget(const SizedBox());

      // ignore: avoid_print
      print('Step 3: Pumping and settling');
      await pumpAndSettleWithTimeout(tester);
      // ignore: avoid_print
      print('Done!');
    }, timeout: const Timeout(Duration(seconds: 1)));
  });
}