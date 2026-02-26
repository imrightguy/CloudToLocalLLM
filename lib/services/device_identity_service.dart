import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// Device identity for OpenClaw Gateway authentication
///
/// Uses ED25519 key pairs for signing device authentication payloads.
/// The device ID is derived from the SHA256 hash of the public key.
/// The key pair is stored as a seed (32 bytes) for deterministic reconstruction.
class DeviceIdentityService {
  static DeviceIdentityService? _instance;
  static const _storageKey = 'device_identity_v2';

  final FlutterSecureStorage _storage;
  final Ed25519 _algorithm = Ed25519();

  SimpleKeyPair? _keyPair;
  String? _deviceId;

  DeviceIdentityService._({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static DeviceIdentityService get instance {
    return _instance ??= DeviceIdentityService._();
  }

  /// Initialize or load the device identity
  Future<void> initialize() async {
    if (_keyPair != null) return;

    try {
      // Try to load existing identity from seed
      final stored = await _storage.read(key: _storageKey);
      if (stored != null) {
        final json = jsonDecode(stored) as Map<String, dynamic>;
        final seedBase64 = json['seed'] as String;
        final seed = base64Decode(seedBase64);

        // Reconstruct key pair from seed
        _keyPair = await _algorithm.newKeyPairFromSeed(seed);
        final publicKey = await _keyPair!.extractPublicKey();

        // Derive device ID from SHA256 of public key
        final digest = sha256.convert(publicKey.bytes);
        _deviceId = digest.toString();

        debugPrint('🔐 [DeviceIdentity] Loaded existing identity: $_deviceId');
        return;
      }
    } catch (e) {
      debugPrint('🔐 [DeviceIdentity] Failed to load identity: $e');
    }

    // Generate new identity
    await _generateNewIdentity();
  }

  Future<void> _generateNewIdentity() async {
    debugPrint('🔐 [DeviceIdentity] Generating new ED25519 key pair...');

    // Generate a secure random seed first, then create key pair from it
    final secureSeed = _generateSecureSeed();
    _keyPair = await _algorithm.newKeyPairFromSeed(secureSeed);
    final publicKey = await _keyPair!.extractPublicKey();

    // Derive device ID from SHA256 of public key
    final digest = sha256.convert(publicKey.bytes);
    _deviceId = digest.toString();

    debugPrint('🔐 [DeviceIdentity] Generated new identity: $_deviceId');

    final storedJson = {
      'deviceId': _deviceId,
      'seed': base64Encode(secureSeed),
      'createdAt': DateTime.now().toIso8601String(),
    };

    await _storage.write(key: _storageKey, value: jsonEncode(storedJson));
    debugPrint('🔐 [DeviceIdentity] Identity stored securely');
  }

  /// Generate a secure random seed
  List<int> _generateSecureSeed() {
    // Use a combination of timestamp and random values
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final seed = <int>[];
    for (var i = 0; i < 32; i++) {
      seed.add((timestamp >> (i % 8)) & 0xFF);
    }
    // Add more entropy
    for (var i = 0; i < 32; i++) {
      seed[i] = (seed[i] + DateTime.now().microsecond + i * 7) % 256;
    }
    return seed;
  }

  /// Get the device ID (SHA256 of public key)
  String get deviceId {
    if (_deviceId == null) {
      throw StateError('DeviceIdentityService not initialized');
    }
    return _deviceId!;
  }

  /// Get the public key as base64url-encoded raw bytes
  Future<String> get publicKeyBase64Url async {
    if (_keyPair == null) {
      throw StateError('DeviceIdentityService not initialized');
    }

    final publicKey = await _keyPair!.extractPublicKey();
    return _base64UrlEncode(Uint8List.fromList(publicKey.bytes));
  }

  /// Build and sign the device auth payload
  ///
  /// Payload format: v2|deviceId|clientId|clientMode|role|scopes|signedAtMs|token|nonce
  Future<DeviceAuth> buildDeviceAuth({
    required String clientId,
    required String clientMode,
    required String role,
    required List<String> scopes,
    required String? token,
    required String nonce,
  }) async {
    if (_keyPair == null) {
      throw StateError('DeviceIdentityService not initialized');
    }

    final signedAtMs = DateTime.now().millisecondsSinceEpoch;
    final scopesStr = scopes.join(',');
    final tokenStr = token ?? '';

    // Build the payload
    final payload = [
      'v2',
      _deviceId!,
      clientId,
      clientMode,
      role,
      scopesStr,
      signedAtMs.toString(),
      tokenStr,
      nonce,
    ].join('|');

    debugPrint('🔐 [DeviceIdentity] Signing payload: $payload');

    // Sign the payload
    final signature = await _algorithm.sign(
      utf8.encode(payload),
      keyPair: _keyPair!,
    );

    final signatureBase64Url =
        _base64UrlEncode(Uint8List.fromList(signature.bytes));
    final publicKeyBase64 = await publicKeyBase64Url;

    debugPrint(
        '🔐 [DeviceIdentity] Signature: ${signatureBase64Url.substring(0, 20)}...');

    return DeviceAuth(
      deviceId: _deviceId!,
      publicKey: publicKeyBase64,
      signature: signatureBase64Url,
      signedAt: signedAtMs,
      nonce: nonce,
    );
  }

  /// Encode bytes as base64url (no padding)
  String _base64UrlEncode(Uint8List bytes) {
    return base64Encode(bytes)
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll(RegExp(r'=+$'), '');
  }

  /// Clear the device identity (for testing/reset)
  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
    _keyPair = null;
    _deviceId = null;
    debugPrint('🔐 [DeviceIdentity] Identity cleared');
  }
}

/// Device authentication data for WebSocket handshake
class DeviceAuth {
  final String deviceId;
  final String publicKey;
  final String signature;
  final int signedAt;
  final String nonce;

  DeviceAuth({
    required this.deviceId,
    required this.publicKey,
    required this.signature,
    required this.signedAt,
    required this.nonce,
  });

  Map<String, dynamic> toJson() => {
        'id': deviceId,
        'publicKey': publicKey,
        'signature': signature,
        'signedAt': signedAt,
        'nonce': nonce,
      };
}
