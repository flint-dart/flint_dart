import 'dart:io';

import 'package:flint_dart/src/cli/web_ui_builder.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('FlintWebUiBuilder', () {
    late Directory originalCurrent;
    late Directory tempDir;

    setUp(() {
      originalCurrent = Directory.current;
      tempDir = Directory.systemTemp.createTempSync('flint_web_ui_builder_');
      Directory.current = tempDir;
    });

    tearDown(() {
      Directory.current = originalCurrent;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('uses sibling public directory for flint_ui entrypoints', () {
      final uiDir = Directory(path.join(tempDir.path, 'flint_ui'))
        ..createSync(recursive: true);
      final publicDir = Directory(path.join(tempDir.path, 'public'))
        ..createSync(recursive: true);
      final entry = File(path.join(uiDir.path, 'main.dart'))
        ..writeAsStringSync('void main() {}');

      final build = FlintWebUiBuilder.resolve(entryArg: entry.path);

      expect(build, isNotNull);
      expect(
          path.normalize(build!.webDir.path), path.normalize(publicDir.path));
      expect(
        path.normalize(build.jsOut),
        path.normalize(path.join(publicDir.path, 'main.dart.js')),
      );
    });

    test('discovers app-owned lib/ui entrypoints', () {
      final uiDir = Directory(path.join(tempDir.path, 'lib', 'ui'))
        ..createSync(recursive: true);
      Directory(path.join(tempDir.path, 'public')).createSync(recursive: true);
      File(path.join(uiDir.path, 'main.dart')).writeAsStringSync(
        'void main() {}',
      );

      final entry = FlintWebUiBuilder.findEntry();
      final build = FlintWebUiBuilder.resolve();

      expect(entry, isNotNull);
      expect(
        path.normalize(entry!.path),
        path.normalize(path.join('lib', 'ui', 'main.dart')),
      );
      expect(build, isNotNull);
      expect(path.normalize(build!.webDir.path), path.normalize('public'));
      expect(
        path.normalize(build.jsOut),
        path.normalize(
          path.join(
            'public',
            'assets',
            'js',
            'flint-ui',
            'main.dart.js',
          ),
        ),
      );
      expect(
        path.normalize(build.cssOut!),
        path.normalize(
          path.join(
            'public',
            'assets',
            'css',
            'flint-ui',
            'style.css',
          ),
        ),
      );
    });

    test('discovers page bundle config from component registry', () {
      File('pubspec.yaml').writeAsStringSync('name: demo_app\n');
      final uiDir = Directory(path.join('lib', 'ui'))
        ..createSync(recursive: true);
      Directory(path.join(uiDir.path, 'styles')).createSync(recursive: true);
      Directory('public').createSync();

      File(path.join(uiDir.path, 'main.dart')).writeAsStringSync('''
import 'package:flint_ui/flint_ui.dart';

import 'component_registry.dart';
import 'styles/demo_design.dart';

void main() {
  createFlintApp(
    '#app',
    registry: componentRegistry,
    rootDesign: demoRootDesign,
  );
}
''');
      File(path.join(uiDir.path, 'styles', 'demo_design.dart'))
          .writeAsStringSync('''
import 'package:flint_ui/flint_ui.dart';

final demoRootDesign = RootDesign(name: 'demo');
''');
      File(path.join(uiDir.path, 'component_registry.dart')).writeAsStringSync(
        '''
import 'package:flint_ui/flint_ui.dart';

import 'pages/home_page.dart';
import 'pages/staff_dashboard_page.dart';

final componentRegistry = PageRegistry({
  'Home': (props) => HomePage(props),
  'StaffDashboard': (props) => StaffDashboardPage(props),
});
''',
      );
      Directory(path.join(uiDir.path, 'pages')).createSync(recursive: true);
      File(path.join(uiDir.path, 'pages', 'home_page.dart')).writeAsStringSync(
        'class HomePage { HomePage(Map<String, dynamic> props); }',
      );
      File(path.join(uiDir.path, 'pages', 'staff_dashboard_page.dart'))
          .writeAsStringSync(
        'class StaffDashboardPage { StaffDashboardPage(Map<String, dynamic> props); }',
      );

      final build = FlintWebUiBuilder.resolve();
      final config = FlintWebUiBuilder.discoverPageBundleConfig(build!);

      expect(config, isNotNull);
      expect(config!.registryImport,
          'package:demo_app/ui/component_registry.dart');
      expect(config.registryName, 'componentRegistry');
      expect(config.rootDesignImport,
          'package:demo_app/ui/styles/demo_design.dart');
      expect(config.rootDesignName, 'demoRootDesign');
      expect(config.pages, {
        'Home': 'home',
        'StaffDashboard': 'staff_dashboard',
      });
      expect(config.pageTargets['Home']!.importUri,
          'package:demo_app/ui/pages/home_page.dart');
      expect(config.pageTargets['Home']!.className, 'HomePage');
      expect(config.pageTargets['StaffDashboard']!.importUri,
          'package:demo_app/ui/pages/staff_dashboard_page.dart');
      expect(config.pageTargets['StaffDashboard']!.className,
          'StaffDashboardPage');
    });

    test('compile writes hashed app bundle filenames', () async {
      final uiDir = Directory(path.join('lib', 'ui'))
        ..createSync(recursive: true);
      final publicDir = Directory('public')..createSync();
      final entry = File(path.join(uiDir.path, 'main.dart'))
        ..writeAsStringSync('void main() { print("hello"); }');
      final build = FlintWebUiBuild(
        entry: entry,
        uiDir: uiDir,
        webDir: publicDir,
        jsOut: path.join(
          publicDir.path,
          'assets',
          'js',
          'flint-ui',
          'main.dart.js',
        ),
      );

      await FlintWebUiBuilder.compile(build);

      final outDir = Directory(path.dirname(build.jsOut));
      final scripts = outDir
          .listSync()
          .whereType<File>()
          .map((file) => path.basename(file.path))
          .toList();

      expect(scripts, isNot(contains('main.dart.js')));
      expect(
        scripts,
        contains(matches(RegExp(r'^main\.[a-f0-9]{12}\.dart\.js$'))),
      );
      expect(
        scripts,
        contains(matches(RegExp(r'^main\.[a-f0-9]{12}\.dart\.js\.map$'))),
      );
      expect(
        scripts,
        contains(matches(RegExp(r'^main\.[a-f0-9]{12}\.dart\.js\.gz$'))),
      );
      expect(
        scripts,
        contains(matches(RegExp(r'^main\.[a-f0-9]{12}\.dart\.js\.map\.gz$'))),
      );
      expect(File(path.join(publicDir.path, 'flint-sw.js')).existsSync(), true);
    });

    test('precompressDirectory writes gzip for JSON and SVG assets', () async {
      final publicDir = Directory('public')..createSync();
      File(path.join(publicDir.path, 'manifest.json'))
          .writeAsStringSync('{"ok":true}');
      File(path.join(publicDir.path, 'logo.svg')).writeAsStringSync(
        '<svg xmlns="http://www.w3.org/2000/svg"></svg>',
      );

      await FlintWebUiBuilder.precompressDirectory(publicDir);

      expect(File(path.join(publicDir.path, 'manifest.json.gz')).existsSync(),
          true);
      expect(File(path.join(publicDir.path, 'logo.svg.gz')).existsSync(), true);
    });
  });
}
