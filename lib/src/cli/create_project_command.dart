import 'dart:io';
import 'package:flint_dart/src/cli/commands.dart';

class CreateProjectCommand extends FlintCommand {
  CreateProjectCommand() : super('create', 'Creates a new FlintDart project');

  @override
  Future<void> execute(List<String> args) async {
    String projectName;

    // Ask for project name if not provided
    if (args.isEmpty) {
      stdout.write('👉 What is your project name? ');
      projectName = stdin.readLineSync()?.trim() ?? '';
      if (projectName.isEmpty) {
        print('❌ Project name cannot be empty.');
        return;
      }
    } else {
      projectName = args[0];
    }

    final dir = Directory(projectName);

    if (await dir.exists()) {
      print('❌ Error: Directory "$projectName" already exists');
      return;
    }

    print('🚀 Creating project "$projectName"...');
    final cloneResult = await Process.run(
      'git',
      [
        'clone',
        'https://github.com/flint-dart/flint-dart-sample.git',
        projectName
      ],
    );

    if (cloneResult.exitCode != 0) {
      print('❌ Error creating project: ${cloneResult.stderr}');
      return;
    }

    // Remove .git folder so it’s a fresh project
    await Directory('${dir.path}/.git').delete(recursive: true);

    // Update package name in pubspec.yaml
    final pubspecFile = File('${dir.path}/pubspec.yaml');
    if (await pubspecFile.exists()) {
      String content = await pubspecFile.readAsString();
      content = content.replaceFirst(
        RegExp(r'^name:.*', multiLine: true),
        'name: $projectName',
      );
      await pubspecFile.writeAsString(content);
    }

    // Update "package:sample/" imports
    await _updatePackageImports(dir.path, 'sample', projectName);

    // Run dart pub get
    print('⚙️ Running `dart pub get`...');
    final pubGetResult = await Process.run(
      'dart',
      ['pub', 'get'],
      workingDirectory: dir.path,
    );

    if (pubGetResult.exitCode != 0) {
      print('❌ Failed to run `dart pub get`: ${pubGetResult.stderr}');
      return;
    }

    print(pubGetResult.stdout);
    print('✅ Project "$projectName" created successfully!');
    print('\nTo get started:');
    print('  cd $projectName');
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
