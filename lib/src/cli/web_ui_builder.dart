import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

bool get _verboseWebUiBuild {
  final value =
      Platform.environment['FLINT_WEB_UI_VERBOSE']?.toLowerCase().trim();
  return value == '1' || value == 'true' || value == 'yes';
}

void _logVerbose(String message) {
  if (_verboseWebUiBuild) Log.debug(message);
}

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
    await compileDefault(build);
    return true;
  }

  static Future<void> compileDefault(
    FlintWebUiBuild build, {
    String? configPath,
  }) async {
    await compile(build);
    try {
      await compilePageBundles(build, configPath: configPath);
    } on StateError catch (e) {
      Log.debug('Page-level Flint UI bundles skipped: ${e.message}');
    }
  }

  static Future<void> compile(FlintWebUiBuild build) async {
    _cleanCompiledAssetFamily(build.jsOut);
    await _compileTailwind(build);
    await _compileRootDesignCss(build);
    await _compileDart(build);
    final hashedJsOut = _hashDartJsAssetFamily(build.jsOut);
    await _compressAssetFamily(hashedJsOut);
    if (build.cssOut != null) {
      await _compressAssetIfUseful(File(build.cssOut!));
    }
    _writeServiceWorker(build);
    await _compressAssetIfUseful(
      File(path.join(build.webDir.path, 'flint-sw.js')),
    );
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

    await _compileRootDesignCss(build);

    final pagesOutDir = Directory(path.join(path.dirname(build.jsOut), 'pages'))
      ..createSync(recursive: true);
    if (onlyPage == null && pagesOutDir.existsSync()) {
      for (final entity in pagesOutDir.listSync()) {
        if (entity is File) _deleteFileIfExists(entity);
      }
    }
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

      _logVerbose('Compiling Flint UI page bundle: $component');
      await _compileDartFile(generatedEntry.path, jsOut);
      final hashedJsOut = _hashDartJsAssetFamily(jsOut);
      if (onlyPage == null) {
        await _compressAssetFamily(hashedJsOut);
      }
      manifestPages[component] = _assetUrlFor(build.webDir, hashedJsOut);
    }

    final manifestFile =
        File(path.join(path.dirname(build.jsOut), 'manifest.json'));
    final existingPages = <String, String>{};
    if (manifestFile.existsSync()) {
      try {
        final decoded = jsonDecode(manifestFile.readAsStringSync());
        if (decoded is Map && decoded['pages'] is Map) {
          existingPages.addEntries(
            (decoded['pages'] as Map)
                .entries
                .map(
                  (entry) =>
                      MapEntry(entry.key.toString(), entry.value.toString()),
                )
                .where((entry) => entry.value.contains('/pages/')),
          );
        }
      } catch (_) {}
    }

    final manifest = {
      'mode': 'page-bundles',
      'fallback': _assetUrlFor(
        build.webDir,
        _currentHashedDartJsAsset(build.jsOut) ?? build.jsOut,
      ),
      'pages': {
        ...existingPages,
        ...manifestPages,
      },
    };

    manifestFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    _logVerbose('Flint UI manifest generated: ${manifestFile.path}');
    if (onlyPage == null) {
      await _compressAssetIfUseful(manifestFile);
    }
    _writeServiceWorker(build);
    if (onlyPage == null) {
      await _compressAssetIfUseful(
        File(path.join(build.webDir.path, 'flint-sw.js')),
      );
    }
  }

  static Future<void> compileSharedRuntimeBundle(
    FlintWebUiBuild build, {
    String? configPath,
  }) async {
    final config = discoverPageBundleConfig(build, configPath: configPath);
    if (config == null) {
      throw StateError(
        'No Flint UI page config found. Create component_registry.dart or pass --pages-config <path>.',
      );
    }
    if (config.pageTargets.isEmpty) {
      throw StateError(
        'Shared runtime needs direct page imports in component_registry.dart.',
      );
    }

    final missingTargets = [
      for (final component in config.pages.keys)
        if (!config.pageTargets.containsKey(component)) component,
    ];
    if (missingTargets.isNotEmpty) {
      throw StateError(
        'Shared runtime could not resolve page imports for: ${missingTargets.join(', ')}.',
      );
    }

    await _compileTailwind(build);
    await _compileRootDesignCss(build);

    final generatedDir =
        Directory(path.join('.dart_tool', 'flint_ui', 'shared_runtime'))
          ..createSync(recursive: true);
    final generatedEntry = File(path.join(generatedDir.path, 'runtime.dart'));
    final runtimeOut = path.join(path.dirname(build.jsOut), 'runtime.dart.js');

    generatedEntry.writeAsStringSync(_sharedRuntimeEntrypointSource(config));
    _cleanCompiledAssetFamily(runtimeOut);
    _deleteDeferredPartSiblings(runtimeOut);

    _logVerbose('Compiling Flint UI shared runtime bundle...');
    await _compileDartFile(generatedEntry.path, runtimeOut);

    final deferredChunks = _hashDeferredPartFiles(
      _deferredPartFiles(runtimeOut),
      runtimeOut,
    );
    final hashedRuntimeOut = _hashDartJsAssetFamily(runtimeOut);
    await _compressAssetFamily(hashedRuntimeOut);
    for (final chunk in deferredChunks) {
      await _compressAssetIfUseful(chunk);
      final mapFile = File('${chunk.path}.map');
      await _compressAssetIfUseful(mapFile);
    }
    if (build.cssOut != null) {
      await _compressAssetIfUseful(File(build.cssOut!));
    }

    final runtimeUrl = _assetUrlFor(build.webDir, hashedRuntimeOut);
    final manifestFile =
        File(path.join(path.dirname(build.jsOut), 'manifest.json'));
    final manifest = {
      'mode': 'shared-runtime',
      'runtime': runtimeUrl,
      'fallback': runtimeUrl,
      'chunks': [
        for (final chunk in deferredChunks)
          _assetUrlFor(build.webDir, chunk.path),
      ],
      'pages': {
        for (final component in config.pages.keys) component: runtimeUrl,
      },
    };

    manifestFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    _logVerbose(
      'Flint UI shared runtime manifest generated: ${manifestFile.path}',
    );
    await _compressAssetIfUseful(manifestFile);
    _writeServiceWorker(build);
    await _compressAssetIfUseful(
      File(path.join(build.webDir.path, 'flint-sw.js')),
    );
  }

  static Future<void> precompressDirectory(Directory directory) async {
    if (!directory.existsSync()) return;
    if (Platform.environment['FLINT_HOT'] == '1') return;

    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (lower.endsWith('.gz') || lower.endsWith('.br')) continue;
      await _compressAssetIfUseful(entity);
    }
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
    _logVerbose('Compiling Flint Web UI...');
    _logVerbose('Entry: ${build.entry.path}');

    final output = File(build.jsOut);
    output.parent.createSync(recursive: true);

    await _compileDartFile(build.entry.path, build.jsOut);
  }

  static Future<void> _compileRootDesignCss(FlintWebUiBuild build) async {
    if (build.cssOut == null) return;
    if (Platform.environment['FLINT_HOT'] == '1') return;

    final packageName = _readPackageName();
    final entryImport = _packageImportFor(packageName, build.entry.path);
    final generatedDir =
        Directory(path.join('.dart_tool', 'flint_ui', 'root_design_css'))
          ..createSync(recursive: true);
    final generatedEntry = File(path.join(generatedDir.path, 'extract.dart'));

    generatedEntry.writeAsStringSync('''
import 'dart:io';

import 'package:flint_ui/flint_ui.dart' as flint;
import '$entryImport' as app;

void main() {
  flint.resetCollectedStyleCss();
  app.main();
  stdout.write(flint.consumeCollectedStyleCss());
}
''');

    final result = await Process.run(
      'dart',
      ['run', generatedEntry.path],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      final stderrText = result.stderr.toString().trim();
      final stdoutText = result.stdout.toString().trim();
      final detail = [stdoutText, stderrText]
          .where((text) => text.isNotEmpty)
          .join('\n')
          .trim();
      Log.debug(
        detail.isEmpty
            ? 'Skipped Flint root design CSS extraction.'
            : 'Skipped Flint root design CSS extraction.\n$detail',
      );
      return;
    }

    final cssText = result.stdout.toString().trim();
    if (cssText.isEmpty) return;

    final output = File(build.cssOut!);
    output.parent.createSync(recursive: true);

    final existing = output.existsSync()
        ? _stripGeneratedRootDesignCss(output.readAsStringSync()).trim()
        : '';
    final generated = [
      existing,
      '/* Generated from Flint UI root design. */',
      cssText,
      '[data-flint-page] { min-height: 100vh; }',
      'img, picture, video, canvas, svg { max-width: 100%; }',
      'button, input, textarea, select { font: inherit; }',
    ].where((chunk) => chunk.trim().isNotEmpty).join('\n');

    output.writeAsStringSync('$generated\n');
    _logVerbose('Root design stylesheet generated: ${output.path}');
  }

  static String _stripGeneratedRootDesignCss(String cssText) {
    const marker = '/* Generated from Flint UI root design. */';
    final markerIndex = cssText.indexOf(marker);
    if (markerIndex == -1) return cssText;
    return cssText.substring(0, markerIndex).trimRight();
  }

  static Future<void> _compileDartFile(String entryPath, String jsOut) async {
    final output = File(jsOut);
    output.parent.createSync(recursive: true);
    _deleteHashedDartJsSiblings(jsOut);

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

    if (stdoutText.isNotEmpty) _logVerbose(stdoutText);
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
      r'(?:final|const|var)\s+([A-Za-z_]\w*)\s*=\s*(?:PageRegistry|FlintComponentRegistry)\s*\(',
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
        RegExp(r'(?:PageRegistry|FlintComponentRegistry)\s*\(\s*\{')
            .firstMatch(source);
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

  static String _sharedRuntimeEntrypointSource(
    FlintWebUiPageBundleConfig config,
  ) {
    final sortedPages = config.pages.keys.toList()..sort();
    final imports = StringBuffer()
      ..writeln("import 'package:flint_ui/flint_ui.dart';");
    final cases = StringBuffer();

    if (config.rootDesignImport != null) {
      imports.writeln("import '${config.rootDesignImport}';");
    }

    for (var i = 0; i < sortedPages.length; i++) {
      final component = sortedPages[i];
      final target = config.pageTargets[component]!;
      final alias = 'p$i';
      imports.writeln("import '${target.importUri}' deferred as $alias;");
      cases.writeln('''
    case ${jsonEncode(component)}:
      await $alias.loadLibrary();
      return (props) => $alias.${target.className}(props);
''');
    }

    final rootDesignName = config.rootDesignName;

    return '''
${imports.toString()}

Future<FlintPageBuilder?> resolveFlintPage(String component) async {
  switch (component) {
${cases.toString()}  }
  return null;
}

void main() {
  createFlintApp(
    '#app',
    resolvePage: resolveFlintPage,
${rootDesignName == null ? '' : '    rootDesign: $rootDesignName,\n'}  );
}
''';
  }

  static String _assetUrlFor(Directory webDir, String filePath) {
    final relative = path.relative(filePath, from: webDir.path);
    return '/${path.split(relative).join('/')}';
  }

  static String _hashDartJsAssetFamily(String jsOut) {
    final jsFile = File(jsOut);
    if (!jsFile.existsSync()) return jsOut;

    final hash = _shortFileHash(jsFile);
    final hashedJsPath = _hashedDartJsPath(jsOut, hash);
    final hashedJsFile = File(hashedJsPath);
    final hashedMapFile = File('$hashedJsPath.map');
    final hashedDepsFile = File('$hashedJsPath.deps');
    final sourceMapName = path.basename(hashedMapFile.path);

    var js = jsFile.readAsStringSync();
    js = _rewriteSourceMapUrl(js, sourceMapName);
    hashedJsFile.writeAsStringSync(js);

    final mapFile = File('$jsOut.map');
    if (mapFile.existsSync()) {
      hashedMapFile.parent.createSync(recursive: true);
      if (hashedMapFile.existsSync()) hashedMapFile.deleteSync();
      mapFile.renameSync(hashedMapFile.path);
    }

    final depsFile = File('$jsOut.deps');
    if (depsFile.existsSync()) {
      hashedDepsFile.parent.createSync(recursive: true);
      if (hashedDepsFile.existsSync()) hashedDepsFile.deleteSync();
      depsFile.renameSync(hashedDepsFile.path);
    }

    jsFile.deleteSync();
    _logVerbose('Hashed Flint UI asset: ${hashedJsFile.path}');
    return hashedJsFile.path;
  }

  static String? _currentHashedDartJsAsset(String jsOut) {
    final exact = File(jsOut);
    if (exact.existsSync()) return exact.path;

    final dir = Directory(path.dirname(jsOut));
    if (!dir.existsSync()) return null;

    final basename = path.basename(jsOut);
    final pattern = _hashedDartJsSiblingPattern(basename);
    final matches = dir.listSync().whereType<File>().where((file) {
      final name = path.basename(file.path);
      return pattern.hasMatch(name) && name.endsWith('.dart.js');
    }).toList()
      ..sort((a, b) {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      });

    return matches.isEmpty ? null : matches.first.path;
  }

  static void _deleteHashedDartJsSiblings(String jsOut) {
    final dir = Directory(path.dirname(jsOut));
    if (!dir.existsSync()) return;

    final basename = path.basename(jsOut);
    final pattern = _hashedDartJsSiblingPattern(basename);
    for (final file in dir.listSync().whereType<File>()) {
      if (pattern.hasMatch(path.basename(file.path))) {
        _deleteFileIfExists(file);
      }
    }
  }

  static void _cleanCompiledAssetFamily(String jsOut) {
    final dir = Directory(path.dirname(jsOut));
    if (!dir.existsSync()) return;

    final directFiles = [
      jsOut,
      '$jsOut.map',
      '$jsOut.deps',
      '$jsOut.gz',
      '$jsOut.br',
      '$jsOut.map.gz',
      '$jsOut.map.br',
      '$jsOut.deps.gz',
      '$jsOut.deps.br',
      path.join(dir.path, 'manifest.json'),
      path.join(dir.path, 'manifest.json.gz'),
      path.join(dir.path, 'manifest.json.br'),
    ];

    for (final filePath in directFiles) {
      final file = File(filePath);
      _deleteFileIfExists(file);
    }

    _deleteHashedDartJsSiblings(jsOut);
    _deleteDeferredPartSiblings(jsOut);
  }

  static void _deleteDeferredPartSiblings(String jsOut) {
    final dir = Directory(path.dirname(jsOut));
    if (!dir.existsSync()) return;

    final basename = path.basename(jsOut);
    for (final file in dir.listSync().whereType<File>()) {
      final name = path.basename(file.path);
      if (name.startsWith('${basename}_') &&
          (name.endsWith('.part.js') ||
              RegExp(r'\.[a-f0-9]{12}\.part\.js$').hasMatch(name) ||
              name.endsWith('.part.js.map') ||
              RegExp(r'\.[a-f0-9]{12}\.part\.js\.map$').hasMatch(name) ||
              name.endsWith('.part.js.gz') ||
              RegExp(r'\.[a-f0-9]{12}\.part\.js\.gz$').hasMatch(name) ||
              name.endsWith('.part.js.br') ||
              RegExp(r'\.[a-f0-9]{12}\.part\.js\.br$').hasMatch(name) ||
              name.endsWith('.part.js.map.gz') ||
              RegExp(r'\.[a-f0-9]{12}\.part\.js\.map\.gz$').hasMatch(name) ||
              name.endsWith('.part.js.map.br'))) {
        _deleteFileIfExists(file);
      }
    }
  }

  static bool _deleteFileIfExists(File file) {
    if (!file.existsSync()) return true;
    try {
      file.deleteSync();
      return true;
    } on FileSystemException catch (e) {
      _logVerbose(
        'Skipped locked Flint asset: ${file.path} (${e.osError?.message ?? e.message})',
      );
      return false;
    }
  }

  static List<File> _deferredPartFiles(String jsOut) {
    final dir = Directory(path.dirname(jsOut));
    if (!dir.existsSync()) return const [];

    final basename = path.basename(jsOut);
    final files = dir.listSync().whereType<File>().where((file) {
      final name = path.basename(file.path);
      return name.startsWith('${basename}_') && name.endsWith('.part.js');
    }).toList()
      ..sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));

    return files;
  }

  static List<File> _hashDeferredPartFiles(
    List<File> chunks,
    String runtimeOut,
  ) {
    if (chunks.isEmpty) return const [];

    final runtimeFile = File(runtimeOut);
    final depsFile = File('$runtimeOut.deps');
    final replacements = <String, String>{};
    final hashedChunks = <File>[];

    for (final chunk in chunks) {
      if (!chunk.existsSync()) continue;

      final hash = _shortFileHash(chunk);
      final oldName = path.basename(chunk.path);
      final hashedPath = _hashedDeferredPartPath(chunk.path, hash);
      final hashedName = path.basename(hashedPath);
      final hashedFile = File(hashedPath);
      final hashedMapFile = File('$hashedPath.map');
      final sourceMapName = path.basename(hashedMapFile.path);

      var js = chunk.readAsStringSync();
      js = _rewriteSourceMapUrl(js, sourceMapName);
      hashedFile.writeAsStringSync(js);

      final mapFile = File('${chunk.path}.map');
      if (mapFile.existsSync()) {
        if (hashedMapFile.existsSync()) hashedMapFile.deleteSync();
        mapFile.renameSync(hashedMapFile.path);
      }

      chunk.deleteSync();
      replacements[oldName] = hashedName;
      hashedChunks.add(hashedFile);
      _logVerbose('Hashed Flint UI deferred asset: ${hashedFile.path}');
    }

    if (runtimeFile.existsSync() && replacements.isNotEmpty) {
      var runtime = runtimeFile.readAsStringSync();
      for (final entry in replacements.entries) {
        runtime = runtime.replaceAll(entry.key, entry.value);
      }
      runtimeFile.writeAsStringSync(runtime);
    }

    if (depsFile.existsSync() && replacements.isNotEmpty) {
      var deps = depsFile.readAsStringSync();
      for (final entry in replacements.entries) {
        deps = deps.replaceAll(entry.key, entry.value);
      }
      depsFile.writeAsStringSync(deps);
    }

    return hashedChunks;
  }

  static String _hashedDeferredPartPath(String filePath, String hash) {
    const suffix = '.part.js';
    if (filePath.endsWith(suffix)) {
      return '${filePath.substring(0, filePath.length - suffix.length)}.$hash$suffix';
    }
    return _hashedDartJsPath(filePath, hash);
  }

  static RegExp _hashedDartJsSiblingPattern(String basename) {
    if (basename.endsWith('.dart.js')) {
      final prefix = RegExp.escape(
        basename.substring(0, basename.length - '.dart.js'.length),
      );
      return RegExp(
        '^$prefix\\.[a-f0-9]{12}\\.dart\\.js(\\.map|\\.deps)?(\\.gz|\\.br)?\$',
      );
    }

    final extension = path.extension(basename);
    final stem = RegExp.escape(
      extension.isEmpty
          ? basename
          : basename.substring(0, basename.length - extension.length),
    );
    final ext = RegExp.escape(extension);
    return RegExp('^$stem\\.[a-f0-9]{12}$ext(\\.map|\\.deps)?(\\.gz|\\.br)?\$');
  }

  static String _hashedDartJsPath(String jsOut, String hash) {
    if (jsOut.endsWith('.dart.js')) {
      return '${jsOut.substring(0, jsOut.length - '.dart.js'.length)}.$hash.dart.js';
    }

    final extension = path.extension(jsOut);
    if (extension.isEmpty) return '$jsOut.$hash';
    return '${jsOut.substring(0, jsOut.length - extension.length)}.$hash$extension';
  }

  static String _shortFileHash(File file) {
    return sha256.convert(file.readAsBytesSync()).toString().substring(0, 12);
  }

  static String _rewriteSourceMapUrl(String js, String sourceMapName) {
    final sourceMapPattern =
        RegExp(r'//# sourceMappingURL=.*$', multiLine: true);
    if (sourceMapPattern.hasMatch(js)) {
      return js.replaceFirst(
        sourceMapPattern,
        '//# sourceMappingURL=$sourceMapName',
      );
    }

    final newline = js.endsWith('\n') ? '' : '\n';
    return '$js$newline//# sourceMappingURL=$sourceMapName\n';
  }

  static Future<void> _compressAssetFamily(String jsPath) async {
    final files = [
      File(jsPath),
      File('$jsPath.map'),
      File('$jsPath.deps'),
    ];

    for (final file in files) {
      await _compressAssetIfUseful(file);
    }
  }

  static Future<void> _compressAssetIfUseful(File file) async {
    if (!file.existsSync()) return;
    if (!_shouldPrecompress(file.path)) return;
    if (Platform.environment['FLINT_HOT'] == '1') return;

    final bytes = file.readAsBytesSync();
    final gzipFile = File('${file.path}.gz');
    gzipFile.writeAsBytesSync(gzip.encode(bytes));
    _logVerbose('Compressed Flint asset: ${gzipFile.path}');

    final brotli = await _resolveBrotliBinary();
    if (brotli == null) return;

    final brFile = File('${file.path}.br');
    final result = await Process.run(
      brotli,
      ['-f', '-q', '11', '-o', brFile.path, file.path],
      runInShell: true,
    );
    if (result.exitCode == 0 && brFile.existsSync()) {
      _logVerbose('Compressed Flint asset: ${brFile.path}');
    } else {
      final stderrText = result.stderr.toString().trim();
      if (stderrText.isNotEmpty) {
        _logVerbose('Brotli compression skipped for ${file.path}: $stderrText');
      }
    }
  }

  static bool _shouldPrecompress(String filePath) {
    final lower = filePath.toLowerCase();
    return lower.endsWith('.js') ||
        lower.endsWith('.css') ||
        lower.endsWith('.json') ||
        lower.endsWith('.svg') ||
        lower.endsWith('.map') ||
        lower.endsWith('.deps');
  }

  static Future<String?> _resolveBrotliBinary() async {
    final explicit = Platform.environment['FLINT_BROTLI_BIN'];
    if (explicit != null && explicit.trim().isNotEmpty) {
      return explicit.trim();
    }

    for (final candidate in ['brotli', 'brotli.exe']) {
      if (await _commandExists(candidate)) return candidate;
    }

    return null;
  }

  static void _writeServiceWorker(FlintWebUiBuild build) {
    final file = File(path.join(build.webDir.path, 'flint-sw.js'));
    file.parent.createSync(recursive: true);
    final cacheName =
        'flint-ui-${DateTime.now().millisecondsSinceEpoch.toString()}';
    file.writeAsStringSync(_serviceWorkerSource(cacheName));
    _logVerbose('Flint service worker generated: ${file.path}');
  }

  static String _serviceWorkerSource(String cacheName) {
    return r'''
const FLINT_CACHE = '__CACHE_NAME__';
const FLINT_MANIFEST_URL = '/assets/js/flint-ui/manifest.json';

async function flintCacheUrls(urls) {
  const cache = await caches.open(FLINT_CACHE);
  for (const url of Array.from(new Set(urls)).filter(Boolean)) {
    try {
      if (await cache.match(url)) continue;
      const response = await fetch(url, { cache: 'reload' });
      if (response.ok) await cache.put(url, response);
      await new Promise(resolve => setTimeout(resolve, 1200));
    } catch (_) {}
  }
}

async function flintManifestAssets({ includeFallback = false } = {}) {
  try {
    const response = await fetch(FLINT_MANIFEST_URL, { cache: 'reload' });
    if (!response.ok) return [FLINT_MANIFEST_URL];
    const manifest = await response.json();
    const pages = manifest && manifest.pages && typeof manifest.pages === 'object'
      ? Object.values(manifest.pages)
      : [];
    const chunks = Array.isArray(manifest && manifest.chunks)
      ? manifest.chunks
      : [];
    return [
      FLINT_MANIFEST_URL,
      manifest.runtime,
      ...(includeFallback || pages.length === 0 ? [manifest.fallback] : []),
      ...pages,
      ...chunks
    ];
  } catch (_) {
    return [FLINT_MANIFEST_URL];
  }
}

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    await flintCacheUrls([FLINT_MANIFEST_URL]);
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(
      keys
        .filter(key => key.startsWith('flint-ui-') && key !== FLINT_CACHE)
        .map(key => caches.delete(key))
    );
    await self.clients.claim();
  })());
});

self.addEventListener('message', event => {
  if (event.data && event.data.type === 'FLINT_PREFETCH') {
    event.waitUntil((async () => {
      await new Promise(resolve => setTimeout(resolve, 12000));
      await flintCacheUrls(await flintManifestAssets());
    })());
  }
});

self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin) {
    return;
  }

  const cacheFirst =
    url.pathname.startsWith('/assets/js/flint-ui/') ||
    url.pathname.startsWith('/assets/css/flint-ui/') ||
    url.pathname === FLINT_MANIFEST_URL;

  if (!cacheFirst) return;

  event.respondWith((async () => {
    const cached = await caches.match(event.request);
    if (cached) return cached;
    const response = await fetch(event.request);
    if (response.ok) {
      const cache = await caches.open(FLINT_CACHE);
      await cache.put(event.request, response.clone());
    }
    return response;
  })());
});
'''
        .replaceAll('__CACHE_NAME__', cacheName);
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

    _logVerbose('Compiling Tailwind CSS...');
    _logVerbose('Input: ${input.path}');

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
    if (stdoutText.isNotEmpty) _logVerbose(stdoutText);
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
