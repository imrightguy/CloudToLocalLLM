import 'dart:convert';

import 'api_service.dart';
import 'cache_service.dart';

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

class LeadSource {
  const LeadSource({required this.source, required this.count});
  final String source;
  final int count;

  factory LeadSource.fromJson(Map<String, dynamic> json) => LeadSource(
        source: json['source'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

class KpiMetric {
  const KpiMetric({
    required this.current,
    required this.previous,
    required this.trend,
  });

  final num current;
  final num previous;
  final double trend;

  factory KpiMetric.fromJson(Map<String, dynamic> json) => KpiMetric(
        current: json['current'] as num? ?? 0,
        previous: json['previous'] as num? ?? 0,
        trend: (json['trend'] as num?)?.toDouble() ?? 0.0,
      );
}

class KpiSummary {
  const KpiSummary({
    required this.revenue,
    required this.occupancyRate,
    required this.activeLeases,
    required this.openLeads,
  });

  final KpiMetric revenue;
  final KpiMetric occupancyRate;
  final KpiMetric activeLeases;
  final KpiMetric openLeads;

  factory KpiSummary.fromJson(Map<String, dynamic> json) => KpiSummary(
        revenue: KpiMetric.fromJson(
            (json['revenue'] as Map<String, dynamic>?) ?? {}),
        occupancyRate: KpiMetric.fromJson(
            (json['occupancyRate'] as Map<String, dynamic>?) ?? {}),
        activeLeases: KpiMetric.fromJson(
            (json['activeLeases'] as Map<String, dynamic>?) ?? {}),
        openLeads: KpiMetric.fromJson(
            (json['openLeads'] as Map<String, dynamic>?) ?? {}),
      );
}

class FullDashboardData {
  const FullDashboardData({
    required this.pipeline,
    required this.hotLeads,
    required this.weeklyStats,
    required this.visitStats,
    required this.conversionRates,
    required this.leadSources,
    this.kpi,
    this.revenueChart,
    this.occupancyChart,
    this.leadFunnel,
    this.buildings,
  });

  final PipelineData pipeline;
  final List<Map<String, dynamic>> hotLeads;
  final WeeklyStats weeklyStats;
  final VisitStatsData visitStats;
  final ConversionRates conversionRates;
  final List<LeadSource> leadSources;
  final KpiSummary? kpi;
  final List<Map<String, dynamic>>? revenueChart;
  final List<Map<String, dynamic>>? occupancyChart;
  final Map<String, int>? leadFunnel;
  final List<Map<String, dynamic>>? buildings;

  factory FullDashboardData.fromJson(Map<String, dynamic> json) {
    final pipelineJson = json['pipeline'] as Map<String, dynamic>? ?? {};
    final hotLeadsJson = json['hotLeads'] as List<dynamic>? ?? [];
    final weeklyStatsJson = json['weeklyStats'] as Map<String, dynamic>? ?? {};
    final visitStatsJson = json['visitStats'] as Map<String, dynamic>? ?? {};
    final conversionRatesJson =
        json['conversionRates'] as Map<String, dynamic>? ?? {};
    final leadSourcesJson = json['leadSources'] as List<dynamic>? ?? [];

    return FullDashboardData(
      pipeline: PipelineData.fromJson(pipelineJson),
      hotLeads: hotLeadsJson.map((e) => e as Map<String, dynamic>).toList(),
      weeklyStats: WeeklyStats.fromJson(weeklyStatsJson),
      visitStats: VisitStatsData.fromJson(visitStatsJson),
      conversionRates: ConversionRates.fromJson(conversionRatesJson),
      leadSources: leadSourcesJson
          .map((e) => LeadSource.fromJson(e as Map<String, dynamic>))
          .toList(),
      kpi: json['kpi'] != null
          ? KpiSummary.fromJson(json['kpi'] as Map<String, dynamic>)
          : null,
      revenueChart: (json['revenueChart'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      occupancyChart: (json['occupancyChart'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      leadFunnel: (json['leadFunnel'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      buildings: (json['buildings'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
    );
  }
}

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static const int _cacheTtlSeconds = 60;

  Future<FullDashboardData> getDashboard({bool forceRefresh = false}) async {
    const cacheKey = 'analytics_dashboard';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        return FullDashboardData.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
    }

    final result = await ApiService.instance.get('/analytics/dashboard');
    final data = result['data'] as Map<String, dynamic>;
    CacheService.instance.set(
      cacheKey,
      jsonEncode(data),
      ttlSeconds: _cacheTtlSeconds,
    );
    return FullDashboardData.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getRevenueTrend(
      {String period = '12m', bool forceRefresh = false}) async {
    final cacheKey = 'analytics_revenue_$period';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        final data = jsonDecode(cached) as List<dynamic>;
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
    }

    final result = await ApiService.instance
        .get('/analytics/revenue-trend?period=$period');
    final data = result['data'] as List<dynamic>;
    CacheService.instance.set(
      cacheKey,
      jsonEncode(data),
      ttlSeconds: _cacheTtlSeconds,
    );
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getOccupancyTrend(
      {String period = '12m', bool forceRefresh = false}) async {
    final cacheKey = 'analytics_occupancy_$period';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        final data = jsonDecode(cached) as List<dynamic>;
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
    }

    final result = await ApiService.instance
        .get('/analytics/occupancy-trend?period=$period');
    final data = result['data'] as List<dynamic>;
    CacheService.instance.set(
      cacheKey,
      jsonEncode(data),
      ttlSeconds: _cacheTtlSeconds,
    );
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, int>> getLeadFunnel({bool forceRefresh = false}) async {
    const cacheKey = 'analytics_lead_funnel';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        return data.map(
            (key, value) => MapEntry(key, (value as num).toInt()));
      }
    }

    final result =
        await ApiService.instance.get('/analytics/lead-funnel');
    final data = result['data'] as Map<String, dynamic>;
    CacheService.instance.set(
      cacheKey,
      jsonEncode(data),
      ttlSeconds: _cacheTtlSeconds,
    );
    return data.map((key, value) => MapEntry(key, (value as num).toInt()));
  }
}
