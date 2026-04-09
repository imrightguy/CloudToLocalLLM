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
      expect(stats.periodStart.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(stats.periodStart.isBefore(after.add(const Duration(seconds: 1))), isTrue);
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

  group('DashboardData', () {
    test('fromJson parses full dashboard', () {
      final dashboard = DashboardData.fromJson({
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
      });

      expect(dashboard.pipeline.stages['nouveau'], 10);
      expect(dashboard.hotLeads.length, 1);
      expect(dashboard.hotLeads.first['fullName'], 'Test User');
      expect(dashboard.weeklyStats.newLeads, 10);
      expect(dashboard.visitStats.total, 50);
      expect(dashboard.conversionRates.conversionRate, '40%');
      expect(dashboard.leadSources.length, 2);
      expect(dashboard.leadSources.first.source, 'Web');
    });

    test('fromJson handles empty dashboard', () {
      final dashboard = DashboardData.fromJson({});
      expect(dashboard.pipeline.stages, isEmpty);
      expect(dashboard.hotLeads, isEmpty);
      expect(dashboard.weeklyStats.newLeads, 0);
      expect(dashboard.visitStats.total, 0);
      expect(dashboard.conversionRates.conversionRate, '0%');
      expect(dashboard.leadSources, isEmpty);
    });
  });
}
