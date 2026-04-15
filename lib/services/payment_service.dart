import 'dart:convert';

import '../models.dart';
import 'api_service.dart';
import 'cache_service.dart';

class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  static const int _cacheTtlSeconds = 120;

  Future<List<PaymentItem>> getPayments({
    String? buildingId,
    String? unitId,
    String? tenantId,
    String? status,
    bool forceRefresh = false,
  }) async {
    final parts = <String>[];
    if (buildingId != null) parts.add('buildingId=$buildingId');
    if (unitId != null) parts.add('unitId=$unitId');
    if (tenantId != null) parts.add('tenantId=$tenantId');
    if (status != null) parts.add('status=$status');

    final cacheKey = 'payments_${parts.join('_')}';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        return _parsePaymentsList(cached);
      }
    }

    final query =
        parts.isNotEmpty ? '?${parts.join('&')}' : '';
    final result = await ApiService.instance.get('/payments$query');
    final raw = jsonEncode(result['data']);
    CacheService.instance.set(cacheKey, raw, ttlSeconds: _cacheTtlSeconds);
    return _parsePaymentsList(raw);
  }

  List<PaymentItem> _parsePaymentsList(String raw) {
    final data = jsonDecode(raw);
    if (data is List) {
      return data
          .map((e) => PaymentItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [PaymentItem.fromJson(data as Map<String, dynamic>)];
  }

  Future<PaymentItem> getPayment(String id,
      {bool forceRefresh = false}) async {
    final cacheKey = 'payment_$id';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        return PaymentItem.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
    }

    final result = await ApiService.instance.get('/payments/$id');
    final raw = jsonEncode(result['data']);
    CacheService.instance.set(cacheKey, raw, ttlSeconds: _cacheTtlSeconds);
    return PaymentItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<PaymentItem> recordPayment(Map<String, dynamic> data) async {
    final result = await ApiService.instance.post('/payments', data);
    CacheService.instance.invalidateAll();
    return PaymentItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<PaymentItem> updatePayment(String id, Map<String, dynamic> data) async {
    final result = await ApiService.instance.patch('/payments/$id', data);
    CacheService.instance.invalidateAll();
    return PaymentItem.fromJson(result['data'] as Map<String, dynamic>);
  }
}
