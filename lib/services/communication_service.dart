import '../models.dart';
import 'api_service.dart';

/// Service for communication (SMS, email, call, note) CRUD and scheduling.
///
/// All methods throw [ApiException] on failure.
class CommunicationService {
  CommunicationService._();
  static final CommunicationService instance = CommunicationService._();

  /// GET /communications?type=...&status=...&search=...&page=...&limit=...
  Future<List<CommunicationItem>> getCommunications({
    String? type,
    String? status,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final result = await ApiService.instance.get('/communications?$query');

    final data = result['data'];
    if (data is List) {
      return data
          .map((e) => CommunicationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// GET /communications/activity?limit=...
  Future<List<CommunicationItem>> getActivity({int limit = 5}) async {
    final result =
        await ApiService.instance.get('/communications/activity?limit=$limit');
    final data = result['data'];
    if (data is List) {
      return data
          .map((e) => CommunicationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// GET /communications/logs?contactId=...&page=...&limit=...
  Future<List<CommunicationItem>> getConversationLogs({
    required String contactId,
    int page = 1,
    int limit = 50,
  }) async {
    final query = 'contactId=$contactId&page=$page&limit=$limit';
    final result =
        await ApiService.instance.get('/communications/logs?$query');
    final data = result['data'];
    if (data is List) {
      return data
          .map((e) => CommunicationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// POST /communications — log a new communication.
  Future<CommunicationItem> createCommunication(
      Map<String, dynamic> data) async {
    final result =
        await ApiService.instance.post('/communications', data);
    return CommunicationItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// POST /webhooks/sms/schedule — schedule an SMS.
  Future<Map<String, dynamic>> scheduleSms(SmsScheduleRequest request) async {
    final result =
        await ApiService.instance.post('/webhooks/sms/schedule', request.toJson());
    return result['data'] as Map<String, dynamic>? ?? {};
  }

  /// GET /sms/conversation/:contactId — get SMS thread for a contact.
  Future<List<SmsMessage>> getSmsConversation({
    required String contactId,
    int page = 1,
    int limit = 50,
  }) async {
    // Guard: an empty contactId would collapse the URL to
    // `/sms/conversation/?...` and return 404 (empty path segment).
    if (contactId.trim().isEmpty) {
      return [];
    }
    final query = 'page=$page&limit=$limit';
    final result = await ApiService.instance
        .get('/sms/conversation/$contactId?$query');
    final data = result['data'];
    if (data is List) {
      return data
          .map((e) => SmsMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// POST /sms/send — send an SMS immediately.
  Future<SmsMessage> sendSms({
    required String contactId,
    required String body,
  }) async {
    final result = await ApiService.instance.post('/sms/send', {
      'contactId': contactId,
      'body': body,
    });
    return SmsMessage.fromJson(result['data'] as Map<String, dynamic>);
  }
}
