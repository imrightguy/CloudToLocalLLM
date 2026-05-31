import 'dart:convert';

import 'package:cloudtolocalllm/services/hermes_manager/main_chat_timeline_record.dart';

/// Authorization that is allowed to carry a sync envelope locally.
enum MainChatTimelineSyncAuthorizationKind {
  pairedDevice,
  userJwt,
}

/// Injectable signature signer used by tests and future transport code.
abstract class MainChatTimelineSyncSigner {
  Future<String> sign(String canonicalPayloadJson);
}

/// Injectable signature verifier used by tests and future transport code.
abstract class MainChatTimelineSyncVerifier {
  Future<bool> verify({
    required String canonicalPayloadJson,
    required String signature,
    required String publicKey,
  });
}

class MainChatTimelineSyncException implements Exception {
  final String message;

  const MainChatTimelineSyncException(this.message);

  @override
  String toString() => 'MainChatTimelineSyncException: $message';
}

class MainChatTimelineSyncAuthorization {
  final MainChatTimelineSyncAuthorizationKind kind;
  final String? deviceId;

  const MainChatTimelineSyncAuthorization._({
    required this.kind,
    required this.deviceId,
  });

  factory MainChatTimelineSyncAuthorization.pairedDevice({
    required String deviceId,
  }) {
    final normalized = deviceId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        deviceId,
        'deviceId',
        'paired device authorization requires a device id',
      );
    }
    return MainChatTimelineSyncAuthorization._(
      kind: MainChatTimelineSyncAuthorizationKind.pairedDevice,
      deviceId: normalized,
    );
  }

  factory MainChatTimelineSyncAuthorization.userJwt() {
    return const MainChatTimelineSyncAuthorization._(
      kind: MainChatTimelineSyncAuthorizationKind.userJwt,
      deviceId: null,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'kind': kind.name,
      if (deviceId != null) 'deviceId': deviceId,
    };
  }

  static MainChatTimelineSyncAuthorization fromJson(Map<String, Object?> json) {
    final kindValue = _stringValue(json['kind']);
    if (kindValue == null || kindValue.trim().isEmpty) {
      throw const MainChatTimelineSyncException(
        'transport authorization kind is required',
      );
    }
    final kind = _authorizationKindFromString(kindValue);
    if (kind == null) {
      throw MainChatTimelineSyncException(
        'unsupported transport authorization kind: $kindValue',
      );
    }
    return switch (kind) {
      MainChatTimelineSyncAuthorizationKind.pairedDevice =>
        MainChatTimelineSyncAuthorization.pairedDevice(
          deviceId: _stringValue(json['deviceId']) ?? '',
        ),
      MainChatTimelineSyncAuthorizationKind.userJwt =>
        throw const MainChatTimelineSyncException(
          'ordinary user JWT cannot authorize sync',
        ),
    };
  }
}

class MainChatTimelineSyncEnvelope {
  static const int currentEnvelopeVersion = 1;

  final int envelopeVersion;
  final String sourceDeviceId;
  final int sourceSequence;
  final DateTime createdAtUtc;
  final MainChatTimelineSyncAuthorization authorization;
  final List<MainChatTimelineRecord> records;
  final String signature;

  MainChatTimelineSyncEnvelope({
    required this.envelopeVersion,
    required this.sourceDeviceId,
    required this.sourceSequence,
    required this.createdAtUtc,
    required this.authorization,
    required List<MainChatTimelineRecord> records,
    required this.signature,
  }) : records = List<MainChatTimelineRecord>.unmodifiable(records);

  static Future<MainChatTimelineSyncEnvelope> buildFromRecords({
    required String sourceDeviceId,
    required int sourceSequence,
    required MainChatTimelineSyncAuthorization authorization,
    required Iterable<MainChatTimelineRecord> records,
    required MainChatTimelineSyncSigner signer,
    DateTime? createdAtUtc,
    int envelopeVersion = currentEnvelopeVersion,
  }) async {
    final normalizedSourceDeviceId = sourceDeviceId.trim();
    if (normalizedSourceDeviceId.isEmpty) {
      throw ArgumentError.value(
        sourceDeviceId,
        'sourceDeviceId',
        'sync envelopes require a source device id',
      );
    }
    if (authorization.kind != MainChatTimelineSyncAuthorizationKind.pairedDevice) {
      throw const MainChatTimelineSyncException(
        'paired device sync requires paired-device authorization',
      );
    }

    final normalizedRecords = _canonicalizeRecords(
      records,
      sourceDeviceId: normalizedSourceDeviceId,
    );
    final envelope = MainChatTimelineSyncEnvelope(
      envelopeVersion: envelopeVersion,
      sourceDeviceId: normalizedSourceDeviceId,
      sourceSequence: sourceSequence,
      createdAtUtc: (createdAtUtc ?? DateTime.now()).toUtc(),
      authorization: authorization,
      records: normalizedRecords,
      signature: '',
    );
    final signature = await signer.sign(envelope.canonicalPayloadJson());
    return envelope.copyWith(signature: signature);
  }

