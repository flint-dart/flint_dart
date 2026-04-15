import 'dart:io';

import 'package:flint_dart/src/cli/make_seeder_command.dart';
import 'package:test/test.dart';

void main() {
  group('MakeSeederCommand', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('flint_make_seeder_');
      await Directory('${tempDir.path}/lib/config').create(recursive: true);
      await File('${tempDir.path}/lib/config/seeder_registry.dart').writeAsString('''
import 'package:flint_dart/db.dart';
import 'package:sample/seeders/demo_post_seeder.dart';

Future<void> main() async {
  await DB.autoConnect();

  await runSeeders([
    DemoPostSeeder(),
  ]);
}
''');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('adds new seeder to an existing custom registry', () async {
      final command = MakeSeederCommand.withWorkingDirectory(tempDir.path);

      await command.execute(['UserModelSeeder']);

      final registry =
          await File('${tempDir.path}/lib/config/seeder_registry.dart')
              .readAsString();
      final seederFile =
          File('${tempDir.path}/lib/seeders/user_model_seeder.dart');

      expect(seederFile.existsSync(), isTrue);
      expect(
        registry,
        contains("import '../seeders/user_model_seeder.dart';"),
      );
      expect(registry, contains('    UserModelSeeder(),'));
      expect(registry, contains("import 'package:flint_dart/db.dart';"));
    });

    test('adds new seeder when runSeeders list is on one line', () async {
      await File('${tempDir.path}/lib/config/seeder_registry.dart').writeAsString('''
import 'package:flint_dart/db.dart';
import 'package:sample/seeders/demo_user_seeder.dart';

Future<void> main() async {
  await DB.autoConnect();
  await runSeeders([DemoUserSeeder()]);
}
''');

      final command = MakeSeederCommand.withWorkingDirectory(tempDir.path);

      await command.execute(['PostModelSeeder']);

      final registry =
          await File('${tempDir.path}/lib/config/seeder_registry.dart')
              .readAsString();

      expect(
        registry,
        contains('runSeeders([\n    DemoUserSeeder(),\n    PostModelSeeder(),\n  ])'),
      );
      expect(
        registry,
        contains("import '../seeders/post_model_seeder.dart';"),
      );
    });
  });
}
