import 'dart:convert';

const String localThinkSilentPreviewSummary = 'Silent wake-gate skip.';

enum LocalThinkJobStatus {
  queued,
  running,
  completed,
  failed,
  cancelled,
  skipped,
  unknown,
}

class LocalThinkJob {
  final String taskId;
  final String? unit;
  final String name;
  final LocalThinkJobStatus status;
  final int? exitCode;
  final int attempts;
  final int maxAttempts;
  final String? dedupKey;
  final String? notify;
  final String? wakeGate;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final double? updatedAt;
  final String? parentTaskId;
  final String? contextFrom;
  final String? finalPreview;
  final String? finalFile;
  final String? logFile;
  final String? outputFile;
  final String? metaFile;
  final String? runnerFile;
  final String? metaJson;
  final bool isSilent;

  const LocalThinkJob({
    required this.taskId,
    required this.name,
    required this.status,
    required this.attempts,
    required this.maxAttempts,
    this.unit,
    this.exitCode,
    this.dedupKey,
    this.notify,
    this.wakeGate,
    this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.updatedAt,
    this.parentTaskId,
    this.contextFrom,
    this.finalPreview,
    this.finalFile,
    this.logFile,
    this.outputFile,
    this.metaFile,
    this.runnerFile,
    this.metaJson,
    this.isSilent = false,
  });

  factory LocalThinkJob.fromJson(Map<String, Object?> json) {
    final taskId =
        _stringValue(json['task_id']) ?? _stringValue(json['taskId']);
    if (taskId == null || taskId.isEmpty) {
      throw const FormatException('LocalThinkJob missing task_id');
    }

    return LocalThinkJob(
      taskId: taskId,
      unit: _stringValue(json['unit']),
      name: _stringValue(json['name']) ?? taskId,
      status: localThinkJobStatusFromString(_stringValue(json['status'])),
      exitCode: _intValue(json['exit_code']) ?? _intValue(json['exitCode']),
      attempts: _intValue(json['attempts']) ?? 0,
      maxAttempts: _intValue(json['max_attempts']) ??
          _intValue(json['maxAttempts']) ??
          1,
      dedupKey:
          _stringValue(json['dedup_key']) ?? _stringValue(json['dedupKey']),
      notify: _stringValue(json['notify']),
      wakeGate:
          _stringValue(json['wake_gate']) ?? _stringValue(json['wakeGate']),
      createdAt: _dateTimeValue(json['created_at']) ??
          _dateTimeValue(json['createdAt']),
      startedAt: _dateTimeValue(json['started_at']) ??
          _dateTimeValue(json['startedAt']),
      finishedAt: _dateTimeValue(json['finished_at']) ??
          _dateTimeValue(json['finishedAt']),
      updatedAt:
          _doubleValue(json['updated_at']) ?? _doubleValue(json['updatedAt']),
      parentTaskId: _stringValue(json['parent_task_id']) ??
          _stringValue(json['parentTaskId']),
      contextFrom: _stringValue(json['context_from']) ??
          _stringValue(json['contextFrom']),
      finalPreview: _stringValue(json['final_preview']) ??
          _stringValue(json['finalPreview']) ??
          _stringValue(json['preview']),
      finalFile:
          _stringValue(json['final_file']) ?? _stringValue(json['finalFile']),
      logFile: _stringValue(json['log_file']) ?? _stringValue(json['logFile']),
      outputFile:
          _stringValue(json['output_file']) ?? _stringValue(json['outputFile']),
      metaFile:
          _stringValue(json['meta_file']) ?? _stringValue(json['metaFile']),
      runnerFile: _stringValue(json['runner_file']) ??
          _stringValue(json['runnerFile']),
      metaJson:
          _stringValue(json['meta_json']) ?? _stringValue(json['metaJson']),
      isSilent: _boolValue(json['is_silent']) ??
          _boolValue(json['isSilent']) ??
          _looksSilent(_stringValue(json['final_preview']) ??
              _stringValue(json['finalPreview']) ??
              _stringValue(json['preview'])),
    );
  }

