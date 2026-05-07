import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:immogestion/screens/login_screen.dart';
import 'package:immogestion/screens/register_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login screen uses the desktop auth layout on wide screens',
      (tester) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connexion sécurisée'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.byType(Row), findsWidgets);
  });

  testWidgets('register screen uses the desktop auth layout on wide screens',
      (tester) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ouverture de compte'), findsOneWidget);
    expect(find.text('Créer mon compte'), findsOneWidget);
    expect(find.text('Rejoignez ImmoGestion depuis un espace de connexion qui respire enfin sur grand écran.'), findsOneWidget);
  });
}
