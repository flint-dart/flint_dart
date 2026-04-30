import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/database/db.dart';
import 'package:flint_dart/src/env_parser.dart';

List<_RegisteredTableDefinition> _registeredTables = [];

class DBMigrateCommand extends FlintCommand {
  DBMigrateCommand() : super('migrate', 'Runs database migrations');

  @override
  Future<void> execute(List<String> args) async {
    final drop = args.contains('--drop');
    final force = args.contains('--force');

    Log.debug(drop
        ? '🔁 Refreshing database (dropping migrations)...'
        : '🚀 Starting database migration...');

    if (drop) {
      await _dropAllTables();
      Log.debug('🧹 All existing tables dropped.');
      return;
    }

    try {
      await _runTableRegistry();
      await DB.autoConnect();

      if (_registeredTables.isEmpty) {
        Log.debug(
            '❗️ No tables were registered. Please call registerTables().');
        return;
      }

      Log.debug('Found ${_registeredTables.length} tables. Migrating...');

      for (final registeredTable in _registeredTables) {
        var sql = registeredTable.createSql;
        String? currentTableName;
        try {
          final tableName = registeredTable.tableName.isNotEmpty
              ? registeredTable.tableName
              : _extractTableName(sql);
          if (tableName == null) {
            Log.debug(
                '⚠️ Skipping SQL statement (could not extract table name): ${sql.substring(0, 50)}...');
            continue;
          }
          currentTableName = tableName;

          Log.debug('   🔹 Processing table: $tableName');

          // --- Inject default columns ---
          sql = _injectDefaultColumns(sql, tableName);

          // --- Normalize SQL for current driver ---
          sql = _normalizeSqlForCurrentDriver(sql);

          // --- Check if table exists ---
          final exists = await _safeTableExists(tableName);

          if (exists) {
            if (force) {
              Log.debug('   ♻️ Force recreating table: $tableName');
              await _safeDropTable(tableName);
              await DB.execute(sql);
            } else {
              await _alterTableAddMissingColumns(
                tableName,
                sql,
                registeredTable.indexes,
                registeredTable.columns,
              );
            }
          } else {
            await DB.execute(sql);
          }

          await _syncColumnComments(tableName, registeredTable.columns);

          // --- Create trigger for PostgreSQL updated_at ---
          if (DB.driver == DBDriver.postgres) {
            await _safeCreateUpdatedAtTriggerForPostgres(tableName);
          }

          // --- Ensure timestamps ---
          await ensureTimestampsOnExistingTable(tableName);

          await _syncDeclaredIndexes(
            tableName,
            _extractColumnsFromCreateSql(sql),
            registeredTable.indexes,
          );
          Log.debug('   ✅ Table "$tableName" migrated successfully.');
        } catch (e, st) {
          final failedTable = currentTableName ?? 'unknown';
          Log.debug('   ❌ Failed to migrate table "$failedTable".');
          if (args.contains('--verbose')) {
            Log.debug("❌ Failed to migrate table:", error: e, stackTrace: st);
          }
          rethrow;
        }
      }

      Log.debug('✅ Migration completed successfully.');
    } catch (e, st) {
      Log.debug('❌ Migration failed: $e');
      if (args.contains('--verbose')) {
        Log.debug("❌ Migration failed:", error: e, stackTrace: st);
      }
      rethrow;
    } finally {
      await DB.close();
    }
  }

  Future<void> _runTableRegistry() async {
    final appRoot = Directory.current.path;
    final registryPath = '$appRoot/lib/config/table_registry.dart';
    final registryFile = File(registryPath);

    if (!await registryFile.exists()) {
      Log.debug('⚠️ Could not find table_registry.dart at $registryPath');
      _registeredTables = [];
      return;
    }

    final receivePort = ReceivePort();

    try {
      await Isolate.spawnUri(
        registryFile.uri,
        [],
        receivePort.sendPort,
        packageConfig: Uri.file('$appRoot/.dart_tool/package_config.json'),
      );

      final payload = await receivePort.first as List<dynamic>;
      _registeredTables = _parseRegisteredTables(payload);
      Log.debug(
          'Loaded ${_registeredTables.length} table definitions from registry.');
    } catch (e) {
      Log.debug('⚠️ Failed to load table registry: ', error: e);
      _registeredTables = [];
    } finally {
      receivePort.close();
    }
  }
}

List<_RegisteredTableDefinition> _parseRegisteredTables(List<dynamic> payload) {
  return payload.map(_RegisteredTableDefinition.fromPayload).toList();
}

/// --- Safe table existence check ---
Future<bool> _safeTableExists(String tableName) async {
  try {
    if (DB.driver == DBDriver.mysql) {
      final result = await DB.query(
          "SELECT COUNT(*) as count FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?",
          positionalParams: [tableName]);
      final count = result.first['count'];
      return (count is int ? count : int.parse(count.toString())) > 0;
    } else if (DB.driver == DBDriver.postgres) {
      final result = await DB.query(
          "SELECT COUNT(*) as count FROM pg_tables WHERE schemaname = 'public' AND tablename = ?",
          positionalParams: [tableName]);
      final count = result.first['count'];
      return (count is int ? count : int.parse(count.toString())) > 0;
    }
    return false;
  } catch (e) {
    Log.debug('⚠️ Error checking if table exists ($tableName): $e');
    return false;
  }
}

/// --- Safe table drop ---
Future<void> _safeDropTable(String tableName) async {
  try {
    if (DB.driver == DBDriver.mysql) {
      await DB.execute('DROP TABLE IF EXISTS `$tableName`');
    } else if (DB.driver == DBDriver.postgres) {
      await DB.execute('DROP TABLE IF EXISTS "$tableName" CASCADE');
    }
  } catch (e) {
    Log.debug('⚠️ Error dropping table $tableName: $e');
  }
}

