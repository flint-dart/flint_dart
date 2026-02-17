import 'dart:io';
import 'dart:isolate';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/database/db.dart';
import 'package:flint_dart/src/env_parser.dart';

List<String> _registeredSqlStrings = [];

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

      if (_registeredSqlStrings.isEmpty) {
        Log.debug(
            '❗️ No tables were registered. Please call registerTables().');
        return;
      }

      Log.debug('Found ${_registeredSqlStrings.length} tables. Migrating...');

      for (var sql in _registeredSqlStrings) {
        String? currentTableName;
        try {
          // --- Extract table name first ---
          final tableName = _extractTableName(sql);
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
              // ALTER table: add missing columns
              await _alterTableAddMissingColumns(tableName, sql);
            }
          } else {
            // CREATE table
            await DB.execute(sql);
          }

          // --- Create trigger for PostgreSQL updated_at ---
          if (DB.driver == DBDriver.postgres) {
            await _safeCreateUpdatedAtTriggerForPostgres(tableName);
          }

          // --- Ensure timestamps ---
          await ensureTimestampsOnExistingTable(tableName);

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
      _registeredSqlStrings = [];
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

      final sqlList = await receivePort.first as List<String>;
      _registeredSqlStrings = sqlList;
      Log.debug('📋 Loaded ${sqlList.length} table definitions from registry.');
    } catch (e) {
      Log.debug('⚠️ Failed to load table registry: ', error: e);
      _registeredSqlStrings = [];
    } finally {
      receivePort.close();
    }
  }
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

/// --- Alter table to add missing columns (MySQL/Postgres) ---
Future<void> _alterTableAddMissingColumns(String tableName, String sql) async {
  // Extract column definitions from CREATE TABLE statement
  final createTableMatch = RegExp(r'CREATE\s+TABLE\s+[^\(]+\((.*)\)',
          caseSensitive: false, dotAll: true)
      .firstMatch(sql);
  if (createTableMatch == null) return;

  final columnsSection = createTableMatch.group(1)!;
  final columnRegex =
      RegExp(r'["`]?(\w+)["`]?\s+([^\s,]+(?:\([^)]+\))?[^,]*)(?:,|$)');
  final matches = columnRegex.allMatches(columnsSection);

  for (final match in matches) {
    final columnName = match.group(1)!;
    var columnDef = match.group(2)!.trim();

    // Skip if it's a constraint
    if (columnName.toUpperCase().startsWith('PRIMARY') ||
        columnName.toUpperCase().startsWith('FOREIGN') ||
        columnName.toUpperCase().startsWith('UNIQUE') ||
        columnName.toUpperCase().startsWith('CHECK')) {
      continue;
    }

    final exists = await DB.columnExists(tableName, columnName);
    if (!exists) {
      final q = DB.driver == DBDriver.postgres ? '"' : '`';
      try {
        await DB.execute(
            'ALTER TABLE $q$tableName$q ADD COLUMN $q$columnName$q $columnDef');
        Log.info('   ➕ Added column `$columnName` to $tableName');
      } catch (e) {
        Log.debug('   ⚠️ Failed to add column `$columnName`: $e');
      }
    }
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
