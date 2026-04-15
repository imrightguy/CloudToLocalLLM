import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheEntry {
  const CacheEntry({
    required this.data,
    required this.cachedAt,
    required this.ttlSeconds,
  });

  final String data;
  final DateTime cachedAt;
  final int ttlSeconds;

  bool get isExpired =>
      DateTime.now().difference(cachedAt).inSeconds > ttlSeconds;

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      data: json['data'] as String,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      ttlSeconds: json['ttlSeconds'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'data': data,
        'cachedAt': cachedAt.toIso8601String(),
        'ttlSeconds': ttlSeconds,
      };
}

/// In-memory + SharedPreferences cache with TTL support.
///
/// Usage:
/// ```dart
/// final cache = await CacheService.instance.init();
/// cache.set('buildings', jsonEncode(data), ttlSeconds: 300);
/// final cached = cache.get('buildings');
/// cache.invalidate('buildings');
/// ```
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  SharedPreferences? _prefs;
  final Map<String, CacheEntry> _memory = {};
  static const String _prefix = 'cache_';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  void set(String key, String data, {int ttlSeconds = 300}) {
    final entry = CacheEntry(
      data: data,
      cachedAt: DateTime.now(),
      ttlSeconds: ttlSeconds,
    );
    _memory[key] = entry;
    _prefs?.setString('$_prefix$key', jsonEncode(entry.toJson()));
  }

  String? get(String key) {
    final memEntry = _memory[key];
    if (memEntry != null && !memEntry.isExpired) {
      return memEntry.data;
    }
    if (memEntry != null && memEntry.isExpired) {
      _memory.remove(key);
    }

    final raw = _prefs?.getString('$_prefix$key');
    if (raw == null) return null;

    try {
      final entry = CacheEntry.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (entry.isExpired) {
        _prefs?.remove('$_prefix$key');
        return null;
      }
      _memory[key] = entry;
      return entry.data;
    } catch (_) {
      return null;
    }
  }

  void invalidate(String key) {
    _memory.remove(key);
    _prefs?.remove('$_prefix$key');
  }

  void invalidateAll() {
    for (final key in _memory.keys.toList()) {
      _prefs?.remove('$_prefix$key');
    }
    _memory.clear();
  }
}
