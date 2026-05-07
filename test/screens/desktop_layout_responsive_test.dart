import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:immogestion/screens/home_screen.dart';
import 'package:immogestion/screens/login_screen.dart';
import 'package:immogestion/screens/register_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('desktop responsive layouts', () {
    testWidgets('login screen uses the desktop auth layout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Connexion sécurisée'), findsOneWidget);
      expect(find.text('Navigation claire pour les opérations quotidiennes'), findsOneWidget);
      expect(find.text('Conçue pour les écrans larges et le travail au clavier'), findsOneWidget);
      expect(find.text('Accès sécurisé à tout le reste de la plateforme'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
    });

    testWidgets('register screen uses the desktop auth layout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Ouverture de compte'), findsOneWidget);
      expect(find.text('Préparez votre accès avant d’entrer dans le tableau de bord'), findsOneWidget);
      expect(find.text('Des champs plus lisibles sur les écrans de bureau'), findsOneWidget);
      expect(find.text('Retour immédiat vers l’espace sécurisé si le compte existe déjà'), findsOneWidget);
      expect(find.text('Créer un compte'), findsWidgets);
    });

    testWidgets('home screen switches to the desktop shell', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });
  });
}
