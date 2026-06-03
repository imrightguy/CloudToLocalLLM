import 'dart:async';

import 'package:flutter/foundation.dart';

class VoiceConversationConfig {
  const VoiceConversationConfig({
    this.engagedHold = const Duration(seconds: 20),
    this.fastAckMaxWords = 18,
    this.minTranscriptWordsForReply = 2,
  });

  final Duration engagedHold;
  final int fastAckMaxWords;
  final int minTranscriptWordsForReply;
}

enum VoiceConversationMode {
  idle,
  listening,
  engaged,
  speaking,
  coolingDown,
}

class VoiceConversationSnapshot {
  const VoiceConversationSnapshot({
    required this.mode,
    required this.isEngaged,
    required this.engagedUntil,
    required this.lastUserTranscript,
    required this.lastAssistantReply,
    required this.liveBridgeConnected,
    required this.liveBridgeStatus,
    required this.transcriptInProgress,
  });

  final VoiceConversationMode mode;
  final bool isEngaged;
  final DateTime? engagedUntil;
  final String lastUserTranscript;
  final String lastAssistantReply;
  final bool liveBridgeConnected;
  final String liveBridgeStatus;
  final String transcriptInProgress;
}

class VoiceConversationService extends ChangeNotifier {
  VoiceConversationService({
    VoiceConversationConfig config = const VoiceConversationConfig(),
  }) : _config = config;

  final VoiceConversationConfig _config;

  VoiceConversationMode _mode = VoiceConversationMode.idle;
  DateTime? _engagedUntil;
  String _lastUserTranscript = '';
  String _lastAssistantReply = '';
  String _transcriptInProgress = '';
  bool _liveBridgeConnected = false;
  String _liveBridgeStatus = 'local demo only';
  Timer? _engagementTimer;

  VoiceConversationMode get mode => _mode;
  DateTime? get engagedUntil => _engagedUntil;
  String get lastUserTranscript => _lastUserTranscript;
  String get lastAssistantReply => _lastAssistantReply;
  bool get liveBridgeConnected => _liveBridgeConnected;
  String get liveBridgeStatus => _liveBridgeStatus;
  String get transcriptInProgress => _transcriptInProgress;
  bool get isEngaged =>
      _engagedUntil != null && DateTime.now().isBefore(_engagedUntil!);

  VoiceConversationSnapshot get snapshot => VoiceConversationSnapshot(
        mode: _mode,
        isEngaged: isEngaged,
        engagedUntil: _engagedUntil,
        lastUserTranscript: _lastUserTranscript,
        lastAssistantReply: _lastAssistantReply,
        liveBridgeConnected: _liveBridgeConnected,
        liveBridgeStatus: _liveBridgeStatus,
        transcriptInProgress: _transcriptInProgress,
      );

  void setListening() {
    _setMode(VoiceConversationMode.listening);
  }

  void setIdle() {
    _setMode(VoiceConversationMode.idle);
  }

  void noteWakePhrase(String transcript) {
    _lastUserTranscript = _clean(transcript);
    _extendConversationHold();
    _setMode(VoiceConversationMode.engaged);
  }

  bool shouldPreferConversationalPath(String transcript) {
    final cleaned = _clean(transcript);
    if (cleaned.isEmpty) {
      return false;
    }
    if (isEngaged) {
      return true;
    }
    return _looksDirectAddress(cleaned) || _hasEnoughWords(cleaned);
  }

  String? buildFastAcknowledgement(String transcript) {
    final cleaned = _clean(transcript).toLowerCase();
    if (cleaned.isEmpty) {
      return null;
    }

    if (_containsAny(cleaned, const [
      'are you hearing me',
      'can you hear me',
      'you there',
      'are you there',
      'respond',
    ])) {
      return 'Yeah, I hear you.';
    }

    if (_containsAny(cleaned, const [
      'zoidbot',
      'hermes',
      'hey bot',
      'hello bot',
    ])) {
      return 'Yeah? I’m here.';
    }

    if (_looksQuestion(cleaned) && _hasEnoughWords(cleaned)) {
      return 'Yeah, go on.';
    }

    return null;
  }

