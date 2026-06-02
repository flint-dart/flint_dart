import 'dart:async';
import 'dart:io';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/cli/web_ui_builder.dart';
import 'package:path/path.dart' as path;
import 'package:package_config/package_config.dart';

class BuildCommand extends FlintCommand {
  BuildCommand() : super('build', 'Builds the application for production');

  @override
  Future<void> execute(List<String> args) async {
    String? targetPlatform;
    String? entryPointArg;
    const buildDir = 'build';

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
      } else if (args[i] == '--macos') {
        targetPlatform = 'macos';
      } else if (args[i] == '--both') {
        targetPlatform = 'both';
      } else if (args[i] == '--help' || args[i] == '-h') {
        _printHelp();
        return;
      } else if (args[i] == '--platform' || args[i] == '--entry') {
        Log.debug('Missing value for ${args[i]}');
        _printHelp();
        exit(1);
      } else {
        Log.debug('Unknown option: ${args[i]}');
        _printHelp();
        exit(1);
      }
    }

    if (!_isValidTargetPlatform(targetPlatform)) {
      Log.debug('Invalid --platform value: $targetPlatform');
      _printHelp();
      exit(1);
    }

    final entryPoint = await _resolveEntryPoint(entryPointArg);
    final compileTargets = _resolveCompileTargets(targetPlatform);

    Log.debug('Building Flint application...');

    final buildDirectory = Directory(buildDir);
    if (await buildDirectory.exists()) {
      Log.debug('Removing previous build...');
      buildDirectory.deleteSync(recursive: true);
    }
    buildDirectory.createSync(recursive: true);

    await _buildWebUiAssets();

    final pubspec = await File('pubspec.yaml').readAsString();
    final match = RegExp(r'name:\s*(\S+)').firstMatch(pubspec);
    if (match == null) {
      Log.debug('Error: Missing project name in pubspec.yaml');
      exit(1);
    }
    final projectName = match.group(1)!.trim();

    Log.debug('Copying non-Dart resources...');
    await _copyNonDartFilesWithSpinner(
        Directory.current, buildDirectory, buildDir);
    _copySwaggerSpec(buildDir);
    await _copySwaggerUiAssets(buildDir);
    await FlintWebUiBuilder.precompressDirectory(
      Directory(path.join(buildDir, 'public')),
    );

    final builtExecutables = <String, String>{};
    for (final target in compileTargets) {
      final exeName = _executableNameForTarget(projectName, target);
      final exePath = path.join(buildDir, exeName);

      Log.debug('Compiling $entryPoint for ${target.toUpperCase()}...');
      final result = await Process.run(
        'dart',
        ['compile', 'exe', entryPoint, '--target-os', target, '-o', exePath],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        Log.debug('Build failed for target $target:');
        Log.debug(result.stderr.toString());
        exit(1);
      }

      builtExecutables[target] = exeName;
      Log.debug('Executable generated: $exePath');
    }

    _createStartScripts(buildDir, builtExecutables, targetPlatform);
    _createDockerfile(
      buildDir,
      linuxExecutableName: builtExecutables['linux'],
    );

    Log.debug('Build completed successfully.');
    Log.debug('Output directory: $buildDir/');
    _printRunInstructions(buildDir, builtExecutables, targetPlatform);
  }

  bool _isValidTargetPlatform(String? targetPlatform) {
    return targetPlatform == null ||
        targetPlatform == 'linux' ||
        targetPlatform == 'windows' ||
        targetPlatform == 'macos' ||
        targetPlatform == 'both';
  }

  List<String> _resolveCompileTargets(String? targetPlatform) {
    if (targetPlatform == null) return [_hostTargetOs()];
    if (targetPlatform == 'both') return ['linux', 'windows'];
    return [targetPlatform];
  }

  String _hostTargetOs() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    return 'linux';
  }

  String _executableNameForTarget(String projectName, String targetPlatform) {
    return targetPlatform == 'windows' ? '$projectName.exe' : projectName;
  }

  Future<String> _resolveEntryPoint(String? entryPointArg) async {
    if (entryPointArg != null) {
      final customEntry = File(entryPointArg);
      if (!await customEntry.exists()) {
        Log.debug('Entry file not found: $entryPointArg');
        exit(1);
      }
      return entryPointArg;
    }

    const candidates = ['bin/server.dart', 'bin/main.dart', 'lib/main.dart'];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }

    Log.debug(
        'No entry point found. Expected one of: ${candidates.join(', ')}');
    Log.debug('Or provide a custom entry with --entry <path>');
    exit(1);
  }

  Future<void> _buildWebUiAssets() async {
    final build = FlintWebUiBuilder.resolve();
    if (build == null) {
      Log.debug('No Flint Web UI entry point found. Skipping web asset build.');
      return;
    }

    Log.debug('Building Flint Web UI assets...');
    try {
      await FlintWebUiBuilder.compileSharedRuntimeBundle(build);
      return;
    } on StateError catch (e) {
      Log.debug('Shared Flint UI runtime skipped: ${e.message}');
    }

    await FlintWebUiBuilder.compile(build);
    try {
      await FlintWebUiBuilder.compilePageBundles(build);
    } on StateError catch (e) {
      Log.debug('Page-level Flint UI bundles skipped: ${e.message}');
    }
  }

  Future<void> _copyNonDartFilesWithSpinner(
      Directory source, Directory target, String buildDirName) async {
    final spinnerChars = ['|', '/', '-', '\\'];
    var spinnerIndex = 0;
    var copying = true;

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!copying) {
        stdout.write('\r');
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

  void _createStartScripts(String buildDir,
      Map<String, String> builtExecutables, String? targetPlatform) {
    final currentPlatform = _hostTargetOs();

    final linuxExeName = builtExecutables['linux'];
    final macExeName = builtExecutables['macos'];
    final windowsExeName = builtExecutables['windows'];

    if (linuxExeName != null) {
      _createLinuxStartScript(buildDir, linuxExeName);
      Log.debug('Created Linux start script: start.sh');
    }

    if (macExeName != null && linuxExeName == null) {
      _createLinuxStartScript(buildDir, macExeName);
      Log.debug('Created macOS start script: start.sh');
    }

    if (windowsExeName != null) {
      _createWindowsStartScript(buildDir, windowsExeName);
      Log.debug('Created Windows start script: start.bat');
    }

    if (targetPlatform != null) {
      Log.debug('Target platform: ${targetPlatform.toUpperCase()}');
    } else {
      Log.debug('Detected platform: ${currentPlatform.toUpperCase()}');
    }
  }

  void _copySwaggerSpec(String buildDir) {
    final candidates = [
      File(path.join('docs', 'swagger.json')),
      File('swagger.json'),
    ];

    File? source;
    for (final candidate in candidates) {
      if (candidate.existsSync()) {
        source = candidate;
        break;
      }
    }

    if (source == null) {
      Log.debug(
          'No swagger.json found (checked docs/swagger.json, swagger.json).');
      return;
    }

    final targets = [
      File(path.join(buildDir, 'public', 'swagger.json')),
      File(path.join(buildDir, 'public', 'docs', 'swagger.json')),
    ];

    for (final target in targets) {
      target.parent.createSync(recursive: true);
      source.copySync(target.path);
      Log.debug('Copied Swagger spec: ${source.path} -> ${target.path}');
    }
  }

  Future<void> _copySwaggerUiAssets(String buildDir) async {
    final source = await _resolveSwaggerUiSourceDir();
    if (source == null) {
      Log.debug(
          'No swagger-ui assets found (checked package and local framework paths).');
      return;
    }

    final targetDir = Directory(path.join(buildDir, 'public', 'swagger-ui'));
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    _copyDirectoryContents(source, targetDir);
    Log.debug('Copied Swagger UI assets: ${source.path} -> ${targetDir.path}');
  }

  Future<Directory?> _resolveSwaggerUiSourceDir() async {
    final candidates = <String>[
      path.join(Directory.current.path, 'lib', 'swagger', 'swagger-ui'),
      path.join(
          Directory.current.path, 'flint_dart', 'lib', 'swagger', 'swagger-ui'),
      path.join(Directory.current.path, '..', 'flint_dart', 'lib', 'swagger',
          'swagger-ui'),
    ];

    try {
      final packageConfig = await findPackageConfig(Directory.current);
      final flintPackage = packageConfig?['flint_dart'];
      if (flintPackage != null) {
        candidates.insert(
            0,
            path.join(flintPackage.root.toFilePath(windows: Platform.isWindows),
                'lib', 'swagger', 'swagger-ui'));
      }
    } catch (_) {
      // Ignore package resolution errors and continue with local fallbacks.
    }

    for (final dirPath in candidates) {
      final dir = Directory(dirPath);
      if (await dir.exists()) return dir;
    }
    return null;
  }

  void _copyDirectoryContents(Directory source, Directory target) {
    for (final entity in source.listSync(recursive: false)) {
      final name = path.basename(entity.path);
      final targetPath = path.join(target.path, name);
      if (entity is File) {
        File(targetPath).parent.createSync(recursive: true);
        entity.copySync(targetPath);
      } else if (entity is Directory) {
        final subDir = Directory(targetPath)..createSync(recursive: true);
        _copyDirectoryContents(entity, subDir);
      }
    }
  }

  void _createLinuxStartScript(String buildDir, String exeName) {
    final content = '''#!/bin/bash
set -e

echo "Starting Flint Application..."

# Ensure executable bit exists even if artifacts were published from Windows.
if [ ! -x "./$exeName" ]; then
  chmod +x "./$exeName"
fi

exec "./$exeName"
''';
    final file = File(path.join(buildDir, 'start.sh'));
    file.writeAsStringSync(content);
    if (!Platform.isWindows) Process.runSync('chmod', ['+x', file.path]);
  }

  void _createWindowsStartScript(String buildDir, String exeName) {
    final content = '''
@echo off
echo Starting Flint Application...
$exeName
''';
    File(path.join(buildDir, 'start.bat')).writeAsStringSync(content);
  }

  void _createDockerfile(String buildDir, {String? linuxExecutableName}) {
    if (linuxExecutableName == null) {
      Log.debug(
          'Skipping Dockerfile generation (no Linux binary built). Use --linux or --both.');
      return;
    }

    final content = '''FROM debian:bookworm-slim

WORKDIR /app

RUN apt-get update \\
    && apt-get install -y --no-install-recommends ca-certificates bash \\
    && rm -rf /var/lib/apt/lists/*

# Copy prebuilt app bundle from this build directory.
COPY . /app

RUN if [ -f /app/start.sh ]; then chmod +x /app/start.sh; fi \\
    && if [ -f /app/$linuxExecutableName ]; then chmod +x /app/$linuxExecutableName; fi

ENV FLINT_HOT=0
ENV PORT=3000
EXPOSE 3000

CMD ["./start.sh"]
''';

    File(path.join(buildDir, 'Dockerfile')).writeAsStringSync(content);
    Log.debug('Created Dockerfile: Dockerfile');
  }

  void _printRunInstructions(String buildDir,
      Map<String, String> builtExecutables, String? targetPlatform) {
    Log.debug('To run your application:');
    final hasPosix = builtExecutables.containsKey('linux') ||
        builtExecutables.containsKey('macos');
    final hasWindows = builtExecutables.containsKey('windows');

    if (hasPosix) Log.debug('  Linux/Mac:   cd $buildDir && ./start.sh');
    if (hasWindows) Log.debug('  Windows:     cd $buildDir && start.bat');

    if (targetPlatform == 'both') {
      Log.debug('Note: both Linux and Windows binaries were created.');
    }
  }

  void _printHelp() {
    Log.debug('''
Usage: flint build [options]

Options:
  --entry <path>       Entry file to compile (default order: bin/server.dart, bin/main.dart, lib/main.dart)
  --platform <value>   linux | windows | macos | both
  --linux              Shortcut for --platform linux
  --windows            Shortcut for --platform windows
  --macos              Shortcut for --platform macos
  --both               Build both Linux and Windows binaries
  --help, -h           Show this help
''');
  }
}
