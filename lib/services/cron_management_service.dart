import 'dart:convert';

import 'package:cloudtolocalllm/config/app_config.dart';
import 'package:cloudtolocalllm/models/cron_job.dart';
import 'package:http/http.dart' as http;

/// Client for managing scheduled tasks through the runtime gateway.
class CronManagementService {
  final String? _apiBaseUrl;
  final http.Client _client;

  CronManagementService({
    String? apiBaseUrl,
    http.Client? client,
  })  : _apiBaseUrl = apiBaseUrl,
        _client = client ?? http.Client();

  String get _resolvedBaseUrl {
    final baseUrl = _apiBaseUrl?.trim();
    return (baseUrl != null && baseUrl.isNotEmpty) ? baseUrl : AppConfig.gatewayUrl;
  }

  Uri _endpoint([String suffix = '']) {
    final normalizedSuffix = suffix.isEmpty
        ? ''
        : suffix.startsWith('/')
            ? suffix
            : '/$suffix';
    return Uri.parse('$_resolvedBaseUrl/api/v1/cron$normalizedSuffix');
  }

  Map<String, String> _headers() => const {'Content-Type': 'application/json'};

  Future<List<CronJob>> listCronJobs() async {
    final response = await _client
        .get(_endpoint())
        .timeout(AppConfig.apiTimeout);

    if (response.statusCode != 200) {
      throw StateError(_describeFailure('list', response.statusCode, response.body));
    }

    final jobs = _extractJobList(jsonDecode(response.body));
    return jobs.map(CronJob.fromJson).toList(growable: false);
  }

  Future<CronJob> createCronJob({
    required String name,
    required String schedule,
    required String command,
    String? scheduleDescription,
    bool enabled = true,
  }) async {
    final response = await _client
        .post(
          _endpoint(),
          headers: _headers(),
          body: jsonEncode({
            'name': name,
            'schedule': schedule,
            'command': command,
            if (scheduleDescription != null) 'scheduleDescription': scheduleDescription,
            'enabled': enabled,
          }),
        )
        .timeout(AppConfig.apiTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StateError(_describeFailure('create', response.statusCode, response.body));
    }

    return CronJob.fromJson(_extractSingleJob(jsonDecode(response.body)));
  }

  Future<bool> setCronJobEnabled(String cronJobId, bool enabled) async {
    final response = await _client
        .patch(
          _endpoint(cronJobId),
          headers: _headers(),
          body: jsonEncode({'enabled': enabled}),
        )
        .timeout(AppConfig.apiTimeout);

    if (response.statusCode == 200 || response.statusCode == 204) {
      return true;
    }

    throw StateError(_describeFailure('update', response.statusCode, response.body));
  }

  Future<bool> deleteCronJob(String cronJobId) async {
    final response = await _client
        .delete(_endpoint(cronJobId), headers: _headers())
        .timeout(AppConfig.apiTimeout);

    if (response.statusCode == 200 || response.statusCode == 204) {
      return true;
    }

    throw StateError(_describeFailure('delete', response.statusCode, response.body));
  }

  Future<bool> runCronJob(String cronJobId) async {
    final response = await _client
        .post(_endpoint('$cronJobId/run'), headers: _headers())
        .timeout(AppConfig.apiTimeout);

    if (response.statusCode == 200 || response.statusCode == 202 || response.statusCode == 204) {
      return true;
    }

    throw StateError(_describeFailure('run', response.statusCode, response.body));
  }

  List<Map<String, dynamic>> _extractJobList(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false);
    }

    if (decoded is Map<String, dynamic>) {
      for (final key in const ['jobs', 'cronJobs', 'items', 'data', 'scheduledTasks']) {
        final value = decoded[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList(growable: false);
        }
      }
    }

    return const [];
  }

  Map<String, dynamic> _extractSingleJob(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      for (final key in const ['job', 'cronJob', 'data']) {
        final value = decoded[key];
        if (value is Map) {
          return Map<String, dynamic>.from(value);
        }
      }
      return decoded;
    }

    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      return Map<String, dynamic>.from(decoded.first as Map);
    }

    throw StateError('Cron service returned an unexpected payload shape.');
  }

  String _describeFailure(String operation, int statusCode, String body) {
    final trimmedBody = body.trim();
    final detail = trimmedBody.isEmpty ? 'no response body' : trimmedBody;
    return 'Failed to $operation cron jobs (HTTP $statusCode): $detail';
  }
}
