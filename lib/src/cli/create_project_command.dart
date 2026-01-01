import 'dart:io';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';

class CreateProjectCommand extends FlintCommand {
  CreateProjectCommand() : super('create', 'Creates a new Flint Dart project');

  @override
  Future<void> execute(List<String> args) async {
    // 🟦 1. Get project name (prompt if missing)
    String projectName =
        args.isNotEmpty ? args.first.trim() : await _promptProjectName();

    if (projectName.isEmpty) {
      Log.debug('❌ Project name cannot be empty.');
      return;
    }

    final dir = Directory(projectName);
    if (await dir.exists()) {
      Log.debug('❌ Error: Directory "$projectName" already exists.');
      return;
    }

    // 🟦 2. Clone template
    Log.debug('🚀 Creating project "$projectName"...');
    final result = await Process.run(
      'git',
      [
        'clone',
        '--depth',
        '1',
        'https://github.com/flint-dart/flint-dart-sample.git',
        projectName
      ],
    );

    if (result.exitCode != 0) {
      Log.debug('❌ Failed to clone template:\n${result.stderr}');
      return;
    }

    // 🟦 3. Clean up .git folder
    final gitDir = Directory('${dir.path}/.git');
    if (await gitDir.exists()) await gitDir.delete(recursive: true);

    // 🟦 4. Update pubspec name
    final pubspecFile = File('${dir.path}/pubspec.yaml');
    if (await pubspecFile.exists()) {
      var content = await pubspecFile.readAsString();
      content = content.replaceFirst(
          RegExp(r'^name:\s*.*', multiLine: true), 'name: $projectName');
      await pubspecFile.writeAsString(content);
    }

    // 🟦 5. Update internal imports
    await _updatePackageImports(dir.path, 'sample', projectName);

    // 🟦 6. Run pub get
    Log.debug('⚙️ Running `dart pub get`...');
    final pubGet =
        await Process.start('dart', ['pub', 'get'], workingDirectory: dir.path);
    await stdout.addStream(pubGet.stdout);
    await stderr.addStream(pubGet.stderr);
    final exitCode = await pubGet.exitCode;

    if (exitCode != 0) {
      Log.debug('❌ Failed to install dependencies.');
      return;
    }

    // 🟦 7. Success message
    Log.info('\n✅ Project "$projectName" created successfully!');
    Log.info('📂 Location: ${dir.absolute.path}');
    Log.info('\nTo get started:');
    Log.info('  cd $projectName');
    Log.info('  flint run');
  }

  /// Prompts the user for a project name.
  Future<String> _promptProjectName() async {
    stdout.write('👉 What is your project name? ');
    return stdin.readLineSync()?.trim() ?? '';
  }

  /// Updates all Dart imports to reflect the new package name.
  Future<void> _updatePackageImports(
      String root, String oldName, String newName) async {
    final dir = Directory(root);
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        var content = await entity.readAsString();
        if (content.contains('package:$oldName/')) {
          content =
              content.replaceAll('package:$oldName/', 'package:$newName/');
          await entity.writeAsString(content);
        }
      }
    }
  }
}