/// --- Drop all tables ---
Future<void> _dropAllTables() async {
  Log.debug('🗑️ Dropping all tables...');
  try {
    await DB.autoConnect();

    if (DB.driver == DBDriver.mysql) {
      final tables = await DB.query('SHOW TABLES');
      for (final row in tables) {
        final tableName = row.values.first;
        Log.debug('   🔹 Dropping `$tableName`...');
        await DB.execute('DROP TABLE IF EXISTS `$tableName`;');
      }
    } else if (DB.driver == DBDriver.postgres) {
      final tables = await DB.query(
          "SELECT tablename FROM pg_tables WHERE schemaname = 'public';");
      await DB.execute('SET session_replication_role = replica;');
      for (final row in tables) {
        final tableName = row['tablename'];
        Log.info('   🔹 Dropping "$tableName"...');
        await DB.execute('DROP TABLE IF EXISTS "$tableName" CASCADE;');
      }
      await DB.execute('SET session_replication_role = DEFAULT;');
    }

    Log.info('✅ All tables dropped successfully.');
  } catch (e, st) {
    Log.debug("❌ Failed to drop tables: ", error: e, stackTrace: st);
  } finally {
    await DB.close();
  }
}

/// --- Inject default columns into CREATE TABLE SQL ---
String _injectDefaultColumns(String sql, String tableName) {
  if (!sql.trim().toUpperCase().startsWith('CREATE TABLE')) return sql;

  final insertIndex = sql.lastIndexOf(')');
  if (insertIndex == -1) return sql;

  final authTable = FlintEnv.get('AUTH_TABLE', "users");
  final providerCol = FlintEnv.get('AUTH_PROVIDER_COLUMN', "provider");
  final providerIdCol = FlintEnv.get('AUTH_PROVIDER_ID_COLUMN', "provider_id");
  final isAuthTable = tableName.toLowerCase() == authTable.toLowerCase();
  final isPostgres = DB.driver == DBDriver.postgres;
  final q = isPostgres ? '"' : '`';

  final hasCreatedAt = sql.toLowerCase().contains('created_at');
  final hasUpdatedAt = sql.toLowerCase().contains('updated_at');
  final hasProvider = sql.toLowerCase().contains(providerCol.toLowerCase());
  final hasProviderId = sql.toLowerCase().contains(providerIdCol.toLowerCase());

  final additions = <String>[];

  // Auth fields
  if (isAuthTable) {
    if (!hasProvider) additions.add('$q$providerCol$q VARCHAR(100)');
    if (!hasProviderId) additions.add('$q$providerIdCol$q VARCHAR(255)');
  }

  // Timestamps
  if (!hasCreatedAt) {
    additions.add(isPostgres
        ? '${q}created_at$q TIMESTAMP DEFAULT CURRENT_TIMESTAMP'
        : '${q}created_at$q DATETIME DEFAULT CURRENT_TIMESTAMP');
  }
  if (!hasUpdatedAt) {
    additions.add(isPostgres
        ? '${q}updated_at$q TIMESTAMP DEFAULT CURRENT_TIMESTAMP'
        : '${q}updated_at$q DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');
  }

  if (additions.isEmpty) return sql;

  final additionSql = ',\n  ${additions.join(',\n  ')}';
  return sql.substring(0, insertIndex) +
      additionSql +
      sql.substring(insertIndex);
}

/// --- Sync table schema for existing tables (add/remove/alter columns) ---
Future<void> _alterTableAddMissingColumns(
  String tableName,
  String sql,
  List<_RegisteredIndexDefinition> declaredIndexes,
  List<_RegisteredColumnDefinition> columnDirectives,
) async {
  final desiredColumns = _extractColumnsFromCreateSql(sql);
  if (desiredColumns.isEmpty) return;

  final existingColumns = await _loadExistingColumnSchemas(tableName);
  final protectedColumns = _protectedColumnsForTable(tableName);
  final q = DB.driver == DBDriver.postgres ? '"' : '`';

  for (final desired in desiredColumns) {
    if (existingColumns.containsKey(desired.name)) continue;

    final renamedFrom = _renamedFromForColumn(desired, columnDirectives);
    if (renamedFrom == null || !existingColumns.containsKey(renamedFrom)) {
      continue;
    }

    final renameSql = _buildRenameColumnSql(
      tableName: tableName,
      from: renamedFrom,
      to: desired.name,
    );
    await _executeMigrationSql(
      tableName: tableName,
      operation: 'rename column `$renamedFrom` to `${desired.name}`',
      sql: renameSql,
      hint:
          'Verify both column names are correct, then rerun `flint db migrate`.',
    );
    final existing = existingColumns.remove(renamedFrom)!;
    existingColumns[desired.name] = existing.copyWith(name: desired.name);
    Log.info('   ~ Renamed column `$renamedFrom` to `${desired.name}`');
  }

  for (var i = 0; i < desiredColumns.length; i++) {
    final desired = desiredColumns[i];
    if (existingColumns.containsKey(desired.name)) continue;
    final caseConflict = _findCaseOnlyColumnName(
      desired.name,
      existingColumns.keys,
    );
    if (caseConflict != null) {
      throw StateError(
        'Migration detected a possible column rename on table "$tableName": '
        '`$caseConflict` -> `${desired.name}`.\n'
        'This looks like a case-only rename. Use '
        'Column(name: \'${desired.name}\', ..., renamedFrom: \'$caseConflict\') '
        'to preserve existing data, or make the new column nullable/provide a '
        'default if you really want a new column.',
      );
    }
    final afterClause = _buildAddColumnAfterClause(
      desiredColumns,
      i,
      columnDirectives,
      existingColumns.keys.toSet(),
    );
    final addSql =
        'ALTER TABLE $q$tableName$q ADD COLUMN $q${desired.name}$q ${desired.definition}$afterClause';
    await _executeMigrationSql(
      tableName: tableName,
      operation: 'add column `${desired.name}`',
      sql: addSql,
      hint:
          'Verify type/default syntax for ${DB.driver.name}, then rerun `flint db migrate`.',
    );
    Log.info('   + Added column `${desired.name}` to $tableName');
    existingColumns[desired.name] = _ExistingColumnSchema(
      name: desired.name,
      typeName: desired.typeName,
      nullable: desired.nullable,
      defaultValue: desired.defaultValue,
      updatesCurrentTimestamp: desired.updatesCurrentTimestamp,
      comment: _desiredColumnComment(desired, columnDirectives),
    );
  }

  for (final desired in desiredColumns) {
    final existing = existingColumns[desired.name];
    if (existing == null) continue;
    if (!_needsAlter(existing, desired)) continue;
    final statements = _buildAlterColumnStatements(
      tableName: tableName,
      existing: existing,
      desired: desired,
    );
    for (final statement in statements) {
      await _executeMigrationSql(
        tableName: tableName,
        operation: 'alter column `${desired.name}`',
        sql: statement,
        hint:
            'Existing rows may violate the new type/null/default constraints. Fix data and rerun migration.',
      );
    }
    if (statements.isNotEmpty) {
      Log.info('   ~ Updated column `${desired.name}` on $tableName');
    }

    final desiredComment = _desiredColumnComment(desired, columnDirectives);
    if (_normalizeColumnComment(existing.comment) !=
        _normalizeColumnComment(desiredComment)) {
      final commentSql = _buildColumnCommentSql(
        tableName: tableName,
        desired: desired,
        comment: desiredComment,
      );
      if (commentSql != null) {
        await _executeMigrationSql(
          tableName: tableName,
          operation: 'comment column `${desired.name}`',
          sql: commentSql,
          hint: 'Verify column comment syntax for ${DB.driver.name}.',
        );
        Log.info('   ~ Updated comment for `${desired.name}` on $tableName');
      }
    }
  }

  for (final existingName in existingColumns.keys) {
    final existsInDesired =
        desiredColumns.any((column) => column.name == existingName);
    if (existsInDesired || protectedColumns.contains(existingName)) continue;
    final dropSql = 'ALTER TABLE $q$tableName$q DROP COLUMN $q$existingName$q';
    await _executeMigrationSql(
      tableName: tableName,
      operation: 'drop column `$existingName`',
      sql: dropSql,
      hint:
          'If this column should remain, re-add it to your table schema class before rerunning migration.',
    );
    Log.info('   - Dropped column `$existingName` from $tableName');
  }

  await _syncDeclaredIndexes(tableName, desiredColumns, declaredIndexes);
}