  void noteAssistantReply(String reply) {
    _lastAssistantReply = _truncate(reply);
    _extendConversationHold();
    _setMode(VoiceConversationMode.speaking);
  }

  void noteAssistantFinishedSpeaking() {
    if (isEngaged) {
      _setMode(VoiceConversationMode.engaged);
    } else {
      _setMode(VoiceConversationMode.idle);
    }
  }

  void noteUserTranscript(String transcript) {
    final cleaned = _clean(transcript);
    if (cleaned.isEmpty) {
      return;
    }
    _lastUserTranscript = cleaned;
    _extendConversationHold();
    _setMode(VoiceConversationMode.engaged);
  }

  /// Push an intermediate transcript (e.g. "Processing...") during an
  /// STT round-trip.  Does NOT change mode or extend the engagement hold.
  void noteTranscriptInProgress(String value) {
    _transcriptInProgress = value;
    notifyListeners();
  }

  void coolDown() {
    _setMode(VoiceConversationMode.coolingDown);
  }

  void applyExternalSnapshot({
    required VoiceConversationMode mode,
    required bool liveBridgeConnected,
    required String liveBridgeStatus,
    DateTime? engagedUntil,
    String? lastUserTranscript,
    String? lastAssistantReply,
  }) {
    _engagementTimer?.cancel();
    _engagementTimer = null;
    _mode = mode;
    _engagedUntil = engagedUntil;
    if (lastUserTranscript != null) {
      _lastUserTranscript = _truncate(lastUserTranscript);
    }
    if (lastAssistantReply != null) {
      _lastAssistantReply = _truncate(lastAssistantReply);
    }
    _liveBridgeConnected = liveBridgeConnected;
    _liveBridgeStatus = liveBridgeStatus;
    _transcriptInProgress = '';
    notifyListeners();
  }

  void reset() {
    _engagementTimer?.cancel();
    _engagementTimer = null;
    _engagedUntil = null;
    _lastUserTranscript = '';
    _lastAssistantReply = '';
    _transcriptInProgress = '';
    _liveBridgeConnected = false;
    _liveBridgeStatus = 'local demo only';
    _setMode(VoiceConversationMode.idle);
  }

  @override
  void dispose() {
    _engagementTimer?.cancel();
    super.dispose();
  }

  bool _looksDirectAddress(String cleaned) {
    return _containsAny(cleaned.toLowerCase(), const [
      'zoidbot',
      'hermes',
      'hey',
      'hello',
      'can you',
      'are you',
      'will you',
      'would you',
      'do you',
      'you ',
    ]);
  }

  bool _looksQuestion(String cleaned) {
    final lower = cleaned.toLowerCase();
    return lower.contains('?') ||
        _containsAny(lower, const ['what', 'why', 'how', 'when', 'where']);
  }

  bool _hasEnoughWords(String cleaned) {
    return cleaned
            .split(RegExp(r'\s+'))
            .where((part) => part.trim().isNotEmpty)
            .length >=
        _config.minTranscriptWordsForReply;
  }

  bool _containsAny(String input, List<String> phrases) {
    for (final phrase in phrases) {
      if (input.contains(phrase)) {
        return true;
      }
    }
    return false;
  }

  void _extendConversationHold() {
    _engagedUntil = DateTime.now().add(_config.engagedHold);
    _engagementTimer?.cancel();
    _engagementTimer = Timer(_config.engagedHold, () {
      _engagedUntil = null;
      if (_mode != VoiceConversationMode.speaking) {
        _setMode(VoiceConversationMode.idle);
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void _setMode(VoiceConversationMode next) {
    if (_mode == next) {
      notifyListeners();
      return;
    }
    _mode = next;
    notifyListeners();
  }

  String _clean(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _truncate(String text) {
    final cleaned = _clean(text);
    if (cleaned.length <= 220) {
      return cleaned;
    }
    return '${cleaned.substring(0, 217)}...';
  }
}
