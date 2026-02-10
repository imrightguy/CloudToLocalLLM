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

abstract class _$LocalBrain extends GeneratedDatabase {
  _$LocalBrain(QueryExecutor e) : super(e);
  $LocalBrainManager get managers => $LocalBrainManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $AgentLogsTable agentLogs = $AgentLogsTable(this);
  late final $AgentEventsTable agentEvents = $AgentEventsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $FileIndexTable fileIndex = $FileIndexTable(this);
  late final $FileContentCacheTable fileContentCache =
      $FileContentCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        users,
        conversations,
        messages,
        agentLogs,
        agentEvents,
        syncQueue,
        fileIndex,
        fileContentCache
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
    PrefetchHooks Function({bool userId, bool messagesRefs})> {
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
          prefetchHooksCallback: ({userId = false, messagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (messagesRefs) db.messages],
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
    PrefetchHooks Function({bool userId, bool messagesRefs})>;
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

class $LocalBrainManager {
  final _$LocalBrain _db;
  $LocalBrainManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$AgentLogsTableTableManager get agentLogs =>
      $$AgentLogsTableTableManager(_db, _db.agentLogs);
  $$AgentEventsTableTableManager get agentEvents =>
      $$AgentEventsTableTableManager(_db, _db.agentEvents);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$FileIndexTableTableManager get fileIndex =>
      $$FileIndexTableTableManager(_db, _db.fileIndex);
  $$FileContentCacheTableTableManager get fileContentCache =>
      $$FileContentCacheTableTableManager(_db, _db.fileContentCache);
}
