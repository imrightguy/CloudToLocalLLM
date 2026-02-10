import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart';
import '../database/local_brain.dart';

/// Service to synchronize local Drift database with cloud PostgreSQL
class BrainSyncService {
  final LocalBrain _db;
  final String _backendUrl;
  final String? _authToken;
  Timer? _syncTimer;
  bool _isSyncing = false;
  final _syncController = StreamController<SyncStatus>.broadcast();

  BrainSyncService(this._db, {String? backendUrl, String? authToken})
      : _backendUrl = backendUrl ?? 'https://api.cloudtolocalllm.online',
        _authToken = authToken;

  /// Stream of sync status updates
  Stream<SyncStatus> get syncStatus => _syncController.stream;

  /// Start periodic sync
  void startSync({Duration interval = const Duration(minutes: 5)}) {
    stopSync();
    print('[BrainSync] Starting periodic sync (interval: ${interval.inMinutes}m)');
    
    // Immediate first sync
    sync();
    
    // Schedule periodic sync
    _syncTimer = Timer.periodic(interval, (_) => sync());
  }

  /// Stop sync
  void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print('[BrainSync] Sync stopped');
  }

  /// Perform sync (upload local events, download cloud events)
  Future<SyncResult> sync() async {
    if (_isSyncing) {
      print('[BrainSync] Sync already in progress, skipping');
      return SyncResult.alreadyRunning();
    }

    _isSyncing = true;
    _syncController.add(const SyncStatus.syncing());
    
    final stopwatch = Stopwatch()..start();
    int uploaded = 0;
    int downloaded = 0;
    int failed = 0;

    try {
      print('[BrainSync] Starting sync...');

      // 1. Upload unsynced local events
      final unsynced = await _db.getUnsyncedEvents(limit: 100);
      if (unsynced.isNotEmpty) {
        print('[BrainSync] Uploading ${unsynced.length} events...');
        final uploadedIds = await _uploadEvents(unsynced);
        await _db.markEventsSynced(uploadedIds);
        uploaded = uploadedIds.length;
        failed = unsynced.length - uploaded;
      }

      // 2. Process sync queue (pending operations)
      final pendingOps = await _db.getPendingSyncItems(limit: 50);
      if (pendingOps.isNotEmpty) {
        print('[BrainSync] Processing ${pendingOps.length} pending operations...');
        for (final op in pendingOps) {
          final success = await _processSyncOperation(op);
          if (success) {
            await _db.dequeueSync(op.id);
          } else {
            await _db.incrementRetry(op.id);
            failed++;
          }
        }
      }

      // 3. Download recent cloud events (if authenticated)
      if (_authToken != null) {
        downloaded = await _downloadRecentEvents();
      }

      stopwatch.stop();
      print('[BrainSync] Sync completed in ${stopwatch.elapsedMilliseconds}ms');
      print('[BrainSync] Uploaded: $uploaded, Downloaded: $downloaded, Failed: $failed');

      final result = SyncResult(
        success: true,
        uploaded: uploaded,
        downloaded: downloaded,
        failed: failed,
        duration: stopwatch.elapsed,
      );
      _syncController.add(SyncStatus.completed(result));
      return result;

    } catch (e, stack) {
      stopwatch.stop();
      print('[BrainSync] Sync failed: $e');
      print('[BrainSync] Stack: $stack');
      
      final result = SyncResult(
        success: false,
        uploaded: uploaded,
        downloaded: downloaded,
        failed: failed + 1,
        duration: stopwatch.elapsed,
        error: e.toString(),
      );
      _syncController.add(SyncStatus.error(e.toString()));
      return result;
    } finally {
      _isSyncing = false;
    }
  }

  /// Upload events to cloud backend
  Future<List<String>> _uploadEvents(List<AgentEvent> events) async {
    final uploadedIds = <String>[];
    
    for (final event in events) {
      try {
        final payload = {
          'id': event.id,
          'agent_id': event.agentId,
          'event_type': event.eventType,
          'event_data': jsonDecode(event.eventData),
          'correlation_id': event.correlationId,
          'timestamp': event.timestamp.toIso8601String(),
        };

        final response = await http.post(
          Uri.parse('$_backendUrl/api/agent/events'),
          headers: {
            'Content-Type': 'application/json',
            if (_authToken != null) 'Authorization': 'Bearer $_authToken',
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          uploadedIds.add(event.id);
        } else {
          print('[BrainSync] Failed to upload event ${event.id}: ${response.statusCode}');
        }
      } catch (e) {
        print('[BrainSync] Error uploading event ${event.id}: $e');
      }
    }

    return uploadedIds;
  }

  /// Process a sync queue operation
  Future<bool> _processSyncOperation(SyncQueueData op) async {
    try {
      final url = Uri.parse('$_backendUrl/api/${op.targetTable}/${op.recordId}');
      
      late final http.Response response;
      switch (op.operation) {
        case 'insert':
        case 'update':
          response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (_authToken != null) 'Authorization': 'Bearer $_authToken',
            },
            body: op.payload,
          );
          break;
        case 'delete':
          response = await http.delete(
            url,
            headers: {
              if (_authToken != null) 'Authorization': 'Bearer $_authToken',
            },
          );
          break;
        default:
          print('[BrainSync] Unknown operation: ${op.operation}');
          return false;
      }

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('[BrainSync] Error processing operation ${op.id}: $e');
      return false;
    }
  }

  /// Download recent events from cloud
  Future<int> _downloadRecentEvents() async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/agent/events?limit=100'),
        headers: {
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final events = data['events'] as List<dynamic>? ?? [];
        
        for (final eventJson in events) {
          await _db.addAgentEvent(AgentEventsCompanion(
            id: Value(eventJson['id'] as String),
            agentId: Value(eventJson['agent_id'] as String),
            eventType: Value(eventJson['event_type'] as String),
            eventData: Value(jsonEncode(eventJson['event_data'])),
            correlationId: Value(eventJson['correlation_id'] as String?),
            timestamp: Value(DateTime.parse(eventJson['timestamp'] as String)),
            synced: const Value(true),
            syncedAt: Value(DateTime.now()),
          ));
        }
        
        return events.length;
      }
    } catch (e) {
      print('[BrainSync] Error downloading events: $e');
    }
    return 0;
  }

  /// Force immediate sync
  Future<SyncResult> forceSync() => sync();

  /// Add a local event to be synced
  Future<void> addLocalEvent({
    required String agentId,
    required String eventType,
    required Map<String, dynamic> eventData,
    String? correlationId,
  }) async {
    await _db.addAgentEvent(AgentEventsCompanion(
      id: Value(_generateId()),
      agentId: Value(agentId),
      eventType: Value(eventType),
      eventData: Value(jsonEncode(eventData)),
      correlationId: Value(correlationId),
      synced: const Value(false),
    ));
  }

  /// Queue an operation for sync
  Future<void> queueOperation({
    required String targetTable,
    required String operation,
    required String recordId,
    required Map<String, dynamic> payload,
  }) async {
    await _db.enqueueSync(SyncQueueCompanion(
      targetTable: Value(targetTable),
      operation: Value(operation),
      recordId: Value(recordId),
      payload: Value(jsonEncode(payload)),
    ));
  }

  /// Get sync status
  bool get isSyncing => _isSyncing;

  /// Get local unsynced count
  Future<int> getUnsyncedCount() async {
    final events = await _db.getUnsyncedEvents(limit: 10000);
    return events.length;
  }

  /// Cleanup old synced events
  Future<int> cleanup({Duration maxAge = const Duration(days: 7)}) async {
    return _db.deleteOldSyncedEvents(maxAge);
  }

  /// Generate unique ID
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${_randomString(8)}';
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (_) => chars[DateTime.now().microsecond % chars.length]).join();
  }

  /// Dispose
  void dispose() {
    stopSync();
    _syncController.close();
  }
}

