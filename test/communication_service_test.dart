import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';

void main() {
  // ---------------------------------------------------------------------------
  // CommunicationItem model
  // ---------------------------------------------------------------------------
  group('CommunicationItem', () {
    test('fromJson with full API payload', () {
      final json = {
        'id': 'comm-1',
        'contactId': 'contact-1',
        'contactName': 'Jean Dupont',
        'contactPhone': '514-555-1234',
        'type': 'sms',
        'direction': 'outbound',
        'status': 'delivered',
        'subject': 'Confirmation de visite',
        'body': 'Votre visite est confirmée pour lundi.',
        'createdAt': '2025-06-15T14:30:00.000Z',
        'parentId': 'comm-0',
      };

      final c = CommunicationItem.fromJson(json);

      expect(c.id, 'comm-1');
      expect(c.contactId, 'contact-1');
      expect(c.contactName, 'Jean Dupont');
      expect(c.contactPhone, '514-555-1234');
      expect(c.contactInitials, 'JD');
      expect(c.type, 'sms');
      expect(c.direction, 'outbound');
      expect(c.status, 'delivered');
      expect(c.subject, 'Confirmation de visite');
      expect(c.body, 'Votre visite est confirmée pour lundi.');
      expect(c.createdAt, DateTime.parse('2025-06-15T14:30:00.000Z'));
      expect(c.parentId, 'comm-0');
    });

    test('fromJson with nested contact object', () {
      final json = {
        'id': 'comm-2',
        'contact': {
          'id': 'contact-2',
          'fullName': 'Marie Tremblay',
          'phone': '514-555-5678',
        },
        'type': 'call',
        'direction': 'inbound',
        'status': 'completed',
        'subject': '',
        'body': 'Appel reçu',
        'createdAt': '2025-07-01T09:00:00.000Z',
      };

      final c = CommunicationItem.fromJson(json);

      expect(c.contactId, 'contact-2');
      expect(c.contactName, 'Marie Tremblay');
      expect(c.contactPhone, '514-555-5678');
      expect(c.contactInitials, 'MT');
    });

    test('fromJson defaults missing optional fields', () {
      final json = <String, dynamic>{
        'contactId': 'contact-3',
        'contactName': 'A',
        'contactPhone': '',
        'body': 'test',
        'createdAt': '2025-01-01T00:00:00.000Z',
      };

      final c = CommunicationItem.fromJson(json);

      expect(c.id, isNull);
      expect(c.type, 'note');
      expect(c.direction, 'outbound');
      expect(c.status, 'sent');
      expect(c.subject, '');
      expect(c.parentId, isNull);
    });

    test('fromJson extracts initials from single name', () {
      final json = {
        'contactId': 'c1',
        'contactName': 'Madonna',
        'contactPhone': '',
        'body': 'x',
        'createdAt': '2025-01-01T00:00:00.000Z',
      };

      final c = CommunicationItem.fromJson(json);
      expect(c.contactInitials, 'MA');
    });

    test('fromJson extracts initials from single-char name', () {
      final json = {
        'contactId': 'c1',
        'contactName': 'A',
        'contactPhone': '',
        'body': 'x',
        'createdAt': '2025-01-01T00:00:00.000Z',
      };

      final c = CommunicationItem.fromJson(json);
      expect(c.contactInitials, 'A');
    });

    test('fromJson handles empty contactName gracefully', () {
      final json = {
        'contactId': 'c1',
        'contactName': '',
        'contactPhone': '',
        'body': 'x',
        'createdAt': '2025-01-01T00:00:00.000Z',
      };

      final c = CommunicationItem.fromJson(json);
      expect(c.contactInitials, '?');
    });

    test('fromJson falls back to content when body missing', () {
      final json = {
        'contactId': 'c1',
        'contactName': 'Test User',
        'contactPhone': '',
        'content': 'Contenu de rechange',
        'createdAt': '2025-01-01T00:00:00.000Z',
      };

      final c = CommunicationItem.fromJson(json);
      expect(c.body, 'Contenu de rechange');
    });

    test('fromJson handles invalid createdAt gracefully', () {
      final json = {
        'contactId': 'c1',
        'contactName': 'Test',
        'contactPhone': '',
        'body': 'x',
        'createdAt': 'not-a-date',
      };

      final c = CommunicationItem.fromJson(json);
      // Should fall back to DateTime.now() — just verify it's not null
      expect(c.createdAt, isNotNull);
    });

    test('toJson round-trips key fields', () {
      final c = CommunicationItem(
        id: 'comm-3',
        contactId: 'contact-4',
        contactName: 'Pierre Martin',
        contactPhone: '514-555-9999',
        contactInitials: 'PM',
        type: 'email',
        direction: 'outbound',
        status: 'sent',
        subject: 'Offre de bail',
        body: 'Veuillez trouver ci-joint...',
        createdAt: DateTime.parse('2025-08-01T12:00:00.000Z'),
        parentId: 'comm-parent',
      );

      final json = c.toJson();

      expect(json['id'], 'comm-3');
      expect(json['contactId'], 'contact-4');
      expect(json['contactName'], 'Pierre Martin');
      expect(json['contactPhone'], '514-555-9999');
      expect(json['type'], 'email');
      expect(json['direction'], 'outbound');
      expect(json['status'], 'sent');
      expect(json['subject'], 'Offre de bail');
      expect(json['body'], 'Veuillez trouver ci-joint...');
      expect(json['createdAt'], '2025-08-01T12:00:00.000Z');
      expect(json['parentId'], 'comm-parent');
    });

    test('toJson omits null id and parentId', () {
      final c = CommunicationItem(
        contactId: 'c1',
        contactName: 'Test',
        contactPhone: '',
        contactInitials: 'TE',
        type: 'note',
        direction: 'outbound',
        status: 'sent',
        subject: '',
        body: 'test',
        createdAt: DateTime(2025),
      );

      final json = c.toJson();

      expect(json.containsKey('id'), false);
      expect(json.containsKey('parentId'), false);
    });

    test('toJson omits empty subject', () {
      final c = CommunicationItem(
        contactId: 'c1',
        contactName: 'Test',
        contactPhone: '',
        contactInitials: 'TE',
        type: 'sms',
        direction: 'inbound',
        status: 'delivered',
        subject: '',
        body: 'msg',
        createdAt: DateTime(2025),
      );

      final json = c.toJson();

      expect(json.containsKey('subject'), false);
    });
  });

  // ---------------------------------------------------------------------------
  // SmsScheduleRequest
  // ---------------------------------------------------------------------------
  group('SmsScheduleRequest', () {
    test('toJson with scheduledAt and templateId', () {
      final req = SmsScheduleRequest(
        contactId: 'contact-1',
        message: 'Bonjour, visite confirmée.',
        scheduledAt: DateTime.parse('2025-07-01T10:00:00.000Z'),
        templateId: 'tmpl-1',
      );

      final json = req.toJson();

      expect(json['contactId'], 'contact-1');
      expect(json['message'], 'Bonjour, visite confirmée.');
      expect(json['scheduledAt'], '2025-07-01T10:00:00.000Z');
      expect(json['templateId'], 'tmpl-1');
    });

    test('toJson omits null optional fields', () {
      final req = SmsScheduleRequest(
        contactId: 'contact-2',
        message: 'Rappel',
      );

      final json = req.toJson();

      expect(json['contactId'], 'contact-2');
      expect(json['message'], 'Rappel');
      expect(json.containsKey('scheduledAt'), false);
      expect(json.containsKey('templateId'), false);
    });
  });

  // ---------------------------------------------------------------------------
  // SmsDeliveryStatus
  // ---------------------------------------------------------------------------
  group('SmsDeliveryStatus', () {
    test('fromString parses all valid values', () {
      expect(SmsDeliveryStatus.fromString('queued'), SmsDeliveryStatus.queued);
      expect(SmsDeliveryStatus.fromString('sent'), SmsDeliveryStatus.sent);
      expect(SmsDeliveryStatus.fromString('delivered'), SmsDeliveryStatus.delivered);
      expect(SmsDeliveryStatus.fromString('read'), SmsDeliveryStatus.read);
      expect(SmsDeliveryStatus.fromString('failed'), SmsDeliveryStatus.failed);
    });

    test('fromString is case-insensitive', () {
      expect(SmsDeliveryStatus.fromString('Queued'), SmsDeliveryStatus.queued);
      expect(SmsDeliveryStatus.fromString('DELIVERED'), SmsDeliveryStatus.delivered);
      expect(SmsDeliveryStatus.fromString('Read'), SmsDeliveryStatus.read);
    });

    test('fromString defaults to queued for unknown values', () {
      expect(SmsDeliveryStatus.fromString('unknown'), SmsDeliveryStatus.queued);
      expect(SmsDeliveryStatus.fromString(''), SmsDeliveryStatus.queued);
      expect(SmsDeliveryStatus.fromString('pending'), SmsDeliveryStatus.queued);
    });

    test('label returns French display strings', () {
      expect(SmsDeliveryStatus.queued.label, 'En attente');
      expect(SmsDeliveryStatus.sent.label, 'Envoyé');
      expect(SmsDeliveryStatus.delivered.label, 'Livré');
      expect(SmsDeliveryStatus.read.label, 'Lu');
      expect(SmsDeliveryStatus.failed.label, 'Échoué');
    });
  });

  // ---------------------------------------------------------------------------
  // SmsMessage
  // ---------------------------------------------------------------------------
  group('SmsMessage', () {
    test('fromJson with full payload', () {
      final json = {
        'id': 'sms-1',
        'contactId': 'contact-1',
        'direction': 'outbound',
        'body': 'Visite confirmée.',
        'status': 'delivered',
        'createdAt': '2025-06-15T14:30:00.000Z',
        'errorCode': null,
        'errorMessage': null,
      };

      final msg = SmsMessage.fromJson(json);

      expect(msg.id, 'sms-1');
      expect(msg.contactId, 'contact-1');
      expect(msg.direction, 'outbound');
      expect(msg.body, 'Visite confirmée.');
      expect(msg.status, SmsDeliveryStatus.delivered);
      expect(msg.createdAt, DateTime.parse('2025-06-15T14:30:00.000Z'));
      expect(msg.errorCode, isNull);
      expect(msg.errorMessage, isNull);
    });

    test('fromJson handles failed message with error info', () {
      final json = {
        'id': 'sms-2',
        'contactId': 'contact-2',
        'direction': 'outbound',
        'body': 'Test',
        'status': 'failed',
        'createdAt': '2025-06-15T14:30:00.000Z',
        'errorCode': '30001',
        'errorMessage': 'Queue overflow',
      };

      final msg = SmsMessage.fromJson(json);

      expect(msg.status, SmsDeliveryStatus.failed);
      expect(msg.errorCode, '30001');
      expect(msg.errorMessage, 'Queue overflow');
    });
  });

  // ---------------------------------------------------------------------------
  // ConversationThread
  // ---------------------------------------------------------------------------
  group('ConversationThread', () {
    test('lastMessage returns first message', () {
      final thread = ConversationThread(
        contactId: 'c1',
        contactName: 'Jean Dupont',
        contactPhone: '514-555-1234',
        contactInitials: 'JD',
        messages: [
          CommunicationItem(
            id: 'm1',
            contactId: 'c1',
            contactName: 'Jean Dupont',
            contactPhone: '514-555-1234',
            contactInitials: 'JD',
            type: 'sms',
            direction: 'outbound',
            status: 'sent',
            subject: '',
            body: 'First',
            createdAt: DateTime(2025),
          ),
          CommunicationItem(
            id: 'm2',
            contactId: 'c1',
            contactName: 'Jean Dupont',
            contactPhone: '514-555-1234',
            contactInitials: 'JD',
            type: 'sms',
            direction: 'inbound',
            status: 'delivered',
            subject: '',
            body: 'Second',
            createdAt: DateTime(2025),
          ),
        ],
      );

      expect(thread.lastMessage, isNotNull);
      expect(thread.lastMessage!.id, 'm1');
    });

    test('lastMessage returns null for empty messages', () {
      final thread = ConversationThread(
        contactId: 'c1',
        contactName: 'Test',
        contactPhone: '',
        contactInitials: 'T',
        messages: [],
      );

      expect(thread.lastMessage, isNull);
    });
  });
}
