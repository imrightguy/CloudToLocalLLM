import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:immogestion/screens/public_entry_screen.dart';

void main() {
  group('PublicEntryScreen', () {
    testWidgets('renders public landing copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PublicEntryScreen(
            location: Uri.parse('https://immogestion.app/'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ImmoGestion'), findsWidgets);
      expect(find.text('Démo publique'), findsOneWidget);
      expect(find.text('Le point d’entrée public pour la démo ImmoGestion.'),
          findsOneWidget);
      expect(
        find.text('La seule page publique. Tout le reste de la plateforme est protégé par connexion.'),
        findsOneWidget,
      );
      expect(find.text('Ouvrir l’application'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Chemin de démo recommandé'), findsOneWidget);
      expect(find.text('Ouvrir la démo'), findsOneWidget);
    });

    testWidgets('shows feature cards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PublicEntryScreen(
            location: Uri.parse('https://immogestion.app/'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Messages et suivi'), findsOneWidget);
      expect(find.text('Visites et coordination'), findsOneWidget);
      expect(find.text('Tableau de bord clair'), findsOneWidget);
    });

    testWidgets('sign in button opens the login screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PublicEntryScreen(
            location: Uri.parse('https://immogestion.app/'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Connectez-vous à votre espace'), findsOneWidget);
    });

    testWidgets('routes app host visitors to the login screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PublicEntryScreen(
            location: Uri.parse('https://app.immogestion.app/'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Connectez-vous à votre espace'), findsOneWidget);
      expect(find.text('Adresse courriel'), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
    });
  });
}
