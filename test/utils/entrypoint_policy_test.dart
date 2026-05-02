import 'package:flutter_test/flutter_test.dart';

import 'package:immogestion/utils/entrypoint_policy.dart';

void main() {
  group('entrypoint policy', () {
    test('root public host uses public landing on landing pages', () {
      final destination = resolveEntryPointDestination(
        location: Uri.parse('https://immogestion.app/'),
        isLoggedIn: false,
      );

      expect(destination, EntryPointDestination.publicLanding);
    });

    test('root public host sends non-landing paths to login wall', () {
      final destination = resolveEntryPointDestination(
        location: Uri.parse('https://immogestion.app/dashboard'),
        isLoggedIn: false,
      );

      expect(destination, EntryPointDestination.loginWall);
    });

    test('app host sends signed-out users to login wall', () {
      final destination = resolveEntryPointDestination(
        location: Uri.parse('https://app.immogestion.app/'),
        isLoggedIn: false,
      );

      expect(destination, EntryPointDestination.loginWall);
    });

    test('app host sends signed-in users to app shell', () {
      final destination = resolveEntryPointDestination(
        location: Uri.parse('https://app.immogestion.app/'),
        isLoggedIn: true,
      );

      expect(destination, EntryPointDestination.appShell);
    });

    test('unknown hosts default to login wall for signed-out users', () {
      final destination = resolveEntryPointDestination(
        location: Uri.parse('https://example.com/'),
        isLoggedIn: false,
      );

      expect(destination, EntryPointDestination.loginWall);
    });
  });
}
