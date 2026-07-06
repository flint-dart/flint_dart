import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:path/path.dart' as path;

class MakePageCommand extends FlintCommand {
  MakePageCommand() : super('--make-page', '  Creates a new Flint UI page');

  @override
  Future<void> execute(List<String> args) async {
    if (args.isEmpty || args.first == '--help' || args.first == '-h') {
      _printHelp();
      return;
    }

    final name = args.first;
    final register = !args.contains('--no-register');
    final pageName = _toPageName(name);
    final className = '${_toPascalCase(pageName)}Page';
    final fileName = '${_toSnakeCase(pageName)}_page.dart';

    final uiRoot = _resolveUiRoot();
    final pagesDir = Directory(path.join(uiRoot.path, 'pages'));
    if (!pagesDir.existsSync()) pagesDir.createSync(recursive: true);

    final pageFile = File(path.join(pagesDir.path, fileName));
    if (pageFile.existsSync()) {
      Log.debug('Page already exists: ${pageFile.path}');
      return;
    }

    pageFile.writeAsStringSync(_pageTemplate(className, pageName));
    Log.info('Page created: ${pageFile.path}');

    _ensureMainFile(uiRoot);

    if (register) {
      _ensureRegistryFile(uiRoot);
      _registerPage(uiRoot, pageName, className, fileName);
    }
  }

  Directory _resolveUiRoot() {
    final candidates = [
      Directory(path.join('lib', 'ui')),
      Directory('flint_ui'),
      Directory(path.join('flint_ui', 'flint_ui')),
      Directory(path.join('lib', 'flint_ui')),
    ];

    for (final candidate in candidates) {
      if (candidate.existsSync()) return candidate;
    }

    final dir = Directory(path.join('lib', 'ui'));
    dir.createSync(recursive: true);
    return dir;
  }

  void _ensureMainFile(Directory uiRoot) {
    final file = File(path.join(uiRoot.path, 'main.dart'));
    if (file.existsSync()) return;

    file.writeAsStringSync('''
import 'package:flint_ui/flint_ui.dart';

import 'component_registry.dart';

void main() {
  createFlintApp('#app', registry: componentRegistry);
}
''');
    Log.info('Created Flint UI entry: ${file.path}');
  }

  void _ensureRegistryFile(Directory uiRoot) {
    final file = File(path.join(uiRoot.path, 'component_registry.dart'));
    if (file.existsSync()) return;

    file.writeAsStringSync('''
import 'package:flint_ui/flint_ui.dart';

final componentRegistry = PageRegistry({
});
''');
    Log.info('Created component registry: ${file.path}');
  }

  void _registerPage(
    Directory uiRoot,
    String pageName,
    String className,
    String fileName,
  ) {
    final registryFile =
        File(path.join(uiRoot.path, 'component_registry.dart'));
    var content = registryFile.readAsStringSync();
    final importLine = "import 'pages/$fileName';";
    final entryLine = "  '$pageName': (props) => $className(props),";

    if (!content.contains(importLine)) {
      final packageImport = "import 'package:flint_ui/flint_ui.dart';";
      if (content.contains(packageImport)) {
        content = content.replaceFirst(
          packageImport,
          '$packageImport\n$importLine',
        );
      } else {
        content = '$importLine\n$content';
      }
    }

    if (!content.contains("'$pageName':")) {
      final registryStart =
          RegExp(r'(?:PageRegistry|FlintComponentRegistry)\s*\(\s*\{');
      final match = registryStart.firstMatch(content);
      if (match == null) {
        Log.debug(
            'Could not update registry automatically: ${registryFile.path}');
        registryFile.writeAsStringSync(content);
        return;
      }

      content = content.replaceRange(
        match.end,
        match.end,
        '\n$entryLine',
      );
    }

    registryFile.writeAsStringSync(content);
    Log.info('Registered page "$pageName" in ${registryFile.path}');
  }

  String _pageTemplate(String className, String pageName) {
    return '''
import 'package:flint_ui/flint_ui.dart';

class $className extends FlintComponent {
  final Map<String, dynamic> props;

  $className(this.props);

  @override
  FlintNode build() {
    final title = props['title']?.toString() ?? '$pageName';

    return Container(
      props: {'className': '${_toKebabCase(pageName)}-page'},
      children: [
        Column(
          props: {'className': 'page-shell'},
          children: [
            h('h1', children: [title]),
            h('p', children: [
              'This page is rendered by Flint UI.',
            ]),
          ],
        ),
      ],
    );
  }
}
''';
  }

  String _toPageName(String input) {
    var value = input.trim().replaceAll(RegExp(r'[^A-Za-z0-9_ -]'), ' ');
    if (value.toLowerCase().endsWith('page')) {
      value = value.substring(0, value.length - 4);
    }
    return _toPascalCase(value);
  }

  String _toPascalCase(String input) {
    final words = input
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .split(RegExp(r'[\s_-]+'))
        .where((word) => word.isNotEmpty);
    return words.map((word) {
      final lower = word.toLowerCase();
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    }).join();
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .toLowerCase();
  }

  String _toKebabCase(String input) => _toSnakeCase(input).replaceAll('_', '-');

  void _printHelp() {
    Log.debug('''
Usage: flint make:page <Name> [options]

Options:
  --no-register    Create the page file without updating component_registry.dart
  --help, -h       Show this help

Examples:
  flint make:page Dashboard
  flint make:page Settings --no-register
''');
  }
}
