import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Opens a web-based database connection (WebAssembly / IndexedDB)
QueryExecutor openConnection() {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: 'local_brain',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );

    if (result.missingFeatures.isNotEmpty) {
      debugPrint(
          'Warning: Missing browser features for Drift: ${result.missingFeatures}');
    }

    return result.resolvedExecutor;
  }));
}
