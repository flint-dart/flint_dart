import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:path/path.dart' as path;

class FlintWebUiBuild {
  final File entry;
  final Directory uiDir;
  final Directory webDir;
  final String jsOut;
  final File? tailwindInput;
  final String? cssOut;

  FlintWebUiBuild({
    required this.entry,
    required this.uiDir,
    required this.webDir,
    required this.jsOut,
    this.tailwindInput,
    this.cssOut,
  });
}

class FlintWebUiPageBundleConfig {
  final String registryImport;
  final String registryName;
  final String? rootDesignImport;
  final String? rootDesignName;
  final Map<String, String> pages;
  final Map<String, FlintWebUiPageTarget> pageTargets;

  FlintWebUiPageBundleConfig({
    required this.registryImport,
    required this.registryName,
    required this.pages,
    this.pageTargets = const {},
    this.rootDesignImport,
    this.rootDesignName,
  });
}

class FlintWebUiPageTarget {
  final String importUri;
  final String className;

  FlintWebUiPageTarget({
    required this.importUri,
    required this.className,
  });
}

class _DetectedRootDesign {
  final String name;
  final String importUri;

  _DetectedRootDesign({
    required this.name,
    required this.importUri,
  });
}

class FlintWebUiBuilder {
  static File? findEntry([String? entryArg]) {
    if (entryArg != null) {
      final file = File(entryArg);
      return file.existsSync() ? file : null;
    }

    final candidates = [
      path.join('lib', 'ui', 'main.dart'),
      path.join('flint_ui', 'main.dart'),
      path.join('flint_ui', 'flint_ui', 'main.dart'),
      path.join('lib', 'flint_ui', 'main.dart'),
      path.join('example', 'flint_ui', 'flint_ui', 'main.dart'),
      'web/main.dart',
      path.join('flint_ui', 'web', 'main.dart'),
      path.join('lib', 'web', 'main.dart'),
      path.join('example', 'flint_ui', 'web', 'main.dart'),
    ];

    for (final candidate in candidates) {
      final file = File(candidate);
      if (file.existsSync()) return file;
    }

    return null;
  }

  static Directory? resolveWebDir(File entry, [String? webDirArg]) {
    if (webDirArg != null) {
      final dir = Directory(webDirArg);
      return dir.existsSync() ? dir : null;
    }

    final entryDir = entry.parent;
    final normalizedEntry = path.normalize(entry.path);
    final appUiEntry = path.normalize(path.join('lib', 'ui', 'main.dart'));
    if (normalizedEntry == appUiEntry ||
        normalizedEntry.endsWith(path.normalize(path.join(
          '${path.separator}lib',
          'ui',
          'main.dart',
        )))) {
      final publicDir = Directory('public');
      if (publicDir.existsSync()) return publicDir;
    }

    if (path.basename(entryDir.path) == 'flint_ui') {
      final siblingWebDir = Directory(path.join(entryDir.parent.path, 'web'));
      if (siblingWebDir.existsSync()) return siblingWebDir;

      final siblingPublicDir =
          Directory(path.join(entryDir.parent.path, 'public'));
      if (siblingPublicDir.existsSync()) return siblingPublicDir;
    }

    final webDir = Directory('web');
    if (webDir.existsSync()) return webDir;

    final publicDir = Directory('public');
    if (publicDir.existsSync()) return publicDir;

    return entryDir;
  }

  static FlintWebUiBuild? resolve({
    String? entryArg,
    String? webDirArg,
    String? outArg,
  }) {
    final entry = findEntry(entryArg);
    if (entry == null) return null;

    final webDir = resolveWebDir(entry, webDirArg);
    if (webDir == null) return null;

    return FlintWebUiBuild(
      entry: entry,
      uiDir: entry.parent,
      webDir: webDir,
      jsOut: outArg ?? _defaultJsOut(entry, webDir),
      tailwindInput: _resolveTailwindInput(entry.parent),
      cssOut: _defaultCssOut(entry, webDir),
    );
  }

