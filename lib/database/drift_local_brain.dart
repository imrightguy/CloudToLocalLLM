import 'package:drift/drift.dart';
import 'connection/connection.dart'
    if (dart.library.io) 'connection/native.dart'
    if (dart.library.js_interop) 'connection/web.dart';

part 'drift_local_brain.g.dart';

// ============================================================================
// CORE TABLES
// ============================================================================

/// Table for storing local user identities
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get nickname => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table for tracking conversation threads
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get model => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table for storing actual chat messages
class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  TextColumn get role => text()(); // user, assistant, system
  TextColumn get content => text()();
  TextColumn get model => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

/// Table for logging internal agent activities
class AgentLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get level => text()(); // info, warn, error
  TextColumn get message => text()();
  TextColumn get context => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

// ============================================================================
// SYNC TABLES (Local-Cloud Bridge)
// ============================================================================

/// Table for agents - local cache of remote agents
class Agents extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get agentId => text()(); // Remote agent ID
  TextColumn get type => text().withDefault(const Constant('custom'))();
  TextColumn get status => text().withDefault(const Constant('unknown'))();
  TextColumn get activity => text().nullable()();
  DateTimeColumn get lastUpdate => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table for agent events - mirrors cloud PostgreSQL agent_events
class AgentEvents extends Table {
  TextColumn get id => text()();
  TextColumn get agentId => text()();
  TextColumn get eventType => text()();
  TextColumn get eventData => text()(); // JSON as text
  TextColumn get correlationId => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table for pending sync operations
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get targetTable => text()();
  TextColumn get operation => text()(); // insert, update, delete
  TextColumn get recordId => text()();
  TextColumn get payload => text()(); // JSON payload
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
}

// ============================================================================
// FILE INDEX TABLES (Full Context)
// ============================================================================

/// Table for indexed files - mirrors cloud PostgreSQL file_index
class FileIndex extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  TextColumn get filename => text()();
  TextColumn get extension => text().nullable()();
  IntColumn get size => integer().nullable()();
  DateTimeColumn get modifiedAt => dateTime().nullable()();
  TextColumn get contentHash => text().nullable()();
  TextColumn get mimeType => text().nullable()();
  BoolColumn get isDirectory => boolean().withDefault(const Constant(false))();
  TextColumn get parentPath => text().nullable()();
  DateTimeColumn get indexedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'UNIQUE(path)',
  ];
}

/// Table for file content cache (for small files)
class FileContentCache extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get filePath => text().references(FileIndex, #path)();
  TextColumn get content => text()();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();
}

// ============================================================================
// DATABASE CLASS
// ============================================================================

