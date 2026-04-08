import 'api_service.dart';

/// Dashboard and analytics data from the API.
class DashboardData {
  const DashboardData({
    required this.stats,
    required this.recentActivity,
    this.alerts = const [],
  });

  /// Key-value stat cards (e.g. occupation rate, monthly revenue).
  final List<Map<String, dynamic>> stats;

  /// Recent activity feed items.
  final List<Map<String, dynamic>> recentActivity;

  /// Active alerts / notifications.
  final List<Map<String, dynamic>> alerts;
}

/// Pipeline summary per stage.
class PipelineSummary {
  const PipelineSummary({
    required this.stages,
    required this.totalLeads,
  });

  /// Map of stage name → lead count.
  final Map<String, int> stages;

  final int totalLeads;
}

/// Visit statistics.
class VisitStats {
  const VisitStats({
    required this.total,
    required this.confirmed,
    required this.pending,
    required this.cancelled,
    required this.completed,
    required this.upcoming,
  });

  final int total;
  final int confirmed;
  final int pending;
  final int cancelled;
  final int completed;
  final int upcoming;
}

/// Service for dashboard analytics and reporting.
///
/// All methods throw [ApiException] on failure.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  /// GET /analytics/dashboard
  ///
  /// Returns dashboard stats, recent activity, and alerts.
  Future<DashboardData> getDashboard() async {
    final result = await ApiService.instance.get('/analytics/dashboard');
    final data = result['data'] as Map<String, dynamic>;

    return DashboardData(
      stats: (data['stats'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      recentActivity: (data['recentActivity'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      alerts: (data['alerts'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }

  /// GET /analytics/pipeline
  ///
  /// Returns a summary of leads grouped by pipeline stage.
  Future<PipelineSummary> getPipelineSummary() async {
    final result =
        await ApiService.instance.get('/analytics/pipeline');
    final data = result['data'] as Map<String, dynamic>;

    final stagesRaw = data['stages'] as Map<String, dynamic>? ?? {};
    final stages = stagesRaw.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );

    return PipelineSummary(
      stages: stages,
      totalLeads: (data['totalLeads'] as num?)?.toInt() ?? stages.values.fold(0, (a, b) => a + b),
    );
  }

  /// GET /analytics/visits?dateFrom=…&dateTo=…
  ///
  /// Returns visit statistics for a given date range.
  Future<VisitStats> getVisitStats({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final params = <String, String>{};
    if (dateFrom != null) {
      params['dateFrom'] = dateFrom.toIso8601String().split('T').first;
    }
    if (dateTo != null) {
      params['dateTo'] = dateTo.toIso8601String().split('T').first;
    }

    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';

    final result =
        await ApiService.instance.get('/analytics/visits$query');
    final data = result['data'] as Map<String, dynamic>;

    return VisitStats(
      total: (data['total'] as num?)?.toInt() ?? 0,
      confirmed: (data['confirmed'] as num?)?.toInt() ?? 0,
      pending: (data['pending'] as num?)?.toInt() ?? 0,
      cancelled: (data['cancelled'] as num?)?.toInt() ?? 0,
      completed: (data['completed'] as num?)?.toInt() ?? 0,
      upcoming: (data['upcoming'] as num?)?.toInt() ?? 0,
    );
  }

  /// GET /analytics/hot-leads
  ///
  /// Returns leads flagged as high-priority / hot.
  Future<List<Map<String, dynamic>>> getHotLeads() async {
    final result =
        await ApiService.instance.get('/analytics/hot-leads');
    final data = result['data'];
    if (data is List) {
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }
}
