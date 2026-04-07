---
name: flutter-database-schema
description: Add new Drift database table with code generation setup
disable-model-invocation: true
---

Add a new Drift database table for {{table_name}}.

Include:
- Table definition in lib/database/drift_local_brain.dart
- Run `dart run build_runner build` to generate code
- Update LocalBrain class with DAO methods
- Add indexes for common query patterns
- Proper foreign key relationships

Follow existing patterns in lib/database/drift_local_brain.dart

Table definition:
```dart
import 'package:drift/drift.dart';

part 'drift_local_brain.g.dart';

/// Table for {{table_purpose}}
class {{TableClassName}} extends Table {
  // Primary key (auto-increment or UUID)
  IntColumn get id => integer().autoIncrement()();
  // OR for UUID:
  // TextColumn get id => text()();

  // Foreign key relationships (if any)
  // TextColumn get userId => text().references(Users, #id)();
  // TextColumn get conversationId => text().references(Conversations, #id)();

  // Columns
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Primary key definition
  @override
  Set<Column> get primaryKey => {id};
  // OR for composite key:
  // @override
  // Set<Column> get primaryKey => {userId, conversationId};

  // Optional: Define indexes
  @override
  List<Set<Column>>? get uniqueKeys => {
    // Example: unique constraint on name + userId
    // {name, userId}
  };

  // Optional: Define indexes
  // Note: Drift 2.x doesn't have direct index() method,
  // indexes are typically defined at the database level
}
```

Update LocalBrain class (in drift_local_brain.dart):
```dart
// In the LocalDatabase class
@override
int get schemaVersion => 1;  // Increment this

@override
List<Table> get allTables => [
  Users,
  Conversations,
  Messages,
  {{TableClassName}},
  // ... other tables
];

// Optional: Migration logic
@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Handle schema upgrades
      if (from < 2) {
        await m.createTable({{TableClassName}});
      }
    },
  );
}

// Add DAO methods
Future<List<{{TableClassName}Data>>> getAll{{TablePlural}}() =>
    select({{TableClassName}}).get();

Future<{{TableClassName}Data?> get{{TableSingular}}ById(int id) =>
    (select({{TableClassName}})..where((t) => t.id.equals(id)))
        .getSingleOrNull();

Future<int> insert{{TableSingular}}({{TableClassName}Companion entry) =>
    into({{TableClassName}}).insert(entry);

Future<bool> update{{TableSingular}}({{TableClassName}Data entry) =>
    update({{TableClassName}}).replace(entry);

Future<int> delete{{TableSingular}}(int id) =>
    (delete({{TableClassName}})..where((t) => t.id.equals(id))).go();
```

Generate code:
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Example query with joins:
```dart
Future<List<{{TableClassName}Data>>> get{{TablePlural}}ByUser(String userId) {
  final query = select({{TableClassName}})
      .join([
    leftOuterJoin(Users, Users.id.equalsExp({{TableClassName}}.userId)),
  ])
    ..where(Users.id.equals(userId));

  return query.get().then((rows) {
    return rows.map((row) => row.readTable({{TableClassName}})).toList();
  });
}
```

Important notes:
- Never edit drift_local_brain.g.dart (auto-generated)
- Increment schemaVersion for breaking changes
- Use .nullable() for optional columns
- Use withLength() constraints on TextColumn
- Use references() for foreign keys
- Add onCreate/onUpgrade handlers for migrations