/// The main Database class for the Local Brain
@DriftDatabase(tables: [
  Users,
  Conversations,
  Messages,
  AgentLogs,
  Agents,
  AgentEvents,
  SyncQueue,
  FileIndex,
  FileContentCache,
])
class LocalBrain extends _$LocalBrain {
  LocalBrain() : super(openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // Add new tables for v2
        await m.createTable(agents);
        await m.createTable(agentEvents);
        await m.createTable(syncQueue);
        await m.createTable(fileIndex);
        await m.createTable(fileContentCache);
      }
    },
  );

  // ==========================================================================
  // CONVERSATION DAO
  // ==========================================================================

  /// Get all conversations for a user
  Future<List<Conversation>> getConversations(String userId) =>
      (select(conversations)..where((t) => t.userId.equals(userId))).get();

  /// Get messages for a specific conversation
  Future<List<Message>> getMessages(String conversationId) =>
      (select(messages)..where((t) => t.conversationId.equals(conversationId))).get();

  /// Insert a new message
  Future<int> addMessage(MessagesCompanion entry) => into(messages).insert(entry);

  /// Create a new conversation
  Future<void> createConversation(ConversationsCompanion entry) =>
      into(conversations).insert(entry);

  // ==========================================================================
  // AGENTS DAO
  // ==========================================================================

  /// Upsert an agent
  Future<void> upsertAgent(AgentsCompanion entry) =>
      into(agents).insert(entry, mode: InsertMode.insertOrReplace);

  /// Get all agents
  Future<List<Agent>> getAllAgents() => select(agents).get();

  /// Get agent by ID
  Future<Agent?> getAgentById(String id) =>
      (select(agents)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Delete old agents
  Future<int> deleteOldAgents(Duration age) async {
    final cutoff = DateTime.now().subtract(age);
    return (delete(agents)
      ..where((t) => t.updatedAt.isSmallerThanValue(cutoff)))
      .go();
  }

  // ==========================================================================
  // AGENT EVENTS DAO (Sync)
  // ==========================================================================

  /// Add an agent event
  Future<void> addAgentEvent(AgentEventsCompanion entry) =>
      into(agentEvents).insert(entry, mode: InsertMode.insertOrReplace);

  /// Get unsynced events
  Future<List<AgentEvent>> getUnsyncedEvents({int limit = 100}) =>
      (select(agentEvents)
        ..where((t) => t.synced.equals(false))
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp)])
        ..limit(limit))
      .get();

  /// Mark events as synced
  Future<void> markEventsSynced(List<String> eventIds) async {
    await (update(agentEvents)
      ..where((t) => t.id.isIn(eventIds)))
      .write(AgentEventsCompanion(
        synced: const Value(true),
        syncedAt: Value(DateTime.now()),
      ));
  }

  /// Get events by type
  Future<List<AgentEvent>> getEventsByType(String eventType, {int limit = 100}) =>
      (select(agentEvents)
        ..where((t) => t.eventType.equals(eventType))
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
        ..limit(limit))
      .get();

  /// Delete old synced events (cleanup)
  Future<int> deleteOldSyncedEvents(Duration age) async {
    final cutoff = DateTime.now().subtract(age);
    return (delete(agentEvents)
      ..where((t) => t.synced.equals(true) & t.timestamp.isSmallerThanValue(cutoff)))
      .go();
  }

  // ==========================================================================
  // FILE INDEX DAO (Full Context)
  // ==========================================================================

  /// Index a file
  Future<void> indexFile(FileIndexCompanion entry) =>
      into(fileIndex).insert(entry, mode: InsertMode.insertOrReplace);

  /// Index multiple files (batch)
  Future<void> indexFilesBatch(List<FileIndexCompanion> entries) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(fileIndex, entries);
    });
  }

  /// Search files by name
  Future<List<FileIndexData>> searchFilesByName(String query, {int limit = 50}) =>
      (select(fileIndex)
        ..where((t) => t.filename.like('%$query%'))
        ..limit(limit))
      .get();

  /// Search files by path
  Future<List<FileIndexData>> searchFilesByPath(String query, {int limit = 50}) =>
      (select(fileIndex)
        ..where((t) => t.path.like('%$query%'))
        ..limit(limit))
      .get();

  /// Get files by extension
  Future<List<FileIndexData>> getFilesByExtension(String ext, {int limit = 100}) =>
      (select(fileIndex)
        ..where((t) => t.extension.equals(ext))
        ..limit(limit))
      .get();

  /// Get indexed file count
  Future<int> getIndexedFileCount() async {
    final result = await select(fileIndex).get();
    return result.length;
  }

  /// Get indexed directory count
  Future<int> getIndexedDirectoryCount() async {
    final result = await (select(fileIndex)
      ..where((t) => t.isDirectory.equals(true)))
      .get();
    return result.length;
  }

  /// Clear file index
  Future<int> clearFileIndex() => delete(fileIndex).go();

  /// Get file by path
  Future<FileIndexData?> getFileByPath(String path) =>
      (select(fileIndex)..where((t) => t.path.equals(path))).getSingleOrNull();

  /// Delete file from index
  Future<int> deleteFileFromIndex(String path) =>
      (delete(fileIndex)..where((t) => t.path.equals(path))).go();

  /// Cache file content
  Future<void> cacheFileContent(String filePath, String content) =>
      into(fileContentCache).insert(
        FileContentCacheCompanion(
          filePath: Value(filePath),
          content: Value(content),
        ),
        mode: InsertMode.insertOrReplace,
      );

  /// Get cached file content
  Future<FileContentCacheData?> getCachedContent(String filePath) =>
      (select(fileContentCache)..where((t) => t.filePath.equals(filePath))).getSingleOrNull();

  /// Clear old cached content
  Future<int> clearOldCache(Duration age) async {
    final cutoff = DateTime.now().subtract(age);
    return (delete(fileContentCache)
      ..where((t) => t.cachedAt.isSmallerThanValue(cutoff)))
      .go();
  }

  // ==========================================================================
  // SYNC QUEUE DAO
  // ==========================================================================

  /// Add to sync queue
  Future<void> enqueueSync(SyncQueueCompanion entry) =>
      into(syncQueue).insert(entry);

  /// Get pending sync items
  Future<List<SyncQueueData>> getPendingSyncItems({int limit = 100}) =>
      (select(syncQueue)
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
        ..limit(limit))
      .get();

  /// Remove from sync queue
  Future<int> dequeueSync(int id) =>
      (delete(syncQueue)..where((t) => t.id.equals(id))).go();

  /// Increment retry count
  Future<void> incrementRetry(int id) async {
    final item = await (select(syncQueue)..where((t) => t.id.equals(id))).getSingle();
    await (update(syncQueue)..where((t) => t.id.equals(id)))
      .write(SyncQueueCompanion(retryCount: Value(item.retryCount + 1)));
  }

  /// Clear old sync queue items
  Future<int> clearOldSyncQueue(Duration age) async {
    final cutoff = DateTime.now().subtract(age);
    return (delete(syncQueue)
      ..where((t) => t.createdAt.isSmallerThanValue(cutoff)))
      .go();
  }

  // ==========================================================================
  // AGENT LOGS DAO
  // ==========================================================================

  /// Log an agent activity
  Future<void> logAgent(String level, String message, {String? context}) =>
      into(agentLogs).insert(AgentLogsCompanion(
        level: Value(level),
        message: Value(message),
        context: Value(context),
      ));

  /// Get recent logs
  Future<List<AgentLog>> getRecentLogs({int limit = 100}) =>
      (select(agentLogs)
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
        ..limit(limit))
      .get();

  /// Get logs by level
  Future<List<AgentLog>> getLogsByLevel(String level, {int limit = 100}) =>
      (select(agentLogs)
        ..where((t) => t.level.equals(level))
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
        ..limit(limit))
      .get();

  /// Clear old logs
  Future<int> clearOldLogs(Duration age) async {
    final cutoff = DateTime.now().subtract(age);
    return (delete(agentLogs)
      ..where((t) => t.timestamp.isSmallerThanValue(cutoff)))
      .go();
  }
}