  factory MainChatTimelineSyncEnvelope.fromJson(Map<String, Object?> json) {
    final recordsJson = json['records'];
    final parsedRecords = <MainChatTimelineRecord>[];
    if (recordsJson is Iterable) {
      for (final entry in recordsJson) {
        if (entry is Map<String, Object?>) {
          parsedRecords.add(MainChatTimelineRecord.fromJson(entry));
        } else if (entry is Map) {
          final converted = <String, Object?>{};
          for (final mapEntry in entry.entries) {
            converted[mapEntry.key.toString()] = mapEntry.value;
          }
          parsedRecords.add(MainChatTimelineRecord.fromJson(converted));
        }
      }
    }

    final authorizationJson = json['authorization'];
    if (authorizationJson == null) {
      throw const MainChatTimelineSyncException(
        'transport authorization is required',
      );
    }
    final authorization = authorizationJson is Map<String, Object?>
        ? MainChatTimelineSyncAuthorization.fromJson(authorizationJson)
        : authorizationJson is Map
            ? MainChatTimelineSyncAuthorization.fromJson(
                authorizationJson.map<String, Object?>((key, value) {
                  return MapEntry<String, Object?>(key.toString(), value);
                }),
              )
            : throw const MainChatTimelineSyncException(
                'transport authorization must be an object',
              );

    return MainChatTimelineSyncEnvelope(
      envelopeVersion: _intValue(json['envelopeVersion']) ?? currentEnvelopeVersion,
      sourceDeviceId: _stringValue(json['sourceDeviceId']) ?? '',
      sourceSequence: _intValue(json['sourceSequence']) ?? 0,
      createdAtUtc: _dateTimeValue(json['createdAtUtc']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      authorization: authorization,
      records: parsedRecords,
      signature: _stringValue(json['signature']) ?? '',
    );
  }

  MainChatTimelineSyncEnvelope copyWith({
    int? envelopeVersion,
    String? sourceDeviceId,
    int? sourceSequence,
    DateTime? createdAtUtc,
    MainChatTimelineSyncAuthorization? authorization,
    List<MainChatTimelineRecord>? records,
    String? signature,
  }) {
    return MainChatTimelineSyncEnvelope(
      envelopeVersion: envelopeVersion ?? this.envelopeVersion,
      sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
      sourceSequence: sourceSequence ?? this.sourceSequence,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      authorization: authorization ?? this.authorization,
      records: records ?? this.records,
      signature: signature ?? this.signature,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'envelopeVersion': envelopeVersion,
      'sourceDeviceId': sourceDeviceId,
      'sourceSequence': sourceSequence,
      'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
      'authorization': authorization.toJson(),
      'records': _orderedRecords().map((record) => record.toSyncJson()).toList(growable: false),
      'signature': signature,
    };
  }

  String canonicalPayloadJson() {
    return _canonicalJsonEncode(_payloadJson());
  }

  String canonicalJson() {
    return _canonicalJsonEncode(toJson());
  }

  Map<String, Object?> _payloadJson() {
    return <String, Object?>{
      'envelopeVersion': envelopeVersion,
      'sourceDeviceId': sourceDeviceId,
      'sourceSequence': sourceSequence,
      'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
      'authorization': authorization.toJson(),
      'records': _orderedRecords().map((record) => record.toSyncJson()).toList(growable: false),
    };
  }

  List<MainChatTimelineRecord> _orderedRecords() {
    final ordered = records.toList(growable: false);
    ordered.sort((left, right) => left.recordId.compareTo(right.recordId));
    return ordered;
  }

  static List<MainChatTimelineRecord> _canonicalizeRecords(
    Iterable<MainChatTimelineRecord> records, {
    required String sourceDeviceId,
  }) {
    final normalized = <MainChatTimelineRecord>[];
    for (final record in records) {
      if (record.sourceDeviceId.trim() != sourceDeviceId) {
        throw MainChatTimelineSyncException(
          'sync envelope records must not claim another sourceDeviceId',
        );
      }
      normalized.add(record);
    }
    normalized.sort((left, right) => left.recordId.compareTo(right.recordId));
    return normalized;
  }
}

MainChatTimelineSyncAuthorizationKind? _authorizationKindFromString(String? value) {
  return switch (value) {
    'pairedDevice' => MainChatTimelineSyncAuthorizationKind.pairedDevice,
    'userJwt' => MainChatTimelineSyncAuthorizationKind.userJwt,
    _ => null,
  };
}

String _canonicalJsonEncode(Object? value) {
  if (value == null) {
    return 'null';
  }
  if (value is bool || value is num) {
    return jsonEncode(value);
  }
  if (value is String) {
    return jsonEncode(value);
  }
  if (value is DateTime) {
    return jsonEncode(value.toUtc().toIso8601String());
  }
  if (value is Enum) {
    return jsonEncode(value.name);
  }
  if (value is Map) {
    final entries = value.entries
        .map((entry) => MapEntry<String, Object?>(entry.key.toString(), entry.value))
        .toList(growable: false)
      ..sort((left, right) => left.key.compareTo(right.key));
    return '{${entries.map((entry) => '${jsonEncode(entry.key)}:${_canonicalJsonEncode(entry.value)}').join(',')}}';
  }
  if (value is Iterable) {
    return '[${value.map(_canonicalJsonEncode).join(',')}]';
  }
  return jsonEncode(value.toString());
}

String? _stringValue(Object? value) {
  if (value == null) {
    return null;
  }
  return value.toString();
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _dateTimeValue(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  final text = _stringValue(value);
  if (text == null || text.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(text)?.toUtc();
}
