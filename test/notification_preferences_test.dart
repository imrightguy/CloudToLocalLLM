import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:immogestion/models.dart';
import 'package:immogestion/services/notification_preferences_service.dart';

void main() {
  group('NotificationPreferences defaults', () {
    test('email notifications are enabled by default', () {
      const prefs = NotificationPreferences();
      expect(prefs.emailNotifications, isTrue);
    });

    test('sms notifications are disabled by default', () {
      const prefs = NotificationPreferences();
      expect(prefs.smsNotifications, isFalse);
    });

    test('weekly digest is enabled by default', () {
      const prefs = NotificationPreferences();
      expect(prefs.weeklyDigest, isTrue);
    });

    test('quiet hours are disabled by default', () {
      const prefs = NotificationPreferences();
      expect(prefs.quietHoursEnabled, isFalse);
      expect(prefs.quietHoursStart, isNull);
      expect(prefs.quietHoursEnd, isNull);
    });
  });

  group('NotificationPreferences fromJson', () {
    test('parses all fields', () {
      final prefs = NotificationPreferences.fromJson({
        'emailNotifications': false,
        'smsNotifications': true,
        'weeklyDigest': false,
        'quietHoursStart': '22:00',
        'quietHoursEnd': '07:00',
        'quietHoursEnabled': true,
      });

      expect(prefs.emailNotifications, isFalse);
      expect(prefs.smsNotifications, isTrue);
      expect(prefs.weeklyDigest, isFalse);
      expect(prefs.quietHoursEnabled, isTrue);
      expect(prefs.quietHoursStart, const TimeOfDay(hour: 22, minute: 0));
      expect(prefs.quietHoursEnd, const TimeOfDay(hour: 7, minute: 0));
    });

    test('defaults missing fields', () {
      final prefs = NotificationPreferences.fromJson({});
      expect(prefs.emailNotifications, isTrue);
      expect(prefs.smsNotifications, isFalse);
      expect(prefs.weeklyDigest, isTrue);
      expect(prefs.quietHoursEnabled, isFalse);
      expect(prefs.quietHoursStart, isNull);
      expect(prefs.quietHoursEnd, isNull);
    });

    test('handles null time strings', () {
      final prefs = NotificationPreferences.fromJson({
        'quietHoursStart': null,
        'quietHoursEnd': null,
      });
      expect(prefs.quietHoursStart, isNull);
      expect(prefs.quietHoursEnd, isNull);
    });

    test('handles empty time strings', () {
      final prefs = NotificationPreferences.fromJson({
        'quietHoursStart': '',
        'quietHoursEnd': '',
      });
      expect(prefs.quietHoursStart, isNull);
      expect(prefs.quietHoursEnd, isNull);
    });

    test('handles malformed time strings', () {
      final prefs = NotificationPreferences.fromJson({
        'quietHoursStart': 'invalid',
        'quietHoursEnd': '25:99',
      });
      expect(prefs.quietHoursStart, isNull);
      expect(prefs.quietHoursEnd, isNull);
    });

    test('parses single-digit hours and minutes', () {
      final prefs = NotificationPreferences.fromJson({
        'quietHoursStart': '9:5',
        'quietHoursEnd': '7:30',
      });
      expect(prefs.quietHoursStart, const TimeOfDay(hour: 9, minute: 5));
      expect(prefs.quietHoursEnd, const TimeOfDay(hour: 7, minute: 30));
    });
  });

  group('NotificationPreferences toJson', () {
    test('serializes all fields', () {
      const prefs = NotificationPreferences(
        emailNotifications: false,
        smsNotifications: true,
        weeklyDigest: true,
        quietHoursStart: TimeOfDay(hour: 22, minute: 0),
        quietHoursEnd: TimeOfDay(hour: 7, minute: 30),
        quietHoursEnabled: true,
      );

      final json = prefs.toJson();
      expect(json['emailNotifications'], isFalse);
      expect(json['smsNotifications'], isTrue);
      expect(json['weeklyDigest'], isTrue);
      expect(json['quietHoursStart'], '22:00');
      expect(json['quietHoursEnd'], '07:30');
      expect(json['quietHoursEnabled'], isTrue);
    });

    test('omits null time fields', () {
      const prefs = NotificationPreferences();
      final json = prefs.toJson();
      expect(json.containsKey('quietHoursStart'), isFalse);
      expect(json.containsKey('quietHoursEnd'), isFalse);
    });

    test('formats times with zero-padding', () {
      const prefs = NotificationPreferences(
        quietHoursStart: TimeOfDay(hour: 7, minute: 5),
        quietHoursEnd: TimeOfDay(hour: 9, minute: 30),
      );

      final json = prefs.toJson();
      expect(json['quietHoursStart'], '07:05');
      expect(json['quietHoursEnd'], '09:30');
    });
  });

  group('NotificationPreferences round-trip', () {
    test('fromJson → toJson → fromJson preserves data', () {
      final original = NotificationPreferences.fromJson({
        'emailNotifications': true,
        'smsNotifications': false,
        'weeklyDigest': true,
        'quietHoursStart': '22:00',
        'quietHoursEnd': '07:00',
        'quietHoursEnabled': true,
      });

      final json = original.toJson();
      final restored = NotificationPreferences.fromJson(json);

      expect(restored.emailNotifications, original.emailNotifications);
      expect(restored.smsNotifications, original.smsNotifications);
      expect(restored.weeklyDigest, original.weeklyDigest);
      expect(restored.quietHoursEnabled, original.quietHoursEnabled);
      expect(restored.quietHoursStart, original.quietHoursStart);
      expect(restored.quietHoursEnd, original.quietHoursEnd);
    });
  });

  group('NotificationPreferences copyWith', () {
    test('overrides specified fields', () {
      const prefs = NotificationPreferences();
      final updated = prefs.copyWith(emailNotifications: false, smsNotifications: true);

      expect(updated.emailNotifications, isFalse);
      expect(updated.smsNotifications, isTrue);
      expect(updated.weeklyDigest, isTrue); // unchanged
      expect(updated.quietHoursEnabled, isFalse); // unchanged
    });

    test('can set quiet hours', () {
      const prefs = NotificationPreferences();
      final updated = prefs.copyWith(
        quietHoursStart: const TimeOfDay(hour: 22, minute: 0),
        quietHoursEnd: const TimeOfDay(hour: 7, minute: 0),
        quietHoursEnabled: true,
      );

      expect(updated.quietHoursStart, const TimeOfDay(hour: 22, minute: 0));
      expect(updated.quietHoursEnd, const TimeOfDay(hour: 7, minute: 0));
      expect(updated.quietHoursEnabled, isTrue);
    });

    test('can clear quiet hours', () {
      const prefs = NotificationPreferences(
        quietHoursStart: TimeOfDay(hour: 22, minute: 0),
        quietHoursEnd: TimeOfDay(hour: 7, minute: 0),
      );
      final updated = prefs.copyWith(clearStart: true, clearEnd: true);

      expect(updated.quietHoursStart, isNull);
      expect(updated.quietHoursEnd, isNull);
    });
  });

  group('NotificationPreferencesService singleton', () {
    test('instance is always the same object', () {
      expect(
        NotificationPreferencesService.instance,
        same(NotificationPreferencesService.instance),
      );
    });

    test('initial prefs are defaults', () {
      final service = NotificationPreferencesService.instance;
      expect(service.prefs.emailNotifications, isTrue);
      expect(service.prefs.smsNotifications, isFalse);
      expect(service.prefs.weeklyDigest, isTrue);
    });
  });
}
