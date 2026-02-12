import 'dart:async';
import 'dart:io';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:path/path.dart' as path;

class BuildCommand extends FlintCommand {
  BuildCommand() : super('build', 'Builds the application for production');

  @override
  Future<void> execute(List<String> args) async {
    String? targetPlatform;
    String? entryPointArg;
    final buildDir = 'build';

    // Parse platform arguments
    for (var i = 0; i < args.length; i++) {
      if (args[i] == '--platform' && i + 1 < args.length) {
        targetPlatform = args[i + 1].toLowerCase();
        i++;
      } else if (args[i] == '--entry' && i + 1 < args.length) {
        entryPointArg = args[i + 1];
        i++;
      } else if (args[i] == '--linux') {
        targetPlatform = 'linux';
      } else if (args[i] == '--windows') {
        targetPlatform = 'windows';
      } else if (args[i] == '--both') {
        targetPlatform = 'both';
      } else if (args[i] == '--help' || args[i] == '-h') {
        _printHelp();
        return;
      } else if (args[i] == '--platform' || args[i] == '--entry') {
        Log.debug('❌ Missing value for ${args[i]}');
        _printHelp();
        exit(1);
      } else {
        Log.debug('❌ Unknown option: ${args[i]}');
        _printHelp();
        exit(1);
      }
    }

    if (!_isValidTargetPlatform(targetPlatform)) {
      Log.debug('❌ Invalid --platform value: $targetPlatform');
      _printHelp();
      exit(1);
    }

    _validateTargetPlatform(targetPlatform);

    final entryPoint = await _resolveEntryPoint(entryPointArg);

    Log.debug('🏗️  Building Flint application...');

    // Reset build directory
    final buildDirectory = Directory(buildDir);
    if (await buildDirectory.exists()) {
      Log.debug('🧹 Removing previous build...');
      buildDirectory.deleteSync(recursive: true);
    }
    buildDirectory.createSync(recursive: true);

    // Load project name from pubspec.yaml
    final pubspec = await File('pubspec.yaml').readAsString();
    final match = RegExp(r'name:\s*(\S+)').firstMatch(pubspec);
    if (match == null) {
      Log.debug('❌ Error: Missing project name in pubspec.yaml');
      exit(1);
    }
    final projectName = match.group(1)!.trim();

    // Determine executable path
    final exeName = Platform.isWindows ? '$projectName.exe' : projectName;
    final exePath = path.join(buildDir, exeName);

    Log.debug('🔨 Compiling Dart executable from $entryPoint...');
    final result = await Process.run(
      'dart',
      ['compile', 'exe', entryPoint, '-o', exePath],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      Log.debug('❌ Build failed:');
      Log.debug(result.stderr);
      exit(1);
    }

    Log.debug('✅ Executable generated: $exePath');

    // Copy files with loading spinner
    Log.debug('📦 Copying non-Dart resources...');
    await _copyNonDartFilesWithSpinner(
        Directory.current, buildDirectory, buildDir);

    // Create start scripts
    _createStartScripts(buildDir, exeName, targetPlatform);
    _createDockerfile(buildDir);

    Log.debug('\n🎉 Build completed successfully!');
    Log.debug('📁 Output directory: $buildDir/');
    _printRunInstructions(buildDir, targetPlatform);
  }

  bool _isValidTargetPlatform(String? targetPlatform) {
    return targetPlatform == null ||
        targetPlatform == 'linux' ||
        targetPlatform == 'windows' ||
        targetPlatform == 'both';
  }

  void _validateTargetPlatform(String? targetPlatform) {
    if (targetPlatform == null) return;
    if (targetPlatform == 'both') {
      Log.debug(
          '⚠️  --both creates both start scripts; executable is still built for the current OS only.');
      return;
    }

    final hostPlatform = Platform.isWindows ? 'windows' : 'linux';
    if (targetPlatform != hostPlatform) {
      Log.debug(
          '❌ Cross-compilation is not supported. Current host is $hostPlatform but requested $targetPlatform.');
      Log.debug(
          '   Build on the target OS or use --both only for script generation.');
      exit(1);
    }
  }

  Future<String> _resolveEntryPoint(String? entryPointArg) async {
    if (entryPointArg != null) {
      final customEntry = File(entryPointArg);
      if (!await customEntry.exists()) {
        Log.debug('❌ Entry file not found: $entryPointArg');
        exit(1);
      }
      return entryPointArg;
    }

    const candidates = ['bin/server.dart', 'bin/main.dart', 'lib/main.dart'];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }

    Log.debug(
        '❌ No entry point found. Expected one of: ${candidates.join(', ')}');
    Log.debug('   Or provide a custom entry with --entry <path>');
    exit(1);
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
          if (await entity.exists()) entity.copySync(targetPath);
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
      Log.debug('🐧 Created Linux start script: start.sh');
    }

    if (createWindows) {
      _createWindowsStartScript(buildDir, exeName);
      Log.debug('🪟 Created Windows start script: start.bat');
    }

    if (targetPlatform != null) {
      Log.debug('🎯 Target platform: ${targetPlatform.toUpperCase()}');
    } else {
      Log.debug('💻 Detected platform: ${currentPlatform.toUpperCase()}');
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
    if (!Platform.isWindows) Process.runSync('chmod', ['+x', file.path]);
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

  void _createDockerfile(String buildDir) {
    final content = '''FROM debian:bookworm-slim

WORKDIR /app

RUN apt-get update \\
    && apt-get install -y --no-install-recommends ca-certificates bash \\
    && rm -rf /var/lib/apt/lists/*

# Copy prebuilt app bundle from this build directory.
COPY . /app

RUN chmod +x /app/start.sh \\
    && find /app -maxdepth 1 -type f -perm -u=x -exec chmod +x {} +

ENV FLINT_HOT=0
ENV PORT=3000
EXPOSE 3000

CMD ["./start.sh"]
''';

    File(path.join(buildDir, 'Dockerfile')).writeAsStringSync(content);
    Log.debug('🐳 Created Dockerfile: Dockerfile');
  }

  void _printRunInstructions(String buildDir, String? targetPlatform) {
    Log.debug('\n🚀 To run your application:');
    final createLinux = targetPlatform == 'linux' ||
        targetPlatform == 'both' ||
        (targetPlatform == null && !Platform.isWindows);
    final createWindows = targetPlatform == 'windows' ||
        targetPlatform == 'both' ||
        (targetPlatform == null && Platform.isWindows);

    if (createLinux) Log.debug('   💻 Linux/Mac:   cd $buildDir && ./start.sh');
    if (createWindows) {
      Log.debug('   🪟 Windows:     cd $buildDir && start.bat');
    }

    if (targetPlatform == 'both') {
      Log.debug(
          '\n📝 Note: Both Linux and Windows start scripts were created.');
      Log.debug('   Use the appropriate script for your target platform.');
    }
  }

  void _printHelp() {
    Log.debug('''
Usage: flint build [options]

Options:
  --entry <path>       Entry file to compile (default order: bin/server.dart, bin/main.dart, lib/main.dart)
  --platform <value>   linux | windows | both
  --linux              Shortcut for --platform linux
  --windows            Shortcut for --platform windows
  --both               Create both Linux and Windows start scripts
  --help, -h           Show this help
''');
  }
}
