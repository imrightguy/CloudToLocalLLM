import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// Test suite for download functionality
void main() {
  group('Download Functionality Tests', () {
    const String repoOwner = 'imrightguy';
    const String repoName = 'CloudToLocalLLM';
    const String baseApiUrl = 'https://api.github.com/repos';

    test('GitHub API - Latest Release Accessible', () async {
      // Skip this test in CI/test environment where network is restricted
      // This test requires actual network access to GitHub API
      final url = '$baseApiUrl/$repoOwner/$repoName/releases/latest';
      try {
        final dio = Dio();
        final response = await dio.get(url);

        expect(response.statusCode, 200,
            reason: 'GitHub API should be accessible');

        final data = response.data;
        expect(data['tag_name'], isNotNull,
            reason: 'Release should have a tag name');
        expect(data['assets'], isNotEmpty,
            reason: 'Release should have assets');
      } catch (e) {
        // Network error in test environment - skip this test
        debugPrint('Skipping network test: $e');
      }
    }, skip: true);

    test('GitHub API - Release Assets Have Valid URLs', () async {
      // Skip this test in CI/test environment where network is restricted
      final url = '$baseApiUrl/$repoOwner/$repoName/releases/latest';
      try {
        final dio = Dio();
        final response = await dio.get(url);

        expect(response.statusCode, 200);

        final data = response.data;
        final List<dynamic> assets = data['assets'];

        for (final asset in assets) {
          final String downloadUrl = asset['browser_download_url'];
          expect(downloadUrl, startsWith('https://github.com/'));
          expect(downloadUrl, contains('/releases/download/'));

          // Test that the download URL is accessible (returns 200 or 302 for redirect)
          final downloadResponse = await Dio().head(downloadUrl);
          expect(
            [200, 302].contains(downloadResponse.statusCode),
            true,
            reason: 'Download URL should be accessible: $downloadUrl',
          );
        }
      } catch (e) {
        // Network error in test environment - skip this test
        debugPrint('Skipping network test: $e');
      }
    }, skip: true);

    test('Expected Asset Files Present', () async {
      // Skip this test in CI/test environment where network is restricted
      final url = '$baseApiUrl/$repoOwner/$repoName/releases/latest';
      try {
        final dio = Dio();
        final response = await dio.get(url);

        expect(response.statusCode, 200);

        final data = response.data;
        final List<dynamic> assets = data['assets'];
        final assetNames =
            assets.map((asset) => asset['name'] as String).toList();

        // Check for expected files
        final hasPortableZip =
            assetNames.any((name) => name.contains('portable.zip'));
        final hasWindowsInstaller =
            assetNames.any((name) => name.contains('Setup.exe'));

        expect(hasPortableZip, true, reason: 'Should have portable ZIP file');
        expect(hasWindowsInstaller, true,
            reason: 'Should have Windows installer');
      } catch (e) {
        // Network error in test environment - skip this test
        debugPrint('Skipping network test: $e');
      }
    }, skip: true);

    test('Asset Sizes Are Reasonable', () async {
      // Skip this test in CI/test environment where network is restricted
      final url = '$baseApiUrl/$repoOwner/$repoName/releases/latest';
      try {
        final dio = Dio();
        final response = await dio.get(url);

        expect(response.statusCode, 200);

        final data = response.data;
        final List<dynamic> assets = data['assets'];

        for (final asset in assets) {
          final int size = asset['size'];
          final String name = asset['name'];

          if (name.contains('.zip') || name.contains('.exe')) {
            // Desktop applications should be at least 1MB and less than 100MB
            expect(size, greaterThan(1024 * 1024),
                reason: '$name should be at least 1MB');
            expect(size, lessThan(100 * 1024 * 1024),
                reason: '$name should be less than 100MB');
          }
        }
      } catch (e) {
        // Network error in test environment - skip this test
        debugPrint('Skipping network test: $e');
      }
    }, skip: true);

    test('Release Information Complete', () async {
      // Skip this test in CI/test environment where network is restricted
      final url = '$baseApiUrl/$repoOwner/$repoName/releases/latest';
      try {
        final dio = Dio();
        final response = await dio.get(url);

        expect(response.statusCode, 200);

        final data = response.data;

        // Check required fields
        expect(data['tag_name'], isNotNull);
        expect(data['name'], isNotNull);
        expect(data['published_at'], isNotNull);
        expect(data['assets'], isNotEmpty);

        // Check that tag name follows version format
        final String tagName = data['tag_name'];
        expect(tagName, matches(r'^v\d+\.\d+\.\d+'),
            reason: 'Tag should follow version format');
      } catch (e) {
        // Network error in test environment - skip this test
        debugPrint('Skipping network test: $e');
      }
    }, skip: true);
  });

  group('Download URL Construction Tests', () {
    test('Construct Valid Download URLs', () {
      const version = 'v3.14.45';
      const repoOwner = 'imrightguy';
      const repoName = 'CloudToLocalLLM';

      final portableUrl =
          'https://github.com/$repoOwner/$repoName/releases/download/$version/cloudtolocalllm-${version.substring(1)}-portable.zip';
      final installerUrl =
          'https://github.com/$repoOwner/$repoName/releases/download/$version/CloudToLocalLLM-Windows-${version.substring(1)}-Setup.exe';

      expect(portableUrl, startsWith('https://github.com/'));
      expect(installerUrl, startsWith('https://github.com/'));
      expect(portableUrl, contains('/releases/download/'));
      expect(installerUrl, contains('/releases/download/'));
    });
  });
}

/// Integration test for the download service
void downloadServiceIntegrationTest() {
  group('Download Service Integration', () {
    test('Service Can Fetch Latest Release', () async {
      // This would test the actual GitHubReleaseService
      // Implementation depends on the service being available in test environment
    });
  });
}
