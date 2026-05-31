import 'package:cloudtolocalllm/screens/channels/channels_screen.dart';
import 'package:cloudtolocalllm/screens/instances/instances_screen.dart';
import 'package:cloudtolocalllm/screens/sessions/sessions_screen.dart';
import 'package:cloudtolocalllm/models/channel.dart';
import 'package:cloudtolocalllm/models/instance.dart';
import 'package:cloudtolocalllm/models/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cockpit screens', () {
    testWidgets('ChannelsScreen renders loaded real channels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChannelsScreen(
            loadChannels: () async => [
              GatewayChannel(
                id: 'channel_general',
                name: 'general',
                description: 'Latest thought · 2 agents',
                messageCount: 8,
                lastActivity: DateTime.now(),
                unreadCount: 3,
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('general'), findsOneWidget);
      expect(find.textContaining('8 thoughts'), findsOneWidget);
      expect(find.textContaining('Recent 3'), findsOneWidget);
    });

    testWidgets('ChannelsScreen surfaces loader errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChannelsScreen(
            loadChannels: () async => throw StateError('boom'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load channels'), findsOneWidget);
    });

    testWidgets('SessionsScreen renders loaded websocket, conversation, and user sessions',
        (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: SessionsScreen(
            loadSessionsData: () async => SessionsScreenData(
              websocketSessions: [
                SessionData.websocket(
                  id: 'ws-1',
                  subject: 'proxy-container-1',
                  detail: 'Proxy proxy-123 · running',
                  startTime: now.subtract(const Duration(minutes: 12)),
                  messageCount: 2,
                  status: 'running',
                  userId: 'user-1',
                  containerId: 'container-1',
                ),
              ],
              conversationSessions: [
                SessionData.conversation(
                  id: 'conv-1',
                  subject: 'Design review',
                  detail: 'Model: hermes-agent',
                  startTime: now.subtract(const Duration(hours: 2)),
                  messageCount: 14,
                  status: 'active',
                ),
              ],
              userSessions: [
                SessionData.user(
                  id: 'sess-1',
                  subject: 'Ada Lovelace',
                  detail: 'Expires in 30m · ada@example.com',
                  startTime: now.subtract(const Duration(hours: 4)),
                  messageCount: 0,
                  status: 'active',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('proxy-container-1'), findsOneWidget);

      await tester.tap(find.text('Conversation'));
      await tester.pumpAndSettle();
      expect(find.text('Design review'), findsOneWidget);

      await tester.tap(find.text('User'));
      await tester.pumpAndSettle();
      expect(find.text('Ada Lovelace'), findsOneWidget);
    });

    testWidgets('SessionsScreen surfaces loader errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SessionsScreen(
            loadSessionsData: () async => throw StateError('boom'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load sessions'), findsOneWidget);
    });

    testWidgets('InstancesScreen renders real gateway and model catalog data',
        (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: InstancesScreen(
            loadInstancesData: () async => InstancesScreenData(
              gatewayState: GatewayInstanceState(
                status: 'running',
                startedAt: now.subtract(const Duration(hours: 3)),
                port: 8080,
              ),
              modelInstances: [
                ModelInstanceState(
                  modelId: 'gpt-4.1-mini',
                  alias: 'Primary Chat Model',
                  contextWindow: 128000,
                  maxTokens: 16000,
                  pricingInput: 0.0005,
                  pricingOutput: 0.0015,
                  isPrimary: true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('RUNNING'), findsWidgets);
      expect(find.text('Primary Chat Model'), findsOneWidget);
      expect(find.textContaining('gpt-4.1-mini'), findsOneWidget);
    });

    testWidgets('InstancesScreen surfaces loader errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InstancesScreen(
            loadInstancesData: () async => throw StateError('boom'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load instances'), findsOneWidget);
    });
  });
}
