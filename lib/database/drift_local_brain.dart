import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
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
// LLM PROVIDER TABLES
// ============================================================================

/// Table for storing configured LLM providers
class LlmProviders extends Table {
  TextColumn get id => text()(); // Unique provider ID (e.g., "openclaw_local")
  TextColumn get name => text()(); // Display name (e.g., "OpenClaw Gateway")
  TextColumn get type => text()(); // Provider type: openclaw, lmstudio, ollama, openai_compatible
  TextColumn get url => text()(); // Full URL (e.g., "http://localhost:18789")
  BoolColumn get isLocal => boolean().withDefault(const Constant(true))();
  BoolColumn get isDefault =>
      boolean().withDefault(const Constant(false))(); // Whether this is the default provider
  TextColumn get version => text().nullable()(); // Provider version (if available)
  TextColumn get config =>
      text().nullable()(); // Additional config as JSON (headers, timeout, etc.)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// RATE LIMIT TABLES
// ============================================================================

/// Table for tracking LLM model capacity and usage
class ModelCapacity extends Table {
  TextColumn get modelId => text()();
  TextColumn get provider => text()(); // zhipu, google, moonshot
  TextColumn get displayName => text().nullable()();
  IntColumn get concurrentUsed => integer().withDefault(const Constant(0))();
  IntColumn get concurrentLimit => integer()();
  IntColumn get tpmUsed => integer().withDefault(const Constant(0))();
  IntColumn get tpmLimit => integer().nullable()();
  IntColumn get rpmUsed => integer().withDefault(const Constant(0))();
  IntColumn get rpmLimit => integer().nullable()();
  DateTimeColumn get lastUpdated =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text()
      .withDefault(const Constant('active'))(); // active, degraded, offline

  @override
  Set<Column> get primaryKey => {modelId};
}

/// Table for tracking LLM requests and queue
class LlmRequests extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get requestId => text()();
  TextColumn get modelId => text().references(ModelCapacity, #modelId)();
  TextColumn get status => text().withDefault(
      const Constant('pending'))(); // pending, active, completed, failed
  IntColumn get promptTokens => integer().nullable()();
  IntColumn get completionTokens => integer().nullable()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();
}

// ============================================================================
// AVATAR AND DESKTOP CONTROL TABLES
// ============================================================================

/// Table for evolving avatar profiles
class AvatarProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get personalityType =>
      text().nullable()(); // e.g., friendly, analytical
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get xp => integer().withDefault(const Constant(0))();
  IntColumn get xpToNextLevel => integer().withDefault(const Constant(100))();
  TextColumn get traits =>
      text().nullable()(); // JSON: {"friendliness": 0.7, ...}
  TextColumn get avatarConfig =>
      text().nullable()(); // JSON config for visual appearance
  DateTimeColumn get lastInteraction => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table for tracking avatar achievements
class Achievements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get avatarId => text().references(AvatarProfiles, #id)();
  TextColumn get achievementId =>
      text()(); // Unique ID for the achievement type
  TextColumn get achievementType => text()(); // e.g., first_chat, power_user
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get unlockedAt => dateTime().nullable()();
  DateTimeColumn get earnedAt => dateTime()
      .withDefault(currentDateAndTime)(); // For backward compatibility

  @override
  Set<Column> get primaryKey => {id};
}

/// Table for avatar memory entries
class AvatarMemoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get avatarId => text().references(AvatarProfiles, #id)();
  TextColumn get memoryType => text()(); // user_preference, interaction_history
  TextColumn get memoryKey => text()();
  TextColumn get memoryValue => text()();
  TextColumn get tags => text().nullable()(); // Comma-separated tags
  IntColumn get importance =>
      integer().withDefault(const Constant(0))(); // 0-100
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime()
      .withDefault(currentDateAndTime)(); // For backward compatibility
  DateTimeColumn get lastAccessed => dateTime()
      .withDefault(currentDateAndTime)(); // For backward compatibility

  @override
  Set<Column> get primaryKey => {id};
}

/// Table for clipboard history (Desktop Control)
class ClipboardHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  TextColumn get contentType => text()(); // text, image, file
  TextColumn get sourceApp => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get copiedAt => dateTime()
      .withDefault(currentDateAndTime)(); // For backward compatibility
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
}

