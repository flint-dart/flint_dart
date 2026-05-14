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

class FlintWebUiBuilder {
  static File? findEntry([String? entryArg]) {
    if (entryArg != null) {
      final file = File(entryArg);
      return file.existsSync() ? file : null;
    }

    final candidates = [
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
      jsOut: outArg ?? path.join(webDir.path, 'main.dart.js'),
      tailwindInput: _resolveTailwindInput(entry.parent),
      cssOut: path.join(webDir.path, 'style.css'),
    );
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

    final result = await Process.run(
      'dart',
      ['compile', 'js', build.entry.path, '-o', build.jsOut],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      Log.debug('Web build failed:');
      Log.debug(result.stderr.toString());
      throw StateError('Flint Web UI build failed.');
    }

    final stdoutText = result.stdout.toString().trim();
    if (stdoutText.isNotEmpty) Log.debug(stdoutText);
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
