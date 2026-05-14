import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as path;

class DeployGlobeCommand extends FlintCommand {
  DeployGlobeCommand()
      : super(
            'deploy-globe',
            'Prepare Globe deployment files '
                '(globe.yaml, optional swagger-ui assets)');

  @override
  Future<void> execute(List<String> args) async {
    String outputDir = '.';
    String? entryPointArg;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--help' || arg == '-h') {
        _printHelp();
        return;
      } else if (arg == '--entry' && i + 1 < args.length) {
        entryPointArg = args[++i];
      } else if (arg == '--entry') {
        Log.debug('❌ Missing value for --entry');
        _printHelp();
        exit(1);
      } else if (arg.startsWith('--')) {
        Log.debug('❌ Unknown option: $arg');
        _printHelp();
        exit(1);
      } else {
        outputDir = arg;
      }
    }

    final target = Directory(outputDir);
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }

    final entryPoint = await _resolveEntryPoint(entryPointArg);
    _createGlobeYaml(target.path, entryPoint);
    await _ensureSwaggerUiAssets(target.path);

    Log.info('✅ Globe deployment files prepared');
    Log.info('📁 Output: ${target.path}');
    Log.info('🚀 Next steps:');
    Log.info('   1) dart pub global activate globe_cli');
    Log.info('   2) globe login');
    Log.info('   3) globe deploy');
  }

  Future<String> _resolveEntryPoint(String? entryPointArg) async {
    if (entryPointArg != null) {
      final file = File(entryPointArg);
      if (!await file.exists()) {
        Log.debug('❌ Entry file not found: $entryPointArg');
        exit(1);
      }
      return entryPointArg;
    }

    const candidates = ['lib/main.dart', 'bin/main.dart', 'bin/server.dart'];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }

    Log.debug(
        '❌ No entry point found. Expected one of: ${candidates.join(', ')}');
    Log.debug('   Or provide a custom entry with --entry <path>');
    exit(1);
  }

  void _createGlobeYaml(String outputDir, String entryPoint) {
    final assetCandidates = [
      'assets',
      'public',
      'docs',
      'swagger-ui',
      'lib/views',
    ];

    final existingAssets = <String>[];
    for (final dir in assetCandidates) {
      if (Directory(dir).existsSync()) {
        existingAssets.add('$dir/');
      }
    }

    final assetsBlock = existingAssets.isEmpty
        ? ''
        : '\nassets:\n${existingAssets.map((a) => '  - $a').join('\n')}\n';

    final content =
        '''# yaml-language-server: \$schema=https://globe.dev/globe.schema.json

entrypoint: $entryPoint

build:
  build_runner:
    automatic_detection: false
  melos:
    automatic_detection: true$assetsBlock''';

    File(path.join(outputDir, 'globe.yaml')).writeAsStringSync(content);
    Log.debug('🌍 Created globe.yaml');
  }

  Future<void> _ensureSwaggerUiAssets(String outputDir) async {
    final existingTarget = Directory(path.join(outputDir, 'swagger-ui'));
    if (existingTarget.existsSync()) {
      Log.debug('ℹ️  swagger-ui already exists. Skipping copy.');
      return;
    }

    final source = await _resolveSwaggerUiSourceDir();
    if (source == null) {
      Log.debug(
          'ℹ️  No swagger-ui assets found (checked package and local paths).');
      return;
    }

    final targetDir = Directory(path.join(outputDir, 'swagger-ui'))
      ..createSync(recursive: true);
    _copyDirectoryContents(source, targetDir);
    Log.debug(
        '📚 Copied Swagger UI assets: ${source.path} -> ${targetDir.path}');
  }

  Future<Directory?> _resolveSwaggerUiSourceDir() async {
    final candidates = <String>[
      path.join(Directory.current.path, 'swagger-ui'),
      path.join(Directory.current.path, 'build', 'swagger-ui'),
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

  void _printHelp() {
    Log.debug('''
Usage: flint deploy-globe [output_dir] [options]

Options:
  --entry <path>       Entry file for Globe (default order: lib/main.dart, bin/main.dart, bin/server.dart)
  --help, -h           Show this help
''');
  }
}
