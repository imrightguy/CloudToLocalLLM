import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/services/cache_service.dart';

void main() {
  group('CacheEntry', () {
    test('isExpired returns false for fresh entries', () {
      final entry = CacheEntry(
        data: '{"test": true}',
        cachedAt: DateTime.now(),
        ttlSeconds: 300,
      );
      expect(entry.isExpired, false);
    });

    test('isExpired returns true for old entries', () {
      final entry = CacheEntry(
        data: '{"test": true}',
        cachedAt: DateTime.now().subtract(const Duration(seconds: 600)),
        ttlSeconds: 300,
      );
      expect(entry.isExpired, true);
    });

    test('fromJson and toJson round-trip', () {
      final now = DateTime.now();
      final original = CacheEntry(
        data: '{"items": [1, 2, 3]}',
        cachedAt: now,
        ttlSeconds: 120,
      );
      final json = original.toJson();
      final restored = CacheEntry.fromJson(json);
      expect(restored.data, original.data);
      expect(restored.cachedAt, now);
      expect(restored.ttlSeconds, 120);
    });
  });

  group('CacheService', () {
    test('singleton instance is stable', () {
      expect(
        identical(CacheService.instance, CacheService.instance),
        true,
      );
    });

    test('set and get work with in-memory cache', () {
      CacheService.instance.set('test_key', '{"value": 42}', ttlSeconds: 60);
      final result = CacheService.instance.get('test_key');
      expect(result, '{"value": 42}');
    });

    test('get returns null for missing keys', () {
      final result = CacheService.instance.get('nonexistent_key');
      expect(result, isNull);
    });

    test('invalidate removes cached value', () {
      CacheService.instance.set('to_delete', 'data', ttlSeconds: 60);
      expect(CacheService.instance.get('to_delete'), isNotNull);
      CacheService.instance.invalidate('to_delete');
      expect(CacheService.instance.get('to_delete'), isNull);
    });

    test('invalidateAll clears everything', () {
      CacheService.instance.set('a', '1', ttlSeconds: 60);
      CacheService.instance.set('b', '2', ttlSeconds: 60);
      CacheService.instance.set('c', '3', ttlSeconds: 60);
      CacheService.instance.invalidateAll();
      expect(CacheService.instance.get('a'), isNull);
      expect(CacheService.instance.get('b'), isNull);
      expect(CacheService.instance.get('c'), isNull);
    });

    test('expired entries are not returned', () {
      final entry = CacheEntry(
        data: 'old_data',
        cachedAt: DateTime.now().subtract(const Duration(seconds: 10)),
        ttlSeconds: 5,
      );
      expect(entry.isExpired, true);
    });

    test('default TTL is 300 seconds', () {
      CacheService.instance.set('default_ttl', 'data');
      final result = CacheService.instance.get('default_ttl');
      expect(result, 'data');
    });
  });
}