Set<String> _protectedColumnsForTable(String tableName) {
  final protected = <String>{'created_at', 'updated_at'};
  final authTable = FlintEnv.get('AUTH_TABLE', 'users');
  if (tableName == authTable) {
    protected.addAll({
      FlintEnv.get('AUTH_PROVIDER_COLUMN', 'provider'),
      FlintEnv.get('AUTH_PROVIDER_ID_COLUMN', 'provider_id'),
      'email_verified_at',
      'is_verified',
    });
  }
  return protected;
}

Future<void> _executeMigrationSql({
  required String tableName,
  required String operation,
  required String sql,
  required String hint,
}) async {
  try {
    await DB.execute(sql);
  } catch (e) {
    throw StateError(
      'Migration failed for table "$tableName" during $operation.\n'
      'SQL: $sql\n'
      'Cause: $e\n'
      'How to fix: $hint',
    );
  }
}

bool _needsAlter(_ExistingColumnSchema existing, _SqlColumnDefinition desired) {
  final sameType = _normalizeTypeName(existing.typeName) ==
      _normalizeTypeName(desired.typeName);
  final sameNullable = existing.nullable == desired.nullable;
  final sameDefault = _normalizeDefaultValue(existing.defaultValue) ==
      _normalizeDefaultValue(desired.defaultValue);
  final sameUpdateBehavior =
      existing.updatesCurrentTimestamp == desired.updatesCurrentTimestamp;
  return !(sameType && sameNullable && sameDefault && sameUpdateBehavior);
}

List<String> _buildAlterColumnStatements({
  required String tableName,
  required _ExistingColumnSchema existing,
  required _SqlColumnDefinition desired,
}) {
  if (DB.driver == DBDriver.mysql) {
    final normalizedExistingType = _normalizeTypeName(existing.typeName);
    final normalizedDesiredType = _normalizeTypeName(desired.typeName);
    final currentDefault = _normalizeDefaultValue(existing.defaultValue);
    final desiredDefault = _normalizeDefaultValue(desired.defaultValue);
    final sameUpdateBehavior =
        existing.updatesCurrentTimestamp == desired.updatesCurrentTimestamp;

    final needsBaseDefinitionChange =
        normalizedExistingType != normalizedDesiredType ||
            existing.nullable != desired.nullable ||
            currentDefault != desiredDefault ||
            !sameUpdateBehavior;
    if (!needsBaseDefinitionChange) {
      return const [];
    }

    final safeDefinition = _stripInlineKeyConstraints(desired.definition);
    return [
      'ALTER TABLE `$tableName` MODIFY COLUMN `${desired.name}` $safeDefinition'
    ];
  }

  final statements = <String>[];
  final normalizedExistingType = _normalizeTypeName(existing.typeName);
  final normalizedDesiredType = _normalizeTypeName(desired.typeName);

  if (normalizedExistingType != normalizedDesiredType) {
    statements.add(
      'ALTER TABLE "$tableName" ALTER COLUMN "${desired.name}" TYPE ${desired.typeName}',
    );
  }

  if (existing.nullable != desired.nullable) {
    statements.add(
      desired.nullable
          ? 'ALTER TABLE "$tableName" ALTER COLUMN "${desired.name}" DROP NOT NULL'
          : 'ALTER TABLE "$tableName" ALTER COLUMN "${desired.name}" SET NOT NULL',
    );
  }

  final currentDefault = _normalizeDefaultValue(existing.defaultValue);
  final desiredDefault = _normalizeDefaultValue(desired.defaultValue);
  if (currentDefault != desiredDefault) {
    if (desired.defaultValue == null) {
      statements.add(
        'ALTER TABLE "$tableName" ALTER COLUMN "${desired.name}" DROP DEFAULT',
      );
    } else {
      statements.add(
        'ALTER TABLE "$tableName" ALTER COLUMN "${desired.name}" SET DEFAULT ${desired.defaultValue}',
      );
    }
  }

  return statements;
}

