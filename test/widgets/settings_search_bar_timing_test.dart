import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/widgets/settings/settings_search_bar.dart';

void main() {
  group('SettingsSearchBar Timing - Property 33', () {
    /// **Feature: platform-settings-screen, Property 33: Search Filtering Timing**
    /// **Validates: Requirements 9.2**
    ///
    /// Property: *For any* search query, filtering and highlighting SHALL complete
    /// within 300 milliseconds

    test(
      'Search filtering completes within 300ms for single result',
      () async {
        final results = [
          SettingsSearchResult(
            id: '1',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Theme',
            settingDescription: 'Choose your theme',
            matchedText: 'Theme',
            matchPosition: 0,
          ),
        ];

        final stopwatch = Stopwatch()..start();

        final filtered = SettingsSearchUtil.search('theme', results);

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(300),
          reason:
              'Search filtering should complete within 300ms, but took ${stopwatch.elapsedMilliseconds}ms',
        );

        expect(filtered.length, 1);
        expect(filtered[0].settingName, 'Theme');
      },
    );

    test(
      'Search filtering completes within 300ms for 100 results',
      () async {
        final results = List.generate(
          100,
          (index) => SettingsSearchResult(
            id: '$index',
            categoryId: 'category_${index % 10}',
            categoryTitle: 'Category ${index % 10}',
            settingName: 'Setting $index',
            settingDescription: 'Description for setting $index',
            matchedText: 'Setting',
            matchPosition: 0,
          ),
        );

        final stopwatch = Stopwatch()..start();

        final filtered = SettingsSearchUtil.search('setting', results);

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(300),
          reason:
              'Search filtering for 100 results should complete within 300ms, but took ${stopwatch.elapsedMilliseconds}ms',
        );

        expect(filtered.length, 100);
      },
    );

    test(
      'Search filtering completes within 300ms for 500 results',
      () async {
        final results = List.generate(
          500,
          (index) => SettingsSearchResult(
            id: '$index',
            categoryId: 'category_${index % 20}',
            categoryTitle: 'Category ${index % 20}',
            settingName: 'Setting $index',
            settingDescription: 'Description for setting $index with keywords',
            matchedText: 'Setting',
            matchPosition: 0,
          ),
        );

        final stopwatch = Stopwatch()..start();

        final filtered = SettingsSearchUtil.search('setting', results);

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(300),
          reason:
              'Search filtering for 500 results should complete within 300ms, but took ${stopwatch.elapsedMilliseconds}ms',
        );

        expect(filtered.length, 500);
      },
    );

    test(
      'Search filtering completes within 300ms for 1000 results',
      () async {
        final results = List.generate(
          1000,
          (index) => SettingsSearchResult(
            id: '$index',
            categoryId: 'category_${index % 50}',
            categoryTitle: 'Category ${index % 50}',
            settingName: 'Setting $index',
            settingDescription: 'Description for setting $index',
            matchedText: 'Setting',
            matchPosition: 0,
          ),
        );

        final stopwatch = Stopwatch()..start();

        final filtered = SettingsSearchUtil.search('setting', results);

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(300),
          reason:
              'Search filtering for 1000 results should complete within 300ms, but took ${stopwatch.elapsedMilliseconds}ms',
        );

        expect(filtered.length, 1000);
      },
    );

    test(
      'Search filtering completes within 300ms with various query patterns',
      () async {
        final results = List.generate(
          200,
          (index) => SettingsSearchResult(
            id: '$index',
            categoryId: 'category_${index % 10}',
            categoryTitle: 'Category ${index % 10}',
            settingName: 'Setting $index',
            settingDescription: 'Description for setting $index',
            matchedText: 'Setting',
            matchPosition: 0,
          ),
        );

        final queries = ['s', 'se', 'set', 'sett', 'settin', 'setting'];

        for (final query in queries) {
          final stopwatch = Stopwatch()..start();

          final filtered = SettingsSearchUtil.search(query, results);

          stopwatch.stop();

          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(300),
            reason:
                'Search filtering for query "$query" should complete within 300ms, but took ${stopwatch.elapsedMilliseconds}ms',
          );

          expect(filtered.isNotEmpty, true);
        }
      },
    );

    test(
      'Search filtering completes within 300ms across 100 iterations',
      () async {
        final results = List.generate(
          100,
          (index) => SettingsSearchResult(
            id: '$index',
            categoryId: 'category_${index % 10}',
            categoryTitle: 'Category ${index % 10}',
            settingName: 'Setting $index',
            settingDescription: 'Description for setting $index',
            matchedText: 'Setting',
            matchPosition: 0,
          ),
        );

        const int iterations = 100;
        final timings = <int>[];
        int exceedCount = 0;

        for (int i = 0; i < iterations; i++) {
          final stopwatch = Stopwatch()..start();

          final filtered = SettingsSearchUtil.search('setting', results);

          stopwatch.stop();
          final elapsed = stopwatch.elapsedMilliseconds;
          timings.add(elapsed);

          if (elapsed >= 300) {
            exceedCount++;
          }

          expect(filtered.isNotEmpty, true);
        }

        expect(
          exceedCount,
          0,
          reason:
              '$exceedCount out of $iterations iterations exceeded 300ms threshold',
        );

        final maxTiming = timings.reduce((a, b) => a > b ? a : b);
        expect(
          maxTiming,
          lessThan(300),
          reason:
              'Maximum timing across 100 iterations was $maxTiming ms, exceeds 300ms threshold',
        );
      },
    );

    test(
      'Search filtering completes within 300ms with case-insensitive queries',
      () async {
        final results = List.generate(
          150,
          (index) => SettingsSearchResult(
            id: '$index',
            categoryId: 'general',
            categoryTitle: 'General Settings',
            settingName: 'Theme Setting $index',
            settingDescription: 'Configure theme preferences',
            matchedText: 'Theme',
            matchPosition: 0,
          ),
        );

        final queries = ['THEME', 'theme', 'ThEmE', 'tHeMe'];

        for (final query in queries) {
          final stopwatch = Stopwatch()..start();

          final filtered = SettingsSearchUtil.search(query, results);

          stopwatch.stop();

          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(300),
            reason:
                'Case-insensitive search for "$query" should complete within 300ms, but took ${stopwatch.elapsedMilliseconds}ms',
          );

          expect(filtered.length, 150);
        }
      },
    );

    test(
      'Search filtering completes within 300ms with partial matches',
      () async {
        final results = List.generate(
          200,
          (index) => SettingsSearchResult(
            id: '$index',
            categoryId: 'category_${index % 10}',
            categoryTitle: 'Category ${index % 10}',
            settingName: 'Setting $index',
            settingDescription: 'Description for setting $index',
            matchedText: 'Setting',
            matchPosition: 0,
          ),
        );

        final stopwatch = Stopwatch()..start();

        final filtered = SettingsSearchUtil.search('set', results);

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(300),
          reason:
              'Partial match search should complete within 300ms, but took ${stopwatch.elapsedMilliseconds}ms',
        );

        expect(filtered.length, 200);
      },
    );

    test(
      'Search filtering completes within 300ms with no matches',
      () async {
        final results = List.generate(
          100,
          (index) => SettingsSearchResult(
            id: '$index',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Theme',
            settingDescription: 'Choose your theme',
            matchedText: 'Theme',
            matchPosition: 0,
          ),
        );

        final stopwatch = Stopwatch()..start();

        final filtered = SettingsSearchUtil.search('xyz123notfound', results);

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(300),
          reason:
              'No-match search should complete within 300ms, but took ${stopwatch.elapsedMilliseconds}ms',
        );

        expect(filtered.isEmpty, true);
      },
    );

    test(
      'Search filtering completes within 300ms with description matches',
      () async {
        final results = List.generate(
          150,
          (index) => SettingsSearchResult(
            id: '$index',
            categoryId: 'category_${index % 10}',
            categoryTitle: 'Category ${index % 10}',
            settingName: 'Setting $index',
            settingDescription: 'This is a description with unique keywords',
            matchedText: 'keywords',
            matchPosition: 0,
          ),
        );

        final stopwatch = Stopwatch()..start();

        final filtered = SettingsSearchUtil.search('keywords', results);

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(300),
          reason:
              'Description match search should complete within 300ms, but took ${stopwatch.elapsedMilliseconds}ms',
        );

        expect(filtered.length, 150);
      },
    );
  });
}
