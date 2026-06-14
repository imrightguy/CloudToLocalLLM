import 'api_service.dart';
import 'cache_service.dart';

/// Client for triggering Hermes qualification on the backend.
///
/// Hermes runs on the operator's MacBook Air and qualifies inbound leads.
/// The backend forwards the request to the configured Hermes webhook.
class HermesService {
  HermesService._();
  static final HermesService instance = HermesService._();

  /// POST /leads/:id/notify-hermes — ask Hermes to qualify the lead.
  ///
  /// Returns true when the backend reports the notification was delivered.
  Future<bool> notifyLead(String leadId) async {
    final result =
        await ApiService.instance.post('/leads/$leadId/notify-hermes', null);
    CacheService.instance.invalidate('lead*');
    final data = result['data'] as Map<String, dynamic>?;
    return (data?['hermesNotified'] as bool?) ?? false;
  }
}
