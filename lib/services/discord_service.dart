import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nyxx/nyxx.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Discord Bot Service
///
/// Manages Discord bot connection, message handling, and event processing.
/// Supports sending messages to Discord channels and receiving messages from users.
class DiscordService extends ChangeNotifier {
  static const String _botTokenKey = 'discord_bot_token';
  static const String _guildIdKey = 'discord_guild_id';

  NyxxGateway? _client;
  String? _botToken;
  String? _guildId;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _connectionError;

  final StreamController<DiscordMessageEvent> _messageController =
      StreamController<DiscordMessageEvent>.broadcast();

  final StreamController<DiscordConnectionEvent> _connectionController =
      StreamController<DiscordConnectionEvent>.broadcast();

  /// Stream of incoming Discord messages
  Stream<DiscordMessageEvent> get messageStream => _messageController.stream;

  /// Stream of connection state changes
  Stream<DiscordConnectionEvent> get connectionStream =>
      _connectionController.stream;

  /// Whether the bot is currently connected to Discord
  bool get isConnected => _isConnected;

  /// Whether the bot is currently connecting
  bool get isConnecting => _isConnecting;

  /// Last connection error, if any
  String? get connectionError => _connectionError;

  /// The bot token (if configured)
  String? get botToken => _botToken;

  /// The guild ID (if configured)
  String? get guildId => _guildId;

  /// Initialize the Discord service
  ///
  /// Loads configuration from shared preferences and optionally auto-connects.
  Future<void> initialize({bool autoConnect = false}) async {
    final prefs = await SharedPreferences.getInstance();
    _botToken = prefs.getString(_botTokenKey);
    _guildId = prefs.getString(_guildIdKey);

    if (autoConnect && _botToken != null && _botToken!.isNotEmpty) {
      await connect();
    }
  }

  /// Connect to Discord gateway
  ///
  /// Establishes a WebSocket connection to Discord using the configured token.
  /// Returns true if connection was successful.
  Future<bool> connect() async {
    if (_botToken == null || _botToken!.isEmpty) {
      _connectionError = 'Bot token not configured';
      _connectionController.add(DiscordConnectionEvent(
        connected: false,
        error: _connectionError,
      ));
      notifyListeners();
      return false;
    }

    if (_isConnected || _isConnecting) {
      debugPrint('[DiscordService] Already connected or connecting');
      return _isConnected;
    }

    _isConnecting = true;
    _connectionError = null;
    notifyListeners();

    try {
      debugPrint('[DiscordService] Connecting to Discord gateway...');

      _client = await Nyxx.connectGateway(
        _botToken!,
        GatewayIntents.allUnprivileged,
      );

      // Set up event handlers
      _setupEventHandlers();

      _isConnected = true;
      _isConnecting = false;

      _connectionController.add(DiscordConnectionEvent(
        connected: true,
      ));

      debugPrint('[DiscordService] Successfully connected to Discord');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[DiscordService] Connection failed: $e');
      _isConnected = false;
      _isConnecting = false;
      _connectionError = e.toString();

      _connectionController.add(DiscordConnectionEvent(
        connected: false,
        error: _connectionError,
      ));

      notifyListeners();
      return false;
    }
  }

  /// Disconnect from Discord gateway
  Future<void> disconnect() async {
    if (!_isConnected || _client == null) {
      return;
    }

    try {
      debugPrint('[DiscordService] Disconnecting from Discord...');
      await _client!.close();
      _client = null;
      _isConnected = false;
      _connectionError = null;

      _connectionController.add(DiscordConnectionEvent(
        connected: false,
      ));

      debugPrint('[DiscordService] Disconnected successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('[DiscordService] Error during disconnect: $e');
    }
  }

  /// Set the bot token
  ///
  /// Saves the token to persistent storage.
  Future<void> setBotToken(String token) async {
    _botToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_botTokenKey, token);
    debugPrint('[DiscordService] Bot token updated');
  }

