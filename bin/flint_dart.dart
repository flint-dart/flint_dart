import 'dart:io';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/agent_docs_command.dart';
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
import 'package:flint_dart/src/cli/make_page_command.dart';
import 'package:flint_dart/src/cli/make_resource_command.dart';
import 'package:flint_dart/src/cli/make_route_command.dart';
import 'package:flint_dart/src/cli/make_seeder_command.dart';
import 'package:flint_dart/src/cli/make_ui_command.dart';
import 'package:flint_dart/src/cli/stop_port_command.dart';
import 'package:flint_dart/src/cli/update_command.dart';
import 'package:flint_dart/src/cli/upgrade_command.dart';
import 'package:flint_dart/src/cli/version_commands.dart';
import 'package:flint_dart/src/cli/web_ui_command.dart';

final Map<String, FlintCommand> commands = {
  'create': CreateProjectCommand(),
  'agent': AgentDocsCommand(),
  'start': RunServerCommand(),
  'run': RunServerCommand(),
  'stop': StopPortCommand(),
  'jobs-work': RunJobsWorkerCommand(),
  'build': BuildCommand(),
  'web': WebUiCommand(),
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
  'seed': DbSeedCommand(),
  '--db-seed': DbSeedCommand(),
  '--make-mail': MakeMailCommand(),
  'update': UpdateCommand(),
  'upgrade': UpgradeCommand(),
  'version': VersionCommand(),
  '--version': VersionCommand(),
  '--make-resource': MakeResourceCommand(),
  '--make-route': MakeRouteCommand(),
  '--make-page': MakePageCommand(),
  '--make-ui': MakeUiCommand(),
  '-v': VersionCommand(),
  '--v': VersionCommand(),
};

final Map<String, String> aliasCommands = {
  '--deploy-globe': 'deploy-globe',
  'agents': 'agent',
  'docs:agent': 'agent',
  'docs:agents': 'agent',
  'serve': 'run',
  'server': 'run',
  'port:stop': 'stop',
  'kill-port': 'stop',
  'port-stop': 'stop',
  '--jobs-work': 'jobs-work',
  '--job-work': 'jobs-work',
  'worker': 'jobs-work',
  'jobs': 'jobs-work',
  'jobs:work': 'jobs-work',
  'job:work': 'jobs-work',
  'db:migrate': 'migrate',
  'db-migrate': 'migrate',
  '--seed': 'seed',
  'db:seed': 'seed',
  'db-seed': 'seed',
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
  'make:page': '--make-page',
  'make:ui': '--make-ui',
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
  'make-page': '--make-page',
  'make-ui': '--make-ui',
  'page': '--make-page',
  'ui': '--make-ui',
  'docs-generate': '--docs-generate',
  'route': '--make-route',
  '--build': 'build',
  '--web': 'web',
  'web:run': 'web',
  'web:serve': 'web',
  'web:build': 'web',
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
