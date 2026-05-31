import 'main_chat_timeline_sync_envelope.dart';

class MainChatTimelineTrustedDevice {
  final String deviceId;
  final String publicKey;
  final bool revoked;
  final int? lastAcceptedSequence;
  final Set<String> approvedScopes;

  MainChatTimelineTrustedDevice({
    required this.deviceId,
    required this.publicKey,
    this.revoked = false,
    this.lastAcceptedSequence,
    Set<String> approvedScopes = const <String>{},
  }) : approvedScopes = Set<String>.unmodifiable(approvedScopes);

  MainChatTimelineTrustedDevice copyWith({
    String? deviceId,
    String? publicKey,
    bool? revoked,
    int? lastAcceptedSequence,
    Set<String>? approvedScopes,
  }) {
    return MainChatTimelineTrustedDevice(
      deviceId: deviceId ?? this.deviceId,
      publicKey: publicKey ?? this.publicKey,
      revoked: revoked ?? this.revoked,
      lastAcceptedSequence: lastAcceptedSequence ?? this.lastAcceptedSequence,
      approvedScopes: approvedScopes ?? this.approvedScopes,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'deviceId': deviceId,
      'publicKey': publicKey,
      'revoked': revoked,
      if (lastAcceptedSequence != null) 'lastAcceptedSequence': lastAcceptedSequence,
      if (approvedScopes.isNotEmpty)
        'approvedScopes': approvedScopes.toList(growable: false),
    };
  }

  static MainChatTimelineTrustedDevice fromJson(Map<String, Object?> json) {
    return MainChatTimelineTrustedDevice(
      deviceId: _stringValue(json['deviceId']) ?? '',
      publicKey: _stringValue(json['publicKey']) ?? '',
      revoked: _boolValue(json['revoked']) ?? false,
      lastAcceptedSequence: _intValue(json['lastAcceptedSequence']),
      approvedScopes: _stringSetValue(json['approvedScopes']),
    );
  }
}

class MainChatTimelineTrustStore {
  final Map<String, MainChatTimelineTrustedDevice> _devices =
      <String, MainChatTimelineTrustedDevice>{};

  MainChatTimelineTrustStore({Iterable<MainChatTimelineTrustedDevice>? devices}) {
    for (final device in devices ?? const <MainChatTimelineTrustedDevice>[]) {
      _devices[device.deviceId] = device;
    }
  }

  Iterable<MainChatTimelineTrustedDevice> get devices {
    return List<MainChatTimelineTrustedDevice>.unmodifiable(_devices.values);
  }

  void trustDevice({
    required String deviceId,
    required String publicKey,
    int? lastAcceptedSequence,
    Iterable<String>? approvedScopes,
  }) {
    final normalizedDeviceId = deviceId.trim();
    if (normalizedDeviceId.isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId', 'device id cannot be empty');
    }
    final normalizedPublicKey = publicKey.trim();
    if (normalizedPublicKey.isEmpty) {
      throw ArgumentError.value(publicKey, 'publicKey', 'public key cannot be empty');
    }
    _devices[normalizedDeviceId] = MainChatTimelineTrustedDevice(
      deviceId: normalizedDeviceId,
      publicKey: normalizedPublicKey,
      revoked: false,
      lastAcceptedSequence: lastAcceptedSequence,
      approvedScopes: approvedScopes?.map((scope) => scope.trim()).where((scope) => scope.isNotEmpty).toSet() ??
          const <String>{},
    );
  }

  void revokeDevice(String deviceId) {
    final normalizedDeviceId = deviceId.trim();
    final existing = _devices[normalizedDeviceId];
    if (existing == null) {
      _devices[normalizedDeviceId] = MainChatTimelineTrustedDevice(
        deviceId: normalizedDeviceId,
        publicKey: '',
        revoked: true,
      );
      return;
    }
    _devices[normalizedDeviceId] = existing.copyWith(revoked: true);
  }

