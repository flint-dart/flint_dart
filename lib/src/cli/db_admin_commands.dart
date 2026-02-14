import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/database/db.dart';
import 'package:flint_dart/src/env_parser.dart';

class DBCreateCommand extends FlintCommand {
  DBCreateCommand() : super('db:create', 'Creates database from .env or name');

  @override
  Future<void> execute(List<String> args) async {
    final dbName = args.isNotEmpty ? args.first : FlintEnv.get('DB_NAME', '');
    if (dbName.isEmpty) {
      Log.debug('❌ Missing DB name. Use db:create <name> or set DB_NAME.');
      exit(1);
    }

    final driver = FlintEnv.get('DB_CONNECTION', 'mysql');
    final host = FlintEnv.get('DB_HOST', 'localhost');
    final port = driver == 'postgres'
        ? FlintEnv.getInt('DB_PORT', 5432)
        : FlintEnv.getInt('DB_PORT', 3306);
    final user = FlintEnv.get(
        'DB_USER', driver == 'postgres' ? 'postgres' : 'root');
    final password = FlintEnv.get('DB_PASSWORD', '');

    try {
      await DB.connect(
        database: driver == 'postgres' ? 'postgres' : 'mysql',
        host: host,
        port: port,
        username: user,
        password: password,
      );

      if (driver == 'postgres') {
        await DB.execute('CREATE DATABASE "$dbName"');
      } else {
        await DB.execute('CREATE DATABASE IF NOT EXISTS `$dbName`');
      }
      Log.info('✅ Database created: $dbName');
    } catch (e) {
      Log.debug('❌ Failed to create database: $e');
      exitCode = 1;
    } finally {
      await _safeClose();
    }
  }
}

class DBUserCreateCommand extends FlintCommand {
  DBUserCreateCommand()
      : super('db:user:create', 'Creates DB user and grants DB privileges');

  @override
  Future<void> execute(List<String> args) async {
    final targetUser =
        args.isNotEmpty ? args[0] : FlintEnv.get('DB_USER', 'flint_user');
    final targetPassword =
        args.length > 1 ? args[1] : FlintEnv.get('DB_PASSWORD', 'flint_pass');
    final dbName = FlintEnv.get('DB_NAME', '');
    if (dbName.isEmpty) {
      Log.debug('❌ Missing DB_NAME in .env');
      exit(1);
    }

    final driver = FlintEnv.get('DB_CONNECTION', 'mysql');
    final host = FlintEnv.get('DB_HOST', 'localhost');
    final port = driver == 'postgres'
        ? FlintEnv.getInt('DB_PORT', 5432)
        : FlintEnv.getInt('DB_PORT', 3306);
    final adminUser = FlintEnv.get(
        'DB_USER', driver == 'postgres' ? 'postgres' : 'root');
    final adminPassword = FlintEnv.get('DB_PASSWORD', '');
    final escapedPassword = targetPassword.replaceAll("'", "''");

    try {
      await DB.connect(
        database: driver == 'postgres' ? 'postgres' : 'mysql',
        host: host,
        port: port,
        username: adminUser,
        password: adminPassword,
      );

      if (driver == 'postgres') {
        await DB.execute(
            "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$targetUser') "
            "THEN CREATE ROLE \"$targetUser\" LOGIN PASSWORD '$escapedPassword'; END IF; END \$\$;");
        await DB.execute('GRANT ALL PRIVILEGES ON DATABASE "$dbName" TO "$targetUser"');
      } else {
        await DB.execute(
            "CREATE USER IF NOT EXISTS '$targetUser'@'%' IDENTIFIED BY '$escapedPassword'");
        await DB.execute(
            "GRANT ALL PRIVILEGES ON `$dbName`.* TO '$targetUser'@'%'");
        await DB.execute('FLUSH PRIVILEGES');
      }

      Log.info('✅ DB user ready: $targetUser');
    } catch (e) {
      Log.debug('❌ Failed to create DB user: $e');
      exitCode = 1;
    } finally {
      await _safeClose();
    }
  }
}

class DBExportCommand extends FlintCommand {
  DBExportCommand()
      : super('db:export', 'Exports database dump using mysqldump/pg_dump');

  @override
  Future<void> execute(List<String> args) async {
    final now = DateTime.now();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
    final outputFile = args.isNotEmpty ? args.first : 'db_export_$stamp.sql';

    final driver = FlintEnv.get('DB_CONNECTION', 'mysql');
    final host = FlintEnv.get('DB_HOST', 'localhost');
    final port = driver == 'postgres'
        ? FlintEnv.getInt('DB_PORT', 5432).toString()
        : FlintEnv.getInt('DB_PORT', 3306).toString();
    final dbName = FlintEnv.get('DB_NAME', '');
    final user = FlintEnv.get(
        'DB_USER', driver == 'postgres' ? 'postgres' : 'root');
    final password = FlintEnv.get('DB_PASSWORD', '');

    if (dbName.isEmpty) {
      Log.debug('❌ Missing DB_NAME in .env');
      exit(1);
    }

    if (driver == 'postgres') {
      await _runDump(
        executable: 'pg_dump',
        args: ['-h', host, '-p', port, '-U', user, '-d', dbName, '-f', outputFile],
        envExtra: {'PGPASSWORD': password},
      );
    } else {
      await _runDump(
        executable: 'mysqldump',
        args: ['-h', host, '-P', port, '-u', user, dbName, '--result-file=$outputFile'],
        envExtra: {'MYSQL_PWD': password},
      );
    }
  }

  Future<void> _runDump({
    required String executable,
    required List<String> args,
    required Map<String, String> envExtra,
  }) async {
    try {
      final probe = await Process.run(executable, ['--version']);
      if (probe.exitCode != 0) {
        Log.debug('❌ $executable is not available in PATH.');
        exit(1);
      }
    } catch (_) {
      Log.debug('❌ $executable is not installed or not in PATH.');
      exit(1);
    }

    final env = Map<String, String>.from(Platform.environment)..addAll(envExtra);
    final result =
        await Process.run(executable, args, runInShell: true, environment: env);
    if (result.exitCode != 0) {
      Log.debug('❌ Export failed: ${result.stderr}');
      exitCode = 1;
      return;
    }

    // For pg_dump, file is created by -f. For mysqldump, result-file also writes file.
    final outPath = args.last.startsWith('--result-file=')
        ? args.last.substring('--result-file='.length)
        : args.last;
    Log.info('✅ Database export saved: $outPath');
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}

Future<void> _safeClose() async {
  try {
    await DB.close();
  } catch (_) {
    // ignore close errors after failed connection attempts
  }
}
