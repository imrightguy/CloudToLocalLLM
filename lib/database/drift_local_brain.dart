import 'package:drift/drift.dart';
import 'connection/connection.dart'
    if (dart.library.io) 'connection/native.dart'
    if (dart.library.js_interop) 'connection/web.dart';

part 'drift_local_brain.g.dart';

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

/// The main Database class for the Local Brain
@DriftDatabase(tables: [Users, Conversations, Messages, AgentLogs])
class LocalBrain extends _$LocalBrain {
  LocalBrain() : super(openConnection());

  @override
  int get schemaVersion => 1;

  // --- DAO Methods (Simplified for now) ---

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
}
