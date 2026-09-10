import 'dart:io';

import 'package:flint_dart/src/cli/agent_docs_command.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('AgentDocsCommand', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('flint_agent_docs_');
      await File(path.join(tempDir.path, 'pubspec.yaml')).writeAsString('''
name: agent_sample_app
dependencies:
  flint_dart: any
''');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('copies package markdown docs into the app docs folder', () async {
      final command = AgentDocsCommand.withWorkingDirectory(tempDir.path);

      await command.execute([]);

      final sourceDocsDir = Directory(path.join(Directory.current.path, 'doc'));
      final generatedDocsDir = Directory(path.join(tempDir.path, 'docs'));
      final sourceDocNames = _markdownFileNames(sourceDocsDir)
        ..removeWhere((name) => name.toLowerCase() == 'agents.md');
      final generatedDocNames = _markdownFileNames(generatedDocsDir);

      expect(generatedDocNames, sourceDocNames);
      expect(generatedDocNames, contains('ai.md'));
      expect(generatedDocNames, contains('frontend-ui.md'));
      expect(generatedDocNames, contains('ui-widgets.md'));
      expect(generatedDocNames, contains('logging.md'));
      expect(generatedDocNames, contains('testing.md'));
      expect(generatedDocNames, contains('templates.md'));
      expect(
        File(path.join(generatedDocsDir.path, 'AGENTS.md')).existsSync(),
        isFalse,
      );

      final sourceAuthentication = await File(
        path.join(sourceDocsDir.path, 'authentication.md'),
      ).readAsString();
      final generatedAuthentication = await File(
        path.join(generatedDocsDir.path, 'authentication.md'),
      ).readAsString();

      expect(generatedAuthentication, sourceAuthentication);

      final agents =
          await File(path.join(tempDir.path, 'AGENTS.md')).readAsString();
      final sourceAgents =
          await File(path.join(sourceDocsDir.path, 'AGENTS.md')).readAsString();
      expect(
        agents,
        sourceAgents.replaceAll('{{project_name}}', 'agent_sample_app'),
      );
      expect(agents, contains('docs/ai.md'));
      expect(agents, contains('docs/frontend-ui.md'));
      expect(agents, contains('docs/ui-widgets.md'));
      expect(agents, contains('docs/logging.md'));
      expect(agents, contains('docs/testing.md'));
      expect(agents, contains('docs/templates.md'));
      expect(agents, contains('lib/ui/'));

      final generatedMarkdown = [
        File(path.join(tempDir.path, 'AGENTS.md')),
        ...generatedDocsDir
            .listSync(followLinks: false)
            .whereType<File>()
            .where((file) => path.extension(file.path).toLowerCase() == '.md'),
      ];

      for (final file in generatedMarkdown) {
        final content = (await file.readAsString()).toLowerCase();
        expect(content, isNot(contains('eucloudhost')));
        expect(content, isNot(contains('eucloadhost')));
        expect(content, isNot(contains('admin@eu')));
        expect(content, isNot(contains('support@eu')));
        expect(content, isNot(contains('hybiekay')));
      }
    });

    test('skips existing files unless force is passed', () async {
      final command = AgentDocsCommand.withWorkingDirectory(tempDir.path);
      final docsDir = Directory(path.join(tempDir.path, 'docs'));
      await docsDir.create(recursive: true);

      final agentsFile = File(path.join(tempDir.path, 'AGENTS.md'));
      final authFile = File(path.join(docsDir.path, 'authentication.md'));
      await agentsFile.writeAsString('custom agents');
      await authFile.writeAsString('custom auth');

      await command.execute([]);

      expect(await agentsFile.readAsString(), 'custom agents');
      expect(await authFile.readAsString(), 'custom auth');

      await command.execute(['--force']);

      expect(await agentsFile.readAsString(), contains('agent_sample_app'));
      expect(
        await authFile.readAsString(),
        await File(
          path.join(Directory.current.path, 'doc', 'authentication.md'),
        ).readAsString(),
      );
    });
  });
}

List<String> _markdownFileNames(Directory directory) {
  final names = directory
      .listSync(followLinks: false)
      .whereType<File>()
      .where((file) => path.extension(file.path).toLowerCase() == '.md')
      .map((file) => path.basename(file.path))
      .toList();

  names.sort();
  return names;
}