/// Table for action history (Desktop Control)
class ActionHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get actionType => text()(); // click, type, drag
  TextColumn get targetElement => text().nullable()();
  TextColumn get parameters => text().nullable()(); // JSON
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get result => text().nullable()(); // success, error message
}

/// Table for macros (Desktop Control)
class Macros extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get sequence => text()(); // JSON sequence of actions
  TextColumn get triggerType => text()(); // hotkey, voice, schedule
  TextColumn get triggerData => text().nullable()(); // e.g., "Ctrl+Shift+A"
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUsed => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// AVATAR PERSONALITY ENGINE TABLES
// ============================================================================

/// Avatar personality state (OpenClaw-owned)
@DataClassName('AvatarPersonalityProfile')
class AvatarPersonalityProfiles extends Table {
  TextColumn get id => text().withDefault(const Constant('default'))();
  TextColumn get agentName => text().withDefault(const Constant('Agent'))();
  TextColumn get personalityTraits => text()(); // JSON: {formality, humor, enthusiasm, empathy}
  TextColumn get evolutionStage => text().withDefault(const Constant('base'))();
  IntColumn get conversationCount => integer().withDefault(const Constant(0))();
  RealColumn get depthScore => real().withDefault(const Constant(0.0))();
  IntColumn get createdAt => integer().nullable()();
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Evolution history
@DataClassName('EvolutionHistory')
class EvolutionHistoryTable extends Table {
  TextColumn get id => text()();
  TextColumn get avatarId => text().references(AvatarPersonalityProfiles, #id)();
  TextColumn get fromStage => text()();
  TextColumn get toStage => text()();
  TextColumn get triggerReason => text()(); // 'conversation_depth', 'pattern_recognition', 'self_reflection'
  TextColumn get context => text().nullable()(); // What triggered it
  TextColumn get confirmedBy => text()(); // 'agent', 'app', 'collaborative'
  IntColumn get triggeredAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Conversation depth metrics (for evolution tracking)
@DataClassName('ConversationDepthMetric')
class ConversationDepthMetrics extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  RealColumn get complexityScore => real()(); // 0-1: topic diversity, length, reasoning
  RealColumn get emotionalDepth => real()(); // 0-1: empathy, personal sharing
  RealColumn get noveltyScore => real()(); // 0-1: new topics vs repeated
  IntColumn get timestamp => integer()();

  @override
  Set<Column> get primaryKey => {id};
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
  LlmProviders,
  ModelCapacity,
  LlmRequests,
  AvatarProfiles,
  Achievements,
  AvatarMemoryEntries,
  ClipboardHistory,
  ActionHistoryEntries,
  Macros,
  AvatarPersonalityProfiles,
  EvolutionHistoryTable,
  ConversationDepthMetrics,
])
class LocalBrain extends _$LocalBrain {
  LocalBrain() : super(openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _populateInitialRateLimits();
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
          if (from < 3) {
            // Add rate limit tables for v3
            await m.createTable(modelCapacity);
            await m.createTable(llmRequests);
            await _populateInitialRateLimits();
          }
          if (from < 4) {
            // Add avatar and desktop control tables for v4
            await m.createTable(avatarProfiles);
            await m.createTable(achievements);
            await m.createTable(avatarMemoryEntries);
            await m.createTable(clipboardHistory);
            await m.createTable(actionHistoryEntries);
            await m.createTable(macros);
            await _createDefaultAvatarProfile();
          }
          if (from < 5) {
            // Add avatar personality engine tables for v5
            await m.createTable(avatarPersonalityProfiles);
            await m.createTable(evolutionHistoryTable);
            await m.createTable(conversationDepthMetrics);
            await _createDefaultAvatarPersonalityProfile();
          }
        },
      );

