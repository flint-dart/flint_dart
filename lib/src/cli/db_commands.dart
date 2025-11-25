import 'dart:io';
import 'dart:isolate';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/database/db.dart';
import 'package:flint_dart/src/env_parser.dart';

List<String> _registeredSqlStrings = [];

class DBMigrateCommand extends FlintCommand {
  DBMigrateCommand() : super('migrate', 'Runs database migrations');

  @override
  Future<void> execute(List<String> args) async {
    final drop = args.contains('--drop');

    print(drop
        ? '🔁 Refreshing database (droping migrations)...'
        : '🚀 Starting database migration...');

    // --- Drop tables if --refresh is used ---
    if (drop) {
      await _dropAllTables();
      print('🧹 All existing tables dropped.');
      return;
    }
    try {
      await _runTableRegistry();
      await DB.autoConnect();

      if (_registeredSqlStrings.isEmpty) {
        print('❗️ No tables were registered. Please call registerTables().');
        return;
      }

      print('Found ${_registeredSqlStrings.length} tables. Migrating...');

      for (var sql in _registeredSqlStrings) {
        // Inject timestamps
        var finalSql = _injectTimestamps(sql);

        // Normalize for PostgreSQL
        if (DB.driver == DBDriver.postgres) {
          finalSql = normalizeSqlForPostgres(finalSql);
        }

        await DB.execute(finalSql);

        // Create PostgreSQL trigger safely
        if (DB.driver == DBDriver.postgres) {
          final tableName = _extractTableName(finalSql);
          if (tableName != null) {
            // wait briefly for table commit
            await _safeCreateUpdatedAtTriggerForPostgres(tableName);
          }
        }
      }

      print('✅ Migration completed successfully.');
    } catch (e, st) {
      print('❌ Migration failed: $e');
      print(st);
    } finally {
      await DB.close();
    }
    await DB.close();
    return;
  }

  Future<void> _runTableRegistry() async {
    final appRoot = Directory.current.path;
    final registryPath = '$appRoot/lib/src/config/table_registry.dart';
    final registryFile = File(registryPath);

    if (!registryFile.existsSync()) {
      throw Exception('❌ Could not find table_registry.dart.');
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
    } finally {
      receivePort.close(); // ← This is crucial
    }
    return;
  }
}

/// --- Drop all tables (used for --refresh) ---
Future<void> _dropAllTables() async {
  print('🗑️ Dropping all tables...');

  try {
    await DB.autoConnect();

    if (DB.driver == DBDriver.mysql) {
      print('💾 MySQL detected — fetching table list...');
      final tables = await DB.query('SHOW TABLES');

      if (tables.isEmpty) {
        print('ℹ️ No tables found.');
        return;
      }

      for (final row in tables) {
        final tableName = row.values.first;
        print('   🔹 Dropping `$tableName`...');
        await DB.execute('DROP TABLE IF EXISTS `$tableName`;');
      }
    } else if (DB.driver == DBDriver.postgres) {
      print('🐘 PostgreSQL detected — fetching table list...');
      final tables = await DB.query(
        "SELECT tablename FROM pg_tables WHERE schemaname = 'public';",
      );

      if (tables.isEmpty) {
        print('ℹ️ No tables found.');
        return;
      }

      await DB.execute('SET session_replication_role = replica;');

      for (final row in tables) {
        final tableName = row['tablename'];
        print('   🔹 Dropping "$tableName"...');
        await DB.execute('DROP TABLE IF EXISTS "$tableName" CASCADE;');
      }

      await DB.execute('SET session_replication_role = DEFAULT;');
    }

    print('✅ All tables dropped successfully.');
    return;
  } catch (e, st) {
    print('❌ Failed to drop tables: $e');
    print(st);
  } finally {
    await DB.close();
  }
  return;
}

/// --- Add created_at & updated_at columns if missing ---

