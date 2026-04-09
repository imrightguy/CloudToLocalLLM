import 'api_service.dart';

/// Pipeline stage counts from the dashboard.
class PipelineData {
  const PipelineData({required this.stages});
  final Map<String, int> stages;

  factory PipelineData.fromJson(Map<String, dynamic> json) {
    final raw = json as Map<String, dynamic>? ?? {};
    return PipelineData(
      stages: raw.map((key, value) => MapEntry(key, (value as num).toInt())),
    );
  }
}

/// Weekly statistics summary.
class WeeklyStats {
  const WeeklyStats({
    required this.period,
    required this.periodStart,
    required this.newLeads,
    required this.visitsCompleted,
    required this.conversions,
    required this.noShows,
  });
  final String period;
  final DateTime periodStart;
  final int newLeads;
  final int visitsCompleted;
  final int conversions;
  final int noShows;

  factory WeeklyStats.fromJson(Map<String, dynamic> json) => WeeklyStats(
        period: json['period'] as String? ?? 'week',
        periodStart: json['periodStart'] != null
            ? DateTime.parse(json['periodStart'] as String)
            : DateTime.now(),
        newLeads: (json['newLeads'] as num?)?.toInt() ?? 0,
        visitsCompleted: (json['visitsCompleted'] as num?)?.toInt() ?? 0,
        conversions: (json['conversions'] as num?)?.toInt() ?? 0,
        noShows: (json['noShows'] as num?)?.toInt() ?? 0,
      );
}

/// Visit statistics.
class VisitStatsData {
  const VisitStatsData({
    required this.total,
    required this.completed,
    required this.cancelled,
    required this.noShow,
  });
  final int total;
  final int completed;
  final int cancelled;
  final int noShow;

  factory VisitStatsData.fromJson(Map<String, dynamic> json) => VisitStatsData(
        total: (json['total'] as num?)?.toInt() ?? 0,
        completed: (json['completed'] as num?)?.toInt() ?? 0,
        cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
        noShow: (json['noShow'] as num?)?.toInt() ?? 0,
      );
}

/// Conversion rate statistics.
class ConversionRates {
  const ConversionRates({
    required this.totalVisits,
    required this.converted,
    required this.conversionRate,
  });
  final int totalVisits;
  final int converted;
  final String conversionRate;

  factory ConversionRates.fromJson(Map<String, dynamic> json) =>
      ConversionRates(
        totalVisits: (json['totalVisits'] as num?)?.toInt() ?? 0,
        converted: (json['converted'] as num?)?.toInt() ?? 0,
        conversionRate: json['conversionRate'] as String? ?? '0%',
      );
}

/// Lead source distribution.
class LeadSource {
  const LeadSource({required this.source, required this.count});
  final String source;
  final int count;

  factory LeadSource.fromJson(Map<String, dynamic> json) => LeadSource(
        source: json['source'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

/// Full dashboard data from /analytics/dashboard.
class DashboardData {
  const DashboardData({
    required this.pipeline,
    required this.hotLeads,
    required this.weeklyStats,
    required this.visitStats,
    required this.conversionRates,
    required this.leadSources,
  });

  final PipelineData pipeline;
  final List<Map<String, dynamic>> hotLeads;
  final WeeklyStats weeklyStats;
  final VisitStatsData visitStats;
  final ConversionRates conversionRates;
  final List<LeadSource> leadSources;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final pipelineJson = json['pipeline'] as Map<String, dynamic>? ?? {};
    final hotLeadsJson = json['hotLeads'] as List<dynamic>? ?? [];
    final weeklyStatsJson = json['weeklyStats'] as Map<String, dynamic>? ?? {};
    final visitStatsJson = json['visitStats'] as Map<String, dynamic>? ?? {};
    final conversionRatesJson =
        json['conversionRates'] as Map<String, dynamic>? ?? {};
    final leadSourcesJson = json['leadSources'] as List<dynamic>? ?? [];

    return DashboardData(
      pipeline: PipelineData.fromJson(pipelineJson),
      hotLeads: hotLeadsJson.map((e) => e as Map<String, dynamic>).toList(),
      weeklyStats: WeeklyStats.fromJson(weeklyStatsJson),
      visitStats: VisitStatsData.fromJson(visitStatsJson),
      conversionRates: ConversionRates.fromJson(conversionRatesJson),
      leadSources: leadSourcesJson
          .map((e) => LeadSource.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Service for dashboard analytics and reporting.
///
/// All methods throw [ApiException] on failure.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  /// GET /analytics/dashboard
  ///
  /// Returns the full dashboard data including pipeline, visit stats,
  /// conversion rates, weekly stats, hot leads, and lead sources.
  Future<DashboardData> getDashboard() async {
    final result = await ApiService.instance.get('/analytics/dashboard');
    final data = result['data'] as Map<String, dynamic>;
    return DashboardData.fromJson(data);
  }
}