  /// Populate initial rate limits
  Future<void> _populateInitialRateLimits() async {
    // GLM (Zhipu)
    await into(modelCapacity).insert(
        ModelCapacityCompanion.insert(
          modelId: 'glm-4-plus',
          provider: 'zhipu',
          displayName: const Value('GLM-4 Plus'),
          concurrentLimit: 20,
        ),
        mode: InsertMode.insertOrIgnore);

    await into(modelCapacity).insert(
        ModelCapacityCompanion.insert(
          modelId: 'glm-4-32b-0414-128k',
          provider: 'zhipu',
          displayName: const Value('GLM-4 32B'),
          concurrentLimit: 15,
        ),
        mode: InsertMode.insertOrIgnore);

    await into(modelCapacity).insert(
        ModelCapacityCompanion.insert(
          modelId: 'glm-4.5',
          provider: 'zhipu',
          displayName: const Value('GLM-4.5'),
          concurrentLimit: 10,
        ),
        mode: InsertMode.insertOrIgnore);

    await into(modelCapacity).insert(
        ModelCapacityCompanion.insert(
          modelId: 'glm-4.7',
          provider: 'zhipu',
          displayName: const Value('GLM-4.7'),
          concurrentLimit: 3,
        ),
        mode: InsertMode.insertOrIgnore);

    await into(modelCapacity).insert(
        ModelCapacityCompanion.insert(
          modelId: 'glm-4.7-flash',
          provider: 'zhipu',
          displayName: const Value('GLM-4.7 Flash'),
          concurrentLimit: 1,
        ),
        mode: InsertMode.insertOrIgnore);

    await into(modelCapacity).insert(
        ModelCapacityCompanion.insert(
          modelId: 'glm-5',
          provider: 'zhipu',
          displayName: const Value('GLM-5'),
          concurrentLimit: 1,
        ),
        mode: InsertMode.insertOrIgnore);

    // Kimi (Moonshot)
    await into(modelCapacity).insert(
        ModelCapacityCompanion.insert(
          modelId: 'kimi-k2.5',
          provider: 'moonshot',
          displayName: const Value('Kimi K2.5'),
          concurrentLimit: 5, // Estimate
        ),
        mode: InsertMode.insertOrIgnore);

    await into(modelCapacity).insert(
        ModelCapacityCompanion.insert(
          modelId: 'kimi-k2-thinking',
          provider: 'moonshot',
          displayName: const Value('Kimi K2 Thinking'),
          concurrentLimit: 3, // Estimate
        ),
        mode: InsertMode.insertOrIgnore);

    // Gemini (Google)
    await into(modelCapacity).insert(
        ModelCapacityCompanion.insert(
          modelId: 'gemini-3-flash',
          provider: 'google',
          displayName: const Value('Gemini 3 Flash'),
          concurrentLimit: 60,
        ),
        mode: InsertMode.insertOrIgnore);

    await into(modelCapacity).insert(
        ModelCapacityCompanion.insert(
          modelId: 'gemini-3-pro',
          provider: 'google',
          displayName: const Value('Gemini 3 Pro'),
          concurrentLimit: 60,
        ),
        mode: InsertMode.insertOrIgnore);
  }

  // ==========================================================================
  // RATE LIMIT DAO
  // ==========================================================================

  /// Get capacity for a model
  Future<ModelCapacityData?> getModelCapacity(String modelId) =>
      (select(modelCapacity)..where((t) => t.modelId.equals(modelId)))
          .getSingleOrNull();

  /// Get all model capacities
  Future<List<ModelCapacityData>> getAllModelCapacities() =>
      select(modelCapacity).get();

  /// Watch all model capacities (for UI gauge)
  Stream<List<ModelCapacityData>> watchAllModelCapacities() =>
      select(modelCapacity).watch();

