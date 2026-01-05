import 'dart:io';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';

class MakeSeederCommand extends FlintCommand {
  MakeSeederCommand()
      : super('make:seeder', 'Create a new standalone database seeder');

  @override
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      Log.debug(
          'Please provide a seeder name. Example: flint make:seeder UserSeeder');
      exit(1);
    }

    final seederraw = args[0];

    // Convert CamelCase class name to snake_case file name

    var seederName = seederraw.toLowerCase().endsWith("seeder")
        ? seederraw
        : "${seederraw}Seeder";
    final snakeCaseFileName = _toSnakeCase(seederName);

    final seedersDir = Directory('lib/seeders');
    if (!seedersDir.existsSync()) {
      seedersDir.createSync(recursive: true);
    }

    final seederFile = File('lib/seeders/$snakeCaseFileName.dart');
    if (seederFile.existsSync()) {
      Log.debug('Seeder already exists!');
      return;
    }

    // 1️⃣ Create the seeder file
    final seederContent = '''
import 'package:flint_dart/logs.dart';

class $seederName {
  static Future<void> run() async {
    // TODO: Add seed data here
    Log.debug('$seederName ran successfully!');
  }
}
''';

    await seederFile.writeAsString(seederContent);
    Log.debug(
        'Seeder $seederName created at lib/seeders/$snakeCaseFileName.dart');

    // 2️⃣ Ensure seeder.dart exists
    final seederMainFile = File('lib/seeders/seeder.dart');
    if (!seederMainFile.existsSync()) {
      await seederMainFile.writeAsString('''
void main() async {
  // Seeders will be added here automatically
}
''');
      Log.debug('Seeder registry created at lib/seeders/seeder.dart');
    }

    // 3️⃣ Update seeder.dart with new import and main() call
    final lines = await seederMainFile.readAsLines();

    final importLine = "import '$snakeCaseFileName.dart';";
    if (!lines.any((line) => line.trim() == importLine)) {
      lines.insert(0, importLine);
    }

    // Find main() closing brace
    final mainEndIndex = lines.lastIndexOf('}', lines.length - 1);

    final seederCallLine = '  await $seederName.run();';
    if (!lines.any((line) => line.trim() == seederCallLine.trim())) {
      lines.insert(mainEndIndex, seederCallLine);
    }

    await seederMainFile.writeAsString(lines.join('\n'));
    Log.debug('$seederName added to main() in seeder.dart');
  }

  /// Converts CamelCase to snake_case
  String _toSnakeCase(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char.toUpperCase() == char && i > 0) {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }
}
