// bin/flint_cli.dart
import 'dart:io';

import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/cli/create_project_command.dart';
import 'package:flint_dart/src/cli/db_commands.dart';
import 'package:flint_dart/src/cli/generate_docs_command.dart';
import 'package:flint_dart/src/cli/make_controller_command.dart';
import 'package:flint_dart/src/cli/make_mail_command.dart';
import 'package:flint_dart/src/cli/make_middleware_command.dart';
import 'package:flint_dart/src/cli/make_model_command.dart';

final Map<String, FlintCommand> commands = {
  'create': CreateProjectCommand(),
  'start': RunServerCommand(),
  'run': RunServerCommand(),
  'migrate': DBMigrateCommand(),
  'make:model': MakeModelCommand(), // ✅ Add this
  'make:controller': MakeControllerCommand(), // ✅ Add this
  'make:middleware': MakeMiddlewareCommand(), // ✅ Add this
  'docs:generate': GenerateDocsCommand(), // ✅ Add this
  'make:mail': MakeMailCommand(), // ✅ Add this line
};
void main(List<String> args) async {
  if (args.isEmpty || !commands.containsKey(args[0])) {
    print('''
FlintDart CLI

Usage: flint <command> [options]

Available commands:
${commands.entries.map((e) => '  ${e.key.padRight(10)}${e.value.description}').join('\n')}
''');
    return;
  }

  try {
    await commands[args[0]]!.execute(args.sublist(1));
  } catch (e) {
    print('Error: $e');
    exitCode = 1;
  }
}
