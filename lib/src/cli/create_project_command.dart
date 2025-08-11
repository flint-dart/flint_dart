import 'dart:io';
import 'package:flint_dart/src/cli/commands.dart';

class CreateProjectCommand extends FlintCommand {
  CreateProjectCommand() : super('create', 'Creates a new FlintDart project');

  @override
  Future<void> execute(List<String> args) async {
    final projectName = args.isNotEmpty ? args[0] : 'my_flint_app';
    final dir = Directory(projectName);

    if (await dir.exists()) {
      print('Error: Directory "$projectName" already exists');
      return;
    }

    print('Cloning Flint Dart sample project...');
    final cloneResult = await Process.run(
      'git',
      [
        'clone',
        'https://github.com/flint-dart/flint-dart-sample.git',
        projectName
      ],
    );

    if (cloneResult.exitCode != 0) {
      print('Error cloning repo: ${cloneResult.stderr}');
      return;
    }

    // Remove .git so it's a fresh project
    await Directory('${dir.path}/.git').delete(recursive: true);

    // Change package name in pubspec.yaml
    final pubspecFile = File('${dir.path}/pubspec.yaml');
    if (await pubspecFile.exists()) {
      String content = await pubspecFile.readAsString();
      content = content.replaceFirst(
        RegExp(r'^name:.*', multiLine: true),
        'name: $projectName',
      );
      await pubspecFile.writeAsString(content);
    }

    // Update all "package:sample/" imports to new project name
    await _updatePackageImports(dir.path, 'sample', projectName);

    print('Project "$projectName" created successfully!');
    print('To get started:');
    print('  cd $projectName');
    print('  dart pub get');
    print('  flint run');
  }

  Future<void> _updatePackageImports(
      String rootPath, String oldName, String newName) async {
    final dir = Directory(rootPath);

    await for (var entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        String content = await entity.readAsString();
        if (content.contains('package:$oldName/')) {
          content =
              content.replaceAll('package:$oldName/', 'package:$newName/');
          await entity.writeAsString(content);
        }
      }
    }
  }
}
