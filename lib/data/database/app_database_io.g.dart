// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database_io.dart';

// ignore_for_file: type=lint
class $UsageRecordsTable extends UsageRecords
    with TableInfo<$UsageRecordsTable, UsageRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputTokensMeta = const VerificationMeta(
    'inputTokens',
  );
  @override
  late final GeneratedColumn<int> inputTokens = GeneratedColumn<int>(
    'input_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outputTokensMeta = const VerificationMeta(
    'outputTokens',
  );
  @override
  late final GeneratedColumn<int> outputTokens = GeneratedColumn<int>(
    'output_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costUsdMeta = const VerificationMeta(
    'costUsd',
  );
  @override
  late final GeneratedColumn<double> costUsd = GeneratedColumn<double>(
    'cost_usd',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    model,
    inputTokens,
    outputTokens,
    costUsd,
    source,
    sessionId,
    metadata,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('input_tokens')) {
      context.handle(
        _inputTokensMeta,
        inputTokens.isAcceptableOrUnknown(
          data['input_tokens']!,
          _inputTokensMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inputTokensMeta);
    }
    if (data.containsKey('output_tokens')) {
      context.handle(
        _outputTokensMeta,
        outputTokens.isAcceptableOrUnknown(
          data['output_tokens']!,
          _outputTokensMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outputTokensMeta);
    }
    if (data.containsKey('cost_usd')) {
      context.handle(
        _costUsdMeta,
        costUsd.isAcceptableOrUnknown(data['cost_usd']!, _costUsdMeta),
      );
    } else if (isInserting) {
      context.missing(_costUsdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UsageRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      inputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_tokens'],
      )!,
      outputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_tokens'],
      )!,
      costUsd: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost_usd'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UsageRecordsTable createAlias(String alias) {
    return $UsageRecordsTable(attachedDatabase, alias);
  }
}

