import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Opens a native SQLite connection (Linux, Windows, Android, iOS)
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'local_brain.sqlite'));

    return NativeDatabase(
      file,
      setup: (db) {
        db.execute('PRAGMA journal_mode = WAL;');
        db.execute('PRAGMA synchronous = NORMAL;');
        db.execute('PRAGMA temp_store = MEMORY;');
        db.execute('PRAGMA cache_size = -65536;'); // 64MB Cache
      },
    );
  });
}
