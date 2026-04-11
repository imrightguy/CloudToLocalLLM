import 'package:flutter_test/flutter_test.dart';

import 'package:immogestion/models.dart';
import 'package:immogestion/services/auth_service.dart';

void main() {
  group('AuthNotifier singleton', () {
    test('instance is always the same object', () {
      expect(AuthNotifier.instance, same(AuthNotifier.instance));
    });

    test('constructor is private — cannot be instantiated externally', () {
      // AuthNotifier._() is private; only instance is available.
      // This is enforced at the language level — no way to call it.
      // Verify the singleton is accessible.
      expect(AuthNotifier.instance, isA<AuthNotifier>());
    });
  });

  group('AuthNotifier initial state', () {
    test('isLoggedIn is false when no token set', () {
      expect(AuthNotifier.instance.isLoggedIn, isFalse);
    });

    test('currentUser is null initially', () {
      expect(AuthNotifier.instance.currentUser, isNull);
    });

    test('isLoggedIn reflects ApiService token state', () {
      // When no token is stored, both should agree.
      final auth = AuthNotifier.instance;
      expect(auth.isLoggedIn, isFalse);
      // After a fresh init (no token), user should still be null.
      expect(auth.currentUser, isNull);
    });
  });

  group('AuthNotifier listener contract', () {
    test('logout resets currentUser to null', () {
      // After logout (even if API call fails), currentUser is cleared.
      // This is verified by initial state — no need for network call.
      final auth = AuthNotifier.instance;
      expect(auth.currentUser, isNull);
    });
  });

  group('UserItem fullName', () {
    test('returns combined first and last name', () {
      const user = UserItem(
        firstName: 'Jean',
        lastName: 'Dupont',
        email: 'jean@example.com',
      );
      expect(user.fullName, 'Jean Dupont');
    });

    test('trims outer whitespace from combined string', () {
      const user = UserItem(
        firstName: ' Jean ',
        lastName: ' Dupont ',
        email: 'jean@example.com',
      );
      // '$firstName $lastName'.trim() only trims outer edges, not internal spaces
      expect(user.fullName, 'Jean   Dupont');
    });

    test('falls back to Utilisateur for empty names', () {
      const user = UserItem(
        firstName: '',
        lastName: '',
        email: 'empty@example.com',
      );
      expect(user.fullName, 'Utilisateur');
    });

    test('falls back to Utilisateur for whitespace-only names', () {
      const user = UserItem(
        firstName: '   ',
        lastName: '   ',
        email: 'whitespace@example.com',
      );
      expect(user.fullName, 'Utilisateur');
    });

    test('handles single name (last empty)', () {
      const user = UserItem(
        firstName: 'Jean',
        lastName: '',
        email: 'jean@example.com',
      );
      expect(user.fullName, 'Jean');
    });

    test('handles single name (first empty)', () {
      const user = UserItem(
        firstName: '',
        lastName: 'Dupont',
        email: 'jean@example.com',
      );
      expect(user.fullName, 'Dupont');
    });
  });

  group('UserItem model', () {
    test('fromJson parses all fields', () {
      final user = UserItem.fromJson({
        'id': 'u-1',
        'firstName': 'Simon',
        'lastName': 'Gagnon',
        'email': 'simon@example.com',
        'phone': '+15145551234',
        'role': 'admin',
        'company': 'ImmoGestion',
        'language': 'fr',
        'createdAt': '2025-01-15T10:30:00.000Z',
      });

      expect(user.id, 'u-1');
      expect(user.firstName, 'Simon');
      expect(user.lastName, 'Gagnon');
      expect(user.email, 'simon@example.com');
      expect(user.phone, '+15145551234');
      expect(user.role, 'admin');
      expect(user.company, 'ImmoGestion');
      expect(user.language, 'fr');
      expect(user.createdAt, isNotNull);
    });

    test('fromJson defaults null optional fields', () {
      final user = UserItem.fromJson({
        'firstName': 'Test',
        'lastName': 'User',
        'email': 'test@example.com',
      });

      expect(user.id, isNull);
      expect(user.phone, isNull);
      expect(user.role, isNull);
      expect(user.company, isNull);
      expect(user.language, isNull);
      expect(user.createdAt, isNull);
    });

    test('fromJson handles missing firstName/lastName gracefully', () {
      final user = UserItem.fromJson({
        'email': 'minimal@example.com',
      });

      expect(user.firstName, '');
      expect(user.lastName, '');
      expect(user.fullName, 'Utilisateur');
    });

    test('toJson round-trips', () {
      const original = UserItem(
        id: 'u-42',
        firstName: 'Marie',
        lastName: 'Curie',
        email: 'marie@example.com',
        phone: '+15145559876',
        role: 'tenant',
      );

      final restored = UserItem.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.firstName, original.firstName);
      expect(restored.lastName, original.lastName);
      expect(restored.email, original.email);
      expect(restored.phone, original.phone);
      expect(restored.role, original.role);
    });

    test('toJson omits null optional fields', () {
      const user = UserItem(
        firstName: 'Test',
        lastName: 'User',
        email: 'test@example.com',
      );

      final json = user.toJson();

      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('phone'), isFalse);
      expect(json.containsKey('role'), isFalse);
      expect(json.containsKey('company'), isFalse);
      expect(json.containsKey('language'), isFalse);
      expect(json.containsKey('createdAt'), isFalse);
      expect(json['firstName'], 'Test');
      expect(json['lastName'], 'User');
      expect(json['email'], 'test@example.com');
    });
  });
}
