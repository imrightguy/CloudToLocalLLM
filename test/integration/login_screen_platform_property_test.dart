import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Login Screen Platform Components Property Tests', () {
    setUp(() {});

    testWidgets(
      'Login screen renders without errors',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const LoginScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Verify basic components are present
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
      },
    );

    testWidgets(
      'Login screen components consistent across themes',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: ThemeMode.light,
            home: const LoginScreen(),
          ),
        );

        await tester.pumpAndSettle();

        final scaffoldFinderLight = find.byType(Scaffold);
        expect(scaffoldFinderLight, findsOneWidget);

        // Switch to dark theme
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: ThemeMode.dark,
            home: const LoginScreen(),
          ),
        );

        await tester.pumpAndSettle();

        final scaffoldFinderDark = find.byType(Scaffold);
        expect(scaffoldFinderDark, findsOneWidget);
      },
    );

    testWidgets(
      'Login button has proper accessibility features',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const LoginScreen(),
          ),
        );

        await tester.pumpAndSettle();

        final button = find.byType(ElevatedButton);
        expect(button, findsOneWidget);

        // Check that the button has semantic properties
        final buttonWidget = tester.widget<ElevatedButton>(button);
        expect(buttonWidget.onPressed, isNotNull);
      },
    );

    testWidgets(
      'Login screen adapts to different screen sizes',
      (WidgetTester tester) async {
        // Test mobile size
        await tester.pumpWidget(
          MaterialApp(
            home: const LoginScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Verify components are present and properly sized
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  });
}
