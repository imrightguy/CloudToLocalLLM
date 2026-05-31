import 'dart:convert';

import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';

class MainChatTimelineSanitizer {
  static const int currentRedactionVersion = 1;

  static const Set<String> _allowedMetadataKeys = <String>{
    'status',
    'model',
    'attempts',
    'maxAttempts',
    'dedupKey',
    'notify',
    'wakeGate',
    'parentTaskId',
    'contextFrom',
    'exitCode',
    'isSilent',
  };

  static Map<String, Object?> sanitizeMetadata(Map<String, Object?> metadata) {
    final sanitized = <String, Object?>{};
    for (final entry in metadata.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || _isSecretLikeKey(key) || !_allowedMetadataKeys.contains(key)) {
        continue;
      }
      final value = _sanitizeValue(entry.value);
      if (value != null) {
        sanitized[key] = value;
      }
    }
    return Map<String, Object?>.unmodifiable(sanitized);
  }

  static String? sanitizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return _redactSecrets(trimmed);
  }

  static Object? _sanitizeValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final redacted = sanitizeText(value);
      return redacted;
    }
    if (value is num || value is bool) {
      return value;
    }
    if (value is Map<String, Object?>) {
      return Map<String, Object?>.unmodifiable(
        value.map((key, nestedValue) {
          return MapEntry<String, Object?>(key, _sanitizeValue(nestedValue));
        }),
      );
    }
    if (value is Map) {
      return Map<String, Object?>.unmodifiable(
        value.map<String, Object?>((key, nestedValue) {
          return MapEntry<String, Object?>(key.toString(), _sanitizeValue(nestedValue));
        }),
      );
    }
    if (value is Iterable) {
      return List<Object?>.unmodifiable(
        value.map<Object?>(_sanitizeValue),
      );
    }
    final redacted = sanitizeText(value.toString());
    return redacted ?? value.toString();
  }

  static bool isSecretLikeKey(String key) {
    final lower = key.toLowerCase();
    return lower.contains('token') ||
        lower.contains('password') ||
        lower.contains('api_key') ||
        lower.contains('secret') ||
        lower == 'authorization' ||
        lower == 'rawlog' ||
        lower == 'promptfile' ||
        lower == 'outputfile' ||
        lower == 'logfile' ||
        lower == 'metafile' ||
        lower == 'runnerfile';
  }

  static bool _isSecretLikeKey(String key) {
    return isSecretLikeKey(key);
  }

  static String _redactSecrets(String source) {
    var redacted = source.replaceAllMapped(
      RegExp(
        r'\b(api_key|token|password)(\s*[:=]\s*)([^\s]+)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}${match.group(2)}[REDACTED]',
    );
    redacted = redacted.replaceAllMapped(
      RegExp(r'\bBearer\s+\S+', caseSensitive: false),
      (_) => 'Bearer [REDACTED]',
    );
    return redacted;
  }
}

enum MainChatTimelineScope {
  conversation,
  global,
  device,
}

enum MainChatTimelineSourceKind {
  chat,
  localThink,
  tool,
  runtime,
  artifact,
  sync,
}

enum MainChatTimelineSyncPolicy {
  localOnly,
  privateSync,
  neverSync,
}

enum MainChatTimelineSensitivity {
  status,
  personal,
  secretAdjacent,
  localPath,
  raw,
}

class MainChatTimelineRecord {
  final String recordId;
  final String eventId;
  final int revision;
  final String sourceDeviceId;
  final int sourceSequence;
  final MainChatTimelineScope scope;
  final String? conversationId;
  final MainChatTimelineEventType eventType;
  final MainChatTimelineSourceKind sourceKind;
  final String? sourceId;
  final DateTime timestampUtc;
  final DateTime observedAtUtc;
  final String title;
  final String? summary;
  final String? bodyRedacted;
  final String? artifactName;
  final String? localArtifactPath;
  final Map<String, Object?> safeMetadata;
  final Map<String, Object?> localOnlyMetadata;
  final MainChatTimelineSyncPolicy syncPolicy;
  final MainChatTimelineSensitivity sensitivity;
  final int redactionVersion;
  final int payloadVersion;