Future<Map<String, _ExistingColumnSchema>> _loadExistingColumnSchemas(
  String tableName,
) async {
  final map = <String, _ExistingColumnSchema>{};

  if (DB.driver == DBDriver.mysql) {
    final rows = await DB.query(
      '''
SELECT COLUMN_NAME as column_name, COLUMN_TYPE as column_type, IS_NULLABLE as is_nullable, COLUMN_DEFAULT as column_default, EXTRA as column_extra, COLUMN_COMMENT as column_comment
FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = ?
''',
      positionalParams: [tableName],
    );

    for (final row in rows) {
      final name = _databaseTextValue(row['column_name']);
      if (name == null) continue;
      map[name] = _ExistingColumnSchema(
        name: name,
        typeName: _databaseTextValue(row['column_type']) ?? '',
        nullable:
            (_databaseTextValue(row['is_nullable']) ?? '').toUpperCase() ==
                'YES',
        defaultValue: _databaseTextValue(row['column_default']),
        updatesCurrentTimestamp: (_databaseTextValue(row['column_extra']) ?? '')
            .toLowerCase()
            .contains('on update current_timestamp'),
        comment: _databaseTextValue(row['column_comment']),
      );
    }
    return map;
  }

  if (DB.driver == DBDriver.postgres) {
    final rows = await DB.query(
      '''
SELECT c.column_name, c.data_type, c.udt_name, c.is_nullable, c.column_default,
       pg_catalog.col_description(format('%I.%I', c.table_schema, c.table_name)::regclass::oid, c.ordinal_position) AS column_comment
FROM information_schema.columns c
WHERE c.table_schema = 'public' AND c.table_name = ?
''',
      positionalParams: [tableName],
    );

    for (final row in rows) {
      final name = _databaseTextValue(row['column_name']);
      if (name == null) continue;
      final type =
          _databaseTextValue(row['udt_name'] ?? row['data_type']) ?? '';
      map[name] = _ExistingColumnSchema(
        name: name,
        typeName: type,
        nullable:
            (_databaseTextValue(row['is_nullable']) ?? '').toUpperCase() ==
                'YES',
        defaultValue: _databaseTextValue(row['column_default']),
        updatesCurrentTimestamp: false,
        comment: _databaseTextValue(row['column_comment']),
      );
    }
  }

  return map;
}

List<_SqlColumnDefinition> _extractColumnsFromCreateSql(String sql) {
  final createTableMatch = RegExp(
    r'CREATE\s+TABLE\s+[^\(]+\((.*)\)',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(sql);
  if (createTableMatch == null) return const [];

  final columnsSection = createTableMatch.group(1)!;
  final parts = _splitTopLevelCsv(columnsSection);
  final columns = <_SqlColumnDefinition>[];

  for (final rawPart in parts) {
    final part = rawPart.trim();
    if (part.isEmpty || _isTableConstraintLine(part)) continue;

    final nameMatch = RegExp(
      r'^\s*["`]?([A-Za-z_]\w*)["`]?\s+(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(part);
    if (nameMatch == null) continue;

    final name = nameMatch.group(1)!;
    final definition = nameMatch.group(2)!.trim();
    final typeName = _extractTypeName(definition);
    final defaultValue = _extractDefaultExpression(definition);
    final comment = _extractCommentExpression(definition);
    final nullable =
        !RegExp(r'\bNOT\s+NULL\b', caseSensitive: false).hasMatch(definition);
    final isUnique =
        RegExp(r'\bUNIQUE\b', caseSensitive: false).hasMatch(definition);
    final isPrimaryKey =
        RegExp(r'\bPRIMARY\s+KEY\b', caseSensitive: false).hasMatch(definition);
    final updatesCurrentTimestamp = RegExp(
      r'\bON\s+UPDATE\s+CURRENT_TIMESTAMP\b',
      caseSensitive: false,
    ).hasMatch(definition);

    columns.add(
      _SqlColumnDefinition(
        name: name,
        definition: definition,
        typeName: typeName,
        nullable: nullable,
        defaultValue: defaultValue,
        comment: comment,
        isUnique: isUnique,
        isPrimaryKey: isPrimaryKey,
        updatesCurrentTimestamp: updatesCurrentTimestamp,
      ),
    );
  }

  return columns;
}

List<String> _splitTopLevelCsv(String input) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;

  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    if (ch == '(') depth++;
    if (ch == ')') depth = depth > 0 ? depth - 1 : 0;
    if (ch == ',' && depth == 0) {
      parts.add(input.substring(start, i));
      start = i + 1;
    }
  }

  if (start < input.length) {
    parts.add(input.substring(start));
  }
  return parts;
}

bool _isTableConstraintLine(String line) {
  final trimmed = line.trimLeft().toUpperCase();
  return trimmed.startsWith('PRIMARY KEY') ||
      trimmed.startsWith('FOREIGN KEY') ||
      trimmed.startsWith('UNIQUE') ||
      trimmed.startsWith('CONSTRAINT') ||
      trimmed.startsWith('CHECK') ||
      trimmed.startsWith('KEY ');
}

