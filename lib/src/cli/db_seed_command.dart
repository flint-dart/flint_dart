import 'dart:io';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';

class DbSeedCommand extends FlintCommand {
  DbSeedCommand() : super('db:seed', 'Run database seeders');

  @override
  Future<void> execute(List<String> args) async {
    final runner = File('lib/seeders/seeder.dart');

    if (!runner.existsSync()) {
      Log.error(
        'Seeder runner not found: lib/seeders/seeder.dart',
      );
      Log.info(
        'Create it or run: flint make:seeder',
      );
      exit(1);
    }

    Log.info('Running database seeders...');

    final result = await Process.start(
      'dart',
      ['run', 'lib/seeders/seeder.dart'],
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await result.exitCode;
    if (exitCode != 0) {
      exit(1);
    }

    Log.success('Database seeding completed');
  }
}
