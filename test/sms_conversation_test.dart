import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';

void main() {
  group('SmsDeliveryStatus', () {
    test('fromString parses all variants', () {
      expect(SmsDeliveryStatus.fromString('queued'), SmsDeliveryStatus.queued);
      expect(SmsDeliveryStatus.fromString('sent'), SmsDeliveryStatus.sent);
      expect(SmsDeliveryStatus.fromString('delivered'), SmsDeliveryStatus.delivered);
      expect(SmsDeliveryStatus.fromString('read'), SmsDeliveryStatus.read);
      expect(SmsDeliveryStatus.fromString('failed'), SmsDeliveryStatus.failed);
    });

    test('fromString is case-insensitive', () {
      expect(SmsDeliveryStatus.fromString('SENT'), SmsDeliveryStatus.sent);
      expect(SmsDeliveryStatus.fromString('Read'), SmsDeliveryStatus.read);
    });

    test('fromString defaults to queued for unknown values', () {
      expect(SmsDeliveryStatus.fromString('unknown'), SmsDeliveryStatus.queued);
      expect(SmsDeliveryStatus.fromString(''), SmsDeliveryStatus.queued);
    });

    test('labels are in French', () {
      expect(SmsDeliveryStatus.queued.label, 'En attente');
      expect(SmsDeliveryStatus.sent.label, 'Envoyé');
      expect(SmsDeliveryStatus.delivered.label, 'Livré');
      expect(SmsDeliveryStatus.read.label, 'Lu');
      expect(SmsDeliveryStatus.failed.label, 'Échoué');
    });
  });

  group('SmsMessage', () {
    test('fromJson parses full message', () {
      final json = {
        'id': 'msg-1',
        'contactId': 'contact-1',
        'direction': 'outbound',
        'body': 'Bonjour !',
        'status': 'delivered',
        'createdAt': '2026-04-15T10:30:00Z',
      };

      final msg = SmsMessage.fromJson(json);
      expect(msg.id, 'msg-1');
      expect(msg.contactId, 'contact-1');
      expect(msg.direction, 'outbound');
      expect(msg.body, 'Bonjour !');
      expect(msg.status, SmsDeliveryStatus.delivered);
      expect(msg.isOutbound, true);
      expect(msg.isInbound, false);
      expect(msg.isFailed, false);
    });

    test('fromJson handles inbound message', () {
      final json = {
        'contactId': 'c1',
        'direction': 'inbound',
        'body': 'Merci',
        'status': 'read',
        'createdAt': '2026-04-15T11:00:00Z',
      };

      final msg = SmsMessage.fromJson(json);
      expect(msg.isInbound, true);
      expect(msg.isOutbound, false);
    });

    test('fromJson handles failed message with error', () {
      final json = {
        'contactId': 'c1',
        'direction': 'outbound',
        'body': 'Test',
        'status': 'failed',
        'errorCode': '42001',
        'errorMessage': 'Numéro invalide',
        'createdAt': '2026-04-15T12:00:00Z',
      };

      final msg = SmsMessage.fromJson(json);
      expect(msg.isFailed, true);
      expect(msg.errorCode, '42001');
      expect(msg.errorMessage, 'Numéro invalide');
    });

    test('fromJson falls back to sentAt when createdAt is missing', () {
      final json = {
        'contactId': 'c1',
        'direction': 'outbound',
        'body': 'Test',
        'status': 'sent',
        'sentAt': '2026-04-15T12:00:00Z',
      };

      final msg = SmsMessage.fromJson(json);
      expect(msg.createdAt.year, 2026);
    });

    test('fromJson defaults missing fields', () {
      final msg = SmsMessage.fromJson({});
      expect(msg.id, isNull);
      expect(msg.contactId, '');
      expect(msg.direction, 'outbound');
      expect(msg.body, '');
      expect(msg.status, SmsDeliveryStatus.queued);
      expect(msg.errorCode, isNull);
    });

    test('fromJson uses content fallback for body', () {
      final json = {
        'contactId': 'c1',
        'content': 'Message via content field',
      };

      final msg = SmsMessage.fromJson(json);
      expect(msg.body, 'Message via content field');
    });

    test('toJson round-trips key fields', () {
      final msg = SmsMessage(
        id: 'msg-1',
        contactId: 'c1',
        direction: 'outbound',
        body: 'Hello',
        status: SmsDeliveryStatus.delivered,
        createdAt: DateTime(2026, 4, 15, 10, 30),
      );

      final json = msg.toJson();
      expect(json['id'], 'msg-1');
      expect(json['contactId'], 'c1');
      expect(json['direction'], 'outbound');
      expect(json['body'], 'Hello');
      expect(json['status'], 'delivered');
    });

    test('toJson omits null optional fields', () {
      final msg = SmsMessage(
        contactId: 'c1',
        direction: 'inbound',
        body: 'Test',
        status: SmsDeliveryStatus.sent,
        createdAt: DateTime.now(),
      );

      final json = msg.toJson();
      expect(json.containsKey('id'), false);
      expect(json.containsKey('errorCode'), false);
      expect(json.containsKey('errorMessage'), false);
    });

    test('fromJson uses deliveryStatus fallback', () {
      final json = {
        'contactId': 'c1',
        'deliveryStatus': 'read',
      };

      final msg = SmsMessage.fromJson(json);
      expect(msg.status, SmsDeliveryStatus.read);
    });
  });

  group('QuickReply', () {
    test('stores label and message', () {
      const reply = QuickReply(label: 'Confirmer', message: 'Confirmé.');
      expect(reply.label, 'Confirmer');
      expect(reply.message, 'Confirmé.');
    });

    test('icon is optional', () {
      const reply = QuickReply(label: 'Test', message: 'Test msg');
      expect(reply.icon, isNull);

      const withIcon = QuickReply(
        label: 'Test',
        message: 'Test msg',
        icon: Icons.check,
      );
      expect(withIcon.icon, Icons.check);
    });
  });
}
