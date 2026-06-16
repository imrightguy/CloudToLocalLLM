import '../models.dart';
import 'api_service.dart';

/// Aggregated notifications data from 4 API endpoints.
class NotificationsData {
  final List<CommunicationItem> recentActivity;
  final List<MaintenanceTaskItem> openTickets;
  final List<VisitItem> upcomingVisits;
  final List<Map<String, dynamic>> latePayments;

  const NotificationsData({
    required this.recentActivity,
    required this.openTickets,
    required this.upcomingVisits,
    required this.latePayments,
  });
}

/// Service for the Notifications Center.
class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  /// Fetch all 4 notification sources in parallel.
  Future<NotificationsData> fetchAll() async {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));

    final results = await Future.wait([
      ApiService.instance.get('/communications?limit=20'),
      ApiService.instance.get('/maintenance'),
      ApiService.instance.get(
        '/visits?dateFrom=${now.toIso8601String().split('T').first}'
        '&dateTo=${weekFromNow.toIso8601String().split('T').first}&limit=50'),
      ApiService.instance.get('/payments/late'),
    ]);

    return NotificationsData(
      recentActivity: _parseList(results[0], CommunicationItem.fromJson),
      openTickets: _parseList(results[1], MaintenanceTaskItem.fromJson),
      upcomingVisits: _parseList(results[2], VisitItem.fromJson),
      latePayments: _parseRawList(results[3]),
    );
  }

  List<T> _parseList<T>(
    dynamic result,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final data = result['data'];
    if (data is List) {
      return data
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _parseRawList(dynamic result) {
    final data = result['data'];
    if (data is List) {
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }
}