/// Sync status for UI updates
abstract class SyncStatus {
  const SyncStatus();
  const factory SyncStatus.idle() = SyncIdle;
  const factory SyncStatus.syncing() = SyncInProgress;
  const factory SyncStatus.completed(SyncResult result) = SyncCompleted;
  const factory SyncStatus.error(String message) = SyncError;
}

class SyncIdle extends SyncStatus {
  const SyncIdle();
}

class SyncInProgress extends SyncStatus {
  const SyncInProgress();
}

class SyncCompleted extends SyncStatus {
  final SyncResult result;
  const SyncCompleted(this.result);
}

class SyncError extends SyncStatus {
  final String message;
  const SyncError(this.message);
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int uploaded;
  final int downloaded;
  final int failed;
  final Duration duration;
  final String? error;

  const SyncResult({
    required this.success,
    required this.uploaded,
    required this.downloaded,
    required this.failed,
    required this.duration,
    this.error,
  });

  SyncResult.alreadyRunning()
      : success = false,
        uploaded = 0,
        downloaded = 0,
        failed = 0,
        duration = Duration.zero,
        error = 'Sync already in progress';

  @override
  String toString() => 'SyncResult(success: $success, uploaded: $uploaded, '
      'downloaded: $downloaded, failed: $failed, duration: ${duration.inMilliseconds}ms)';
}