  MainChatTimelineRecord({
    required this.recordId,
    required this.eventId,
    required this.revision,
    required this.sourceDeviceId,
    required this.sourceSequence,
    required this.scope,
    required this.conversationId,
    required this.eventType,
    required this.sourceKind,
    required this.sourceId,
    required this.timestampUtc,
    required this.observedAtUtc,
    required this.title,
    required this.summary,
    required this.bodyRedacted,
    required this.artifactName,
    required this.localArtifactPath,
    required Map<String, Object?> safeMetadata,
    required Map<String, Object?> localOnlyMetadata,
    required this.syncPolicy,
    required this.sensitivity,
    required this.redactionVersion,
    required this.payloadVersion,
  })  : safeMetadata = Map<String, Object?>.unmodifiable(safeMetadata),
        localOnlyMetadata = Map<String, Object?>.unmodifiable(localOnlyMetadata);

  factory MainChatTimelineRecord.fromTimelineEvent(
    MainChatTimelineEvent event, {
    required String sourceDeviceId,
    required int sourceSequence,
    required int revision,
    required MainChatTimelineScope scope,
    String? conversationId,
    MainChatTimelineSourceKind? sourceKind,
    DateTime? observedAtUtc,
    int redactionVersion = MainChatTimelineSanitizer.currentRedactionVersion,
    int payloadVersion = 1,
  }) {
    if (scope == MainChatTimelineScope.conversation &&
        (conversationId == null || conversationId.trim().isEmpty)) {
      throw ArgumentError.value(
        conversationId,
        'conversationId',
        'conversation-scoped records require a conversation id',
      );
    }

    final normalizedConversationId = conversationId?.trim();
    final timestampUtc =
        (event.timestamp ?? observedAtUtc ?? DateTime.now()).toUtc();
    final receiptUtc = (observedAtUtc ?? DateTime.now()).toUtc();
    final safeMetadata =
        MainChatTimelineSanitizer.sanitizeMetadata(event.metadata);
    final localOnlyMetadata = _localOnlyMetadataFor(event);
    final normalizedTitle = event.title.trim();
    final summary = MainChatTimelineSanitizer.sanitizeText(event.summary);
    final bodyRedacted = MainChatTimelineSanitizer.sanitizeText(event.body);
    final normalizedArtifactName = _basename(event.artifactPath);
    final normalizedSourceKind = sourceKind ?? _sourceKindForEventType(event.type);
    final normalizedSensitivity = _sensitivityForEvent(
      event,
      bodyRedacted: bodyRedacted,
      localArtifactPath: event.artifactPath,
    );
    final normalizedSyncPolicy = _syncPolicyForSensitivity(normalizedSensitivity);
    final normalizedEventId = event.id.trim();
    final normalizedRecordId = '$sourceDeviceId:$normalizedEventId:$revision';

    return MainChatTimelineRecord(
      recordId: normalizedRecordId,
      eventId: normalizedEventId,
      revision: revision,
      sourceDeviceId: sourceDeviceId,
      sourceSequence: sourceSequence,
      scope: scope,
      conversationId: normalizedConversationId,
      eventType: event.type,
      sourceKind: normalizedSourceKind,
      sourceId: _trimToNull(event.sourceId),
      timestampUtc: timestampUtc,
      observedAtUtc: receiptUtc,
      title: normalizedTitle,
      summary: summary,
      bodyRedacted: bodyRedacted,
      artifactName: normalizedArtifactName,
      localArtifactPath: event.artifactPath,
      safeMetadata: safeMetadata,
      localOnlyMetadata: localOnlyMetadata,
      syncPolicy: normalizedSyncPolicy,
      sensitivity: normalizedSensitivity,
      redactionVersion: redactionVersion,
      payloadVersion: payloadVersion,
    );
  }

