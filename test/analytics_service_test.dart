import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/services/analytics_service.dart';

void main() {
  group('PipelineData', () {
    test('fromJson parses stage counts', () {
      final data = PipelineData.fromJson({
        'nouveau': 5,
        'contacte': 3,
        'qualifie': 2,
      });
      expect(data.stages, {'nouveau': 5, 'contacte': 3, 'qualifie': 2});
    });

    test('fromJson handles empty input', () {
      final data = PipelineData.fromJson({});
      expect(data.stages, isEmpty);
    });

    test('fromJson converts double values to int via toInt', () {
      final data = PipelineData.fromJson({'nouveau': 5.9});
      expect(data.stages['nouveau'], 5);
    });

    test('fromJson converts numeric values to int', () {
      final data = PipelineData.fromJson({'bail_signe': 1.5});
      expect(data.stages['bail_signe'], 1);
    });
  });

  group('WeeklyStats', () {
    test('fromJson parses all fields', () {
      final stats = WeeklyStats.fromJson({
        'period': 'week',
        'periodStart': '2024-06-10T00:00:00.000Z',
        'newLeads': 12,
        'visitsCompleted': 8,
        'conversions': 3,
        'noShows': 2,
      });
      expect(stats.period, 'week');
      expect(stats.newLeads, 12);
      expect(stats.visitsCompleted, 8);
      expect(stats.conversions, 3);
      expect(stats.noShows, 2);
      expect(stats.periodStart, DateTime.utc(2024, 6, 10));
    });

    test('fromJson defaults missing fields', () {
      final stats = WeeklyStats.fromJson({});
      expect(stats.period, 'week');
      expect(stats.newLeads, 0);
      expect(stats.visitsCompleted, 0);
      expect(stats.conversions, 0);
      expect(stats.noShows, 0);
      expect(stats.periodStart, isNotNull);
    });

    test('fromJson uses DateTime.now() when periodStart is null', () {
      final before = DateTime.now();
      final stats = WeeklyStats.fromJson({});
      final after = DateTime.now();
      expect(
          stats.periodStart
              .isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(stats.periodStart.isBefore(after.add(const Duration(seconds: 1))),
          isTrue);
    });
  });

  group('VisitStatsData', () {
    test('fromJson parses all fields', () {
      final stats = VisitStatsData.fromJson({
        'total': 20,
        'completed': 15,
        'cancelled': 3,
        'noShow': 2,
      });
      expect(stats.total, 20);
      expect(stats.completed, 15);
      expect(stats.cancelled, 3);
      expect(stats.noShow, 2);
    });

    test('fromJson defaults to zero', () {
      final stats = VisitStatsData.fromJson({});
      expect(stats.total, 0);
      expect(stats.completed, 0);
      expect(stats.cancelled, 0);
      expect(stats.noShow, 0);
    });
  });

  group('ConversionRates', () {
    test('fromJson parses all fields', () {
      final rates = ConversionRates.fromJson({
        'totalVisits': 100,
        'converted': 35,
        'conversionRate': '35%',
      });
      expect(rates.totalVisits, 100);
      expect(rates.converted, 35);
      expect(rates.conversionRate, '35%');
    });

    test('fromJson defaults', () {
      final rates = ConversionRates.fromJson({});
      expect(rates.totalVisits, 0);
      expect(rates.converted, 0);
      expect(rates.conversionRate, '0%');
    });
  });

  group('LeadSource', () {
    test('fromJson parses source and count', () {
      final src = LeadSource.fromJson({'source': 'Facebook', 'count': 42});
      expect(src.source, 'Facebook');
      expect(src.count, 42);
    });

    test('fromJson defaults', () {
      final src = LeadSource.fromJson({});
      expect(src.source, '');
      expect(src.count, 0);
    });
  });

  group('Operational metrics', () {
    test('OperationalMetricsWindow.fromJson parses all fields', () {
      final window = OperationalMetricsWindow.fromJson({
        'inboxVolume': 14,
        'replies': 9,
        'bookings': 3,
        'completedVisits': 2,
        'noShows': 1,
        'stalledConversations': 4,
      });

      expect(window.inboxVolume, 14);
      expect(window.replies, 9);
      expect(window.bookings, 3);
      expect(window.completedVisits, 2);
      expect(window.noShows, 1);
      expect(window.stalledConversations, 4);
    });

    test('InboxToVisitMetrics.fromJson parses nested periods', () {
      final metrics = InboxToVisitMetrics.fromJson({
        'generatedAt': '2026-05-01T20:00:00.000Z',
        'daily': {
          'inboxVolume': 4,
          'replies': 2,
          'bookings': 1,
          'completedVisits': 1,
          'noShows': 0,
          'stalledConversations': 2,
        },
        'weekly': {
          'inboxVolume': 18,
          'replies': 11,
          'bookings': 6,
          'completedVisits': 4,
          'noShows': 1,
          'stalledConversations': 3,
        },
      });

      expect(metrics.generatedAt, DateTime.utc(2026, 5, 1, 20));
      expect(metrics.daily.bookings, 1);
      expect(metrics.weekly.replies, 11);
    });
  });

  group('FullDashboardData', () {
    test('fromJson parses full dashboard', () {
      final dashboard = FullDashboardData.fromJson({
        'pipeline': {'nouveau': 10, 'contacte': 5},
        'hotLeads': [
          {'id': 'l1', 'fullName': 'Test User'},
        ],
        'weeklyStats': {
          'period': 'week',
          'periodStart': '2024-06-10',
          'newLeads': 10,
          'visitsCompleted': 7,
          'conversions': 2,
          'noShows': 1,
        },
        'visitStats': {
          'total': 50,
          'completed': 40,
          'cancelled': 5,
          'noShow': 5,
        },
        'conversionRates': {
          'totalVisits': 50,
          'converted': 20,
          'conversionRate': '40%',
        },
        'leadSources': [
          {'source': 'Web', 'count': 30},
          {'source': 'Referral', 'count': 15},
        ],
        'inboxToVisitMetrics': {
          'generatedAt': '2026-05-01T20:00:00.000Z',
          'daily': {
            'inboxVolume': 5,
            'replies': 3,
            'bookings': 1,
            'completedVisits': 1,
            'noShows': 0,
            'stalledConversations': 2,
          },
          'weekly': {
            'inboxVolume': 19,
            'replies': 12,
            'bookings': 7,
            'completedVisits': 4,
            'noShows': 1,
            'stalledConversations': 3,
          },
        },
      });

      expect(dashboard.pipeline.stages['nouveau'], 10);
      expect(dashboard.hotLeads.length, 1);
      expect(dashboard.hotLeads.first['fullName'], 'Test User');
      expect(dashboard.weeklyStats.newLeads, 10);
      expect(dashboard.visitStats.total, 50);
      expect(dashboard.conversionRates.conversionRate, '40%');
      expect(dashboard.leadSources.length, 2);
      expect(dashboard.leadSources.first.source, 'Web');
      expect(dashboard.inboxToVisitMetrics, isNotNull);
      expect(dashboard.inboxToVisitMetrics!.daily.inboxVolume, 5);
      expect(dashboard.inboxToVisitMetrics!.weekly.stalledConversations, 3);
    });

    test('fromJson handles empty dashboard', () {
      final dashboard = FullDashboardData.fromJson({});
      expect(dashboard.pipeline.stages, isEmpty);
      expect(dashboard.hotLeads, isEmpty);
      expect(dashboard.weeklyStats.newLeads, 0);
      expect(dashboard.visitStats.total, 0);
      expect(dashboard.conversionRates.conversionRate, '0%');
      expect(dashboard.leadSources, isEmpty);
      expect(dashboard.inboxToVisitMetrics, isNull);
    });

    test('fromJson parses KPI summary', () {
      final dashboard = FullDashboardData.fromJson({
        'kpi': {
          'revenue': {'current': 45000, 'previous': 42000, 'trend': 7.14},
          'occupancyRate': {'current': 87.5, 'previous': 82.1, 'trend': 5.3},
          'activeLeases': {'current': 156, 'previous': 148, 'trend': 5.4},
          'openLeads': {'current': 42, 'previous': 38, 'trend': -10.5},
        },
      });

      expect(dashboard.kpi, isNotNull);
      expect(dashboard.kpi!.revenue.current, 45000);
      expect(dashboard.kpi!.occupancyRate.trend, 5.3);
      expect(dashboard.kpi!.activeLeases.current, 156);
      expect(dashboard.kpi!.openLeads.trend, -10.5);
    });

    test('fromJson parses revenue chart data', () {
      final dashboard = FullDashboardData.fromJson({
        'revenueChart': [
          {'month': '2026-01', 'revenue': 38000},
          {'month': '2026-02', 'revenue': 41000},
        ],
      });

      expect(dashboard.revenueChart, isNotNull);
      expect(dashboard.revenueChart!.length, 2);
      expect(dashboard.revenueChart!.first['month'], '2026-01');
    });

    test('fromJson parses lead funnel', () {
      final dashboard = FullDashboardData.fromJson({
        'leadFunnel': {
          'nouveau': 42,
          'contacte': 35,
          'bailSigne': 8,
        },
      });

      expect(dashboard.leadFunnel, isNotNull);
      expect(dashboard.leadFunnel!['nouveau'], 42);
      expect(dashboard.leadFunnel!['bailSigne'], 8);
    });
  });
}
