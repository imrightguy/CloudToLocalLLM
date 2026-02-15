import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import '../database/local_brain.dart';

/// Service for indexing the local file system
/// Mirrors the cloud PostgreSQL file_index table for fast local lookups
class FullContextIndexer {
  final LocalBrain _db;
  bool _isIndexing = false;
  final _progressController = StreamController<IndexingProgress>.broadcast();
  Timer? _watchTimer;

  FullContextIndexer(this._db);

  /// Stream of indexing progress updates
  Stream<IndexingProgress> get progress => _progressController.stream;

  bool get isIndexing => _isIndexing;

  /// Index all files in specified directories
  Future<IndexingResult> indexAllFiles(List<String> directories) async {
    if (_isIndexing) {
      return IndexingResult.alreadyRunning();
    }

    _isIndexing = true;
    _progressController.add(IndexingProgress.started());

    final stopwatch = Stopwatch()..start();
    int totalFiles = 0;
    int totalDirs = 0;
    int errors = 0;

    try {
      debugPrint(
          '[FullContext] Starting full index of ${directories.length} directories...');

      for (final dirPath in directories) {
        final dir = Directory(dirPath);
        if (!await dir.exists()) {
          debugPrint('[FullContext] Directory not found: $dirPath');
          continue;
        }

        await for (final entity
            in dir.list(recursive: true, followLinks: false)) {
          try {
            if (entity is File) {
              await _indexFile(entity);
              totalFiles++;

              // Emit progress every 100 files
              if (totalFiles % 100 == 0) {
                _progressController.add(IndexingProgress.inProgress(
                  filesProcessed: totalFiles,
                  directoriesProcessed: totalDirs,
                ));
              }
            } else if (entity is Directory) {
              await _indexDirectory(entity);
              totalDirs++;
            }
          } catch (e) {
            errors++;
            if (errors <= 10) {
              debugPrint('[FullContext] Error indexing ${entity.path}: $e');
            }
          }
        }
      }

      stopwatch.stop();
      debugPrint(
          '[FullContext] Indexing completed: $totalFiles files, $totalDirs dirs in ${stopwatch.elapsed}');

      final result = IndexingResult(
        success: true,
        filesIndexed: totalFiles,
        directoriesIndexed: totalDirs,
        errors: errors,
        duration: stopwatch.elapsed,
      );
      _progressController.add(IndexingProgress.completed(result));
      return result;
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint('[FullContext] Indexing failed: $e');
      debugPrint('[FullContext] Stack: $stack');

      final result = IndexingResult(
        success: false,
        filesIndexed: totalFiles,
        directoriesIndexed: totalDirs,
        errors: errors + 1,
        duration: stopwatch.elapsed,
        error: e.toString(),
      );
      _progressController.add(IndexingProgress.error(e.toString()));
      return result;
    } finally {
      _isIndexing = false;
    }
  }

  /// Index a single file
  Future<void> _indexFile(File file) async {
    final stat = await file.stat();
    final path = file.path;
    final filename = path.split(Platform.pathSeparator).last;
    final ext =
        filename.contains('.') ? filename.split('.').last.toLowerCase() : null;
    final parentPath = path.substring(0, path.length - filename.length - 1);

    // Calculate content hash for small files (< 10MB)
    String? contentHash;
    if (stat.size < 10 * 1024 * 1024) {
      try {
        final bytes = await file.readAsBytes();
        contentHash = sha256.convert(bytes).toString();
      } catch (e) {
        // Ignore hash errors for unreadable files
      }
    }

    await _db.indexFile(FileIndexCompanion(
      path: Value(path),
      filename: Value(filename),
      extension: Value(ext),
      size: Value(stat.size),
      modifiedAt: Value(stat.modified),
      contentHash: Value(contentHash),
      mimeType: Value(_getMimeType(ext)),
      isDirectory: const Value(false),
      parentPath: Value(parentPath),
    ));
  }