  factory MainChatTimelineRecord.fromJson(Map<String, Object?> json) {
    return MainChatTimelineRecord(
      recordId: _stringValue(json['recordId']) ??
          _stringValue(json['record_id']) ??
          '',
      eventId: _stringValue(json['eventId']) ??
          _stringValue(json['event_id']) ??
          '',
      revision: _intValue(json['revision']) ?? 1,
      sourceDeviceId: _stringValue(json['sourceDeviceId']) ??
          _stringValue(json['source_device_id']) ??
          '',
      sourceSequence: _intValue(json['sourceSequence']) ??
          _intValue(json['source_sequence']) ??
          0,
      scope: _scopeFromString(_stringValue(json['scope'])) ??
          MainChatTimelineScope.global,
      conversationId: _stringValue(json['conversationId']) ??
          _stringValue(json['conversation_id']),
      eventType: _eventTypeFromString(_stringValue(json['eventType'])) ??
          MainChatTimelineEventType.chatSystem,
      sourceKind: _sourceKindFromString(_stringValue(json['sourceKind'])) ??
          MainChatTimelineSourceKind.chat,
      sourceId: _stringValue(json['sourceId']) ?? _stringValue(json['source_id']),
      timestampUtc: _dateTimeValue(json['timestampUtc']) ??
          _dateTimeValue(json['timestamp_utc']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      observedAtUtc: _dateTimeValue(json['observedAtUtc']) ??
          _dateTimeValue(json['observed_at_utc']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      title: _stringValue(json['title']) ?? '',
      summary: _stringValue(json['summary']),
      bodyRedacted: _stringValue(json['bodyRedacted']) ??
          _stringValue(json['body_redacted']),
      artifactName: _stringValue(json['artifactName']) ??
          _stringValue(json['artifact_name']),
      localArtifactPath: _stringValue(json['localArtifactPath']) ??
          _stringValue(json['local_artifact_path']),
      safeMetadata: _mapValue(json['safeMetadata']) ??
          _mapValue(json['safe_metadata']) ??
          const <String, Object?>{},
      localOnlyMetadata: _mapValue(json['localOnlyMetadata']) ??
          _mapValue(json['local_only_metadata']) ??
          const <String, Object?>{},
      syncPolicy: _syncPolicyFromString(_stringValue(json['syncPolicy'])) ??
          MainChatTimelineSyncPolicy.privateSync,
      sensitivity: _sensitivityFromString(_stringValue(json['sensitivity'])) ??
          MainChatTimelineSensitivity.status,
      redactionVersion: _intValue(json['redactionVersion']) ??
          _intValue(json['redaction_version']) ??
          MainChatTimelineSanitizer.currentRedactionVersion,
      payloadVersion: _intValue(json['payloadVersion']) ??
          _intValue(json['payload_version']) ??
          1,
    );
  }

  Map<String, Object?> toLocalJson() {
    return <String, Object?>{
      'recordId': recordId,
      'eventId': eventId,
      'revision': revision,
      'sourceDeviceId': sourceDeviceId,
      'sourceSequence': sourceSequence,
      'scope': scope.name,
      if (conversationId != null) 'conversationId': conversationId,
      'eventType': eventType.name,
      'sourceKind': sourceKind.name,
      if (sourceId != null) 'sourceId': sourceId,
      'timestampUtc': timestampUtc.toUtc().toIso8601String(),
      'observedAtUtc': observedAtUtc.toUtc().toIso8601String(),
      'title': title,
      if (summary != null) 'summary': summary,
      if (bodyRedacted != null) 'bodyRedacted': bodyRedacted,
      if (artifactName != null) 'artifactName': artifactName,
      if (localArtifactPath != null) 'localArtifactPath': localArtifactPath,
      'safeMetadata': safeMetadata,
      'localOnlyMetadata': localOnlyMetadata,
      'syncPolicy': syncPolicy.name,
      'sensitivity': sensitivity.name,
      'redactionVersion': redactionVersion,
      'payloadVersion': payloadVersion,
    };
  }

  Map<String, Object?> toSyncJson() {
    return <String, Object?>{
      'recordId': recordId,
      'eventId': eventId,
      'revision': revision,
      'sourceDeviceId': sourceDeviceId,
      'sourceSequence': sourceSequence,
      'scope': scope.name,
      if (conversationId != null) 'conversationId': conversationId,
      'eventType': eventType.name,
      'sourceKind': sourceKind.name,
      if (sourceId != null) 'sourceId': sourceId,
      'timestampUtc': timestampUtc.toUtc().toIso8601String(),
      'observedAtUtc': observedAtUtc.toUtc().toIso8601String(),
      'title': title,
      if (summary != null) 'summary': summary,
      if (bodyRedacted != null) 'bodyRedacted': bodyRedacted,
      if (artifactName != null) 'artifactName': artifactName,
      'safeMetadata': safeMetadata,
      'syncPolicy': syncPolicy.name,
      'sensitivity': sensitivity.name,
      'redactionVersion': redactionVersion,
      'payloadVersion': payloadVersion,
    };
  }

  MainChatTimelineEvent toTimelineEvent() {
    final verboseBody = bodyRedacted;
    return MainChatTimelineEvent(
      id: eventId,
      type: eventType,
      title: title,
      summary: summary,
      body: bodyRedacted,
      timestamp: timestampUtc,
      sourceId: sourceId,
      artifactPath: localArtifactPath,
      isVerbose: verboseBody != null &&
          verboseBody.trim().isNotEmpty &&
          verboseBody != summary,
      isExpandable: bodyRedacted != null || safeMetadata.isNotEmpty,
      metadata: safeMetadata,
    );
  }

  MainChatTimelineRecord copyWith({
    String? bodyRedacted,
  }) {
    return MainChatTimelineRecord(
      recordId: recordId,
      eventId: eventId,
      revision: revision,
      sourceDeviceId: sourceDeviceId,
      sourceSequence: sourceSequence,
      scope: scope,
      conversationId: conversationId,
      eventType: eventType,
      sourceKind: sourceKind,
      sourceId: sourceId,
      timestampUtc: timestampUtc,
      observedAtUtc: observedAtUtc,
      title: title,
      summary: summary,
      bodyRedacted: bodyRedacted ?? this.bodyRedacted,
      artifactName: artifactName,
      localArtifactPath: localArtifactPath,
      safeMetadata: safeMetadata,
      localOnlyMetadata: localOnlyMetadata,
      syncPolicy: syncPolicy,
      sensitivity: sensitivity,
      redactionVersion: redactionVersion,
      payloadVersion: payloadVersion,
    );
  }

  static MainChatTimelineSourceKind _sourceKindForEventType(
    MainChatTimelineEventType type,
  ) {
    return switch (type) {
      MainChatTimelineEventType.chatUser ||
      MainChatTimelineEventType.chatAssistant ||
      MainChatTimelineEventType.chatSystem =>
        MainChatTimelineSourceKind.chat,
      MainChatTimelineEventType.localThinkQueued ||
      MainChatTimelineEventType.localThinkRunning ||
      MainChatTimelineEventType.localThinkCompleted ||
      MainChatTimelineEventType.localThinkCancelled ||
      MainChatTimelineEventType.localThinkFailed ||
      MainChatTimelineEventType.localThinkSkipped =>
        MainChatTimelineSourceKind.localThink,
      MainChatTimelineEventType.toolStarted ||
      MainChatTimelineEventType.toolFinished =>
        MainChatTimelineSourceKind.tool,
      MainChatTimelineEventType.restartRecovered =>
        MainChatTimelineSourceKind.runtime,
      MainChatTimelineEventType.artifactCreated =>
        MainChatTimelineSourceKind.artifact,
    };
  }

  static MainChatTimelineSensitivity _sensitivityForEvent(
    MainChatTimelineEvent event, {
    required String? bodyRedacted,
    required String? localArtifactPath,
  }) {
    if (localArtifactPath != null && localArtifactPath.trim().isNotEmpty) {
      return MainChatTimelineSensitivity.localPath;
    }
    if (event.type == MainChatTimelineEventType.chatUser ||
        event.type == MainChatTimelineEventType.chatAssistant) {
      return bodyRedacted == null
          ? MainChatTimelineSensitivity.status
          : MainChatTimelineSensitivity.personal;
    }
    if (bodyRedacted != null && bodyRedacted.trim().isNotEmpty) {
      return MainChatTimelineSensitivity.personal;
    }
    return MainChatTimelineSensitivity.status;
  }

  static MainChatTimelineSyncPolicy _syncPolicyForSensitivity(
    MainChatTimelineSensitivity sensitivity,
  ) {
    return switch (sensitivity) {
      MainChatTimelineSensitivity.localPath => MainChatTimelineSyncPolicy.localOnly,
      MainChatTimelineSensitivity.raw => MainChatTimelineSyncPolicy.localOnly,
      MainChatTimelineSensitivity.personal => MainChatTimelineSyncPolicy.privateSync,
      MainChatTimelineSensitivity.secretAdjacent => MainChatTimelineSyncPolicy.privateSync,
      MainChatTimelineSensitivity.status => MainChatTimelineSyncPolicy.privateSync,
    };
  }

  static Map<String, Object?> _localOnlyMetadataFor(MainChatTimelineEvent event) {
    final localOnly = <String, Object?>{};
    final artifactPath = event.artifactPath?.trim();
    if (artifactPath != null && artifactPath.isNotEmpty) {
      localOnly['artifactPath'] = artifactPath;
    }

    for (final entry in event.metadata.entries) {
      final key = entry.key.trim();
      final lower = key.toLowerCase();
      if (key.isEmpty || MainChatTimelineSanitizer.isSecretLikeKey(key)) {
        continue;
      }
      if (lower == 'finalfile' ||
          lower == 'logfile' ||
          lower == 'outputfile' ||
          lower == 'metafile' ||
          lower == 'runnerfile') {
        final value = entry.value;
        if (value is String && value.trim().isNotEmpty) {
          localOnly[key] = value.trim();
        }
      }
    }

    return Map<String, Object?>.unmodifiable(localOnly);
  }

  static String? _basename(String? path) {
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final normalized = trimmed.replaceAll('\\', '/');
    final segments = normalized.split('/');
    final name = segments.isEmpty ? normalized : segments.last;
    return name.trim().isEmpty ? null : name.trim();
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static String? _stringValue(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static DateTime? _dateTimeValue(Object? value) {
    final text = _stringValue(value);
    if (text == null) {
      return null;
    }
    return DateTime.tryParse(text)?.toUtc();
  }

  static Map<String, Object?>? _mapValue(Object? value) {
    if (value is Map<String, Object?>) {
      return Map<String, Object?>.unmodifiable(value);
    }
    if (value is Map) {
      final converted = <String, Object?>{};
      for (final entry in value.entries) {
        converted[entry.key.toString()] = entry.value;
      }
      return Map<String, Object?>.unmodifiable(converted);
    }
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        final converted = <String, Object?>{};
        for (final entry in decoded.entries) {
          converted[entry.key.toString()] = entry.value;
        }
        return Map<String, Object?>.unmodifiable(converted);
      }
    }
    return null;
  }

  static MainChatTimelineScope? _scopeFromString(String? value) {
    return switch (value) {
      'conversation' => MainChatTimelineScope.conversation,
      'global' => MainChatTimelineScope.global,
      'device' => MainChatTimelineScope.device,
      _ => null,
    };
  }

  static MainChatTimelineSourceKind? _sourceKindFromString(String? value) {
    return switch (value) {
      'chat' => MainChatTimelineSourceKind.chat,
      'localThink' => MainChatTimelineSourceKind.localThink,
      'tool' => MainChatTimelineSourceKind.tool,
      'runtime' => MainChatTimelineSourceKind.runtime,
      'artifact' => MainChatTimelineSourceKind.artifact,
      'sync' => MainChatTimelineSourceKind.sync,
      _ => null,
    };
  }

  static MainChatTimelineSyncPolicy? _syncPolicyFromString(String? value) {
    return switch (value) {
      'localOnly' => MainChatTimelineSyncPolicy.localOnly,
      'privateSync' => MainChatTimelineSyncPolicy.privateSync,
      'neverSync' => MainChatTimelineSyncPolicy.neverSync,
      _ => null,
    };
  }

  static MainChatTimelineSensitivity? _sensitivityFromString(String? value) {
    return switch (value) {
      'status' => MainChatTimelineSensitivity.status,
      'personal' => MainChatTimelineSensitivity.personal,
      'secretAdjacent' => MainChatTimelineSensitivity.secretAdjacent,
      'localPath' => MainChatTimelineSensitivity.localPath,
      'raw' => MainChatTimelineSensitivity.raw,
      _ => null,
    };
  }

  static MainChatTimelineEventType? _eventTypeFromString(String? value) {
    return switch (value) {
      'chatUser' => MainChatTimelineEventType.chatUser,
      'chatAssistant' => MainChatTimelineEventType.chatAssistant,
      'chatSystem' => MainChatTimelineEventType.chatSystem,
      'localThinkQueued' => MainChatTimelineEventType.localThinkQueued,
      'localThinkRunning' => MainChatTimelineEventType.localThinkRunning,
      'localThinkCompleted' => MainChatTimelineEventType.localThinkCompleted,
      'localThinkCancelled' => MainChatTimelineEventType.localThinkCancelled,
      'localThinkFailed' => MainChatTimelineEventType.localThinkFailed,
      'localThinkSkipped' => MainChatTimelineEventType.localThinkSkipped,
      'toolStarted' => MainChatTimelineEventType.toolStarted,
      'toolFinished' => MainChatTimelineEventType.toolFinished,
      'restartRecovered' => MainChatTimelineEventType.restartRecovered,
      'artifactCreated' => MainChatTimelineEventType.artifactCreated,
      _ => null,
    };
  }
}