  bool isTrusted(String deviceId) {
    final device = _devices[deviceId.trim()];
    return device != null && !device.revoked;
  }

  bool isRevoked(String deviceId) {
    return _devices[deviceId.trim()]?.revoked ?? false;
  }

  int? lastAcceptedSequenceFor(String deviceId) {
    return _devices[deviceId.trim()]?.lastAcceptedSequence;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'devices': _devices.values.map((device) => device.toJson()).toList(growable: false),
    };
  }

  factory MainChatTimelineTrustStore.fromJson(Map<String, Object?> json) {
    final devicesJson = json['devices'];
    final devices = <MainChatTimelineTrustedDevice>[];
    if (devicesJson is Iterable) {
      for (final entry in devicesJson) {
        if (entry is Map<String, Object?>) {
          devices.add(MainChatTimelineTrustedDevice.fromJson(entry));
        } else if (entry is Map) {
          devices.add(
            MainChatTimelineTrustedDevice.fromJson(
              entry.map<String, Object?>((key, value) {
                return MapEntry<String, Object?>(key.toString(), value);
              }),
            ),
          );
        }
      }
    }
    return MainChatTimelineTrustStore(devices: devices);
  }

  Future<void> acceptEnvelope(
    MainChatTimelineSyncEnvelope envelope, {
    required MainChatTimelineSyncVerifier verifier,
  }) async {
    await validateEnvelope(envelope, verifier: verifier);
    final current = _devices[envelope.sourceDeviceId];
    if (current != null) {
      _devices[envelope.sourceDeviceId] = current.copyWith(
        lastAcceptedSequence: envelope.sourceSequence,
      );
    }
  }

  Future<void> validateEnvelope(
    MainChatTimelineSyncEnvelope envelope, {
    required MainChatTimelineSyncVerifier verifier,
  }) async {
    if (envelope.authorization.kind != MainChatTimelineSyncAuthorizationKind.pairedDevice) {
      throw const MainChatTimelineSyncException(
        'ordinary user JWT cannot authorize sync',
      );
    }

    final authorizationDeviceId = envelope.authorization.deviceId?.trim();
    if (authorizationDeviceId == null || authorizationDeviceId.isEmpty) {
      throw const MainChatTimelineSyncException(
        'paired device sync requires an authorization device id',
      );
    }
    if (authorizationDeviceId != envelope.sourceDeviceId.trim()) {
      throw const MainChatTimelineSyncException(
        'sync envelope claimed another sourceDeviceId',
      );
    }

    final trustedDevice = _devices[authorizationDeviceId];
    if (trustedDevice == null) {
      throw const MainChatTimelineSyncException('unknown device signature');
    }
    if (trustedDevice.revoked) {
      throw const MainChatTimelineSyncException('revoked device signature');
    }
    if (trustedDevice.publicKey.trim().isEmpty) {
      throw const MainChatTimelineSyncException('unknown device signature');
    }

    final lastAcceptedSequence = trustedDevice.lastAcceptedSequence;
    if (lastAcceptedSequence != null && envelope.sourceSequence <= lastAcceptedSequence) {
      throw const MainChatTimelineSyncException('replayed source sequence');
    }

    for (final record in envelope.records) {
      if (record.sourceDeviceId.trim() != envelope.sourceDeviceId.trim()) {
        throw const MainChatTimelineSyncException(
          'sync envelope records must not claim another sourceDeviceId',
        );
      }
    }

    final isValidSignature = await verifier.verify(
      canonicalPayloadJson: envelope.canonicalPayloadJson(),
      signature: envelope.signature,
      publicKey: trustedDevice.publicKey,
    );
    if (!isValidSignature) {
      throw const MainChatTimelineSyncException('tampered record payload');
    }
  }
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

Set<String> _stringSetValue(Object? value) {
  final result = <String>{};
  if (value is Iterable) {
    for (final entry in value) {
      final text = entry?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        result.add(text);
      }
    }
  }
  return result;
}

bool? _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  return null;
}