  /// Index a directory
  Future<void> _indexDirectory(Directory dir) async {
    final stat = await dir.stat();
    final path = dir.path;
    final name = path.split(Platform.pathSeparator).last;
    final parentPath = path.substring(0, path.length - name.length - 1);

    await _db.indexFile(FileIndexCompanion(
      path: Value(path),
      filename: Value(name),
      extension: const Value(null),
      size: const Value(null),
      modifiedAt: Value(stat.modified),
      contentHash: const Value(null),
      mimeType: const Value('inode/directory'),
      isDirectory: const Value(true),
      parentPath: Value(parentPath),
    ));
  }

  /// Perform incremental scan (only modified files)
  Future<IndexingResult> performIncrementalScan(
      List<String> directories) async {
    debugPrint('[FullContext] Starting incremental scan...');

    final stopwatch = Stopwatch()..start();
    int updated = 0;
    int removed = 0;

    try {
      // Get all indexed paths
      final indexedCount = await _db.getIndexedFileCount();
      debugPrint('[FullContext] Current index: $indexedCount entries');

      // Check each indexed file still exists and is up to date
      // Note: This is simplified - for large indexes we'd need batching

      for (final dirPath in directories) {
        final dir = Directory(dirPath);
        if (!await dir.exists()) continue;

        await for (final entity
            in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final existing = await _db.getFileByPath(entity.path);
            final stat = await entity.stat();

            // Update if new or modified
            if (existing == null ||
                existing.modifiedAt?.isBefore(stat.modified) != false) {
              await _indexFile(entity);
              updated++;
            }
          }
        }
      }

      stopwatch.stop();
      debugPrint(
          '[FullContext] Incremental scan completed: $updated updated, $removed removed');

      return IndexingResult(
        success: true,
        filesIndexed: updated,
        directoriesIndexed: 0,
        errors: 0,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('[FullContext] Incremental scan failed: $e');
      return IndexingResult(
        success: false,
        filesIndexed: updated,
        directoriesIndexed: 0,
        errors: 1,
        duration: stopwatch.elapsed,
        error: e.toString(),
      );
    }
  }

  /// Get indexed file count
  Future<int> getIndexedFileCount() async {
    return _db.getIndexedFileCount();
  }

  /// Get indexed directory count
  Future<int> getIndexedDirectoryCount() async {
    return _db.getIndexedDirectoryCount();
  }

  /// Search indexed files by name
  Future<List<FileSearchResult>> searchFiles(String query,
      {int limit = 50}) async {
    final results = await _db.searchFilesByName(query, limit: limit);
    return results
        .map((f) => FileSearchResult(
              path: f.path,
              filename: f.filename,
              isDirectory: f.isDirectory,
              size: f.size,
              modifiedAt: f.modifiedAt,
            ))
        .toList();
  }

  /// Search indexed files by path pattern
  Future<List<FileSearchResult>> searchByPath(String pattern,
      {int limit = 50}) async {
    final results = await _db.searchFilesByPath(pattern, limit: limit);
    return results
        .map((f) => FileSearchResult(
              path: f.path,
              filename: f.filename,
              isDirectory: f.isDirectory,
              size: f.size,
              modifiedAt: f.modifiedAt,
            ))
        .toList();
  }

  /// Get files by extension
  Future<List<FileSearchResult>> getFilesByExtension(String ext,
      {int limit = 100}) async {
    final results =
        await _db.getFilesByExtension(ext.toLowerCase(), limit: limit);
    return results
        .map((f) => FileSearchResult(
              path: f.path,
              filename: f.filename,
              isDirectory: f.isDirectory,
              size: f.size,
              modifiedAt: f.modifiedAt,
            ))
        .toList();
  }

  /// Clear file index
  Future<int> clearIndex() async {
    debugPrint('[FullContext] Clearing file index...');
    final count = await _db.clearFileIndex();
    debugPrint('[FullContext] Cleared $count entries');
    return count;
  }

  /// Cache file content for small files
  Future<void> cacheFileContent(String filePath,
      {int maxSize = 1024 * 1024}) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    final stat = await file.stat();
    if (stat.size > maxSize) return;

