import 'package:flint_dart/logs.dart';
import 'package:flint_dart/schema.dart' as schema;
import 'package:flint_dart/src/cli/db_commands.dart';
import 'package:flint_dart/src/database/db.dart';
import 'package:flint_dart/src/env_parser.dart';

class FlintMigrations {
  static bool _hasRun = false;

  static bool get hasRun => _hasRun;

  static bool enabledFromEnv([
    String key = 'FLINT_AUTO_MIGRATE',
    bool defaultValue = false,
  ]) {
    final value = FlintEnv.get(key, '').trim().toLowerCase();
    if (value.isEmpty) return defaultValue;
    return value == '1' || value == 'true' || value == 'yes';
  }

  static bool createDatabaseFromEnv([
    String key = 'FLINT_AUTO_MIGRATE_CREATE_DB',
  ]) {
    final value = FlintEnv.get(key, '').trim().toLowerCase();
    return value == '1' || value == 'true' || value == 'yes';
  }

  static bool verboseFromEnv([String key = 'FLINT_AUTO_MIGRATE_VERBOSE']) {
    final value = FlintEnv.get(key, '').trim().toLowerCase();
    return value == '1' || value == 'true' || value == 'yes';
  }

  static Future<void> ensure({
    bool enabled = true,
    bool runOnce = true,
    bool createDatabase = false,
    bool noInteraction = true,
    bool force = false,
    bool verbose = false,
    bool reconnectIfPreviouslyConnected = true,
    List<schema.Table>? tables,
  }) async {
    if (!enabled) return;
    if (runOnce && _hasRun) {
      Log.debug('[FLINT] Auto migration skipped; already ran in this process.');
      return;
    }

    final args = <String>[
      if (noInteraction) '--no-interaction',
      if (createDatabase) '--create-db',
      if (force) '--force',
      if (verbose) '--verbose',
    ];

    final wasConnected = DB.isConnected;
    Log.debug('[FLINT] Running database migrations before server start...');
    try {
      await DBMigrateCommand().execute(args, tables: tables);
      if (reconnectIfPreviouslyConnected && wasConnected && !DB.isConnected) {
        await DB.autoConnect();
      }
      _hasRun = true;
      Log.debug('[FLINT] Database migrations are ready.');
    } catch (_) {
      _hasRun = false;
      rethrow;
    }
  }

  static Future<void> ensureFromEnv({
    String enabledKey = 'FLINT_AUTO_MIGRATE',
    String createDatabaseKey = 'FLINT_AUTO_MIGRATE_CREATE_DB',
    String verboseKey = 'FLINT_AUTO_MIGRATE_VERBOSE',
    bool runOnce = true,
    bool noInteraction = true,
    bool force = false,
    bool reconnectIfPreviouslyConnected = true,
    List<schema.Table>? tables,
  }) {
    return ensure(
      enabled: enabledFromEnv(enabledKey),
      runOnce: runOnce,
      createDatabase: createDatabaseFromEnv(createDatabaseKey),
      noInteraction: noInteraction,
      force: force,
      verbose: verboseFromEnv(verboseKey),
      reconnectIfPreviouslyConnected: reconnectIfPreviouslyConnected,
      tables: tables,
    );
  }
}