  LocalThinkJob mergeWithJson(Map<String, Object?> json) {
    final statusValue = _stringValue(json['status']);
    final preview = _stringValue(json['final_preview']) ??
        _stringValue(json['finalPreview']) ??
        _stringValue(json['preview']) ??
        finalPreview;

    return LocalThinkJob(
      taskId: taskId,
      unit: _stringValue(json['unit']) ?? unit,
      name: _stringValue(json['name']) ?? name,
      status: statusValue == null
          ? status
          : localThinkJobStatusFromString(statusValue),
      exitCode: _intValue(json['exit_code']) ??
          _intValue(json['exitCode']) ??
          exitCode,
      attempts: _intValue(json['attempts']) ?? attempts,
      maxAttempts: _intValue(json['max_attempts']) ??
          _intValue(json['maxAttempts']) ??
          maxAttempts,
      dedupKey: _stringValue(json['dedup_key']) ??
          _stringValue(json['dedupKey']) ??
          dedupKey,
      notify: _stringValue(json['notify']) ?? notify,
      wakeGate: _stringValue(json['wake_gate']) ??
          _stringValue(json['wakeGate']) ??
          wakeGate,
      createdAt: _dateTimeValue(json['created_at']) ??
          _dateTimeValue(json['createdAt']) ??
          createdAt,
      startedAt: _dateTimeValue(json['started_at']) ??
          _dateTimeValue(json['startedAt']) ??
          startedAt,
      finishedAt: _dateTimeValue(json['finished_at']) ??
          _dateTimeValue(json['finishedAt']) ??
          finishedAt,
      updatedAt: _doubleValue(json['updated_at']) ??
          _doubleValue(json['updatedAt']) ??
          updatedAt,
      parentTaskId: _stringValue(json['parent_task_id']) ??
          _stringValue(json['parentTaskId']) ??
          parentTaskId,
      contextFrom: _stringValue(json['context_from']) ??
          _stringValue(json['contextFrom']) ??
          contextFrom,
      finalPreview: preview,
      finalFile: _stringValue(json['final_file']) ??
          _stringValue(json['finalFile']) ??
          finalFile,
      logFile: _stringValue(json['log_file']) ??
          _stringValue(json['logFile']) ??
          logFile,
      outputFile: _stringValue(json['output_file']) ??
          _stringValue(json['outputFile']) ??
          outputFile,
      metaFile: _stringValue(json['meta_file']) ??
          _stringValue(json['metaFile']) ??
          metaFile,
      runnerFile: _stringValue(json['runner_file']) ??
          _stringValue(json['runnerFile']) ??
          runnerFile,
      metaJson: _stringValue(json['meta_json']) ??
          _stringValue(json['metaJson']) ??
          metaJson,
      isSilent: _boolValue(json['is_silent']) ??
          _boolValue(json['isSilent']) ??
          isSilent ||
              _looksSilent(
                preview,
              ),
    );
  }

  LocalThinkJob copyWith({
    String? finalPreview,
  }) {
    final nextFinalPreview = finalPreview ?? this.finalPreview;
    return LocalThinkJob(
      taskId: taskId,
      unit: unit,
      name: name,
      status: status,
      attempts: attempts,
      maxAttempts: maxAttempts,
      exitCode: exitCode,
      dedupKey: dedupKey,
      notify: notify,
      wakeGate: wakeGate,
      createdAt: createdAt,
      startedAt: startedAt,
      finishedAt: finishedAt,
      updatedAt: updatedAt,
      parentTaskId: parentTaskId,
      contextFrom: contextFrom,
      finalPreview: nextFinalPreview,
      finalFile: finalFile,
      logFile: logFile,
      outputFile: outputFile,
      metaFile: metaFile,
      runnerFile: runnerFile,
      metaJson: metaJson,
      isSilent: isSilent || _looksSilent(nextFinalPreview),
    );
  }

  static List<LocalThinkJob> listFromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is List<Object?>) {
      return decoded
          .whereType<Map<String, Object?>>()
          .map(LocalThinkJob.fromJson)
          .toList(growable: false);
    }
    if (decoded is Map<String, Object?>) {
      final jobs = decoded['jobs'];
      if (jobs is List<Object?>) {
        return jobs
            .whereType<Map<String, Object?>>()
            .map(LocalThinkJob.fromJson)
            .toList(growable: false);
      }
    }
    throw const FormatException(
      'Expected local-think ledger JSON list or object with jobs list',
    );
  }

  static Map<String, Object?> detailMapFromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, Object?>) {
      final job = decoded['job'];
      if (job is Map<String, Object?>) {
        return job;
      }
      final task = decoded['task'];
      if (task is Map<String, Object?>) {
        return task;
      }
      return decoded;
    }
    throw const FormatException('Expected local-think detail JSON object');
  }
}

LocalThinkJobStatus localThinkJobStatusFromString(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'queued':
      return LocalThinkJobStatus.queued;
    case 'running':
      return LocalThinkJobStatus.running;
    case 'completed':
      return LocalThinkJobStatus.completed;
    case 'failed':
      return LocalThinkJobStatus.failed;
    case 'cancelled':
    case 'canceled':
      return LocalThinkJobStatus.cancelled;
    case 'skipped':
      return LocalThinkJobStatus.skipped;
    default:
      return LocalThinkJobStatus.unknown;
  }
}

String? _stringValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  return value.toString();
}

int? _intValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

double? _doubleValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

bool? _boolValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    if (value == 1) {
      return true;
    }
    if (value == 0) {
      return false;
    }
  }
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
    }
  }
  return null;
}

DateTime? _dateTimeValue(Object? value) {
  final source = _stringValue(value);
  if (source == null || source.isEmpty) {
    return null;
  }
  return DateTime.tryParse(source);
}

bool _looksSilent(String? value) {
  if (value == null) {
    return false;
  }
  final trimmed = value.trim();
  return trimmed == localThinkSilentPreviewSummary ||
      trimmed.startsWith('[SILENT]');
}
