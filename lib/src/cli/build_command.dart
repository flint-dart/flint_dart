import 'dart:async';
import 'dart:io';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:path/path.dart' as path;

class BuildCommand extends FlintCommand {
  BuildCommand() : super('build', 'Builds the application for production');

  @override
  Future<void> execute(List<String> args) async {
    String? targetPlatform;
    final buildDir = 'build';

    // Parse platform arguments
    for (var i = 0; i < args.length; i++) {
      if (args[i] == '--platform' && i + 1 < args.length) {
        targetPlatform = args[i + 1].toLowerCase();
      } else if (args[i] == '--linux') {
        targetPlatform = 'linux';
      } else if (args[i] == '--windows') {
        targetPlatform = 'windows';
      } else if (args[i] == '--both') {
        targetPlatform = 'both';
      }
    }

    print('🏗️  Building Flint application...');

    // Reset build directory
    final buildDirectory = Directory(buildDir);
    if (buildDirectory.existsSync()) {
      print('🧹 Removing previous build...');
      buildDirectory.deleteSync(recursive: true);
    }
    buildDirectory.createSync(recursive: true);

    // Load project name from pubspec.yaml
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'name:\s*(\S+)').firstMatch(pubspec);
    if (match == null) {
      print('❌ Error: Missing project name in pubspec.yaml');
      exit(1);
    }
    final projectName = match.group(1)!.trim();

    // Determine executable path
    final exeName = Platform.isWindows ? '$projectName.exe' : projectName;
    final exePath = path.join(buildDir, exeName);

    print('🔨 Compiling Dart executable...');
    final result = await Process.run(
      'dart',
      ['compile', 'exe', 'lib/main.dart', '-o', exePath],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      print('❌ Build failed:');
      print(result.stderr);
      exit(1);
    }

    print('✅ Executable generated: $exePath');

    // Copy files with loading spinner
    print('📦 Copying non-Dart resources...');
    await _copyNonDartFilesWithSpinner(
        Directory.current, buildDirectory, buildDir);

    // Create start scripts
    _createStartScripts(buildDir, exeName, targetPlatform);

    print('\n🎉 Build completed successfully!');
    print('📁 Output directory: $buildDir/');
    _printRunInstructions(buildDir, targetPlatform);
  }

  // Spinner wrapper for copying files
  Future<void> _copyNonDartFilesWithSpinner(
      Directory source, Directory target, String buildDirName) async {
    final spinnerChars = ['|', '/', '-', '\\'];
    int spinnerIndex = 0;
    bool copying = true;

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!copying) {
        stdout.write('\r'); // clear spinner
        timer.cancel();
      } else {
        stdout.write(
            '\r${spinnerChars[spinnerIndex % spinnerChars.length]} Copying files...');
        spinnerIndex++;
      }
    });

    await _copyFilesRecursively(source, target, buildDirName);

    copying = false;
  }

  // Recursive file copy
  Future<void> _copyFilesRecursively(
      Directory source, Directory target, String buildDirName) async {
    for (final entity in source.listSync(recursive: false)) {
      final relativePath = path.relative(entity.path, from: source.path);

      if (relativePath == buildDirName ||
          [
            '.dart_tool',
            '.git',
            '.idea',
            'doc',
            '.vscode',
            'pubspec.yaml',
            'pubspec.lock'
          ].contains(relativePath)) {
        continue;
      }

      final targetPath = path.join(target.path, relativePath);

      if (entity is File) {
        if (!entity.path.endsWith('.dart')) {
          File(targetPath).parent.createSync(recursive: true);
          if (entity.existsSync()) entity.copySync(targetPath);
        }
      } else if (entity is Directory) {
        await _copyFilesRecursively(
            entity, Directory(targetPath), buildDirName);
      }
    }
  }

  void _createStartScripts(
      String buildDir, String exeName, String? targetPlatform) {
    final currentPlatform = Platform.isWindows ? 'windows' : 'linux';
    final createLinux = targetPlatform == 'linux' ||
        targetPlatform == 'both' ||
        (targetPlatform == null && !Platform.isWindows);
    final createWindows = targetPlatform == 'windows' ||
        targetPlatform == 'both' ||
        (targetPlatform == null && Platform.isWindows);

    if (createLinux) {
      _createLinuxStartScript(buildDir, exeName);
      print('🐧 Created Linux start script: start.sh');
    }

    if (createWindows) {
      _createWindowsStartScript(buildDir, exeName);
      print('🪟 Created Windows start script: start.bat');
    }

    if (targetPlatform != null) {
      print('🎯 Target platform: ${targetPlatform.toUpperCase()}');
    } else {
      print('💻 Detected platform: ${currentPlatform.toUpperCase()}');
    }
  }

  void _createLinuxStartScript(String buildDir, String exeName) {
    final content = '''#!/bin/bash
echo "🚀 Starting Flint Application..."
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi
./$exeName
''';
    final file = File(path.join(buildDir, 'start.sh'));
    file.writeAsStringSync(content);
    if (!Platform.isWindows) Process.run('chmod', ['+x', file.path]);
  }

  void _createWindowsStartScript(String buildDir, String exeName) {
    final content = '''
@echo off
echo 🚀 Starting Flint Application...
if exist .env (
    for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
        set "%%A=%%B"
    )
)
$exeName
''';
    File(path.join(buildDir, 'start.bat')).writeAsStringSync(content);
  }

  void _printRunInstructions(String buildDir, String? targetPlatform) {
    print('\n🚀 To run your application:');
    final createLinux = targetPlatform == 'linux' ||
        targetPlatform == 'both' ||
        (targetPlatform == null && !Platform.isWindows);
    final createWindows = targetPlatform == 'windows' ||
        targetPlatform == 'both' ||
        (targetPlatform == null && Platform.isWindows);

    if (createLinux) print('   💻 Linux/Mac:   cd $buildDir && ./start.sh');
    if (createWindows) print('   🪟 Windows:     cd $buildDir && start.bat');

    if (targetPlatform == 'both') {
      print('\n📝 Note: Both Linux and Windows start scripts were created.');
      print('   Use the appropriate script for your target platform.');
    }
  }
}
