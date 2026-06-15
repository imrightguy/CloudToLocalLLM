import 'api_service.dart';

/// API client for the customizable automatic-message templates used by the
/// PlexFlow webhooks (departure / arrival / lease SMS + vacant / occupied email).
class MessageTemplatesService {
  MessageTemplatesService._();
  static final MessageTemplatesService instance = MessageTemplatesService._();

  /// GET /message-templates — returns the full set (one per event type).
  Future<List<Map<String, dynamic>>> list() async {
    final result = await ApiService.instance.get('/message-templates');
    final data = result['data'] as List<dynamic>? ?? const [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  /// PUT /message-templates/:eventType — update a single template.
  Future<Map<String, dynamic>> update(
    String eventType, {
    String? body,
    String? subject,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (body != null) payload['body'] = body;
    if (subject != null) payload['subject'] = subject;
    if (isActive != null) payload['isActive'] = isActive;

    final result =
        await ApiService.instance.put('/message-templates/$eventType', payload);
    return (result['data'] as Map<String, dynamic>?) ?? const {};
  }
}
