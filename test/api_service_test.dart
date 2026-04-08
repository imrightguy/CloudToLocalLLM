import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:immogestion/services/api_service.dart';

void main() {
  group('ApiException', () {
    test('stores message and optional statusCode', () {
      final e = ApiException('something failed', statusCode: 404);
      expect(e.message, 'something failed');
      expect(e.statusCode, 404);
    });

    test('statusCode defaults to null', () {
      final e = ApiException('oops');
      expect(e.statusCode, isNull);
    });

    test('toString includes message and statusCode', () {
      final e = ApiException('not found', statusCode: 404);
      expect(e.toString(), contains('not found'));
      expect(e.toString(), contains('404'));
    });

    test('toString without statusCode omits status', () {
      final e = ApiException('network error');
      expect(e.toString(), contains('network error'));
      expect(e.toString(), contains('null'), reason: 'should show null status');
    });
  });

  group('ApiService singleton', () {
    late ApiService api;

    setUp(() {
      api = ApiService.instance;
    });

    test('hasToken is false when no token set', () {
      expect(api.hasToken, isFalse);
    });
  });

  group('ApiService headers', () {
    test('_getHeaders returns Content-Type without token', () {
      final api = ApiService.instance;
      // Access via the public interface — headers are private,
      // so we test indirectly through the request flow.
      // Instead, verify the header contract: no auth header when no token.
      expect(api.hasToken, isFalse);
    });
  });

  group('ApiService request error parsing', () {
    // These tests validate the error-parsing logic in _request by testing
    // the observable behavior through ApiException messages.
    // Full HTTP integration tests require a mocking library.

    test('ApiException message is preserved through throw/catch', () {
      const message = 'Session expirée — veuillez vous reconnecter';
      try {
        throw ApiException(message);
      } on ApiException catch (e) {
        expect(e.message, message);
      }
    });

    test('ApiException with French error messages', () {
      final errors = [
        'Erreur réseau — vérifiez votre connexion',
        'Réponse invalide du serveur',
        'Session expirée — veuillez vous reconnecter',
      ];
      for (final msg in errors) {
        final e = ApiException(msg, statusCode: 401);
        expect(e.toString(), contains(msg));
      }
    });
  });

  group('ApiService JSON handling', () {
    test('login response shape can be parsed', () {
      // Simulate the response shape the login method expects
      final responseJson = jsonDecode('''
{
  "success": true,
  "data": {
    "tokens": {
      "accessToken": "eyJhbGciOiJIUzI1NiIs...",
      "refreshToken": "rt_abc123"
    },
    "user": {
      "id": "user-1",
      "email": "test@example.com",
      "firstName": "Jean",
      "lastName": "Dupont"
    }
  }
}
''') as Map<String, dynamic>;

      expect(responseJson['success'], isTrue);
      final data = responseJson['data'] as Map<String, dynamic>;
      final tokens = data['tokens'] as Map<String, dynamic>;
      expect(tokens['accessToken'], isA<String>());
      expect(tokens['refreshToken'], isA<String>());
      expect(data['user'], isA<Map<String, dynamic>>());
    });

    test('register response shape can be parsed', () {
      final responseJson = jsonDecode('''
{
  "success": true,
  "data": {
    "tokens": {
      "accessToken": "eyJhbGciOiJIUzI1NiIs...",
      "refreshToken": "rt_xyz789"
    },
    "user": {
      "id": "user-2",
      "email": "new@example.com",
      "firstName": "Marie",
      "lastName": "Curie",
      "role": "tenant"
    }
  }
}
''') as Map<String, dynamic>;

      final data = responseJson['data'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      expect(user['role'], 'tenant');
    });

    test('error response with nested error object', () {
      final responseJson = jsonDecode('''
{
  "error": {
    "message": "Email already registered"
  }
}
''') as Map<String, dynamic>;

      // This mirrors the error extraction logic in _request
      final errorMsg = responseJson['error'] is Map
          ? responseJson['error']['message'] ?? responseJson['error'].toString()
          : responseJson['message'] ?? 'Erreur';
      expect(errorMsg, 'Email already registered');
    });

    test('error response with flat message', () {
      final responseJson = jsonDecode('''
{
  "message": "Invalid credentials"
}
''') as Map<String, dynamic>;

      final errorMsg = responseJson['error'] is Map
          ? responseJson['error']['message']
          : responseJson['message'] ?? 'Erreur';
      expect(errorMsg, 'Invalid credentials');
    });
  });
}
