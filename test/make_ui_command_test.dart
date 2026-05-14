import 'dart:io';

import 'package:flint_dart/src/cli/make_ui_command.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('MakeUiCommand', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('flint_make_ui_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates and registers a page with optional root design', () async {
      final command = MakeUiCommand.withWorkingDirectory(tempDir.path);

      await command.execute([
        '--p',
        '/',
        '-page',
        'Portfolio',
        '--with-root-design',
      ]);

      final uiRoot = path.join(tempDir.path, 'flint_ui', 'flint_ui');
      final pageFile = File(path.join(uiRoot, 'pages', 'portfolio_page.dart'));
      final registryFile = File(path.join(uiRoot, 'component_registry.dart'));
      final mainFile = File(path.join(uiRoot, 'main.dart'));
      final rootDesignFile =
          File(path.join(uiRoot, 'components', 'root_design.dart'));

      expect(pageFile.existsSync(), isTrue);
      expect(registryFile.existsSync(), isTrue);
      expect(mainFile.existsSync(), isTrue);
      expect(rootDesignFile.existsSync(), isTrue);

      final page = await pageFile.readAsString();
      expect(page, contains('class PortfolioPage extends FlintComponent'));
      expect(page, contains('PageShell('));

      final registry = await registryFile.readAsString();
      expect(registry, contains("import 'pages/portfolio_page.dart';"));
      expect(
        registry,
        contains("'Portfolio': (props) => PortfolioPage(props),"),
      );

      final main = await mainFile.readAsString();
      expect(main, contains("import 'components/root_design.dart';"));
      expect(main, contains('rootDesign: appRootDesign'));

      final rootDesign = await rootDesignFile.readAsString();
      expect(rootDesign, contains('final appRootDesign = RootDesign('));
      expect(rootDesign, contains('body: DartStyle('));
    });

    test('creates component and section templates', () async {
      final command = MakeUiCommand.withWorkingDirectory(tempDir.path);

      await command.execute(['--component', 'ProjectCard']);
      await command.execute(['--section', 'Skills']);

      final uiRoot = path.join(tempDir.path, 'flint_ui', 'flint_ui');
      final componentFile =
          File(path.join(uiRoot, 'components', 'project_card.dart'));
      final sectionFile =
          File(path.join(uiRoot, 'components', 'skills_section.dart'));

      expect(componentFile.existsSync(), isTrue);
      expect(sectionFile.existsSync(), isTrue);

      final component = await componentFile.readAsString();
      expect(component, contains('class ProjectCard extends FlintComponent'));
      expect(component, contains('Box('));

      final section = await sectionFile.readAsString();
      expect(section, contains('class SkillsSection extends FlintComponent'));
      expect(section, contains('ResponsiveGrid('));
    });

    test('updates an existing registry without duplicating entries', () async {
      final uiRoot = Directory(
        path.join(tempDir.path, 'flint_ui', 'flint_ui'),
      );
      await uiRoot.create(recursive: true);
      await File(path.join(uiRoot.path, 'component_registry.dart'))
          .writeAsString('''
import 'package:flint_ui/flint_ui.dart';

final componentRegistry = FlintComponentRegistry({
});
''');

      final command = MakeUiCommand.withWorkingDirectory(tempDir.path);

      await command.execute(['--page', 'Dashboard']);
      await command.execute(['--page', 'Dashboard']);

      final registry =
          await File(path.join(uiRoot.path, 'component_registry.dart'))
              .readAsString();

      expect("Dashboard':".allMatches(registry), hasLength(1));
      expect("dashboard_page.dart".allMatches(registry), hasLength(1));
    });
  });
}
