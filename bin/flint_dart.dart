import 'dart:io';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/build_command.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/cli/create_project_command.dart';
import 'package:flint_dart/src/cli/db_commands.dart';
import 'package:flint_dart/src/cli/generate_docs_command.dart';
import 'package:flint_dart/src/cli/make_controller_command.dart';
import 'package:flint_dart/src/cli/make_docker_command.dart';
import 'package:flint_dart/src/cli/make_isolate_command.dart';
import 'package:flint_dart/src/cli/make_mail_command.dart';
import 'package:flint_dart/src/cli/make_middleware_command.dart';
import 'package:flint_dart/src/cli/make_model_command.dart';
import 'package:flint_dart/src/cli/make_seeder_command.dart';
import 'package:flint_dart/src/cli/update_command.dart';
import 'package:flint_dart/src/cli/upgrade_command.dart';
import 'package:flint_dart/src/cli/version_commands.dart';

final Map<String, FlintCommand> commands = {
  'create': CreateProjectCommand(),
  'start': RunServerCommand(),
  'run': RunServerCommand(),
  'build': BuildCommand(),
  'make:docker': MakeDockerCommand(),
  'migrate': DBMigrateCommand(),
  'make:model': MakeModelCommand(),
  'make:controller': MakeControllerCommand(),
  'make:middleware': MakeMiddlewareCommand(),
  'make:isolate': MakeIsolateCommand(), // ✅ Add here
  'docs:generate': GenerateDocsCommand(),
  'make:seeder': MakeSeederCommand(), // <-- Add here

  'make:mail': MakeMailCommand(),
  'update': UpdateCommand(),
  'upgrade': UpgradeCommand(),
  'version': VersionCommand(),
  '--v': VersionCommand(),
};

// Map alternative long-form commands (with --) to standard commands
final Map<String, String> aliasCommands = {
  '--make-mail': 'make:mail',
  '--make-model': 'make:model',
  '--make-controller': 'make:controller',
  '--make-middleware': 'make:middleware',
  '--make-docker': 'make:docker',
  '--make-isolate': 'make:isolate',
  "--docs-generate": 'docs:generate',
  '--make-seeder': 'make:seeder', // <-- Add alias here
};

void main(List<String> args) async {
  if (args.isEmpty) {
    debugUsage();
    return;
  }

  // Map long-form --commands to normal commands
  final firstArg = aliasCommands[args[0]] ?? args[0];

  if (!commands.containsKey(firstArg)) {
    Log.debug('❌ Unknown command: ${args[0]}');
    debugUsage();
    exit(1);
  }

  try {
    await commands[firstArg]!.execute(args.sublist(1));
  } catch (e) {
    Log.debug('Error: $e');
    exitCode = 1;
  }
}

void debugUsage() {
  Log.debug('''
FlintDart CLI

Usage: flint <command> [options]

Available commands:
${commands.entries.map((e) => '  ${e.key.padRight(20)}${e.value.description}').join('\n')}
''');
}
