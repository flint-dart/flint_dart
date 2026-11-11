import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/cli/web_ui_builder.dart';
import 'package:flint_dart/src/env_parser.dart';
import 'package:path/path.dart' as path;
import 'package:package_config/package_config.dart';

class BuildCommand extends FlintCommand {
  BuildCommand() : super('build', 'Builds the application for production');

  @override
  Future<void> execute(List<String> args) async {
    String? targetPlatform;
    String? entryPointArg;
    String? flavorArg;
    var sharedRuntime = false;
    var skipWeb = false;
    var forceRebuildWeb = false;
    var pushToBranch = false;
    var buildBranch = 'build';
    const buildDir = 'build';

    for (var i = 0; i < args.length; i++) {
      if (args[i] == '--platform' && i + 1 < args.length) {
        targetPlatform = args[i + 1].toLowerCase();
        i++;
      } else if (args[i] == '--entry' && i + 1 < args.length) {
        entryPointArg = args[i + 1];
        i++;
      } else if (args[i].startsWith('--flavor=')) {
        flavorArg = args[i].substring('--flavor='.length);
      } else if (args[i] == '--flavor' && i + 1 < args.length) {
        flavorArg = args[++i];
      } else if (args[i] == '--shared-runtime') {
        sharedRuntime = true;
        forceRebuildWeb = true;
      } else if (args[i] == '--page-bundles' || args[i] == '--no-shared-runtime') {
        sharedRuntime = false;
      } else if (args[i] == '--rebuild-web') {
        forceRebuildWeb = true;
      } else if (args[i] == '--skip-web' || args[i] == '--no-web') {
        skipWeb = true;
      } else if (args[i] == '--push') {
        pushToBranch = true;
      } else if (args[i].startsWith('--push-branch=')) {
        pushToBranch = true;
        buildBranch = args[i].substring('--push-branch='.length).trim();
      } else if (args[i] == '--push-branch' && i + 1 < args.length) {
        pushToBranch = true;
        buildBranch = args[++i].trim();
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
      } else if (args[i] == '--platform' ||
          args[i] == '--entry' ||
          args[i] == '--push-branch') {
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

    if (flavorArg != null && flavorArg.trim().isNotEmpty) {
      FlintEnv.setFlavor(flavorArg);
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

    if (!skipWeb) {
      await _buildWebUiAssets(
        sharedRuntime: sharedRuntime,
        forceRebuildWeb: forceRebuildWeb,
        flavorArg: flavorArg,
      );
    } else {
      Log.debug('Skipping Web UI compilation (--skip-web).');
    }

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
    Directory(path.join(buildDir, 'public', 'downloads'))
        .createSync(recursive: true);
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
        [
          'compile',
          'exe',
          entryPoint,
          if (flavorArg != null) '--define=FLAVOR=$flavorArg',
          '--target-os',
          target,
          '-o',
          exePath,
        ],
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

    if (pushToBranch) {
      await _pushBuildDirectoryToBranch(buildDir, buildBranch);
    }
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

  Future<void> _buildWebUiAssets({
    required bool sharedRuntime,
    required bool forceRebuildWeb,
    String? flavorArg,
  }) async {
    final build = FlintWebUiBuilder.resolve();
    if (build == null) {
      Log.debug('No Flint Web UI entry point found. Skipping web asset build.');
      return;
    }

    final manifestDir = Directory(path.join('public', 'assets', 'js', 'flint-ui'));
    final mainManifestFile = File(path.join(manifestDir.path, 'manifest.json'));

    if (!forceRebuildWeb &&
        !sharedRuntime &&
        _hasValidPrebuiltPageBundles(mainManifestFile)) {
      Log.debug(
        'Reusing existing pre-built page-by-page Web UI bundles (pass --rebuild-web to force full recompile).',
      );
      return;
    }

    Log.debug(
      'Building Flint Web UI assets (${sharedRuntime ? 'shared runtime' : 'page bundles'})...',
    );
    if (sharedRuntime) {
      try {
        await FlintWebUiBuilder.compileSharedRuntimeBundle(build);
      } on StateError catch (e) {
        Log.debug(
          'Shared runtime skipped (${e.message}). Falling back to standard bundle compilation...',
        );
        await FlintWebUiBuilder.compile(build);
      }
    } else {
      await FlintWebUiBuilder.compile(build);
      try {
        await FlintWebUiBuilder.compilePageBundles(build);
      } on StateError catch (e) {
        Log.debug('Page-level Flint UI bundles skipped: ${e.message}');
      }
    }
  }

  bool _hasValidPrebuiltPageBundles(File manifestFile) {
    if (!manifestFile.existsSync()) return false;
    try {
      final decoded =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      if (decoded['mode'] != 'page-bundles') return false;
      final pages = decoded['pages'];
      if (pages is! Map || pages.isEmpty) return false;
      for (final value in pages.values) {
        final assetUrl = value?.toString() ?? '';
        if (assetUrl.isEmpty) return false;
        final relPath = assetUrl.replaceFirst(RegExp(r'^/+'), '');
        final diskFile = File(path.join('public', relPath));
        if (!diskFile.existsSync()) return false;
      }
      return true;
    } catch (_) {
      return false;
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

  bool _shouldSkipPath(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    final base = path.basename(normalized);

    const topLevelSkips = {
      '.dart_tool',
      '.git',
      '.idea',
      'doc',
      '.vscode',
      'test',
      'tool',
      'pubspec.yaml',
      'pubspec.lock',
      '.gitignore',
      '.dockerignore',
      'docker-compose.yml',
      'deploy.sh',
    };
    if (topLevelSkips.contains(normalized)) return true;
    if (base == 'Dockerfile' || base.startsWith('Dockerfile.')) return true;

    // Never copy local secret .env files into build output
    if (base == '.env' ||
        (base.startsWith('.env.') && !base.endsWith('.example'))) {
      return true;
    }

    // Skip source maps and compiler dependency files
    if (base.endsWith('.map') ||
        base.endsWith('.map.gz') ||
        base.endsWith('.deps') ||
        base.endsWith('.deps.gz')) {
      return true;
    }

    // Skip heavy installer artifacts in public/downloads
    if (normalized.startsWith('public/downloads/') &&
        (base.endsWith('.apk') ||
            base.endsWith('.exe') ||
            base.endsWith('.zip') ||
            base.endsWith('.msi'))) {
      return true;
    }

    return false;
  }

  Future<void> _copyFilesRecursively(
      Directory source, Directory target, String buildDirName) async {
    for (final entity in source.listSync(recursive: false)) {
      final relativePath = path.relative(entity.path, from: source.path);

      if (relativePath == buildDirName || _shouldSkipPath(relativePath)) {
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
      File(path.join(buildDir, 'swagger.json')),
      File(path.join(buildDir, 'docs', 'swagger.json')),
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

# Activate flavor-specific Web UI manifest if APP_FLAVOR or FLAVOR is set
ACTIVE_FLAVOR="\${APP_FLAVOR:-\${FLAVOR:-}}"
if [ -n "\$ACTIVE_FLAVOR" ] && [ -f "./public/assets/js/flint-ui/manifest-\${ACTIVE_FLAVOR}.json" ]; then
  cp "./public/assets/js/flint-ui/manifest-\${ACTIVE_FLAVOR}.json" "./public/assets/js/flint-ui/manifest.json"
fi

# Ensure executable bit exists even if artifacts were published from Windows.
if [ ! -x "./$exeName" ]; then
  chmod +x "./$exeName"
fi

exec "./$exeName"
''';
    final file = File(path.join(buildDir, 'start.sh'));
    file.writeAsStringSync(content.replaceAll('\r\n', '\n'));
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

  int _detectDefaultPort() {
    final rootDockerfile = File('Dockerfile');
    if (rootDockerfile.existsSync()) {
      final content = rootDockerfile.readAsStringSync();
      final argMatch =
          RegExp(r'ARG\s+APP_PORT\s*=\s*(\d+)').firstMatch(content);
      if (argMatch != null) {
        return int.tryParse(argMatch.group(1)!) ?? 3000;
      }
      final envMatch = RegExp(r'ENV\s+PORT\s*=\s*(\d+)').firstMatch(content);
      if (envMatch != null) {
        return int.tryParse(envMatch.group(1)!) ?? 3000;
      }
    }
    return 3000;
  }

  String _detectDefaultFlavor() {
    final rootDockerfile = File('Dockerfile');
    if (rootDockerfile.existsSync()) {
      final content = rootDockerfile.readAsStringSync();
      final match =
          RegExp(r'ARG\s+APP_FLAVOR\s*=\s*(\S+)').firstMatch(content);
      if (match != null) return match.group(1)!.trim();
    }
    return '';
  }

  String _renderRuntimeDockerfile({
    required String linuxExecutableName,
    required int defaultPort,
    String defaultFlavor = '',
  }) {
    final flavorBlock = defaultFlavor.isEmpty
        ? ''
        : '''
ARG APP_FLAVOR=$defaultFlavor
ENV APP_FLAVOR=\$APP_FLAVOR
ENV FLAVOR=\$APP_FLAVOR
RUN if [ -f "/app/public/assets/js/flint-ui/manifest-\${APP_FLAVOR}.json" ]; then \\
      cp "/app/public/assets/js/flint-ui/manifest-\${APP_FLAVOR}.json" "/app/public/assets/js/flint-ui/manifest.json" && \\
      cp "/app/public/assets/js/flint-ui/manifest-\${APP_FLAVOR}.json" "/app/public/assets/js/flint-ui/manifest-farmbenefit.json" 2>/dev/null || true; \\
    fi
''';

    return '''FROM debian:bookworm-slim

WORKDIR /app

RUN apt-get update \\
    && apt-get install -y --no-install-recommends ca-certificates bash \\
    && rm -rf /var/lib/apt/lists/*

# Copy prebuilt app bundle from this build directory.
COPY . /app

RUN mkdir -p /app/public/downloads \\
    && if [ -f /app/start.sh ]; then chmod +x /app/start.sh; fi \\
    && if [ -f /app/$linuxExecutableName ]; then chmod +x /app/$linuxExecutableName; fi
$flavorBlock
ENV FLINT_HOT=0
ENV FLINT_SWAGGER_UI_DIR=/app/public/swagger-ui
ARG APP_PORT=$defaultPort
ENV PORT=\$APP_PORT
EXPOSE \$APP_PORT

CMD ["./start.sh"]
''';
  }

  void _createDockerfile(String buildDir, {String? linuxExecutableName}) {
    if (linuxExecutableName == null) {
      Log.debug(
          'Skipping Dockerfile generation (no Linux binary built). Use --linux or --both.');
      return;
    }

    final defaultPort = _detectDefaultPort();
    final defaultFlavor = _detectDefaultFlavor();

    final mainContent = _renderRuntimeDockerfile(
      linuxExecutableName: linuxExecutableName,
      defaultPort: defaultPort,
      defaultFlavor: defaultFlavor,
    ).replaceAll('\r\n', '\n');
    File(path.join(buildDir, 'Dockerfile')).writeAsStringSync(mainContent);
    Log.debug('Created Dockerfile: Dockerfile');

    // Also generate any flavor-specific Dockerfiles found in project root (e.g. Dockerfile.farmsbenefit)
    for (final entity in Directory.current.listSync().whereType<File>()) {
      final name = path.basename(entity.path);
      if (name.startsWith('Dockerfile.') && name.length > 'Dockerfile.'.length) {
        final flavorSuffix = name.substring('Dockerfile.'.length).trim();
        final flavorContent = _renderRuntimeDockerfile(
          linuxExecutableName: linuxExecutableName,
          defaultPort: defaultPort,
          defaultFlavor: flavorSuffix,
        ).replaceAll('\r\n', '\n');
        File(path.join(buildDir, name)).writeAsStringSync(flavorContent);
        Log.debug('Created flavor Dockerfile: $name');
      }
    }
  }

  Future<void> _pushBuildDirectoryToBranch(
    String buildDir,
    String branchName,
  ) async {
    final remotesResult = await Process.run(
      'git',
      ['remote'],
      runInShell: true,
    );
    if (remotesResult.exitCode != 0) {
      Log.debug('Failed to read git remotes: ${remotesResult.stderr}');
      exit(1);
    }

    final remotes = remotesResult.stdout
        .toString()
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (remotes.isEmpty) {
      Log.debug('No git remotes found to push $branchName branch.');
      return;
    }

    final remoteUrls = <String, String>{};
    for (final remote in remotes) {
      final urlRes = await Process.run(
        'git',
        ['remote', 'get-url', remote],
        runInShell: true,
      );
      if (urlRes.exitCode == 0) {
        final url = urlRes.stdout.toString().trim();
        if (url.isNotEmpty) remoteUrls[remote] = url;
      }
    }

    final commitRes = await Process.run(
      'git',
      ['rev-parse', '--short', 'HEAD'],
      runInShell: true,
    );
    final sourceCommit = commitRes.exitCode == 0
        ? commitRes.stdout.toString().trim()
        : 'local';

    Log.debug('Preparing $buildDir/ for branch "$branchName" (from $sourceCommit)...');
    final tempGitDir = Directory(path.join(buildDir, '.git'));
    if (tempGitDir.existsSync()) {
      tempGitDir.deleteSync(recursive: true);
    }

    Future<void> runGitInBuild(List<String> gitArgs) async {
      final res = await Process.run(
        'git',
        gitArgs,
        workingDirectory: buildDir,
        runInShell: true,
      );
      if (res.exitCode != 0) {
        throw StateError(
          'git ${gitArgs.join(' ')} failed:\n${res.stderr}\n${res.stdout}',
        );
      }
    }

    try {
      File(path.join(buildDir, '.gitattributes')).writeAsStringSync(
        '*.sh text eol=lf\nDockerfile* text eol=lf\n',
      );
      await runGitInBuild(['init', '-b', branchName]);
      await runGitInBuild(['config', 'core.autocrlf', 'false']);
      // Build output must ship everything (compiled UI assets are often
      // git-ignored in the source repo), so remove any copied ignore file
      // and force-add all files.
      final copiedIgnore = File(path.join(buildDir, '.gitignore'));
      if (copiedIgnore.existsSync()) copiedIgnore.deleteSync();
      await runGitInBuild(['add', '-A', '--force', '.']);
      await runGitInBuild([
        'commit',
        '-m',
        'chore(build): prebuilt Linux AOT + Web UI bundle from $sourceCommit',
      ]);

      for (final entry in remoteUrls.entries) {
        Log.debug('Pushing $branchName to ${entry.key} (${entry.value})...');
        await runGitInBuild([
          'push',
          '--force',
          entry.value,
          'HEAD:refs/heads/$branchName',
        ]);
        Log.debug('Pushed $branchName to ${entry.key}.');
      }
    } finally {
      if (tempGitDir.existsSync()) {
        tempGitDir.deleteSync(recursive: true);
      }
    }
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
  --entry <path>          Entry file to compile (default order: bin/server.dart, bin/main.dart, lib/main.dart)
  --platform <value>      linux | windows | macos | both
  --linux                 Shortcut for --platform linux
  --windows               Shortcut for --platform windows
  --macos                 Shortcut for --platform macos
  --both                  Build both Linux and Windows binaries
  --shared-runtime        Compile Web UI as a shared runtime with deferred chunks (default)
  --page-bundles          Compile separate standalone page bundles
  --skip-web, --no-web    Reuse existing pre-built Web UI assets without recompiling
  --push                  Force-push the generated build/ folder to the "build" branch on all git remotes
  --push-branch <branch>  Force-push the generated build/ folder to a custom branch on all git remotes
  --help, -h              Show this help
''');
  }
}