class UsageRecord extends DataClass implements Insertable<UsageRecord> {
  final String id;
  final String model;
  final int inputTokens;
  final int outputTokens;
  final double costUsd;
  final String source;
  final String? sessionId;
  final String metadata;
  final DateTime createdAt;
  const UsageRecord({
    required this.id,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.costUsd,
    required this.source,
    this.sessionId,
    required this.metadata,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['model'] = Variable<String>(model);
    map['input_tokens'] = Variable<int>(inputTokens);
    map['output_tokens'] = Variable<int>(outputTokens);
    map['cost_usd'] = Variable<double>(costUsd);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    map['metadata'] = Variable<String>(metadata);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UsageRecordsCompanion toCompanion(bool nullToAbsent) {
    return UsageRecordsCompanion(
      id: Value(id),
      model: Value(model),
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
      costUsd: Value(costUsd),
      source: Value(source),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      metadata: Value(metadata),
      createdAt: Value(createdAt),
    );
  }

  factory UsageRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageRecord(
      id: serializer.fromJson<String>(json['id']),
      model: serializer.fromJson<String>(json['model']),
      inputTokens: serializer.fromJson<int>(json['inputTokens']),
      outputTokens: serializer.fromJson<int>(json['outputTokens']),
      costUsd: serializer.fromJson<double>(json['costUsd']),
      source: serializer.fromJson<String>(json['source']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      metadata: serializer.fromJson<String>(json['metadata']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'model': serializer.toJson<String>(model),
      'inputTokens': serializer.toJson<int>(inputTokens),
      'outputTokens': serializer.toJson<int>(outputTokens),
      'costUsd': serializer.toJson<double>(costUsd),
      'source': serializer.toJson<String>(source),
      'sessionId': serializer.toJson<String?>(sessionId),
      'metadata': serializer.toJson<String>(metadata),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  UsageRecord copyWith({
    String? id,
    String? model,
    int? inputTokens,
    int? outputTokens,
    double? costUsd,
    String? source,
    Value<String?> sessionId = const Value.absent(),
    String? metadata,
    DateTime? createdAt,
  }) => UsageRecord(
    id: id ?? this.id,
    model: model ?? this.model,
    inputTokens: inputTokens ?? this.inputTokens,
    outputTokens: outputTokens ?? this.outputTokens,
    costUsd: costUsd ?? this.costUsd,
    source: source ?? this.source,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    metadata: metadata ?? this.metadata,
    createdAt: createdAt ?? this.createdAt,
  );
  UsageRecord copyWithCompanion(UsageRecordsCompanion data) {
    return UsageRecord(
      id: data.id.present ? data.id.value : this.id,
      model: data.model.present ? data.model.value : this.model,
      inputTokens: data.inputTokens.present
          ? data.inputTokens.value
          : this.inputTokens,
      outputTokens: data.outputTokens.present
          ? data.outputTokens.value
          : this.outputTokens,
      costUsd: data.costUsd.present ? data.costUsd.value : this.costUsd,
      source: data.source.present ? data.source.value : this.source,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageRecord(')
          ..write('id: $id, ')
          ..write('model: $model, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('costUsd: $costUsd, ')
          ..write('source: $source, ')
          ..write('sessionId: $sessionId, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    model,
    inputTokens,
    outputTokens,
    costUsd,
    source,
    sessionId,
    metadata,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageRecord &&
          other.id == this.id &&
          other.model == this.model &&
          other.inputTokens == this.inputTokens &&
          other.outputTokens == this.outputTokens &&
          other.costUsd == this.costUsd &&
          other.source == this.source &&
          other.sessionId == this.sessionId &&
          other.metadata == this.metadata &&
          other.createdAt == this.createdAt);
}

class UsageRecordsCompanion extends UpdateCompanion<UsageRecord> {
  final Value<String> id;
  final Value<String> model;
  final Value<int> inputTokens;
  final Value<int> outputTokens;
  final Value<double> costUsd;
  final Value<String> source;
  final Value<String?> sessionId;
  final Value<String> metadata;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const UsageRecordsCompanion({
    this.id = const Value.absent(),
    this.model = const Value.absent(),
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.costUsd = const Value.absent(),
    this.source = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.metadata = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsageRecordsCompanion.insert({
    required String id,
    required String model,
    required int inputTokens,
    required int outputTokens,
    required double costUsd,
    required String source,
    this.sessionId = const Value.absent(),
    this.metadata = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       model = Value(model),
       inputTokens = Value(inputTokens),
       outputTokens = Value(outputTokens),
       costUsd = Value(costUsd),
       source = Value(source),
       createdAt = Value(createdAt);
  static Insertable<UsageRecord> custom({
    Expression<String>? id,
    Expression<String>? model,
    Expression<int>? inputTokens,
    Expression<int>? outputTokens,
    Expression<double>? costUsd,
    Expression<String>? source,
    Expression<String>? sessionId,
    Expression<String>? metadata,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (model != null) 'model': model,
      if (inputTokens != null) 'input_tokens': inputTokens,
      if (outputTokens != null) 'output_tokens': outputTokens,
      if (costUsd != null) 'cost_usd': costUsd,
      if (source != null) 'source': source,
      if (sessionId != null) 'session_id': sessionId,
      if (metadata != null) 'metadata': metadata,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsageRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? model,
    Value<int>? inputTokens,
    Value<int>? outputTokens,
    Value<double>? costUsd,
    Value<String>? source,
    Value<String?>? sessionId,
    Value<String>? metadata,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return UsageRecordsCompanion(
      id: id ?? this.id,
      model: model ?? this.model,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      costUsd: costUsd ?? this.costUsd,
      source: source ?? this.source,
      sessionId: sessionId ?? this.sessionId,
      metadata: metadata ?? this.metadata,
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
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (inputTokens.present) {
      map['input_tokens'] = Variable<int>(inputTokens.value);
    }
    if (outputTokens.present) {
      map['output_tokens'] = Variable<int>(outputTokens.value);
    }
    if (costUsd.present) {
      map['cost_usd'] = Variable<double>(costUsd.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
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
    return (StringBuffer('UsageRecordsCompanion(')
          ..write('id: $id, ')
          ..write('model: $model, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('costUsd: $costUsd, ')
          ..write('source: $source, ')
          ..write('sessionId: $sessionId, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputTokensMeta = const VerificationMeta(
    'inputTokens',
  );
  @override
  late final GeneratedColumn<int> inputTokens = GeneratedColumn<int>(
    'input_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outputTokensMeta = const VerificationMeta(
    'outputTokens',
  );
  @override
  late final GeneratedColumn<int> outputTokens = GeneratedColumn<int>(
    'output_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costUsdMeta = const VerificationMeta(
    'costUsd',
  );
  @override
  late final GeneratedColumn<double> costUsd = GeneratedColumn<double>(
    'cost_usd',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _interruptedMeta = const VerificationMeta(
    'interrupted',
  );
  @override
  late final GeneratedColumn<bool> interrupted = GeneratedColumn<bool>(
    'interrupted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("interrupted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    role,
    content,
    inputTokens,
    outputTokens,
    costUsd,
    model,
    interrupted,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('input_tokens')) {
      context.handle(
        _inputTokensMeta,
        inputTokens.isAcceptableOrUnknown(
          data['input_tokens']!,
          _inputTokensMeta,
        ),
      );
    }
    if (data.containsKey('output_tokens')) {
      context.handle(
        _outputTokensMeta,
        outputTokens.isAcceptableOrUnknown(
          data['output_tokens']!,
          _outputTokensMeta,
        ),
      );
    }
    if (data.containsKey('cost_usd')) {
      context.handle(
        _costUsdMeta,
        costUsd.isAcceptableOrUnknown(data['cost_usd']!, _costUsdMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('interrupted')) {
      context.handle(
        _interruptedMeta,
        interrupted.isAcceptableOrUnknown(
          data['interrupted']!,
          _interruptedMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      inputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_tokens'],
      ),
      outputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_tokens'],
      ),
      costUsd: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost_usd'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      interrupted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}interrupted'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }
}

class ChatMessage extends DataClass implements Insertable<ChatMessage> {
  final String id;
  final String sessionId;
  final String role;
  final String content;
  final int? inputTokens;
  final int? outputTokens;
  final double? costUsd;
  final String? model;
  final bool interrupted;
  final DateTime createdAt;
  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.inputTokens,
    this.outputTokens,
    this.costUsd,
    this.model,
    required this.interrupted,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || inputTokens != null) {
      map['input_tokens'] = Variable<int>(inputTokens);
    }
    if (!nullToAbsent || outputTokens != null) {
      map['output_tokens'] = Variable<int>(outputTokens);
    }
    if (!nullToAbsent || costUsd != null) {
      map['cost_usd'] = Variable<double>(costUsd);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    map['interrupted'] = Variable<bool>(interrupted);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      role: Value(role),
      content: Value(content),
      inputTokens: inputTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(inputTokens),
      outputTokens: outputTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(outputTokens),
      costUsd: costUsd == null && nullToAbsent
          ? const Value.absent()
          : Value(costUsd),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      interrupted: Value(interrupted),
      createdAt: Value(createdAt),
    );
  }

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessage(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      inputTokens: serializer.fromJson<int?>(json['inputTokens']),
      outputTokens: serializer.fromJson<int?>(json['outputTokens']),
      costUsd: serializer.fromJson<double?>(json['costUsd']),
      model: serializer.fromJson<String?>(json['model']),
      interrupted: serializer.fromJson<bool>(json['interrupted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'inputTokens': serializer.toJson<int?>(inputTokens),
      'outputTokens': serializer.toJson<int?>(outputTokens),
      'costUsd': serializer.toJson<double?>(costUsd),
      'model': serializer.toJson<String?>(model),
      'interrupted': serializer.toJson<bool>(interrupted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? sessionId,
    String? role,
    String? content,
    Value<int?> inputTokens = const Value.absent(),
    Value<int?> outputTokens = const Value.absent(),
    Value<double?> costUsd = const Value.absent(),
    Value<String?> model = const Value.absent(),
    bool? interrupted,
    DateTime? createdAt,
  }) => ChatMessage(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    role: role ?? this.role,
    content: content ?? this.content,
    inputTokens: inputTokens.present ? inputTokens.value : this.inputTokens,
    outputTokens: outputTokens.present ? outputTokens.value : this.outputTokens,
    costUsd: costUsd.present ? costUsd.value : this.costUsd,
    model: model.present ? model.value : this.model,
    interrupted: interrupted ?? this.interrupted,
    createdAt: createdAt ?? this.createdAt,
  );
  ChatMessage copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessage(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      inputTokens: data.inputTokens.present
          ? data.inputTokens.value
          : this.inputTokens,
      outputTokens: data.outputTokens.present
          ? data.outputTokens.value
          : this.outputTokens,
      costUsd: data.costUsd.present ? data.costUsd.value : this.costUsd,
      model: data.model.present ? data.model.value : this.model,
      interrupted: data.interrupted.present
          ? data.interrupted.value
          : this.interrupted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessage(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('costUsd: $costUsd, ')
          ..write('model: $model, ')
          ..write('interrupted: $interrupted, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    role,
    content,
    inputTokens,
    outputTokens,
    costUsd,
    model,
    interrupted,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessage &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.role == this.role &&
          other.content == this.content &&
          other.inputTokens == this.inputTokens &&
          other.outputTokens == this.outputTokens &&
          other.costUsd == this.costUsd &&
          other.model == this.model &&
          other.interrupted == this.interrupted &&
          other.createdAt == this.createdAt);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessage> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> role;
  final Value<String> content;
  final Value<int?> inputTokens;
  final Value<int?> outputTokens;
  final Value<double?> costUsd;
  final Value<String?> model;
  final Value<bool> interrupted;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ChatMessagesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.costUsd = const Value.absent(),
    this.model = const Value.absent(),
    this.interrupted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    required String id,
    required String sessionId,
    required String role,
    required String content,
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.costUsd = const Value.absent(),
    this.model = const Value.absent(),
    this.interrupted = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       role = Value(role),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<ChatMessage> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<int>? inputTokens,
    Expression<int>? outputTokens,
    Expression<double>? costUsd,
    Expression<String>? model,
    Expression<bool>? interrupted,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (inputTokens != null) 'input_tokens': inputTokens,
      if (outputTokens != null) 'output_tokens': outputTokens,
      if (costUsd != null) 'cost_usd': costUsd,
      if (model != null) 'model': model,
      if (interrupted != null) 'interrupted': interrupted,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? role,
    Value<String>? content,
    Value<int?>? inputTokens,
    Value<int?>? outputTokens,
    Value<double?>? costUsd,
    Value<String?>? model,
    Value<bool>? interrupted,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ChatMessagesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      costUsd: costUsd ?? this.costUsd,
      model: model ?? this.model,
      interrupted: interrupted ?? this.interrupted,
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
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (inputTokens.present) {
      map['input_tokens'] = Variable<int>(inputTokens.value);
    }
    if (outputTokens.present) {
      map['output_tokens'] = Variable<int>(outputTokens.value);
    }
    if (costUsd.present) {
      map['cost_usd'] = Variable<double>(costUsd.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (interrupted.present) {
      map['interrupted'] = Variable<bool>(interrupted.value);
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
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('costUsd: $costUsd, ')
          ..write('model: $model, ')
          ..write('interrupted: $interrupted, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsageRecordsTable usageRecords = $UsageRecordsTable(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    usageRecords,
    chatMessages,
  ];
}

typedef $$UsageRecordsTableCreateCompanionBuilder =
    UsageRecordsCompanion Function({
      required String id,
      required String model,
      required int inputTokens,
      required int outputTokens,
      required double costUsd,
      required String source,
      Value<String?> sessionId,
      Value<String> metadata,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$UsageRecordsTableUpdateCompanionBuilder =
    UsageRecordsCompanion Function({
      Value<String> id,
      Value<String> model,
      Value<int> inputTokens,
      Value<int> outputTokens,
      Value<double> costUsd,
      Value<String> source,
      Value<String?> sessionId,
      Value<String> metadata,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$UsageRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $UsageRecordsTable> {
  $$UsageRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get costUsd => $composableBuilder(
    column: $table.costUsd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsageRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $UsageRecordsTable> {
  $$UsageRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get costUsd => $composableBuilder(
    column: $table.costUsd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsageRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsageRecordsTable> {
  $$UsageRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<double> get costUsd =>
      $composableBuilder(column: $table.costUsd, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UsageRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsageRecordsTable,
          UsageRecord,
          $$UsageRecordsTableFilterComposer,
          $$UsageRecordsTableOrderingComposer,
          $$UsageRecordsTableAnnotationComposer,
          $$UsageRecordsTableCreateCompanionBuilder,
          $$UsageRecordsTableUpdateCompanionBuilder,
          (
            UsageRecord,
            BaseReferences<_$AppDatabase, $UsageRecordsTable, UsageRecord>,
          ),
          UsageRecord,
          PrefetchHooks Function()
        > {
  $$UsageRecordsTableTableManager(_$AppDatabase db, $UsageRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsageRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsageRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int> inputTokens = const Value.absent(),
                Value<int> outputTokens = const Value.absent(),
                Value<double> costUsd = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsageRecordsCompanion(
                id: id,
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                costUsd: costUsd,
                source: source,
                sessionId: sessionId,
                metadata: metadata,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String model,
                required int inputTokens,
                required int outputTokens,
                required double costUsd,
                required String source,
                Value<String?> sessionId = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => UsageRecordsCompanion.insert(
                id: id,
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                costUsd: costUsd,
                source: source,
                sessionId: sessionId,
                metadata: metadata,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsageRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsageRecordsTable,
      UsageRecord,
      $$UsageRecordsTableFilterComposer,
      $$UsageRecordsTableOrderingComposer,
      $$UsageRecordsTableAnnotationComposer,
      $$UsageRecordsTableCreateCompanionBuilder,
      $$UsageRecordsTableUpdateCompanionBuilder,
      (
        UsageRecord,
        BaseReferences<_$AppDatabase, $UsageRecordsTable, UsageRecord>,
      ),
      UsageRecord,
      PrefetchHooks Function()
    >;
typedef $$ChatMessagesTableCreateCompanionBuilder =
    ChatMessagesCompanion Function({
      required String id,
      required String sessionId,
      required String role,
      required String content,
      Value<int?> inputTokens,
      Value<int?> outputTokens,
      Value<double?> costUsd,
      Value<String?> model,
      Value<bool> interrupted,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ChatMessagesTableUpdateCompanionBuilder =
    ChatMessagesCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> role,
      Value<String> content,
      Value<int?> inputTokens,
      Value<int?> outputTokens,
      Value<double?> costUsd,
      Value<String?> model,
      Value<bool> interrupted,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ChatMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get costUsd => $composableBuilder(
    column: $table.costUsd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get interrupted => $composableBuilder(
    column: $table.interrupted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get costUsd => $composableBuilder(
    column: $table.costUsd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get interrupted => $composableBuilder(
    column: $table.interrupted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<double> get costUsd =>
      $composableBuilder(column: $table.costUsd, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<bool> get interrupted => $composableBuilder(
    column: $table.interrupted,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ChatMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatMessagesTable,
          ChatMessage,
          $$ChatMessagesTableFilterComposer,
          $$ChatMessagesTableOrderingComposer,
          $$ChatMessagesTableAnnotationComposer,
          $$ChatMessagesTableCreateCompanionBuilder,
          $$ChatMessagesTableUpdateCompanionBuilder,
          (
            ChatMessage,
            BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>,
          ),
          ChatMessage,
          PrefetchHooks Function()
        > {
  $$ChatMessagesTableTableManager(_$AppDatabase db, $ChatMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int?> inputTokens = const Value.absent(),
                Value<int?> outputTokens = const Value.absent(),
                Value<double?> costUsd = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<bool> interrupted = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion(
                id: id,
                sessionId: sessionId,
                role: role,
                content: content,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                costUsd: costUsd,
                model: model,
                interrupted: interrupted,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String role,
                required String content,
                Value<int?> inputTokens = const Value.absent(),
                Value<int?> outputTokens = const Value.absent(),
                Value<double?> costUsd = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<bool> interrupted = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion.insert(
                id: id,
                sessionId: sessionId,
                role: role,
                content: content,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                costUsd: costUsd,
                model: model,
                interrupted: interrupted,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatMessagesTable,
      ChatMessage,
      $$ChatMessagesTableFilterComposer,
      $$ChatMessagesTableOrderingComposer,
      $$ChatMessagesTableAnnotationComposer,
      $$ChatMessagesTableCreateCompanionBuilder,
      $$ChatMessagesTableUpdateCompanionBuilder,
      (
        ChatMessage,
        BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>,
      ),
      ChatMessage,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsageRecordsTableTableManager get usageRecords =>
      $$UsageRecordsTableTableManager(_db, _db.usageRecords);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
}