  /// Set the guild ID
  ///
  /// Saves the guild ID to persistent storage.
  Future<void> setGuildId(String guildId) async {
    _guildId = guildId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guildIdKey, guildId);
    debugPrint('[DiscordService] Guild ID updated');
  }

  /// Send a message to a Discord channel
  ///
  /// [channelId] - The snowflake ID of the target channel
  /// [content] - The message content to send
  Future<void> sendMessage(String channelId, String content) async {
    if (!_isConnected || _client == null) {
      debugPrint('[DiscordService] Cannot send message: not connected');
      throw DiscordServiceException('Not connected to Discord');
    }

    try {
      final channel = await _client!.channels.get(Snowflake.parse(channelId));
      if (channel is TextChannel) {
        await channel.sendMessage(MessageBuilder(content: content));
        debugPrint('[DiscordService] Message sent to channel $channelId');
      } else {
        throw DiscordServiceException('Channel is not a text channel');
      }
    } catch (e) {
      debugPrint('[DiscordService] Failed to send message: $e');
      throw DiscordServiceException('Failed to send message: $e');
    }
  }

  /// Send a reply to a specific message
  ///
  /// [messageId] - The snowflake ID of the message to reply to
  /// [channelId] - The snowflake ID of the channel
  /// [content] - The reply content
  Future<void> sendReply(
    String channelId,
    String messageId,
    String content,
  ) async {
    if (!_isConnected || _client == null) {
      debugPrint('[DiscordService] Cannot send reply: not connected');
      throw DiscordServiceException('Not connected to Discord');
    }

    try {
      final channel = await _client!.channels.get(Snowflake.parse(channelId));
      if (channel is TextChannel) {
        await channel.sendMessage(
          MessageBuilder(
            content: content,
            referencedMessage: MessageReferenceBuilder.reply(
              messageId: Snowflake.parse(messageId),
            ),
          ),
        );
        debugPrint('[DiscordService] Reply sent to message $messageId');
      } else {
        throw DiscordServiceException('Channel is not a text channel');
      }
    } catch (e) {
      debugPrint('[DiscordService] Failed to send reply: $e');
      throw DiscordServiceException('Failed to send reply: $e');
    }
  }

  /// Test the current configuration
  ///
  /// Attempts to connect and verify the bot can access Discord.
  Future<Map<String, dynamic>> testConfiguration() async {
    if (_botToken == null || _botToken!.isEmpty) {
      return {
        'success': false,
        'error': 'Bot token not configured',
      };
    }

    try {
      final success = await connect();
      if (success) {
        final botUser = await _client!.users.fetchCurrentUser();
        return {
          'success': true,
          'botName': botUser.username,
          'botId': botUser.id.toString(),
          'connected': true,
        };
      } else {
        return {
          'success': false,
          'error': _connectionError ?? 'Unknown error',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Set up Discord event handlers
  void _setupEventHandlers() {
    if (_client == null) return;

    _client!.onMessageCreate.listen((event) {
      final message = event.message;

      // Skip if no content
      if (message.content.isEmpty) {
        return;
      }

      debugPrint(
          '[DiscordService] Received message from ${message.author.username}: ${message.content}');

      _messageController.add(DiscordMessageEvent(
        messageId: message.id.toString(),
        channelId: message.channelId.toString(),
        authorId: message.author.id.toString(),
        authorName: message.author.username,
        content: message.content,
        timestamp: DateTime.now(),
      ));
    });
  }

  /// Dispose of resources
  @override
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
    super.dispose();
  }
}

/// Event representing a Discord message received by the bot
class DiscordMessageEvent {
  final String messageId;
  final String channelId;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime timestamp;

  DiscordMessageEvent({
    required this.messageId,
    required this.channelId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'DiscordMessageEvent(messageId: $messageId, author: $authorName, content: $content)';
  }
}

/// Event representing a Discord connection state change
class DiscordConnectionEvent {
  final bool connected;
  final String? error;
  final DateTime timestamp;

  DiscordConnectionEvent({
    required this.connected,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'DiscordConnectionEvent(connected: $connected, error: $error)';
  }
}

/// Exception thrown by Discord service operations
class DiscordServiceException implements Exception {
  final String message;
  final dynamic originalError;

  DiscordServiceException(this.message, {this.originalError});

  @override
  String toString() {
    return 'DiscordServiceException: $message';
  }
}