  /// Update usage
  Future<void> updateUsage(String modelId, int concurrentChange) async {
    // This needs to be a raw query or transaction to be atomic-ish
    // But for Drift/SQLite, a simple read-modify-write in transaction works
    await transaction(() async {
      final model = await (select(modelCapacity)
            ..where((t) => t.modelId.equals(modelId)))
          .getSingle();
      final newUsage = model.concurrentUsed + concurrentChange;

      await (update(modelCapacity)..where((t) => t.modelId.equals(modelId)))
          .write(
        ModelCapacityCompanion(
          concurrentUsed:
              Value(newUsage < 0 ? 0 : newUsage), // Prevent negative
          lastUpdated: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Sync from API header (Trust but Verify)
  Future<void> syncUsageFromHeader(String modelId, int remaining) async {
    await transaction(() async {
      final model = await (select(modelCapacity)
            ..where((t) => t.modelId.equals(modelId)))
          .getSingle();
      // If API says 50 remaining and limit is 60, then used is 10.
      final calculatedUsed = model.concurrentLimit - remaining;

      await (update(modelCapacity)..where((t) => t.modelId.equals(modelId)))
          .write(
        ModelCapacityCompanion(
          concurrentUsed: Value(calculatedUsed < 0 ? 0 : calculatedUsed),
          lastUpdated: Value(DateTime.now()),
        ),
      );
    });
  }

  // ==========================================================================
  // CONVERSATION DAO
  // ==========================================================================

  /// Get all conversations for a user
  Future<List<Conversation>> getConversations(String userId) =>
      (select(conversations)..where((t) => t.userId.equals(userId))).get();

  /// Get messages for a specific conversation
  Future<List<Message>> getMessages(String conversationId) =>
      (select(messages)..where((t) => t.conversationId.equals(conversationId)))
          .get();

  /// Insert a new message
  Future<int> addMessage(MessagesCompanion entry) =>
      into(messages).insert(entry);

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
    await (update(agentEvents)..where((t) => t.id.isIn(eventIds)))
        .write(AgentEventsCompanion(
      synced: const Value(true),
      syncedAt: Value(DateTime.now()),
    ));
  }

  /// Get events by type
  Future<List<AgentEvent>> getEventsByType(String eventType,
          {int limit = 100}) =>
      (select(agentEvents)
            ..where((t) => t.eventType.equals(eventType))
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
            ])
            ..limit(limit))
          .get();

  /// Delete old synced events (cleanup)
  Future<int> deleteOldSyncedEvents(Duration age) async {
    final cutoff = DateTime.now().subtract(age);
    return (delete(agentEvents)
          ..where((t) =>
              t.synced.equals(true) & t.timestamp.isSmallerThanValue(cutoff)))
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
  Future<List<FileIndexData>> searchFilesByName(String query,
          {int limit = 50}) =>
      (select(fileIndex)
            ..where((t) => t.filename.like('%$query%'))
            ..limit(limit))
          .get();

  /// Search files by path
  Future<List<FileIndexData>> searchFilesByPath(String query,
          {int limit = 50}) =>
      (select(fileIndex)
            ..where((t) => t.path.like('%$query%'))
            ..limit(limit))
          .get();

  /// Get files by extension
  Future<List<FileIndexData>> getFilesByExtension(String ext,
          {int limit = 100}) =>
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
      (select(fileContentCache)..where((t) => t.filePath.equals(filePath)))
          .getSingleOrNull();

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
    final item =
        await (select(syncQueue)..where((t) => t.id.equals(id))).getSingle();
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
  Future<List<AgentLog>> getRecentLogs({int limit = 100}) => (select(agentLogs)
        ..orderBy([
          (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
        ])
        ..limit(limit))
      .get();

  /// Get logs by level
  Future<List<AgentLog>> getLogsByLevel(String level, {int limit = 100}) =>
      (select(agentLogs)
            ..where((t) => t.level.equals(level))
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
            ])
            ..limit(limit))
          .get();

  /// Clear old logs
  Future<int> clearOldLogs(Duration age) async {
    final cutoff = DateTime.now().subtract(age);
    return (delete(agentLogs)
          ..where((t) => t.timestamp.isSmallerThanValue(cutoff)))
        .go();
  }

  // ==========================================================================
  // AVATAR DAO
  // ==========================================================================

  /// Get all avatar profiles
  Future<List<AvatarProfile>> getAllAvatarProfiles() =>
      select(avatarProfiles).get();

  /// Get active avatar profile
  Future<AvatarProfile?> getActiveAvatarProfile() async {
    final profiles = await select(avatarProfiles).get();
    return profiles.isNotEmpty ? profiles.first : null;
  }

  /// Create default avatar profile
  Future<void> _createDefaultAvatarProfile() async {
    final existing = await select(avatarProfiles).get();
    if (existing.isEmpty) {
      await into(avatarProfiles).insert(AvatarProfilesCompanion.insert(
        id: 'default-avatar',
        name: 'Avatar',
        level: const Value(1),
        xp: const Value(0),
        xpToNextLevel: const Value(100),
        traits: const Value(
            '{"friendliness":0.7,"curiosity":0.6,"humor":0.5,"formality":0.4,"empathy":0.8}'),
      ));
    }
  }

  /// Update avatar profile
  Future<void> updateAvatarProfile(AvatarProfilesCompanion entry) =>
      into(avatarProfiles).insert(entry, mode: InsertMode.insertOrReplace);

  /// Award XP to avatar
  Future<void> awardXP(int amount) async {
    final profile = await getActiveAvatarProfile();
    if (profile == null) return;

    int newXp = profile.xp + amount;
    int newLevel = profile.level;
    int newXpToNextLevel = profile.xpToNextLevel;

    // Check for level up
    while (newXp >= newXpToNextLevel) {
      newLevel++;
      newXp -= newXpToNextLevel;
      newXpToNextLevel = (newXpToNextLevel * 1.5).toInt();
    }

    await into(avatarProfiles).insert(
      AvatarProfilesCompanion(
        id: Value(profile.id),
        xp: Value(newXp),
        level: Value(newLevel),
        xpToNextLevel: Value(newXpToNextLevel),
        lastInteraction: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  // Achievement DAO

  /// Get all achievements
  Future<List<Achievement>> getAllAchievements() => select(achievements).get();

  /// Get unlocked achievements
  Future<List<Achievement>> getUnlockedAchievements() => (select(achievements)
        ..where((t) => t.unlockedAt.isNotNull())
        ..orderBy([
          (t) => OrderingTerm(expression: t.unlockedAt, mode: OrderingMode.desc)
        ]))
      .get();

  /// Insert achievement
  Future<void> insertAchievement(AchievementsCompanion entry) =>
      into(achievements).insert(entry, mode: InsertMode.insertOrIgnore);

  /// Unlock achievement
  Future<void> unlockAchievement(String achievementId) async {
    final existing = await (select(achievements)
          ..where((t) => t.achievementId.equals(achievementId)))
        .getSingleOrNull();
    if (existing == null) {
      return;
    }
    await (update(achievements)
          ..where((t) => t.achievementId.equals(achievementId)))
        .write(AchievementsCompanion(
      unlockedAt: Value(DateTime.now()),
    ));
  }

  // Avatar Memory DAO

  /// Store avatar memory
  Future<void> insertAvatarMemoryEntry(AvatarMemoryEntriesCompanion entry) =>
      into(avatarMemoryEntries).insert(entry);

  /// Get all avatar memories
  Future<List<AvatarMemoryEntry>> getAllAvatarMemoryEntries() =>
      (select(avatarMemoryEntries)
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
            ]))
          .get();

  /// Search memories by tag
  Future<List<AvatarMemoryEntry>> searchMemoriesByTag(String tag) =>
      (select(avatarMemoryEntries)
            ..where((t) => t.tags.like('%$tag%'))
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
            ]))
          .get();

  /// Delete old memories
  Future<int> deleteOldAvatarMemories(DateTime cutoff) =>
      (delete(avatarMemoryEntries)
            ..where((t) => t.timestamp.isSmallerThanValue(cutoff)))
          .go();

  // ==========================================================================
  // DESKTOP CONTROL DAO
  // ==========================================================================

  // Clipboard History DAO

  /// Insert clipboard entry
  Future<void> insertClipboardEntry(ClipboardHistoryCompanion entry) =>
      into(clipboardHistory).insert(entry);

  /// Get all clipboard entries
  Future<List<ClipboardHistoryData>> getAllClipboardEntries() =>
      (select(clipboardHistory)
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
            ]))
          .get();

  /// Delete clipboard entry
  Future<int> deleteClipboardEntry(int id) =>
      (delete(clipboardHistory)..where((t) => t.id.equals(id))).go();

  /// Clear clipboard history
  Future<int> clearClipboardHistory() => delete(clipboardHistory).go();

  // Action History DAO

  /// Insert action history entry
  Future<void> insertActionHistoryEntry(ActionHistoryEntriesCompanion entry) =>
      into(actionHistoryEntries).insert(entry);

  /// Get all action history entries
  Future<List<ActionHistoryEntry>> getAllActionHistoryEntries() =>
      (select(actionHistoryEntries)
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
            ]))
          .get();

  /// Clear action history
  Future<int> clearActionHistory() => delete(actionHistoryEntries).go();

  // Macros DAO

  /// Insert macro
  Future<void> insertMacro(MacrosCompanion entry) => into(macros).insert(entry);

  /// Get all macros
  Future<List<Macro>> getAllMacros() => select(macros).get();

  /// Get macro by ID
  Future<Macro?> getMacroById(String id) =>
      (select(macros)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Update macro last used
  Future<void> updateMacroLastUsed(String id) =>
      (update(macros)..where((t) => t.id.equals(id))).write(MacrosCompanion(
        lastUsed: Value(DateTime.now()),
      ));

  /// Delete macro
  Future<int> deleteMacro(String id) =>
      (delete(macros)..where((t) => t.id.equals(id))).go();

  // ==========================================================================
  // LLM PROVIDER DAO
  // ==========================================================================

  /// Get all configured providers
  /// Note: This uses raw SQL since the generated code might not be updated yet
  Future<List<dynamic>> getAllProviders() {
    return customSelect(
      'SELECT * FROM llm_providers ORDER BY created_at DESC',
    ).get();
  }

  /// Get provider by ID
  Future<dynamic> getProviderById(String id) {
    return customSelect(
      'SELECT * FROM llm_providers WHERE id = ?',
      variables: [Variable(id)],
    ).getSingleOrNull();
  }

  /// Get default provider
  Future<dynamic> getDefaultProvider() {
    return customSelect(
      'SELECT * FROM llm_providers WHERE is_default = 1 LIMIT 1',
    ).getSingleOrNull();
  }

  /// Get providers by type
  Future<List<dynamic>> getProvidersByType(String type) {
    return customSelect(
      'SELECT * FROM llm_providers WHERE type = ?',
      variables: [Variable(type)],
    ).get();
  }

  /// Insert or update a provider
  Future<void> upsertProvider(Map<String, dynamic> data) {
    final keys = data.keys.join(', ');
    final updates = data.keys
        .where((k) => k != 'created_at')
        .map((k) => '$k = excluded.$k')
        .join(', ');

    final valueList = data.values.toList();
    final placeholders = List.generate(valueList.length, (i) => '?$i').join(', ');

    return customUpdate(
      'INSERT INTO llm_providers ($keys) VALUES ($placeholders) '
      'ON CONFLICT(id) DO UPDATE SET $updates, updated_at = datetime("now")',
      variables: List.generate(valueList.length, (i) => Variable(valueList[i])),
    );
  }

  /// Delete a provider
  Future<int> deleteProvider(String id) {
    return customUpdate(
      'DELETE FROM llm_providers WHERE id = ?',
      variables: [Variable(id)],
    );
  }

  /// Set a provider as default (unsets others)
  Future<void> setDefaultProvider(String id) async {
    await transaction(() async {
      // Unset all existing defaults
      await customUpdate(
        'UPDATE llm_providers SET is_default = 0',
      );

      // Set new default
      await customUpdate(
        'UPDATE llm_providers SET is_default = 1 WHERE id = ?',
        variables: [Variable(id)],
      );
    });
  }

  /// Check if any providers are configured
  Future<bool> hasProviders() async {
    final result = await customSelect(
      'SELECT COUNT(*) as count FROM llm_providers',
    ).getSingle();
    return (result.data['count'] as int) > 0;
  }

  // ==========================================================================
  // AVATAR PERSONALITY ENGINE DAO
  // ==========================================================================

  // Avatar profile operations

  /// Get avatar personality profile
  Future<AvatarPersonalityProfile> getAvatarProfile() async {
    final profiles = await select(avatarPersonalityProfiles).get();
    if (profiles.isEmpty) {
      // Create default profile
      final defaultProfile = AvatarPersonalityProfile(
        id: 'default',
        agentName: 'Agent',
        personalityTraits:
            '{"formality":0.5,"humor":0.5,"enthusiasm":0.5,"empathy":0.5}',
        evolutionStage: 'base',
        conversationCount: 0,
        depthScore: 0.0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await into(avatarPersonalityProfiles).insert(defaultProfile);
      return defaultProfile;
    }
    return profiles.first;
  }

  /// Update avatar personality traits
  Future<void> updateAvatarTraits(Map<String, double> traits) async {
    final json = jsonEncode(traits);
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(avatarPersonalityProfiles)
          ..where((tbl) => tbl.id.equals('default')))
        .write(AvatarPersonalityProfilesCompanion(
      personalityTraits: Value(json),
      updatedAt: Value(now),
    ));
  }

  /// Update agent name
  Future<void> updateAgentName(String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(avatarPersonalityProfiles)
          ..where((tbl) => tbl.id.equals('default')))
        .write(AvatarPersonalityProfilesCompanion(
      agentName: Value(name),
      updatedAt: Value(now),
    ));
  }

  /// Update evolution stage
  Future<void> updateEvolutionStage(String stage) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(avatarPersonalityProfiles)
          ..where((tbl) => tbl.id.equals('default')))
        .write(AvatarPersonalityProfilesCompanion(
      evolutionStage: Value(stage),
      updatedAt: Value(now),
    ));
  }

  /// Create default avatar personality profile
  Future<void> _createDefaultAvatarPersonalityProfile() async {
    final existing = await select(avatarPersonalityProfiles).get();
    if (existing.isEmpty) {
      await into(avatarPersonalityProfiles).insert(
        AvatarPersonalityProfile(
          id: 'default',
          agentName: 'Agent',
          personalityTraits:
              '{"formality":0.5,"humor":0.5,"enthusiasm":0.5,"empathy":0.5}',
          evolutionStage: 'base',
          conversationCount: 0,
          depthScore: 0.0,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  // Evolution history operations

  /// Record evolution event
  Future<void> recordEvolution({
    required String fromStage,
    required String toStage,
    required String triggerReason,
    required String context,
    required String confirmedBy,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await into(evolutionHistoryTable).insert(EvolutionHistoryTableCompanion(
      id: Value(const Uuid().v4()),
      avatarId: const Value('default'),
      fromStage: Value(fromStage),
      toStage: Value(toStage),
      triggerReason: Value(triggerReason),
      context: Value(context),
      confirmedBy: Value(confirmedBy),
      triggeredAt: Value(now),
    ));
  }

  /// Get evolution history
  Future<List<EvolutionHistory>> getEvolutionHistory() async {
    return await (select(evolutionHistoryTable)
          ..orderBy([(t) => OrderingTerm.desc(t.triggeredAt)]))
        .get();
  }

  // Depth metrics operations

  /// Add conversation depth metrics
  Future<void> addConversationDepthMetrics(
          ConversationDepthMetricsCompanion metric) async {
    await into(conversationDepthMetrics).insert(metric);
  }

  /// Get recent depth metrics
  Future<List<ConversationDepthMetric>> getDepthMetrics() async {
    return await (select(conversationDepthMetrics)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(20))
        .get();
  }

  /// Get depth metrics for a specific conversation
  Future<List<ConversationDepthMetric>> getDepthMetricsForConversation(
      String conversationId) async {
    return await (select(conversationDepthMetrics)
          ..where((tbl) => tbl.conversationId.equals(conversationId)))
        .get();
  }
}
