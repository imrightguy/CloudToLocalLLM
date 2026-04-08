import 'package:drift/drift.dart';

// Backend-specific tables that complement existing Flutter schema

/// User identities table for authentication
class BackendUsers extends Table {
  TextColumn get id => text()();
  TextColumn get email => text().unique()();
  TextColumn get jwtId => text().unique().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get nickname => text().nullable()();
  TextColumn get picture => text().nullable()();
  BoolColumn get emailVerified =>
      boolean().withDefault(const Constant(false))();
  TextColumn get locale => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get lastLogin => dateTime().nullable()();
  IntColumn get loginCount => integer().withDefault(const Constant(0))();
  TextColumn get metadata =>
      text().withDefault(const Constant('{}'))(); // JSON as text

  @override
  Set<Column> get primaryKey => {id};
}

/// User sessions table for authentication
class BackendUserSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(BackendUsers, #id)();
  TextColumn get sessionToken => text().unique()();
  TextColumn get jwtTokenHash => text().nullable()();
  TextColumn get jwtAccessToken => text().nullable()();
  TextColumn get jwtIdToken => text().nullable()();
  TextColumn get refreshToken => text().nullable()();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastActivity =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get ipAddress => text().nullable()();
  TextColumn get userAgent => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tunnel connections table
class BackendTunnelConnections extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get tunnelId => text().unique()();
  TextColumn get bridgeId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get connectionType => text().withDefault(const Constant('http'))();
  TextColumn get targetHost => text().nullable()();
  IntColumn get targetPort => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastActivity =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get metadata => text().nullable()(); // JSON as text

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        "CHECK (status IN ('pending', 'active', 'inactive', 'error'))",
        "CHECK (connection_type IN ('http', 'websocket'))"
      ];
}

/// Audit logs table
class BackendAuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text().nullable()();
  TextColumn get action => text()();
  TextColumn get resourceType => text().nullable()();
  TextColumn get resourceId => text().nullable()();
  TextColumn get details =>
      text().withDefault(const Constant('{}'))(); // JSON as text
  TextColumn get ipAddress => text().nullable()();
  TextColumn get userAgent => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get severity => text().withDefault(const Constant('info'))();

  @override
  List<String> get customConstraints =>
      ["CHECK (severity IN ('debug', 'info', 'warn', 'error', 'critical'))"];
}

/// Auth Audit logs table
class BackendAuthAuditLogs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get action => text()();
  TextColumn get eventType => text()();
  TextColumn get details =>
      text().withDefault(const Constant('{}'))(); // JSON as text
  TextColumn get ipAddress => text().nullable()();
  TextColumn get userAgent => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get severity => text().withDefault(const Constant('info'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        "CHECK (event_type IN ('login', 'logout', 'token_refresh', 'token_revoke', 'failed_login', 'password_change', 'session_timeout'))",
        "CHECK (severity IN ('debug', 'info', 'warn', 'error', 'critical'))"
      ];
}

/// API usage tracking
class BackendApiUsage extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get endpoint => text()();
  TextColumn get method => text()();
  IntColumn get statusCode => integer().nullable()();
  IntColumn get responseTimeMs => integer().nullable()();
  IntColumn get requestSizeBytes => integer().nullable()();
  IntColumn get responseSizeBytes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get metadata =>
      text().withDefault(const Constant('{}'))(); // JSON as text
}

/// User preferences
class BackendUserPreferences extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().unique()();
  TextColumn get preferences =>
      text().withDefault(const Constant('{}'))(); // JSON as text
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Conversations table
class BackendConversations extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get model => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get metadata =>
      text().withDefault(const Constant('{}'))(); // JSON as text

  @override
  Set<Column> get primaryKey => {id};
}

/// Messages table
class BackendMessages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(BackendConversations, #id)();
  TextColumn get role => text()();
  TextColumn get content => text()();
  TextColumn get model => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('sent'))();
  TextColumn get error => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get metadata =>
      text().withDefault(const Constant('{}'))(); // JSON as text

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        "CHECK (role IN ('user', 'assistant', 'system'))",
        "CHECK (status IN ('sending', 'sent', 'error'))"
      ];
}
