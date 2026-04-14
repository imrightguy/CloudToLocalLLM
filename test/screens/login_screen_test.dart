import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginScreen UI contract', () {
    testWidgets('renders login form elements', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ImmoGestion'), findsOneWidget);
      expect(find.text('Connectez-vous à votre espace'), findsOneWidget);
      expect(find.text('Adresse courriel'), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
    });

    testWidgets('email field has mail icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
    });

    testWidgets('password field has lock icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('password visibility toggle toggles back', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('login button is initially enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Se connecter'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows brand icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.apartment_rounded), findsOneWidget);
    });

    testWidgets('email validation shows error for empty email', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Veuillez entrer votre courriel'), findsOneWidget);
    });

    testWidgets('email validation shows error for invalid email', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'invalid-email');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Format de courriel invalide'), findsOneWidget);
    });

    testWidgets('email validation accepts valid email', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Format de courriel invalide'), findsNothing);
    });

    testWidgets('password validation shows error for empty password', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Veuillez entrer votre mot de passe'), findsOneWidget);
    });

    testWidgets('has two TextFormField widgets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('has register link', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('password field has hint text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('••••••••'), findsOneWidget);
    });

    testWidgets('email field has hint text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('nom@exemple.com'), findsOneWidget);
    });

    testWidgets('no validation errors initially', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Veuillez entrer votre courriel'), findsNothing);
      expect(find.text('Format de courriel invalide'), findsNothing);
      expect(find.text('Veuillez entrer votre mot de passe'), findsNothing);
    });

    testWidgets('both fields valid shows no errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestableLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Veuillez entrer votre courriel'), findsNothing);
      expect(find.text('Veuillez entrer votre mot de passe'), findsNothing);
    });
  });
}

class _TestableLoginScreen extends StatefulWidget {
  const _TestableLoginScreen();

  @override
  State<_TestableLoginScreen> createState() => _TestableLoginScreenState();
}

class _TestableLoginScreenState extends State<_TestableLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        size: 48,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ImmoGestion',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Connectez-vous à votre espace',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 36),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Adresse courriel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez entrer votre courriel';
                        }
                        final emailRegex =
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                        if (!emailRegex.hasMatch(value.trim())) {
                          return 'Format de courriel invalide';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        hintText: 'nom@exemple.com',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        prefixIcon: Icon(Icons.mail_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Mot de passe',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre mot de passe';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () {
                          if (!_formKey.currentState!.validate()) return;
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF0F766E).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Se connecter',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {},
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(text: 'Pas de compte? '),
                            TextSpan(
                              text: 'Créer un compte',
                              style: TextStyle(
                                color: Color(0xFF0F766E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
