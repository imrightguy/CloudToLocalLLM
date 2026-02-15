import 'package:drift/drift.dart';

/// Cross-platform database opener
/// Note: Import platform-specific file directly:
///   native.dart for desktop/mobile
///   web.dart for web
QueryExecutor openConnection() {
  throw UnimplementedError(
    'Use platform-specific import: native.dart or web.dart',
  );
}
