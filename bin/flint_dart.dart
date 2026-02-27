import 'dart:io';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/build_command.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/cli/create_project_command.dart';
import 'package:flint_dart/src/cli/db_commands.dart';
import 'package:flint_dart/src/cli/db_admin_commands.dart';
import 'package:flint_dart/src/cli/db_seed_command.dart';
import 'package:flint_dart/src/cli/deploy_globe_command.dart';
import 'package:flint_dart/src/cli/generate_docs_command.dart';
import 'package:flint_dart/src/cli/make_controller_command.dart';
import 'package:flint_dart/src/cli/make_docker_command.dart';
import 'package:flint_dart/src/cli/make_isolate_command.dart';
import 'package:flint_dart/src/cli/make_mail_command.dart';
import 'package:flint_dart/src/cli/make_middleware_command.dart';
import 'package:flint_dart/src/cli/make_model_command.dart';
import 'package:flint_dart/src/cli/make_resource_command.dart';
import 'package:flint_dart/src/cli/make_route_command.dart';
import 'package:flint_dart/src/cli/make_seeder_command.dart';
import 'package:flint_dart/src/cli/update_command.dart';
import 'package:flint_dart/src/cli/upgrade_command.dart';
import 'package:flint_dart/src/cli/version_commands.dart';

final Map<String, FlintCommand> commands = {
  'create': CreateProjectCommand(),
  'start': RunServerCommand(),
  'run': RunServerCommand(),
  'build': BuildCommand(),
  '--make-docker': MakeDockerCommand(),
  'deploy-globe': DeployGlobeCommand(),
  'migrate': DBMigrateCommand(),
  '--db-create': DBCreateCommand(),
  '--db-user-create': DBUserCreateCommand(),
  '--db-export': DBExportCommand(),
  '--db-table-export': DBTableExportCommand(),
  '--make-model': MakeModelCommand(),
  '--make-controller': MakeControllerCommand(),
  '--make-middleware': MakeMiddlewareCommand(),
  '--make-isolate': MakeIsolateCommand(),
  '--docs-generate': GenerateDocsCommand(),
  '--make-seeder': MakeSeederCommand(),
  '--db-seed': DbSeedCommand(),
  '--make-mail': MakeMailCommand(),
  'update': UpdateCommand(),
  'upgrade': UpgradeCommand(),
  'version': VersionCommand(),
  '--make-resource': MakeResourceCommand(),
  '--make-route': MakeRouteCommand(),
  '--v': VersionCommand(),
};

final Map<String, String> aliasCommands = {
  '--deploy-globe': 'deploy-globe',
  '--seed': '--db-seed',
  'seed': '--db-seed',
  'db:seed': '--db-seed',
  'db-seed': '--db-seed',
  'db:create': '--db-create',
  'db:user:create': '--db-user-create',
  'db:export': '--db-export',
  'db:table:export': '--db-table-export',
  'db-create': '--db-create',
  'db-user-create': '--db-user-create',
  'db-export': '--db-export',
  'db-table-export': '--db-table-export',
  'make:mail': '--make-mail',
  'make:model': '--make-model',
  'make:controller': '--make-controller',
  'make:resource': '--make-resource',
  'make:middleware': '--make-middleware',
  'make:docker': '--make-docker',
  'make:isolate': '--make-isolate',
  'make:seeder': '--make-seeder',
  'make:route': '--make-route',
  'docs:generate': '--docs-generate',
  'make-mail': '--make-mail',
  'make-model': '--make-model',
  'make-controller': '--make-controller',
  'make-resource': '--make-resource',
  'make-middleware': '--make-middleware',
  'make-docker': '--make-docker',
  'make-isolate': '--make-isolate',
  'make-seeder': '--make-seeder',
  'make-route': '--make-route',
  'docs-generate': '--docs-generate',
  'route': '--make-route',
  '--build': 'build',
  '--update': 'update',
  '--upgrade': 'upgrade',
};

void main(List<String> args) async {
  if (args.isEmpty) {
    debugUsage();
    return;
  }

  final firstArg = aliasCommands[args[0]] ?? args[0];

  if (!commands.containsKey(firstArg)) {
    Log.debug('Unknown command: ${args[0]}');
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