    try {
      final content = await file.readAsString();
      await _db.cacheFileContent(filePath, content);
    } catch (e) {
      // Ignore binary files or encoding errors
    }
  }

  /// Get cached file content
  Future<String?> getCachedContent(String filePath) async {
    final cached = await _db.getCachedContent(filePath);
    return cached?.content;
  }

  /// Clear old cache entries
  Future<int> clearOldCache({Duration maxAge = const Duration(days: 1)}) async {
    return _db.clearOldCache(maxAge);
  }

  /// Start watching directories for changes (periodic scan)
  void startWatching(List<String> directories,
      {Duration interval = const Duration(minutes: 5)}) {
    stopWatching();
    debugPrint(
        '[FullContext] Starting directory watch (interval: ${interval.inMinutes}m)');

    _watchTimer = Timer.periodic(interval, (_) async {
      if (!_isIndexing) {
        await performIncrementalScan(directories);
      }
    });
  }

  /// Stop watching directories
  void stopWatching() {
    _watchTimer?.cancel();
    _watchTimer = null;
  }

  /// Get mime type from extension
  String? _getMimeType(String? ext) {
    if (ext == null) return null;

    final mimeTypes = {
      'dart': 'application/vnd.dart',
      'json': 'application/json',
      'yaml': 'application/x-yaml',
      'yml': 'application/x-yaml',
      'md': 'text/markdown',
      'txt': 'text/plain',
      'html': 'text/html',
      'css': 'text/css',
      'js': 'application/javascript',
      'ts': 'application/typescript',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'zip': 'application/zip',
      'tar': 'application/x-tar',
      'gz': 'application/gzip',
    };

    return mimeTypes[ext.toLowerCase()];
  }

  /// Dispose
  void dispose() {
    stopWatching();
    _progressController.close();
  }
}

/// Indexing progress for UI updates
abstract class IndexingProgress {
  const IndexingProgress();
  const factory IndexingProgress.started() = IndexingStarted;
  const factory IndexingProgress.inProgress({
    required int filesProcessed,
    required int directoriesProcessed,
  }) = IndexingInProgress;
  const factory IndexingProgress.completed(IndexingResult result) =
      IndexingCompleted;
  const factory IndexingProgress.error(String message) = IndexingError;
}

class IndexingStarted extends IndexingProgress {
  const IndexingStarted();
}

class IndexingInProgress extends IndexingProgress {
  final int filesProcessed;
  final int directoriesProcessed;
  const IndexingInProgress({
    required this.filesProcessed,
    required this.directoriesProcessed,
  });
}

class IndexingCompleted extends IndexingProgress {
  final IndexingResult result;
  const IndexingCompleted(this.result);
}

class IndexingError extends IndexingProgress {
  final String message;
  const IndexingError(this.message);
}

/// Result of an indexing operation
class IndexingResult {
  final bool success;
  final int filesIndexed;
  final int directoriesIndexed;
  final int errors;
  final Duration duration;
  final String? error;

  const IndexingResult({
    required this.success,
    required this.filesIndexed,
    required this.directoriesIndexed,
    required this.errors,
    required this.duration,
    this.error,
  });

  IndexingResult.alreadyRunning()
      : success = false,
        filesIndexed = 0,
        directoriesIndexed = 0,
        errors = 0,
        duration = Duration.zero,
        error = 'Indexing already in progress';

  @override
  String toString() =>
      'IndexingResult(success: $success, files: $filesIndexed, '
      'dirs: $directoriesIndexed, errors: $errors, duration: ${duration.inSeconds}s)';
}

/// File search result
class FileSearchResult {
  final String path;
  final String filename;
  final bool isDirectory;
  final int? size;
  final DateTime? modifiedAt;

  const FileSearchResult({
    required this.path,
    required this.filename,
    required this.isDirectory,
    this.size,
    this.modifiedAt,
  });

  @override
  String toString() =>
      isDirectory ? '📁 $filename/' : '📄 $filename (${_formatSize(size)})';

  static String _formatSize(int? bytes) {
    if (bytes == null) return '?';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
