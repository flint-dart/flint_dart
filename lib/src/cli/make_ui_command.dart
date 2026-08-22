import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:path/path.dart' as path;

class MakeUiCommand extends FlintCommand {
  final String? workingDirectory;

  MakeUiCommand()
      : workingDirectory = null,
        super('--make-ui', '  Generates Flint UI pages and components');

  MakeUiCommand.withWorkingDirectory(this.workingDirectory)
      : super('--make-ui', '  Generates Flint UI pages and components');

  @override
  Future<void> execute(List<String> args) async {
    if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
      _printHelp();
      return;
    }

    final options = _MakeUiOptions.parse(args);
    final uiRoot = _resolveUiRoot(options.uiPath);

    if (options.rootDesign) {
      _ensureRootDesign(uiRoot);
      _ensureMainFile(uiRoot, withRootDesign: true);
    }

    if (options.page != null) {
      _makePage(uiRoot, options.page!, withRootDesign: options.withRootDesign);
    }

    if (options.component != null) {
      _makeComponent(uiRoot, options.component!);
    }

    if (options.section != null) {
      _makeSection(uiRoot, options.section!);
    }

    if (!options.hasTarget) {
      Log.debug(
          'Please provide --page, --component, --section, or --root-design.');
      _printHelp();
    }
  }

  Directory _projectRoot() =>
      Directory(workingDirectory ?? Directory.current.path);

  Directory _resolveUiRoot(String? uiPath) {
    final root = _projectRoot();
    if (uiPath != null && uiPath.trim().isNotEmpty && uiPath != '/') {
      final explicit = Directory(path.join(root.path, uiPath));
      explicit.createSync(recursive: true);
      return explicit;
    }

    final appUi = Directory(path.join(root.path, 'lib', 'ui'));
    if (appUi.existsSync()) return appUi;

    final flat = Directory(path.join(root.path, 'flint_ui'));
    if (flat.existsSync() &&
        (File(path.join(flat.path, 'main.dart')).existsSync() ||
            File(path.join(flat.path, 'component_registry.dart'))
                .existsSync())) {
      return flat;
    }

    final nested = Directory(path.join(root.path, 'flint_ui', 'flint_ui'));
    if (nested.existsSync()) return nested;

    appUi.createSync(recursive: true);
    return appUi;
  }

  void _makePage(
    Directory uiRoot,
    String rawName, {
    required bool withRootDesign,
  }) {
    final name = _cleanName(rawName, suffixToRemove: 'page');
    final className = '${_toPascalCase(name)}Page';
    final componentName = _toPascalCase(name);
    final fileName = '${_toSnakeCase(name)}_page.dart';
    final pagesDir = Directory(path.join(uiRoot.path, 'pages'));
    pagesDir.createSync(recursive: true);

    final file = File(path.join(pagesDir.path, fileName));
    if (file.existsSync()) {
      Log.debug('Page already exists: ${file.path}');
      return;
    }

    file.writeAsStringSync(_pageTemplate(className, componentName));
    Log.info('Page created: ${file.path}');

    _ensureMainFile(uiRoot, withRootDesign: withRootDesign);
    _ensureRegistryFile(uiRoot);
    _registerPage(uiRoot, componentName, className, fileName);

    if (withRootDesign) {
      _ensureRootDesign(uiRoot);
      _ensureMainFile(uiRoot, withRootDesign: true);
    }
  }

  void _makeComponent(Directory uiRoot, String rawName) {
    final name = _cleanName(rawName);
    final className = _toPascalCase(name);
    final fileName = '${_toSnakeCase(name)}.dart';
    final componentsDir = Directory(path.join(uiRoot.path, 'components'));
    componentsDir.createSync(recursive: true);

    final file = File(path.join(componentsDir.path, fileName));
    if (file.existsSync()) {
      Log.debug('Component already exists: ${file.path}');
      return;
    }

    file.writeAsStringSync(_componentTemplate(className));
    Log.info('Component created: ${file.path}');
  }

  void _makeSection(Directory uiRoot, String rawName) {
    final name = _cleanName(rawName, suffixToRemove: 'section');
    final className = '${_toPascalCase(name)}Section';
    final fileName = '${_toSnakeCase(name)}_section.dart';
    final componentsDir = Directory(path.join(uiRoot.path, 'components'));
    componentsDir.createSync(recursive: true);

    final file = File(path.join(componentsDir.path, fileName));
    if (file.existsSync()) {
      Log.debug('Section already exists: ${file.path}');
      return;
    }

    file.writeAsStringSync(_sectionTemplate(className, _toPascalCase(name)));
    Log.info('Section created: ${file.path}');
  }

  void _ensureMainFile(Directory uiRoot, {required bool withRootDesign}) {
    final file = File(path.join(uiRoot.path, 'main.dart'));
    if (!file.existsSync()) {
      file.writeAsStringSync(
          withRootDesign ? _mainWithRootDesign() : _mainTemplate());
      Log.info('Created Flint UI entry: ${file.path}');
      return;
    }

    if (!withRootDesign) return;

    var content = file.readAsStringSync();
    if (!content.contains("import 'components/root_design.dart';")) {
      final registryImport = "import 'component_registry.dart';";
      content = content.contains(registryImport)
          ? content.replaceFirst(
              registryImport,
              "$registryImport\nimport 'components/root_design.dart';",
            )
          : "import 'components/root_design.dart';\n$content";
    }

    if (!content.contains('rootDesign: appRootDesign')) {
      content = content.replaceFirst(
        'createFlintApp(\'#app\', registry: componentRegistry);',
        'createFlintApp(\n'
            '    \'#app\',\n'
            '    registry: componentRegistry,\n'
            '    rootDesign: appRootDesign,\n'
            '  );',
      );
    }

    file.writeAsStringSync(content);
  }

  void _ensureRegistryFile(Directory uiRoot) {
    final file = File(path.join(uiRoot.path, 'component_registry.dart'));
    if (file.existsSync()) return;

    file.writeAsStringSync('''
import 'package:flint_dart/ui.dart';

final componentRegistry = PageRegistry({
});
''');
    Log.info('Created component registry: ${file.path}');
  }

  void _ensureRootDesign(Directory uiRoot) {
    final componentsDir = Directory(path.join(uiRoot.path, 'components'));
    componentsDir.createSync(recursive: true);
    final file = File(path.join(componentsDir.path, 'root_design.dart'));
    if (file.existsSync()) return;

    file.writeAsStringSync('''
import 'package:flint_dart/ui.dart';

const appTheme = FlintTheme(
  colors: {
    'pageBackground': Color('#f8fafc'),
    'pageText': Color('#101828'),
    'surface': Color('#ffffff'),
    'surfaceBorder': Color('#e4e7ec'),
    'primarySolid': Colors.blue600,
    'primarySolidHover': Colors.blue700,
    'primarySoft': Colors.blue50,
    'primaryText': Colors.blue700,
  },
  spacing: {
    '4': SizeValue.rem(1),
    '6': SizeValue.rem(1.5),
  },
  radii: {
    'md': 8,
    'lg': 12,
  },
);

final appRootDesign = RootDesign(
  theme: appTheme,
  all: const DartStyle(boxSizing: BoxSizing.borderBox),
  html: const DartStyle(scrollBehavior: ScrollBehavior.smooth),
  body: DartStyle(
    margin: EdgeInsets.all(0),
    fontFamily: FontFamily.systemSans,
    background: ThemeToken.color('pageBackground'),
    color: ThemeToken.color('pageText'),
  ),
  links: const DartStyle(
    color: Color('inherit'),
    textDecoration: TextDecorationStyle.none,
  ),
);
''');
    Log.info('Created root design: ${file.path}');
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
      final packageImport = "import 'package:flint_dart/ui.dart';";
      final legacyImport = "import 'package:flint_ui/flint_ui.dart';";
      if (content.contains(packageImport)) {
        content = content.replaceFirst(packageImport, '$packageImport\n$importLine');
      } else if (content.contains(legacyImport)) {
        content = content.replaceFirst(legacyImport, '$legacyImport\n$importLine');
      } else {
        content = '$importLine\n$content';
      }
    }

    if (!content.contains("'$pageName':")) {
      final match = RegExp(r'(?:PageRegistry|FlintComponentRegistry)\s*\(\s*\{')
          .firstMatch(content);
      if (match == null) {
        Log.debug(
            'Could not update registry automatically: ${registryFile.path}');
        registryFile.writeAsStringSync(content);
        return;
      }
      content = content.replaceRange(match.end, match.end, '\n$entryLine');
    }

    registryFile.writeAsStringSync(content);
    Log.info('Registered page "$pageName" in ${registryFile.path}');
  }

  String _mainTemplate() {
    return '''
import 'package:flint_dart/ui.dart';

import 'component_registry.dart';

void main() {
  createFlintApp('#app', registry: componentRegistry);
}
''';
  }

  String _mainWithRootDesign() {
    return '''
import 'package:flint_dart/ui.dart';

import 'component_registry.dart';
import 'components/root_design.dart';

void main() {
  createFlintApp(
    '#app',
    registry: componentRegistry,
    rootDesign: appRootDesign,
  );
}
''';
  }

  String _pageTemplate(String className, String pageName) {
    return '''
import 'package:flint_dart/ui.dart';

class $className extends FlintComponent {
  final Map<String, dynamic> props;

  $className(this.props);

  @override
  FlintNode build() {
    return PageShell(
      header: PageHeader(
        title: props['title']?.toString() ?? '$pageName',
        description: 'Generated with Flint UI.',
      ),
      child: Section(
        title: '$pageName',
        child: Text.p('Start building this page in Dart.'),
      ),
    );
  }
}
''';
  }

  String _componentTemplate(String className) {
    return '''
import 'package:flint_dart/ui.dart';

class $className extends FlintComponent {
  @override
  FlintNode build() {
    return Box(
      dartStyle: const DartStyle(
        display: Display.grid,
        gap: 12,
        padding: EdgeInsets.all(16),
        radius: 8,
        background: Colors.white,
        border: Border.all(color: Colors.slate200),
      ),
      child: Text('$className'),
    );
  }
}
''';
  }

  String _sectionTemplate(String className, String title) {
    return '''
import 'package:flint_dart/ui.dart';

class $className extends FlintComponent {
  @override
  FlintNode build() {
    return Section(
      title: '$title',
      description: 'Generated section.',
      child: ResponsiveGrid(
        minItemWidth: 240,
        gap: 16,
        children: [
          StatCard(label: 'Metric', value: '0'),
          StatCard(label: 'Status', value: 'Ready', tone: Tone.success),
        ],
      ),
    );
  }
}
''';
  }

  String _cleanName(String input, {String? suffixToRemove}) {
    var value = input.trim().replaceAll(RegExp(r'[^A-Za-z0-9_ -]'), ' ');
    if (suffixToRemove != null &&
        value.toLowerCase().endsWith(suffixToRemove.toLowerCase())) {
      value = value.substring(0, value.length - suffixToRemove.length);
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

  void _printHelp() {
    Log.debug('''
Usage:
  flint --make-ui --page Portfolio [--with-root-design]
  flint --make-ui --component ProjectCard
  flint --make-ui --section Skills
  flint --make-ui --root-design

Aliases:
  --page, -page
  --component, -component
  --section, -section
  --root-design, -root-design
  --path, --p, -p

Examples:
  flint --make-ui --p lib/ui -page Portfolio
  flint --make-ui --c / -component ProjectCard
  flint --make-ui -root-design
''');
  }
}

class _MakeUiOptions {
  final String? uiPath;
  final String? page;
  final String? component;
  final String? section;
  final bool rootDesign;
  final bool withRootDesign;

  const _MakeUiOptions({
    this.uiPath,
    this.page,
    this.component,
    this.section,
    this.rootDesign = false,
    this.withRootDesign = false,
  });

  bool get hasTarget =>
      page != null || component != null || section != null || rootDesign;

  factory _MakeUiOptions.parse(List<String> args) {
    String? uiPath;
    String? page;
    String? component;
    String? section;
    var rootDesign = false;
    var withRootDesign = false;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      String? nextValue() {
        if (i + 1 >= args.length) return null;
        final value = args[++i];
        return value.startsWith('-') ? null : value;
      }

      switch (arg) {
        case '--p':
        case '-p':
        case '--c':
        case '-c':
        case '--path':
          uiPath = nextValue();
          break;
        case '--page':
        case '-page':
          page = nextValue();
          break;
        case '--component':
        case '-component':
          component = nextValue();
          break;
        case '--section':
        case '-section':
          section = nextValue();
          break;
        case '--root-design':
        case '-root-design':
          rootDesign = true;
          break;
        case '--with-root-design':
          withRootDesign = true;
          break;
      }
    }

    return _MakeUiOptions(
      uiPath: uiPath,
      page: page,
      component: component,
      section: section,
      rootDesign: rootDesign,
      withRootDesign: withRootDesign,
    );
  }
}
