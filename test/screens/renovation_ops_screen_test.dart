import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:immogestion/screens/renovation_ops_screen.dart';

void main() {
  testWidgets('shows renovation ops shell sections', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RenovationOpsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rénovation Ops'), findsOneWidget);
    expect(find.text('Module séparé du Leasing'), findsOneWidget);
    expect(find.text('Appartements en rénovation'), findsOneWidget);
    expect(find.text('Flux de travail'), findsOneWidget);
    expect(find.text('Hooks prévus'), findsOneWidget);
    expect(find.text('Prêt pour Leasing'), findsWidgets);
  });

  testWidgets('opens apartment detail sheet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RenovationOpsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Logement 304'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Détail du logement 304'), findsOneWidget);
    expect(find.text('Tâches'), findsOneWidget);
    expect(find.text('Bloqueur principal'), findsOneWidget);
  });
}
