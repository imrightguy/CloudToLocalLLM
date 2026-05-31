import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('main chat cockpit transport review gate', () {
    test('future sync path files stay transport-free', () {
      final envelopeSource = File(
        'lib/services/hermes_manager/main_chat_timeline_sync_envelope.dart',
      ).readAsStringSync();
      final trustStoreSource = File(
        'lib/services/hermes_manager/main_chat_timeline_trust_store.dart',
      ).readAsStringSync();

      final selectorSource = File(
        'lib/services/hermes_manager/main_chat_timeline_destination_selector.dart',
      ).readAsStringSync();

      for (final source in <String>[envelopeSource, trustStoreSource, selectorSource]) {
        expect(source, isNot(contains('dart:io')));
        expect(source, isNot(contains('package:shelf')));
        expect(source, isNot(contains('package:shelf_router')));
        expect(source, isNot(contains('HttpServer')));
        expect(source, isNot(contains('ServerSocket')));
        expect(source, isNot(contains('WebSocket')));
        expect(source, isNot(contains('bindHost')));
        expect(source, isNot(contains('targetIp')));
        expect(source, isNot(contains('0.0.0.0')));
        expect(source, isNot(contains('/api/main-chat-timeline-sync')));
        expect(source, isNot(contains('/main-chat-timeline/sync')));
      }
    });

    test('sync gate rules stay explicit in the review document', () {
      final gateDoc = File(
        'docs/plans/2026-05-09-main-chat-cockpit-transport-review-gate.md',
      ).readAsStringSync();

      expect(gateDoc, contains('No unauthenticated listener.'));
      expect(gateDoc, contains('No all-interface bind by default.'));
      expect(gateDoc, contains('No client-selected target IP or route authority.'));
      expect(gateDoc, contains('No unpaired-device writes.'));
      expect(gateDoc, contains('No user-JWT-as-device-auth.'));
    });
  });
}
