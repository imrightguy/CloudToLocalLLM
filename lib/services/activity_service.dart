import 'api_service.dart';

/// A single activity event from the recent-activity feed.
class ActivityEvent {
  const ActivityEvent({
    this.id,
    required this.type,
    required this.title,
    required this.detail,
    required this.timestamp,
    this.relatedId,
    this.relatedType,
  });

  final String? id;
  final String type;
  final String title;
  final String detail;
  final DateTime timestamp;

  /// ID of the related entity (e.g. lead ID, building ID).
  final String? relatedId;

  /// Type of related entity (e.g. 'lead', 'building', 'visit').
  final String? relatedType;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      id: json['id'] as String?,
      type: json['type'] as String? ?? 'info',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      relatedId: json['relatedId'] as String?,
      relatedType: json['relatedType'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'type': type,
        'title': title,
        'detail': detail,
        'timestamp': timestamp.toIso8601String(),
        if (relatedId != null) 'relatedId': relatedId,
        if (relatedType != null) 'relatedType': relatedType,
      };
}

/// Service for fetching recent activity / audit-log feed.
///
/// All methods throw [ApiException] on failure.
class ActivityService {
  ActivityService._();
  static final ActivityService instance = ActivityService._();

  /// GET /activity?limit=…
  ///
  /// Returns the most recent activity events, newest first.
  Future<List<ActivityEvent>> getRecentActivity({int limit = 20}) async {
    final query = 'limit=$limit';
    final result =
        await ApiService.instance.get('/communications/activity?$query');
    final data = result['data'];
    if (data is List) {
      return data
          .map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
