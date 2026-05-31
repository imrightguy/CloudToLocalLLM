// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_local_brain.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nicknameMeta =
      const VerificationMeta('nickname');
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
      'nickname', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, email, name, nickname, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(Insertable<User> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('nickname')) {
      context.handle(_nicknameMeta,
          nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name']),
      nickname: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nickname']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final String id;
  final String? email;
  final String? name;
  final String? nickname;
  final DateTime createdAt;
  const User(
      {required this.id,
      this.email,
      this.name,
      this.nickname,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || nickname != null) {
      map['nickname'] = Variable<String>(nickname);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      nickname: nickname == null && nullToAbsent
          ? const Value.absent()
          : Value(nickname),
      createdAt: Value(createdAt),
    );
  }

  factory User.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<String>(json['id']),
      email: serializer.fromJson<String?>(json['email']),
      name: serializer.fromJson<String?>(json['name']),
      nickname: serializer.fromJson<String?>(json['nickname']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'email': serializer.toJson<String?>(email),
      'name': serializer.toJson<String?>(name),
      'nickname': serializer.toJson<String?>(nickname),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  User copyWith(
          {String? id,
          Value<String?> email = const Value.absent(),
          Value<String?> name = const Value.absent(),
          Value<String?> nickname = const Value.absent(),
          DateTime? createdAt}) =>
      User(
        id: id ?? this.id,
        email: email.present ? email.value : this.email,
        name: name.present ? name.value : this.name,
        nickname: nickname.present ? nickname.value : this.nickname,
        createdAt: createdAt ?? this.createdAt,
      );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      name: data.name.present ? data.name.value : this.name,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('name: $name, ')
          ..write('nickname: $nickname, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, email, name, nickname, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.email == this.email &&
          other.name == this.name &&
          other.nickname == this.nickname &&
          other.createdAt == this.createdAt);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<String> id;
  final Value<String?> email;
  final Value<String?> name;
  final Value<String?> nickname;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.name = const Value.absent(),
    this.nickname = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String id,
    this.email = const Value.absent(),
    this.name = const Value.absent(),
    this.nickname = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<User> custom({
    Expression<String>? id,
    Expression<String>? email,
    Expression<String>? name,
    Expression<String>? nickname,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (name != null) 'name': name,
      if (nickname != null) 'nickname': nickname,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith(
      {Value<String>? id,
      Value<String?>? email,
      Value<String?>? name,
      Value<String?>? nickname,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return UsersCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('name: $name, ')
          ..write('nickname: $nickname, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES users (id)'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
      'model', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, userId, title, model, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(Insertable<Conversation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
          _modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      model: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final String id;
  final String userId;
  final String title;
  final String model;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Conversation(
      {required this.id,
      required this.userId,
      required this.title,
      required this.model,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['title'] = Variable<String>(title);
    map['model'] = Variable<String>(model);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      userId: Value(userId),
      title: Value(title),
      model: Value(model),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Conversation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      title: serializer.fromJson<String>(json['title']),
      model: serializer.fromJson<String>(json['model']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'title': serializer.toJson<String>(title),
      'model': serializer.toJson<String>(model),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Conversation copyWith(
          {String? id,
          String? userId,
          String? title,
          String? model,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Conversation(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        model: model ?? this.model,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      title: data.title.present ? data.title.value : this.title,
      model: data.model.present ? data.model.value : this.model,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('title: $title, ')
          ..write('model: $model, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, title, model, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.title == this.title &&
          other.model == this.model &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> title;
  final Value<String> model;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.title = const Value.absent(),
    this.model = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    required String userId,
    required String title,
    required String model,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        title = Value(title),
        model = Value(model);
  static Insertable<Conversation> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? title,
    Expression<String>? model,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (title != null) 'title': title,
      if (model != null) 'model': model,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? title,
      Value<String>? model,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ConversationsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('title: $title, ')
          ..write('model: $model, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES conversations (id)'));
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
      'model', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, conversationId, role, content, model, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<Message> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
          _modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      model: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final int id;
  final String conversationId;
  final String role;
  final String content;
  final String? model;
  final DateTime timestamp;
  const Message(
      {required this.id,
      required this.conversationId,
      required this.role,
      required this.content,
      this.model,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      role: Value(role),
      content: Value(content),
      model:
          model == null && nullToAbsent ? const Value.absent() : Value(model),
      timestamp: Value(timestamp),
    );
  }

  factory Message.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<int>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      model: serializer.fromJson<String?>(json['model']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'model': serializer.toJson<String?>(model),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  Message copyWith(
          {int? id,
          String? conversationId,
          String? role,
          String? content,
          Value<String?> model = const Value.absent(),
          DateTime? timestamp}) =>
      Message(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        role: role ?? this.role,
        content: content ?? this.content,
        model: model.present ? model.value : this.model,
        timestamp: timestamp ?? this.timestamp,
      );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      model: data.model.present ? data.model.value : this.model,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('model: $model, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, conversationId, role, content, model, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.role == this.role &&
          other.content == this.content &&
          other.model == this.model &&
          other.timestamp == this.timestamp);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<int> id;
  final Value<String> conversationId;
  final Value<String> role;
  final Value<String> content;
  final Value<String?> model;
  final Value<DateTime> timestamp;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.model = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required String conversationId,
    required String role,
    required String content,
    this.model = const Value.absent(),
    this.timestamp = const Value.absent(),
  })  : conversationId = Value(conversationId),
        role = Value(role),
        content = Value(content);
  static Insertable<Message> custom({
    Expression<int>? id,
    Expression<String>? conversationId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? model,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (model != null) 'model': model,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  MessagesCompanion copyWith(
      {Value<int>? id,
      Value<String>? conversationId,
      Value<String>? role,
      Value<String>? content,
      Value<String?>? model,
      Value<DateTime>? timestamp}) {
    return MessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      model: model ?? this.model,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('model: $model, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $MainChatTimelineRecordsTable extends MainChatTimelineRecords
    with TableInfo<$MainChatTimelineRecordsTable, MainChatTimelineDbRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MainChatTimelineRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
      'event_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _revisionMeta =
      const VerificationMeta('revision');
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
      'revision', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sourceDeviceIdMeta =
      const VerificationMeta('sourceDeviceId');
  @override
  late final GeneratedColumn<String> sourceDeviceId = GeneratedColumn<String>(
      'source_device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceSequenceMeta =
      const VerificationMeta('sourceSequence');
  @override
  late final GeneratedColumn<int> sourceSequence = GeneratedColumn<int>(
      'source_sequence', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
      'scope', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _eventTypeMeta =
      const VerificationMeta('eventType');
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
      'event_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceKindMeta =
      const VerificationMeta('sourceKind');
  @override
  late final GeneratedColumn<String> sourceKind = GeneratedColumn<String>(
      'source_kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceIdMeta =
      const VerificationMeta('sourceId');
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
      'source_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampUtcMeta =
      const VerificationMeta('timestampUtc');
  @override
  late final GeneratedColumn<DateTime> timestampUtc = GeneratedColumn<DateTime>(
      'timestamp_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _observedAtUtcMeta =
      const VerificationMeta('observedAtUtc');
  @override
  late final GeneratedColumn<DateTime> observedAtUtc =
      GeneratedColumn<DateTime>('observed_at_utc', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _summaryMeta =
      const VerificationMeta('summary');
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
      'summary', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bodyRedactedMeta =
      const VerificationMeta('bodyRedacted');
  @override
  late final GeneratedColumn<String> bodyRedacted = GeneratedColumn<String>(
      'body_redacted', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _artifactNameMeta =
      const VerificationMeta('artifactName');
  @override
  late final GeneratedColumn<String> artifactName = GeneratedColumn<String>(
      'artifact_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _localArtifactPathMeta =
      const VerificationMeta('localArtifactPath');
  @override
  late final GeneratedColumn<String> localArtifactPath =
      GeneratedColumn<String>('local_artifact_path', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _safeMetadataJsonMeta =
      const VerificationMeta('safeMetadataJson');
  @override
  late final GeneratedColumn<String> safeMetadataJson = GeneratedColumn<String>(
      'safe_metadata_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localOnlyMetadataJsonMeta =
      const VerificationMeta('localOnlyMetadataJson');
  @override
  late final GeneratedColumn<String> localOnlyMetadataJson =
      GeneratedColumn<String>('local_only_metadata_json', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _syncPolicyMeta =
      const VerificationMeta('syncPolicy');
  @override
  late final GeneratedColumn<String> syncPolicy = GeneratedColumn<String>(
      'sync_policy', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sensitivityMeta =
      const VerificationMeta('sensitivity');
  @override
  late final GeneratedColumn<String> sensitivity = GeneratedColumn<String>(
      'sensitivity', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _redactionVersionMeta =
      const VerificationMeta('redactionVersion');
  @override
  late final GeneratedColumn<int> redactionVersion = GeneratedColumn<int>(
      'redaction_version', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _payloadVersionMeta =
      const VerificationMeta('payloadVersion');
  @override
  late final GeneratedColumn<int> payloadVersion = GeneratedColumn<int>(
      'payload_version', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        recordId,
        eventId,
        revision,
        sourceDeviceId,
        sourceSequence,
        scope,
        conversationId,
        eventType,
        sourceKind,
        sourceId,
        timestampUtc,
        observedAtUtc,
        title,
        summary,
        bodyRedacted,
        artifactName,
        localArtifactPath,
        safeMetadataJson,
        localOnlyMetadataJson,
        syncPolicy,
        sensitivity,
        redactionVersion,
        payloadVersion
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'main_chat_timeline_records';
  @override
  VerificationContext validateIntegrity(
      Insertable<MainChatTimelineDbRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(_revisionMeta,
          revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta));
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('source_device_id')) {
      context.handle(
          _sourceDeviceIdMeta,
          sourceDeviceId.isAcceptableOrUnknown(
              data['source_device_id']!, _sourceDeviceIdMeta));
    } else if (isInserting) {
      context.missing(_sourceDeviceIdMeta);
    }
    if (data.containsKey('source_sequence')) {
      context.handle(
          _sourceSequenceMeta,
          sourceSequence.isAcceptableOrUnknown(
              data['source_sequence']!, _sourceSequenceMeta));
    } else if (isInserting) {
      context.missing(_sourceSequenceMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
          _scopeMeta, scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta));
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    }
    if (data.containsKey('event_type')) {
      context.handle(_eventTypeMeta,
          eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta));
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('source_kind')) {
      context.handle(
          _sourceKindMeta,
          sourceKind.isAcceptableOrUnknown(
              data['source_kind']!, _sourceKindMeta));
    } else if (isInserting) {
      context.missing(_sourceKindMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta,
          sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    }
    if (data.containsKey('timestamp_utc')) {
      context.handle(
          _timestampUtcMeta,
          timestampUtc.isAcceptableOrUnknown(
              data['timestamp_utc']!, _timestampUtcMeta));
    } else if (isInserting) {
      context.missing(_timestampUtcMeta);
    }
    if (data.containsKey('observed_at_utc')) {
      context.handle(
          _observedAtUtcMeta,
          observedAtUtc.isAcceptableOrUnknown(
              data['observed_at_utc']!, _observedAtUtcMeta));
    } else if (isInserting) {
      context.missing(_observedAtUtcMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(_summaryMeta,
          summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta));
    }
    if (data.containsKey('body_redacted')) {
      context.handle(
          _bodyRedactedMeta,
          bodyRedacted.isAcceptableOrUnknown(
              data['body_redacted']!, _bodyRedactedMeta));
    }
    if (data.containsKey('artifact_name')) {
      context.handle(
          _artifactNameMeta,
          artifactName.isAcceptableOrUnknown(
              data['artifact_name']!, _artifactNameMeta));
    }
    if (data.containsKey('local_artifact_path')) {
      context.handle(
          _localArtifactPathMeta,
          localArtifactPath.isAcceptableOrUnknown(
              data['local_artifact_path']!, _localArtifactPathMeta));
    }
    if (data.containsKey('safe_metadata_json')) {
      context.handle(
          _safeMetadataJsonMeta,
          safeMetadataJson.isAcceptableOrUnknown(
              data['safe_metadata_json']!, _safeMetadataJsonMeta));
    } else if (isInserting) {
      context.missing(_safeMetadataJsonMeta);
    }
    if (data.containsKey('local_only_metadata_json')) {
      context.handle(
          _localOnlyMetadataJsonMeta,
          localOnlyMetadataJson.isAcceptableOrUnknown(
              data['local_only_metadata_json']!, _localOnlyMetadataJsonMeta));
    } else if (isInserting) {
      context.missing(_localOnlyMetadataJsonMeta);
    }
    if (data.containsKey('sync_policy')) {
      context.handle(
          _syncPolicyMeta,
          syncPolicy.isAcceptableOrUnknown(
              data['sync_policy']!, _syncPolicyMeta));
    } else if (isInserting) {
      context.missing(_syncPolicyMeta);
    }
    if (data.containsKey('sensitivity')) {
      context.handle(
          _sensitivityMeta,
          sensitivity.isAcceptableOrUnknown(
              data['sensitivity']!, _sensitivityMeta));
    } else if (isInserting) {
      context.missing(_sensitivityMeta);
    }
    if (data.containsKey('redaction_version')) {
      context.handle(
          _redactionVersionMeta,
          redactionVersion.isAcceptableOrUnknown(
              data['redaction_version']!, _redactionVersionMeta));
    } else if (isInserting) {
      context.missing(_redactionVersionMeta);
    }
    if (data.containsKey('payload_version')) {
      context.handle(
          _payloadVersionMeta,
          payloadVersion.isAcceptableOrUnknown(
              data['payload_version']!, _payloadVersionMeta));
    } else if (isInserting) {
      context.missing(_payloadVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recordId};
  @override
  MainChatTimelineDbRecord map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MainChatTimelineDbRecord(
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_id'])!,
      revision: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}revision'])!,
      sourceDeviceId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}source_device_id'])!,
      sourceSequence: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}source_sequence'])!,
      scope: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope'])!,
      conversationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}conversation_id']),
      eventType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_type'])!,
      sourceKind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_kind'])!,
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_id']),
      timestampUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}timestamp_utc'])!,
      observedAtUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}observed_at_utc'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      summary: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}summary']),
      bodyRedacted: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body_redacted']),
      artifactName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artifact_name']),
      localArtifactPath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}local_artifact_path']),
      safeMetadataJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}safe_metadata_json'])!,
      localOnlyMetadataJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}local_only_metadata_json'])!,
      syncPolicy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_policy'])!,
      sensitivity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sensitivity'])!,
      redactionVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}redaction_version'])!,
      payloadVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}payload_version'])!,
    );
  }

  @override
  $MainChatTimelineRecordsTable createAlias(String alias) {
    return $MainChatTimelineRecordsTable(attachedDatabase, alias);
  }
}

class MainChatTimelineDbRecord extends DataClass
    implements Insertable<MainChatTimelineDbRecord> {
  final String recordId;
  final String eventId;
  final int revision;
  final String sourceDeviceId;
  final int sourceSequence;
  final String scope;
  final String? conversationId;
  final String eventType;
  final String sourceKind;
  final String? sourceId;
  final DateTime timestampUtc;
  final DateTime observedAtUtc;
  final String title;
  final String? summary;
  final String? bodyRedacted;
  final String? artifactName;
  final String? localArtifactPath;
  final String safeMetadataJson;
  final String localOnlyMetadataJson;
  final String syncPolicy;
  final String sensitivity;
  final int redactionVersion;
  final int payloadVersion;
  const MainChatTimelineDbRecord(
      {required this.recordId,
      required this.eventId,
      required this.revision,
      required this.sourceDeviceId,
      required this.sourceSequence,
      required this.scope,
      this.conversationId,
      required this.eventType,
      required this.sourceKind,
      this.sourceId,
      required this.timestampUtc,
      required this.observedAtUtc,
      required this.title,
      this.summary,
      this.bodyRedacted,
      this.artifactName,
      this.localArtifactPath,
      required this.safeMetadataJson,
      required this.localOnlyMetadataJson,
      required this.syncPolicy,
      required this.sensitivity,
      required this.redactionVersion,
      required this.payloadVersion});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['record_id'] = Variable<String>(recordId);
    map['event_id'] = Variable<String>(eventId);
    map['revision'] = Variable<int>(revision);
    map['source_device_id'] = Variable<String>(sourceDeviceId);
    map['source_sequence'] = Variable<int>(sourceSequence);
    map['scope'] = Variable<String>(scope);
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<String>(conversationId);
    }
    map['event_type'] = Variable<String>(eventType);
    map['source_kind'] = Variable<String>(sourceKind);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    map['timestamp_utc'] = Variable<DateTime>(timestampUtc);
    map['observed_at_utc'] = Variable<DateTime>(observedAtUtc);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || bodyRedacted != null) {
      map['body_redacted'] = Variable<String>(bodyRedacted);
    }
    if (!nullToAbsent || artifactName != null) {
      map['artifact_name'] = Variable<String>(artifactName);
    }
    if (!nullToAbsent || localArtifactPath != null) {
      map['local_artifact_path'] = Variable<String>(localArtifactPath);
    }
    map['safe_metadata_json'] = Variable<String>(safeMetadataJson);
    map['local_only_metadata_json'] = Variable<String>(localOnlyMetadataJson);
    map['sync_policy'] = Variable<String>(syncPolicy);
    map['sensitivity'] = Variable<String>(sensitivity);
    map['redaction_version'] = Variable<int>(redactionVersion);
    map['payload_version'] = Variable<int>(payloadVersion);
    return map;
  }

  MainChatTimelineRecordsCompanion toCompanion(bool nullToAbsent) {
    return MainChatTimelineRecordsCompanion(
      recordId: Value(recordId),
      eventId: Value(eventId),
      revision: Value(revision),
      sourceDeviceId: Value(sourceDeviceId),
      sourceSequence: Value(sourceSequence),
      scope: Value(scope),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
      eventType: Value(eventType),
      sourceKind: Value(sourceKind),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      timestampUtc: Value(timestampUtc),
      observedAtUtc: Value(observedAtUtc),
      title: Value(title),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      bodyRedacted: bodyRedacted == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyRedacted),
      artifactName: artifactName == null && nullToAbsent
          ? const Value.absent()
          : Value(artifactName),
      localArtifactPath: localArtifactPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localArtifactPath),
      safeMetadataJson: Value(safeMetadataJson),
      localOnlyMetadataJson: Value(localOnlyMetadataJson),
      syncPolicy: Value(syncPolicy),
      sensitivity: Value(sensitivity),
      redactionVersion: Value(redactionVersion),
      payloadVersion: Value(payloadVersion),
    );
  }

  factory MainChatTimelineDbRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MainChatTimelineDbRecord(
      recordId: serializer.fromJson<String>(json['recordId']),
      eventId: serializer.fromJson<String>(json['eventId']),
      revision: serializer.fromJson<int>(json['revision']),
      sourceDeviceId: serializer.fromJson<String>(json['sourceDeviceId']),
      sourceSequence: serializer.fromJson<int>(json['sourceSequence']),
      scope: serializer.fromJson<String>(json['scope']),
      conversationId: serializer.fromJson<String?>(json['conversationId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      sourceKind: serializer.fromJson<String>(json['sourceKind']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      timestampUtc: serializer.fromJson<DateTime>(json['timestampUtc']),
      observedAtUtc: serializer.fromJson<DateTime>(json['observedAtUtc']),
      title: serializer.fromJson<String>(json['title']),
      summary: serializer.fromJson<String?>(json['summary']),
      bodyRedacted: serializer.fromJson<String?>(json['bodyRedacted']),
      artifactName: serializer.fromJson<String?>(json['artifactName']),
      localArtifactPath:
          serializer.fromJson<String?>(json['localArtifactPath']),
      safeMetadataJson: serializer.fromJson<String>(json['safeMetadataJson']),
      localOnlyMetadataJson:
          serializer.fromJson<String>(json['localOnlyMetadataJson']),
      syncPolicy: serializer.fromJson<String>(json['syncPolicy']),
      sensitivity: serializer.fromJson<String>(json['sensitivity']),
      redactionVersion: serializer.fromJson<int>(json['redactionVersion']),
      payloadVersion: serializer.fromJson<int>(json['payloadVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recordId': serializer.toJson<String>(recordId),
      'eventId': serializer.toJson<String>(eventId),
      'revision': serializer.toJson<int>(revision),
      'sourceDeviceId': serializer.toJson<String>(sourceDeviceId),
      'sourceSequence': serializer.toJson<int>(sourceSequence),
      'scope': serializer.toJson<String>(scope),
      'conversationId': serializer.toJson<String?>(conversationId),
      'eventType': serializer.toJson<String>(eventType),
      'sourceKind': serializer.toJson<String>(sourceKind),
      'sourceId': serializer.toJson<String?>(sourceId),
      'timestampUtc': serializer.toJson<DateTime>(timestampUtc),
      'observedAtUtc': serializer.toJson<DateTime>(observedAtUtc),
      'title': serializer.toJson<String>(title),
      'summary': serializer.toJson<String?>(summary),
      'bodyRedacted': serializer.toJson<String?>(bodyRedacted),
      'artifactName': serializer.toJson<String?>(artifactName),
      'localArtifactPath': serializer.toJson<String?>(localArtifactPath),
      'safeMetadataJson': serializer.toJson<String>(safeMetadataJson),
      'localOnlyMetadataJson': serializer.toJson<String>(localOnlyMetadataJson),
      'syncPolicy': serializer.toJson<String>(syncPolicy),
      'sensitivity': serializer.toJson<String>(sensitivity),
      'redactionVersion': serializer.toJson<int>(redactionVersion),
      'payloadVersion': serializer.toJson<int>(payloadVersion),
    };
  }

  MainChatTimelineDbRecord copyWith(
          {String? recordId,
          String? eventId,
          int? revision,
          String? sourceDeviceId,
          int? sourceSequence,
          String? scope,
          Value<String?> conversationId = const Value.absent(),
          String? eventType,
          String? sourceKind,
          Value<String?> sourceId = const Value.absent(),
          DateTime? timestampUtc,
          DateTime? observedAtUtc,
          String? title,
          Value<String?> summary = const Value.absent(),
          Value<String?> bodyRedacted = const Value.absent(),
          Value<String?> artifactName = const Value.absent(),
          Value<String?> localArtifactPath = const Value.absent(),
          String? safeMetadataJson,
          String? localOnlyMetadataJson,
          String? syncPolicy,
          String? sensitivity,
          int? redactionVersion,
          int? payloadVersion}) =>
      MainChatTimelineDbRecord(
        recordId: recordId ?? this.recordId,
        eventId: eventId ?? this.eventId,
        revision: revision ?? this.revision,
        sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
        sourceSequence: sourceSequence ?? this.sourceSequence,
        scope: scope ?? this.scope,
        conversationId:
            conversationId.present ? conversationId.value : this.conversationId,
        eventType: eventType ?? this.eventType,
        sourceKind: sourceKind ?? this.sourceKind,
        sourceId: sourceId.present ? sourceId.value : this.sourceId,
        timestampUtc: timestampUtc ?? this.timestampUtc,
        observedAtUtc: observedAtUtc ?? this.observedAtUtc,
        title: title ?? this.title,
        summary: summary.present ? summary.value : this.summary,
        bodyRedacted:
            bodyRedacted.present ? bodyRedacted.value : this.bodyRedacted,
        artifactName:
            artifactName.present ? artifactName.value : this.artifactName,
        localArtifactPath: localArtifactPath.present
            ? localArtifactPath.value
            : this.localArtifactPath,
        safeMetadataJson: safeMetadataJson ?? this.safeMetadataJson,
        localOnlyMetadataJson:
            localOnlyMetadataJson ?? this.localOnlyMetadataJson,
        syncPolicy: syncPolicy ?? this.syncPolicy,
        sensitivity: sensitivity ?? this.sensitivity,
        redactionVersion: redactionVersion ?? this.redactionVersion,
        payloadVersion: payloadVersion ?? this.payloadVersion,
      );
  MainChatTimelineDbRecord copyWithCompanion(
      MainChatTimelineRecordsCompanion data) {
    return MainChatTimelineDbRecord(
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      revision: data.revision.present ? data.revision.value : this.revision,
      sourceDeviceId: data.sourceDeviceId.present
          ? data.sourceDeviceId.value
          : this.sourceDeviceId,
      sourceSequence: data.sourceSequence.present
          ? data.sourceSequence.value
          : this.sourceSequence,
      scope: data.scope.present ? data.scope.value : this.scope,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      sourceKind:
          data.sourceKind.present ? data.sourceKind.value : this.sourceKind,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      timestampUtc: data.timestampUtc.present
          ? data.timestampUtc.value
          : this.timestampUtc,
      observedAtUtc: data.observedAtUtc.present
          ? data.observedAtUtc.value
          : this.observedAtUtc,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      bodyRedacted: data.bodyRedacted.present
          ? data.bodyRedacted.value
          : this.bodyRedacted,
      artifactName: data.artifactName.present
          ? data.artifactName.value
          : this.artifactName,
      localArtifactPath: data.localArtifactPath.present
          ? data.localArtifactPath.value
          : this.localArtifactPath,
      safeMetadataJson: data.safeMetadataJson.present
          ? data.safeMetadataJson.value
          : this.safeMetadataJson,
      localOnlyMetadataJson: data.localOnlyMetadataJson.present
          ? data.localOnlyMetadataJson.value
          : this.localOnlyMetadataJson,
      syncPolicy:
          data.syncPolicy.present ? data.syncPolicy.value : this.syncPolicy,
      sensitivity:
          data.sensitivity.present ? data.sensitivity.value : this.sensitivity,
      redactionVersion: data.redactionVersion.present
          ? data.redactionVersion.value
          : this.redactionVersion,
      payloadVersion: data.payloadVersion.present
          ? data.payloadVersion.value
          : this.payloadVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MainChatTimelineDbRecord(')
          ..write('recordId: $recordId, ')
          ..write('eventId: $eventId, ')
          ..write('revision: $revision, ')
          ..write('sourceDeviceId: $sourceDeviceId, ')
          ..write('sourceSequence: $sourceSequence, ')
          ..write('scope: $scope, ')
          ..write('conversationId: $conversationId, ')
          ..write('eventType: $eventType, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceId: $sourceId, ')
          ..write('timestampUtc: $timestampUtc, ')
          ..write('observedAtUtc: $observedAtUtc, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('bodyRedacted: $bodyRedacted, ')
          ..write('artifactName: $artifactName, ')
          ..write('localArtifactPath: $localArtifactPath, ')
          ..write('safeMetadataJson: $safeMetadataJson, ')
          ..write('localOnlyMetadataJson: $localOnlyMetadataJson, ')
          ..write('syncPolicy: $syncPolicy, ')
          ..write('sensitivity: $sensitivity, ')
          ..write('redactionVersion: $redactionVersion, ')
          ..write('payloadVersion: $payloadVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        recordId,
        eventId,
        revision,
        sourceDeviceId,
        sourceSequence,
        scope,
        conversationId,
        eventType,
        sourceKind,
        sourceId,
        timestampUtc,
        observedAtUtc,
        title,
        summary,
        bodyRedacted,
        artifactName,
        localArtifactPath,
        safeMetadataJson,
        localOnlyMetadataJson,
        syncPolicy,
        sensitivity,
        redactionVersion,
        payloadVersion
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MainChatTimelineDbRecord &&
          other.recordId == this.recordId &&
          other.eventId == this.eventId &&
          other.revision == this.revision &&
          other.sourceDeviceId == this.sourceDeviceId &&
          other.sourceSequence == this.sourceSequence &&
          other.scope == this.scope &&
          other.conversationId == this.conversationId &&
          other.eventType == this.eventType &&
          other.sourceKind == this.sourceKind &&
          other.sourceId == this.sourceId &&
          other.timestampUtc == this.timestampUtc &&
          other.observedAtUtc == this.observedAtUtc &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.bodyRedacted == this.bodyRedacted &&
          other.artifactName == this.artifactName &&
          other.localArtifactPath == this.localArtifactPath &&
          other.safeMetadataJson == this.safeMetadataJson &&
          other.localOnlyMetadataJson == this.localOnlyMetadataJson &&
          other.syncPolicy == this.syncPolicy &&
          other.sensitivity == this.sensitivity &&
          other.redactionVersion == this.redactionVersion &&
          other.payloadVersion == this.payloadVersion);
}

class MainChatTimelineRecordsCompanion
    extends UpdateCompanion<MainChatTimelineDbRecord> {
  final Value<String> recordId;
  final Value<String> eventId;
  final Value<int> revision;
  final Value<String> sourceDeviceId;
  final Value<int> sourceSequence;
  final Value<String> scope;
  final Value<String?> conversationId;
  final Value<String> eventType;
  final Value<String> sourceKind;
  final Value<String?> sourceId;
  final Value<DateTime> timestampUtc;
  final Value<DateTime> observedAtUtc;
  final Value<String> title;
  final Value<String?> summary;
  final Value<String?> bodyRedacted;
  final Value<String?> artifactName;
  final Value<String?> localArtifactPath;
  final Value<String> safeMetadataJson;
  final Value<String> localOnlyMetadataJson;
  final Value<String> syncPolicy;
  final Value<String> sensitivity;
  final Value<int> redactionVersion;
  final Value<int> payloadVersion;
  final Value<int> rowid;
  const MainChatTimelineRecordsCompanion({
    this.recordId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.revision = const Value.absent(),
    this.sourceDeviceId = const Value.absent(),
    this.sourceSequence = const Value.absent(),
    this.scope = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.timestampUtc = const Value.absent(),
    this.observedAtUtc = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.bodyRedacted = const Value.absent(),
    this.artifactName = const Value.absent(),
    this.localArtifactPath = const Value.absent(),
    this.safeMetadataJson = const Value.absent(),
    this.localOnlyMetadataJson = const Value.absent(),
    this.syncPolicy = const Value.absent(),
    this.sensitivity = const Value.absent(),
    this.redactionVersion = const Value.absent(),
    this.payloadVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MainChatTimelineRecordsCompanion.insert({
    required String recordId,
    required String eventId,
    required int revision,
    required String sourceDeviceId,
    required int sourceSequence,
    required String scope,
    this.conversationId = const Value.absent(),
    required String eventType,
    required String sourceKind,
    this.sourceId = const Value.absent(),
    required DateTime timestampUtc,
    required DateTime observedAtUtc,
    required String title,
    this.summary = const Value.absent(),
    this.bodyRedacted = const Value.absent(),
    this.artifactName = const Value.absent(),
    this.localArtifactPath = const Value.absent(),
    required String safeMetadataJson,
    required String localOnlyMetadataJson,
    required String syncPolicy,
    required String sensitivity,
    required int redactionVersion,
    required int payloadVersion,
    this.rowid = const Value.absent(),
  })  : recordId = Value(recordId),
        eventId = Value(eventId),
        revision = Value(revision),
        sourceDeviceId = Value(sourceDeviceId),
        sourceSequence = Value(sourceSequence),
        scope = Value(scope),
        eventType = Value(eventType),
        sourceKind = Value(sourceKind),
        timestampUtc = Value(timestampUtc),
        observedAtUtc = Value(observedAtUtc),
        title = Value(title),
        safeMetadataJson = Value(safeMetadataJson),
        localOnlyMetadataJson = Value(localOnlyMetadataJson),
        syncPolicy = Value(syncPolicy),
        sensitivity = Value(sensitivity),
        redactionVersion = Value(redactionVersion),
        payloadVersion = Value(payloadVersion);
  static Insertable<MainChatTimelineDbRecord> custom({
    Expression<String>? recordId,
    Expression<String>? eventId,
    Expression<int>? revision,
    Expression<String>? sourceDeviceId,
    Expression<int>? sourceSequence,
    Expression<String>? scope,
    Expression<String>? conversationId,
    Expression<String>? eventType,
    Expression<String>? sourceKind,
    Expression<String>? sourceId,
    Expression<DateTime>? timestampUtc,
    Expression<DateTime>? observedAtUtc,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? bodyRedacted,
    Expression<String>? artifactName,
    Expression<String>? localArtifactPath,
    Expression<String>? safeMetadataJson,
    Expression<String>? localOnlyMetadataJson,
    Expression<String>? syncPolicy,
    Expression<String>? sensitivity,
    Expression<int>? redactionVersion,
    Expression<int>? payloadVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recordId != null) 'record_id': recordId,
      if (eventId != null) 'event_id': eventId,
      if (revision != null) 'revision': revision,
      if (sourceDeviceId != null) 'source_device_id': sourceDeviceId,
      if (sourceSequence != null) 'source_sequence': sourceSequence,
      if (scope != null) 'scope': scope,
      if (conversationId != null) 'conversation_id': conversationId,
      if (eventType != null) 'event_type': eventType,
      if (sourceKind != null) 'source_kind': sourceKind,
      if (sourceId != null) 'source_id': sourceId,
      if (timestampUtc != null) 'timestamp_utc': timestampUtc,
      if (observedAtUtc != null) 'observed_at_utc': observedAtUtc,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (bodyRedacted != null) 'body_redacted': bodyRedacted,
      if (artifactName != null) 'artifact_name': artifactName,
      if (localArtifactPath != null) 'local_artifact_path': localArtifactPath,
      if (safeMetadataJson != null) 'safe_metadata_json': safeMetadataJson,
      if (localOnlyMetadataJson != null)
        'local_only_metadata_json': localOnlyMetadataJson,
      if (syncPolicy != null) 'sync_policy': syncPolicy,
      if (sensitivity != null) 'sensitivity': sensitivity,
      if (redactionVersion != null) 'redaction_version': redactionVersion,
      if (payloadVersion != null) 'payload_version': payloadVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MainChatTimelineRecordsCompanion copyWith(
      {Value<String>? recordId,
      Value<String>? eventId,
      Value<int>? revision,
      Value<String>? sourceDeviceId,
      Value<int>? sourceSequence,
      Value<String>? scope,
      Value<String?>? conversationId,
      Value<String>? eventType,
      Value<String>? sourceKind,
      Value<String?>? sourceId,
      Value<DateTime>? timestampUtc,
      Value<DateTime>? observedAtUtc,
      Value<String>? title,
      Value<String?>? summary,
      Value<String?>? bodyRedacted,
      Value<String?>? artifactName,
      Value<String?>? localArtifactPath,
      Value<String>? safeMetadataJson,
      Value<String>? localOnlyMetadataJson,
      Value<String>? syncPolicy,
      Value<String>? sensitivity,
      Value<int>? redactionVersion,
      Value<int>? payloadVersion,
      Value<int>? rowid}) {
    return MainChatTimelineRecordsCompanion(
      recordId: recordId ?? this.recordId,
      eventId: eventId ?? this.eventId,
      revision: revision ?? this.revision,
      sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
      sourceSequence: sourceSequence ?? this.sourceSequence,
      scope: scope ?? this.scope,
      conversationId: conversationId ?? this.conversationId,
      eventType: eventType ?? this.eventType,
      sourceKind: sourceKind ?? this.sourceKind,
      sourceId: sourceId ?? this.sourceId,
      timestampUtc: timestampUtc ?? this.timestampUtc,
      observedAtUtc: observedAtUtc ?? this.observedAtUtc,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      bodyRedacted: bodyRedacted ?? this.bodyRedacted,
      artifactName: artifactName ?? this.artifactName,
      localArtifactPath: localArtifactPath ?? this.localArtifactPath,
      safeMetadataJson: safeMetadataJson ?? this.safeMetadataJson,
      localOnlyMetadataJson:
          localOnlyMetadataJson ?? this.localOnlyMetadataJson,
      syncPolicy: syncPolicy ?? this.syncPolicy,
      sensitivity: sensitivity ?? this.sensitivity,
      redactionVersion: redactionVersion ?? this.redactionVersion,
      payloadVersion: payloadVersion ?? this.payloadVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (sourceDeviceId.present) {
      map['source_device_id'] = Variable<String>(sourceDeviceId.value);
    }
    if (sourceSequence.present) {
      map['source_sequence'] = Variable<int>(sourceSequence.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (sourceKind.present) {
      map['source_kind'] = Variable<String>(sourceKind.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (timestampUtc.present) {
      map['timestamp_utc'] = Variable<DateTime>(timestampUtc.value);
    }
    if (observedAtUtc.present) {
      map['observed_at_utc'] = Variable<DateTime>(observedAtUtc.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (bodyRedacted.present) {
      map['body_redacted'] = Variable<String>(bodyRedacted.value);
    }
    if (artifactName.present) {
      map['artifact_name'] = Variable<String>(artifactName.value);
    }
    if (localArtifactPath.present) {
      map['local_artifact_path'] = Variable<String>(localArtifactPath.value);
    }
    if (safeMetadataJson.present) {
      map['safe_metadata_json'] = Variable<String>(safeMetadataJson.value);
    }
    if (localOnlyMetadataJson.present) {
      map['local_only_metadata_json'] =
          Variable<String>(localOnlyMetadataJson.value);
    }
    if (syncPolicy.present) {
      map['sync_policy'] = Variable<String>(syncPolicy.value);
    }
    if (sensitivity.present) {
      map['sensitivity'] = Variable<String>(sensitivity.value);
    }
    if (redactionVersion.present) {
      map['redaction_version'] = Variable<int>(redactionVersion.value);
    }
    if (payloadVersion.present) {
      map['payload_version'] = Variable<int>(payloadVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MainChatTimelineRecordsCompanion(')
          ..write('recordId: $recordId, ')
          ..write('eventId: $eventId, ')
          ..write('revision: $revision, ')
          ..write('sourceDeviceId: $sourceDeviceId, ')
          ..write('sourceSequence: $sourceSequence, ')
          ..write('scope: $scope, ')
          ..write('conversationId: $conversationId, ')
          ..write('eventType: $eventType, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceId: $sourceId, ')
          ..write('timestampUtc: $timestampUtc, ')
          ..write('observedAtUtc: $observedAtUtc, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('bodyRedacted: $bodyRedacted, ')
          ..write('artifactName: $artifactName, ')
          ..write('localArtifactPath: $localArtifactPath, ')
          ..write('safeMetadataJson: $safeMetadataJson, ')
          ..write('localOnlyMetadataJson: $localOnlyMetadataJson, ')
          ..write('syncPolicy: $syncPolicy, ')
          ..write('sensitivity: $sensitivity, ')
          ..write('redactionVersion: $redactionVersion, ')
          ..write('payloadVersion: $payloadVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentLogsTable extends AgentLogs
    with TableInfo<$AgentLogsTable, AgentLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
      'level', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageMeta =
      const VerificationMeta('message');
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
      'message', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contextMeta =
      const VerificationMeta('context');
  @override
  late final GeneratedColumn<String> context = GeneratedColumn<String>(
      'context', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, level, message, context, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_logs';
  @override
  VerificationContext validateIntegrity(Insertable<AgentLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('level')) {
      context.handle(
          _levelMeta, level.isAcceptableOrUnknown(data['level']!, _levelMeta));
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('message')) {
      context.handle(_messageMeta,
          message.isAcceptableOrUnknown(data['message']!, _messageMeta));
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('context')) {
      context.handle(_contextMeta,
          this.context.isAcceptableOrUnknown(data['context']!, _contextMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgentLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      level: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}level'])!,
      message: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message'])!,
      context: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}context']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $AgentLogsTable createAlias(String alias) {
    return $AgentLogsTable(attachedDatabase, alias);
  }
}

class AgentLog extends DataClass implements Insertable<AgentLog> {
  final int id;
  final String level;
  final String message;
  final String? context;
  final DateTime timestamp;
  const AgentLog(
      {required this.id,
      required this.level,
      required this.message,
      this.context,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['level'] = Variable<String>(level);
    map['message'] = Variable<String>(message);
    if (!nullToAbsent || context != null) {
      map['context'] = Variable<String>(context);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  AgentLogsCompanion toCompanion(bool nullToAbsent) {
    return AgentLogsCompanion(
      id: Value(id),
      level: Value(level),
      message: Value(message),
      context: context == null && nullToAbsent
          ? const Value.absent()
          : Value(context),
      timestamp: Value(timestamp),
    );
  }

  factory AgentLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentLog(
      id: serializer.fromJson<int>(json['id']),
      level: serializer.fromJson<String>(json['level']),
      message: serializer.fromJson<String>(json['message']),
      context: serializer.fromJson<String?>(json['context']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'level': serializer.toJson<String>(level),
      'message': serializer.toJson<String>(message),
      'context': serializer.toJson<String?>(context),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  AgentLog copyWith(
          {int? id,
          String? level,
          String? message,
          Value<String?> context = const Value.absent(),
          DateTime? timestamp}) =>
      AgentLog(
        id: id ?? this.id,
        level: level ?? this.level,
        message: message ?? this.message,
        context: context.present ? context.value : this.context,
        timestamp: timestamp ?? this.timestamp,
      );
  AgentLog copyWithCompanion(AgentLogsCompanion data) {
    return AgentLog(
      id: data.id.present ? data.id.value : this.id,
      level: data.level.present ? data.level.value : this.level,
      message: data.message.present ? data.message.value : this.message,
      context: data.context.present ? data.context.value : this.context,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentLog(')
          ..write('id: $id, ')
          ..write('level: $level, ')
          ..write('message: $message, ')
          ..write('context: $context, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, level, message, context, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentLog &&
          other.id == this.id &&
          other.level == this.level &&
          other.message == this.message &&
          other.context == this.context &&
          other.timestamp == this.timestamp);
}

class AgentLogsCompanion extends UpdateCompanion<AgentLog> {
  final Value<int> id;
  final Value<String> level;
  final Value<String> message;
  final Value<String?> context;
  final Value<DateTime> timestamp;
  const AgentLogsCompanion({
    this.id = const Value.absent(),
    this.level = const Value.absent(),
    this.message = const Value.absent(),
    this.context = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  AgentLogsCompanion.insert({
    this.id = const Value.absent(),
    required String level,
    required String message,
    this.context = const Value.absent(),
    this.timestamp = const Value.absent(),
  })  : level = Value(level),
        message = Value(message);
  static Insertable<AgentLog> custom({
    Expression<int>? id,
    Expression<String>? level,
    Expression<String>? message,
    Expression<String>? context,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (level != null) 'level': level,
      if (message != null) 'message': message,
      if (context != null) 'context': context,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  AgentLogsCompanion copyWith(
      {Value<int>? id,
      Value<String>? level,
      Value<String>? message,
      Value<String?>? context,
      Value<DateTime>? timestamp}) {
    return AgentLogsCompanion(
      id: id ?? this.id,
      level: level ?? this.level,
      message: message ?? this.message,
      context: context ?? this.context,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (context.present) {
      map['context'] = Variable<String>(context.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentLogsCompanion(')
          ..write('id: $id, ')
          ..write('level: $level, ')
          ..write('message: $message, ')
          ..write('context: $context, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $AgentsTable extends Agents with TableInfo<$AgentsTable, Agent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _agentIdMeta =
      const VerificationMeta('agentId');
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
      'agent_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('custom'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('unknown'));
  static const VerificationMeta _activityMeta =
      const VerificationMeta('activity');
  @override
  late final GeneratedColumn<String> activity = GeneratedColumn<String>(
      'activity', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastUpdateMeta =
      const VerificationMeta('lastUpdate');
  @override
  late final GeneratedColumn<DateTime> lastUpdate = GeneratedColumn<DateTime>(
      'last_update', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, agentId, type, status, activity, lastUpdate, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agents';
  @override
  VerificationContext validateIntegrity(Insertable<Agent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('agent_id')) {
      context.handle(_agentIdMeta,
          agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta));
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('activity')) {
      context.handle(_activityMeta,
          activity.isAcceptableOrUnknown(data['activity']!, _activityMeta));
    }
    if (data.containsKey('last_update')) {
      context.handle(
          _lastUpdateMeta,
          lastUpdate.isAcceptableOrUnknown(
              data['last_update']!, _lastUpdateMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Agent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Agent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      agentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}agent_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      activity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}activity']),
      lastUpdate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_update']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AgentsTable createAlias(String alias) {
    return $AgentsTable(attachedDatabase, alias);
  }
}

class Agent extends DataClass implements Insertable<Agent> {
  final String id;
  final String name;
  final String agentId;
  final String type;
  final String status;
  final String? activity;
  final DateTime? lastUpdate;
  final DateTime updatedAt;
  const Agent(
      {required this.id,
      required this.name,
      required this.agentId,
      required this.type,
      required this.status,
      this.activity,
      this.lastUpdate,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['agent_id'] = Variable<String>(agentId);
    map['type'] = Variable<String>(type);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || activity != null) {
      map['activity'] = Variable<String>(activity);
    }
    if (!nullToAbsent || lastUpdate != null) {
      map['last_update'] = Variable<DateTime>(lastUpdate);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AgentsCompanion toCompanion(bool nullToAbsent) {
    return AgentsCompanion(
      id: Value(id),
      name: Value(name),
      agentId: Value(agentId),
      type: Value(type),
      status: Value(status),
      activity: activity == null && nullToAbsent
          ? const Value.absent()
          : Value(activity),
      lastUpdate: lastUpdate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdate),
      updatedAt: Value(updatedAt),
    );
  }

  factory Agent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Agent(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      agentId: serializer.fromJson<String>(json['agentId']),
      type: serializer.fromJson<String>(json['type']),
      status: serializer.fromJson<String>(json['status']),
      activity: serializer.fromJson<String?>(json['activity']),
      lastUpdate: serializer.fromJson<DateTime?>(json['lastUpdate']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'agentId': serializer.toJson<String>(agentId),
      'type': serializer.toJson<String>(type),
      'status': serializer.toJson<String>(status),
      'activity': serializer.toJson<String?>(activity),
      'lastUpdate': serializer.toJson<DateTime?>(lastUpdate),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Agent copyWith(
          {String? id,
          String? name,
          String? agentId,
          String? type,
          String? status,
          Value<String?> activity = const Value.absent(),
          Value<DateTime?> lastUpdate = const Value.absent(),
          DateTime? updatedAt}) =>
      Agent(
        id: id ?? this.id,
        name: name ?? this.name,
        agentId: agentId ?? this.agentId,
        type: type ?? this.type,
        status: status ?? this.status,
        activity: activity.present ? activity.value : this.activity,
        lastUpdate: lastUpdate.present ? lastUpdate.value : this.lastUpdate,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Agent copyWithCompanion(AgentsCompanion data) {
    return Agent(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      activity: data.activity.present ? data.activity.value : this.activity,
      lastUpdate:
          data.lastUpdate.present ? data.lastUpdate.value : this.lastUpdate,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Agent(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('agentId: $agentId, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('activity: $activity, ')
          ..write('lastUpdate: $lastUpdate, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, agentId, type, status, activity, lastUpdate, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Agent &&
          other.id == this.id &&
          other.name == this.name &&
          other.agentId == this.agentId &&
          other.type == this.type &&
          other.status == this.status &&
          other.activity == this.activity &&
          other.lastUpdate == this.lastUpdate &&
          other.updatedAt == this.updatedAt);
}

class AgentsCompanion extends UpdateCompanion<Agent> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> agentId;
  final Value<String> type;
  final Value<String> status;
  final Value<String?> activity;
  final Value<DateTime?> lastUpdate;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AgentsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.agentId = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.activity = const Value.absent(),
    this.lastUpdate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentsCompanion.insert({
    required String id,
    required String name,
    required String agentId,
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.activity = const Value.absent(),
    this.lastUpdate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        agentId = Value(agentId);
  static Insertable<Agent> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? agentId,
    Expression<String>? type,
    Expression<String>? status,
    Expression<String>? activity,
    Expression<DateTime>? lastUpdate,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (agentId != null) 'agent_id': agentId,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (activity != null) 'activity': activity,
      if (lastUpdate != null) 'last_update': lastUpdate,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? agentId,
      Value<String>? type,
      Value<String>? status,
      Value<String?>? activity,
      Value<DateTime?>? lastUpdate,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return AgentsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      agentId: agentId ?? this.agentId,
      type: type ?? this.type,
      status: status ?? this.status,
      activity: activity ?? this.activity,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (activity.present) {
      map['activity'] = Variable<String>(activity.value);
    }
    if (lastUpdate.present) {
      map['last_update'] = Variable<DateTime>(lastUpdate.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('agentId: $agentId, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('activity: $activity, ')
          ..write('lastUpdate: $lastUpdate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentEventsTable extends AgentEvents
    with TableInfo<$AgentEventsTable, AgentEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _agentIdMeta =
      const VerificationMeta('agentId');
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
      'agent_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventTypeMeta =
      const VerificationMeta('eventType');
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
      'event_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventDataMeta =
      const VerificationMeta('eventData');
  @override
  late final GeneratedColumn<String> eventData = GeneratedColumn<String>(
      'event_data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _correlationIdMeta =
      const VerificationMeta('correlationId');
  @override
  late final GeneratedColumn<String> correlationId = GeneratedColumn<String>(
      'correlation_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        agentId,
        eventType,
        eventData,
        correlationId,
        timestamp,
        synced,
        syncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_events';
  @override
  VerificationContext validateIntegrity(Insertable<AgentEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('agent_id')) {
      context.handle(_agentIdMeta,
          agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta));
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(_eventTypeMeta,
          eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta));
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('event_data')) {
      context.handle(_eventDataMeta,
          eventData.isAcceptableOrUnknown(data['event_data']!, _eventDataMeta));
    } else if (isInserting) {
      context.missing(_eventDataMeta);
    }
    if (data.containsKey('correlation_id')) {
      context.handle(
          _correlationIdMeta,
          correlationId.isAcceptableOrUnknown(
              data['correlation_id']!, _correlationIdMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgentEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      agentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}agent_id'])!,
      eventType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_type'])!,
      eventData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_data'])!,
      correlationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}correlation_id']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
    );
  }

  @override
  $AgentEventsTable createAlias(String alias) {
    return $AgentEventsTable(attachedDatabase, alias);
  }
}

class AgentEvent extends DataClass implements Insertable<AgentEvent> {
  final String id;
  final String agentId;
  final String eventType;
  final String eventData;
  final String? correlationId;
  final DateTime timestamp;
  final bool synced;
  final DateTime? syncedAt;
  const AgentEvent(
      {required this.id,
      required this.agentId,
      required this.eventType,
      required this.eventData,
      this.correlationId,
      required this.timestamp,
      required this.synced,
      this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['agent_id'] = Variable<String>(agentId);
    map['event_type'] = Variable<String>(eventType);
    map['event_data'] = Variable<String>(eventData);
    if (!nullToAbsent || correlationId != null) {
      map['correlation_id'] = Variable<String>(correlationId);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  AgentEventsCompanion toCompanion(bool nullToAbsent) {
    return AgentEventsCompanion(
      id: Value(id),
      agentId: Value(agentId),
      eventType: Value(eventType),
      eventData: Value(eventData),
      correlationId: correlationId == null && nullToAbsent
          ? const Value.absent()
          : Value(correlationId),
      timestamp: Value(timestamp),
      synced: Value(synced),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory AgentEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentEvent(
      id: serializer.fromJson<String>(json['id']),
      agentId: serializer.fromJson<String>(json['agentId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      eventData: serializer.fromJson<String>(json['eventData']),
      correlationId: serializer.fromJson<String?>(json['correlationId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      synced: serializer.fromJson<bool>(json['synced']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'agentId': serializer.toJson<String>(agentId),
      'eventType': serializer.toJson<String>(eventType),
      'eventData': serializer.toJson<String>(eventData),
      'correlationId': serializer.toJson<String?>(correlationId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'synced': serializer.toJson<bool>(synced),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  AgentEvent copyWith(
          {String? id,
          String? agentId,
          String? eventType,
          String? eventData,
          Value<String?> correlationId = const Value.absent(),
          DateTime? timestamp,
          bool? synced,
          Value<DateTime?> syncedAt = const Value.absent()}) =>
      AgentEvent(
        id: id ?? this.id,
        agentId: agentId ?? this.agentId,
        eventType: eventType ?? this.eventType,
        eventData: eventData ?? this.eventData,
        correlationId:
            correlationId.present ? correlationId.value : this.correlationId,
        timestamp: timestamp ?? this.timestamp,
        synced: synced ?? this.synced,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
      );
  AgentEvent copyWithCompanion(AgentEventsCompanion data) {
    return AgentEvent(
      id: data.id.present ? data.id.value : this.id,
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      eventData: data.eventData.present ? data.eventData.value : this.eventData,
      correlationId: data.correlationId.present
          ? data.correlationId.value
          : this.correlationId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      synced: data.synced.present ? data.synced.value : this.synced,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentEvent(')
          ..write('id: $id, ')
          ..write('agentId: $agentId, ')
          ..write('eventType: $eventType, ')
          ..write('eventData: $eventData, ')
          ..write('correlationId: $correlationId, ')
          ..write('timestamp: $timestamp, ')
          ..write('synced: $synced, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, agentId, eventType, eventData,
      correlationId, timestamp, synced, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentEvent &&
          other.id == this.id &&
          other.agentId == this.agentId &&
          other.eventType == this.eventType &&
          other.eventData == this.eventData &&
          other.correlationId == this.correlationId &&
          other.timestamp == this.timestamp &&
          other.synced == this.synced &&
          other.syncedAt == this.syncedAt);
}

class AgentEventsCompanion extends UpdateCompanion<AgentEvent> {
  final Value<String> id;
  final Value<String> agentId;
  final Value<String> eventType;
  final Value<String> eventData;
  final Value<String?> correlationId;
  final Value<DateTime> timestamp;
  final Value<bool> synced;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const AgentEventsCompanion({
    this.id = const Value.absent(),
    this.agentId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.eventData = const Value.absent(),
    this.correlationId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.synced = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentEventsCompanion.insert({
    required String id,
    required String agentId,
    required String eventType,
    required String eventData,
    this.correlationId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.synced = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        agentId = Value(agentId),
        eventType = Value(eventType),
        eventData = Value(eventData);
  static Insertable<AgentEvent> custom({
    Expression<String>? id,
    Expression<String>? agentId,
    Expression<String>? eventType,
    Expression<String>? eventData,
    Expression<String>? correlationId,
    Expression<DateTime>? timestamp,
    Expression<bool>? synced,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (agentId != null) 'agent_id': agentId,
      if (eventType != null) 'event_type': eventType,
      if (eventData != null) 'event_data': eventData,
      if (correlationId != null) 'correlation_id': correlationId,
      if (timestamp != null) 'timestamp': timestamp,
      if (synced != null) 'synced': synced,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentEventsCompanion copyWith(
      {Value<String>? id,
      Value<String>? agentId,
      Value<String>? eventType,
      Value<String>? eventData,
      Value<String?>? correlationId,
      Value<DateTime>? timestamp,
      Value<bool>? synced,
      Value<DateTime?>? syncedAt,
      Value<int>? rowid}) {
    return AgentEventsCompanion(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      eventType: eventType ?? this.eventType,
      eventData: eventData ?? this.eventData,
      correlationId: correlationId ?? this.correlationId,
      timestamp: timestamp ?? this.timestamp,
      synced: synced ?? this.synced,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (eventData.present) {
      map['event_data'] = Variable<String>(eventData.value);
    }
    if (correlationId.present) {
      map['correlation_id'] = Variable<String>(correlationId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentEventsCompanion(')
          ..write('id: $id, ')
          ..write('agentId: $agentId, ')
          ..write('eventType: $eventType, ')
          ..write('eventData: $eventData, ')
          ..write('correlationId: $correlationId, ')
          ..write('timestamp: $timestamp, ')
          ..write('synced: $synced, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _targetTableMeta =
      const VerificationMeta('targetTable');
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
      'target_table', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, targetTable, operation, recordId, payload, createdAt, retryCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(Insertable<SyncQueueData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('target_table')) {
      context.handle(
          _targetTableMeta,
          targetTable.isAcceptableOrUnknown(
              data['target_table']!, _targetTableMeta));
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      targetTable: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_table'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final int id;
  final String targetTable;
  final String operation;
  final String recordId;
  final String payload;
  final DateTime createdAt;
  final int retryCount;
  const SyncQueueData(
      {required this.id,
      required this.targetTable,
      required this.operation,
      required this.recordId,
      required this.payload,
      required this.createdAt,
      required this.retryCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['target_table'] = Variable<String>(targetTable);
    map['operation'] = Variable<String>(operation);
    map['record_id'] = Variable<String>(recordId);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['retry_count'] = Variable<int>(retryCount);
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      targetTable: Value(targetTable),
      operation: Value(operation),
      recordId: Value(recordId),
      payload: Value(payload),
      createdAt: Value(createdAt),
      retryCount: Value(retryCount),
    );
  }

  factory SyncQueueData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      operation: serializer.fromJson<String>(json['operation']),
      recordId: serializer.fromJson<String>(json['recordId']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'targetTable': serializer.toJson<String>(targetTable),
      'operation': serializer.toJson<String>(operation),
      'recordId': serializer.toJson<String>(recordId),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
    };
  }

  SyncQueueData copyWith(
          {int? id,
          String? targetTable,
          String? operation,
          String? recordId,
          String? payload,
          DateTime? createdAt,
          int? retryCount}) =>
      SyncQueueData(
        id: id ?? this.id,
        targetTable: targetTable ?? this.targetTable,
        operation: operation ?? this.operation,
        recordId: recordId ?? this.recordId,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
        retryCount: retryCount ?? this.retryCount,
      );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      targetTable:
          data.targetTable.present ? data.targetTable.value : this.targetTable,
      operation: data.operation.present ? data.operation.value : this.operation,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('id: $id, ')
          ..write('targetTable: $targetTable, ')
          ..write('operation: $operation, ')
          ..write('recordId: $recordId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, targetTable, operation, recordId, payload, createdAt, retryCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.targetTable == this.targetTable &&
          other.operation == this.operation &&
          other.recordId == this.recordId &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> id;
  final Value<String> targetTable;
  final Value<String> operation;
  final Value<String> recordId;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<int> retryCount;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.operation = const Value.absent(),
    this.recordId = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String targetTable,
    required String operation,
    required String recordId,
    required String payload,
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
  })  : targetTable = Value(targetTable),
        operation = Value(operation),
        recordId = Value(recordId),
        payload = Value(payload);
  static Insertable<SyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? targetTable,
    Expression<String>? operation,
    Expression<String>? recordId,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? retryCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetTable != null) 'target_table': targetTable,
      if (operation != null) 'operation': operation,
      if (recordId != null) 'record_id': recordId,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
    });
  }

  SyncQueueCompanion copyWith(
      {Value<int>? id,
      Value<String>? targetTable,
      Value<String>? operation,
      Value<String>? recordId,
      Value<String>? payload,
      Value<DateTime>? createdAt,
      Value<int>? retryCount}) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      targetTable: targetTable ?? this.targetTable,
      operation: operation ?? this.operation,
      recordId: recordId ?? this.recordId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (targetTable.present) {
      map['target_table'] = Variable<String>(targetTable.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('targetTable: $targetTable, ')
          ..write('operation: $operation, ')
          ..write('recordId: $recordId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }
}

class $FileIndexTable extends FileIndex
    with TableInfo<$FileIndexTable, FileIndexData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FileIndexTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
      'path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filenameMeta =
      const VerificationMeta('filename');
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
      'filename', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _extensionMeta =
      const VerificationMeta('extension');
  @override
  late final GeneratedColumn<String> extension = GeneratedColumn<String>(
      'extension', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
      'size', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _modifiedAtMeta =
      const VerificationMeta('modifiedAt');
  @override
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
      'modified_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _contentHashMeta =
      const VerificationMeta('contentHash');
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
      'content_hash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mimeTypeMeta =
      const VerificationMeta('mimeType');
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
      'mime_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isDirectoryMeta =
      const VerificationMeta('isDirectory');
  @override
  late final GeneratedColumn<bool> isDirectory = GeneratedColumn<bool>(
      'is_directory', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_directory" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _parentPathMeta =
      const VerificationMeta('parentPath');
  @override
  late final GeneratedColumn<String> parentPath = GeneratedColumn<String>(
      'parent_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _indexedAtMeta =
      const VerificationMeta('indexedAt');
  @override
  late final GeneratedColumn<DateTime> indexedAt = GeneratedColumn<DateTime>(
      'indexed_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        path,
        filename,
        extension,
        size,
        modifiedAt,
        contentHash,
        mimeType,
        isDirectory,
        parentPath,
        indexedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_index';
  @override
  VerificationContext validateIntegrity(Insertable<FileIndexData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
          _pathMeta, path.isAcceptableOrUnknown(data['path']!, _pathMeta));
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('filename')) {
      context.handle(_filenameMeta,
          filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta));
    } else if (isInserting) {
      context.missing(_filenameMeta);
    }
    if (data.containsKey('extension')) {
      context.handle(_extensionMeta,
          extension.isAcceptableOrUnknown(data['extension']!, _extensionMeta));
    }
    if (data.containsKey('size')) {
      context.handle(
          _sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    }
    if (data.containsKey('modified_at')) {
      context.handle(
          _modifiedAtMeta,
          modifiedAt.isAcceptableOrUnknown(
              data['modified_at']!, _modifiedAtMeta));
    }
    if (data.containsKey('content_hash')) {
      context.handle(
          _contentHashMeta,
          contentHash.isAcceptableOrUnknown(
              data['content_hash']!, _contentHashMeta));
    }
    if (data.containsKey('mime_type')) {
      context.handle(_mimeTypeMeta,
          mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta));
    }
    if (data.containsKey('is_directory')) {
      context.handle(
          _isDirectoryMeta,
          isDirectory.isAcceptableOrUnknown(
              data['is_directory']!, _isDirectoryMeta));
    }
    if (data.containsKey('parent_path')) {
      context.handle(
          _parentPathMeta,
          parentPath.isAcceptableOrUnknown(
              data['parent_path']!, _parentPathMeta));
    }
    if (data.containsKey('indexed_at')) {
      context.handle(_indexedAtMeta,
          indexedAt.isAcceptableOrUnknown(data['indexed_at']!, _indexedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FileIndexData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileIndexData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      path: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}path'])!,
      filename: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}filename'])!,
      extension: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}extension']),
      size: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size']),
      modifiedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_at']),
      contentHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_hash']),
      mimeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mime_type']),
      isDirectory: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_directory'])!,
      parentPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_path']),
      indexedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}indexed_at'])!,
    );
  }

  @override
  $FileIndexTable createAlias(String alias) {
    return $FileIndexTable(attachedDatabase, alias);
  }
}

class FileIndexData extends DataClass implements Insertable<FileIndexData> {
  final int id;
  final String path;
  final String filename;
  final String? extension;
  final int? size;
  final DateTime? modifiedAt;
  final String? contentHash;
  final String? mimeType;
  final bool isDirectory;
  final String? parentPath;
  final DateTime indexedAt;
  const FileIndexData(
      {required this.id,
      required this.path,
      required this.filename,
      this.extension,
      this.size,
      this.modifiedAt,
      this.contentHash,
      this.mimeType,
      required this.isDirectory,
      this.parentPath,
      required this.indexedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['filename'] = Variable<String>(filename);
    if (!nullToAbsent || extension != null) {
      map['extension'] = Variable<String>(extension);
    }
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<int>(size);
    }
    if (!nullToAbsent || modifiedAt != null) {
      map['modified_at'] = Variable<DateTime>(modifiedAt);
    }
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    map['is_directory'] = Variable<bool>(isDirectory);
    if (!nullToAbsent || parentPath != null) {
      map['parent_path'] = Variable<String>(parentPath);
    }
    map['indexed_at'] = Variable<DateTime>(indexedAt);
    return map;
  }

  FileIndexCompanion toCompanion(bool nullToAbsent) {
    return FileIndexCompanion(
      id: Value(id),
      path: Value(path),
      filename: Value(filename),
      extension: extension == null && nullToAbsent
          ? const Value.absent()
          : Value(extension),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      modifiedAt: modifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(modifiedAt),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      isDirectory: Value(isDirectory),
      parentPath: parentPath == null && nullToAbsent
          ? const Value.absent()
          : Value(parentPath),
      indexedAt: Value(indexedAt),
    );
  }

  factory FileIndexData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileIndexData(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      filename: serializer.fromJson<String>(json['filename']),
      extension: serializer.fromJson<String?>(json['extension']),
      size: serializer.fromJson<int?>(json['size']),
      modifiedAt: serializer.fromJson<DateTime?>(json['modifiedAt']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      isDirectory: serializer.fromJson<bool>(json['isDirectory']),
      parentPath: serializer.fromJson<String?>(json['parentPath']),
      indexedAt: serializer.fromJson<DateTime>(json['indexedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'filename': serializer.toJson<String>(filename),
      'extension': serializer.toJson<String?>(extension),
      'size': serializer.toJson<int?>(size),
      'modifiedAt': serializer.toJson<DateTime?>(modifiedAt),
      'contentHash': serializer.toJson<String?>(contentHash),
      'mimeType': serializer.toJson<String?>(mimeType),
      'isDirectory': serializer.toJson<bool>(isDirectory),
      'parentPath': serializer.toJson<String?>(parentPath),
      'indexedAt': serializer.toJson<DateTime>(indexedAt),
    };
  }

  FileIndexData copyWith(
          {int? id,
          String? path,
          String? filename,
          Value<String?> extension = const Value.absent(),
          Value<int?> size = const Value.absent(),
          Value<DateTime?> modifiedAt = const Value.absent(),
          Value<String?> contentHash = const Value.absent(),
          Value<String?> mimeType = const Value.absent(),
          bool? isDirectory,
          Value<String?> parentPath = const Value.absent(),
          DateTime? indexedAt}) =>
      FileIndexData(
        id: id ?? this.id,
        path: path ?? this.path,
        filename: filename ?? this.filename,
        extension: extension.present ? extension.value : this.extension,
        size: size.present ? size.value : this.size,
        modifiedAt: modifiedAt.present ? modifiedAt.value : this.modifiedAt,
        contentHash: contentHash.present ? contentHash.value : this.contentHash,
        mimeType: mimeType.present ? mimeType.value : this.mimeType,
        isDirectory: isDirectory ?? this.isDirectory,
        parentPath: parentPath.present ? parentPath.value : this.parentPath,
        indexedAt: indexedAt ?? this.indexedAt,
      );
  FileIndexData copyWithCompanion(FileIndexCompanion data) {
    return FileIndexData(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      filename: data.filename.present ? data.filename.value : this.filename,
      extension: data.extension.present ? data.extension.value : this.extension,
      size: data.size.present ? data.size.value : this.size,
      modifiedAt:
          data.modifiedAt.present ? data.modifiedAt.value : this.modifiedAt,
      contentHash:
          data.contentHash.present ? data.contentHash.value : this.contentHash,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      isDirectory:
          data.isDirectory.present ? data.isDirectory.value : this.isDirectory,
      parentPath:
          data.parentPath.present ? data.parentPath.value : this.parentPath,
      indexedAt: data.indexedAt.present ? data.indexedAt.value : this.indexedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileIndexData(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('filename: $filename, ')
          ..write('extension: $extension, ')
          ..write('size: $size, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('contentHash: $contentHash, ')
          ..write('mimeType: $mimeType, ')
          ..write('isDirectory: $isDirectory, ')
          ..write('parentPath: $parentPath, ')
          ..write('indexedAt: $indexedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, filename, extension, size,
      modifiedAt, contentHash, mimeType, isDirectory, parentPath, indexedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileIndexData &&
          other.id == this.id &&
          other.path == this.path &&
          other.filename == this.filename &&
          other.extension == this.extension &&
          other.size == this.size &&
          other.modifiedAt == this.modifiedAt &&
          other.contentHash == this.contentHash &&
          other.mimeType == this.mimeType &&
          other.isDirectory == this.isDirectory &&
          other.parentPath == this.parentPath &&
          other.indexedAt == this.indexedAt);
}

class FileIndexCompanion extends UpdateCompanion<FileIndexData> {
  final Value<int> id;
  final Value<String> path;
  final Value<String> filename;
  final Value<String?> extension;
  final Value<int?> size;
  final Value<DateTime?> modifiedAt;
  final Value<String?> contentHash;
  final Value<String?> mimeType;
  final Value<bool> isDirectory;
  final Value<String?> parentPath;
  final Value<DateTime> indexedAt;
  const FileIndexCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.filename = const Value.absent(),
    this.extension = const Value.absent(),
    this.size = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.isDirectory = const Value.absent(),
    this.parentPath = const Value.absent(),
    this.indexedAt = const Value.absent(),
  });
  FileIndexCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required String filename,
    this.extension = const Value.absent(),
    this.size = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.isDirectory = const Value.absent(),
    this.parentPath = const Value.absent(),
    this.indexedAt = const Value.absent(),
  })  : path = Value(path),
        filename = Value(filename);
  static Insertable<FileIndexData> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<String>? filename,
    Expression<String>? extension,
    Expression<int>? size,
    Expression<DateTime>? modifiedAt,
    Expression<String>? contentHash,
    Expression<String>? mimeType,
    Expression<bool>? isDirectory,
    Expression<String>? parentPath,
    Expression<DateTime>? indexedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (filename != null) 'filename': filename,
      if (extension != null) 'extension': extension,
      if (size != null) 'size': size,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (contentHash != null) 'content_hash': contentHash,
      if (mimeType != null) 'mime_type': mimeType,
      if (isDirectory != null) 'is_directory': isDirectory,
      if (parentPath != null) 'parent_path': parentPath,
      if (indexedAt != null) 'indexed_at': indexedAt,
    });
  }

  FileIndexCompanion copyWith(
      {Value<int>? id,
      Value<String>? path,
      Value<String>? filename,
      Value<String?>? extension,
      Value<int?>? size,
      Value<DateTime?>? modifiedAt,
      Value<String?>? contentHash,
      Value<String?>? mimeType,
      Value<bool>? isDirectory,
      Value<String?>? parentPath,
      Value<DateTime>? indexedAt}) {
    return FileIndexCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      filename: filename ?? this.filename,
      extension: extension ?? this.extension,
      size: size ?? this.size,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      contentHash: contentHash ?? this.contentHash,
      mimeType: mimeType ?? this.mimeType,
      isDirectory: isDirectory ?? this.isDirectory,
      parentPath: parentPath ?? this.parentPath,
      indexedAt: indexedAt ?? this.indexedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (extension.present) {
      map['extension'] = Variable<String>(extension.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<DateTime>(modifiedAt.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (isDirectory.present) {
      map['is_directory'] = Variable<bool>(isDirectory.value);
    }
    if (parentPath.present) {
      map['parent_path'] = Variable<String>(parentPath.value);
    }
    if (indexedAt.present) {
      map['indexed_at'] = Variable<DateTime>(indexedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FileIndexCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('filename: $filename, ')
          ..write('extension: $extension, ')
          ..write('size: $size, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('contentHash: $contentHash, ')
          ..write('mimeType: $mimeType, ')
          ..write('isDirectory: $isDirectory, ')
          ..write('parentPath: $parentPath, ')
          ..write('indexedAt: $indexedAt')
          ..write(')'))
        .toString();
  }
}

class $FileContentCacheTable extends FileContentCache
    with TableInfo<$FileContentCacheTable, FileContentCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FileContentCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES file_index (path)'));
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, filePath, content, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_content_cache';
  @override
  VerificationContext validateIntegrity(
      Insertable<FileContentCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FileContentCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileContentCacheData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $FileContentCacheTable createAlias(String alias) {
    return $FileContentCacheTable(attachedDatabase, alias);
  }
}

class FileContentCacheData extends DataClass
    implements Insertable<FileContentCacheData> {
  final int id;
  final String filePath;
  final String content;
  final DateTime cachedAt;
  const FileContentCacheData(
      {required this.id,
      required this.filePath,
      required this.content,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_path'] = Variable<String>(filePath);
    map['content'] = Variable<String>(content);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  FileContentCacheCompanion toCompanion(bool nullToAbsent) {
    return FileContentCacheCompanion(
      id: Value(id),
      filePath: Value(filePath),
      content: Value(content),
      cachedAt: Value(cachedAt),
    );
  }

  factory FileContentCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileContentCacheData(
      id: serializer.fromJson<int>(json['id']),
      filePath: serializer.fromJson<String>(json['filePath']),
      content: serializer.fromJson<String>(json['content']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'filePath': serializer.toJson<String>(filePath),
      'content': serializer.toJson<String>(content),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  FileContentCacheData copyWith(
          {int? id, String? filePath, String? content, DateTime? cachedAt}) =>
      FileContentCacheData(
        id: id ?? this.id,
        filePath: filePath ?? this.filePath,
        content: content ?? this.content,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  FileContentCacheData copyWithCompanion(FileContentCacheCompanion data) {
    return FileContentCacheData(
      id: data.id.present ? data.id.value : this.id,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      content: data.content.present ? data.content.value : this.content,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileContentCacheData(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('content: $content, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, filePath, content, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileContentCacheData &&
          other.id == this.id &&
          other.filePath == this.filePath &&
          other.content == this.content &&
          other.cachedAt == this.cachedAt);
}

class FileContentCacheCompanion extends UpdateCompanion<FileContentCacheData> {
  final Value<int> id;
  final Value<String> filePath;
  final Value<String> content;
  final Value<DateTime> cachedAt;
  const FileContentCacheCompanion({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.content = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  FileContentCacheCompanion.insert({
    this.id = const Value.absent(),
    required String filePath,
    required String content,
    this.cachedAt = const Value.absent(),
  })  : filePath = Value(filePath),
        content = Value(content);
  static Insertable<FileContentCacheData> custom({
    Expression<int>? id,
    Expression<String>? filePath,
    Expression<String>? content,
    Expression<DateTime>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filePath != null) 'file_path': filePath,
      if (content != null) 'content': content,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  FileContentCacheCompanion copyWith(
      {Value<int>? id,
      Value<String>? filePath,
      Value<String>? content,
      Value<DateTime>? cachedAt}) {
    return FileContentCacheCompanion(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      content: content ?? this.content,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FileContentCacheCompanion(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('content: $content, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

class $LlmProvidersTable extends LlmProviders
    with TableInfo<$LlmProvidersTable, LlmProvider> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LlmProvidersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
      'url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isLocalMeta =
      const VerificationMeta('isLocal');
  @override
  late final GeneratedColumn<bool> isLocal = GeneratedColumn<bool>(
      'is_local', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_local" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _isDefaultMeta =
      const VerificationMeta('isDefault');
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
      'is_default', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_default" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
      'version', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _configMeta = const VerificationMeta('config');
  @override
  late final GeneratedColumn<String> config = GeneratedColumn<String>(
      'config', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        type,
        url,
        isLocal,
        isDefault,
        version,
        config,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'llm_providers';
  @override
  VerificationContext validateIntegrity(Insertable<LlmProvider> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
          _urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('is_local')) {
      context.handle(_isLocalMeta,
          isLocal.isAcceptableOrUnknown(data['is_local']!, _isLocalMeta));
    }
    if (data.containsKey('is_default')) {
      context.handle(_isDefaultMeta,
          isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('config')) {
      context.handle(_configMeta,
          config.isAcceptableOrUnknown(data['config']!, _configMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LlmProvider map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LlmProvider(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      url: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      isLocal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_local'])!,
      isDefault: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_default'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version']),
      config: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}config']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LlmProvidersTable createAlias(String alias) {
    return $LlmProvidersTable(attachedDatabase, alias);
  }
}

class LlmProvider extends DataClass implements Insertable<LlmProvider> {
  final String id;
  final String name;
  final String type;
  final String url;
  final bool isLocal;
  final bool isDefault;
  final String? version;
  final String? config;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LlmProvider(
      {required this.id,
      required this.name,
      required this.type,
      required this.url,
      required this.isLocal,
      required this.isDefault,
      this.version,
      this.config,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['url'] = Variable<String>(url);
    map['is_local'] = Variable<bool>(isLocal);
    map['is_default'] = Variable<bool>(isDefault);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<String>(version);
    }
    if (!nullToAbsent || config != null) {
      map['config'] = Variable<String>(config);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LlmProvidersCompanion toCompanion(bool nullToAbsent) {
    return LlmProvidersCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      url: Value(url),
      isLocal: Value(isLocal),
      isDefault: Value(isDefault),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      config:
          config == null && nullToAbsent ? const Value.absent() : Value(config),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LlmProvider.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LlmProvider(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      url: serializer.fromJson<String>(json['url']),
      isLocal: serializer.fromJson<bool>(json['isLocal']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      version: serializer.fromJson<String?>(json['version']),
      config: serializer.fromJson<String?>(json['config']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'url': serializer.toJson<String>(url),
      'isLocal': serializer.toJson<bool>(isLocal),
      'isDefault': serializer.toJson<bool>(isDefault),
      'version': serializer.toJson<String?>(version),
      'config': serializer.toJson<String?>(config),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LlmProvider copyWith(
          {String? id,
          String? name,
          String? type,
          String? url,
          bool? isLocal,
          bool? isDefault,
          Value<String?> version = const Value.absent(),
          Value<String?> config = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      LlmProvider(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        url: url ?? this.url,
        isLocal: isLocal ?? this.isLocal,
        isDefault: isDefault ?? this.isDefault,
        version: version.present ? version.value : this.version,
        config: config.present ? config.value : this.config,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LlmProvider copyWithCompanion(LlmProvidersCompanion data) {
    return LlmProvider(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      url: data.url.present ? data.url.value : this.url,
      isLocal: data.isLocal.present ? data.isLocal.value : this.isLocal,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      version: data.version.present ? data.version.value : this.version,
      config: data.config.present ? data.config.value : this.config,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LlmProvider(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('url: $url, ')
          ..write('isLocal: $isLocal, ')
          ..write('isDefault: $isDefault, ')
          ..write('version: $version, ')
          ..write('config: $config, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, type, url, isLocal, isDefault,
      version, config, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LlmProvider &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.url == this.url &&
          other.isLocal == this.isLocal &&
          other.isDefault == this.isDefault &&
          other.version == this.version &&
          other.config == this.config &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LlmProvidersCompanion extends UpdateCompanion<LlmProvider> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> url;
  final Value<bool> isLocal;
  final Value<bool> isDefault;
  final Value<String?> version;
  final Value<String?> config;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LlmProvidersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.url = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.version = const Value.absent(),
    this.config = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LlmProvidersCompanion.insert({
    required String id,
    required String name,
    required String type,
    required String url,
    this.isLocal = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.version = const Value.absent(),
    this.config = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        type = Value(type),
        url = Value(url);
  static Insertable<LlmProvider> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? url,
    Expression<bool>? isLocal,
    Expression<bool>? isDefault,
    Expression<String>? version,
    Expression<String>? config,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (url != null) 'url': url,
      if (isLocal != null) 'is_local': isLocal,
      if (isDefault != null) 'is_default': isDefault,
      if (version != null) 'version': version,
      if (config != null) 'config': config,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LlmProvidersCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? type,
      Value<String>? url,
      Value<bool>? isLocal,
      Value<bool>? isDefault,
      Value<String?>? version,
      Value<String?>? config,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return LlmProvidersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
      isLocal: isLocal ?? this.isLocal,
      isDefault: isDefault ?? this.isDefault,
      version: version ?? this.version,
      config: config ?? this.config,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (isLocal.present) {
      map['is_local'] = Variable<bool>(isLocal.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (config.present) {
      map['config'] = Variable<String>(config.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LlmProvidersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('url: $url, ')
          ..write('isLocal: $isLocal, ')
          ..write('isDefault: $isDefault, ')
          ..write('version: $version, ')
          ..write('config: $config, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelCapacityTable extends ModelCapacity
    with TableInfo<$ModelCapacityTable, ModelCapacityData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelCapacityTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _modelIdMeta =
      const VerificationMeta('modelId');
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
      'model_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _providerMeta =
      const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
      'provider', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _concurrentUsedMeta =
      const VerificationMeta('concurrentUsed');
  @override
  late final GeneratedColumn<int> concurrentUsed = GeneratedColumn<int>(
      'concurrent_used', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _concurrentLimitMeta =
      const VerificationMeta('concurrentLimit');
  @override
  late final GeneratedColumn<int> concurrentLimit = GeneratedColumn<int>(
      'concurrent_limit', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _tpmUsedMeta =
      const VerificationMeta('tpmUsed');
  @override
  late final GeneratedColumn<int> tpmUsed = GeneratedColumn<int>(
      'tpm_used', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _tpmLimitMeta =
      const VerificationMeta('tpmLimit');
  @override
  late final GeneratedColumn<int> tpmLimit = GeneratedColumn<int>(
      'tpm_limit', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _rpmUsedMeta =
      const VerificationMeta('rpmUsed');
  @override
  late final GeneratedColumn<int> rpmUsed = GeneratedColumn<int>(
      'rpm_used', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _rpmLimitMeta =
      const VerificationMeta('rpmLimit');
  @override
  late final GeneratedColumn<int> rpmLimit = GeneratedColumn<int>(
      'rpm_limit', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lastUpdatedMeta =
      const VerificationMeta('lastUpdated');
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
      'last_updated', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('active'));
  @override
  List<GeneratedColumn> get $columns => [
        modelId,
        provider,
        displayName,
        concurrentUsed,
        concurrentLimit,
        tpmUsed,
        tpmLimit,
        rpmUsed,
        rpmLimit,
        lastUpdated,
        status
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_capacity';
  @override
  VerificationContext validateIntegrity(Insertable<ModelCapacityData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('model_id')) {
      context.handle(_modelIdMeta,
          modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta));
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(_providerMeta,
          provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('concurrent_used')) {
      context.handle(
          _concurrentUsedMeta,
          concurrentUsed.isAcceptableOrUnknown(
              data['concurrent_used']!, _concurrentUsedMeta));
    }
    if (data.containsKey('concurrent_limit')) {
      context.handle(
          _concurrentLimitMeta,
          concurrentLimit.isAcceptableOrUnknown(
              data['concurrent_limit']!, _concurrentLimitMeta));
    } else if (isInserting) {
      context.missing(_concurrentLimitMeta);
    }
    if (data.containsKey('tpm_used')) {
      context.handle(_tpmUsedMeta,
          tpmUsed.isAcceptableOrUnknown(data['tpm_used']!, _tpmUsedMeta));
    }
    if (data.containsKey('tpm_limit')) {
      context.handle(_tpmLimitMeta,
          tpmLimit.isAcceptableOrUnknown(data['tpm_limit']!, _tpmLimitMeta));
    }
    if (data.containsKey('rpm_used')) {
      context.handle(_rpmUsedMeta,
          rpmUsed.isAcceptableOrUnknown(data['rpm_used']!, _rpmUsedMeta));
    }
    if (data.containsKey('rpm_limit')) {
      context.handle(_rpmLimitMeta,
          rpmLimit.isAcceptableOrUnknown(data['rpm_limit']!, _rpmLimitMeta));
    }
    if (data.containsKey('last_updated')) {
      context.handle(
          _lastUpdatedMeta,
          lastUpdated.isAcceptableOrUnknown(
              data['last_updated']!, _lastUpdatedMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {modelId};
  @override
  ModelCapacityData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelCapacityData(
      modelId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model_id'])!,
      provider: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name']),
      concurrentUsed: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}concurrent_used'])!,
      concurrentLimit: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}concurrent_limit'])!,
      tpmUsed: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tpm_used'])!,
      tpmLimit: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tpm_limit']),
      rpmUsed: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rpm_used'])!,
      rpmLimit: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rpm_limit']),
      lastUpdated: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_updated'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
    );
  }

  @override
  $ModelCapacityTable createAlias(String alias) {
    return $ModelCapacityTable(attachedDatabase, alias);
  }
}

class ModelCapacityData extends DataClass
    implements Insertable<ModelCapacityData> {
  final String modelId;
  final String provider;
  final String? displayName;
  final int concurrentUsed;
  final int concurrentLimit;
  final int tpmUsed;
  final int? tpmLimit;
  final int rpmUsed;
  final int? rpmLimit;
  final DateTime lastUpdated;
  final String status;
  const ModelCapacityData(
      {required this.modelId,
      required this.provider,
      this.displayName,
      required this.concurrentUsed,
      required this.concurrentLimit,
      required this.tpmUsed,
      this.tpmLimit,
      required this.rpmUsed,
      this.rpmLimit,
      required this.lastUpdated,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['model_id'] = Variable<String>(modelId);
    map['provider'] = Variable<String>(provider);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['concurrent_used'] = Variable<int>(concurrentUsed);
    map['concurrent_limit'] = Variable<int>(concurrentLimit);
    map['tpm_used'] = Variable<int>(tpmUsed);
    if (!nullToAbsent || tpmLimit != null) {
      map['tpm_limit'] = Variable<int>(tpmLimit);
    }
    map['rpm_used'] = Variable<int>(rpmUsed);
    if (!nullToAbsent || rpmLimit != null) {
      map['rpm_limit'] = Variable<int>(rpmLimit);
    }
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    map['status'] = Variable<String>(status);
    return map;
  }

  ModelCapacityCompanion toCompanion(bool nullToAbsent) {
    return ModelCapacityCompanion(
      modelId: Value(modelId),
      provider: Value(provider),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      concurrentUsed: Value(concurrentUsed),
      concurrentLimit: Value(concurrentLimit),
      tpmUsed: Value(tpmUsed),
      tpmLimit: tpmLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(tpmLimit),
      rpmUsed: Value(rpmUsed),
      rpmLimit: rpmLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(rpmLimit),
      lastUpdated: Value(lastUpdated),
      status: Value(status),
    );
  }

  factory ModelCapacityData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelCapacityData(
      modelId: serializer.fromJson<String>(json['modelId']),
      provider: serializer.fromJson<String>(json['provider']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      concurrentUsed: serializer.fromJson<int>(json['concurrentUsed']),
      concurrentLimit: serializer.fromJson<int>(json['concurrentLimit']),
      tpmUsed: serializer.fromJson<int>(json['tpmUsed']),
      tpmLimit: serializer.fromJson<int?>(json['tpmLimit']),
      rpmUsed: serializer.fromJson<int>(json['rpmUsed']),
      rpmLimit: serializer.fromJson<int?>(json['rpmLimit']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'modelId': serializer.toJson<String>(modelId),
      'provider': serializer.toJson<String>(provider),
      'displayName': serializer.toJson<String?>(displayName),
      'concurrentUsed': serializer.toJson<int>(concurrentUsed),
      'concurrentLimit': serializer.toJson<int>(concurrentLimit),
      'tpmUsed': serializer.toJson<int>(tpmUsed),
      'tpmLimit': serializer.toJson<int?>(tpmLimit),
      'rpmUsed': serializer.toJson<int>(rpmUsed),
      'rpmLimit': serializer.toJson<int?>(rpmLimit),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
      'status': serializer.toJson<String>(status),
    };
  }

  ModelCapacityData copyWith(
          {String? modelId,
          String? provider,
          Value<String?> displayName = const Value.absent(),
          int? concurrentUsed,
          int? concurrentLimit,
          int? tpmUsed,
          Value<int?> tpmLimit = const Value.absent(),
          int? rpmUsed,
          Value<int?> rpmLimit = const Value.absent(),
          DateTime? lastUpdated,
          String? status}) =>
      ModelCapacityData(
        modelId: modelId ?? this.modelId,
        provider: provider ?? this.provider,
        displayName: displayName.present ? displayName.value : this.displayName,
        concurrentUsed: concurrentUsed ?? this.concurrentUsed,
        concurrentLimit: concurrentLimit ?? this.concurrentLimit,
        tpmUsed: tpmUsed ?? this.tpmUsed,
        tpmLimit: tpmLimit.present ? tpmLimit.value : this.tpmLimit,
        rpmUsed: rpmUsed ?? this.rpmUsed,
        rpmLimit: rpmLimit.present ? rpmLimit.value : this.rpmLimit,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        status: status ?? this.status,
      );
  ModelCapacityData copyWithCompanion(ModelCapacityCompanion data) {
    return ModelCapacityData(
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      provider: data.provider.present ? data.provider.value : this.provider,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      concurrentUsed: data.concurrentUsed.present
          ? data.concurrentUsed.value
          : this.concurrentUsed,
      concurrentLimit: data.concurrentLimit.present
          ? data.concurrentLimit.value
          : this.concurrentLimit,
      tpmUsed: data.tpmUsed.present ? data.tpmUsed.value : this.tpmUsed,
      tpmLimit: data.tpmLimit.present ? data.tpmLimit.value : this.tpmLimit,
      rpmUsed: data.rpmUsed.present ? data.rpmUsed.value : this.rpmUsed,
      rpmLimit: data.rpmLimit.present ? data.rpmLimit.value : this.rpmLimit,
      lastUpdated:
          data.lastUpdated.present ? data.lastUpdated.value : this.lastUpdated,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelCapacityData(')
          ..write('modelId: $modelId, ')
          ..write('provider: $provider, ')
          ..write('displayName: $displayName, ')
          ..write('concurrentUsed: $concurrentUsed, ')
          ..write('concurrentLimit: $concurrentLimit, ')
          ..write('tpmUsed: $tpmUsed, ')
          ..write('tpmLimit: $tpmLimit, ')
          ..write('rpmUsed: $rpmUsed, ')
          ..write('rpmLimit: $rpmLimit, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      modelId,
      provider,
      displayName,
      concurrentUsed,
      concurrentLimit,
      tpmUsed,
      tpmLimit,
      rpmUsed,
      rpmLimit,
      lastUpdated,
      status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCapacityData &&
          other.modelId == this.modelId &&
          other.provider == this.provider &&
          other.displayName == this.displayName &&
          other.concurrentUsed == this.concurrentUsed &&
          other.concurrentLimit == this.concurrentLimit &&
          other.tpmUsed == this.tpmUsed &&
          other.tpmLimit == this.tpmLimit &&
          other.rpmUsed == this.rpmUsed &&
          other.rpmLimit == this.rpmLimit &&
          other.lastUpdated == this.lastUpdated &&
          other.status == this.status);
}

class ModelCapacityCompanion extends UpdateCompanion<ModelCapacityData> {
  final Value<String> modelId;
  final Value<String> provider;
  final Value<String?> displayName;
  final Value<int> concurrentUsed;
  final Value<int> concurrentLimit;
  final Value<int> tpmUsed;
  final Value<int?> tpmLimit;
  final Value<int> rpmUsed;
  final Value<int?> rpmLimit;
  final Value<DateTime> lastUpdated;
  final Value<String> status;
  final Value<int> rowid;
  const ModelCapacityCompanion({
    this.modelId = const Value.absent(),
    this.provider = const Value.absent(),
    this.displayName = const Value.absent(),
    this.concurrentUsed = const Value.absent(),
    this.concurrentLimit = const Value.absent(),
    this.tpmUsed = const Value.absent(),
    this.tpmLimit = const Value.absent(),
    this.rpmUsed = const Value.absent(),
    this.rpmLimit = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelCapacityCompanion.insert({
    required String modelId,
    required String provider,
    this.displayName = const Value.absent(),
    this.concurrentUsed = const Value.absent(),
    required int concurrentLimit,
    this.tpmUsed = const Value.absent(),
    this.tpmLimit = const Value.absent(),
    this.rpmUsed = const Value.absent(),
    this.rpmLimit = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : modelId = Value(modelId),
        provider = Value(provider),
        concurrentLimit = Value(concurrentLimit);
  static Insertable<ModelCapacityData> custom({
    Expression<String>? modelId,
    Expression<String>? provider,
    Expression<String>? displayName,
    Expression<int>? concurrentUsed,
    Expression<int>? concurrentLimit,
    Expression<int>? tpmUsed,
    Expression<int>? tpmLimit,
    Expression<int>? rpmUsed,
    Expression<int>? rpmLimit,
    Expression<DateTime>? lastUpdated,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (modelId != null) 'model_id': modelId,
      if (provider != null) 'provider': provider,
      if (displayName != null) 'display_name': displayName,
      if (concurrentUsed != null) 'concurrent_used': concurrentUsed,
      if (concurrentLimit != null) 'concurrent_limit': concurrentLimit,
      if (tpmUsed != null) 'tpm_used': tpmUsed,
      if (tpmLimit != null) 'tpm_limit': tpmLimit,
      if (rpmUsed != null) 'rpm_used': rpmUsed,
      if (rpmLimit != null) 'rpm_limit': rpmLimit,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelCapacityCompanion copyWith(
      {Value<String>? modelId,
      Value<String>? provider,
      Value<String?>? displayName,
      Value<int>? concurrentUsed,
      Value<int>? concurrentLimit,
      Value<int>? tpmUsed,
      Value<int?>? tpmLimit,
      Value<int>? rpmUsed,
      Value<int?>? rpmLimit,
      Value<DateTime>? lastUpdated,
      Value<String>? status,
      Value<int>? rowid}) {
    return ModelCapacityCompanion(
      modelId: modelId ?? this.modelId,
      provider: provider ?? this.provider,
      displayName: displayName ?? this.displayName,
      concurrentUsed: concurrentUsed ?? this.concurrentUsed,
      concurrentLimit: concurrentLimit ?? this.concurrentLimit,
      tpmUsed: tpmUsed ?? this.tpmUsed,
      tpmLimit: tpmLimit ?? this.tpmLimit,
      rpmUsed: rpmUsed ?? this.rpmUsed,
      rpmLimit: rpmLimit ?? this.rpmLimit,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (concurrentUsed.present) {
      map['concurrent_used'] = Variable<int>(concurrentUsed.value);
    }
    if (concurrentLimit.present) {
      map['concurrent_limit'] = Variable<int>(concurrentLimit.value);
    }
    if (tpmUsed.present) {
      map['tpm_used'] = Variable<int>(tpmUsed.value);
    }
    if (tpmLimit.present) {
      map['tpm_limit'] = Variable<int>(tpmLimit.value);
    }
    if (rpmUsed.present) {
      map['rpm_used'] = Variable<int>(rpmUsed.value);
    }
    if (rpmLimit.present) {
      map['rpm_limit'] = Variable<int>(rpmLimit.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelCapacityCompanion(')
          ..write('modelId: $modelId, ')
          ..write('provider: $provider, ')
          ..write('displayName: $displayName, ')
          ..write('concurrentUsed: $concurrentUsed, ')
          ..write('concurrentLimit: $concurrentLimit, ')
          ..write('tpmUsed: $tpmUsed, ')
          ..write('tpmLimit: $tpmLimit, ')
          ..write('rpmUsed: $rpmUsed, ')
          ..write('rpmLimit: $rpmLimit, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LlmRequestsTable extends LlmRequests
    with TableInfo<$LlmRequestsTable, LlmRequest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LlmRequestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _requestIdMeta =
      const VerificationMeta('requestId');
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
      'request_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modelIdMeta =
      const VerificationMeta('modelId');
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
      'model_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES model_capacity (model_id)'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _promptTokensMeta =
      const VerificationMeta('promptTokens');
  @override
  late final GeneratedColumn<int> promptTokens = GeneratedColumn<int>(
      'prompt_tokens', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _completionTokensMeta =
      const VerificationMeta('completionTokens');
  @override
  late final GeneratedColumn<int> completionTokens = GeneratedColumn<int>(
      'completion_tokens', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        requestId,
        modelId,
        status,
        promptTokens,
        completionTokens,
        startedAt,
        completedAt,
        errorMessage
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'llm_requests';
  @override
  VerificationContext validateIntegrity(Insertable<LlmRequest> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('request_id')) {
      context.handle(_requestIdMeta,
          requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta));
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(_modelIdMeta,
          modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta));
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('prompt_tokens')) {
      context.handle(
          _promptTokensMeta,
          promptTokens.isAcceptableOrUnknown(
              data['prompt_tokens']!, _promptTokensMeta));
    }
    if (data.containsKey('completion_tokens')) {
      context.handle(
          _completionTokensMeta,
          completionTokens.isAcceptableOrUnknown(
              data['completion_tokens']!, _completionTokensMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LlmRequest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LlmRequest(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      requestId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}request_id'])!,
      modelId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      promptTokens: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}prompt_tokens']),
      completionTokens: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}completion_tokens']),
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
    );
  }

  @override
  $LlmRequestsTable createAlias(String alias) {
    return $LlmRequestsTable(attachedDatabase, alias);
  }
}

class LlmRequest extends DataClass implements Insertable<LlmRequest> {
  final int id;
  final String requestId;
  final String modelId;
  final String status;
  final int? promptTokens;
  final int? completionTokens;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? errorMessage;
  const LlmRequest(
      {required this.id,
      required this.requestId,
      required this.modelId,
      required this.status,
      this.promptTokens,
      this.completionTokens,
      required this.startedAt,
      this.completedAt,
      this.errorMessage});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['request_id'] = Variable<String>(requestId);
    map['model_id'] = Variable<String>(modelId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || promptTokens != null) {
      map['prompt_tokens'] = Variable<int>(promptTokens);
    }
    if (!nullToAbsent || completionTokens != null) {
      map['completion_tokens'] = Variable<int>(completionTokens);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  LlmRequestsCompanion toCompanion(bool nullToAbsent) {
    return LlmRequestsCompanion(
      id: Value(id),
      requestId: Value(requestId),
      modelId: Value(modelId),
      status: Value(status),
      promptTokens: promptTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(promptTokens),
      completionTokens: completionTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(completionTokens),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory LlmRequest.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LlmRequest(
      id: serializer.fromJson<int>(json['id']),
      requestId: serializer.fromJson<String>(json['requestId']),
      modelId: serializer.fromJson<String>(json['modelId']),
      status: serializer.fromJson<String>(json['status']),
      promptTokens: serializer.fromJson<int?>(json['promptTokens']),
      completionTokens: serializer.fromJson<int?>(json['completionTokens']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'requestId': serializer.toJson<String>(requestId),
      'modelId': serializer.toJson<String>(modelId),
      'status': serializer.toJson<String>(status),
      'promptTokens': serializer.toJson<int?>(promptTokens),
      'completionTokens': serializer.toJson<int?>(completionTokens),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  LlmRequest copyWith(
          {int? id,
          String? requestId,
          String? modelId,
          String? status,
          Value<int?> promptTokens = const Value.absent(),
          Value<int?> completionTokens = const Value.absent(),
          DateTime? startedAt,
          Value<DateTime?> completedAt = const Value.absent(),
          Value<String?> errorMessage = const Value.absent()}) =>
      LlmRequest(
        id: id ?? this.id,
        requestId: requestId ?? this.requestId,
        modelId: modelId ?? this.modelId,
        status: status ?? this.status,
        promptTokens:
            promptTokens.present ? promptTokens.value : this.promptTokens,
        completionTokens: completionTokens.present
            ? completionTokens.value
            : this.completionTokens,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
      );
  LlmRequest copyWithCompanion(LlmRequestsCompanion data) {
    return LlmRequest(
      id: data.id.present ? data.id.value : this.id,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      status: data.status.present ? data.status.value : this.status,
      promptTokens: data.promptTokens.present
          ? data.promptTokens.value
          : this.promptTokens,
      completionTokens: data.completionTokens.present
          ? data.completionTokens.value
          : this.completionTokens,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LlmRequest(')
          ..write('id: $id, ')
          ..write('requestId: $requestId, ')
          ..write('modelId: $modelId, ')
          ..write('status: $status, ')
          ..write('promptTokens: $promptTokens, ')
          ..write('completionTokens: $completionTokens, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, requestId, modelId, status, promptTokens,
      completionTokens, startedAt, completedAt, errorMessage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LlmRequest &&
          other.id == this.id &&
          other.requestId == this.requestId &&
          other.modelId == this.modelId &&
          other.status == this.status &&
          other.promptTokens == this.promptTokens &&
          other.completionTokens == this.completionTokens &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.errorMessage == this.errorMessage);
}

class LlmRequestsCompanion extends UpdateCompanion<LlmRequest> {
  final Value<int> id;
  final Value<String> requestId;
  final Value<String> modelId;
  final Value<String> status;
  final Value<int?> promptTokens;
  final Value<int?> completionTokens;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  final Value<String?> errorMessage;
  const LlmRequestsCompanion({
    this.id = const Value.absent(),
    this.requestId = const Value.absent(),
    this.modelId = const Value.absent(),
    this.status = const Value.absent(),
    this.promptTokens = const Value.absent(),
    this.completionTokens = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
  });
  LlmRequestsCompanion.insert({
    this.id = const Value.absent(),
    required String requestId,
    required String modelId,
    this.status = const Value.absent(),
    this.promptTokens = const Value.absent(),
    this.completionTokens = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
  })  : requestId = Value(requestId),
        modelId = Value(modelId);
  static Insertable<LlmRequest> custom({
    Expression<int>? id,
    Expression<String>? requestId,
    Expression<String>? modelId,
    Expression<String>? status,
    Expression<int>? promptTokens,
    Expression<int>? completionTokens,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<String>? errorMessage,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (requestId != null) 'request_id': requestId,
      if (modelId != null) 'model_id': modelId,
      if (status != null) 'status': status,
      if (promptTokens != null) 'prompt_tokens': promptTokens,
      if (completionTokens != null) 'completion_tokens': completionTokens,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (errorMessage != null) 'error_message': errorMessage,
    });
  }

  LlmRequestsCompanion copyWith(
      {Value<int>? id,
      Value<String>? requestId,
      Value<String>? modelId,
      Value<String>? status,
      Value<int?>? promptTokens,
      Value<int?>? completionTokens,
      Value<DateTime>? startedAt,
      Value<DateTime?>? completedAt,
      Value<String?>? errorMessage}) {
    return LlmRequestsCompanion(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      modelId: modelId ?? this.modelId,
      status: status ?? this.status,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (promptTokens.present) {
      map['prompt_tokens'] = Variable<int>(promptTokens.value);
    }
    if (completionTokens.present) {
      map['completion_tokens'] = Variable<int>(completionTokens.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LlmRequestsCompanion(')
          ..write('id: $id, ')
          ..write('requestId: $requestId, ')
          ..write('modelId: $modelId, ')
          ..write('status: $status, ')
          ..write('promptTokens: $promptTokens, ')
          ..write('completionTokens: $completionTokens, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }
}

class $AvatarProfilesTable extends AvatarProfiles
    with TableInfo<$AvatarProfilesTable, AvatarProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AvatarProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _personalityTypeMeta =
      const VerificationMeta('personalityType');
  @override
  late final GeneratedColumn<String> personalityType = GeneratedColumn<String>(
      'personality_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
      'level', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _xpMeta = const VerificationMeta('xp');
  @override
  late final GeneratedColumn<int> xp = GeneratedColumn<int>(
      'xp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _xpToNextLevelMeta =
      const VerificationMeta('xpToNextLevel');
  @override
  late final GeneratedColumn<int> xpToNextLevel = GeneratedColumn<int>(
      'xp_to_next_level', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(100));
  static const VerificationMeta _traitsMeta = const VerificationMeta('traits');
  @override
  late final GeneratedColumn<String> traits = GeneratedColumn<String>(
      'traits', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _avatarConfigMeta =
      const VerificationMeta('avatarConfig');
  @override
  late final GeneratedColumn<String> avatarConfig = GeneratedColumn<String>(
      'avatar_config', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastInteractionMeta =
      const VerificationMeta('lastInteraction');
  @override
  late final GeneratedColumn<DateTime> lastInteraction =
      GeneratedColumn<DateTime>('last_interaction', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        personalityType,
        level,
        xp,
        xpToNextLevel,
        traits,
        avatarConfig,
        lastInteraction,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'avatar_profiles';
  @override
  VerificationContext validateIntegrity(Insertable<AvatarProfile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('personality_type')) {
      context.handle(
          _personalityTypeMeta,
          personalityType.isAcceptableOrUnknown(
              data['personality_type']!, _personalityTypeMeta));
    }
    if (data.containsKey('level')) {
      context.handle(
          _levelMeta, level.isAcceptableOrUnknown(data['level']!, _levelMeta));
    }
    if (data.containsKey('xp')) {
      context.handle(_xpMeta, xp.isAcceptableOrUnknown(data['xp']!, _xpMeta));
    }
    if (data.containsKey('xp_to_next_level')) {
      context.handle(
          _xpToNextLevelMeta,
          xpToNextLevel.isAcceptableOrUnknown(
              data['xp_to_next_level']!, _xpToNextLevelMeta));
    }
    if (data.containsKey('traits')) {
      context.handle(_traitsMeta,
          traits.isAcceptableOrUnknown(data['traits']!, _traitsMeta));
    }
    if (data.containsKey('avatar_config')) {
      context.handle(
          _avatarConfigMeta,
          avatarConfig.isAcceptableOrUnknown(
              data['avatar_config']!, _avatarConfigMeta));
    }
    if (data.containsKey('last_interaction')) {
      context.handle(
          _lastInteractionMeta,
          lastInteraction.isAcceptableOrUnknown(
              data['last_interaction']!, _lastInteractionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AvatarProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AvatarProfile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      personalityType: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}personality_type']),
      level: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}level'])!,
      xp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}xp'])!,
      xpToNextLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}xp_to_next_level'])!,
      traits: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}traits']),
      avatarConfig: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_config']),
      lastInteraction: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_interaction']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AvatarProfilesTable createAlias(String alias) {
    return $AvatarProfilesTable(attachedDatabase, alias);
  }
}

class AvatarProfile extends DataClass implements Insertable<AvatarProfile> {
  final String id;
  final String name;
  final String? personalityType;
  final int level;
  final int xp;
  final int xpToNextLevel;
  final String? traits;
  final String? avatarConfig;
  final DateTime? lastInteraction;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AvatarProfile(
      {required this.id,
      required this.name,
      this.personalityType,
      required this.level,
      required this.xp,
      required this.xpToNextLevel,
      this.traits,
      this.avatarConfig,
      this.lastInteraction,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || personalityType != null) {
      map['personality_type'] = Variable<String>(personalityType);
    }
    map['level'] = Variable<int>(level);
    map['xp'] = Variable<int>(xp);
    map['xp_to_next_level'] = Variable<int>(xpToNextLevel);
    if (!nullToAbsent || traits != null) {
      map['traits'] = Variable<String>(traits);
    }
    if (!nullToAbsent || avatarConfig != null) {
      map['avatar_config'] = Variable<String>(avatarConfig);
    }
    if (!nullToAbsent || lastInteraction != null) {
      map['last_interaction'] = Variable<DateTime>(lastInteraction);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AvatarProfilesCompanion toCompanion(bool nullToAbsent) {
    return AvatarProfilesCompanion(
      id: Value(id),
      name: Value(name),
      personalityType: personalityType == null && nullToAbsent
          ? const Value.absent()
          : Value(personalityType),
      level: Value(level),
      xp: Value(xp),
      xpToNextLevel: Value(xpToNextLevel),
      traits:
          traits == null && nullToAbsent ? const Value.absent() : Value(traits),
      avatarConfig: avatarConfig == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarConfig),
      lastInteraction: lastInteraction == null && nullToAbsent
          ? const Value.absent()
          : Value(lastInteraction),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AvatarProfile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AvatarProfile(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      personalityType: serializer.fromJson<String?>(json['personalityType']),
      level: serializer.fromJson<int>(json['level']),
      xp: serializer.fromJson<int>(json['xp']),
      xpToNextLevel: serializer.fromJson<int>(json['xpToNextLevel']),
      traits: serializer.fromJson<String?>(json['traits']),
      avatarConfig: serializer.fromJson<String?>(json['avatarConfig']),
      lastInteraction: serializer.fromJson<DateTime?>(json['lastInteraction']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'personalityType': serializer.toJson<String?>(personalityType),
      'level': serializer.toJson<int>(level),
      'xp': serializer.toJson<int>(xp),
      'xpToNextLevel': serializer.toJson<int>(xpToNextLevel),
      'traits': serializer.toJson<String?>(traits),
      'avatarConfig': serializer.toJson<String?>(avatarConfig),
      'lastInteraction': serializer.toJson<DateTime?>(lastInteraction),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AvatarProfile copyWith(
          {String? id,
          String? name,
          Value<String?> personalityType = const Value.absent(),
          int? level,
          int? xp,
          int? xpToNextLevel,
          Value<String?> traits = const Value.absent(),
          Value<String?> avatarConfig = const Value.absent(),
          Value<DateTime?> lastInteraction = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      AvatarProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        personalityType: personalityType.present
            ? personalityType.value
            : this.personalityType,
        level: level ?? this.level,
        xp: xp ?? this.xp,
        xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
        traits: traits.present ? traits.value : this.traits,
        avatarConfig:
            avatarConfig.present ? avatarConfig.value : this.avatarConfig,
        lastInteraction: lastInteraction.present
            ? lastInteraction.value
            : this.lastInteraction,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AvatarProfile copyWithCompanion(AvatarProfilesCompanion data) {
    return AvatarProfile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      personalityType: data.personalityType.present
          ? data.personalityType.value
          : this.personalityType,
      level: data.level.present ? data.level.value : this.level,
      xp: data.xp.present ? data.xp.value : this.xp,
      xpToNextLevel: data.xpToNextLevel.present
          ? data.xpToNextLevel.value
          : this.xpToNextLevel,
      traits: data.traits.present ? data.traits.value : this.traits,
      avatarConfig: data.avatarConfig.present
          ? data.avatarConfig.value
          : this.avatarConfig,
      lastInteraction: data.lastInteraction.present
          ? data.lastInteraction.value
          : this.lastInteraction,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AvatarProfile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('personalityType: $personalityType, ')
          ..write('level: $level, ')
          ..write('xp: $xp, ')
          ..write('xpToNextLevel: $xpToNextLevel, ')
          ..write('traits: $traits, ')
          ..write('avatarConfig: $avatarConfig, ')
          ..write('lastInteraction: $lastInteraction, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      personalityType,
      level,
      xp,
      xpToNextLevel,
      traits,
      avatarConfig,
      lastInteraction,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AvatarProfile &&
          other.id == this.id &&
          other.name == this.name &&
          other.personalityType == this.personalityType &&
          other.level == this.level &&
          other.xp == this.xp &&
          other.xpToNextLevel == this.xpToNextLevel &&
          other.traits == this.traits &&
          other.avatarConfig == this.avatarConfig &&
          other.lastInteraction == this.lastInteraction &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AvatarProfilesCompanion extends UpdateCompanion<AvatarProfile> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> personalityType;
  final Value<int> level;
  final Value<int> xp;
  final Value<int> xpToNextLevel;
  final Value<String?> traits;
  final Value<String?> avatarConfig;
  final Value<DateTime?> lastInteraction;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AvatarProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.personalityType = const Value.absent(),
    this.level = const Value.absent(),
    this.xp = const Value.absent(),
    this.xpToNextLevel = const Value.absent(),
    this.traits = const Value.absent(),
    this.avatarConfig = const Value.absent(),
    this.lastInteraction = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AvatarProfilesCompanion.insert({
    required String id,
    required String name,
    this.personalityType = const Value.absent(),
    this.level = const Value.absent(),
    this.xp = const Value.absent(),
    this.xpToNextLevel = const Value.absent(),
    this.traits = const Value.absent(),
    this.avatarConfig = const Value.absent(),
    this.lastInteraction = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<AvatarProfile> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? personalityType,
    Expression<int>? level,
    Expression<int>? xp,
    Expression<int>? xpToNextLevel,
    Expression<String>? traits,
    Expression<String>? avatarConfig,
    Expression<DateTime>? lastInteraction,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (personalityType != null) 'personality_type': personalityType,
      if (level != null) 'level': level,
      if (xp != null) 'xp': xp,
      if (xpToNextLevel != null) 'xp_to_next_level': xpToNextLevel,
      if (traits != null) 'traits': traits,
      if (avatarConfig != null) 'avatar_config': avatarConfig,
      if (lastInteraction != null) 'last_interaction': lastInteraction,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AvatarProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? personalityType,
      Value<int>? level,
      Value<int>? xp,
      Value<int>? xpToNextLevel,
      Value<String?>? traits,
      Value<String?>? avatarConfig,
      Value<DateTime?>? lastInteraction,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return AvatarProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      personalityType: personalityType ?? this.personalityType,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
      traits: traits ?? this.traits,
      avatarConfig: avatarConfig ?? this.avatarConfig,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (personalityType.present) {
      map['personality_type'] = Variable<String>(personalityType.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (xp.present) {
      map['xp'] = Variable<int>(xp.value);
    }
    if (xpToNextLevel.present) {
      map['xp_to_next_level'] = Variable<int>(xpToNextLevel.value);
    }
    if (traits.present) {
      map['traits'] = Variable<String>(traits.value);
    }
    if (avatarConfig.present) {
      map['avatar_config'] = Variable<String>(avatarConfig.value);
    }
    if (lastInteraction.present) {
      map['last_interaction'] = Variable<DateTime>(lastInteraction.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AvatarProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('personalityType: $personalityType, ')
          ..write('level: $level, ')
          ..write('xp: $xp, ')
          ..write('xpToNextLevel: $xpToNextLevel, ')
          ..write('traits: $traits, ')
          ..write('avatarConfig: $avatarConfig, ')
          ..write('lastInteraction: $lastInteraction, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AchievementsTable extends Achievements
    with TableInfo<$AchievementsTable, Achievement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AchievementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _avatarIdMeta =
      const VerificationMeta('avatarId');
  @override
  late final GeneratedColumn<String> avatarId = GeneratedColumn<String>(
      'avatar_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES avatar_profiles (id)'));
  static const VerificationMeta _achievementIdMeta =
      const VerificationMeta('achievementId');
  @override
  late final GeneratedColumn<String> achievementId = GeneratedColumn<String>(
      'achievement_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _achievementTypeMeta =
      const VerificationMeta('achievementType');
  @override
  late final GeneratedColumn<String> achievementType = GeneratedColumn<String>(
      'achievement_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _unlockedAtMeta =
      const VerificationMeta('unlockedAt');
  @override
  late final GeneratedColumn<DateTime> unlockedAt = GeneratedColumn<DateTime>(
      'unlocked_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _earnedAtMeta =
      const VerificationMeta('earnedAt');
  @override
  late final GeneratedColumn<DateTime> earnedAt = GeneratedColumn<DateTime>(
      'earned_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        avatarId,
        achievementId,
        achievementType,
        title,
        description,
        unlockedAt,
        earnedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'achievements';
  @override
  VerificationContext validateIntegrity(Insertable<Achievement> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('avatar_id')) {
      context.handle(_avatarIdMeta,
          avatarId.isAcceptableOrUnknown(data['avatar_id']!, _avatarIdMeta));
    } else if (isInserting) {
      context.missing(_avatarIdMeta);
    }
    if (data.containsKey('achievement_id')) {
      context.handle(
          _achievementIdMeta,
          achievementId.isAcceptableOrUnknown(
              data['achievement_id']!, _achievementIdMeta));
    } else if (isInserting) {
      context.missing(_achievementIdMeta);
    }
    if (data.containsKey('achievement_type')) {
      context.handle(
          _achievementTypeMeta,
          achievementType.isAcceptableOrUnknown(
              data['achievement_type']!, _achievementTypeMeta));
    } else if (isInserting) {
      context.missing(_achievementTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('unlocked_at')) {
      context.handle(
          _unlockedAtMeta,
          unlockedAt.isAcceptableOrUnknown(
              data['unlocked_at']!, _unlockedAtMeta));
    }
    if (data.containsKey('earned_at')) {
      context.handle(_earnedAtMeta,
          earnedAt.isAcceptableOrUnknown(data['earned_at']!, _earnedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Achievement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Achievement(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      avatarId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_id'])!,
      achievementId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}achievement_id'])!,
      achievementType: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}achievement_type'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      unlockedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}unlocked_at']),
      earnedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}earned_at'])!,
    );
  }

  @override
  $AchievementsTable createAlias(String alias) {
    return $AchievementsTable(attachedDatabase, alias);
  }
}

class Achievement extends DataClass implements Insertable<Achievement> {
  final int id;
  final String avatarId;
  final String achievementId;
  final String achievementType;
  final String title;
  final String? description;
  final DateTime? unlockedAt;
  final DateTime earnedAt;
  const Achievement(
      {required this.id,
      required this.avatarId,
      required this.achievementId,
      required this.achievementType,
      required this.title,
      this.description,
      this.unlockedAt,
      required this.earnedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['avatar_id'] = Variable<String>(avatarId);
    map['achievement_id'] = Variable<String>(achievementId);
    map['achievement_type'] = Variable<String>(achievementType);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || unlockedAt != null) {
      map['unlocked_at'] = Variable<DateTime>(unlockedAt);
    }
    map['earned_at'] = Variable<DateTime>(earnedAt);
    return map;
  }

  AchievementsCompanion toCompanion(bool nullToAbsent) {
    return AchievementsCompanion(
      id: Value(id),
      avatarId: Value(avatarId),
      achievementId: Value(achievementId),
      achievementType: Value(achievementType),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      unlockedAt: unlockedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(unlockedAt),
      earnedAt: Value(earnedAt),
    );
  }

  factory Achievement.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Achievement(
      id: serializer.fromJson<int>(json['id']),
      avatarId: serializer.fromJson<String>(json['avatarId']),
      achievementId: serializer.fromJson<String>(json['achievementId']),
      achievementType: serializer.fromJson<String>(json['achievementType']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      unlockedAt: serializer.fromJson<DateTime?>(json['unlockedAt']),
      earnedAt: serializer.fromJson<DateTime>(json['earnedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'avatarId': serializer.toJson<String>(avatarId),
      'achievementId': serializer.toJson<String>(achievementId),
      'achievementType': serializer.toJson<String>(achievementType),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'unlockedAt': serializer.toJson<DateTime?>(unlockedAt),
      'earnedAt': serializer.toJson<DateTime>(earnedAt),
    };
  }

  Achievement copyWith(
          {int? id,
          String? avatarId,
          String? achievementId,
          String? achievementType,
          String? title,
          Value<String?> description = const Value.absent(),
          Value<DateTime?> unlockedAt = const Value.absent(),
          DateTime? earnedAt}) =>
      Achievement(
        id: id ?? this.id,
        avatarId: avatarId ?? this.avatarId,
        achievementId: achievementId ?? this.achievementId,
        achievementType: achievementType ?? this.achievementType,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        unlockedAt: unlockedAt.present ? unlockedAt.value : this.unlockedAt,
        earnedAt: earnedAt ?? this.earnedAt,
      );
  Achievement copyWithCompanion(AchievementsCompanion data) {
    return Achievement(
      id: data.id.present ? data.id.value : this.id,
      avatarId: data.avatarId.present ? data.avatarId.value : this.avatarId,
      achievementId: data.achievementId.present
          ? data.achievementId.value
          : this.achievementId,
      achievementType: data.achievementType.present
          ? data.achievementType.value
          : this.achievementType,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      unlockedAt:
          data.unlockedAt.present ? data.unlockedAt.value : this.unlockedAt,
      earnedAt: data.earnedAt.present ? data.earnedAt.value : this.earnedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Achievement(')
          ..write('id: $id, ')
          ..write('avatarId: $avatarId, ')
          ..write('achievementId: $achievementId, ')
          ..write('achievementType: $achievementType, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('earnedAt: $earnedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, avatarId, achievementId, achievementType,
      title, description, unlockedAt, earnedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Achievement &&
          other.id == this.id &&
          other.avatarId == this.avatarId &&
          other.achievementId == this.achievementId &&
          other.achievementType == this.achievementType &&
          other.title == this.title &&
          other.description == this.description &&
          other.unlockedAt == this.unlockedAt &&
          other.earnedAt == this.earnedAt);
}

class AchievementsCompanion extends UpdateCompanion<Achievement> {
  final Value<int> id;
  final Value<String> avatarId;
  final Value<String> achievementId;
  final Value<String> achievementType;
  final Value<String> title;
  final Value<String?> description;
  final Value<DateTime?> unlockedAt;
  final Value<DateTime> earnedAt;
  const AchievementsCompanion({
    this.id = const Value.absent(),
    this.avatarId = const Value.absent(),
    this.achievementId = const Value.absent(),
    this.achievementType = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.unlockedAt = const Value.absent(),
    this.earnedAt = const Value.absent(),
  });
  AchievementsCompanion.insert({
    this.id = const Value.absent(),
    required String avatarId,
    required String achievementId,
    required String achievementType,
    required String title,
    this.description = const Value.absent(),
    this.unlockedAt = const Value.absent(),
    this.earnedAt = const Value.absent(),
  })  : avatarId = Value(avatarId),
        achievementId = Value(achievementId),
        achievementType = Value(achievementType),
        title = Value(title);
  static Insertable<Achievement> custom({
    Expression<int>? id,
    Expression<String>? avatarId,
    Expression<String>? achievementId,
    Expression<String>? achievementType,
    Expression<String>? title,
    Expression<String>? description,
    Expression<DateTime>? unlockedAt,
    Expression<DateTime>? earnedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (avatarId != null) 'avatar_id': avatarId,
      if (achievementId != null) 'achievement_id': achievementId,
      if (achievementType != null) 'achievement_type': achievementType,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (unlockedAt != null) 'unlocked_at': unlockedAt,
      if (earnedAt != null) 'earned_at': earnedAt,
    });
  }

  AchievementsCompanion copyWith(
      {Value<int>? id,
      Value<String>? avatarId,
      Value<String>? achievementId,
      Value<String>? achievementType,
      Value<String>? title,
      Value<String?>? description,
      Value<DateTime?>? unlockedAt,
      Value<DateTime>? earnedAt}) {
    return AchievementsCompanion(
      id: id ?? this.id,
      avatarId: avatarId ?? this.avatarId,
      achievementId: achievementId ?? this.achievementId,
      achievementType: achievementType ?? this.achievementType,
      title: title ?? this.title,
      description: description ?? this.description,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      earnedAt: earnedAt ?? this.earnedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (avatarId.present) {
      map['avatar_id'] = Variable<String>(avatarId.value);
    }
    if (achievementId.present) {
      map['achievement_id'] = Variable<String>(achievementId.value);
    }
    if (achievementType.present) {
      map['achievement_type'] = Variable<String>(achievementType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (unlockedAt.present) {
      map['unlocked_at'] = Variable<DateTime>(unlockedAt.value);
    }
    if (earnedAt.present) {
      map['earned_at'] = Variable<DateTime>(earnedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AchievementsCompanion(')
          ..write('id: $id, ')
          ..write('avatarId: $avatarId, ')
          ..write('achievementId: $achievementId, ')
          ..write('achievementType: $achievementType, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('earnedAt: $earnedAt')
          ..write(')'))
        .toString();
  }
}

class $AvatarMemoryEntriesTable extends AvatarMemoryEntries
    with TableInfo<$AvatarMemoryEntriesTable, AvatarMemoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AvatarMemoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _avatarIdMeta =
      const VerificationMeta('avatarId');
  @override
  late final GeneratedColumn<String> avatarId = GeneratedColumn<String>(
      'avatar_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES avatar_profiles (id)'));
  static const VerificationMeta _memoryTypeMeta =
      const VerificationMeta('memoryType');
  @override
  late final GeneratedColumn<String> memoryType = GeneratedColumn<String>(
      'memory_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _memoryKeyMeta =
      const VerificationMeta('memoryKey');
  @override
  late final GeneratedColumn<String> memoryKey = GeneratedColumn<String>(
      'memory_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _memoryValueMeta =
      const VerificationMeta('memoryValue');
  @override
  late final GeneratedColumn<String> memoryValue = GeneratedColumn<String>(
      'memory_value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _importanceMeta =
      const VerificationMeta('importance');
  @override
  late final GeneratedColumn<int> importance = GeneratedColumn<int>(
      'importance', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _lastAccessedMeta =
      const VerificationMeta('lastAccessed');
  @override
  late final GeneratedColumn<DateTime> lastAccessed = GeneratedColumn<DateTime>(
      'last_accessed', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        avatarId,
        memoryType,
        memoryKey,
        memoryValue,
        tags,
        importance,
        timestamp,
        createdAt,
        lastAccessed
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'avatar_memory_entries';
  @override
  VerificationContext validateIntegrity(Insertable<AvatarMemoryEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('avatar_id')) {
      context.handle(_avatarIdMeta,
          avatarId.isAcceptableOrUnknown(data['avatar_id']!, _avatarIdMeta));
    } else if (isInserting) {
      context.missing(_avatarIdMeta);
    }
    if (data.containsKey('memory_type')) {
      context.handle(
          _memoryTypeMeta,
          memoryType.isAcceptableOrUnknown(
              data['memory_type']!, _memoryTypeMeta));
    } else if (isInserting) {
      context.missing(_memoryTypeMeta);
    }
    if (data.containsKey('memory_key')) {
      context.handle(_memoryKeyMeta,
          memoryKey.isAcceptableOrUnknown(data['memory_key']!, _memoryKeyMeta));
    } else if (isInserting) {
      context.missing(_memoryKeyMeta);
    }
    if (data.containsKey('memory_value')) {
      context.handle(
          _memoryValueMeta,
          memoryValue.isAcceptableOrUnknown(
              data['memory_value']!, _memoryValueMeta));
    } else if (isInserting) {
      context.missing(_memoryValueMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('importance')) {
      context.handle(
          _importanceMeta,
          importance.isAcceptableOrUnknown(
              data['importance']!, _importanceMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('last_accessed')) {
      context.handle(
          _lastAccessedMeta,
          lastAccessed.isAcceptableOrUnknown(
              data['last_accessed']!, _lastAccessedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AvatarMemoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AvatarMemoryEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      avatarId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_id'])!,
      memoryType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}memory_type'])!,
      memoryKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}memory_key'])!,
      memoryValue: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}memory_value'])!,
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags']),
      importance: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}importance'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastAccessed: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_accessed'])!,
    );
  }

  @override
  $AvatarMemoryEntriesTable createAlias(String alias) {
    return $AvatarMemoryEntriesTable(attachedDatabase, alias);
  }
}

class AvatarMemoryEntry extends DataClass
    implements Insertable<AvatarMemoryEntry> {
  final int id;
  final String avatarId;
  final String memoryType;
  final String memoryKey;
  final String memoryValue;
  final String? tags;
  final int importance;
  final DateTime timestamp;
  final DateTime createdAt;
  final DateTime lastAccessed;
  const AvatarMemoryEntry(
      {required this.id,
      required this.avatarId,
      required this.memoryType,
      required this.memoryKey,
      required this.memoryValue,
      this.tags,
      required this.importance,
      required this.timestamp,
      required this.createdAt,
      required this.lastAccessed});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['avatar_id'] = Variable<String>(avatarId);
    map['memory_type'] = Variable<String>(memoryType);
    map['memory_key'] = Variable<String>(memoryKey);
    map['memory_value'] = Variable<String>(memoryValue);
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    map['importance'] = Variable<int>(importance);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_accessed'] = Variable<DateTime>(lastAccessed);
    return map;
  }

  AvatarMemoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return AvatarMemoryEntriesCompanion(
      id: Value(id),
      avatarId: Value(avatarId),
      memoryType: Value(memoryType),
      memoryKey: Value(memoryKey),
      memoryValue: Value(memoryValue),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      importance: Value(importance),
      timestamp: Value(timestamp),
      createdAt: Value(createdAt),
      lastAccessed: Value(lastAccessed),
    );
  }

  factory AvatarMemoryEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AvatarMemoryEntry(
      id: serializer.fromJson<int>(json['id']),
      avatarId: serializer.fromJson<String>(json['avatarId']),
      memoryType: serializer.fromJson<String>(json['memoryType']),
      memoryKey: serializer.fromJson<String>(json['memoryKey']),
      memoryValue: serializer.fromJson<String>(json['memoryValue']),
      tags: serializer.fromJson<String?>(json['tags']),
      importance: serializer.fromJson<int>(json['importance']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAccessed: serializer.fromJson<DateTime>(json['lastAccessed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'avatarId': serializer.toJson<String>(avatarId),
      'memoryType': serializer.toJson<String>(memoryType),
      'memoryKey': serializer.toJson<String>(memoryKey),
      'memoryValue': serializer.toJson<String>(memoryValue),
      'tags': serializer.toJson<String?>(tags),
      'importance': serializer.toJson<int>(importance),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAccessed': serializer.toJson<DateTime>(lastAccessed),
    };
  }

  AvatarMemoryEntry copyWith(
          {int? id,
          String? avatarId,
          String? memoryType,
          String? memoryKey,
          String? memoryValue,
          Value<String?> tags = const Value.absent(),
          int? importance,
          DateTime? timestamp,
          DateTime? createdAt,
          DateTime? lastAccessed}) =>
      AvatarMemoryEntry(
        id: id ?? this.id,
        avatarId: avatarId ?? this.avatarId,
        memoryType: memoryType ?? this.memoryType,
        memoryKey: memoryKey ?? this.memoryKey,
        memoryValue: memoryValue ?? this.memoryValue,
        tags: tags.present ? tags.value : this.tags,
        importance: importance ?? this.importance,
        timestamp: timestamp ?? this.timestamp,
        createdAt: createdAt ?? this.createdAt,
        lastAccessed: lastAccessed ?? this.lastAccessed,
      );
  AvatarMemoryEntry copyWithCompanion(AvatarMemoryEntriesCompanion data) {
    return AvatarMemoryEntry(
      id: data.id.present ? data.id.value : this.id,
      avatarId: data.avatarId.present ? data.avatarId.value : this.avatarId,
      memoryType:
          data.memoryType.present ? data.memoryType.value : this.memoryType,
      memoryKey: data.memoryKey.present ? data.memoryKey.value : this.memoryKey,
      memoryValue:
          data.memoryValue.present ? data.memoryValue.value : this.memoryValue,
      tags: data.tags.present ? data.tags.value : this.tags,
      importance:
          data.importance.present ? data.importance.value : this.importance,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAccessed: data.lastAccessed.present
          ? data.lastAccessed.value
          : this.lastAccessed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AvatarMemoryEntry(')
          ..write('id: $id, ')
          ..write('avatarId: $avatarId, ')
          ..write('memoryType: $memoryType, ')
          ..write('memoryKey: $memoryKey, ')
          ..write('memoryValue: $memoryValue, ')
          ..write('tags: $tags, ')
          ..write('importance: $importance, ')
          ..write('timestamp: $timestamp, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAccessed: $lastAccessed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, avatarId, memoryType, memoryKey,
      memoryValue, tags, importance, timestamp, createdAt, lastAccessed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AvatarMemoryEntry &&
          other.id == this.id &&
          other.avatarId == this.avatarId &&
          other.memoryType == this.memoryType &&
          other.memoryKey == this.memoryKey &&
          other.memoryValue == this.memoryValue &&
          other.tags == this.tags &&
          other.importance == this.importance &&
          other.timestamp == this.timestamp &&
          other.createdAt == this.createdAt &&
          other.lastAccessed == this.lastAccessed);
}

class AvatarMemoryEntriesCompanion extends UpdateCompanion<AvatarMemoryEntry> {
  final Value<int> id;
  final Value<String> avatarId;
  final Value<String> memoryType;
  final Value<String> memoryKey;
  final Value<String> memoryValue;
  final Value<String?> tags;
  final Value<int> importance;
  final Value<DateTime> timestamp;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastAccessed;
  const AvatarMemoryEntriesCompanion({
    this.id = const Value.absent(),
    this.avatarId = const Value.absent(),
    this.memoryType = const Value.absent(),
    this.memoryKey = const Value.absent(),
    this.memoryValue = const Value.absent(),
    this.tags = const Value.absent(),
    this.importance = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAccessed = const Value.absent(),
  });
  AvatarMemoryEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String avatarId,
    required String memoryType,
    required String memoryKey,
    required String memoryValue,
    this.tags = const Value.absent(),
    this.importance = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAccessed = const Value.absent(),
  })  : avatarId = Value(avatarId),
        memoryType = Value(memoryType),
        memoryKey = Value(memoryKey),
        memoryValue = Value(memoryValue);
  static Insertable<AvatarMemoryEntry> custom({
    Expression<int>? id,
    Expression<String>? avatarId,
    Expression<String>? memoryType,
    Expression<String>? memoryKey,
    Expression<String>? memoryValue,
    Expression<String>? tags,
    Expression<int>? importance,
    Expression<DateTime>? timestamp,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAccessed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (avatarId != null) 'avatar_id': avatarId,
      if (memoryType != null) 'memory_type': memoryType,
      if (memoryKey != null) 'memory_key': memoryKey,
      if (memoryValue != null) 'memory_value': memoryValue,
      if (tags != null) 'tags': tags,
      if (importance != null) 'importance': importance,
      if (timestamp != null) 'timestamp': timestamp,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAccessed != null) 'last_accessed': lastAccessed,
    });
  }

  AvatarMemoryEntriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? avatarId,
      Value<String>? memoryType,
      Value<String>? memoryKey,
      Value<String>? memoryValue,
      Value<String?>? tags,
      Value<int>? importance,
      Value<DateTime>? timestamp,
      Value<DateTime>? createdAt,
      Value<DateTime>? lastAccessed}) {
    return AvatarMemoryEntriesCompanion(
      id: id ?? this.id,
      avatarId: avatarId ?? this.avatarId,
      memoryType: memoryType ?? this.memoryType,
      memoryKey: memoryKey ?? this.memoryKey,
      memoryValue: memoryValue ?? this.memoryValue,
      tags: tags ?? this.tags,
      importance: importance ?? this.importance,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      lastAccessed: lastAccessed ?? this.lastAccessed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (avatarId.present) {
      map['avatar_id'] = Variable<String>(avatarId.value);
    }
    if (memoryType.present) {
      map['memory_type'] = Variable<String>(memoryType.value);
    }
    if (memoryKey.present) {
      map['memory_key'] = Variable<String>(memoryKey.value);
    }
    if (memoryValue.present) {
      map['memory_value'] = Variable<String>(memoryValue.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (importance.present) {
      map['importance'] = Variable<int>(importance.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAccessed.present) {
      map['last_accessed'] = Variable<DateTime>(lastAccessed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AvatarMemoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('avatarId: $avatarId, ')
          ..write('memoryType: $memoryType, ')
          ..write('memoryKey: $memoryKey, ')
          ..write('memoryValue: $memoryValue, ')
          ..write('tags: $tags, ')
          ..write('importance: $importance, ')
          ..write('timestamp: $timestamp, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAccessed: $lastAccessed')
          ..write(')'))
        .toString();
  }
}

class $ClipboardHistoryTable extends ClipboardHistory
    with TableInfo<$ClipboardHistoryTable, ClipboardHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClipboardHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentTypeMeta =
      const VerificationMeta('contentType');
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
      'content_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceAppMeta =
      const VerificationMeta('sourceApp');
  @override
  late final GeneratedColumn<String> sourceApp = GeneratedColumn<String>(
      'source_app', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _copiedAtMeta =
      const VerificationMeta('copiedAt');
  @override
  late final GeneratedColumn<DateTime> copiedAt = GeneratedColumn<DateTime>(
      'copied_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _isPinnedMeta =
      const VerificationMeta('isPinned');
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
      'is_pinned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pinned" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, content, contentType, sourceApp, timestamp, copiedAt, isPinned];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clipboard_history';
  @override
  VerificationContext validateIntegrity(
      Insertable<ClipboardHistoryData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('content_type')) {
      context.handle(
          _contentTypeMeta,
          contentType.isAcceptableOrUnknown(
              data['content_type']!, _contentTypeMeta));
    } else if (isInserting) {
      context.missing(_contentTypeMeta);
    }
    if (data.containsKey('source_app')) {
      context.handle(_sourceAppMeta,
          sourceApp.isAcceptableOrUnknown(data['source_app']!, _sourceAppMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    if (data.containsKey('copied_at')) {
      context.handle(_copiedAtMeta,
          copiedAt.isAcceptableOrUnknown(data['copied_at']!, _copiedAtMeta));
    }
    if (data.containsKey('is_pinned')) {
      context.handle(_isPinnedMeta,
          isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClipboardHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClipboardHistoryData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      contentType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_type'])!,
      sourceApp: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_app']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      copiedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}copied_at'])!,
      isPinned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pinned'])!,
    );
  }

  @override
  $ClipboardHistoryTable createAlias(String alias) {
    return $ClipboardHistoryTable(attachedDatabase, alias);
  }
}

class ClipboardHistoryData extends DataClass
    implements Insertable<ClipboardHistoryData> {
  final int id;
  final String content;
  final String contentType;
  final String? sourceApp;
  final DateTime timestamp;
  final DateTime copiedAt;
  final bool isPinned;
  const ClipboardHistoryData(
      {required this.id,
      required this.content,
      required this.contentType,
      this.sourceApp,
      required this.timestamp,
      required this.copiedAt,
      required this.isPinned});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content'] = Variable<String>(content);
    map['content_type'] = Variable<String>(contentType);
    if (!nullToAbsent || sourceApp != null) {
      map['source_app'] = Variable<String>(sourceApp);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['copied_at'] = Variable<DateTime>(copiedAt);
    map['is_pinned'] = Variable<bool>(isPinned);
    return map;
  }

  ClipboardHistoryCompanion toCompanion(bool nullToAbsent) {
    return ClipboardHistoryCompanion(
      id: Value(id),
      content: Value(content),
      contentType: Value(contentType),
      sourceApp: sourceApp == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceApp),
      timestamp: Value(timestamp),
      copiedAt: Value(copiedAt),
      isPinned: Value(isPinned),
    );
  }

  factory ClipboardHistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClipboardHistoryData(
      id: serializer.fromJson<int>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      contentType: serializer.fromJson<String>(json['contentType']),
      sourceApp: serializer.fromJson<String?>(json['sourceApp']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      copiedAt: serializer.fromJson<DateTime>(json['copiedAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'content': serializer.toJson<String>(content),
      'contentType': serializer.toJson<String>(contentType),
      'sourceApp': serializer.toJson<String?>(sourceApp),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'copiedAt': serializer.toJson<DateTime>(copiedAt),
      'isPinned': serializer.toJson<bool>(isPinned),
    };
  }

  ClipboardHistoryData copyWith(
          {int? id,
          String? content,
          String? contentType,
          Value<String?> sourceApp = const Value.absent(),
          DateTime? timestamp,
          DateTime? copiedAt,
          bool? isPinned}) =>
      ClipboardHistoryData(
        id: id ?? this.id,
        content: content ?? this.content,
        contentType: contentType ?? this.contentType,
        sourceApp: sourceApp.present ? sourceApp.value : this.sourceApp,
        timestamp: timestamp ?? this.timestamp,
        copiedAt: copiedAt ?? this.copiedAt,
        isPinned: isPinned ?? this.isPinned,
      );
  ClipboardHistoryData copyWithCompanion(ClipboardHistoryCompanion data) {
    return ClipboardHistoryData(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      contentType:
          data.contentType.present ? data.contentType.value : this.contentType,
      sourceApp: data.sourceApp.present ? data.sourceApp.value : this.sourceApp,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      copiedAt: data.copiedAt.present ? data.copiedAt.value : this.copiedAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClipboardHistoryData(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('contentType: $contentType, ')
          ..write('sourceApp: $sourceApp, ')
          ..write('timestamp: $timestamp, ')
          ..write('copiedAt: $copiedAt, ')
          ..write('isPinned: $isPinned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, content, contentType, sourceApp, timestamp, copiedAt, isPinned);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClipboardHistoryData &&
          other.id == this.id &&
          other.content == this.content &&
          other.contentType == this.contentType &&
          other.sourceApp == this.sourceApp &&
          other.timestamp == this.timestamp &&
          other.copiedAt == this.copiedAt &&
          other.isPinned == this.isPinned);
}

class ClipboardHistoryCompanion extends UpdateCompanion<ClipboardHistoryData> {
  final Value<int> id;
  final Value<String> content;
  final Value<String> contentType;
  final Value<String?> sourceApp;
  final Value<DateTime> timestamp;
  final Value<DateTime> copiedAt;
  final Value<bool> isPinned;
  const ClipboardHistoryCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.contentType = const Value.absent(),
    this.sourceApp = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.copiedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
  });
  ClipboardHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String content,
    required String contentType,
    this.sourceApp = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.copiedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
  })  : content = Value(content),
        contentType = Value(contentType);
  static Insertable<ClipboardHistoryData> custom({
    Expression<int>? id,
    Expression<String>? content,
    Expression<String>? contentType,
    Expression<String>? sourceApp,
    Expression<DateTime>? timestamp,
    Expression<DateTime>? copiedAt,
    Expression<bool>? isPinned,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (contentType != null) 'content_type': contentType,
      if (sourceApp != null) 'source_app': sourceApp,
      if (timestamp != null) 'timestamp': timestamp,
      if (copiedAt != null) 'copied_at': copiedAt,
      if (isPinned != null) 'is_pinned': isPinned,
    });
  }

  ClipboardHistoryCompanion copyWith(
      {Value<int>? id,
      Value<String>? content,
      Value<String>? contentType,
      Value<String?>? sourceApp,
      Value<DateTime>? timestamp,
      Value<DateTime>? copiedAt,
      Value<bool>? isPinned}) {
    return ClipboardHistoryCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      contentType: contentType ?? this.contentType,
      sourceApp: sourceApp ?? this.sourceApp,
      timestamp: timestamp ?? this.timestamp,
      copiedAt: copiedAt ?? this.copiedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (sourceApp.present) {
      map['source_app'] = Variable<String>(sourceApp.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (copiedAt.present) {
      map['copied_at'] = Variable<DateTime>(copiedAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClipboardHistoryCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('contentType: $contentType, ')
          ..write('sourceApp: $sourceApp, ')
          ..write('timestamp: $timestamp, ')
          ..write('copiedAt: $copiedAt, ')
          ..write('isPinned: $isPinned')
          ..write(')'))
        .toString();
  }
}

class $ActionHistoryEntriesTable extends ActionHistoryEntries
    with TableInfo<$ActionHistoryEntriesTable, ActionHistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActionHistoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _actionTypeMeta =
      const VerificationMeta('actionType');
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
      'action_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetElementMeta =
      const VerificationMeta('targetElement');
  @override
  late final GeneratedColumn<String> targetElement = GeneratedColumn<String>(
      'target_element', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _parametersMeta =
      const VerificationMeta('parameters');
  @override
  late final GeneratedColumn<String> parameters = GeneratedColumn<String>(
      'parameters', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
      'result', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, actionType, targetElement, parameters, timestamp, result];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'action_history_entries';
  @override
  VerificationContext validateIntegrity(Insertable<ActionHistoryEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('action_type')) {
      context.handle(
          _actionTypeMeta,
          actionType.isAcceptableOrUnknown(
              data['action_type']!, _actionTypeMeta));
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('target_element')) {
      context.handle(
          _targetElementMeta,
          targetElement.isAcceptableOrUnknown(
              data['target_element']!, _targetElementMeta));
    }
    if (data.containsKey('parameters')) {
      context.handle(
          _parametersMeta,
          parameters.isAcceptableOrUnknown(
              data['parameters']!, _parametersMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    if (data.containsKey('result')) {
      context.handle(_resultMeta,
          result.isAcceptableOrUnknown(data['result']!, _resultMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActionHistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActionHistoryEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      actionType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action_type'])!,
      targetElement: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_element']),
      parameters: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parameters']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      result: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}result']),
    );
  }

  @override
  $ActionHistoryEntriesTable createAlias(String alias) {
    return $ActionHistoryEntriesTable(attachedDatabase, alias);
  }
}

class ActionHistoryEntry extends DataClass
    implements Insertable<ActionHistoryEntry> {
  final int id;
  final String actionType;
  final String? targetElement;
  final String? parameters;
  final DateTime timestamp;
  final String? result;
  const ActionHistoryEntry(
      {required this.id,
      required this.actionType,
      this.targetElement,
      this.parameters,
      required this.timestamp,
      this.result});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['action_type'] = Variable<String>(actionType);
    if (!nullToAbsent || targetElement != null) {
      map['target_element'] = Variable<String>(targetElement);
    }
    if (!nullToAbsent || parameters != null) {
      map['parameters'] = Variable<String>(parameters);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || result != null) {
      map['result'] = Variable<String>(result);
    }
    return map;
  }

  ActionHistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return ActionHistoryEntriesCompanion(
      id: Value(id),
      actionType: Value(actionType),
      targetElement: targetElement == null && nullToAbsent
          ? const Value.absent()
          : Value(targetElement),
      parameters: parameters == null && nullToAbsent
          ? const Value.absent()
          : Value(parameters),
      timestamp: Value(timestamp),
      result:
          result == null && nullToAbsent ? const Value.absent() : Value(result),
    );
  }

  factory ActionHistoryEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActionHistoryEntry(
      id: serializer.fromJson<int>(json['id']),
      actionType: serializer.fromJson<String>(json['actionType']),
      targetElement: serializer.fromJson<String?>(json['targetElement']),
      parameters: serializer.fromJson<String?>(json['parameters']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      result: serializer.fromJson<String?>(json['result']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'actionType': serializer.toJson<String>(actionType),
      'targetElement': serializer.toJson<String?>(targetElement),
      'parameters': serializer.toJson<String?>(parameters),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'result': serializer.toJson<String?>(result),
    };
  }

  ActionHistoryEntry copyWith(
          {int? id,
          String? actionType,
          Value<String?> targetElement = const Value.absent(),
          Value<String?> parameters = const Value.absent(),
          DateTime? timestamp,
          Value<String?> result = const Value.absent()}) =>
      ActionHistoryEntry(
        id: id ?? this.id,
        actionType: actionType ?? this.actionType,
        targetElement:
            targetElement.present ? targetElement.value : this.targetElement,
        parameters: parameters.present ? parameters.value : this.parameters,
        timestamp: timestamp ?? this.timestamp,
        result: result.present ? result.value : this.result,
      );
  ActionHistoryEntry copyWithCompanion(ActionHistoryEntriesCompanion data) {
    return ActionHistoryEntry(
      id: data.id.present ? data.id.value : this.id,
      actionType:
          data.actionType.present ? data.actionType.value : this.actionType,
      targetElement: data.targetElement.present
          ? data.targetElement.value
          : this.targetElement,
      parameters:
          data.parameters.present ? data.parameters.value : this.parameters,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      result: data.result.present ? data.result.value : this.result,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActionHistoryEntry(')
          ..write('id: $id, ')
          ..write('actionType: $actionType, ')
          ..write('targetElement: $targetElement, ')
          ..write('parameters: $parameters, ')
          ..write('timestamp: $timestamp, ')
          ..write('result: $result')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, actionType, targetElement, parameters, timestamp, result);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActionHistoryEntry &&
          other.id == this.id &&
          other.actionType == this.actionType &&
          other.targetElement == this.targetElement &&
          other.parameters == this.parameters &&
          other.timestamp == this.timestamp &&
          other.result == this.result);
}

class ActionHistoryEntriesCompanion
    extends UpdateCompanion<ActionHistoryEntry> {
  final Value<int> id;
  final Value<String> actionType;
  final Value<String?> targetElement;
  final Value<String?> parameters;
  final Value<DateTime> timestamp;
  final Value<String?> result;
  const ActionHistoryEntriesCompanion({
    this.id = const Value.absent(),
    this.actionType = const Value.absent(),
    this.targetElement = const Value.absent(),
    this.parameters = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.result = const Value.absent(),
  });
  ActionHistoryEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String actionType,
    this.targetElement = const Value.absent(),
    this.parameters = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.result = const Value.absent(),
  }) : actionType = Value(actionType);
  static Insertable<ActionHistoryEntry> custom({
    Expression<int>? id,
    Expression<String>? actionType,
    Expression<String>? targetElement,
    Expression<String>? parameters,
    Expression<DateTime>? timestamp,
    Expression<String>? result,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (actionType != null) 'action_type': actionType,
      if (targetElement != null) 'target_element': targetElement,
      if (parameters != null) 'parameters': parameters,
      if (timestamp != null) 'timestamp': timestamp,
      if (result != null) 'result': result,
    });
  }

  ActionHistoryEntriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? actionType,
      Value<String?>? targetElement,
      Value<String?>? parameters,
      Value<DateTime>? timestamp,
      Value<String?>? result}) {
    return ActionHistoryEntriesCompanion(
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      targetElement: targetElement ?? this.targetElement,
      parameters: parameters ?? this.parameters,
      timestamp: timestamp ?? this.timestamp,
      result: result ?? this.result,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (targetElement.present) {
      map['target_element'] = Variable<String>(targetElement.value);
    }
    if (parameters.present) {
      map['parameters'] = Variable<String>(parameters.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActionHistoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('actionType: $actionType, ')
          ..write('targetElement: $targetElement, ')
          ..write('parameters: $parameters, ')
          ..write('timestamp: $timestamp, ')
          ..write('result: $result')
          ..write(')'))
        .toString();
  }
}

class $MacrosTable extends Macros with TableInfo<$MacrosTable, Macro> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MacrosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sequenceMeta =
      const VerificationMeta('sequence');
  @override
  late final GeneratedColumn<String> sequence = GeneratedColumn<String>(
      'sequence', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _triggerTypeMeta =
      const VerificationMeta('triggerType');
  @override
  late final GeneratedColumn<String> triggerType = GeneratedColumn<String>(
      'trigger_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _triggerDataMeta =
      const VerificationMeta('triggerData');
  @override
  late final GeneratedColumn<String> triggerData = GeneratedColumn<String>(
      'trigger_data', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _lastUsedMeta =
      const VerificationMeta('lastUsed');
  @override
  late final GeneratedColumn<DateTime> lastUsed = GeneratedColumn<DateTime>(
      'last_used', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        description,
        sequence,
        triggerType,
        triggerData,
        createdAt,
        lastUsed
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'macros';
  @override
  VerificationContext validateIntegrity(Insertable<Macro> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('sequence')) {
      context.handle(_sequenceMeta,
          sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta));
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('trigger_type')) {
      context.handle(
          _triggerTypeMeta,
          triggerType.isAcceptableOrUnknown(
              data['trigger_type']!, _triggerTypeMeta));
    } else if (isInserting) {
      context.missing(_triggerTypeMeta);
    }
    if (data.containsKey('trigger_data')) {
      context.handle(
          _triggerDataMeta,
          triggerData.isAcceptableOrUnknown(
              data['trigger_data']!, _triggerDataMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('last_used')) {
      context.handle(_lastUsedMeta,
          lastUsed.isAcceptableOrUnknown(data['last_used']!, _lastUsedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Macro map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Macro(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      sequence: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sequence'])!,
      triggerType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trigger_type'])!,
      triggerData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trigger_data']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastUsed: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_used']),
    );
  }

  @override
  $MacrosTable createAlias(String alias) {
    return $MacrosTable(attachedDatabase, alias);
  }
}

class Macro extends DataClass implements Insertable<Macro> {
  final String id;
  final String name;
  final String? description;
  final String sequence;
  final String triggerType;
  final String? triggerData;
  final DateTime createdAt;
  final DateTime? lastUsed;
  const Macro(
      {required this.id,
      required this.name,
      this.description,
      required this.sequence,
      required this.triggerType,
      this.triggerData,
      required this.createdAt,
      this.lastUsed});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['sequence'] = Variable<String>(sequence);
    map['trigger_type'] = Variable<String>(triggerType);
    if (!nullToAbsent || triggerData != null) {
      map['trigger_data'] = Variable<String>(triggerData);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastUsed != null) {
      map['last_used'] = Variable<DateTime>(lastUsed);
    }
    return map;
  }

  MacrosCompanion toCompanion(bool nullToAbsent) {
    return MacrosCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      sequence: Value(sequence),
      triggerType: Value(triggerType),
      triggerData: triggerData == null && nullToAbsent
          ? const Value.absent()
          : Value(triggerData),
      createdAt: Value(createdAt),
      lastUsed: lastUsed == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsed),
    );
  }

  factory Macro.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Macro(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      sequence: serializer.fromJson<String>(json['sequence']),
      triggerType: serializer.fromJson<String>(json['triggerType']),
      triggerData: serializer.fromJson<String?>(json['triggerData']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUsed: serializer.fromJson<DateTime?>(json['lastUsed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'sequence': serializer.toJson<String>(sequence),
      'triggerType': serializer.toJson<String>(triggerType),
      'triggerData': serializer.toJson<String?>(triggerData),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUsed': serializer.toJson<DateTime?>(lastUsed),
    };
  }

  Macro copyWith(
          {String? id,
          String? name,
          Value<String?> description = const Value.absent(),
          String? sequence,
          String? triggerType,
          Value<String?> triggerData = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> lastUsed = const Value.absent()}) =>
      Macro(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        sequence: sequence ?? this.sequence,
        triggerType: triggerType ?? this.triggerType,
        triggerData: triggerData.present ? triggerData.value : this.triggerData,
        createdAt: createdAt ?? this.createdAt,
        lastUsed: lastUsed.present ? lastUsed.value : this.lastUsed,
      );
  Macro copyWithCompanion(MacrosCompanion data) {
    return Macro(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      triggerType:
          data.triggerType.present ? data.triggerType.value : this.triggerType,
      triggerData:
          data.triggerData.present ? data.triggerData.value : this.triggerData,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUsed: data.lastUsed.present ? data.lastUsed.value : this.lastUsed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Macro(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('sequence: $sequence, ')
          ..write('triggerType: $triggerType, ')
          ..write('triggerData: $triggerData, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsed: $lastUsed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, sequence, triggerType,
      triggerData, createdAt, lastUsed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Macro &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.sequence == this.sequence &&
          other.triggerType == this.triggerType &&
          other.triggerData == this.triggerData &&
          other.createdAt == this.createdAt &&
          other.lastUsed == this.lastUsed);
}

class MacrosCompanion extends UpdateCompanion<Macro> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> sequence;
  final Value<String> triggerType;
  final Value<String?> triggerData;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastUsed;
  final Value<int> rowid;
  const MacrosCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.sequence = const Value.absent(),
    this.triggerType = const Value.absent(),
    this.triggerData = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MacrosCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required String sequence,
    required String triggerType,
    this.triggerData = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsed = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        sequence = Value(sequence),
        triggerType = Value(triggerType);
  static Insertable<Macro> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? sequence,
    Expression<String>? triggerType,
    Expression<String>? triggerData,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUsed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (sequence != null) 'sequence': sequence,
      if (triggerType != null) 'trigger_type': triggerType,
      if (triggerData != null) 'trigger_data': triggerData,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUsed != null) 'last_used': lastUsed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MacrosCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? description,
      Value<String>? sequence,
      Value<String>? triggerType,
      Value<String?>? triggerData,
      Value<DateTime>? createdAt,
      Value<DateTime?>? lastUsed,
      Value<int>? rowid}) {
    return MacrosCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sequence: sequence ?? this.sequence,
      triggerType: triggerType ?? this.triggerType,
      triggerData: triggerData ?? this.triggerData,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<String>(sequence.value);
    }
    if (triggerType.present) {
      map['trigger_type'] = Variable<String>(triggerType.value);
    }
    if (triggerData.present) {
      map['trigger_data'] = Variable<String>(triggerData.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUsed.present) {
      map['last_used'] = Variable<DateTime>(lastUsed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MacrosCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('sequence: $sequence, ')
          ..write('triggerType: $triggerType, ')
          ..write('triggerData: $triggerData, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsed: $lastUsed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AvatarPersonalityProfilesTable extends AvatarPersonalityProfiles
    with TableInfo<$AvatarPersonalityProfilesTable, AvatarPersonalityProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AvatarPersonalityProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('default'));
  static const VerificationMeta _agentNameMeta =
      const VerificationMeta('agentName');
  @override
  late final GeneratedColumn<String> agentName = GeneratedColumn<String>(
      'agent_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Agent'));
  static const VerificationMeta _personalityTraitsMeta =
      const VerificationMeta('personalityTraits');
  @override
  late final GeneratedColumn<String> personalityTraits =
      GeneratedColumn<String>('personality_traits', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _evolutionStageMeta =
      const VerificationMeta('evolutionStage');
  @override
  late final GeneratedColumn<String> evolutionStage = GeneratedColumn<String>(
      'evolution_stage', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('base'));
  static const VerificationMeta _conversationCountMeta =
      const VerificationMeta('conversationCount');
  @override
  late final GeneratedColumn<int> conversationCount = GeneratedColumn<int>(
      'conversation_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _depthScoreMeta =
      const VerificationMeta('depthScore');
  @override
  late final GeneratedColumn<double> depthScore = GeneratedColumn<double>(
      'depth_score', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        agentName,
        personalityTraits,
        evolutionStage,
        conversationCount,
        depthScore,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'avatar_personality_profiles';
  @override
  VerificationContext validateIntegrity(
      Insertable<AvatarPersonalityProfile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('agent_name')) {
      context.handle(_agentNameMeta,
          agentName.isAcceptableOrUnknown(data['agent_name']!, _agentNameMeta));
    }
    if (data.containsKey('personality_traits')) {
      context.handle(
          _personalityTraitsMeta,
          personalityTraits.isAcceptableOrUnknown(
              data['personality_traits']!, _personalityTraitsMeta));
    } else if (isInserting) {
      context.missing(_personalityTraitsMeta);
    }
    if (data.containsKey('evolution_stage')) {
      context.handle(
          _evolutionStageMeta,
          evolutionStage.isAcceptableOrUnknown(
              data['evolution_stage']!, _evolutionStageMeta));
    }
    if (data.containsKey('conversation_count')) {
      context.handle(
          _conversationCountMeta,
          conversationCount.isAcceptableOrUnknown(
              data['conversation_count']!, _conversationCountMeta));
    }
    if (data.containsKey('depth_score')) {
      context.handle(
          _depthScoreMeta,
          depthScore.isAcceptableOrUnknown(
              data['depth_score']!, _depthScoreMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AvatarPersonalityProfile map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AvatarPersonalityProfile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      agentName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}agent_name'])!,
      personalityTraits: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}personality_traits'])!,
      evolutionStage: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}evolution_stage'])!,
      conversationCount: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}conversation_count'])!,
      depthScore: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}depth_score'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $AvatarPersonalityProfilesTable createAlias(String alias) {
    return $AvatarPersonalityProfilesTable(attachedDatabase, alias);
  }
}

class AvatarPersonalityProfile extends DataClass
    implements Insertable<AvatarPersonalityProfile> {
  final String id;
  final String agentName;
  final String personalityTraits;
  final String evolutionStage;
  final int conversationCount;
  final double depthScore;
  final int? createdAt;
  final int? updatedAt;
  const AvatarPersonalityProfile(
      {required this.id,
      required this.agentName,
      required this.personalityTraits,
      required this.evolutionStage,
      required this.conversationCount,
      required this.depthScore,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['agent_name'] = Variable<String>(agentName);
    map['personality_traits'] = Variable<String>(personalityTraits);
    map['evolution_stage'] = Variable<String>(evolutionStage);
    map['conversation_count'] = Variable<int>(conversationCount);
    map['depth_score'] = Variable<double>(depthScore);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    return map;
  }

  AvatarPersonalityProfilesCompanion toCompanion(bool nullToAbsent) {
    return AvatarPersonalityProfilesCompanion(
      id: Value(id),
      agentName: Value(agentName),
      personalityTraits: Value(personalityTraits),
      evolutionStage: Value(evolutionStage),
      conversationCount: Value(conversationCount),
      depthScore: Value(depthScore),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory AvatarPersonalityProfile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AvatarPersonalityProfile(
      id: serializer.fromJson<String>(json['id']),
      agentName: serializer.fromJson<String>(json['agentName']),
      personalityTraits: serializer.fromJson<String>(json['personalityTraits']),
      evolutionStage: serializer.fromJson<String>(json['evolutionStage']),
      conversationCount: serializer.fromJson<int>(json['conversationCount']),
      depthScore: serializer.fromJson<double>(json['depthScore']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'agentName': serializer.toJson<String>(agentName),
      'personalityTraits': serializer.toJson<String>(personalityTraits),
      'evolutionStage': serializer.toJson<String>(evolutionStage),
      'conversationCount': serializer.toJson<int>(conversationCount),
      'depthScore': serializer.toJson<double>(depthScore),
      'createdAt': serializer.toJson<int?>(createdAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
    };
  }

  AvatarPersonalityProfile copyWith(
          {String? id,
          String? agentName,
          String? personalityTraits,
          String? evolutionStage,
          int? conversationCount,
          double? depthScore,
          Value<int?> createdAt = const Value.absent(),
          Value<int?> updatedAt = const Value.absent()}) =>
      AvatarPersonalityProfile(
        id: id ?? this.id,
        agentName: agentName ?? this.agentName,
        personalityTraits: personalityTraits ?? this.personalityTraits,
        evolutionStage: evolutionStage ?? this.evolutionStage,
        conversationCount: conversationCount ?? this.conversationCount,
        depthScore: depthScore ?? this.depthScore,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  AvatarPersonalityProfile copyWithCompanion(
      AvatarPersonalityProfilesCompanion data) {
    return AvatarPersonalityProfile(
      id: data.id.present ? data.id.value : this.id,
      agentName: data.agentName.present ? data.agentName.value : this.agentName,
      personalityTraits: data.personalityTraits.present
          ? data.personalityTraits.value
          : this.personalityTraits,
      evolutionStage: data.evolutionStage.present
          ? data.evolutionStage.value
          : this.evolutionStage,
      conversationCount: data.conversationCount.present
          ? data.conversationCount.value
          : this.conversationCount,
      depthScore:
          data.depthScore.present ? data.depthScore.value : this.depthScore,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AvatarPersonalityProfile(')
          ..write('id: $id, ')
          ..write('agentName: $agentName, ')
          ..write('personalityTraits: $personalityTraits, ')
          ..write('evolutionStage: $evolutionStage, ')
          ..write('conversationCount: $conversationCount, ')
          ..write('depthScore: $depthScore, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, agentName, personalityTraits,
      evolutionStage, conversationCount, depthScore, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AvatarPersonalityProfile &&
          other.id == this.id &&
          other.agentName == this.agentName &&
          other.personalityTraits == this.personalityTraits &&
          other.evolutionStage == this.evolutionStage &&
          other.conversationCount == this.conversationCount &&
          other.depthScore == this.depthScore &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AvatarPersonalityProfilesCompanion
    extends UpdateCompanion<AvatarPersonalityProfile> {
  final Value<String> id;
  final Value<String> agentName;
  final Value<String> personalityTraits;
  final Value<String> evolutionStage;
  final Value<int> conversationCount;
  final Value<double> depthScore;
  final Value<int?> createdAt;
  final Value<int?> updatedAt;
  final Value<int> rowid;
  const AvatarPersonalityProfilesCompanion({
    this.id = const Value.absent(),
    this.agentName = const Value.absent(),
    this.personalityTraits = const Value.absent(),
    this.evolutionStage = const Value.absent(),
    this.conversationCount = const Value.absent(),
    this.depthScore = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AvatarPersonalityProfilesCompanion.insert({
    this.id = const Value.absent(),
    this.agentName = const Value.absent(),
    required String personalityTraits,
    this.evolutionStage = const Value.absent(),
    this.conversationCount = const Value.absent(),
    this.depthScore = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : personalityTraits = Value(personalityTraits);
  static Insertable<AvatarPersonalityProfile> custom({
    Expression<String>? id,
    Expression<String>? agentName,
    Expression<String>? personalityTraits,
    Expression<String>? evolutionStage,
    Expression<int>? conversationCount,
    Expression<double>? depthScore,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (agentName != null) 'agent_name': agentName,
      if (personalityTraits != null) 'personality_traits': personalityTraits,
      if (evolutionStage != null) 'evolution_stage': evolutionStage,
      if (conversationCount != null) 'conversation_count': conversationCount,
      if (depthScore != null) 'depth_score': depthScore,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AvatarPersonalityProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String>? agentName,
      Value<String>? personalityTraits,
      Value<String>? evolutionStage,
      Value<int>? conversationCount,
      Value<double>? depthScore,
      Value<int?>? createdAt,
      Value<int?>? updatedAt,
      Value<int>? rowid}) {
    return AvatarPersonalityProfilesCompanion(
      id: id ?? this.id,
      agentName: agentName ?? this.agentName,
      personalityTraits: personalityTraits ?? this.personalityTraits,
      evolutionStage: evolutionStage ?? this.evolutionStage,
      conversationCount: conversationCount ?? this.conversationCount,
      depthScore: depthScore ?? this.depthScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (agentName.present) {
      map['agent_name'] = Variable<String>(agentName.value);
    }
    if (personalityTraits.present) {
      map['personality_traits'] = Variable<String>(personalityTraits.value);
    }
    if (evolutionStage.present) {
      map['evolution_stage'] = Variable<String>(evolutionStage.value);
    }
    if (conversationCount.present) {
      map['conversation_count'] = Variable<int>(conversationCount.value);
    }
    if (depthScore.present) {
      map['depth_score'] = Variable<double>(depthScore.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AvatarPersonalityProfilesCompanion(')
          ..write('id: $id, ')
          ..write('agentName: $agentName, ')
          ..write('personalityTraits: $personalityTraits, ')
          ..write('evolutionStage: $evolutionStage, ')
          ..write('conversationCount: $conversationCount, ')
          ..write('depthScore: $depthScore, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EvolutionHistoryTableTable extends EvolutionHistoryTable
    with TableInfo<$EvolutionHistoryTableTable, EvolutionHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EvolutionHistoryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _avatarIdMeta =
      const VerificationMeta('avatarId');
  @override
  late final GeneratedColumn<String> avatarId = GeneratedColumn<String>(
      'avatar_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES avatar_personality_profiles (id)'));
  static const VerificationMeta _fromStageMeta =
      const VerificationMeta('fromStage');
  @override
  late final GeneratedColumn<String> fromStage = GeneratedColumn<String>(
      'from_stage', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _toStageMeta =
      const VerificationMeta('toStage');
  @override
  late final GeneratedColumn<String> toStage = GeneratedColumn<String>(
      'to_stage', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _triggerReasonMeta =
      const VerificationMeta('triggerReason');
  @override
  late final GeneratedColumn<String> triggerReason = GeneratedColumn<String>(
      'trigger_reason', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contextMeta =
      const VerificationMeta('context');
  @override
  late final GeneratedColumn<String> context = GeneratedColumn<String>(
      'context', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _confirmedByMeta =
      const VerificationMeta('confirmedBy');
  @override
  late final GeneratedColumn<String> confirmedBy = GeneratedColumn<String>(
      'confirmed_by', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _triggeredAtMeta =
      const VerificationMeta('triggeredAt');
  @override
  late final GeneratedColumn<int> triggeredAt = GeneratedColumn<int>(
      'triggered_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        avatarId,
        fromStage,
        toStage,
        triggerReason,
        context,
        confirmedBy,
        triggeredAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'evolution_history_table';
  @override
  VerificationContext validateIntegrity(Insertable<EvolutionHistory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('avatar_id')) {
      context.handle(_avatarIdMeta,
          avatarId.isAcceptableOrUnknown(data['avatar_id']!, _avatarIdMeta));
    } else if (isInserting) {
      context.missing(_avatarIdMeta);
    }
    if (data.containsKey('from_stage')) {
      context.handle(_fromStageMeta,
          fromStage.isAcceptableOrUnknown(data['from_stage']!, _fromStageMeta));
    } else if (isInserting) {
      context.missing(_fromStageMeta);
    }
    if (data.containsKey('to_stage')) {
      context.handle(_toStageMeta,
          toStage.isAcceptableOrUnknown(data['to_stage']!, _toStageMeta));
    } else if (isInserting) {
      context.missing(_toStageMeta);
    }
    if (data.containsKey('trigger_reason')) {
      context.handle(
          _triggerReasonMeta,
          triggerReason.isAcceptableOrUnknown(
              data['trigger_reason']!, _triggerReasonMeta));
    } else if (isInserting) {
      context.missing(_triggerReasonMeta);
    }
    if (data.containsKey('context')) {
      context.handle(_contextMeta,
          this.context.isAcceptableOrUnknown(data['context']!, _contextMeta));
    }
    if (data.containsKey('confirmed_by')) {
      context.handle(
          _confirmedByMeta,
          confirmedBy.isAcceptableOrUnknown(
              data['confirmed_by']!, _confirmedByMeta));
    } else if (isInserting) {
      context.missing(_confirmedByMeta);
    }
    if (data.containsKey('triggered_at')) {
      context.handle(
          _triggeredAtMeta,
          triggeredAt.isAcceptableOrUnknown(
              data['triggered_at']!, _triggeredAtMeta));
    } else if (isInserting) {
      context.missing(_triggeredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EvolutionHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EvolutionHistory(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      avatarId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_id'])!,
      fromStage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}from_stage'])!,
      toStage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}to_stage'])!,
      triggerReason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trigger_reason'])!,
      context: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}context']),
      confirmedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}confirmed_by'])!,
      triggeredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}triggered_at'])!,
    );
  }

  @override
  $EvolutionHistoryTableTable createAlias(String alias) {
    return $EvolutionHistoryTableTable(attachedDatabase, alias);
  }
}

class EvolutionHistory extends DataClass
    implements Insertable<EvolutionHistory> {
  final String id;
  final String avatarId;
  final String fromStage;
  final String toStage;
  final String triggerReason;
  final String? context;
  final String confirmedBy;
  final int triggeredAt;
  const EvolutionHistory(
      {required this.id,
      required this.avatarId,
      required this.fromStage,
      required this.toStage,
      required this.triggerReason,
      this.context,
      required this.confirmedBy,
      required this.triggeredAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['avatar_id'] = Variable<String>(avatarId);
    map['from_stage'] = Variable<String>(fromStage);
    map['to_stage'] = Variable<String>(toStage);
    map['trigger_reason'] = Variable<String>(triggerReason);
    if (!nullToAbsent || context != null) {
      map['context'] = Variable<String>(context);
    }
    map['confirmed_by'] = Variable<String>(confirmedBy);
    map['triggered_at'] = Variable<int>(triggeredAt);
    return map;
  }

  EvolutionHistoryTableCompanion toCompanion(bool nullToAbsent) {
    return EvolutionHistoryTableCompanion(
      id: Value(id),
      avatarId: Value(avatarId),
      fromStage: Value(fromStage),
      toStage: Value(toStage),
      triggerReason: Value(triggerReason),
      context: context == null && nullToAbsent
          ? const Value.absent()
          : Value(context),
      confirmedBy: Value(confirmedBy),
      triggeredAt: Value(triggeredAt),
    );
  }

  factory EvolutionHistory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EvolutionHistory(
      id: serializer.fromJson<String>(json['id']),
      avatarId: serializer.fromJson<String>(json['avatarId']),
      fromStage: serializer.fromJson<String>(json['fromStage']),
      toStage: serializer.fromJson<String>(json['toStage']),
      triggerReason: serializer.fromJson<String>(json['triggerReason']),
      context: serializer.fromJson<String?>(json['context']),
      confirmedBy: serializer.fromJson<String>(json['confirmedBy']),
      triggeredAt: serializer.fromJson<int>(json['triggeredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'avatarId': serializer.toJson<String>(avatarId),
      'fromStage': serializer.toJson<String>(fromStage),
      'toStage': serializer.toJson<String>(toStage),
      'triggerReason': serializer.toJson<String>(triggerReason),
      'context': serializer.toJson<String?>(context),
      'confirmedBy': serializer.toJson<String>(confirmedBy),
      'triggeredAt': serializer.toJson<int>(triggeredAt),
    };
  }

  EvolutionHistory copyWith(
          {String? id,
          String? avatarId,
          String? fromStage,
          String? toStage,
          String? triggerReason,
          Value<String?> context = const Value.absent(),
          String? confirmedBy,
          int? triggeredAt}) =>
      EvolutionHistory(
        id: id ?? this.id,
        avatarId: avatarId ?? this.avatarId,
        fromStage: fromStage ?? this.fromStage,
        toStage: toStage ?? this.toStage,
        triggerReason: triggerReason ?? this.triggerReason,
        context: context.present ? context.value : this.context,
        confirmedBy: confirmedBy ?? this.confirmedBy,
        triggeredAt: triggeredAt ?? this.triggeredAt,
      );
  EvolutionHistory copyWithCompanion(EvolutionHistoryTableCompanion data) {
    return EvolutionHistory(
      id: data.id.present ? data.id.value : this.id,
      avatarId: data.avatarId.present ? data.avatarId.value : this.avatarId,
      fromStage: data.fromStage.present ? data.fromStage.value : this.fromStage,
      toStage: data.toStage.present ? data.toStage.value : this.toStage,
      triggerReason: data.triggerReason.present
          ? data.triggerReason.value
          : this.triggerReason,
      context: data.context.present ? data.context.value : this.context,
      confirmedBy:
          data.confirmedBy.present ? data.confirmedBy.value : this.confirmedBy,
      triggeredAt:
          data.triggeredAt.present ? data.triggeredAt.value : this.triggeredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EvolutionHistory(')
          ..write('id: $id, ')
          ..write('avatarId: $avatarId, ')
          ..write('fromStage: $fromStage, ')
          ..write('toStage: $toStage, ')
          ..write('triggerReason: $triggerReason, ')
          ..write('context: $context, ')
          ..write('confirmedBy: $confirmedBy, ')
          ..write('triggeredAt: $triggeredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, avatarId, fromStage, toStage,
      triggerReason, context, confirmedBy, triggeredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EvolutionHistory &&
          other.id == this.id &&
          other.avatarId == this.avatarId &&
          other.fromStage == this.fromStage &&
          other.toStage == this.toStage &&
          other.triggerReason == this.triggerReason &&
          other.context == this.context &&
          other.confirmedBy == this.confirmedBy &&
          other.triggeredAt == this.triggeredAt);
}

class EvolutionHistoryTableCompanion extends UpdateCompanion<EvolutionHistory> {
  final Value<String> id;
  final Value<String> avatarId;
  final Value<String> fromStage;
  final Value<String> toStage;
  final Value<String> triggerReason;
  final Value<String?> context;
  final Value<String> confirmedBy;
  final Value<int> triggeredAt;
  final Value<int> rowid;
  const EvolutionHistoryTableCompanion({
    this.id = const Value.absent(),
    this.avatarId = const Value.absent(),
    this.fromStage = const Value.absent(),
    this.toStage = const Value.absent(),
    this.triggerReason = const Value.absent(),
    this.context = const Value.absent(),
    this.confirmedBy = const Value.absent(),
    this.triggeredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EvolutionHistoryTableCompanion.insert({
    required String id,
    required String avatarId,
    required String fromStage,
    required String toStage,
    required String triggerReason,
    this.context = const Value.absent(),
    required String confirmedBy,
    required int triggeredAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        avatarId = Value(avatarId),
        fromStage = Value(fromStage),
        toStage = Value(toStage),
        triggerReason = Value(triggerReason),
        confirmedBy = Value(confirmedBy),
        triggeredAt = Value(triggeredAt);
  static Insertable<EvolutionHistory> custom({
    Expression<String>? id,
    Expression<String>? avatarId,
    Expression<String>? fromStage,
    Expression<String>? toStage,
    Expression<String>? triggerReason,
    Expression<String>? context,
    Expression<String>? confirmedBy,
    Expression<int>? triggeredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (avatarId != null) 'avatar_id': avatarId,
      if (fromStage != null) 'from_stage': fromStage,
      if (toStage != null) 'to_stage': toStage,
      if (triggerReason != null) 'trigger_reason': triggerReason,
      if (context != null) 'context': context,
      if (confirmedBy != null) 'confirmed_by': confirmedBy,
      if (triggeredAt != null) 'triggered_at': triggeredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EvolutionHistoryTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? avatarId,
      Value<String>? fromStage,
      Value<String>? toStage,
      Value<String>? triggerReason,
      Value<String?>? context,
      Value<String>? confirmedBy,
      Value<int>? triggeredAt,
      Value<int>? rowid}) {
    return EvolutionHistoryTableCompanion(
      id: id ?? this.id,
      avatarId: avatarId ?? this.avatarId,
      fromStage: fromStage ?? this.fromStage,
      toStage: toStage ?? this.toStage,
      triggerReason: triggerReason ?? this.triggerReason,
      context: context ?? this.context,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (avatarId.present) {
      map['avatar_id'] = Variable<String>(avatarId.value);
    }
    if (fromStage.present) {
      map['from_stage'] = Variable<String>(fromStage.value);
    }
    if (toStage.present) {
      map['to_stage'] = Variable<String>(toStage.value);
    }
    if (triggerReason.present) {
      map['trigger_reason'] = Variable<String>(triggerReason.value);
    }
    if (context.present) {
      map['context'] = Variable<String>(context.value);
    }
    if (confirmedBy.present) {
      map['confirmed_by'] = Variable<String>(confirmedBy.value);
    }
    if (triggeredAt.present) {
      map['triggered_at'] = Variable<int>(triggeredAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EvolutionHistoryTableCompanion(')
          ..write('id: $id, ')
          ..write('avatarId: $avatarId, ')
          ..write('fromStage: $fromStage, ')
          ..write('toStage: $toStage, ')
          ..write('triggerReason: $triggerReason, ')
          ..write('context: $context, ')
          ..write('confirmedBy: $confirmedBy, ')
          ..write('triggeredAt: $triggeredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationDepthMetricsTable extends ConversationDepthMetrics
    with TableInfo<$ConversationDepthMetricsTable, ConversationDepthMetric> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationDepthMetricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES conversations (id)'));
  static const VerificationMeta _complexityScoreMeta =
      const VerificationMeta('complexityScore');
  @override
  late final GeneratedColumn<double> complexityScore = GeneratedColumn<double>(
      'complexity_score', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _emotionalDepthMeta =
      const VerificationMeta('emotionalDepth');
  @override
  late final GeneratedColumn<double> emotionalDepth = GeneratedColumn<double>(
      'emotional_depth', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _noveltyScoreMeta =
      const VerificationMeta('noveltyScore');
  @override
  late final GeneratedColumn<double> noveltyScore = GeneratedColumn<double>(
      'novelty_score', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        conversationId,
        complexityScore,
        emotionalDepth,
        noveltyScore,
        timestamp
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_depth_metrics';
  @override
  VerificationContext validateIntegrity(
      Insertable<ConversationDepthMetric> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('complexity_score')) {
      context.handle(
          _complexityScoreMeta,
          complexityScore.isAcceptableOrUnknown(
              data['complexity_score']!, _complexityScoreMeta));
    } else if (isInserting) {
      context.missing(_complexityScoreMeta);
    }
    if (data.containsKey('emotional_depth')) {
      context.handle(
          _emotionalDepthMeta,
          emotionalDepth.isAcceptableOrUnknown(
              data['emotional_depth']!, _emotionalDepthMeta));
    } else if (isInserting) {
      context.missing(_emotionalDepthMeta);
    }
    if (data.containsKey('novelty_score')) {
      context.handle(
          _noveltyScoreMeta,
          noveltyScore.isAcceptableOrUnknown(
              data['novelty_score']!, _noveltyScoreMeta));
    } else if (isInserting) {
      context.missing(_noveltyScoreMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationDepthMetric map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationDepthMetric(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      complexityScore: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}complexity_score'])!,
      emotionalDepth: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}emotional_depth'])!,
      noveltyScore: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}novelty_score'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $ConversationDepthMetricsTable createAlias(String alias) {
    return $ConversationDepthMetricsTable(attachedDatabase, alias);
  }
}

class ConversationDepthMetric extends DataClass
    implements Insertable<ConversationDepthMetric> {
  final String id;
  final String conversationId;
  final double complexityScore;
  final double emotionalDepth;
  final double noveltyScore;
  final int timestamp;
  const ConversationDepthMetric(
      {required this.id,
      required this.conversationId,
      required this.complexityScore,
      required this.emotionalDepth,
      required this.noveltyScore,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['complexity_score'] = Variable<double>(complexityScore);
    map['emotional_depth'] = Variable<double>(emotionalDepth);
    map['novelty_score'] = Variable<double>(noveltyScore);
    map['timestamp'] = Variable<int>(timestamp);
    return map;
  }

  ConversationDepthMetricsCompanion toCompanion(bool nullToAbsent) {
    return ConversationDepthMetricsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      complexityScore: Value(complexityScore),
      emotionalDepth: Value(emotionalDepth),
      noveltyScore: Value(noveltyScore),
      timestamp: Value(timestamp),
    );
  }

  factory ConversationDepthMetric.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationDepthMetric(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      complexityScore: serializer.fromJson<double>(json['complexityScore']),
      emotionalDepth: serializer.fromJson<double>(json['emotionalDepth']),
      noveltyScore: serializer.fromJson<double>(json['noveltyScore']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'complexityScore': serializer.toJson<double>(complexityScore),
      'emotionalDepth': serializer.toJson<double>(emotionalDepth),
      'noveltyScore': serializer.toJson<double>(noveltyScore),
      'timestamp': serializer.toJson<int>(timestamp),
    };
  }

  ConversationDepthMetric copyWith(
          {String? id,
          String? conversationId,
          double? complexityScore,
          double? emotionalDepth,
          double? noveltyScore,
          int? timestamp}) =>
      ConversationDepthMetric(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        complexityScore: complexityScore ?? this.complexityScore,
        emotionalDepth: emotionalDepth ?? this.emotionalDepth,
        noveltyScore: noveltyScore ?? this.noveltyScore,
        timestamp: timestamp ?? this.timestamp,
      );
  ConversationDepthMetric copyWithCompanion(
      ConversationDepthMetricsCompanion data) {
    return ConversationDepthMetric(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      complexityScore: data.complexityScore.present
          ? data.complexityScore.value
          : this.complexityScore,
      emotionalDepth: data.emotionalDepth.present
          ? data.emotionalDepth.value
          : this.emotionalDepth,
      noveltyScore: data.noveltyScore.present
          ? data.noveltyScore.value
          : this.noveltyScore,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationDepthMetric(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('complexityScore: $complexityScore, ')
          ..write('emotionalDepth: $emotionalDepth, ')
          ..write('noveltyScore: $noveltyScore, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, conversationId, complexityScore,
      emotionalDepth, noveltyScore, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationDepthMetric &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.complexityScore == this.complexityScore &&
          other.emotionalDepth == this.emotionalDepth &&
          other.noveltyScore == this.noveltyScore &&
          other.timestamp == this.timestamp);
}

class ConversationDepthMetricsCompanion
    extends UpdateCompanion<ConversationDepthMetric> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<double> complexityScore;
  final Value<double> emotionalDepth;
  final Value<double> noveltyScore;
  final Value<int> timestamp;
  final Value<int> rowid;
  const ConversationDepthMetricsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.complexityScore = const Value.absent(),
    this.emotionalDepth = const Value.absent(),
    this.noveltyScore = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationDepthMetricsCompanion.insert({
    required String id,
    required String conversationId,
    required double complexityScore,
    required double emotionalDepth,
    required double noveltyScore,
    required int timestamp,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        conversationId = Value(conversationId),
        complexityScore = Value(complexityScore),
        emotionalDepth = Value(emotionalDepth),
        noveltyScore = Value(noveltyScore),
        timestamp = Value(timestamp);
  static Insertable<ConversationDepthMetric> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<double>? complexityScore,
    Expression<double>? emotionalDepth,
    Expression<double>? noveltyScore,
    Expression<int>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (complexityScore != null) 'complexity_score': complexityScore,
      if (emotionalDepth != null) 'emotional_depth': emotionalDepth,
      if (noveltyScore != null) 'novelty_score': noveltyScore,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationDepthMetricsCompanion copyWith(
      {Value<String>? id,
      Value<String>? conversationId,
      Value<double>? complexityScore,
      Value<double>? emotionalDepth,
      Value<double>? noveltyScore,
      Value<int>? timestamp,
      Value<int>? rowid}) {
    return ConversationDepthMetricsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      complexityScore: complexityScore ?? this.complexityScore,
      emotionalDepth: emotionalDepth ?? this.emotionalDepth,
      noveltyScore: noveltyScore ?? this.noveltyScore,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (complexityScore.present) {
      map['complexity_score'] = Variable<double>(complexityScore.value);
    }
    if (emotionalDepth.present) {
      map['emotional_depth'] = Variable<double>(emotionalDepth.value);
    }
    if (noveltyScore.present) {
      map['novelty_score'] = Variable<double>(noveltyScore.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationDepthMetricsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('complexityScore: $complexityScore, ')
          ..write('emotionalDepth: $emotionalDepth, ')
          ..write('noveltyScore: $noveltyScore, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationMemoriesTable extends ConversationMemories
    with TableInfo<$ConversationMemoriesTable, ConversationMemory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationMemoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES conversations (id)'));
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _embeddingMeta =
      const VerificationMeta('embedding');
  @override
  late final GeneratedColumn<String> embedding = GeneratedColumn<String>(
      'embedding', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _summaryMeta =
      const VerificationMeta('summary');
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
      'summary', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, conversationId, content, embedding, timestamp, summary];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_memories';
  @override
  VerificationContext validateIntegrity(Insertable<ConversationMemory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('embedding')) {
      context.handle(_embeddingMeta,
          embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta));
    } else if (isInserting) {
      context.missing(_embeddingMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    if (data.containsKey('summary')) {
      context.handle(_summaryMeta,
          summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationMemory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationMemory(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      embedding: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}embedding'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      summary: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}summary']),
    );
  }

  @override
  $ConversationMemoriesTable createAlias(String alias) {
    return $ConversationMemoriesTable(attachedDatabase, alias);
  }
}

class ConversationMemory extends DataClass
    implements Insertable<ConversationMemory> {
  final String id;
  final String conversationId;
  final String content;
  final String embedding;
  final DateTime timestamp;
  final String? summary;
  const ConversationMemory(
      {required this.id,
      required this.conversationId,
      required this.content,
      required this.embedding,
      required this.timestamp,
      this.summary});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['content'] = Variable<String>(content);
    map['embedding'] = Variable<String>(embedding);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    return map;
  }

  ConversationMemoriesCompanion toCompanion(bool nullToAbsent) {
    return ConversationMemoriesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      content: Value(content),
      embedding: Value(embedding),
      timestamp: Value(timestamp),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
    );
  }

  factory ConversationMemory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationMemory(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      content: serializer.fromJson<String>(json['content']),
      embedding: serializer.fromJson<String>(json['embedding']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      summary: serializer.fromJson<String?>(json['summary']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'content': serializer.toJson<String>(content),
      'embedding': serializer.toJson<String>(embedding),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'summary': serializer.toJson<String?>(summary),
    };
  }

  ConversationMemory copyWith(
          {String? id,
          String? conversationId,
          String? content,
          String? embedding,
          DateTime? timestamp,
          Value<String?> summary = const Value.absent()}) =>
      ConversationMemory(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        content: content ?? this.content,
        embedding: embedding ?? this.embedding,
        timestamp: timestamp ?? this.timestamp,
        summary: summary.present ? summary.value : this.summary,
      );
  ConversationMemory copyWithCompanion(ConversationMemoriesCompanion data) {
    return ConversationMemory(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      content: data.content.present ? data.content.value : this.content,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      summary: data.summary.present ? data.summary.value : this.summary,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMemory(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('content: $content, ')
          ..write('embedding: $embedding, ')
          ..write('timestamp: $timestamp, ')
          ..write('summary: $summary')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, conversationId, content, embedding, timestamp, summary);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationMemory &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.content == this.content &&
          other.embedding == this.embedding &&
          other.timestamp == this.timestamp &&
          other.summary == this.summary);
}

class ConversationMemoriesCompanion
    extends UpdateCompanion<ConversationMemory> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> content;
  final Value<String> embedding;
  final Value<DateTime> timestamp;
  final Value<String?> summary;
  final Value<int> rowid;
  const ConversationMemoriesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.content = const Value.absent(),
    this.embedding = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.summary = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationMemoriesCompanion.insert({
    required String id,
    required String conversationId,
    required String content,
    required String embedding,
    this.timestamp = const Value.absent(),
    this.summary = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        conversationId = Value(conversationId),
        content = Value(content),
        embedding = Value(embedding);
  static Insertable<ConversationMemory> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? content,
    Expression<String>? embedding,
    Expression<DateTime>? timestamp,
    Expression<String>? summary,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (content != null) 'content': content,
      if (embedding != null) 'embedding': embedding,
      if (timestamp != null) 'timestamp': timestamp,
      if (summary != null) 'summary': summary,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationMemoriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? conversationId,
      Value<String>? content,
      Value<String>? embedding,
      Value<DateTime>? timestamp,
      Value<String?>? summary,
      Value<int>? rowid}) {
    return ConversationMemoriesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      content: content ?? this.content,
      embedding: embedding ?? this.embedding,
      timestamp: timestamp ?? this.timestamp,
      summary: summary ?? this.summary,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<String>(embedding.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMemoriesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('content: $content, ')
          ..write('embedding: $embedding, ')
          ..write('timestamp: $timestamp, ')
          ..write('summary: $summary, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentThoughtsTable extends AgentThoughts
    with TableInfo<$AgentThoughtsTable, AgentThought> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentThoughtsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _channelMeta =
      const VerificationMeta('channel');
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
      'channel', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('general'));
  static const VerificationMeta _agentMeta = const VerificationMeta('agent');
  @override
  late final GeneratedColumn<String> agent = GeneratedColumn<String>(
      'agent', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _thoughtTypeMeta =
      const VerificationMeta('thoughtType');
  @override
  late final GeneratedColumn<String> thoughtType = GeneratedColumn<String>(
      'thought_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _metadataMeta =
      const VerificationMeta('metadata');
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
      'metadata', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, timestamp, channel, agent, thoughtType, content, metadata];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_thoughts';
  @override
  VerificationContext validateIntegrity(Insertable<AgentThought> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    if (data.containsKey('channel')) {
      context.handle(_channelMeta,
          channel.isAcceptableOrUnknown(data['channel']!, _channelMeta));
    }
    if (data.containsKey('agent')) {
      context.handle(
          _agentMeta, agent.isAcceptableOrUnknown(data['agent']!, _agentMeta));
    } else if (isInserting) {
      context.missing(_agentMeta);
    }
    if (data.containsKey('thought_type')) {
      context.handle(
          _thoughtTypeMeta,
          thoughtType.isAcceptableOrUnknown(
              data['thought_type']!, _thoughtTypeMeta));
    } else if (isInserting) {
      context.missing(_thoughtTypeMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('metadata')) {
      context.handle(_metadataMeta,
          metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgentThought map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentThought(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      channel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}channel'])!,
      agent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}agent'])!,
      thoughtType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thought_type'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      metadata: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata']),
    );
  }

  @override
  $AgentThoughtsTable createAlias(String alias) {
    return $AgentThoughtsTable(attachedDatabase, alias);
  }
}

class AgentThought extends DataClass implements Insertable<AgentThought> {
  final String id;
  final DateTime timestamp;
  final String channel;
  final String agent;
  final String thoughtType;
  final String content;
  final String? metadata;
  const AgentThought(
      {required this.id,
      required this.timestamp,
      required this.channel,
      required this.agent,
      required this.thoughtType,
      required this.content,
      this.metadata});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['channel'] = Variable<String>(channel);
    map['agent'] = Variable<String>(agent);
    map['thought_type'] = Variable<String>(thoughtType);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    return map;
  }

  AgentThoughtsCompanion toCompanion(bool nullToAbsent) {
    return AgentThoughtsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      channel: Value(channel),
      agent: Value(agent),
      thoughtType: Value(thoughtType),
      content: Value(content),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
    );
  }

  factory AgentThought.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentThought(
      id: serializer.fromJson<String>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      channel: serializer.fromJson<String>(json['channel']),
      agent: serializer.fromJson<String>(json['agent']),
      thoughtType: serializer.fromJson<String>(json['thoughtType']),
      content: serializer.fromJson<String>(json['content']),
      metadata: serializer.fromJson<String?>(json['metadata']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'channel': serializer.toJson<String>(channel),
      'agent': serializer.toJson<String>(agent),
      'thoughtType': serializer.toJson<String>(thoughtType),
      'content': serializer.toJson<String>(content),
      'metadata': serializer.toJson<String?>(metadata),
    };
  }

  AgentThought copyWith(
          {String? id,
          DateTime? timestamp,
          String? channel,
          String? agent,
          String? thoughtType,
          String? content,
          Value<String?> metadata = const Value.absent()}) =>
      AgentThought(
        id: id ?? this.id,
        timestamp: timestamp ?? this.timestamp,
        channel: channel ?? this.channel,
        agent: agent ?? this.agent,
        thoughtType: thoughtType ?? this.thoughtType,
        content: content ?? this.content,
        metadata: metadata.present ? metadata.value : this.metadata,
      );
  AgentThought copyWithCompanion(AgentThoughtsCompanion data) {
    return AgentThought(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      channel: data.channel.present ? data.channel.value : this.channel,
      agent: data.agent.present ? data.agent.value : this.agent,
      thoughtType:
          data.thoughtType.present ? data.thoughtType.value : this.thoughtType,
      content: data.content.present ? data.content.value : this.content,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentThought(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('channel: $channel, ')
          ..write('agent: $agent, ')
          ..write('thoughtType: $thoughtType, ')
          ..write('content: $content, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, timestamp, channel, agent, thoughtType, content, metadata);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentThought &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.channel == this.channel &&
          other.agent == this.agent &&
          other.thoughtType == this.thoughtType &&
          other.content == this.content &&
          other.metadata == this.metadata);
}

class AgentThoughtsCompanion extends UpdateCompanion<AgentThought> {
  final Value<String> id;
  final Value<DateTime> timestamp;
  final Value<String> channel;
  final Value<String> agent;
  final Value<String> thoughtType;
  final Value<String> content;
  final Value<String?> metadata;
  final Value<int> rowid;
  const AgentThoughtsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.channel = const Value.absent(),
    this.agent = const Value.absent(),
    this.thoughtType = const Value.absent(),
    this.content = const Value.absent(),
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentThoughtsCompanion.insert({
    required String id,
    this.timestamp = const Value.absent(),
    this.channel = const Value.absent(),
    required String agent,
    required String thoughtType,
    required String content,
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        agent = Value(agent),
        thoughtType = Value(thoughtType),
        content = Value(content);
  static Insertable<AgentThought> custom({
    Expression<String>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? channel,
    Expression<String>? agent,
    Expression<String>? thoughtType,
    Expression<String>? content,
    Expression<String>? metadata,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (channel != null) 'channel': channel,
      if (agent != null) 'agent': agent,
      if (thoughtType != null) 'thought_type': thoughtType,
      if (content != null) 'content': content,
      if (metadata != null) 'metadata': metadata,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentThoughtsCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? timestamp,
      Value<String>? channel,
      Value<String>? agent,
      Value<String>? thoughtType,
      Value<String>? content,
      Value<String?>? metadata,
      Value<int>? rowid}) {
    return AgentThoughtsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      channel: channel ?? this.channel,
      agent: agent ?? this.agent,
      thoughtType: thoughtType ?? this.thoughtType,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (agent.present) {
      map['agent'] = Variable<String>(agent.value);
    }
    if (thoughtType.present) {
      map['thought_type'] = Variable<String>(thoughtType.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentThoughtsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('channel: $channel, ')
          ..write('agent: $agent, ')
          ..write('thoughtType: $thoughtType, ')
          ..write('content: $content, ')
          ..write('metadata: $metadata, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConscienceDecisionsTable extends ConscienceDecisions
    with TableInfo<$ConscienceDecisionsTable, ConscienceDecision> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConscienceDecisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _riskLevelMeta =
      const VerificationMeta('riskLevel');
  @override
  late final GeneratedColumn<String> riskLevel = GeneratedColumn<String>(
      'risk_level', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _verdictMeta =
      const VerificationMeta('verdict');
  @override
  late final GeneratedColumn<String> verdict = GeneratedColumn<String>(
      'verdict', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _reviewerMeta =
      const VerificationMeta('reviewer');
  @override
  late final GeneratedColumn<String> reviewer = GeneratedColumn<String>(
      'reviewer', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _reasoningMeta =
      const VerificationMeta('reasoning');
  @override
  late final GeneratedColumn<String> reasoning = GeneratedColumn<String>(
      'reasoning', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  @override
  List<GeneratedColumn> get $columns =>
      [id, timestamp, action, riskLevel, verdict, reviewer, reasoning, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conscience_decisions';
  @override
  VerificationContext validateIntegrity(Insertable<ConscienceDecision> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('risk_level')) {
      context.handle(_riskLevelMeta,
          riskLevel.isAcceptableOrUnknown(data['risk_level']!, _riskLevelMeta));
    } else if (isInserting) {
      context.missing(_riskLevelMeta);
    }
    if (data.containsKey('verdict')) {
      context.handle(_verdictMeta,
          verdict.isAcceptableOrUnknown(data['verdict']!, _verdictMeta));
    }
    if (data.containsKey('reviewer')) {
      context.handle(_reviewerMeta,
          reviewer.isAcceptableOrUnknown(data['reviewer']!, _reviewerMeta));
    }
    if (data.containsKey('reasoning')) {
      context.handle(_reasoningMeta,
          reasoning.isAcceptableOrUnknown(data['reasoning']!, _reasoningMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConscienceDecision map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConscienceDecision(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      riskLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}risk_level'])!,
      verdict: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}verdict']),
      reviewer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reviewer']),
      reasoning: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reasoning']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
    );
  }

  @override
  $ConscienceDecisionsTable createAlias(String alias) {
    return $ConscienceDecisionsTable(attachedDatabase, alias);
  }
}

class ConscienceDecision extends DataClass
    implements Insertable<ConscienceDecision> {
  final String id;
  final DateTime timestamp;
  final String action;
  final String riskLevel;
  final String? verdict;
  final String? reviewer;
  final String? reasoning;
  final String status;
  const ConscienceDecision(
      {required this.id,
      required this.timestamp,
      required this.action,
      required this.riskLevel,
      this.verdict,
      this.reviewer,
      this.reasoning,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['action'] = Variable<String>(action);
    map['risk_level'] = Variable<String>(riskLevel);
    if (!nullToAbsent || verdict != null) {
      map['verdict'] = Variable<String>(verdict);
    }
    if (!nullToAbsent || reviewer != null) {
      map['reviewer'] = Variable<String>(reviewer);
    }
    if (!nullToAbsent || reasoning != null) {
      map['reasoning'] = Variable<String>(reasoning);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  ConscienceDecisionsCompanion toCompanion(bool nullToAbsent) {
    return ConscienceDecisionsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      action: Value(action),
      riskLevel: Value(riskLevel),
      verdict: verdict == null && nullToAbsent
          ? const Value.absent()
          : Value(verdict),
      reviewer: reviewer == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewer),
      reasoning: reasoning == null && nullToAbsent
          ? const Value.absent()
          : Value(reasoning),
      status: Value(status),
    );
  }

  factory ConscienceDecision.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConscienceDecision(
      id: serializer.fromJson<String>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      action: serializer.fromJson<String>(json['action']),
      riskLevel: serializer.fromJson<String>(json['riskLevel']),
      verdict: serializer.fromJson<String?>(json['verdict']),
      reviewer: serializer.fromJson<String?>(json['reviewer']),
      reasoning: serializer.fromJson<String?>(json['reasoning']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'action': serializer.toJson<String>(action),
      'riskLevel': serializer.toJson<String>(riskLevel),
      'verdict': serializer.toJson<String?>(verdict),
      'reviewer': serializer.toJson<String?>(reviewer),
      'reasoning': serializer.toJson<String?>(reasoning),
      'status': serializer.toJson<String>(status),
    };
  }

  ConscienceDecision copyWith(
          {String? id,
          DateTime? timestamp,
          String? action,
          String? riskLevel,
          Value<String?> verdict = const Value.absent(),
          Value<String?> reviewer = const Value.absent(),
          Value<String?> reasoning = const Value.absent(),
          String? status}) =>
      ConscienceDecision(
        id: id ?? this.id,
        timestamp: timestamp ?? this.timestamp,
        action: action ?? this.action,
        riskLevel: riskLevel ?? this.riskLevel,
        verdict: verdict.present ? verdict.value : this.verdict,
        reviewer: reviewer.present ? reviewer.value : this.reviewer,
        reasoning: reasoning.present ? reasoning.value : this.reasoning,
        status: status ?? this.status,
      );
  ConscienceDecision copyWithCompanion(ConscienceDecisionsCompanion data) {
    return ConscienceDecision(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      action: data.action.present ? data.action.value : this.action,
      riskLevel: data.riskLevel.present ? data.riskLevel.value : this.riskLevel,
      verdict: data.verdict.present ? data.verdict.value : this.verdict,
      reviewer: data.reviewer.present ? data.reviewer.value : this.reviewer,
      reasoning: data.reasoning.present ? data.reasoning.value : this.reasoning,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConscienceDecision(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('action: $action, ')
          ..write('riskLevel: $riskLevel, ')
          ..write('verdict: $verdict, ')
          ..write('reviewer: $reviewer, ')
          ..write('reasoning: $reasoning, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, timestamp, action, riskLevel, verdict, reviewer, reasoning, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConscienceDecision &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.action == this.action &&
          other.riskLevel == this.riskLevel &&
          other.verdict == this.verdict &&
          other.reviewer == this.reviewer &&
          other.reasoning == this.reasoning &&
          other.status == this.status);
}

class ConscienceDecisionsCompanion extends UpdateCompanion<ConscienceDecision> {
  final Value<String> id;
  final Value<DateTime> timestamp;
  final Value<String> action;
  final Value<String> riskLevel;
  final Value<String?> verdict;
  final Value<String?> reviewer;
  final Value<String?> reasoning;
  final Value<String> status;
  final Value<int> rowid;
  const ConscienceDecisionsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.action = const Value.absent(),
    this.riskLevel = const Value.absent(),
    this.verdict = const Value.absent(),
    this.reviewer = const Value.absent(),
    this.reasoning = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConscienceDecisionsCompanion.insert({
    required String id,
    this.timestamp = const Value.absent(),
    required String action,
    required String riskLevel,
    this.verdict = const Value.absent(),
    this.reviewer = const Value.absent(),
    this.reasoning = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        action = Value(action),
        riskLevel = Value(riskLevel);
  static Insertable<ConscienceDecision> custom({
    Expression<String>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? action,
    Expression<String>? riskLevel,
    Expression<String>? verdict,
    Expression<String>? reviewer,
    Expression<String>? reasoning,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (action != null) 'action': action,
      if (riskLevel != null) 'risk_level': riskLevel,
      if (verdict != null) 'verdict': verdict,
      if (reviewer != null) 'reviewer': reviewer,
      if (reasoning != null) 'reasoning': reasoning,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConscienceDecisionsCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? timestamp,
      Value<String>? action,
      Value<String>? riskLevel,
      Value<String?>? verdict,
      Value<String?>? reviewer,
      Value<String?>? reasoning,
      Value<String>? status,
      Value<int>? rowid}) {
    return ConscienceDecisionsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      action: action ?? this.action,
      riskLevel: riskLevel ?? this.riskLevel,
      verdict: verdict ?? this.verdict,
      reviewer: reviewer ?? this.reviewer,
      reasoning: reasoning ?? this.reasoning,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (riskLevel.present) {
      map['risk_level'] = Variable<String>(riskLevel.value);
    }
    if (verdict.present) {
      map['verdict'] = Variable<String>(verdict.value);
    }
    if (reviewer.present) {
      map['reviewer'] = Variable<String>(reviewer.value);
    }
    if (reasoning.present) {
      map['reasoning'] = Variable<String>(reasoning.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConscienceDecisionsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('action: $action, ')
          ..write('riskLevel: $riskLevel, ')
          ..write('verdict: $verdict, ')
          ..write('reviewer: $reviewer, ')
          ..write('reasoning: $reasoning, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalBrain extends GeneratedDatabase {
  _$LocalBrain(QueryExecutor e) : super(e);
  $LocalBrainManager get managers => $LocalBrainManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $MainChatTimelineRecordsTable mainChatTimelineRecords =
      $MainChatTimelineRecordsTable(this);
  late final $AgentLogsTable agentLogs = $AgentLogsTable(this);
  late final $AgentsTable agents = $AgentsTable(this);
  late final $AgentEventsTable agentEvents = $AgentEventsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $FileIndexTable fileIndex = $FileIndexTable(this);
  late final $FileContentCacheTable fileContentCache =
      $FileContentCacheTable(this);
  late final $LlmProvidersTable llmProviders = $LlmProvidersTable(this);
  late final $ModelCapacityTable modelCapacity = $ModelCapacityTable(this);
  late final $LlmRequestsTable llmRequests = $LlmRequestsTable(this);
  late final $AvatarProfilesTable avatarProfiles = $AvatarProfilesTable(this);
  late final $AchievementsTable achievements = $AchievementsTable(this);
  late final $AvatarMemoryEntriesTable avatarMemoryEntries =
      $AvatarMemoryEntriesTable(this);
  late final $ClipboardHistoryTable clipboardHistory =
      $ClipboardHistoryTable(this);
  late final $ActionHistoryEntriesTable actionHistoryEntries =
      $ActionHistoryEntriesTable(this);
  late final $MacrosTable macros = $MacrosTable(this);
  late final $AvatarPersonalityProfilesTable avatarPersonalityProfiles =
      $AvatarPersonalityProfilesTable(this);
  late final $EvolutionHistoryTableTable evolutionHistoryTable =
      $EvolutionHistoryTableTable(this);
  late final $ConversationDepthMetricsTable conversationDepthMetrics =
      $ConversationDepthMetricsTable(this);
  late final $ConversationMemoriesTable conversationMemories =
      $ConversationMemoriesTable(this);
  late final $AgentThoughtsTable agentThoughts = $AgentThoughtsTable(this);
  late final $ConscienceDecisionsTable conscienceDecisions =
      $ConscienceDecisionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        users,
        conversations,
        messages,
        mainChatTimelineRecords,
        agentLogs,
        agents,
        agentEvents,
        syncQueue,
        fileIndex,
        fileContentCache,
        llmProviders,
        modelCapacity,
        llmRequests,
        avatarProfiles,
        achievements,
        avatarMemoryEntries,
        clipboardHistory,
        actionHistoryEntries,
        macros,
        avatarPersonalityProfiles,
        evolutionHistoryTable,
        conversationDepthMetrics,
        conversationMemories,
        agentThoughts,
        conscienceDecisions
      ];
}

typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  required String id,
  Value<String?> email,
  Value<String?> name,
  Value<String?> nickname,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<String> id,
  Value<String?> email,
  Value<String?> name,
  Value<String?> nickname,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$UsersTableReferences
    extends BaseReferences<_$LocalBrain, $UsersTable, User> {
  $$UsersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ConversationsTable, List<Conversation>>
      _conversationsRefsTable(_$LocalBrain db) =>
          MultiTypedResultKey.fromTable(db.conversations,
              aliasName:
                  $_aliasNameGenerator(db.users.id, db.conversations.userId));

  $$ConversationsTableProcessedTableManager get conversationsRefs {
    final manager = $$ConversationsTableTableManager($_db, $_db.conversations)
        .filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_conversationsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$UsersTableFilterComposer extends Composer<_$LocalBrain, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nickname => $composableBuilder(
      column: $table.nickname, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> conversationsRefs(
      Expression<bool> Function($$ConversationsTableFilterComposer f) f) {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.conversations,
        getReferencedColumn: (t) => t.userId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConversationsTableFilterComposer(
              $db: $db,
              $table: $db.conversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$UsersTableOrderingComposer extends Composer<_$LocalBrain, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nickname => $composableBuilder(
      column: $table.nickname, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$UsersTableAnnotationComposer
    extends Composer<_$LocalBrain, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> conversationsRefs<T extends Object>(
      Expression<T> Function($$ConversationsTableAnnotationComposer a) f) {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.conversations,
        getReferencedColumn: (t) => t.userId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConversationsTableAnnotationComposer(
              $db: $db,
              $table: $db.conversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$UsersTableTableManager extends RootTableManager<
    _$LocalBrain,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, $$UsersTableReferences),
    User,
    PrefetchHooks Function({bool conversationsRefs})> {
  $$UsersTableTableManager(_$LocalBrain db, $UsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<String?> nickname = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UsersCompanion(
            id: id,
            email: email,
            name: name,
            nickname: nickname,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> email = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<String?> nickname = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UsersCompanion.insert(
            id: id,
            email: email,
            name: name,
            nickname: nickname,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$UsersTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({conversationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (conversationsRefs) db.conversations
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (conversationsRefs)
                    await $_getPrefetchedData<User, $UsersTable, Conversation>(
                        currentTable: table,
                        referencedTable:
                            $$UsersTableReferences._conversationsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$UsersTableReferences(db, table, p0)
                                .conversationsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.userId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$UsersTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, $$UsersTableReferences),
    User,
    PrefetchHooks Function({bool conversationsRefs})>;
typedef $$ConversationsTableCreateCompanionBuilder = ConversationsCompanion
    Function({
  required String id,
  required String userId,
  required String title,
  required String model,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$ConversationsTableUpdateCompanionBuilder = ConversationsCompanion
    Function({
  Value<String> id,
  Value<String> userId,
  Value<String> title,
  Value<String> model,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ConversationsTableReferences
    extends BaseReferences<_$LocalBrain, $ConversationsTable, Conversation> {
  $$ConversationsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$LocalBrain db) => db.users
      .createAlias($_aliasNameGenerator(db.conversations.userId, db.users.id));

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager($_db, $_db.users)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$MessagesTable, List<Message>> _messagesRefsTable(
          _$LocalBrain db) =>
      MultiTypedResultKey.fromTable(db.messages,
          aliasName: $_aliasNameGenerator(
              db.conversations.id, db.messages.conversationId));

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager($_db, $_db.messages).filter(
        (f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ConversationDepthMetricsTable,
      List<ConversationDepthMetric>> _conversationDepthMetricsRefsTable(
          _$LocalBrain db) =>
      MultiTypedResultKey.fromTable(db.conversationDepthMetrics,
          aliasName: $_aliasNameGenerator(
              db.conversations.id, db.conversationDepthMetrics.conversationId));

  $$ConversationDepthMetricsTableProcessedTableManager
      get conversationDepthMetricsRefs {
    final manager = $$ConversationDepthMetricsTableTableManager(
            $_db, $_db.conversationDepthMetrics)
        .filter(
            (f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_conversationDepthMetricsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ConversationMemoriesTable,
      List<ConversationMemory>> _conversationMemoriesRefsTable(
          _$LocalBrain db) =>
      MultiTypedResultKey.fromTable(db.conversationMemories,
          aliasName: $_aliasNameGenerator(
              db.conversations.id, db.conversationMemories.conversationId));

  $$ConversationMemoriesTableProcessedTableManager
      get conversationMemoriesRefs {
    final manager = $$ConversationMemoriesTableTableManager(
            $_db, $_db.conversationMemories)
        .filter(
            (f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_conversationMemoriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ConversationsTableFilterComposer
    extends Composer<_$LocalBrain, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.userId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableFilterComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> messagesRefs(
      Expression<bool> Function($$MessagesTableFilterComposer f) f) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.messages,
        getReferencedColumn: (t) => t.conversationId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MessagesTableFilterComposer(
              $db: $db,
              $table: $db.messages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> conversationDepthMetricsRefs(
      Expression<bool> Function($$ConversationDepthMetricsTableFilterComposer f)
          f) {
    final $$ConversationDepthMetricsTableFilterComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.conversationDepthMetrics,
            getReferencedColumn: (t) => t.conversationId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ConversationDepthMetricsTableFilterComposer(
                  $db: $db,
                  $table: $db.conversationDepthMetrics,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<bool> conversationMemoriesRefs(
      Expression<bool> Function($$ConversationMemoriesTableFilterComposer f)
          f) {
    final $$ConversationMemoriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.conversationMemories,
        getReferencedColumn: (t) => t.conversationId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConversationMemoriesTableFilterComposer(
              $db: $db,
              $table: $db.conversationMemories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$LocalBrain, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.userId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableOrderingComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$LocalBrain, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.userId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableAnnotationComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> messagesRefs<T extends Object>(
      Expression<T> Function($$MessagesTableAnnotationComposer a) f) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.messages,
        getReferencedColumn: (t) => t.conversationId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MessagesTableAnnotationComposer(
              $db: $db,
              $table: $db.messages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> conversationDepthMetricsRefs<T extends Object>(
      Expression<T> Function(
              $$ConversationDepthMetricsTableAnnotationComposer a)
          f) {
    final $$ConversationDepthMetricsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.conversationDepthMetrics,
            getReferencedColumn: (t) => t.conversationId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ConversationDepthMetricsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.conversationDepthMetrics,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> conversationMemoriesRefs<T extends Object>(
      Expression<T> Function($$ConversationMemoriesTableAnnotationComposer a)
          f) {
    final $$ConversationMemoriesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.conversationMemories,
            getReferencedColumn: (t) => t.conversationId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ConversationMemoriesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.conversationMemories,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$ConversationsTableTableManager extends RootTableManager<
    _$LocalBrain,
    $ConversationsTable,
    Conversation,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (Conversation, $$ConversationsTableReferences),
    Conversation,
    PrefetchHooks Function(
        {bool userId,
        bool messagesRefs,
        bool conversationDepthMetricsRefs,
        bool conversationMemoriesRefs})> {
  $$ConversationsTableTableManager(_$LocalBrain db, $ConversationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> model = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationsCompanion(
            id: id,
            userId: userId,
            title: title,
            model: model,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String title,
            required String model,
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationsCompanion.insert(
            id: id,
            userId: userId,
            title: title,
            model: model,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ConversationsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {userId = false,
              messagesRefs = false,
              conversationDepthMetricsRefs = false,
              conversationMemoriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (messagesRefs) db.messages,
                if (conversationDepthMetricsRefs) db.conversationDepthMetrics,
                if (conversationMemoriesRefs) db.conversationMemories
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (userId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.userId,
                    referencedTable:
                        $$ConversationsTableReferences._userIdTable(db),
                    referencedColumn:
                        $$ConversationsTableReferences._userIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (messagesRefs)
                    await $_getPrefetchedData<Conversation, $ConversationsTable,
                            Message>(
                        currentTable: table,
                        referencedTable: $$ConversationsTableReferences
                            ._messagesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ConversationsTableReferences(db, table, p0)
                                .messagesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.conversationId == item.id),
                        typedResults: items),
                  if (conversationDepthMetricsRefs)
                    await $_getPrefetchedData<Conversation, $ConversationsTable,
                            ConversationDepthMetric>(
                        currentTable: table,
                        referencedTable: $$ConversationsTableReferences
                            ._conversationDepthMetricsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ConversationsTableReferences(db, table, p0)
                                .conversationDepthMetricsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.conversationId == item.id),
                        typedResults: items),
                  if (conversationMemoriesRefs)
                    await $_getPrefetchedData<Conversation, $ConversationsTable,
                            ConversationMemory>(
                        currentTable: table,
                        referencedTable: $$ConversationsTableReferences
                            ._conversationMemoriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ConversationsTableReferences(db, table, p0)
                                .conversationMemoriesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.conversationId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ConversationsTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $ConversationsTable,
    Conversation,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (Conversation, $$ConversationsTableReferences),
    Conversation,
    PrefetchHooks Function(
        {bool userId,
        bool messagesRefs,
        bool conversationDepthMetricsRefs,
        bool conversationMemoriesRefs})>;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  required String conversationId,
  required String role,
  required String content,
  Value<String?> model,
  Value<DateTime> timestamp,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  Value<String> conversationId,
  Value<String> role,
  Value<String> content,
  Value<String?> model,
  Value<DateTime> timestamp,
});

final class $$MessagesTableReferences
    extends BaseReferences<_$LocalBrain, $MessagesTable, Message> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConversationsTable _conversationIdTable(_$LocalBrain db) =>
      db.conversations.createAlias($_aliasNameGenerator(
          db.messages.conversationId, db.conversations.id));

  $$ConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableManager($_db, $_db.conversations)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$LocalBrain, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conversationId,
        referencedTable: $db.conversations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConversationsTableFilterComposer(
              $db: $db,
              $table: $db.conversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$LocalBrain, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conversationId,
        referencedTable: $db.conversations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConversationsTableOrderingComposer(
              $db: $db,
              $table: $db.conversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$LocalBrain, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conversationId,
        referencedTable: $db.conversations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConversationsTableAnnotationComposer(
              $db: $db,
              $table: $db.conversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MessagesTableTableManager extends RootTableManager<
    _$LocalBrain,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, $$MessagesTableReferences),
    Message,
    PrefetchHooks Function({bool conversationId})> {
  $$MessagesTableTableManager(_$LocalBrain db, $MessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> conversationId = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String?> model = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              MessagesCompanion(
            id: id,
            conversationId: conversationId,
            role: role,
            content: content,
            model: model,
            timestamp: timestamp,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String conversationId,
            required String role,
            required String content,
            Value<String?> model = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              MessagesCompanion.insert(
            id: id,
            conversationId: conversationId,
            role: role,
            content: content,
            model: model,
            timestamp: timestamp,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$MessagesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (conversationId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.conversationId,
                    referencedTable:
                        $$MessagesTableReferences._conversationIdTable(db),
                    referencedColumn:
                        $$MessagesTableReferences._conversationIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$MessagesTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, $$MessagesTableReferences),
    Message,
    PrefetchHooks Function({bool conversationId})>;
typedef $$MainChatTimelineRecordsTableCreateCompanionBuilder
    = MainChatTimelineRecordsCompanion Function({
  required String recordId,
  required String eventId,
  required int revision,
  required String sourceDeviceId,
  required int sourceSequence,
  required String scope,
  Value<String?> conversationId,
  required String eventType,
  required String sourceKind,
  Value<String?> sourceId,
  required DateTime timestampUtc,
  required DateTime observedAtUtc,
  required String title,
  Value<String?> summary,
  Value<String?> bodyRedacted,
  Value<String?> artifactName,
  Value<String?> localArtifactPath,
  required String safeMetadataJson,
  required String localOnlyMetadataJson,
  required String syncPolicy,
  required String sensitivity,
  required int redactionVersion,
  required int payloadVersion,
  Value<int> rowid,
});
typedef $$MainChatTimelineRecordsTableUpdateCompanionBuilder
    = MainChatTimelineRecordsCompanion Function({
  Value<String> recordId,
  Value<String> eventId,
  Value<int> revision,
  Value<String> sourceDeviceId,
  Value<int> sourceSequence,
  Value<String> scope,
  Value<String?> conversationId,
  Value<String> eventType,
  Value<String> sourceKind,
  Value<String?> sourceId,
  Value<DateTime> timestampUtc,
  Value<DateTime> observedAtUtc,
  Value<String> title,
  Value<String?> summary,
  Value<String?> bodyRedacted,
  Value<String?> artifactName,
  Value<String?> localArtifactPath,
  Value<String> safeMetadataJson,
  Value<String> localOnlyMetadataJson,
  Value<String> syncPolicy,
  Value<String> sensitivity,
  Value<int> redactionVersion,
  Value<int> payloadVersion,
  Value<int> rowid,
});

class $$MainChatTimelineRecordsTableFilterComposer
    extends Composer<_$LocalBrain, $MainChatTimelineRecordsTable> {
  $$MainChatTimelineRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceDeviceId => $composableBuilder(
      column: $table.sourceDeviceId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sourceSequence => $composableBuilder(
      column: $table.sourceSequence,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceKind => $composableBuilder(
      column: $table.sourceKind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceId => $composableBuilder(
      column: $table.sourceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestampUtc => $composableBuilder(
      column: $table.timestampUtc, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get observedAtUtc => $composableBuilder(
      column: $table.observedAtUtc, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bodyRedacted => $composableBuilder(
      column: $table.bodyRedacted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artifactName => $composableBuilder(
      column: $table.artifactName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localArtifactPath => $composableBuilder(
      column: $table.localArtifactPath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get safeMetadataJson => $composableBuilder(
      column: $table.safeMetadataJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localOnlyMetadataJson => $composableBuilder(
      column: $table.localOnlyMetadataJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncPolicy => $composableBuilder(
      column: $table.syncPolicy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sensitivity => $composableBuilder(
      column: $table.sensitivity, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get redactionVersion => $composableBuilder(
      column: $table.redactionVersion,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get payloadVersion => $composableBuilder(
      column: $table.payloadVersion,
      builder: (column) => ColumnFilters(column));
}

class $$MainChatTimelineRecordsTableOrderingComposer
    extends Composer<_$LocalBrain, $MainChatTimelineRecordsTable> {
  $$MainChatTimelineRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceDeviceId => $composableBuilder(
      column: $table.sourceDeviceId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sourceSequence => $composableBuilder(
      column: $table.sourceSequence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceKind => $composableBuilder(
      column: $table.sourceKind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceId => $composableBuilder(
      column: $table.sourceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestampUtc => $composableBuilder(
      column: $table.timestampUtc,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get observedAtUtc => $composableBuilder(
      column: $table.observedAtUtc,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bodyRedacted => $composableBuilder(
      column: $table.bodyRedacted,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artifactName => $composableBuilder(
      column: $table.artifactName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localArtifactPath => $composableBuilder(
      column: $table.localArtifactPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get safeMetadataJson => $composableBuilder(
      column: $table.safeMetadataJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localOnlyMetadataJson => $composableBuilder(
      column: $table.localOnlyMetadataJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncPolicy => $composableBuilder(
      column: $table.syncPolicy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sensitivity => $composableBuilder(
      column: $table.sensitivity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get redactionVersion => $composableBuilder(
      column: $table.redactionVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get payloadVersion => $composableBuilder(
      column: $table.payloadVersion,
      builder: (column) => ColumnOrderings(column));
}

class $$MainChatTimelineRecordsTableAnnotationComposer
    extends Composer<_$LocalBrain, $MainChatTimelineRecordsTable> {
  $$MainChatTimelineRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get sourceDeviceId => $composableBuilder(
      column: $table.sourceDeviceId, builder: (column) => column);

  GeneratedColumn<int> get sourceSequence => $composableBuilder(
      column: $table.sourceSequence, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get sourceKind => $composableBuilder(
      column: $table.sourceKind, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<DateTime> get timestampUtc => $composableBuilder(
      column: $table.timestampUtc, builder: (column) => column);

  GeneratedColumn<DateTime> get observedAtUtc => $composableBuilder(
      column: $table.observedAtUtc, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get bodyRedacted => $composableBuilder(
      column: $table.bodyRedacted, builder: (column) => column);

  GeneratedColumn<String> get artifactName => $composableBuilder(
      column: $table.artifactName, builder: (column) => column);

  GeneratedColumn<String> get localArtifactPath => $composableBuilder(
      column: $table.localArtifactPath, builder: (column) => column);

  GeneratedColumn<String> get safeMetadataJson => $composableBuilder(
      column: $table.safeMetadataJson, builder: (column) => column);

  GeneratedColumn<String> get localOnlyMetadataJson => $composableBuilder(
      column: $table.localOnlyMetadataJson, builder: (column) => column);

  GeneratedColumn<String> get syncPolicy => $composableBuilder(
      column: $table.syncPolicy, builder: (column) => column);

  GeneratedColumn<String> get sensitivity => $composableBuilder(
      column: $table.sensitivity, builder: (column) => column);

  GeneratedColumn<int> get redactionVersion => $composableBuilder(
      column: $table.redactionVersion, builder: (column) => column);

  GeneratedColumn<int> get payloadVersion => $composableBuilder(
      column: $table.payloadVersion, builder: (column) => column);
}

class $$MainChatTimelineRecordsTableTableManager extends RootTableManager<
    _$LocalBrain,
    $MainChatTimelineRecordsTable,
    MainChatTimelineDbRecord,
    $$MainChatTimelineRecordsTableFilterComposer,
    $$MainChatTimelineRecordsTableOrderingComposer,
    $$MainChatTimelineRecordsTableAnnotationComposer,
    $$MainChatTimelineRecordsTableCreateCompanionBuilder,
    $$MainChatTimelineRecordsTableUpdateCompanionBuilder,
    (
      MainChatTimelineDbRecord,
      BaseReferences<_$LocalBrain, $MainChatTimelineRecordsTable,
          MainChatTimelineDbRecord>
    ),
    MainChatTimelineDbRecord,
    PrefetchHooks Function()> {
  $$MainChatTimelineRecordsTableTableManager(
      _$LocalBrain db, $MainChatTimelineRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MainChatTimelineRecordsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$MainChatTimelineRecordsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MainChatTimelineRecordsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> recordId = const Value.absent(),
            Value<String> eventId = const Value.absent(),
            Value<int> revision = const Value.absent(),
            Value<String> sourceDeviceId = const Value.absent(),
            Value<int> sourceSequence = const Value.absent(),
            Value<String> scope = const Value.absent(),
            Value<String?> conversationId = const Value.absent(),
            Value<String> eventType = const Value.absent(),
            Value<String> sourceKind = const Value.absent(),
            Value<String?> sourceId = const Value.absent(),
            Value<DateTime> timestampUtc = const Value.absent(),
            Value<DateTime> observedAtUtc = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> summary = const Value.absent(),
            Value<String?> bodyRedacted = const Value.absent(),
            Value<String?> artifactName = const Value.absent(),
            Value<String?> localArtifactPath = const Value.absent(),
            Value<String> safeMetadataJson = const Value.absent(),
            Value<String> localOnlyMetadataJson = const Value.absent(),
            Value<String> syncPolicy = const Value.absent(),
            Value<String> sensitivity = const Value.absent(),
            Value<int> redactionVersion = const Value.absent(),
            Value<int> payloadVersion = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MainChatTimelineRecordsCompanion(
            recordId: recordId,
            eventId: eventId,
            revision: revision,
            sourceDeviceId: sourceDeviceId,
            sourceSequence: sourceSequence,
            scope: scope,
            conversationId: conversationId,
            eventType: eventType,
            sourceKind: sourceKind,
            sourceId: sourceId,
            timestampUtc: timestampUtc,
            observedAtUtc: observedAtUtc,
            title: title,
            summary: summary,
            bodyRedacted: bodyRedacted,
            artifactName: artifactName,
            localArtifactPath: localArtifactPath,
            safeMetadataJson: safeMetadataJson,
            localOnlyMetadataJson: localOnlyMetadataJson,
            syncPolicy: syncPolicy,
            sensitivity: sensitivity,
            redactionVersion: redactionVersion,
            payloadVersion: payloadVersion,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String recordId,
            required String eventId,
            required int revision,
            required String sourceDeviceId,
            required int sourceSequence,
            required String scope,
            Value<String?> conversationId = const Value.absent(),
            required String eventType,
            required String sourceKind,
            Value<String?> sourceId = const Value.absent(),
            required DateTime timestampUtc,
            required DateTime observedAtUtc,
            required String title,
            Value<String?> summary = const Value.absent(),
            Value<String?> bodyRedacted = const Value.absent(),
            Value<String?> artifactName = const Value.absent(),
            Value<String?> localArtifactPath = const Value.absent(),
            required String safeMetadataJson,
            required String localOnlyMetadataJson,
            required String syncPolicy,
            required String sensitivity,
            required int redactionVersion,
            required int payloadVersion,
            Value<int> rowid = const Value.absent(),
          }) =>
              MainChatTimelineRecordsCompanion.insert(
            recordId: recordId,
            eventId: eventId,
            revision: revision,
            sourceDeviceId: sourceDeviceId,
            sourceSequence: sourceSequence,
            scope: scope,
            conversationId: conversationId,
            eventType: eventType,
            sourceKind: sourceKind,
            sourceId: sourceId,
            timestampUtc: timestampUtc,
            observedAtUtc: observedAtUtc,
            title: title,
            summary: summary,
            bodyRedacted: bodyRedacted,
            artifactName: artifactName,
            localArtifactPath: localArtifactPath,
            safeMetadataJson: safeMetadataJson,
            localOnlyMetadataJson: localOnlyMetadataJson,
            syncPolicy: syncPolicy,
            sensitivity: sensitivity,
            redactionVersion: redactionVersion,
            payloadVersion: payloadVersion,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MainChatTimelineRecordsTableProcessedTableManager
    = ProcessedTableManager<
        _$LocalBrain,
        $MainChatTimelineRecordsTable,
        MainChatTimelineDbRecord,
        $$MainChatTimelineRecordsTableFilterComposer,
        $$MainChatTimelineRecordsTableOrderingComposer,
        $$MainChatTimelineRecordsTableAnnotationComposer,
        $$MainChatTimelineRecordsTableCreateCompanionBuilder,
        $$MainChatTimelineRecordsTableUpdateCompanionBuilder,
        (
          MainChatTimelineDbRecord,
          BaseReferences<_$LocalBrain, $MainChatTimelineRecordsTable,
              MainChatTimelineDbRecord>
        ),
        MainChatTimelineDbRecord,
        PrefetchHooks Function()>;
typedef $$AgentLogsTableCreateCompanionBuilder = AgentLogsCompanion Function({
  Value<int> id,
  required String level,
  required String message,
  Value<String?> context,
  Value<DateTime> timestamp,
});
typedef $$AgentLogsTableUpdateCompanionBuilder = AgentLogsCompanion Function({
  Value<int> id,
  Value<String> level,
  Value<String> message,
  Value<String?> context,
  Value<DateTime> timestamp,
});

class $$AgentLogsTableFilterComposer
    extends Composer<_$LocalBrain, $AgentLogsTable> {
  $$AgentLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get message => $composableBuilder(
      column: $table.message, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get context => $composableBuilder(
      column: $table.context, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$AgentLogsTableOrderingComposer
    extends Composer<_$LocalBrain, $AgentLogsTable> {
  $$AgentLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get message => $composableBuilder(
      column: $table.message, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get context => $composableBuilder(
      column: $table.context, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$AgentLogsTableAnnotationComposer
    extends Composer<_$LocalBrain, $AgentLogsTable> {
  $$AgentLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get context =>
      $composableBuilder(column: $table.context, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$AgentLogsTableTableManager extends RootTableManager<
    _$LocalBrain,
    $AgentLogsTable,
    AgentLog,
    $$AgentLogsTableFilterComposer,
    $$AgentLogsTableOrderingComposer,
    $$AgentLogsTableAnnotationComposer,
    $$AgentLogsTableCreateCompanionBuilder,
    $$AgentLogsTableUpdateCompanionBuilder,
    (AgentLog, BaseReferences<_$LocalBrain, $AgentLogsTable, AgentLog>),
    AgentLog,
    PrefetchHooks Function()> {
  $$AgentLogsTableTableManager(_$LocalBrain db, $AgentLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> level = const Value.absent(),
            Value<String> message = const Value.absent(),
            Value<String?> context = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              AgentLogsCompanion(
            id: id,
            level: level,
            message: message,
            context: context,
            timestamp: timestamp,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String level,
            required String message,
            Value<String?> context = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              AgentLogsCompanion.insert(
            id: id,
            level: level,
            message: message,
            context: context,
            timestamp: timestamp,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AgentLogsTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $AgentLogsTable,
    AgentLog,
    $$AgentLogsTableFilterComposer,
    $$AgentLogsTableOrderingComposer,
    $$AgentLogsTableAnnotationComposer,
    $$AgentLogsTableCreateCompanionBuilder,
    $$AgentLogsTableUpdateCompanionBuilder,
    (AgentLog, BaseReferences<_$LocalBrain, $AgentLogsTable, AgentLog>),
    AgentLog,
    PrefetchHooks Function()>;
typedef $$AgentsTableCreateCompanionBuilder = AgentsCompanion Function({
  required String id,
  required String name,
  required String agentId,
  Value<String> type,
  Value<String> status,
  Value<String?> activity,
  Value<DateTime?> lastUpdate,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$AgentsTableUpdateCompanionBuilder = AgentsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> agentId,
  Value<String> type,
  Value<String> status,
  Value<String?> activity,
  Value<DateTime?> lastUpdate,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$AgentsTableFilterComposer extends Composer<_$LocalBrain, $AgentsTable> {
  $$AgentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get agentId => $composableBuilder(
      column: $table.agentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get activity => $composableBuilder(
      column: $table.activity, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdate => $composableBuilder(
      column: $table.lastUpdate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$AgentsTableOrderingComposer
    extends Composer<_$LocalBrain, $AgentsTable> {
  $$AgentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get agentId => $composableBuilder(
      column: $table.agentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get activity => $composableBuilder(
      column: $table.activity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdate => $composableBuilder(
      column: $table.lastUpdate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AgentsTableAnnotationComposer
    extends Composer<_$LocalBrain, $AgentsTable> {
  $$AgentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get activity =>
      $composableBuilder(column: $table.activity, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdate => $composableBuilder(
      column: $table.lastUpdate, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AgentsTableTableManager extends RootTableManager<
    _$LocalBrain,
    $AgentsTable,
    Agent,
    $$AgentsTableFilterComposer,
    $$AgentsTableOrderingComposer,
    $$AgentsTableAnnotationComposer,
    $$AgentsTableCreateCompanionBuilder,
    $$AgentsTableUpdateCompanionBuilder,
    (Agent, BaseReferences<_$LocalBrain, $AgentsTable, Agent>),
    Agent,
    PrefetchHooks Function()> {
  $$AgentsTableTableManager(_$LocalBrain db, $AgentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> agentId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> activity = const Value.absent(),
            Value<DateTime?> lastUpdate = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AgentsCompanion(
            id: id,
            name: name,
            agentId: agentId,
            type: type,
            status: status,
            activity: activity,
            lastUpdate: lastUpdate,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String agentId,
            Value<String> type = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> activity = const Value.absent(),
            Value<DateTime?> lastUpdate = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AgentsCompanion.insert(
            id: id,
            name: name,
            agentId: agentId,
            type: type,
            status: status,
            activity: activity,
            lastUpdate: lastUpdate,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AgentsTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $AgentsTable,
    Agent,
    $$AgentsTableFilterComposer,
    $$AgentsTableOrderingComposer,
    $$AgentsTableAnnotationComposer,
    $$AgentsTableCreateCompanionBuilder,
    $$AgentsTableUpdateCompanionBuilder,
    (Agent, BaseReferences<_$LocalBrain, $AgentsTable, Agent>),
    Agent,
    PrefetchHooks Function()>;
typedef $$AgentEventsTableCreateCompanionBuilder = AgentEventsCompanion
    Function({
  required String id,
  required String agentId,
  required String eventType,
  required String eventData,
  Value<String?> correlationId,
  Value<DateTime> timestamp,
  Value<bool> synced,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});
typedef $$AgentEventsTableUpdateCompanionBuilder = AgentEventsCompanion
    Function({
  Value<String> id,
  Value<String> agentId,
  Value<String> eventType,
  Value<String> eventData,
  Value<String?> correlationId,
  Value<DateTime> timestamp,
  Value<bool> synced,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});

class $$AgentEventsTableFilterComposer
    extends Composer<_$LocalBrain, $AgentEventsTable> {
  $$AgentEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get agentId => $composableBuilder(
      column: $table.agentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventData => $composableBuilder(
      column: $table.eventData, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get correlationId => $composableBuilder(
      column: $table.correlationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$AgentEventsTableOrderingComposer
    extends Composer<_$LocalBrain, $AgentEventsTable> {
  $$AgentEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get agentId => $composableBuilder(
      column: $table.agentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventData => $composableBuilder(
      column: $table.eventData, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get correlationId => $composableBuilder(
      column: $table.correlationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$AgentEventsTableAnnotationComposer
    extends Composer<_$LocalBrain, $AgentEventsTable> {
  $$AgentEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get eventData =>
      $composableBuilder(column: $table.eventData, builder: (column) => column);

  GeneratedColumn<String> get correlationId => $composableBuilder(
      column: $table.correlationId, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$AgentEventsTableTableManager extends RootTableManager<
    _$LocalBrain,
    $AgentEventsTable,
    AgentEvent,
    $$AgentEventsTableFilterComposer,
    $$AgentEventsTableOrderingComposer,
    $$AgentEventsTableAnnotationComposer,
    $$AgentEventsTableCreateCompanionBuilder,
    $$AgentEventsTableUpdateCompanionBuilder,
    (AgentEvent, BaseReferences<_$LocalBrain, $AgentEventsTable, AgentEvent>),
    AgentEvent,
    PrefetchHooks Function()> {
  $$AgentEventsTableTableManager(_$LocalBrain db, $AgentEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> agentId = const Value.absent(),
            Value<String> eventType = const Value.absent(),
            Value<String> eventData = const Value.absent(),
            Value<String?> correlationId = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<bool> synced = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AgentEventsCompanion(
            id: id,
            agentId: agentId,
            eventType: eventType,
            eventData: eventData,
            correlationId: correlationId,
            timestamp: timestamp,
            synced: synced,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String agentId,
            required String eventType,
            required String eventData,
            Value<String?> correlationId = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<bool> synced = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AgentEventsCompanion.insert(
            id: id,
            agentId: agentId,
            eventType: eventType,
            eventData: eventData,
            correlationId: correlationId,
            timestamp: timestamp,
            synced: synced,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AgentEventsTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $AgentEventsTable,
    AgentEvent,
    $$AgentEventsTableFilterComposer,
    $$AgentEventsTableOrderingComposer,
    $$AgentEventsTableAnnotationComposer,
    $$AgentEventsTableCreateCompanionBuilder,
    $$AgentEventsTableUpdateCompanionBuilder,
    (AgentEvent, BaseReferences<_$LocalBrain, $AgentEventsTable, AgentEvent>),
    AgentEvent,
    PrefetchHooks Function()>;
typedef $$SyncQueueTableCreateCompanionBuilder = SyncQueueCompanion Function({
  Value<int> id,
  required String targetTable,
  required String operation,
  required String recordId,
  required String payload,
  Value<DateTime> createdAt,
  Value<int> retryCount,
});
typedef $$SyncQueueTableUpdateCompanionBuilder = SyncQueueCompanion Function({
  Value<int> id,
  Value<String> targetTable,
  Value<String> operation,
  Value<String> recordId,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<int> retryCount,
});

class $$SyncQueueTableFilterComposer
    extends Composer<_$LocalBrain, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$LocalBrain, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$LocalBrain, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);
}

class $$SyncQueueTableTableManager extends RootTableManager<
    _$LocalBrain,
    $SyncQueueTable,
    SyncQueueData,
    $$SyncQueueTableFilterComposer,
    $$SyncQueueTableOrderingComposer,
    $$SyncQueueTableAnnotationComposer,
    $$SyncQueueTableCreateCompanionBuilder,
    $$SyncQueueTableUpdateCompanionBuilder,
    (
      SyncQueueData,
      BaseReferences<_$LocalBrain, $SyncQueueTable, SyncQueueData>
    ),
    SyncQueueData,
    PrefetchHooks Function()> {
  $$SyncQueueTableTableManager(_$LocalBrain db, $SyncQueueTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> targetTable = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<String> recordId = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
          }) =>
              SyncQueueCompanion(
            id: id,
            targetTable: targetTable,
            operation: operation,
            recordId: recordId,
            payload: payload,
            createdAt: createdAt,
            retryCount: retryCount,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String targetTable,
            required String operation,
            required String recordId,
            required String payload,
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
          }) =>
              SyncQueueCompanion.insert(
            id: id,
            targetTable: targetTable,
            operation: operation,
            recordId: recordId,
            payload: payload,
            createdAt: createdAt,
            retryCount: retryCount,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncQueueTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $SyncQueueTable,
    SyncQueueData,
    $$SyncQueueTableFilterComposer,
    $$SyncQueueTableOrderingComposer,
    $$SyncQueueTableAnnotationComposer,
    $$SyncQueueTableCreateCompanionBuilder,
    $$SyncQueueTableUpdateCompanionBuilder,
    (
      SyncQueueData,
      BaseReferences<_$LocalBrain, $SyncQueueTable, SyncQueueData>
    ),
    SyncQueueData,
    PrefetchHooks Function()>;
typedef $$FileIndexTableCreateCompanionBuilder = FileIndexCompanion Function({
  Value<int> id,
  required String path,
  required String filename,
  Value<String?> extension,
  Value<int?> size,
  Value<DateTime?> modifiedAt,
  Value<String?> contentHash,
  Value<String?> mimeType,
  Value<bool> isDirectory,
  Value<String?> parentPath,
  Value<DateTime> indexedAt,
});
typedef $$FileIndexTableUpdateCompanionBuilder = FileIndexCompanion Function({
  Value<int> id,
  Value<String> path,
  Value<String> filename,
  Value<String?> extension,
  Value<int?> size,
  Value<DateTime?> modifiedAt,
  Value<String?> contentHash,
  Value<String?> mimeType,
  Value<bool> isDirectory,
  Value<String?> parentPath,
  Value<DateTime> indexedAt,
});

final class $$FileIndexTableReferences
    extends BaseReferences<_$LocalBrain, $FileIndexTable, FileIndexData> {
  $$FileIndexTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FileContentCacheTable, List<FileContentCacheData>>
      _fileContentCacheRefsTable(_$LocalBrain db) =>
          MultiTypedResultKey.fromTable(db.fileContentCache,
              aliasName: $_aliasNameGenerator(
                  db.fileIndex.path, db.fileContentCache.filePath));

  $$FileContentCacheTableProcessedTableManager get fileContentCacheRefs {
    final manager =
        $$FileContentCacheTableTableManager($_db, $_db.fileContentCache).filter(
            (f) => f.filePath.path.sqlEquals($_itemColumn<String>('path')!));

    final cache =
        $_typedResult.readTableOrNull(_fileContentCacheRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$FileIndexTableFilterComposer
    extends Composer<_$LocalBrain, $FileIndexTable> {
  $$FileIndexTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filename => $composableBuilder(
      column: $table.filename, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get extension => $composableBuilder(
      column: $table.extension, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedAt => $composableBuilder(
      column: $table.modifiedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDirectory => $composableBuilder(
      column: $table.isDirectory, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentPath => $composableBuilder(
      column: $table.parentPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get indexedAt => $composableBuilder(
      column: $table.indexedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> fileContentCacheRefs(
      Expression<bool> Function($$FileContentCacheTableFilterComposer f) f) {
    final $$FileContentCacheTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.path,
        referencedTable: $db.fileContentCache,
        getReferencedColumn: (t) => t.filePath,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FileContentCacheTableFilterComposer(
              $db: $db,
              $table: $db.fileContentCache,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$FileIndexTableOrderingComposer
    extends Composer<_$LocalBrain, $FileIndexTable> {
  $$FileIndexTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filename => $composableBuilder(
      column: $table.filename, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get extension => $composableBuilder(
      column: $table.extension, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedAt => $composableBuilder(
      column: $table.modifiedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDirectory => $composableBuilder(
      column: $table.isDirectory, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentPath => $composableBuilder(
      column: $table.parentPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get indexedAt => $composableBuilder(
      column: $table.indexedAt, builder: (column) => ColumnOrderings(column));
}

class $$FileIndexTableAnnotationComposer
    extends Composer<_$LocalBrain, $FileIndexTable> {
  $$FileIndexTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get filename =>
      $composableBuilder(column: $table.filename, builder: (column) => column);

  GeneratedColumn<String> get extension =>
      $composableBuilder(column: $table.extension, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedAt => $composableBuilder(
      column: $table.modifiedAt, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<bool> get isDirectory => $composableBuilder(
      column: $table.isDirectory, builder: (column) => column);

  GeneratedColumn<String> get parentPath => $composableBuilder(
      column: $table.parentPath, builder: (column) => column);

  GeneratedColumn<DateTime> get indexedAt =>
      $composableBuilder(column: $table.indexedAt, builder: (column) => column);

  Expression<T> fileContentCacheRefs<T extends Object>(
      Expression<T> Function($$FileContentCacheTableAnnotationComposer a) f) {
    final $$FileContentCacheTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.path,
        referencedTable: $db.fileContentCache,
        getReferencedColumn: (t) => t.filePath,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FileContentCacheTableAnnotationComposer(
              $db: $db,
              $table: $db.fileContentCache,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$FileIndexTableTableManager extends RootTableManager<
    _$LocalBrain,
    $FileIndexTable,
    FileIndexData,
    $$FileIndexTableFilterComposer,
    $$FileIndexTableOrderingComposer,
    $$FileIndexTableAnnotationComposer,
    $$FileIndexTableCreateCompanionBuilder,
    $$FileIndexTableUpdateCompanionBuilder,
    (FileIndexData, $$FileIndexTableReferences),
    FileIndexData,
    PrefetchHooks Function({bool fileContentCacheRefs})> {
  $$FileIndexTableTableManager(_$LocalBrain db, $FileIndexTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FileIndexTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FileIndexTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FileIndexTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> path = const Value.absent(),
            Value<String> filename = const Value.absent(),
            Value<String?> extension = const Value.absent(),
            Value<int?> size = const Value.absent(),
            Value<DateTime?> modifiedAt = const Value.absent(),
            Value<String?> contentHash = const Value.absent(),
            Value<String?> mimeType = const Value.absent(),
            Value<bool> isDirectory = const Value.absent(),
            Value<String?> parentPath = const Value.absent(),
            Value<DateTime> indexedAt = const Value.absent(),
          }) =>
              FileIndexCompanion(
            id: id,
            path: path,
            filename: filename,
            extension: extension,
            size: size,
            modifiedAt: modifiedAt,
            contentHash: contentHash,
            mimeType: mimeType,
            isDirectory: isDirectory,
            parentPath: parentPath,
            indexedAt: indexedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String path,
            required String filename,
            Value<String?> extension = const Value.absent(),
            Value<int?> size = const Value.absent(),
            Value<DateTime?> modifiedAt = const Value.absent(),
            Value<String?> contentHash = const Value.absent(),
            Value<String?> mimeType = const Value.absent(),
            Value<bool> isDirectory = const Value.absent(),
            Value<String?> parentPath = const Value.absent(),
            Value<DateTime> indexedAt = const Value.absent(),
          }) =>
              FileIndexCompanion.insert(
            id: id,
            path: path,
            filename: filename,
            extension: extension,
            size: size,
            modifiedAt: modifiedAt,
            contentHash: contentHash,
            mimeType: mimeType,
            isDirectory: isDirectory,
            parentPath: parentPath,
            indexedAt: indexedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$FileIndexTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({fileContentCacheRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (fileContentCacheRefs) db.fileContentCache
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (fileContentCacheRefs)
                    await $_getPrefetchedData<FileIndexData, $FileIndexTable,
                            FileContentCacheData>(
                        currentTable: table,
                        referencedTable: $$FileIndexTableReferences
                            ._fileContentCacheRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$FileIndexTableReferences(db, table, p0)
                                .fileContentCacheRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.filePath == item.path),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$FileIndexTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $FileIndexTable,
    FileIndexData,
    $$FileIndexTableFilterComposer,
    $$FileIndexTableOrderingComposer,
    $$FileIndexTableAnnotationComposer,
    $$FileIndexTableCreateCompanionBuilder,
    $$FileIndexTableUpdateCompanionBuilder,
    (FileIndexData, $$FileIndexTableReferences),
    FileIndexData,
    PrefetchHooks Function({bool fileContentCacheRefs})>;
typedef $$FileContentCacheTableCreateCompanionBuilder
    = FileContentCacheCompanion Function({
  Value<int> id,
  required String filePath,
  required String content,
  Value<DateTime> cachedAt,
});
typedef $$FileContentCacheTableUpdateCompanionBuilder
    = FileContentCacheCompanion Function({
  Value<int> id,
  Value<String> filePath,
  Value<String> content,
  Value<DateTime> cachedAt,
});

final class $$FileContentCacheTableReferences extends BaseReferences<
    _$LocalBrain, $FileContentCacheTable, FileContentCacheData> {
  $$FileContentCacheTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $FileIndexTable _filePathTable(_$LocalBrain db) =>
      db.fileIndex.createAlias($_aliasNameGenerator(
          db.fileContentCache.filePath, db.fileIndex.path));

  $$FileIndexTableProcessedTableManager get filePath {
    final $_column = $_itemColumn<String>('file_path')!;

    final manager = $$FileIndexTableTableManager($_db, $_db.fileIndex)
        .filter((f) => f.path.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_filePathTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$FileContentCacheTableFilterComposer
    extends Composer<_$LocalBrain, $FileContentCacheTable> {
  $$FileContentCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));

  $$FileIndexTableFilterComposer get filePath {
    final $$FileIndexTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.filePath,
        referencedTable: $db.fileIndex,
        getReferencedColumn: (t) => t.path,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FileIndexTableFilterComposer(
              $db: $db,
              $table: $db.fileIndex,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FileContentCacheTableOrderingComposer
    extends Composer<_$LocalBrain, $FileContentCacheTable> {
  $$FileContentCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));

  $$FileIndexTableOrderingComposer get filePath {
    final $$FileIndexTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.filePath,
        referencedTable: $db.fileIndex,
        getReferencedColumn: (t) => t.path,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FileIndexTableOrderingComposer(
              $db: $db,
              $table: $db.fileIndex,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FileContentCacheTableAnnotationComposer
    extends Composer<_$LocalBrain, $FileContentCacheTable> {
  $$FileContentCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  $$FileIndexTableAnnotationComposer get filePath {
    final $$FileIndexTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.filePath,
        referencedTable: $db.fileIndex,
        getReferencedColumn: (t) => t.path,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FileIndexTableAnnotationComposer(
              $db: $db,
              $table: $db.fileIndex,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FileContentCacheTableTableManager extends RootTableManager<
    _$LocalBrain,
    $FileContentCacheTable,
    FileContentCacheData,
    $$FileContentCacheTableFilterComposer,
    $$FileContentCacheTableOrderingComposer,
    $$FileContentCacheTableAnnotationComposer,
    $$FileContentCacheTableCreateCompanionBuilder,
    $$FileContentCacheTableUpdateCompanionBuilder,
    (FileContentCacheData, $$FileContentCacheTableReferences),
    FileContentCacheData,
    PrefetchHooks Function({bool filePath})> {
  $$FileContentCacheTableTableManager(
      _$LocalBrain db, $FileContentCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FileContentCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FileContentCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FileContentCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
          }) =>
              FileContentCacheCompanion(
            id: id,
            filePath: filePath,
            content: content,
            cachedAt: cachedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String filePath,
            required String content,
            Value<DateTime> cachedAt = const Value.absent(),
          }) =>
              FileContentCacheCompanion.insert(
            id: id,
            filePath: filePath,
            content: content,
            cachedAt: cachedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$FileContentCacheTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({filePath = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (filePath) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.filePath,
                    referencedTable:
                        $$FileContentCacheTableReferences._filePathTable(db),
                    referencedColumn: $$FileContentCacheTableReferences
                        ._filePathTable(db)
                        .path,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$FileContentCacheTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $FileContentCacheTable,
    FileContentCacheData,
    $$FileContentCacheTableFilterComposer,
    $$FileContentCacheTableOrderingComposer,
    $$FileContentCacheTableAnnotationComposer,
    $$FileContentCacheTableCreateCompanionBuilder,
    $$FileContentCacheTableUpdateCompanionBuilder,
    (FileContentCacheData, $$FileContentCacheTableReferences),
    FileContentCacheData,
    PrefetchHooks Function({bool filePath})>;
typedef $$LlmProvidersTableCreateCompanionBuilder = LlmProvidersCompanion
    Function({
  required String id,
  required String name,
  required String type,
  required String url,
  Value<bool> isLocal,
  Value<bool> isDefault,
  Value<String?> version,
  Value<String?> config,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$LlmProvidersTableUpdateCompanionBuilder = LlmProvidersCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> type,
  Value<String> url,
  Value<bool> isLocal,
  Value<bool> isDefault,
  Value<String?> version,
  Value<String?> config,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LlmProvidersTableFilterComposer
    extends Composer<_$LocalBrain, $LlmProvidersTable> {
  $$LlmProvidersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get config => $composableBuilder(
      column: $table.config, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LlmProvidersTableOrderingComposer
    extends Composer<_$LocalBrain, $LlmProvidersTable> {
  $$LlmProvidersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get config => $composableBuilder(
      column: $table.config, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LlmProvidersTableAnnotationComposer
    extends Composer<_$LocalBrain, $LlmProvidersTable> {
  $$LlmProvidersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<bool> get isLocal =>
      $composableBuilder(column: $table.isLocal, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get config =>
      $composableBuilder(column: $table.config, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LlmProvidersTableTableManager extends RootTableManager<
    _$LocalBrain,
    $LlmProvidersTable,
    LlmProvider,
    $$LlmProvidersTableFilterComposer,
    $$LlmProvidersTableOrderingComposer,
    $$LlmProvidersTableAnnotationComposer,
    $$LlmProvidersTableCreateCompanionBuilder,
    $$LlmProvidersTableUpdateCompanionBuilder,
    (
      LlmProvider,
      BaseReferences<_$LocalBrain, $LlmProvidersTable, LlmProvider>
    ),
    LlmProvider,
    PrefetchHooks Function()> {
  $$LlmProvidersTableTableManager(_$LocalBrain db, $LlmProvidersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LlmProvidersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LlmProvidersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LlmProvidersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> url = const Value.absent(),
            Value<bool> isLocal = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<String?> version = const Value.absent(),
            Value<String?> config = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LlmProvidersCompanion(
            id: id,
            name: name,
            type: type,
            url: url,
            isLocal: isLocal,
            isDefault: isDefault,
            version: version,
            config: config,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String type,
            required String url,
            Value<bool> isLocal = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<String?> version = const Value.absent(),
            Value<String?> config = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LlmProvidersCompanion.insert(
            id: id,
            name: name,
            type: type,
            url: url,
            isLocal: isLocal,
            isDefault: isDefault,
            version: version,
            config: config,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LlmProvidersTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $LlmProvidersTable,
    LlmProvider,
    $$LlmProvidersTableFilterComposer,
    $$LlmProvidersTableOrderingComposer,
    $$LlmProvidersTableAnnotationComposer,
    $$LlmProvidersTableCreateCompanionBuilder,
    $$LlmProvidersTableUpdateCompanionBuilder,
    (
      LlmProvider,
      BaseReferences<_$LocalBrain, $LlmProvidersTable, LlmProvider>
    ),
    LlmProvider,
    PrefetchHooks Function()>;
typedef $$ModelCapacityTableCreateCompanionBuilder = ModelCapacityCompanion
    Function({
  required String modelId,
  required String provider,
  Value<String?> displayName,
  Value<int> concurrentUsed,
  required int concurrentLimit,
  Value<int> tpmUsed,
  Value<int?> tpmLimit,
  Value<int> rpmUsed,
  Value<int?> rpmLimit,
  Value<DateTime> lastUpdated,
  Value<String> status,
  Value<int> rowid,
});
typedef $$ModelCapacityTableUpdateCompanionBuilder = ModelCapacityCompanion
    Function({
  Value<String> modelId,
  Value<String> provider,
  Value<String?> displayName,
  Value<int> concurrentUsed,
  Value<int> concurrentLimit,
  Value<int> tpmUsed,
  Value<int?> tpmLimit,
  Value<int> rpmUsed,
  Value<int?> rpmLimit,
  Value<DateTime> lastUpdated,
  Value<String> status,
  Value<int> rowid,
});

final class $$ModelCapacityTableReferences extends BaseReferences<_$LocalBrain,
    $ModelCapacityTable, ModelCapacityData> {
  $$ModelCapacityTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LlmRequestsTable, List<LlmRequest>>
      _llmRequestsRefsTable(_$LocalBrain db) =>
          MultiTypedResultKey.fromTable(db.llmRequests,
              aliasName: $_aliasNameGenerator(
                  db.modelCapacity.modelId, db.llmRequests.modelId));

  $$LlmRequestsTableProcessedTableManager get llmRequestsRefs {
    final manager = $$LlmRequestsTableTableManager($_db, $_db.llmRequests)
        .filter((f) =>
            f.modelId.modelId.sqlEquals($_itemColumn<String>('model_id')!));

    final cache = $_typedResult.readTableOrNull(_llmRequestsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ModelCapacityTableFilterComposer
    extends Composer<_$LocalBrain, $ModelCapacityTable> {
  $$ModelCapacityTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get modelId => $composableBuilder(
      column: $table.modelId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get concurrentUsed => $composableBuilder(
      column: $table.concurrentUsed,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get concurrentLimit => $composableBuilder(
      column: $table.concurrentLimit,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tpmUsed => $composableBuilder(
      column: $table.tpmUsed, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tpmLimit => $composableBuilder(
      column: $table.tpmLimit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rpmUsed => $composableBuilder(
      column: $table.rpmUsed, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rpmLimit => $composableBuilder(
      column: $table.rpmLimit, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  Expression<bool> llmRequestsRefs(
      Expression<bool> Function($$LlmRequestsTableFilterComposer f) f) {
    final $$LlmRequestsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.modelId,
        referencedTable: $db.llmRequests,
        getReferencedColumn: (t) => t.modelId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LlmRequestsTableFilterComposer(
              $db: $db,
              $table: $db.llmRequests,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ModelCapacityTableOrderingComposer
    extends Composer<_$LocalBrain, $ModelCapacityTable> {
  $$ModelCapacityTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get modelId => $composableBuilder(
      column: $table.modelId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get concurrentUsed => $composableBuilder(
      column: $table.concurrentUsed,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get concurrentLimit => $composableBuilder(
      column: $table.concurrentLimit,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tpmUsed => $composableBuilder(
      column: $table.tpmUsed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tpmLimit => $composableBuilder(
      column: $table.tpmLimit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rpmUsed => $composableBuilder(
      column: $table.rpmUsed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rpmLimit => $composableBuilder(
      column: $table.rpmLimit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));
}

class $$ModelCapacityTableAnnotationComposer
    extends Composer<_$LocalBrain, $ModelCapacityTable> {
  $$ModelCapacityTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<int> get concurrentUsed => $composableBuilder(
      column: $table.concurrentUsed, builder: (column) => column);

  GeneratedColumn<int> get concurrentLimit => $composableBuilder(
      column: $table.concurrentLimit, builder: (column) => column);

  GeneratedColumn<int> get tpmUsed =>
      $composableBuilder(column: $table.tpmUsed, builder: (column) => column);

  GeneratedColumn<int> get tpmLimit =>
      $composableBuilder(column: $table.tpmLimit, builder: (column) => column);

  GeneratedColumn<int> get rpmUsed =>
      $composableBuilder(column: $table.rpmUsed, builder: (column) => column);

  GeneratedColumn<int> get rpmLimit =>
      $composableBuilder(column: $table.rpmLimit, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  Expression<T> llmRequestsRefs<T extends Object>(
      Expression<T> Function($$LlmRequestsTableAnnotationComposer a) f) {
    final $$LlmRequestsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.modelId,
        referencedTable: $db.llmRequests,
        getReferencedColumn: (t) => t.modelId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LlmRequestsTableAnnotationComposer(
              $db: $db,
              $table: $db.llmRequests,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ModelCapacityTableTableManager extends RootTableManager<
    _$LocalBrain,
    $ModelCapacityTable,
    ModelCapacityData,
    $$ModelCapacityTableFilterComposer,
    $$ModelCapacityTableOrderingComposer,
    $$ModelCapacityTableAnnotationComposer,
    $$ModelCapacityTableCreateCompanionBuilder,
    $$ModelCapacityTableUpdateCompanionBuilder,
    (ModelCapacityData, $$ModelCapacityTableReferences),
    ModelCapacityData,
    PrefetchHooks Function({bool llmRequestsRefs})> {
  $$ModelCapacityTableTableManager(_$LocalBrain db, $ModelCapacityTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelCapacityTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelCapacityTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelCapacityTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> modelId = const Value.absent(),
            Value<String> provider = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<int> concurrentUsed = const Value.absent(),
            Value<int> concurrentLimit = const Value.absent(),
            Value<int> tpmUsed = const Value.absent(),
            Value<int?> tpmLimit = const Value.absent(),
            Value<int> rpmUsed = const Value.absent(),
            Value<int?> rpmLimit = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ModelCapacityCompanion(
            modelId: modelId,
            provider: provider,
            displayName: displayName,
            concurrentUsed: concurrentUsed,
            concurrentLimit: concurrentLimit,
            tpmUsed: tpmUsed,
            tpmLimit: tpmLimit,
            rpmUsed: rpmUsed,
            rpmLimit: rpmLimit,
            lastUpdated: lastUpdated,
            status: status,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String modelId,
            required String provider,
            Value<String?> displayName = const Value.absent(),
            Value<int> concurrentUsed = const Value.absent(),
            required int concurrentLimit,
            Value<int> tpmUsed = const Value.absent(),
            Value<int?> tpmLimit = const Value.absent(),
            Value<int> rpmUsed = const Value.absent(),
            Value<int?> rpmLimit = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ModelCapacityCompanion.insert(
            modelId: modelId,
            provider: provider,
            displayName: displayName,
            concurrentUsed: concurrentUsed,
            concurrentLimit: concurrentLimit,
            tpmUsed: tpmUsed,
            tpmLimit: tpmLimit,
            rpmUsed: rpmUsed,
            rpmLimit: rpmLimit,
            lastUpdated: lastUpdated,
            status: status,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ModelCapacityTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({llmRequestsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (llmRequestsRefs) db.llmRequests],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (llmRequestsRefs)
                    await $_getPrefetchedData<ModelCapacityData,
                            $ModelCapacityTable, LlmRequest>(
                        currentTable: table,
                        referencedTable: $$ModelCapacityTableReferences
                            ._llmRequestsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ModelCapacityTableReferences(db, table, p0)
                                .llmRequestsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.modelId == item.modelId),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ModelCapacityTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $ModelCapacityTable,
    ModelCapacityData,
    $$ModelCapacityTableFilterComposer,
    $$ModelCapacityTableOrderingComposer,
    $$ModelCapacityTableAnnotationComposer,
    $$ModelCapacityTableCreateCompanionBuilder,
    $$ModelCapacityTableUpdateCompanionBuilder,
    (ModelCapacityData, $$ModelCapacityTableReferences),
    ModelCapacityData,
    PrefetchHooks Function({bool llmRequestsRefs})>;
typedef $$LlmRequestsTableCreateCompanionBuilder = LlmRequestsCompanion
    Function({
  Value<int> id,
  required String requestId,
  required String modelId,
  Value<String> status,
  Value<int?> promptTokens,
  Value<int?> completionTokens,
  Value<DateTime> startedAt,
  Value<DateTime?> completedAt,
  Value<String?> errorMessage,
});
typedef $$LlmRequestsTableUpdateCompanionBuilder = LlmRequestsCompanion
    Function({
  Value<int> id,
  Value<String> requestId,
  Value<String> modelId,
  Value<String> status,
  Value<int?> promptTokens,
  Value<int?> completionTokens,
  Value<DateTime> startedAt,
  Value<DateTime?> completedAt,
  Value<String?> errorMessage,
});

final class $$LlmRequestsTableReferences
    extends BaseReferences<_$LocalBrain, $LlmRequestsTable, LlmRequest> {
  $$LlmRequestsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ModelCapacityTable _modelIdTable(_$LocalBrain db) =>
      db.modelCapacity.createAlias($_aliasNameGenerator(
          db.llmRequests.modelId, db.modelCapacity.modelId));

  $$ModelCapacityTableProcessedTableManager get modelId {
    final $_column = $_itemColumn<String>('model_id')!;

    final manager = $$ModelCapacityTableTableManager($_db, $_db.modelCapacity)
        .filter((f) => f.modelId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_modelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$LlmRequestsTableFilterComposer
    extends Composer<_$LocalBrain, $LlmRequestsTable> {
  $$LlmRequestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get requestId => $composableBuilder(
      column: $table.requestId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get promptTokens => $composableBuilder(
      column: $table.promptTokens, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get completionTokens => $composableBuilder(
      column: $table.completionTokens,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));

  $$ModelCapacityTableFilterComposer get modelId {
    final $$ModelCapacityTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.modelId,
        referencedTable: $db.modelCapacity,
        getReferencedColumn: (t) => t.modelId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ModelCapacityTableFilterComposer(
              $db: $db,
              $table: $db.modelCapacity,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LlmRequestsTableOrderingComposer
    extends Composer<_$LocalBrain, $LlmRequestsTable> {
  $$LlmRequestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get requestId => $composableBuilder(
      column: $table.requestId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get promptTokens => $composableBuilder(
      column: $table.promptTokens,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get completionTokens => $composableBuilder(
      column: $table.completionTokens,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));

  $$ModelCapacityTableOrderingComposer get modelId {
    final $$ModelCapacityTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.modelId,
        referencedTable: $db.modelCapacity,
        getReferencedColumn: (t) => t.modelId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ModelCapacityTableOrderingComposer(
              $db: $db,
              $table: $db.modelCapacity,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LlmRequestsTableAnnotationComposer
    extends Composer<_$LocalBrain, $LlmRequestsTable> {
  $$LlmRequestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get promptTokens => $composableBuilder(
      column: $table.promptTokens, builder: (column) => column);

  GeneratedColumn<int> get completionTokens => $composableBuilder(
      column: $table.completionTokens, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);

  $$ModelCapacityTableAnnotationComposer get modelId {
    final $$ModelCapacityTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.modelId,
        referencedTable: $db.modelCapacity,
        getReferencedColumn: (t) => t.modelId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ModelCapacityTableAnnotationComposer(
              $db: $db,
              $table: $db.modelCapacity,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LlmRequestsTableTableManager extends RootTableManager<
    _$LocalBrain,
    $LlmRequestsTable,
    LlmRequest,
    $$LlmRequestsTableFilterComposer,
    $$LlmRequestsTableOrderingComposer,
    $$LlmRequestsTableAnnotationComposer,
    $$LlmRequestsTableCreateCompanionBuilder,
    $$LlmRequestsTableUpdateCompanionBuilder,
    (LlmRequest, $$LlmRequestsTableReferences),
    LlmRequest,
    PrefetchHooks Function({bool modelId})> {
  $$LlmRequestsTableTableManager(_$LocalBrain db, $LlmRequestsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LlmRequestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LlmRequestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LlmRequestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> requestId = const Value.absent(),
            Value<String> modelId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int?> promptTokens = const Value.absent(),
            Value<int?> completionTokens = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
          }) =>
              LlmRequestsCompanion(
            id: id,
            requestId: requestId,
            modelId: modelId,
            status: status,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            startedAt: startedAt,
            completedAt: completedAt,
            errorMessage: errorMessage,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String requestId,
            required String modelId,
            Value<String> status = const Value.absent(),
            Value<int?> promptTokens = const Value.absent(),
            Value<int?> completionTokens = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
          }) =>
              LlmRequestsCompanion.insert(
            id: id,
            requestId: requestId,
            modelId: modelId,
            status: status,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            startedAt: startedAt,
            completedAt: completedAt,
            errorMessage: errorMessage,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$LlmRequestsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({modelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (modelId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.modelId,
                    referencedTable:
                        $$LlmRequestsTableReferences._modelIdTable(db),
                    referencedColumn:
                        $$LlmRequestsTableReferences._modelIdTable(db).modelId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$LlmRequestsTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $LlmRequestsTable,
    LlmRequest,
    $$LlmRequestsTableFilterComposer,
    $$LlmRequestsTableOrderingComposer,
    $$LlmRequestsTableAnnotationComposer,
    $$LlmRequestsTableCreateCompanionBuilder,
    $$LlmRequestsTableUpdateCompanionBuilder,
    (LlmRequest, $$LlmRequestsTableReferences),
    LlmRequest,
    PrefetchHooks Function({bool modelId})>;
typedef $$AvatarProfilesTableCreateCompanionBuilder = AvatarProfilesCompanion
    Function({
  required String id,
  required String name,
  Value<String?> personalityType,
  Value<int> level,
  Value<int> xp,
  Value<int> xpToNextLevel,
  Value<String?> traits,
  Value<String?> avatarConfig,
  Value<DateTime?> lastInteraction,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$AvatarProfilesTableUpdateCompanionBuilder = AvatarProfilesCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String?> personalityType,
  Value<int> level,
  Value<int> xp,
  Value<int> xpToNextLevel,
  Value<String?> traits,
  Value<String?> avatarConfig,
  Value<DateTime?> lastInteraction,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$AvatarProfilesTableReferences
    extends BaseReferences<_$LocalBrain, $AvatarProfilesTable, AvatarProfile> {
  $$AvatarProfilesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AchievementsTable, List<Achievement>>
      _achievementsRefsTable(_$LocalBrain db) =>
          MultiTypedResultKey.fromTable(db.achievements,
              aliasName: $_aliasNameGenerator(
                  db.avatarProfiles.id, db.achievements.avatarId));

  $$AchievementsTableProcessedTableManager get achievementsRefs {
    final manager = $$AchievementsTableTableManager($_db, $_db.achievements)
        .filter((f) => f.avatarId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_achievementsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$AvatarMemoryEntriesTable, List<AvatarMemoryEntry>>
      _avatarMemoryEntriesRefsTable(_$LocalBrain db) =>
          MultiTypedResultKey.fromTable(db.avatarMemoryEntries,
              aliasName: $_aliasNameGenerator(
                  db.avatarProfiles.id, db.avatarMemoryEntries.avatarId));

  $$AvatarMemoryEntriesTableProcessedTableManager get avatarMemoryEntriesRefs {
    final manager = $$AvatarMemoryEntriesTableTableManager(
            $_db, $_db.avatarMemoryEntries)
        .filter((f) => f.avatarId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_avatarMemoryEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$AvatarProfilesTableFilterComposer
    extends Composer<_$LocalBrain, $AvatarProfilesTable> {
  $$AvatarProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get personalityType => $composableBuilder(
      column: $table.personalityType,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get xp => $composableBuilder(
      column: $table.xp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get xpToNextLevel => $composableBuilder(
      column: $table.xpToNextLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get traits => $composableBuilder(
      column: $table.traits, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarConfig => $composableBuilder(
      column: $table.avatarConfig, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastInteraction => $composableBuilder(
      column: $table.lastInteraction,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> achievementsRefs(
      Expression<bool> Function($$AchievementsTableFilterComposer f) f) {
    final $$AchievementsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.achievements,
        getReferencedColumn: (t) => t.avatarId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AchievementsTableFilterComposer(
              $db: $db,
              $table: $db.achievements,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> avatarMemoryEntriesRefs(
      Expression<bool> Function($$AvatarMemoryEntriesTableFilterComposer f) f) {
    final $$AvatarMemoryEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.avatarMemoryEntries,
        getReferencedColumn: (t) => t.avatarId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AvatarMemoryEntriesTableFilterComposer(
              $db: $db,
              $table: $db.avatarMemoryEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AvatarProfilesTableOrderingComposer
    extends Composer<_$LocalBrain, $AvatarProfilesTable> {
  $$AvatarProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get personalityType => $composableBuilder(
      column: $table.personalityType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get xp => $composableBuilder(
      column: $table.xp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get xpToNextLevel => $composableBuilder(
      column: $table.xpToNextLevel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get traits => $composableBuilder(
      column: $table.traits, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarConfig => $composableBuilder(
      column: $table.avatarConfig,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastInteraction => $composableBuilder(
      column: $table.lastInteraction,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AvatarProfilesTableAnnotationComposer
    extends Composer<_$LocalBrain, $AvatarProfilesTable> {
  $$AvatarProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get personalityType => $composableBuilder(
      column: $table.personalityType, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get xp =>
      $composableBuilder(column: $table.xp, builder: (column) => column);

  GeneratedColumn<int> get xpToNextLevel => $composableBuilder(
      column: $table.xpToNextLevel, builder: (column) => column);

  GeneratedColumn<String> get traits =>
      $composableBuilder(column: $table.traits, builder: (column) => column);

  GeneratedColumn<String> get avatarConfig => $composableBuilder(
      column: $table.avatarConfig, builder: (column) => column);

  GeneratedColumn<DateTime> get lastInteraction => $composableBuilder(
      column: $table.lastInteraction, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> achievementsRefs<T extends Object>(
      Expression<T> Function($$AchievementsTableAnnotationComposer a) f) {
    final $$AchievementsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.achievements,
        getReferencedColumn: (t) => t.avatarId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AchievementsTableAnnotationComposer(
              $db: $db,
              $table: $db.achievements,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> avatarMemoryEntriesRefs<T extends Object>(
      Expression<T> Function($$AvatarMemoryEntriesTableAnnotationComposer a)
          f) {
    final $$AvatarMemoryEntriesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.avatarMemoryEntries,
            getReferencedColumn: (t) => t.avatarId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$AvatarMemoryEntriesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.avatarMemoryEntries,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$AvatarProfilesTableTableManager extends RootTableManager<
    _$LocalBrain,
    $AvatarProfilesTable,
    AvatarProfile,
    $$AvatarProfilesTableFilterComposer,
    $$AvatarProfilesTableOrderingComposer,
    $$AvatarProfilesTableAnnotationComposer,
    $$AvatarProfilesTableCreateCompanionBuilder,
    $$AvatarProfilesTableUpdateCompanionBuilder,
    (AvatarProfile, $$AvatarProfilesTableReferences),
    AvatarProfile,
    PrefetchHooks Function(
        {bool achievementsRefs, bool avatarMemoryEntriesRefs})> {
  $$AvatarProfilesTableTableManager(_$LocalBrain db, $AvatarProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AvatarProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AvatarProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AvatarProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> personalityType = const Value.absent(),
            Value<int> level = const Value.absent(),
            Value<int> xp = const Value.absent(),
            Value<int> xpToNextLevel = const Value.absent(),
            Value<String?> traits = const Value.absent(),
            Value<String?> avatarConfig = const Value.absent(),
            Value<DateTime?> lastInteraction = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AvatarProfilesCompanion(
            id: id,
            name: name,
            personalityType: personalityType,
            level: level,
            xp: xp,
            xpToNextLevel: xpToNextLevel,
            traits: traits,
            avatarConfig: avatarConfig,
            lastInteraction: lastInteraction,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> personalityType = const Value.absent(),
            Value<int> level = const Value.absent(),
            Value<int> xp = const Value.absent(),
            Value<int> xpToNextLevel = const Value.absent(),
            Value<String?> traits = const Value.absent(),
            Value<String?> avatarConfig = const Value.absent(),
            Value<DateTime?> lastInteraction = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AvatarProfilesCompanion.insert(
            id: id,
            name: name,
            personalityType: personalityType,
            level: level,
            xp: xp,
            xpToNextLevel: xpToNextLevel,
            traits: traits,
            avatarConfig: avatarConfig,
            lastInteraction: lastInteraction,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AvatarProfilesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {achievementsRefs = false, avatarMemoryEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (achievementsRefs) db.achievements,
                if (avatarMemoryEntriesRefs) db.avatarMemoryEntries
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (achievementsRefs)
                    await $_getPrefetchedData<AvatarProfile,
                            $AvatarProfilesTable, Achievement>(
                        currentTable: table,
                        referencedTable: $$AvatarProfilesTableReferences
                            ._achievementsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$AvatarProfilesTableReferences(db, table, p0)
                                .achievementsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.avatarId == item.id),
                        typedResults: items),
                  if (avatarMemoryEntriesRefs)
                    await $_getPrefetchedData<AvatarProfile,
                            $AvatarProfilesTable, AvatarMemoryEntry>(
                        currentTable: table,
                        referencedTable: $$AvatarProfilesTableReferences
                            ._avatarMemoryEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$AvatarProfilesTableReferences(db, table, p0)
                                .avatarMemoryEntriesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.avatarId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$AvatarProfilesTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $AvatarProfilesTable,
    AvatarProfile,
    $$AvatarProfilesTableFilterComposer,
    $$AvatarProfilesTableOrderingComposer,
    $$AvatarProfilesTableAnnotationComposer,
    $$AvatarProfilesTableCreateCompanionBuilder,
    $$AvatarProfilesTableUpdateCompanionBuilder,
    (AvatarProfile, $$AvatarProfilesTableReferences),
    AvatarProfile,
    PrefetchHooks Function(
        {bool achievementsRefs, bool avatarMemoryEntriesRefs})>;
typedef $$AchievementsTableCreateCompanionBuilder = AchievementsCompanion
    Function({
  Value<int> id,
  required String avatarId,
  required String achievementId,
  required String achievementType,
  required String title,
  Value<String?> description,
  Value<DateTime?> unlockedAt,
  Value<DateTime> earnedAt,
});
typedef $$AchievementsTableUpdateCompanionBuilder = AchievementsCompanion
    Function({
  Value<int> id,
  Value<String> avatarId,
  Value<String> achievementId,
  Value<String> achievementType,
  Value<String> title,
  Value<String?> description,
  Value<DateTime?> unlockedAt,
  Value<DateTime> earnedAt,
});

final class $$AchievementsTableReferences
    extends BaseReferences<_$LocalBrain, $AchievementsTable, Achievement> {
  $$AchievementsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AvatarProfilesTable _avatarIdTable(_$LocalBrain db) =>
      db.avatarProfiles.createAlias(
          $_aliasNameGenerator(db.achievements.avatarId, db.avatarProfiles.id));

  $$AvatarProfilesTableProcessedTableManager get avatarId {
    final $_column = $_itemColumn<String>('avatar_id')!;

    final manager = $$AvatarProfilesTableTableManager($_db, $_db.avatarProfiles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_avatarIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AchievementsTableFilterComposer
    extends Composer<_$LocalBrain, $AchievementsTable> {
  $$AchievementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get achievementId => $composableBuilder(
      column: $table.achievementId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get achievementType => $composableBuilder(
      column: $table.achievementType,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get unlockedAt => $composableBuilder(
      column: $table.unlockedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get earnedAt => $composableBuilder(
      column: $table.earnedAt, builder: (column) => ColumnFilters(column));

  $$AvatarProfilesTableFilterComposer get avatarId {
    final $$AvatarProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.avatarId,
        referencedTable: $db.avatarProfiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AvatarProfilesTableFilterComposer(
              $db: $db,
              $table: $db.avatarProfiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AchievementsTableOrderingComposer
    extends Composer<_$LocalBrain, $AchievementsTable> {
  $$AchievementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get achievementId => $composableBuilder(
      column: $table.achievementId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get achievementType => $composableBuilder(
      column: $table.achievementType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get unlockedAt => $composableBuilder(
      column: $table.unlockedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get earnedAt => $composableBuilder(
      column: $table.earnedAt, builder: (column) => ColumnOrderings(column));

  $$AvatarProfilesTableOrderingComposer get avatarId {
    final $$AvatarProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.avatarId,
        referencedTable: $db.avatarProfiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AvatarProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.avatarProfiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AchievementsTableAnnotationComposer
    extends Composer<_$LocalBrain, $AchievementsTable> {
  $$AchievementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get achievementId => $composableBuilder(
      column: $table.achievementId, builder: (column) => column);

  GeneratedColumn<String> get achievementType => $composableBuilder(
      column: $table.achievementType, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get unlockedAt => $composableBuilder(
      column: $table.unlockedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get earnedAt =>
      $composableBuilder(column: $table.earnedAt, builder: (column) => column);

  $$AvatarProfilesTableAnnotationComposer get avatarId {
    final $$AvatarProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.avatarId,
        referencedTable: $db.avatarProfiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AvatarProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.avatarProfiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AchievementsTableTableManager extends RootTableManager<
    _$LocalBrain,
    $AchievementsTable,
    Achievement,
    $$AchievementsTableFilterComposer,
    $$AchievementsTableOrderingComposer,
    $$AchievementsTableAnnotationComposer,
    $$AchievementsTableCreateCompanionBuilder,
    $$AchievementsTableUpdateCompanionBuilder,
    (Achievement, $$AchievementsTableReferences),
    Achievement,
    PrefetchHooks Function({bool avatarId})> {
  $$AchievementsTableTableManager(_$LocalBrain db, $AchievementsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AchievementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AchievementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AchievementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> avatarId = const Value.absent(),
            Value<String> achievementId = const Value.absent(),
            Value<String> achievementType = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<DateTime?> unlockedAt = const Value.absent(),
            Value<DateTime> earnedAt = const Value.absent(),
          }) =>
              AchievementsCompanion(
            id: id,
            avatarId: avatarId,
            achievementId: achievementId,
            achievementType: achievementType,
            title: title,
            description: description,
            unlockedAt: unlockedAt,
            earnedAt: earnedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String avatarId,
            required String achievementId,
            required String achievementType,
            required String title,
            Value<String?> description = const Value.absent(),
            Value<DateTime?> unlockedAt = const Value.absent(),
            Value<DateTime> earnedAt = const Value.absent(),
          }) =>
              AchievementsCompanion.insert(
            id: id,
            avatarId: avatarId,
            achievementId: achievementId,
            achievementType: achievementType,
            title: title,
            description: description,
            unlockedAt: unlockedAt,
            earnedAt: earnedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AchievementsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({avatarId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (avatarId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.avatarId,
                    referencedTable:
                        $$AchievementsTableReferences._avatarIdTable(db),
                    referencedColumn:
                        $$AchievementsTableReferences._avatarIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$AchievementsTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $AchievementsTable,
    Achievement,
    $$AchievementsTableFilterComposer,
    $$AchievementsTableOrderingComposer,
    $$AchievementsTableAnnotationComposer,
    $$AchievementsTableCreateCompanionBuilder,
    $$AchievementsTableUpdateCompanionBuilder,
    (Achievement, $$AchievementsTableReferences),
    Achievement,
    PrefetchHooks Function({bool avatarId})>;
typedef $$AvatarMemoryEntriesTableCreateCompanionBuilder
    = AvatarMemoryEntriesCompanion Function({
  Value<int> id,
  required String avatarId,
  required String memoryType,
  required String memoryKey,
  required String memoryValue,
  Value<String?> tags,
  Value<int> importance,
  Value<DateTime> timestamp,
  Value<DateTime> createdAt,
  Value<DateTime> lastAccessed,
});
typedef $$AvatarMemoryEntriesTableUpdateCompanionBuilder
    = AvatarMemoryEntriesCompanion Function({
  Value<int> id,
  Value<String> avatarId,
  Value<String> memoryType,
  Value<String> memoryKey,
  Value<String> memoryValue,
  Value<String?> tags,
  Value<int> importance,
  Value<DateTime> timestamp,
  Value<DateTime> createdAt,
  Value<DateTime> lastAccessed,
});

final class $$AvatarMemoryEntriesTableReferences extends BaseReferences<
    _$LocalBrain, $AvatarMemoryEntriesTable, AvatarMemoryEntry> {
  $$AvatarMemoryEntriesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $AvatarProfilesTable _avatarIdTable(_$LocalBrain db) =>
      db.avatarProfiles.createAlias($_aliasNameGenerator(
          db.avatarMemoryEntries.avatarId, db.avatarProfiles.id));

  $$AvatarProfilesTableProcessedTableManager get avatarId {
    final $_column = $_itemColumn<String>('avatar_id')!;

    final manager = $$AvatarProfilesTableTableManager($_db, $_db.avatarProfiles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_avatarIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AvatarMemoryEntriesTableFilterComposer
    extends Composer<_$LocalBrain, $AvatarMemoryEntriesTable> {
  $$AvatarMemoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memoryType => $composableBuilder(
      column: $table.memoryType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memoryKey => $composableBuilder(
      column: $table.memoryKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memoryValue => $composableBuilder(
      column: $table.memoryValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get importance => $composableBuilder(
      column: $table.importance, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAccessed => $composableBuilder(
      column: $table.lastAccessed, builder: (column) => ColumnFilters(column));

  $$AvatarProfilesTableFilterComposer get avatarId {
    final $$AvatarProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.avatarId,
        referencedTable: $db.avatarProfiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AvatarProfilesTableFilterComposer(
              $db: $db,
              $table: $db.avatarProfiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AvatarMemoryEntriesTableOrderingComposer
    extends Composer<_$LocalBrain, $AvatarMemoryEntriesTable> {
  $$AvatarMemoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memoryType => $composableBuilder(
      column: $table.memoryType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memoryKey => $composableBuilder(
      column: $table.memoryKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memoryValue => $composableBuilder(
      column: $table.memoryValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get importance => $composableBuilder(
      column: $table.importance, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAccessed => $composableBuilder(
      column: $table.lastAccessed,
      builder: (column) => ColumnOrderings(column));

  $$AvatarProfilesTableOrderingComposer get avatarId {
    final $$AvatarProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.avatarId,
        referencedTable: $db.avatarProfiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AvatarProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.avatarProfiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AvatarMemoryEntriesTableAnnotationComposer
    extends Composer<_$LocalBrain, $AvatarMemoryEntriesTable> {
  $$AvatarMemoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get memoryType => $composableBuilder(
      column: $table.memoryType, builder: (column) => column);

  GeneratedColumn<String> get memoryKey =>
      $composableBuilder(column: $table.memoryKey, builder: (column) => column);

  GeneratedColumn<String> get memoryValue => $composableBuilder(
      column: $table.memoryValue, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<int> get importance => $composableBuilder(
      column: $table.importance, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAccessed => $composableBuilder(
      column: $table.lastAccessed, builder: (column) => column);

  $$AvatarProfilesTableAnnotationComposer get avatarId {
    final $$AvatarProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.avatarId,
        referencedTable: $db.avatarProfiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AvatarProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.avatarProfiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AvatarMemoryEntriesTableTableManager extends RootTableManager<
    _$LocalBrain,
    $AvatarMemoryEntriesTable,
    AvatarMemoryEntry,
    $$AvatarMemoryEntriesTableFilterComposer,
    $$AvatarMemoryEntriesTableOrderingComposer,
    $$AvatarMemoryEntriesTableAnnotationComposer,
    $$AvatarMemoryEntriesTableCreateCompanionBuilder,
    $$AvatarMemoryEntriesTableUpdateCompanionBuilder,
    (AvatarMemoryEntry, $$AvatarMemoryEntriesTableReferences),
    AvatarMemoryEntry,
    PrefetchHooks Function({bool avatarId})> {
  $$AvatarMemoryEntriesTableTableManager(
      _$LocalBrain db, $AvatarMemoryEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AvatarMemoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AvatarMemoryEntriesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AvatarMemoryEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> avatarId = const Value.absent(),
            Value<String> memoryType = const Value.absent(),
            Value<String> memoryKey = const Value.absent(),
            Value<String> memoryValue = const Value.absent(),
            Value<String?> tags = const Value.absent(),
            Value<int> importance = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> lastAccessed = const Value.absent(),
          }) =>
              AvatarMemoryEntriesCompanion(
            id: id,
            avatarId: avatarId,
            memoryType: memoryType,
            memoryKey: memoryKey,
            memoryValue: memoryValue,
            tags: tags,
            importance: importance,
            timestamp: timestamp,
            createdAt: createdAt,
            lastAccessed: lastAccessed,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String avatarId,
            required String memoryType,
            required String memoryKey,
            required String memoryValue,
            Value<String?> tags = const Value.absent(),
            Value<int> importance = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> lastAccessed = const Value.absent(),
          }) =>
              AvatarMemoryEntriesCompanion.insert(
            id: id,
            avatarId: avatarId,
            memoryType: memoryType,
            memoryKey: memoryKey,
            memoryValue: memoryValue,
            tags: tags,
            importance: importance,
            timestamp: timestamp,
            createdAt: createdAt,
            lastAccessed: lastAccessed,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AvatarMemoryEntriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({avatarId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (avatarId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.avatarId,
                    referencedTable:
                        $$AvatarMemoryEntriesTableReferences._avatarIdTable(db),
                    referencedColumn: $$AvatarMemoryEntriesTableReferences
                        ._avatarIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$AvatarMemoryEntriesTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $AvatarMemoryEntriesTable,
    AvatarMemoryEntry,
    $$AvatarMemoryEntriesTableFilterComposer,
    $$AvatarMemoryEntriesTableOrderingComposer,
    $$AvatarMemoryEntriesTableAnnotationComposer,
    $$AvatarMemoryEntriesTableCreateCompanionBuilder,
    $$AvatarMemoryEntriesTableUpdateCompanionBuilder,
    (AvatarMemoryEntry, $$AvatarMemoryEntriesTableReferences),
    AvatarMemoryEntry,
    PrefetchHooks Function({bool avatarId})>;
typedef $$ClipboardHistoryTableCreateCompanionBuilder
    = ClipboardHistoryCompanion Function({
  Value<int> id,
  required String content,
  required String contentType,
  Value<String?> sourceApp,
  Value<DateTime> timestamp,
  Value<DateTime> copiedAt,
  Value<bool> isPinned,
});
typedef $$ClipboardHistoryTableUpdateCompanionBuilder
    = ClipboardHistoryCompanion Function({
  Value<int> id,
  Value<String> content,
  Value<String> contentType,
  Value<String?> sourceApp,
  Value<DateTime> timestamp,
  Value<DateTime> copiedAt,
  Value<bool> isPinned,
});

class $$ClipboardHistoryTableFilterComposer
    extends Composer<_$LocalBrain, $ClipboardHistoryTable> {
  $$ClipboardHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceApp => $composableBuilder(
      column: $table.sourceApp, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get copiedAt => $composableBuilder(
      column: $table.copiedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnFilters(column));
}

class $$ClipboardHistoryTableOrderingComposer
    extends Composer<_$LocalBrain, $ClipboardHistoryTable> {
  $$ClipboardHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceApp => $composableBuilder(
      column: $table.sourceApp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get copiedAt => $composableBuilder(
      column: $table.copiedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnOrderings(column));
}

class $$ClipboardHistoryTableAnnotationComposer
    extends Composer<_$LocalBrain, $ClipboardHistoryTable> {
  $$ClipboardHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => column);

  GeneratedColumn<String> get sourceApp =>
      $composableBuilder(column: $table.sourceApp, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<DateTime> get copiedAt =>
      $composableBuilder(column: $table.copiedAt, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);
}

class $$ClipboardHistoryTableTableManager extends RootTableManager<
    _$LocalBrain,
    $ClipboardHistoryTable,
    ClipboardHistoryData,
    $$ClipboardHistoryTableFilterComposer,
    $$ClipboardHistoryTableOrderingComposer,
    $$ClipboardHistoryTableAnnotationComposer,
    $$ClipboardHistoryTableCreateCompanionBuilder,
    $$ClipboardHistoryTableUpdateCompanionBuilder,
    (
      ClipboardHistoryData,
      BaseReferences<_$LocalBrain, $ClipboardHistoryTable, ClipboardHistoryData>
    ),
    ClipboardHistoryData,
    PrefetchHooks Function()> {
  $$ClipboardHistoryTableTableManager(
      _$LocalBrain db, $ClipboardHistoryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClipboardHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClipboardHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClipboardHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String> contentType = const Value.absent(),
            Value<String?> sourceApp = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<DateTime> copiedAt = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
          }) =>
              ClipboardHistoryCompanion(
            id: id,
            content: content,
            contentType: contentType,
            sourceApp: sourceApp,
            timestamp: timestamp,
            copiedAt: copiedAt,
            isPinned: isPinned,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String content,
            required String contentType,
            Value<String?> sourceApp = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<DateTime> copiedAt = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
          }) =>
              ClipboardHistoryCompanion.insert(
            id: id,
            content: content,
            contentType: contentType,
            sourceApp: sourceApp,
            timestamp: timestamp,
            copiedAt: copiedAt,
            isPinned: isPinned,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ClipboardHistoryTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $ClipboardHistoryTable,
    ClipboardHistoryData,
    $$ClipboardHistoryTableFilterComposer,
    $$ClipboardHistoryTableOrderingComposer,
    $$ClipboardHistoryTableAnnotationComposer,
    $$ClipboardHistoryTableCreateCompanionBuilder,
    $$ClipboardHistoryTableUpdateCompanionBuilder,
    (
      ClipboardHistoryData,
      BaseReferences<_$LocalBrain, $ClipboardHistoryTable, ClipboardHistoryData>
    ),
    ClipboardHistoryData,
    PrefetchHooks Function()>;
typedef $$ActionHistoryEntriesTableCreateCompanionBuilder
    = ActionHistoryEntriesCompanion Function({
  Value<int> id,
  required String actionType,
  Value<String?> targetElement,
  Value<String?> parameters,
  Value<DateTime> timestamp,
  Value<String?> result,
});
typedef $$ActionHistoryEntriesTableUpdateCompanionBuilder
    = ActionHistoryEntriesCompanion Function({
  Value<int> id,
  Value<String> actionType,
  Value<String?> targetElement,
  Value<String?> parameters,
  Value<DateTime> timestamp,
  Value<String?> result,
});

class $$ActionHistoryEntriesTableFilterComposer
    extends Composer<_$LocalBrain, $ActionHistoryEntriesTable> {
  $$ActionHistoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetElement => $composableBuilder(
      column: $table.targetElement, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parameters => $composableBuilder(
      column: $table.parameters, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get result => $composableBuilder(
      column: $table.result, builder: (column) => ColumnFilters(column));
}

class $$ActionHistoryEntriesTableOrderingComposer
    extends Composer<_$LocalBrain, $ActionHistoryEntriesTable> {
  $$ActionHistoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetElement => $composableBuilder(
      column: $table.targetElement,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parameters => $composableBuilder(
      column: $table.parameters, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get result => $composableBuilder(
      column: $table.result, builder: (column) => ColumnOrderings(column));
}

class $$ActionHistoryEntriesTableAnnotationComposer
    extends Composer<_$LocalBrain, $ActionHistoryEntriesTable> {
  $$ActionHistoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => column);

  GeneratedColumn<String> get targetElement => $composableBuilder(
      column: $table.targetElement, builder: (column) => column);

  GeneratedColumn<String> get parameters => $composableBuilder(
      column: $table.parameters, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);
}

class $$ActionHistoryEntriesTableTableManager extends RootTableManager<
    _$LocalBrain,
    $ActionHistoryEntriesTable,
    ActionHistoryEntry,
    $$ActionHistoryEntriesTableFilterComposer,
    $$ActionHistoryEntriesTableOrderingComposer,
    $$ActionHistoryEntriesTableAnnotationComposer,
    $$ActionHistoryEntriesTableCreateCompanionBuilder,
    $$ActionHistoryEntriesTableUpdateCompanionBuilder,
    (
      ActionHistoryEntry,
      BaseReferences<_$LocalBrain, $ActionHistoryEntriesTable,
          ActionHistoryEntry>
    ),
    ActionHistoryEntry,
    PrefetchHooks Function()> {
  $$ActionHistoryEntriesTableTableManager(
      _$LocalBrain db, $ActionHistoryEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActionHistoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActionHistoryEntriesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActionHistoryEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> actionType = const Value.absent(),
            Value<String?> targetElement = const Value.absent(),
            Value<String?> parameters = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String?> result = const Value.absent(),
          }) =>
              ActionHistoryEntriesCompanion(
            id: id,
            actionType: actionType,
            targetElement: targetElement,
            parameters: parameters,
            timestamp: timestamp,
            result: result,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String actionType,
            Value<String?> targetElement = const Value.absent(),
            Value<String?> parameters = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String?> result = const Value.absent(),
          }) =>
              ActionHistoryEntriesCompanion.insert(
            id: id,
            actionType: actionType,
            targetElement: targetElement,
            parameters: parameters,
            timestamp: timestamp,
            result: result,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ActionHistoryEntriesTableProcessedTableManager
    = ProcessedTableManager<
        _$LocalBrain,
        $ActionHistoryEntriesTable,
        ActionHistoryEntry,
        $$ActionHistoryEntriesTableFilterComposer,
        $$ActionHistoryEntriesTableOrderingComposer,
        $$ActionHistoryEntriesTableAnnotationComposer,
        $$ActionHistoryEntriesTableCreateCompanionBuilder,
        $$ActionHistoryEntriesTableUpdateCompanionBuilder,
        (
          ActionHistoryEntry,
          BaseReferences<_$LocalBrain, $ActionHistoryEntriesTable,
              ActionHistoryEntry>
        ),
        ActionHistoryEntry,
        PrefetchHooks Function()>;
typedef $$MacrosTableCreateCompanionBuilder = MacrosCompanion Function({
  required String id,
  required String name,
  Value<String?> description,
  required String sequence,
  required String triggerType,
  Value<String?> triggerData,
  Value<DateTime> createdAt,
  Value<DateTime?> lastUsed,
  Value<int> rowid,
});
typedef $$MacrosTableUpdateCompanionBuilder = MacrosCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> description,
  Value<String> sequence,
  Value<String> triggerType,
  Value<String?> triggerData,
  Value<DateTime> createdAt,
  Value<DateTime?> lastUsed,
  Value<int> rowid,
});

class $$MacrosTableFilterComposer extends Composer<_$LocalBrain, $MacrosTable> {
  $$MacrosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sequence => $composableBuilder(
      column: $table.sequence, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get triggerType => $composableBuilder(
      column: $table.triggerType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get triggerData => $composableBuilder(
      column: $table.triggerData, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUsed => $composableBuilder(
      column: $table.lastUsed, builder: (column) => ColumnFilters(column));
}

class $$MacrosTableOrderingComposer
    extends Composer<_$LocalBrain, $MacrosTable> {
  $$MacrosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sequence => $composableBuilder(
      column: $table.sequence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get triggerType => $composableBuilder(
      column: $table.triggerType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get triggerData => $composableBuilder(
      column: $table.triggerData, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUsed => $composableBuilder(
      column: $table.lastUsed, builder: (column) => ColumnOrderings(column));
}

class $$MacrosTableAnnotationComposer
    extends Composer<_$LocalBrain, $MacrosTable> {
  $$MacrosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get triggerType => $composableBuilder(
      column: $table.triggerType, builder: (column) => column);

  GeneratedColumn<String> get triggerData => $composableBuilder(
      column: $table.triggerData, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsed =>
      $composableBuilder(column: $table.lastUsed, builder: (column) => column);
}

class $$MacrosTableTableManager extends RootTableManager<
    _$LocalBrain,
    $MacrosTable,
    Macro,
    $$MacrosTableFilterComposer,
    $$MacrosTableOrderingComposer,
    $$MacrosTableAnnotationComposer,
    $$MacrosTableCreateCompanionBuilder,
    $$MacrosTableUpdateCompanionBuilder,
    (Macro, BaseReferences<_$LocalBrain, $MacrosTable, Macro>),
    Macro,
    PrefetchHooks Function()> {
  $$MacrosTableTableManager(_$LocalBrain db, $MacrosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MacrosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MacrosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MacrosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> sequence = const Value.absent(),
            Value<String> triggerType = const Value.absent(),
            Value<String?> triggerData = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastUsed = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MacrosCompanion(
            id: id,
            name: name,
            description: description,
            sequence: sequence,
            triggerType: triggerType,
            triggerData: triggerData,
            createdAt: createdAt,
            lastUsed: lastUsed,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> description = const Value.absent(),
            required String sequence,
            required String triggerType,
            Value<String?> triggerData = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastUsed = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MacrosCompanion.insert(
            id: id,
            name: name,
            description: description,
            sequence: sequence,
            triggerType: triggerType,
            triggerData: triggerData,
            createdAt: createdAt,
            lastUsed: lastUsed,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MacrosTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $MacrosTable,
    Macro,
    $$MacrosTableFilterComposer,
    $$MacrosTableOrderingComposer,
    $$MacrosTableAnnotationComposer,
    $$MacrosTableCreateCompanionBuilder,
    $$MacrosTableUpdateCompanionBuilder,
    (Macro, BaseReferences<_$LocalBrain, $MacrosTable, Macro>),
    Macro,
    PrefetchHooks Function()>;
typedef $$AvatarPersonalityProfilesTableCreateCompanionBuilder
    = AvatarPersonalityProfilesCompanion Function({
  Value<String> id,
  Value<String> agentName,
  required String personalityTraits,
  Value<String> evolutionStage,
  Value<int> conversationCount,
  Value<double> depthScore,
  Value<int?> createdAt,
  Value<int?> updatedAt,
  Value<int> rowid,
});
typedef $$AvatarPersonalityProfilesTableUpdateCompanionBuilder
    = AvatarPersonalityProfilesCompanion Function({
  Value<String> id,
  Value<String> agentName,
  Value<String> personalityTraits,
  Value<String> evolutionStage,
  Value<int> conversationCount,
  Value<double> depthScore,
  Value<int?> createdAt,
  Value<int?> updatedAt,
  Value<int> rowid,
});

final class $$AvatarPersonalityProfilesTableReferences extends BaseReferences<
    _$LocalBrain, $AvatarPersonalityProfilesTable, AvatarPersonalityProfile> {
  $$AvatarPersonalityProfilesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EvolutionHistoryTableTable,
      List<EvolutionHistory>> _evolutionHistoryTableRefsTable(
          _$LocalBrain db) =>
      MultiTypedResultKey.fromTable(db.evolutionHistoryTable,
          aliasName: $_aliasNameGenerator(db.avatarPersonalityProfiles.id,
              db.evolutionHistoryTable.avatarId));

  $$EvolutionHistoryTableTableProcessedTableManager
      get evolutionHistoryTableRefs {
    final manager = $$EvolutionHistoryTableTableTableManager(
            $_db, $_db.evolutionHistoryTable)
        .filter((f) => f.avatarId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_evolutionHistoryTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$AvatarPersonalityProfilesTableFilterComposer
    extends Composer<_$LocalBrain, $AvatarPersonalityProfilesTable> {
  $$AvatarPersonalityProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get agentName => $composableBuilder(
      column: $table.agentName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get personalityTraits => $composableBuilder(
      column: $table.personalityTraits,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get evolutionStage => $composableBuilder(
      column: $table.evolutionStage,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get conversationCount => $composableBuilder(
      column: $table.conversationCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get depthScore => $composableBuilder(
      column: $table.depthScore, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> evolutionHistoryTableRefs(
      Expression<bool> Function($$EvolutionHistoryTableTableFilterComposer f)
          f) {
    final $$EvolutionHistoryTableTableFilterComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.evolutionHistoryTable,
            getReferencedColumn: (t) => t.avatarId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$EvolutionHistoryTableTableFilterComposer(
                  $db: $db,
                  $table: $db.evolutionHistoryTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$AvatarPersonalityProfilesTableOrderingComposer
    extends Composer<_$LocalBrain, $AvatarPersonalityProfilesTable> {
  $$AvatarPersonalityProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get agentName => $composableBuilder(
      column: $table.agentName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get personalityTraits => $composableBuilder(
      column: $table.personalityTraits,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get evolutionStage => $composableBuilder(
      column: $table.evolutionStage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get conversationCount => $composableBuilder(
      column: $table.conversationCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get depthScore => $composableBuilder(
      column: $table.depthScore, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AvatarPersonalityProfilesTableAnnotationComposer
    extends Composer<_$LocalBrain, $AvatarPersonalityProfilesTable> {
  $$AvatarPersonalityProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get agentName =>
      $composableBuilder(column: $table.agentName, builder: (column) => column);

  GeneratedColumn<String> get personalityTraits => $composableBuilder(
      column: $table.personalityTraits, builder: (column) => column);

  GeneratedColumn<String> get evolutionStage => $composableBuilder(
      column: $table.evolutionStage, builder: (column) => column);

  GeneratedColumn<int> get conversationCount => $composableBuilder(
      column: $table.conversationCount, builder: (column) => column);

  GeneratedColumn<double> get depthScore => $composableBuilder(
      column: $table.depthScore, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> evolutionHistoryTableRefs<T extends Object>(
      Expression<T> Function($$EvolutionHistoryTableTableAnnotationComposer a)
          f) {
    final $$EvolutionHistoryTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.evolutionHistoryTable,
            getReferencedColumn: (t) => t.avatarId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$EvolutionHistoryTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.evolutionHistoryTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$AvatarPersonalityProfilesTableTableManager extends RootTableManager<
    _$LocalBrain,
    $AvatarPersonalityProfilesTable,
    AvatarPersonalityProfile,
    $$AvatarPersonalityProfilesTableFilterComposer,
    $$AvatarPersonalityProfilesTableOrderingComposer,
    $$AvatarPersonalityProfilesTableAnnotationComposer,
    $$AvatarPersonalityProfilesTableCreateCompanionBuilder,
    $$AvatarPersonalityProfilesTableUpdateCompanionBuilder,
    (AvatarPersonalityProfile, $$AvatarPersonalityProfilesTableReferences),
    AvatarPersonalityProfile,
    PrefetchHooks Function({bool evolutionHistoryTableRefs})> {
  $$AvatarPersonalityProfilesTableTableManager(
      _$LocalBrain db, $AvatarPersonalityProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AvatarPersonalityProfilesTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$AvatarPersonalityProfilesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AvatarPersonalityProfilesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> agentName = const Value.absent(),
            Value<String> personalityTraits = const Value.absent(),
            Value<String> evolutionStage = const Value.absent(),
            Value<int> conversationCount = const Value.absent(),
            Value<double> depthScore = const Value.absent(),
            Value<int?> createdAt = const Value.absent(),
            Value<int?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AvatarPersonalityProfilesCompanion(
            id: id,
            agentName: agentName,
            personalityTraits: personalityTraits,
            evolutionStage: evolutionStage,
            conversationCount: conversationCount,
            depthScore: depthScore,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> agentName = const Value.absent(),
            required String personalityTraits,
            Value<String> evolutionStage = const Value.absent(),
            Value<int> conversationCount = const Value.absent(),
            Value<double> depthScore = const Value.absent(),
            Value<int?> createdAt = const Value.absent(),
            Value<int?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AvatarPersonalityProfilesCompanion.insert(
            id: id,
            agentName: agentName,
            personalityTraits: personalityTraits,
            evolutionStage: evolutionStage,
            conversationCount: conversationCount,
            depthScore: depthScore,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AvatarPersonalityProfilesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({evolutionHistoryTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (evolutionHistoryTableRefs) db.evolutionHistoryTable
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (evolutionHistoryTableRefs)
                    await $_getPrefetchedData<AvatarPersonalityProfile,
                            $AvatarPersonalityProfilesTable, EvolutionHistory>(
                        currentTable: table,
                        referencedTable:
                            $$AvatarPersonalityProfilesTableReferences
                                ._evolutionHistoryTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$AvatarPersonalityProfilesTableReferences(
                                    db, table, p0)
                                .evolutionHistoryTableRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.avatarId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$AvatarPersonalityProfilesTableProcessedTableManager
    = ProcessedTableManager<
        _$LocalBrain,
        $AvatarPersonalityProfilesTable,
        AvatarPersonalityProfile,
        $$AvatarPersonalityProfilesTableFilterComposer,
        $$AvatarPersonalityProfilesTableOrderingComposer,
        $$AvatarPersonalityProfilesTableAnnotationComposer,
        $$AvatarPersonalityProfilesTableCreateCompanionBuilder,
        $$AvatarPersonalityProfilesTableUpdateCompanionBuilder,
        (AvatarPersonalityProfile, $$AvatarPersonalityProfilesTableReferences),
        AvatarPersonalityProfile,
        PrefetchHooks Function({bool evolutionHistoryTableRefs})>;
typedef $$EvolutionHistoryTableTableCreateCompanionBuilder
    = EvolutionHistoryTableCompanion Function({
  required String id,
  required String avatarId,
  required String fromStage,
  required String toStage,
  required String triggerReason,
  Value<String?> context,
  required String confirmedBy,
  required int triggeredAt,
  Value<int> rowid,
});
typedef $$EvolutionHistoryTableTableUpdateCompanionBuilder
    = EvolutionHistoryTableCompanion Function({
  Value<String> id,
  Value<String> avatarId,
  Value<String> fromStage,
  Value<String> toStage,
  Value<String> triggerReason,
  Value<String?> context,
  Value<String> confirmedBy,
  Value<int> triggeredAt,
  Value<int> rowid,
});

final class $$EvolutionHistoryTableTableReferences extends BaseReferences<
    _$LocalBrain, $EvolutionHistoryTableTable, EvolutionHistory> {
  $$EvolutionHistoryTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $AvatarPersonalityProfilesTable _avatarIdTable(_$LocalBrain db) =>
      db.avatarPersonalityProfiles.createAlias($_aliasNameGenerator(
          db.evolutionHistoryTable.avatarId, db.avatarPersonalityProfiles.id));

  $$AvatarPersonalityProfilesTableProcessedTableManager get avatarId {
    final $_column = $_itemColumn<String>('avatar_id')!;

    final manager = $$AvatarPersonalityProfilesTableTableManager(
            $_db, $_db.avatarPersonalityProfiles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_avatarIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$EvolutionHistoryTableTableFilterComposer
    extends Composer<_$LocalBrain, $EvolutionHistoryTableTable> {
  $$EvolutionHistoryTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fromStage => $composableBuilder(
      column: $table.fromStage, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toStage => $composableBuilder(
      column: $table.toStage, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get triggerReason => $composableBuilder(
      column: $table.triggerReason, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get context => $composableBuilder(
      column: $table.context, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get confirmedBy => $composableBuilder(
      column: $table.confirmedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get triggeredAt => $composableBuilder(
      column: $table.triggeredAt, builder: (column) => ColumnFilters(column));

  $$AvatarPersonalityProfilesTableFilterComposer get avatarId {
    final $$AvatarPersonalityProfilesTableFilterComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.avatarId,
            referencedTable: $db.avatarPersonalityProfiles,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$AvatarPersonalityProfilesTableFilterComposer(
                  $db: $db,
                  $table: $db.avatarPersonalityProfiles,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$EvolutionHistoryTableTableOrderingComposer
    extends Composer<_$LocalBrain, $EvolutionHistoryTableTable> {
  $$EvolutionHistoryTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fromStage => $composableBuilder(
      column: $table.fromStage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toStage => $composableBuilder(
      column: $table.toStage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get triggerReason => $composableBuilder(
      column: $table.triggerReason,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get context => $composableBuilder(
      column: $table.context, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get confirmedBy => $composableBuilder(
      column: $table.confirmedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get triggeredAt => $composableBuilder(
      column: $table.triggeredAt, builder: (column) => ColumnOrderings(column));

  $$AvatarPersonalityProfilesTableOrderingComposer get avatarId {
    final $$AvatarPersonalityProfilesTableOrderingComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.avatarId,
            referencedTable: $db.avatarPersonalityProfiles,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$AvatarPersonalityProfilesTableOrderingComposer(
                  $db: $db,
                  $table: $db.avatarPersonalityProfiles,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$EvolutionHistoryTableTableAnnotationComposer
    extends Composer<_$LocalBrain, $EvolutionHistoryTableTable> {
  $$EvolutionHistoryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fromStage =>
      $composableBuilder(column: $table.fromStage, builder: (column) => column);

  GeneratedColumn<String> get toStage =>
      $composableBuilder(column: $table.toStage, builder: (column) => column);

  GeneratedColumn<String> get triggerReason => $composableBuilder(
      column: $table.triggerReason, builder: (column) => column);

  GeneratedColumn<String> get context =>
      $composableBuilder(column: $table.context, builder: (column) => column);

  GeneratedColumn<String> get confirmedBy => $composableBuilder(
      column: $table.confirmedBy, builder: (column) => column);

  GeneratedColumn<int> get triggeredAt => $composableBuilder(
      column: $table.triggeredAt, builder: (column) => column);

  $$AvatarPersonalityProfilesTableAnnotationComposer get avatarId {
    final $$AvatarPersonalityProfilesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.avatarId,
            referencedTable: $db.avatarPersonalityProfiles,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$AvatarPersonalityProfilesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.avatarPersonalityProfiles,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$EvolutionHistoryTableTableTableManager extends RootTableManager<
    _$LocalBrain,
    $EvolutionHistoryTableTable,
    EvolutionHistory,
    $$EvolutionHistoryTableTableFilterComposer,
    $$EvolutionHistoryTableTableOrderingComposer,
    $$EvolutionHistoryTableTableAnnotationComposer,
    $$EvolutionHistoryTableTableCreateCompanionBuilder,
    $$EvolutionHistoryTableTableUpdateCompanionBuilder,
    (EvolutionHistory, $$EvolutionHistoryTableTableReferences),
    EvolutionHistory,
    PrefetchHooks Function({bool avatarId})> {
  $$EvolutionHistoryTableTableTableManager(
      _$LocalBrain db, $EvolutionHistoryTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EvolutionHistoryTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$EvolutionHistoryTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EvolutionHistoryTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> avatarId = const Value.absent(),
            Value<String> fromStage = const Value.absent(),
            Value<String> toStage = const Value.absent(),
            Value<String> triggerReason = const Value.absent(),
            Value<String?> context = const Value.absent(),
            Value<String> confirmedBy = const Value.absent(),
            Value<int> triggeredAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EvolutionHistoryTableCompanion(
            id: id,
            avatarId: avatarId,
            fromStage: fromStage,
            toStage: toStage,
            triggerReason: triggerReason,
            context: context,
            confirmedBy: confirmedBy,
            triggeredAt: triggeredAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String avatarId,
            required String fromStage,
            required String toStage,
            required String triggerReason,
            Value<String?> context = const Value.absent(),
            required String confirmedBy,
            required int triggeredAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              EvolutionHistoryTableCompanion.insert(
            id: id,
            avatarId: avatarId,
            fromStage: fromStage,
            toStage: toStage,
            triggerReason: triggerReason,
            context: context,
            confirmedBy: confirmedBy,
            triggeredAt: triggeredAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$EvolutionHistoryTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({avatarId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (avatarId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.avatarId,
                    referencedTable: $$EvolutionHistoryTableTableReferences
                        ._avatarIdTable(db),
                    referencedColumn: $$EvolutionHistoryTableTableReferences
                        ._avatarIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$EvolutionHistoryTableTableProcessedTableManager
    = ProcessedTableManager<
        _$LocalBrain,
        $EvolutionHistoryTableTable,
        EvolutionHistory,
        $$EvolutionHistoryTableTableFilterComposer,
        $$EvolutionHistoryTableTableOrderingComposer,
        $$EvolutionHistoryTableTableAnnotationComposer,
        $$EvolutionHistoryTableTableCreateCompanionBuilder,
        $$EvolutionHistoryTableTableUpdateCompanionBuilder,
        (EvolutionHistory, $$EvolutionHistoryTableTableReferences),
        EvolutionHistory,
        PrefetchHooks Function({bool avatarId})>;
typedef $$ConversationDepthMetricsTableCreateCompanionBuilder
    = ConversationDepthMetricsCompanion Function({
  required String id,
  required String conversationId,
  required double complexityScore,
  required double emotionalDepth,
  required double noveltyScore,
  required int timestamp,
  Value<int> rowid,
});
typedef $$ConversationDepthMetricsTableUpdateCompanionBuilder
    = ConversationDepthMetricsCompanion Function({
  Value<String> id,
  Value<String> conversationId,
  Value<double> complexityScore,
  Value<double> emotionalDepth,
  Value<double> noveltyScore,
  Value<int> timestamp,
  Value<int> rowid,
});

final class $$ConversationDepthMetricsTableReferences extends BaseReferences<
    _$LocalBrain, $ConversationDepthMetricsTable, ConversationDepthMetric> {
  $$ConversationDepthMetricsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ConversationsTable _conversationIdTable(_$LocalBrain db) =>
      db.conversations.createAlias($_aliasNameGenerator(
          db.conversationDepthMetrics.conversationId, db.conversations.id));

  $$ConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableManager($_db, $_db.conversations)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ConversationDepthMetricsTableFilterComposer
    extends Composer<_$LocalBrain, $ConversationDepthMetricsTable> {
  $$ConversationDepthMetricsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get complexityScore => $composableBuilder(
      column: $table.complexityScore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get emotionalDepth => $composableBuilder(
      column: $table.emotionalDepth,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get noveltyScore => $composableBuilder(
      column: $table.noveltyScore, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conversationId,
        referencedTable: $db.conversations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConversationsTableFilterComposer(
              $db: $db,
              $table: $db.conversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ConversationDepthMetricsTableOrderingComposer
    extends Composer<_$LocalBrain, $ConversationDepthMetricsTable> {
  $$ConversationDepthMetricsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get complexityScore => $composableBuilder(
      column: $table.complexityScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get emotionalDepth => $composableBuilder(
      column: $table.emotionalDepth,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get noveltyScore => $composableBuilder(
      column: $table.noveltyScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conversationId,
        referencedTable: $db.conversations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConversationsTableOrderingComposer(
              $db: $db,
              $table: $db.conversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ConversationDepthMetricsTableAnnotationComposer
    extends Composer<_$LocalBrain, $ConversationDepthMetricsTable> {
  $$ConversationDepthMetricsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get complexityScore => $composableBuilder(
      column: $table.complexityScore, builder: (column) => column);

  GeneratedColumn<double> get emotionalDepth => $composableBuilder(
      column: $table.emotionalDepth, builder: (column) => column);

  GeneratedColumn<double> get noveltyScore => $composableBuilder(
      column: $table.noveltyScore, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conversationId,
        referencedTable: $db.conversations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConversationsTableAnnotationComposer(
              $db: $db,
              $table: $db.conversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ConversationDepthMetricsTableTableManager extends RootTableManager<
    _$LocalBrain,
    $ConversationDepthMetricsTable,
    ConversationDepthMetric,
    $$ConversationDepthMetricsTableFilterComposer,
    $$ConversationDepthMetricsTableOrderingComposer,
    $$ConversationDepthMetricsTableAnnotationComposer,
    $$ConversationDepthMetricsTableCreateCompanionBuilder,
    $$ConversationDepthMetricsTableUpdateCompanionBuilder,
    (ConversationDepthMetric, $$ConversationDepthMetricsTableReferences),
    ConversationDepthMetric,
    PrefetchHooks Function({bool conversationId})> {
  $$ConversationDepthMetricsTableTableManager(
      _$LocalBrain db, $ConversationDepthMetricsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationDepthMetricsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationDepthMetricsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationDepthMetricsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> conversationId = const Value.absent(),
            Value<double> complexityScore = const Value.absent(),
            Value<double> emotionalDepth = const Value.absent(),
            Value<double> noveltyScore = const Value.absent(),
            Value<int> timestamp = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationDepthMetricsCompanion(
            id: id,
            conversationId: conversationId,
            complexityScore: complexityScore,
            emotionalDepth: emotionalDepth,
            noveltyScore: noveltyScore,
            timestamp: timestamp,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String conversationId,
            required double complexityScore,
            required double emotionalDepth,
            required double noveltyScore,
            required int timestamp,
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationDepthMetricsCompanion.insert(
            id: id,
            conversationId: conversationId,
            complexityScore: complexityScore,
            emotionalDepth: emotionalDepth,
            noveltyScore: noveltyScore,
            timestamp: timestamp,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ConversationDepthMetricsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (conversationId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.conversationId,
                    referencedTable: $$ConversationDepthMetricsTableReferences
                        ._conversationIdTable(db),
                    referencedColumn: $$ConversationDepthMetricsTableReferences
                        ._conversationIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ConversationDepthMetricsTableProcessedTableManager
    = ProcessedTableManager<
        _$LocalBrain,
        $ConversationDepthMetricsTable,
        ConversationDepthMetric,
        $$ConversationDepthMetricsTableFilterComposer,
        $$ConversationDepthMetricsTableOrderingComposer,
        $$ConversationDepthMetricsTableAnnotationComposer,
        $$ConversationDepthMetricsTableCreateCompanionBuilder,
        $$ConversationDepthMetricsTableUpdateCompanionBuilder,
        (ConversationDepthMetric, $$ConversationDepthMetricsTableReferences),
        ConversationDepthMetric,
        PrefetchHooks Function({bool conversationId})>;
typedef $$ConversationMemoriesTableCreateCompanionBuilder
    = ConversationMemoriesCompanion Function({
  required String id,
  required String conversationId,
  required String content,
  required String embedding,
  Value<DateTime> timestamp,
  Value<String?> summary,
  Value<int> rowid,
});
typedef $$ConversationMemoriesTableUpdateCompanionBuilder
    = ConversationMemoriesCompanion Function({
  Value<String> id,
  Value<String> conversationId,
  Value<String> content,
  Value<String> embedding,
  Value<DateTime> timestamp,
  Value<String?> summary,
  Value<int> rowid,
});

final class $$ConversationMemoriesTableReferences extends BaseReferences<
    _$LocalBrain, $ConversationMemoriesTable, ConversationMemory> {
  $$ConversationMemoriesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ConversationsTable _conversationIdTable(_$LocalBrain db) =>
      db.conversations.createAlias($_aliasNameGenerator(
          db.conversationMemories.conversationId, db.conversations.id));

  $$ConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableManager($_db, $_db.conversations)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ConversationMemoriesTableFilterComposer
    extends Composer<_$LocalBrain, $ConversationMemoriesTable> {
  $$ConversationMemoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get embedding => $composableBuilder(
      column: $table.embedding, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnFilters(column));

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conversationId,
        referencedTable: $db.conversations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConversationsTableFilterComposer(
              $db: $db,
              $table: $db.conversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ConversationMemoriesTableOrderingComposer
    extends Composer<_$LocalBrain, $ConversationMemoriesTable> {
  $$ConversationMemoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get embedding => $composableBuilder(
      column: $table.embedding, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnOrderings(column));

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conversationId,
        referencedTable: $db.conversations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConversationsTableOrderingComposer(
              $db: $db,
              $table: $db.conversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ConversationMemoriesTableAnnotationComposer
    extends Composer<_$LocalBrain, $ConversationMemoriesTable> {
  $$ConversationMemoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conversationId,
        referencedTable: $db.conversations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConversationsTableAnnotationComposer(
              $db: $db,
              $table: $db.conversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ConversationMemoriesTableTableManager extends RootTableManager<
    _$LocalBrain,
    $ConversationMemoriesTable,
    ConversationMemory,
    $$ConversationMemoriesTableFilterComposer,
    $$ConversationMemoriesTableOrderingComposer,
    $$ConversationMemoriesTableAnnotationComposer,
    $$ConversationMemoriesTableCreateCompanionBuilder,
    $$ConversationMemoriesTableUpdateCompanionBuilder,
    (ConversationMemory, $$ConversationMemoriesTableReferences),
    ConversationMemory,
    PrefetchHooks Function({bool conversationId})> {
  $$ConversationMemoriesTableTableManager(
      _$LocalBrain db, $ConversationMemoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationMemoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationMemoriesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationMemoriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> conversationId = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String> embedding = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String?> summary = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationMemoriesCompanion(
            id: id,
            conversationId: conversationId,
            content: content,
            embedding: embedding,
            timestamp: timestamp,
            summary: summary,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String conversationId,
            required String content,
            required String embedding,
            Value<DateTime> timestamp = const Value.absent(),
            Value<String?> summary = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationMemoriesCompanion.insert(
            id: id,
            conversationId: conversationId,
            content: content,
            embedding: embedding,
            timestamp: timestamp,
            summary: summary,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ConversationMemoriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (conversationId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.conversationId,
                    referencedTable: $$ConversationMemoriesTableReferences
                        ._conversationIdTable(db),
                    referencedColumn: $$ConversationMemoriesTableReferences
                        ._conversationIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ConversationMemoriesTableProcessedTableManager
    = ProcessedTableManager<
        _$LocalBrain,
        $ConversationMemoriesTable,
        ConversationMemory,
        $$ConversationMemoriesTableFilterComposer,
        $$ConversationMemoriesTableOrderingComposer,
        $$ConversationMemoriesTableAnnotationComposer,
        $$ConversationMemoriesTableCreateCompanionBuilder,
        $$ConversationMemoriesTableUpdateCompanionBuilder,
        (ConversationMemory, $$ConversationMemoriesTableReferences),
        ConversationMemory,
        PrefetchHooks Function({bool conversationId})>;
typedef $$AgentThoughtsTableCreateCompanionBuilder = AgentThoughtsCompanion
    Function({
  required String id,
  Value<DateTime> timestamp,
  Value<String> channel,
  required String agent,
  required String thoughtType,
  required String content,
  Value<String?> metadata,
  Value<int> rowid,
});
typedef $$AgentThoughtsTableUpdateCompanionBuilder = AgentThoughtsCompanion
    Function({
  Value<String> id,
  Value<DateTime> timestamp,
  Value<String> channel,
  Value<String> agent,
  Value<String> thoughtType,
  Value<String> content,
  Value<String?> metadata,
  Value<int> rowid,
});

class $$AgentThoughtsTableFilterComposer
    extends Composer<_$LocalBrain, $AgentThoughtsTable> {
  $$AgentThoughtsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get channel => $composableBuilder(
      column: $table.channel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get agent => $composableBuilder(
      column: $table.agent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thoughtType => $composableBuilder(
      column: $table.thoughtType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnFilters(column));
}

class $$AgentThoughtsTableOrderingComposer
    extends Composer<_$LocalBrain, $AgentThoughtsTable> {
  $$AgentThoughtsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get channel => $composableBuilder(
      column: $table.channel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get agent => $composableBuilder(
      column: $table.agent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thoughtType => $composableBuilder(
      column: $table.thoughtType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnOrderings(column));
}

class $$AgentThoughtsTableAnnotationComposer
    extends Composer<_$LocalBrain, $AgentThoughtsTable> {
  $$AgentThoughtsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get agent =>
      $composableBuilder(column: $table.agent, builder: (column) => column);

  GeneratedColumn<String> get thoughtType => $composableBuilder(
      column: $table.thoughtType, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);
}

class $$AgentThoughtsTableTableManager extends RootTableManager<
    _$LocalBrain,
    $AgentThoughtsTable,
    AgentThought,
    $$AgentThoughtsTableFilterComposer,
    $$AgentThoughtsTableOrderingComposer,
    $$AgentThoughtsTableAnnotationComposer,
    $$AgentThoughtsTableCreateCompanionBuilder,
    $$AgentThoughtsTableUpdateCompanionBuilder,
    (
      AgentThought,
      BaseReferences<_$LocalBrain, $AgentThoughtsTable, AgentThought>
    ),
    AgentThought,
    PrefetchHooks Function()> {
  $$AgentThoughtsTableTableManager(_$LocalBrain db, $AgentThoughtsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentThoughtsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentThoughtsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentThoughtsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String> channel = const Value.absent(),
            Value<String> agent = const Value.absent(),
            Value<String> thoughtType = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String?> metadata = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AgentThoughtsCompanion(
            id: id,
            timestamp: timestamp,
            channel: channel,
            agent: agent,
            thoughtType: thoughtType,
            content: content,
            metadata: metadata,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<DateTime> timestamp = const Value.absent(),
            Value<String> channel = const Value.absent(),
            required String agent,
            required String thoughtType,
            required String content,
            Value<String?> metadata = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AgentThoughtsCompanion.insert(
            id: id,
            timestamp: timestamp,
            channel: channel,
            agent: agent,
            thoughtType: thoughtType,
            content: content,
            metadata: metadata,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AgentThoughtsTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $AgentThoughtsTable,
    AgentThought,
    $$AgentThoughtsTableFilterComposer,
    $$AgentThoughtsTableOrderingComposer,
    $$AgentThoughtsTableAnnotationComposer,
    $$AgentThoughtsTableCreateCompanionBuilder,
    $$AgentThoughtsTableUpdateCompanionBuilder,
    (
      AgentThought,
      BaseReferences<_$LocalBrain, $AgentThoughtsTable, AgentThought>
    ),
    AgentThought,
    PrefetchHooks Function()>;
typedef $$ConscienceDecisionsTableCreateCompanionBuilder
    = ConscienceDecisionsCompanion Function({
  required String id,
  Value<DateTime> timestamp,
  required String action,
  required String riskLevel,
  Value<String?> verdict,
  Value<String?> reviewer,
  Value<String?> reasoning,
  Value<String> status,
  Value<int> rowid,
});
typedef $$ConscienceDecisionsTableUpdateCompanionBuilder
    = ConscienceDecisionsCompanion Function({
  Value<String> id,
  Value<DateTime> timestamp,
  Value<String> action,
  Value<String> riskLevel,
  Value<String?> verdict,
  Value<String?> reviewer,
  Value<String?> reasoning,
  Value<String> status,
  Value<int> rowid,
});

class $$ConscienceDecisionsTableFilterComposer
    extends Composer<_$LocalBrain, $ConscienceDecisionsTable> {
  $$ConscienceDecisionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get riskLevel => $composableBuilder(
      column: $table.riskLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get verdict => $composableBuilder(
      column: $table.verdict, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reviewer => $composableBuilder(
      column: $table.reviewer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reasoning => $composableBuilder(
      column: $table.reasoning, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));
}

class $$ConscienceDecisionsTableOrderingComposer
    extends Composer<_$LocalBrain, $ConscienceDecisionsTable> {
  $$ConscienceDecisionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get riskLevel => $composableBuilder(
      column: $table.riskLevel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get verdict => $composableBuilder(
      column: $table.verdict, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reviewer => $composableBuilder(
      column: $table.reviewer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reasoning => $composableBuilder(
      column: $table.reasoning, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));
}

class $$ConscienceDecisionsTableAnnotationComposer
    extends Composer<_$LocalBrain, $ConscienceDecisionsTable> {
  $$ConscienceDecisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get riskLevel =>
      $composableBuilder(column: $table.riskLevel, builder: (column) => column);

  GeneratedColumn<String> get verdict =>
      $composableBuilder(column: $table.verdict, builder: (column) => column);

  GeneratedColumn<String> get reviewer =>
      $composableBuilder(column: $table.reviewer, builder: (column) => column);

  GeneratedColumn<String> get reasoning =>
      $composableBuilder(column: $table.reasoning, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$ConscienceDecisionsTableTableManager extends RootTableManager<
    _$LocalBrain,
    $ConscienceDecisionsTable,
    ConscienceDecision,
    $$ConscienceDecisionsTableFilterComposer,
    $$ConscienceDecisionsTableOrderingComposer,
    $$ConscienceDecisionsTableAnnotationComposer,
    $$ConscienceDecisionsTableCreateCompanionBuilder,
    $$ConscienceDecisionsTableUpdateCompanionBuilder,
    (
      ConscienceDecision,
      BaseReferences<_$LocalBrain, $ConscienceDecisionsTable,
          ConscienceDecision>
    ),
    ConscienceDecision,
    PrefetchHooks Function()> {
  $$ConscienceDecisionsTableTableManager(
      _$LocalBrain db, $ConscienceDecisionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConscienceDecisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConscienceDecisionsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConscienceDecisionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<String> riskLevel = const Value.absent(),
            Value<String?> verdict = const Value.absent(),
            Value<String?> reviewer = const Value.absent(),
            Value<String?> reasoning = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConscienceDecisionsCompanion(
            id: id,
            timestamp: timestamp,
            action: action,
            riskLevel: riskLevel,
            verdict: verdict,
            reviewer: reviewer,
            reasoning: reasoning,
            status: status,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<DateTime> timestamp = const Value.absent(),
            required String action,
            required String riskLevel,
            Value<String?> verdict = const Value.absent(),
            Value<String?> reviewer = const Value.absent(),
            Value<String?> reasoning = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConscienceDecisionsCompanion.insert(
            id: id,
            timestamp: timestamp,
            action: action,
            riskLevel: riskLevel,
            verdict: verdict,
            reviewer: reviewer,
            reasoning: reasoning,
            status: status,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConscienceDecisionsTableProcessedTableManager = ProcessedTableManager<
    _$LocalBrain,
    $ConscienceDecisionsTable,
    ConscienceDecision,
    $$ConscienceDecisionsTableFilterComposer,
    $$ConscienceDecisionsTableOrderingComposer,
    $$ConscienceDecisionsTableAnnotationComposer,
    $$ConscienceDecisionsTableCreateCompanionBuilder,
    $$ConscienceDecisionsTableUpdateCompanionBuilder,
    (
      ConscienceDecision,
      BaseReferences<_$LocalBrain, $ConscienceDecisionsTable,
          ConscienceDecision>
    ),
    ConscienceDecision,
    PrefetchHooks Function()>;

class $LocalBrainManager {
  final _$LocalBrain _db;
  $LocalBrainManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$MainChatTimelineRecordsTableTableManager get mainChatTimelineRecords =>
      $$MainChatTimelineRecordsTableTableManager(
          _db, _db.mainChatTimelineRecords);
  $$AgentLogsTableTableManager get agentLogs =>
      $$AgentLogsTableTableManager(_db, _db.agentLogs);
  $$AgentsTableTableManager get agents =>
      $$AgentsTableTableManager(_db, _db.agents);
  $$AgentEventsTableTableManager get agentEvents =>
      $$AgentEventsTableTableManager(_db, _db.agentEvents);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$FileIndexTableTableManager get fileIndex =>
      $$FileIndexTableTableManager(_db, _db.fileIndex);
  $$FileContentCacheTableTableManager get fileContentCache =>
      $$FileContentCacheTableTableManager(_db, _db.fileContentCache);
  $$LlmProvidersTableTableManager get llmProviders =>
      $$LlmProvidersTableTableManager(_db, _db.llmProviders);
  $$ModelCapacityTableTableManager get modelCapacity =>
      $$ModelCapacityTableTableManager(_db, _db.modelCapacity);
  $$LlmRequestsTableTableManager get llmRequests =>
      $$LlmRequestsTableTableManager(_db, _db.llmRequests);
  $$AvatarProfilesTableTableManager get avatarProfiles =>
      $$AvatarProfilesTableTableManager(_db, _db.avatarProfiles);
  $$AchievementsTableTableManager get achievements =>
      $$AchievementsTableTableManager(_db, _db.achievements);
  $$AvatarMemoryEntriesTableTableManager get avatarMemoryEntries =>
      $$AvatarMemoryEntriesTableTableManager(_db, _db.avatarMemoryEntries);
  $$ClipboardHistoryTableTableManager get clipboardHistory =>
      $$ClipboardHistoryTableTableManager(_db, _db.clipboardHistory);
  $$ActionHistoryEntriesTableTableManager get actionHistoryEntries =>
      $$ActionHistoryEntriesTableTableManager(_db, _db.actionHistoryEntries);
  $$MacrosTableTableManager get macros =>
      $$MacrosTableTableManager(_db, _db.macros);
  $$AvatarPersonalityProfilesTableTableManager get avatarPersonalityProfiles =>
      $$AvatarPersonalityProfilesTableTableManager(
          _db, _db.avatarPersonalityProfiles);
  $$EvolutionHistoryTableTableTableManager get evolutionHistoryTable =>
      $$EvolutionHistoryTableTableTableManager(_db, _db.evolutionHistoryTable);
  $$ConversationDepthMetricsTableTableManager get conversationDepthMetrics =>
      $$ConversationDepthMetricsTableTableManager(
          _db, _db.conversationDepthMetrics);
  $$ConversationMemoriesTableTableManager get conversationMemories =>
      $$ConversationMemoriesTableTableManager(_db, _db.conversationMemories);
  $$AgentThoughtsTableTableManager get agentThoughts =>
      $$AgentThoughtsTableTableManager(_db, _db.agentThoughts);
  $$ConscienceDecisionsTableTableManager get conscienceDecisions =>
      $$ConscienceDecisionsTableTableManager(_db, _db.conscienceDecisions);
}
