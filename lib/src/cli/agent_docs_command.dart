import 'dart:io';
import 'dart:isolate';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:path/path.dart' as path;

class AgentDocsCommand extends FlintCommand {
  final String? workingDirectory;

  AgentDocsCommand()
      : workingDirectory = null,
        super('agent', 'Creates Flint AI agent docs in an existing app');

  AgentDocsCommand.withWorkingDirectory(this.workingDirectory)
      : super('agent', 'Creates Flint AI agent docs in an existing app');

  @override
  Future<void> execute(List<String> args) async {
    final force = args.contains('--force') || args.contains('-f');
    final projectRoot = Directory(
      workingDirectory ?? Directory.current.path,
    ).absolute;
    final pubspec = File(path.join(projectRoot.path, 'pubspec.yaml'));

    if (!await pubspec.exists()) {
      Log.debug(
        'No pubspec.yaml found. Run `flint agent` from a Flint app root.',
      );
      return;
    }

    final docsDir = Directory(path.join(projectRoot.path, 'docs'));
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }

    var written = 0;
    var skipped = 0;
    final sourceDocsDir = await _resolvePackageDocsDir();

    if (sourceDocsDir == null) {
      Log.debug(
        'Could not find Flint package docs. No agent docs were created.',
      );
      return;
    }

    final files = await _readPackageDocs(sourceDocsDir);
    if (files.isEmpty) {
      Log.debug(
        'No markdown files found in ${sourceDocsDir.path}.',
      );
      return;
    }

    if (!files.containsKey('AGENTS.md')) {
      Log.debug(
        'No AGENTS.md found in ${sourceDocsDir.path}; only docs/*.md files '
        'will be created.',
      );
    } else {
      files['AGENTS.md'] = await _withProjectName(files['AGENTS.md']!, pubspec);
    }

    for (final entry in files.entries) {
      final file = File(path.join(projectRoot.path, entry.key));
      if (await file.exists() && !force) {
        skipped++;
        Log.debug(
          'Skipped existing ${_displayPath(entry.key)}. '
          'Use --force to overwrite.',
        );
        continue;
      }

      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
      written++;
      Log.info('Created ${_displayPath(entry.key)}');
    }

    Log.info(
      'Flint agent docs ready. Written: $written, skipped: $skipped.',
    );
  }

  Future<Directory?> _resolvePackageDocsDir() async {
    final packageUri = await Isolate.resolvePackageUri(
      Uri.parse('package:flint_dart/flint_dart.dart'),
    );
    if (packageUri == null || packageUri.scheme != 'file') {
      return null;
    }

    final libFilePath = packageUri.toFilePath(windows: Platform.isWindows);
    final packageRoot = path.dirname(path.dirname(libFilePath));
    final docsDir = Directory(path.join(packageRoot, 'doc'));

    return docsDir.existsSync() ? docsDir : null;
  }

  Future<Map<String, String>> _readPackageDocs(Directory docsDir) async {
    final docs = <File>[];

    await for (final entity in docsDir.list(followLinks: false)) {
      if (entity is File &&
          path.extension(entity.path).toLowerCase() == '.md') {
        docs.add(entity);
      }
    }

    docs.sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));

    return {
      for (final file in docs)
        _targetPathForDoc(path.basename(file.path)): await file.readAsString(),
    };
  }

  Future<String> _withProjectName(String template, File pubspec) async {
    final projectName = await _projectName(pubspec);
    return template.replaceAll('{{project_name}}', projectName);
  }

  Future<String> _projectName(File pubspec) async {
    final lines = await pubspec.readAsLines();
    for (final line in lines) {
      final match = RegExp(r'^name:\s*(.+)$').firstMatch(line.trim());
      if (match != null) {
        final name = match.group(1)?.trim();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return 'this_app';
  }

  String _targetPathForDoc(String fileName) {
    return fileName.toLowerCase() == 'agents.md'
        ? 'AGENTS.md'
        : path.join('docs', fileName);
  }

  String _displayPath(String relativePath) {
    return relativePath.replaceAll(r'\', '/');
  }
}