String _extractTypeName(String definition) {
  final normalized = definition.trim().replaceAll(RegExp(r'\s+'), ' ');
  final constraintMatch = RegExp(
    r'\s+(?:NOT\s+NULL|NULL|DEFAULT|UNIQUE|PRIMARY\s+KEY|CHECK|REFERENCES|COMMENT|AFTER)\b',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (constraintMatch == null) {
    return normalized;
  }
  return normalized.substring(0, constraintMatch.start).trim();
}

String? _extractDefaultExpression(String definition) {
  final match = RegExp(
    r'\bDEFAULT\s+(.+?)(?:\s+NOT\s+NULL|\s+NULL|\s+UNIQUE|\s+PRIMARY|\s+CHECK|\s+REFERENCES|\s+ON\s+UPDATE|\s+COMMENT|\s+AFTER|$)',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(definition);
  if (match == null) return null;
  return match.group(1)?.trim();
}

String? _extractCommentExpression(String definition) {
  final match = RegExp(
    r"\bCOMMENT\s+'((?:''|[^'])*)'",
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(definition);
  return match?.group(1)?.replaceAll("''", "'");
}

String _normalizeTypeName(String input) {
  var normalized = input
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase()
      .replaceAll('character varying', 'varchar')
      .replaceAll('timestamp without time zone', 'timestamp')
      .replaceAll('timestamp with time zone', 'timestamptz');
  if (normalized == 'bool' ||
      normalized == 'boolean' ||
      normalized == 'tinyint(1)') {
    return 'boolean';
  }
  if (normalized == 'int' || normalized == 'integer') {
    return 'int';
  }
  if (normalized == 'double precision') {
    return 'double';
  }
  return normalized;
}

String? _normalizeDefaultValue(String? input) {
  if (input == null) return null;
  var normalized = input.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'null') return null;
  final quotedMatch = RegExp(r"^'(.*)'$").firstMatch(normalized);
  if (quotedMatch != null) {
    normalized = quotedMatch.group(1)!;
  }
  normalized =
      normalized.replaceAll('current_timestamp()', 'current_timestamp');
  normalized = normalized.replaceAll('::character varying', '');
  normalized = normalized.replaceAll('::text', '');
  normalized = normalized.replaceAll('::timestamp without time zone', '');
  normalized = normalized.replaceAll('::timestamp with time zone', '');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
  final numericValue = num.tryParse(normalized);
  if (numericValue != null) {
    final asDouble = numericValue.toDouble();
    return asDouble == asDouble.truncateToDouble()
        ? numericValue.toInt().toString()
        : numericValue.toString();
  }
  if (normalized == 'true' || normalized == 't') return '1';
  if (normalized == 'false' || normalized == 'f') return '0';
  return normalized;
}

String? _databaseTextValue(dynamic value) {
  if (value == null) return null;
  if (value is List<int>) {
    return utf8.decode(value);
  }
  return value.toString();
}

String _stripInlineKeyConstraints(String definition) {
  return definition
      .replaceAll(RegExp(r'\s+PRIMARY\s+KEY', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+UNIQUE', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _buildAddColumnAfterClause(
  List<_SqlColumnDefinition> desiredColumns,
  int desiredIndex,
  List<_RegisteredColumnDefinition> columnDirectives,
  Set<String> existingColumns,
) {
  if (DB.driver != DBDriver.mysql) return '';

  final desired = desiredColumns[desiredIndex];
  final explicitAfter = columnDirectives
      .firstWhereOrNull((column) => column.name == desired.name)
      ?.after;
  final after = explicitAfter ??
      (desiredIndex > 0 ? desiredColumns[desiredIndex - 1].name : null);

  if (after == null || after == desired.name) return '';
  if (!existingColumns.contains(after) &&
      !desiredColumns
          .take(desiredIndex)
          .any((column) => column.name == after)) {
    return '';
  }

  return ' AFTER `$after`';
}

String? _renamedFromForColumn(
  _SqlColumnDefinition desired,
  List<_RegisteredColumnDefinition> columnDirectives,
) {
  return columnDirectives
      .firstWhereOrNull((column) => column.name == desired.name)
      ?.renamedFrom;
}

String _buildRenameColumnSql({
  required String tableName,
  required String from,
  required String to,
}) {
  if (DB.driver == DBDriver.postgres) {
    return 'ALTER TABLE "$tableName" RENAME COLUMN "$from" TO "$to"';
  }
  return 'ALTER TABLE `$tableName` RENAME COLUMN `$from` TO `$to`';
}

String? _findCaseOnlyColumnName(
  String desiredName,
  Iterable<String> existingNames,
) {
  for (final existingName in existingNames) {
    if (existingName != desiredName &&
        existingName.toLowerCase() == desiredName.toLowerCase()) {
      return existingName;
    }
  }
  return null;
}

String? _desiredColumnComment(
  _SqlColumnDefinition desired,
  List<_RegisteredColumnDefinition> columnDirectives,
) {
  return columnDirectives
          .firstWhereOrNull((column) => column.name == desired.name)
          ?.comment ??
      desired.comment;
}

String? _buildColumnCommentSql({
  required String tableName,
  required _SqlColumnDefinition desired,
  required String? comment,
}) {
  if (DB.driver == DBDriver.postgres) {
    final value = comment == null ? 'NULL' : "'${_escapeSqlString(comment)}'";
    return 'COMMENT ON COLUMN "$tableName"."${desired.name}" IS $value';
  }

  if (DB.driver == DBDriver.mysql) {
    final definition = _definitionWithComment(desired.definition, comment);
    return 'ALTER TABLE `$tableName` MODIFY COLUMN `${desired.name}` $definition';
  }

  return null;
}

String _definitionWithComment(String definition, String? comment) {
  final withoutComment = definition
      .replaceAll(
        RegExp(r"\s+COMMENT\s+'(?:''|[^'])*'", caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (comment == null || comment.isEmpty) return withoutComment;
  return "$withoutComment COMMENT '${_escapeSqlString(comment)}'";
}

String? _normalizeColumnComment(String? comment) {
  if (comment == null || comment.isEmpty) return null;
  return comment;
}

String _escapeSqlString(String value) {
  return value.replaceAll("'", "''");
}

Future<void> _syncColumnComments(
  String tableName,
  List<_RegisteredColumnDefinition> columnDirectives,
) async {
  if (columnDirectives.isEmpty || DB.driver != DBDriver.postgres) return;

  final comments = columnDirectives
      .where((column) => column.comment != null)
      .toList(growable: false);
  if (comments.isEmpty) return;

  final existingColumns = await _getTableColumns(tableName);
  for (final column in comments) {
    if (!existingColumns.contains(column.name)) continue;
    final sql =
        'COMMENT ON COLUMN "$tableName"."${column.name}" IS \'${_escapeSqlString(column.comment!)}\'';
    await _executeMigrationSql(
      tableName: tableName,
      operation: 'comment column `${column.name}`',
      sql: sql,
      hint: 'Verify the column exists before rerunning migration.',
    );
  }
}

Future<void> _syncDeclaredIndexes(
  String tableName,
  List<_SqlColumnDefinition> desiredColumns,
  List<_RegisteredIndexDefinition> declaredIndexes,
) async {
  final desiredIndexes = _buildDesiredIndexes(desiredColumns, declaredIndexes);
  if (desiredIndexes.isEmpty) return;

  final existingIndexes = await _loadExistingIndexes(tableName);
  final existingKeys = existingIndexes.map((index) => index.shapeKey).toSet();

  for (final desired in desiredIndexes) {
    if (existingKeys.contains(desired.shapeKey)) continue;
    final sql = _buildCreateIndexSql(tableName, desired);
    await _executeMigrationSql(
      tableName: tableName,
      operation: 'add index `${desired.name}`',
      sql: sql,
      hint:
          'Remove duplicate values or verify the indexed columns exist before rerunning migration.',
    );
    Log.info(
      '   + Added ${desired.isUnique ? 'unique ' : ''}index `${desired.name}` on $tableName',
    );
  }
}

List<_DesiredIndexDefinition> _buildDesiredIndexes(
  List<_SqlColumnDefinition> desiredColumns,
  List<_RegisteredIndexDefinition> declaredIndexes,
) {
  final desired = <_DesiredIndexDefinition>[];

  for (final column in desiredColumns) {
    if (!column.isUnique || column.isPrimaryKey) continue;
    desired.add(
      _DesiredIndexDefinition(
        name: '',
        columns: [column.name],
        isUnique: true,
      ),
    );
  }

  for (final index in declaredIndexes) {
    if (index.columns.isEmpty) continue;
    desired.add(
      _DesiredIndexDefinition(
        name: index.name,
        columns: index.columns,
        isUnique: index.isUnique,
      ),
    );
  }

  final deduped = <String, _DesiredIndexDefinition>{};
  for (final index in desired) {
    deduped.putIfAbsent(index.shapeKey, () => index);
  }
  return deduped.values.toList();
}

Future<List<_ExistingIndexDefinition>> _loadExistingIndexes(
    String tableName) async {
  if (DB.driver == DBDriver.mysql) {
    final rows = await DB.query(
      '''
SELECT INDEX_NAME as index_name, COLUMN_NAME as column_name, NON_UNIQUE as non_unique, SEQ_IN_INDEX as seq_in_index
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = ?
  AND index_name <> 'PRIMARY'
ORDER BY index_name, seq_in_index
''',
      positionalParams: [tableName],
    );

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final indexName = _databaseTextValue(row['index_name']);
      final columnName = _databaseTextValue(row['column_name']);
      if (indexName == null || columnName == null) continue;
      grouped.putIfAbsent(indexName, () => <Map<String, dynamic>>[]).add({
        'column': columnName,
        'nonUnique': row['non_unique'],
      });
    }

    final result = <_ExistingIndexDefinition>[];
    for (final entry in grouped.entries) {
      final items = entry.value;
      if (items.isEmpty) continue;
      result.add(
        _ExistingIndexDefinition(
          name: entry.key,
          columns: items.map((item) => item['column']!.toString()).toList(),
          isUnique: !_coerceBoolish(items.first['nonUnique']),
        ),
      );
    }
    return result;
  }

  final rows = await DB.query(
    '''
SELECT
  i.relname as index_name,
  ix.indisunique as is_unique,
  array_agg(a.attname ORDER BY cols.ordinality) as columns
FROM pg_class t
JOIN pg_index ix ON t.oid = ix.indrelid
JOIN pg_class i ON i.oid = ix.indexrelid
JOIN unnest(ix.indkey) WITH ORDINALITY AS cols(attnum, ordinality) ON TRUE
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = cols.attnum
WHERE t.relname = ?
  AND ix.indisprimary = false
GROUP BY i.relname, ix.indisunique
''',
    positionalParams: [tableName],
  );

  final result = <_ExistingIndexDefinition>[];
  for (final row in rows) {
    final indexName = _databaseTextValue(row['index_name']);
    if (indexName == null) continue;
    result.add(
      _ExistingIndexDefinition(
        name: indexName,
        columns: _coerceStringList(row['columns']),
        isUnique: _coerceBoolish(row['is_unique']),
      ),
    );
  }
  return result;
}

String _buildCreateIndexSql(String tableName, _DesiredIndexDefinition index) {
  final indexName = index.name.isNotEmpty
      ? index.name
      : _buildIndexName(tableName, index.columns, isUnique: index.isUnique);

  if (DB.driver == DBDriver.postgres) {
    final columns = index.columns.map((column) => '"$column"').join(', ');
    return 'CREATE ${index.isUnique ? 'UNIQUE ' : ''}INDEX "$indexName" ON "$tableName" ($columns)';
  }

  final columns = index.columns.map((column) => '`$column`').join(', ');
  return 'ALTER TABLE `$tableName` ADD ${index.isUnique ? 'UNIQUE ' : ''}INDEX `$indexName` ($columns)';
}

String _buildIndexName(
  String tableName,
  List<String> columns, {
  required bool isUnique,
}) {
  final suffix = isUnique ? 'unique' : 'index';
  final raw = '${tableName}_${columns.join('_')}_$suffix';
  if (raw.length <= 63) return raw;

  var tablePart = tableName;
  if (tablePart.length > 24) {
    tablePart = tablePart.substring(0, 24);
  }

  final trimmedColumns = columns
      .map((column) => column.length > 12 ? column.substring(0, 12) : column)
      .join('_');
  final candidate =
      '${tablePart}_${trimmedColumns}_${isUnique ? 'uniq' : 'idx'}';
  if (candidate.length <= 63) return candidate;
  return candidate.substring(0, 63);
}

bool _coerceBoolish(dynamic value) {
  if (value is bool) return value;
  final normalized = _databaseTextValue(value)?.trim().toLowerCase() ?? '';
  return normalized == '1' ||
      normalized == 'true' ||
      normalized == 't' ||
      normalized == 'yes';
}

List<String> _coerceStringList(dynamic value) {
  if (value is List) {
    return value.map(_databaseTextValue).whereType<String>().toList();
  }

  final raw = _databaseTextValue(value) ?? '';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const [];

  final withoutBraces =
      trimmed.replaceAll(RegExp(r'^\{'), '').replaceAll(RegExp(r'\}$'), '');
  if (withoutBraces.isEmpty) return const [];
  return withoutBraces
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

class _SqlColumnDefinition {
  final String name;
  final String definition;
  final String typeName;
  final bool nullable;
  final String? defaultValue;
  final String? comment;
  final bool isUnique;
  final bool isPrimaryKey;
  final bool updatesCurrentTimestamp;

  const _SqlColumnDefinition({
    required this.name,
    required this.definition,
    required this.typeName,
    required this.nullable,
    required this.defaultValue,
    required this.comment,
    required this.isUnique,
    required this.isPrimaryKey,
    required this.updatesCurrentTimestamp,
  });
}

class _RegisteredTableDefinition {
  final String tableName;
  final String createSql;
  final List<_RegisteredIndexDefinition> indexes;
  final List<_RegisteredColumnDefinition> columns;

  const _RegisteredTableDefinition({
    required this.tableName,
    required this.createSql,
    required this.indexes,
    required this.columns,
  });

  factory _RegisteredTableDefinition.fromPayload(dynamic payload) {
    if (payload is String) {
      return _RegisteredTableDefinition(
        tableName: _extractTableName(payload) ?? '',
        createSql: payload,
        indexes: const [],
        columns: const [],
      );
    }

    if (payload is Map) {
      final rawIndexes = payload['indexes'];
      final rawColumns = payload['columns'];
      return _RegisteredTableDefinition(
        tableName: payload['tableName']?.toString() ??
            _extractTableName(payload['createSql']?.toString() ?? '') ??
            '',
        createSql: payload['createSql']?.toString() ?? '',
        indexes: rawIndexes is List
            ? rawIndexes
                .map(_RegisteredIndexDefinition.fromPayload)
                .whereType<_RegisteredIndexDefinition>()
                .toList()
            : const [],
        columns: rawColumns is List
            ? rawColumns
                .map(_RegisteredColumnDefinition.fromPayload)
                .whereType<_RegisteredColumnDefinition>()
                .toList()
            : const [],
      );
    }

    throw ArgumentError('Unsupported table registry payload: $payload');
  }
}

class _RegisteredIndexDefinition {
  final String name;
  final List<String> columns;
  final bool isUnique;

  const _RegisteredIndexDefinition({
    required this.name,
    required this.columns,
    required this.isUnique,
  });

  static _RegisteredIndexDefinition? fromPayload(dynamic payload) {
    if (payload is! Map) return null;
    final rawColumns = payload['columns'];
    return _RegisteredIndexDefinition(
      name: payload['name']?.toString() ?? '',
      columns: rawColumns is List
          ? rawColumns.map((column) => column.toString()).toList()
          : const [],
      isUnique: _coerceBoolish(payload['isUnique']),
    );
  }
}

class _DesiredIndexDefinition {
  final String name;
  final List<String> columns;
  final bool isUnique;

  const _DesiredIndexDefinition({
    required this.name,
    required this.columns,
    required this.isUnique,
  });

  String get shapeKey =>
      '${isUnique ? 'unique' : 'index'}:${columns.join(',').toLowerCase()}';
}

class _ExistingIndexDefinition {
  final String name;
  final List<String> columns;
  final bool isUnique;

  const _ExistingIndexDefinition({
    required this.name,
    required this.columns,
    required this.isUnique,
  });

  String get shapeKey =>
      '${isUnique ? 'unique' : 'index'}:${columns.join(',').toLowerCase()}';
}

class _ExistingColumnSchema {
  final String name;
  final String typeName;
  final bool nullable;
  final String? defaultValue;
  final bool updatesCurrentTimestamp;
  final String? comment;

  const _ExistingColumnSchema({
    required this.name,
    required this.typeName,
    required this.nullable,
    required this.defaultValue,
    required this.updatesCurrentTimestamp,
    required this.comment,
  });

  _ExistingColumnSchema copyWith({
    String? name,
    String? typeName,
    bool? nullable,
    String? defaultValue,
    bool? updatesCurrentTimestamp,
    String? comment,
  }) {
    return _ExistingColumnSchema(
      name: name ?? this.name,
      typeName: typeName ?? this.typeName,
      nullable: nullable ?? this.nullable,
      defaultValue: defaultValue ?? this.defaultValue,
      updatesCurrentTimestamp:
          updatesCurrentTimestamp ?? this.updatesCurrentTimestamp,
      comment: comment ?? this.comment,
    );
  }
}

class _RegisteredColumnDefinition {
  final String name;
  final String? comment;
  final String? after;
  final String? renamedFrom;

  const _RegisteredColumnDefinition({
    required this.name,
    required this.comment,
    required this.after,
    required this.renamedFrom,
  });

  static _RegisteredColumnDefinition? fromPayload(dynamic payload) {
    if (payload is! Map) return null;
    final name = payload['name']?.toString();
    if (name == null || name.isEmpty) return null;
    return _RegisteredColumnDefinition(
      name: name,
      comment: payload['comment']?.toString(),
      after: payload['after']?.toString(),
      renamedFrom: payload['renamedFrom']?.toString(),
    );
  }
}

/// --- Normalize SQL for current driver ---
String _normalizeSqlForCurrentDriver(String sql) {
  if (DB.driver == DBDriver.postgres) {
    return _normalizeSqlForPostgres(sql);
  }
  return sql;
}

/// --- Normalize SQL for PostgreSQL ---
String _normalizeSqlForPostgres(String sql) {
  var normalized = sql.replaceAll('`', '"');
  normalized = normalized.replaceAllMapped(
      RegExp(r'DATETIME(?:\([^)]+\))?', caseSensitive: false),
      (match) => 'TIMESTAMP');
  normalized = normalized.replaceAll('MODIFY COLUMN', 'ALTER COLUMN');

  // Handle AUTO_INCREMENT
  if (normalized.contains('AUTO_INCREMENT')) {
    normalized = normalized.replaceAll(
      'AUTO_INCREMENT',
      'GENERATED ALWAYS AS IDENTITY',
    );
  }

  // Handle ON UPDATE CURRENT_TIMESTAMP for MySQL compatibility
  normalized = normalized.replaceAll('ON UPDATE CURRENT_TIMESTAMP', '');

  return normalized;
}

/// Exposed for testing migrate SQL normalization without requiring DB access.
String dbMigrateNormalizeSqlForPostgres(String sql) {
  return _normalizeSqlForPostgres(sql);
}

/// Exposed for testing migration column parser without requiring DB access.
List<Map<String, Object?>> dbMigrateExtractColumns(String sql) {
  return _extractColumnsFromCreateSql(sql)
      .map((c) => {
            'name': c.name,
            'definition': c.definition,
            'type': c.typeName,
            'nullable': c.nullable,
            'default': c.defaultValue,
            'comment': c.comment,
            'unique': c.isUnique,
            'primaryKey': c.isPrimaryKey,
          })
      .toList();
}

List<Map<String, Object?>> dbMigrateBuildDesiredIndexes(
  String sql, [
  List<Map<String, Object?>> declaredIndexes = const [],
]) {
  final indexes = declaredIndexes
      .map(_RegisteredIndexDefinition.fromPayload)
      .whereType<_RegisteredIndexDefinition>()
      .toList();
  return _buildDesiredIndexes(_extractColumnsFromCreateSql(sql), indexes)
      .map((index) => {
            'name': index.name,
            'columns': index.columns,
            'unique': index.isUnique,
          })
      .toList();
}

String? dbMigrateNormalizeDefaultValue(String? input) {
  return _normalizeDefaultValue(input);
}

/// --- Extract table name from SQL ---
String? _extractTableName(String sql) {
  // Match CREATE TABLE or ALTER TABLE statements
  final match = RegExp(
    r'(?:CREATE\s+TABLE|ALTER\s+TABLE)\s+["`]?(\w+)["`]?',
    caseSensitive: false,
  ).firstMatch(sql);

  return match?.group(1);
}

/// Exposed for testing migrate table-name extraction without DB access.
String? dbMigrateExtractTableName(String sql) {
  return _extractTableName(sql);
}

/// --- Create trigger for PostgreSQL updated_at ---
Future<void> _safeCreateUpdatedAtTriggerForPostgres(String tableName) async {
  final exists = await _safeTableExists(tableName);
  if (!exists) return;

  final functionName = 'update_${tableName}_timestamp';
  final triggerName = '${tableName}_updated_at_trigger';

  try {
    // Check if function already exists
    final funcResult = await DB.query(
        "SELECT COUNT(*) as count FROM pg_proc WHERE proname = ?",
        positionalParams: [functionName]);

    if ((funcResult.first['count'] as int) == 0) {
      final functionSql = '''
CREATE OR REPLACE FUNCTION $functionName()
RETURNS TRIGGER AS \$\$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;
''';
      await DB.execute(functionSql);
    }

    // Drop existing trigger if exists
    await DB.execute('DROP TRIGGER IF EXISTS $triggerName ON "$tableName";');

    // Create new trigger
    final createTriggerSql = '''
CREATE TRIGGER $triggerName
BEFORE UPDATE ON "$tableName"
FOR EACH ROW
EXECUTE FUNCTION $functionName();
''';
    await DB.execute(createTriggerSql);

    Log.debug('   🔧 Created updated_at trigger for "$tableName"');
  } catch (e) {
    Log.debug('   ⚠️ Could not create updated_at trigger for "$tableName": $e');
  }
}

/// Checks existing table SQL and injects missing timestamps
Future<void> ensureTimestampsOnExistingTable(String tableName) async {
  try {
    final driver = DB.driver;
    final q = driver == DBDriver.postgres ? '"' : '`';

    // Get existing columns
    final existingColumns = await _getTableColumns(tableName);

    final additions = <String>[];

    if (!existingColumns.contains('created_at')) {
      additions.add(driver == DBDriver.postgres
          ? '${q}created_at$q TIMESTAMP DEFAULT CURRENT_TIMESTAMP'
          : '${q}created_at$q DATETIME DEFAULT CURRENT_TIMESTAMP');
    }

    if (!existingColumns.contains('updated_at')) {
      additions.add(driver == DBDriver.postgres
          ? '${q}updated_at$q TIMESTAMP DEFAULT CURRENT_TIMESTAMP'
          : '${q}updated_at$q DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');
    }

    if (additions.isEmpty) return;

    final alterSql =
        'ALTER TABLE $q$tableName$q ADD COLUMN ${additions.join(', ADD COLUMN ')};';
    await DB.execute(alterSql);

    // For PostgreSQL, create trigger if updated_at was added
    if (driver == DBDriver.postgres &&
        !existingColumns.contains('updated_at')) {
      await _safeCreateUpdatedAtTriggerForPostgres(tableName);
    }

    Log.info('   ✅ Timestamps ensured for table "$tableName"');
  } catch (e) {
    Log.debug('   ⚠️ Error ensuring timestamps for "$tableName": $e');
  }
}

/// Get table columns
Future<Set<String>> _getTableColumns(String tableName) async {
  final driver = DB.driver;

  if (driver == DBDriver.postgres) {
    final result = await DB.query(
        "SELECT column_name FROM information_schema.columns WHERE table_name = ?",
        positionalParams: [tableName]);
    return result.map((row) => row['column_name'] as String).toSet();
  } else if (driver == DBDriver.mysql) {
    final result = await DB.query("SHOW COLUMNS FROM `$tableName`");
    return result.map((row) => row['Field'] as String).toSet();
  }

  return {};
}

extension _FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }
}