/// --- Add created_at, updated_at, provider, and provider_id columns if missing ---
String _injectTimestamps(String sql) {
  if (!sql.trim().toUpperCase().startsWith('CREATE TABLE')) return sql;

  final insertIndex = sql.lastIndexOf(')');
  if (insertIndex == -1) return sql;

  // --- Extract table name ---
  final tableMatch = RegExp(r'CREATE TABLE\s+["`]?(\w+)["`]?').firstMatch(sql);
  final tableName = tableMatch?.group(1) ?? '';

  // --- ENV values ---
  final authTable = FlintEnv.get('AUTH_TABLE', "users");
  final providerCol = FlintEnv.get('AUTH_PROVIDER_COLUMN', "provider");
  final providerIdCol = FlintEnv.get('AUTH_PROVIDER_ID_COLUMN', "provider_id");

  final isAuthTable = tableName.toLowerCase() == authTable.toLowerCase();

  // --- Driver checks ---
  final isPostgres = DB.driver == DBDriver.postgres;
  final q = isPostgres ? '"' : '`';

  // --- Detect existing columns ---
  bool hasCreatedAt = sql.contains('created_at');
  bool hasUpdatedAt = sql.contains('updated_at');
  bool hasProvider = sql.contains(providerCol);
  bool hasProviderId = sql.contains(providerIdCol);
  bool hasEmailVerifiedAt = sql.contains('email_verified_at');
  bool hasIsVerified = sql.contains('is_verified');

  final additions = <String>[];

  // --- Add provider/provider_id if missing and is auth table ---
  if (isAuthTable) {
    if (!hasProvider) additions.add('$q$providerCol$q VARCHAR(100)');
    if (!hasProviderId) additions.add('$q$providerIdCol$q VARCHAR(255)');
    if (!hasEmailVerifiedAt) {
      additions.add(isPostgres
          ? '${q}email_verified_at$q TIMESTAMP NULL DEFAULT NULL'
          : '${q}email_verified_at$q DATETIME NULL DEFAULT NULL');
    }
    if (!hasIsVerified) {
      additions.add('${q}is_verified$q BOOLEAN DEFAULT FALSE');
    }
  }
  // --- Add auth-related verification fields ---
  if (isAuthTable) {}

  // --- Add timestamps if missing ---
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

  // --- If nothing to add, skip ---
  if (additions.isEmpty) return sql;

  // --- Inject new columns before closing parenthesis ---
  final additionSql = ',\n  ${additions.join(',\n  ')}';
  return sql.substring(0, insertIndex) +
      additionSql +
      sql.substring(insertIndex);
}

/// --- Normalize SQL for PostgreSQL ---
String normalizeSqlForPostgres(String sql) {
  var normalized = sql;
  normalized = normalized.replaceAll('`', '"');
  normalized = normalized.replaceAll('DATETIME', 'TIMESTAMP');
  normalized = normalized.replaceAll('MODIFY COLUMN', 'ALTER COLUMN');

  if (normalized.contains('AUTO_INCREMENT')) {
    normalized = normalized.replaceAll(
      'AUTO_INCREMENT',
      'GENERATED ALWAYS AS IDENTITY',
    );
  }

  return normalized;
}

/// --- Extract table name from CREATE TABLE ---
String? _extractTableName(String sql) {
  final regex = RegExp(r'CREATE TABLE\s+["`]?(\w+)["`]?', caseSensitive: false);
  final match = regex.firstMatch(sql);
  return match?.group(1);
}

/// --- Create updated_at trigger safely for PostgreSQL ---
Future<void> _safeCreateUpdatedAtTriggerForPostgres(String tableName) async {
  // Check table exists first
  final exists = await DB.tableExists(tableName);
  if (!exists) {
    return;
  }

  final functionSql = '''
  CREATE OR REPLACE FUNCTION update_${tableName}_timestamp()
  RETURNS TRIGGER AS \$\$
  BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
  END;
  \$\$ LANGUAGE 'plpgsql';
  ''';

  final dropTriggerSql =
      'DROP TRIGGER IF EXISTS ${tableName}_updated_at_trigger ON "$tableName";';

  final createTriggerSql = '''
  CREATE TRIGGER ${tableName}_updated_at_trigger
  BEFORE UPDATE ON "$tableName"
  FOR EACH ROW
  EXECUTE PROCEDURE update_${tableName}_timestamp();
  ''';

  try {
    await DB.execute(functionSql);
    await DB.execute(dropTriggerSql);
    await DB.execute(createTriggerSql);
  } catch (e) {
    final error = e.toString().toLowerCase();
    if (error.contains('permission denied') ||
        error.contains('trigger') ||
        error.contains('function')) {
      print(
          '⚠️ Warning: Could not create updated_at trigger for "$tableName".\n   Reason: ${e.toString().split('\n').first}');
    } else {
      print('⚠️ Skipped trigger for "$tableName" due to: $e');
    }
  }
  return;
}
