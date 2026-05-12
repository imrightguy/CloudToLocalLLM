import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:immogestion/main.dart';
import 'package:immogestion/screens/home_screen.dart';
import 'package:immogestion/screens/marketplace_inbox_screen.dart';
import 'package:immogestion/screens/visits_screen.dart';
import 'package:immogestion/utils/entrypoint_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('authenticated start screen routing', () {
    test('normalizes trailing slashes on authenticated deep links', () {
      expect(normalizeAppPath('/messages/'), '/messages');
      expect(normalizeAppPath('/visits/'), '/visits');
    });

    test('maps /messages to the marketplace inbox screen', () {
      final widget = buildAuthenticatedStartScreen(
        Uri.parse('https://app.immogestion.app/messages?tab=inbox'),
      );

      expect(widget, isA<AuthGate>());
      expect((widget as AuthGate).child, isA<MarketplaceInboxScreen>());
    });

    test('maps /marketplace to the marketplace inbox screen', () {
      final widget = buildAuthenticatedStartScreen(
        Uri.parse('https://app.immogestion.app/marketplace'),
      );

      expect(widget, isA<AuthGate>());
      expect((widget as AuthGate).child, isA<MarketplaceInboxScreen>());
    });

    test('maps /leads/:id to the lead detail route screen', () {
      final widget = buildAuthenticatedStartScreen(
        Uri.parse('https://app.immogestion.app/leads/lead-123'),
      );

      expect(widget, isA<AuthGate>());
      expect(
        (widget as AuthGate).child.runtimeType.toString(),
        contains('LeadDetailRouteScreen'),
      );
    });

    test('maps /visits/:id to the visit detail route screen', () {
      final widget = buildAuthenticatedStartScreen(
        Uri.parse('https://app.immogestion.app/visits/visit-123'),
      );

      expect(widget, isA<AuthGate>());
      expect(
        (widget as AuthGate).child.runtimeType.toString(),
        contains('VisitDetailRouteScreen'),
      );
    });

    test('maps /visits to the visits screen', () {
      final widget = buildAuthenticatedStartScreen(
        Uri.parse('https://app.immogestion.app/visits/'),
      );

      expect(widget, isA<AuthGate>());
      expect((widget as AuthGate).child, isA<VisitsScreen>());
    });

    test('keeps unknown authenticated paths on the dashboard fallback', () {
      final widget = buildAuthenticatedStartScreen(
        Uri.parse('https://app.immogestion.app/unknown'),
      );

      expect(widget, isA<AuthGate>());
      expect((widget as AuthGate).child, isA<HomeScreen>());
    });
  });
}