  static String _defaultJsOut(File entry, Directory webDir) {
    if (_isAppUiEntry(entry) && path.basename(webDir.path) == 'public') {
      return path.join(webDir.path, 'assets', 'js', 'flint-ui', 'main.dart.js');
    }

    return path.join(webDir.path, 'main.dart.js');
  }

  static String _defaultCssOut(File entry, Directory webDir) {
    if (_isAppUiEntry(entry) && path.basename(webDir.path) == 'public') {
      return path.join(webDir.path, 'assets', 'css', 'flint-ui', 'style.css');
    }

    return path.join(webDir.path, 'style.css');
  }

  static bool _isAppUiEntry(File entry) {
    final normalizedEntry = path.normalize(entry.path);
    final appUiEntry = path.normalize(path.join('lib', 'ui', 'main.dart'));
    return normalizedEntry == appUiEntry ||
        normalizedEntry.endsWith(path.normalize(path.join(
          '${path.separator}lib',
          'ui',
          'main.dart',
        )));
  }

  static Future<bool> compileIfPresent() async {
    final build = resolve();
    if (build == null) return false;
    await compile(build);
    return true;
  }

  static Future<void> compile(FlintWebUiBuild build) async {
    await _compileTailwind(build);
    await _compileDart(build);
  }

  static Future<void> compilePageBundles(
    FlintWebUiBuild build, {
    String? configPath,
    String? onlyPage,
  }) async {
    final config = discoverPageBundleConfig(build, configPath: configPath);
    if (config == null) {
      throw StateError(
        'No Flint UI page bundle config found. Create flint_ui.yaml or pass --pages-config <path>.',
      );
    }

    final requestedPages = onlyPage == null
        ? config.pages
        : {
            for (final entry in config.pages.entries)
              if (entry.key == onlyPage) entry.key: entry.value,
          };

    if (requestedPages.isEmpty) {
      throw StateError('No page bundle target found for "$onlyPage".');
    }

    final pagesOutDir = Directory(path.join(path.dirname(build.jsOut), 'pages'))
      ..createSync(recursive: true);
    final generatedDir =
        Directory(path.join('.dart_tool', 'flint_ui', 'page_bundles'))
          ..createSync(recursive: true);
    final manifestPages = <String, String>{};

    for (final entry in requestedPages.entries) {
      final component = entry.key;
      final slug = entry.value;
      final generatedEntry = File(path.join(generatedDir.path, '$slug.dart'));
      final jsOut = path.join(pagesOutDir.path, '$slug.dart.js');

      generatedEntry.writeAsStringSync(
        _pageEntrypointSource(component, config),
      );

      Log.debug('Compiling Flint UI page bundle: $component');
      await _compileDartFile(generatedEntry.path, jsOut);
      manifestPages[component] = _assetUrlFor(build.webDir, jsOut);
    }

    final manifestFile =
        File(path.join(path.dirname(build.jsOut), 'manifest.json'));
    final existingPages = <String, String>{};
    if (manifestFile.existsSync()) {
      try {
        final decoded = jsonDecode(manifestFile.readAsStringSync());
        if (decoded is Map && decoded['pages'] is Map) {
          existingPages.addAll(
            (decoded['pages'] as Map).map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ),
          );
        }
      } catch (_) {}
    }

    final manifest = {
      'mode': 'page-bundles',
      'fallback': _assetUrlFor(build.webDir, build.jsOut),
      'pages': {
        ...existingPages,
        ...manifestPages,
      },
    };

    manifestFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    Log.debug('Flint UI manifest generated: ${manifestFile.path}');
  }

  static File? _resolveTailwindInput(Directory uiDir) {
    final candidates = [
      File(path.join(uiDir.path, 'tailwind.css')),
      File(path.join(uiDir.path, 'styles', 'tailwind.css')),
    ];

    for (final file in candidates) {
      if (file.existsSync()) return file;
    }

    return null;
  }

  static Future<void> _compileDart(FlintWebUiBuild build) async {
    Log.debug('Compiling Flint Web UI...');
    Log.debug('Entry: ${build.entry.path}');

    final output = File(build.jsOut);
    output.parent.createSync(recursive: true);

    await _compileDartFile(build.entry.path, build.jsOut);
  }

  static Future<void> _compileDartFile(String entryPath, String jsOut) async {
    final output = File(jsOut);
    output.parent.createSync(recursive: true);

    final result = await Process.run(
      'dart',
      ['compile', 'js', entryPath, '-o', jsOut],
      runInShell: true,
    );

    final stdoutText = result.stdout.toString().trim();
    final stderrText = result.stderr.toString().trim();

    if (result.exitCode != 0) {
      Log.debug('Web build failed:');
      if (stdoutText.isNotEmpty) Log.debug(stdoutText);
      if (stderrText.isNotEmpty) Log.debug(stderrText);
      final detail = [stdoutText, stderrText]
          .where((text) => text.isNotEmpty)
          .join('\n')
          .trim();
      throw StateError(
        detail.isEmpty
            ? 'Flint Web UI build failed.'
            : 'Flint Web UI build failed.\n$detail',
      );
    }

    if (stdoutText.isNotEmpty) Log.debug(stdoutText);
  }

  static FlintWebUiPageBundleConfig? discoverPageBundleConfig(
    FlintWebUiBuild build, {
    String? configPath,
  }) {
    final file = File(configPath ?? 'flint_ui.yaml');
    if (file.existsSync()) {
      return _loadPageBundleConfigFile(file);
    }

    return _detectPageBundleConfig(build);
  }

  static FlintWebUiPageBundleConfig? _loadPageBundleConfigFile(File file) {
    final packageName = _readPackageName();
    final values = <String, String>{};
    final pages = <String, String>{};
    var inPages = false;

    for (final rawLine in file.readAsLinesSync()) {
      final line = rawLine.split('#').first.trimRight();
      if (line.trim().isEmpty) continue;

      if (line.trim() == 'flint_ui:') {
        inPages = false;
        continue;
      }

      final trimmed = line.trim();
      if (trimmed == 'pages:') {
        inPages = true;
        continue;
      }

      final separator = trimmed.indexOf(':');
      if (separator == -1) continue;

      final key = trimmed.substring(0, separator).trim();
      final value = _unquote(trimmed.substring(separator + 1).trim());
      if (key.isEmpty || value.isEmpty) continue;

      if (inPages) {
        pages[key] = value;
      } else {
        values[key] = value;
      }
    }

    if (pages.isEmpty) return null;

    final registryImport = values['registry_import'] ??
        _packageImportFor(packageName, 'lib/ui/component_registry.dart');
    final rootDesignImport = values['root_design_import'];
    final rootDesignName = values['root_design'];

    return FlintWebUiPageBundleConfig(
      registryImport: registryImport,
      registryName: values['registry'] ?? 'componentRegistry',
      rootDesignImport: rootDesignImport,
      rootDesignName: rootDesignName,
      pages: pages.map((key, value) => MapEntry(key, _safeSlug(value))),
    );
  }

  static FlintWebUiPageBundleConfig? _detectPageBundleConfig(
    FlintWebUiBuild build,
  ) {
    final registryFile =
        File(path.join('lib', 'ui', 'component_registry.dart'));
    if (!registryFile.existsSync()) return null;

    final packageName = _readPackageName();
    final registrySource = registryFile.readAsStringSync();
    final pageTargets = _detectRegistryPageTargets(
      registrySource,
      registryFile,
      packageName,
    );
    if (pageTargets.isEmpty) return null;

    final mainFile = File(path.join('lib', 'ui', 'main.dart'));
    final rootDesign = mainFile.existsSync()
        ? _detectRootDesign(mainFile.readAsStringSync(), mainFile)
        : null;

    return FlintWebUiPageBundleConfig(
      registryImport: _packageImportFor(
        packageName,
        path.join('lib', 'ui', 'component_registry.dart'),
      ),
      registryName: _detectRegistryName(registrySource) ?? 'componentRegistry',
      rootDesignImport: rootDesign?.importUri,
      rootDesignName: rootDesign?.name,
      pages: {
        for (final page in pageTargets.keys) page: _safeSlug(page),
      },
      pageTargets: pageTargets,
    );
  }

  static String? _detectRegistryName(String source) {
    final match = RegExp(
      r'(?:final|const|var)\s+([A-Za-z_]\w*)\s*=\s*FlintComponentRegistry\s*\(',
      multiLine: true,
    ).firstMatch(source);
    return match?.group(1);
  }

  static Map<String, FlintWebUiPageTarget> _detectRegistryPageTargets(
    String source,
    File registryFile,
    String packageName,
  ) {
    final registryStart =
        RegExp(r'FlintComponentRegistry\s*\(\s*\{').firstMatch(source);
    if (registryStart == null) return const {};

    final start = registryStart.end;
    var depth = 1;
    var index = start;
    while (index < source.length && depth > 0) {
      final char = source[index];
      if (char == '{') depth++;
      if (char == '}') depth--;
      index++;
    }
    if (depth != 0) return const {};

    final body = source.substring(start, index - 1);
    final imports = _detectImports(source, registryFile, packageName);
    final targets = <String, FlintWebUiPageTarget>{};
    final pattern = RegExp(
      r'''['"]([^'"]+)['"]\s*:\s*\([^)]*\)\s*=>\s*([A-Za-z_]\w*)\s*\(''',
    );

    for (final match in pattern.allMatches(body)) {
      final name = match.group(1)?.trim();
      final className = match.group(2)?.trim();
      if (name == null || name.isEmpty || className == null) continue;

      final importUri = imports[className];
      if (importUri == null) continue;
      targets[name] = FlintWebUiPageTarget(
        importUri: importUri,
        className: className,
      );
    }

    return targets;
  }

  static Map<String, String> _detectImports(
    String source,
    File fromFile,
    String packageName,
  ) {
    final imports = <String, String>{};

    for (final importMatch
        in RegExp(r'''import\s+['"]([^'"]+)['"]\s*;''').allMatches(source)) {
      final importUri = importMatch.group(1);
      if (importUri == null || importUri.startsWith('package:')) continue;

      final importedFile =
          File(path.normalize(path.join(fromFile.parent.path, importUri)));
      if (!importedFile.existsSync()) continue;

      final importedSource = importedFile.readAsStringSync();
      for (final classMatch
          in RegExp(r'\bclass\s+([A-Za-z_]\w*)\b').allMatches(importedSource)) {
        final className = classMatch.group(1);
        if (className == null) continue;
        imports[className] = _packageImportFor(packageName, importedFile.path);
      }
    }

    return imports;
  }

  static _DetectedRootDesign? _detectRootDesign(String source, File mainFile) {
    final nameMatch =
        RegExp(r'rootDesign\s*:\s*([A-Za-z_]\w*)').firstMatch(source);
    final name = nameMatch?.group(1);
    if (name == null || name.isEmpty) return null;

    for (final importMatch
        in RegExp(r'''import\s+['"]([^'"]+)['"]\s*;''').allMatches(source)) {
      final importUri = importMatch.group(1);
      if (importUri == null || importUri.startsWith('package:')) continue;

      final importedFile =
          File(path.normalize(path.join(mainFile.parent.path, importUri)));
      if (!importedFile.existsSync()) continue;
      if (!RegExp('\\b${RegExp.escape(name)}\\b')
          .hasMatch(importedFile.readAsStringSync())) {
        continue;
      }

      final packageName = _readPackageName();
      return _DetectedRootDesign(
        name: name,
        importUri: _packageImportFor(packageName, importedFile.path),
      );
    }

    return null;
  }

  static String _pageEntrypointSource(
    String component,
    FlintWebUiPageBundleConfig config,
  ) {
    final rootImport = config.rootDesignImport;
    final rootDesignName = config.rootDesignName;
    final target = config.pageTargets[component];

    if (target != null) {
      return '''
import 'package:flint_ui/flint_ui.dart';
import '${target.importUri}';
${rootImport == null ? '' : "import '$rootImport';"}

void main() {
  createFlintApp(
    '#app',
    pages: {'$component': (props) => ${target.className}(props)},
${rootDesignName == null ? '' : '    rootDesign: $rootDesignName,\n'}  );
}
''';
    }

    return '''
import 'package:flint_ui/flint_ui.dart';
import '${config.registryImport}';
${rootImport == null ? '' : "import '$rootImport';"}

void main() {
  final pageBuilder = ${config.registryName}['$component'];
  if (pageBuilder == null) {
    throw StateError('Flint page "$component" is not registered.');
  }

  createFlintApp(
    '#app',
    pages: {'$component': pageBuilder},
${rootDesignName == null ? '' : '    rootDesign: $rootDesignName,\n'}  );
}
''';
  }

  static String _assetUrlFor(Directory webDir, String filePath) {
    final relative = path.relative(filePath, from: webDir.path);
    return '/${path.split(relative).join('/')}';
  }

  static String _readPackageName() {
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) return 'app';
    final match = RegExp(r'^name:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec.readAsStringSync());
    return match?.group(1)?.trim() ?? 'app';
  }

  static String _packageImportFor(String packageName, String filePath) {
    final parts = path.split(filePath);
    final libIndex = parts.indexOf('lib');
    final packagePath = libIndex == -1
        ? path.split(filePath).join('/')
        : parts.skip(libIndex + 1).join('/');
    return 'package:$packageName/$packagePath';
  }

  static String _safeSlug(String value) {
    final slug = value
        .trim()
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)}_${match.group(2)}',
        )
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toLowerCase();
    return slug.isEmpty ? 'page' : slug;
  }

  static String _unquote(String value) {
    if ((value.startsWith("'") && value.endsWith("'")) ||
        (value.startsWith('"') && value.endsWith('"'))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  static Future<void> _compileTailwind(FlintWebUiBuild build) async {
    final input = build.tailwindInput;
    final output = build.cssOut;
    if (input == null || output == null) return;

    final binary = await _resolveTailwindBinary();
    if (binary == null) {
      Log.warning(
        'Tailwind input found at ${input.path}, but no standalone tailwindcss binary was found on PATH. '
        'Skipping CSS build. Install Tailwind standalone, set FLINT_TAILWIND_BIN, or include a stylesheet/Tailwind CDN link in your page header.',
      );
      return;
    }

    Log.debug('Compiling Tailwind CSS...');
    Log.debug('Input: ${input.path}');

    final result = await Process.run(
      binary,
      ['-i', input.path, '-o', output],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      Log.warning('Tailwind CSS build failed. Skipping CSS build.');
      final stderrText = result.stderr.toString().trim();
      if (stderrText.isNotEmpty) Log.debug(stderrText);
      return;
    }

    final stdoutText = result.stdout.toString().trim();
    if (stdoutText.isNotEmpty) Log.debug(stdoutText);
  }

  static Future<String?> _resolveTailwindBinary() async {
    final explicit = Platform.environment['FLINT_TAILWIND_BIN'];
    if (explicit != null && explicit.trim().isNotEmpty) {
      return explicit.trim();
    }

    for (final candidate in ['tailwindcss', 'tailwindcss.exe']) {
      if (await _commandExists(candidate)) return candidate;
    }

    return null;
  }

  static Future<bool> _commandExists(String command) async {
    try {
      final probe = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(probe, [command], runInShell: true);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
