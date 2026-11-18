import 'dart:io';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';

class MakeSeederCommand extends FlintCommand {
  final String? workingDirectory;

  MakeSeederCommand()
      : workingDirectory = null,
        super('--make-seeder', 'Create a new framework database seeder');

  MakeSeederCommand.withWorkingDirectory(this.workingDirectory)
      : super('--make-seeder', 'Create a new framework database seeder');

  @override
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      Log.debug(
          'Please provide a seeder name. Example: flint --make-seeder UserSeeder');
      exit(1);
    }

    final seederraw = args[0];

    // Convert CamelCase class name to snake_case file name

    var seederName = seederraw.toLowerCase().endsWith("seeder")
        ? seederraw
        : "${seederraw}Seeder";
    final snakeCaseFileName = _toSnakeCase(seederName);
    final projectRoot = Directory(
      workingDirectory ?? Directory.current.path,
    ).absolute.path;

    final seedersDir = Directory('$projectRoot/lib/seeders');
    if (!seedersDir.existsSync()) {
      seedersDir.createSync(recursive: true);
    }

    final seederFile = File('$projectRoot/lib/seeders/$snakeCaseFileName.dart');
    if (seederFile.existsSync()) {
      Log.debug('Seeder already exists!');
      return;
    }

    // Create the seeder file.
    final seederContent = '''
import 'package:flint_dart/flint_dart.dart';

class $seederName extends Seeder {
  @override
  Future<void> run() async {
    // TODO: Add seed data here
    Log.debug('$seederName ran successfully.');
  }
}
''';

    await seederFile.writeAsString(seederContent);
    Log.debug(
        'Seeder $seederName created at lib/seeders/$snakeCaseFileName.dart');

    // Ensure framework seeder registry exists.
    final configDir = Directory('$projectRoot/lib/config');
    if (!configDir.existsSync()) {
      configDir.createSync(recursive: true);
    }

    final seederRegistryFile =
        File('$projectRoot/lib/config/seeder_registry.dart');
    if (!seederRegistryFile.existsSync()) {
      await seederRegistryFile.writeAsString('''
import 'package:flint_dart/flint_dart.dart';

class AppSeederRegistry extends SeederRegistry {
  const AppSeederRegistry();

  @override
  Iterable<Seeder> get seeders => [
  ];
}

Future<void> main() => const AppSeederRegistry().registerAll();
''');
      Log.debug('Seeder registry created at lib/config/seeder_registry.dart');
    }

    // Update registry with the new seeder import and instance.
    final lines = await seederRegistryFile.readAsLines();

    final importLine = "import '../seeders/$snakeCaseFileName.dart';";
    if (!lines.any((line) => line.trim() == importLine)) {
      final insertionIndex = _findImportInsertionIndex(lines);
      lines.insert(insertionIndex, importLine);
    }

    final registryEntry = '    $seederName(),';
    if (!lines.any((line) => line.trim() == registryEntry.trim())) {
      final updatedRegistry = _insertSeederIntoRegistry(
        lines.join('\n'),
        seederName,
      );
      await seederRegistryFile.writeAsString(updatedRegistry);
      Log.debug('$seederName added to lib/config/seeder_registry.dart');
      return;
    }

    await seederRegistryFile.writeAsString(lines.join('\n'));
    Log.debug('$seederName added to lib/config/seeder_registry.dart');
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

  int _findImportInsertionIndex(List<String> lines) {
    var lastImportIndex = -1;

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().startsWith('import ')) {
        lastImportIndex = i;
      }
    }

    if (lastImportIndex != -1) {
      return lastImportIndex + 1;
    }

    final futureMainIndex = lines.indexWhere(
      (line) => line.contains('Future<void> main()'),
    );
    if (futureMainIndex != -1) {
      return futureMainIndex;
    }

    return 0;
  }

  String _insertSeederIntoRegistry(String content, String seederName) {
    final registryMatch = RegExp(
      r'Iterable<Seeder>\s+get\s+seeders\s*=>\s*\[(.*?)\]\s*;',
      dotAll: true,
    ).firstMatch(content);

    if (registryMatch != null) {
      final currentEntries = registryMatch.group(1)?.trim() ?? '';
      final normalizedEntries = _normalizeSeederEntries(currentEntries);
      final newEntry = '    $seederName(),';

      final replacement = normalizedEntries.isEmpty
          ? 'Iterable<Seeder> get seeders => [\n$newEntry\n  ];'
          : 'Iterable<Seeder> get seeders => [\n$normalizedEntries\n$newEntry\n  ];';

      return content.replaceRange(
        registryMatch.start,
        registryMatch.end,
        replacement,
      );
    }

    final legacyMatch = RegExp(
      r'runSeeders\s*\(\s*\[(.*?)\]\s*\)',
      dotAll: true,
    ).firstMatch(content);

    if (legacyMatch == null) {
      throw StateError(
        'Could not update lib/config/seeder_registry.dart: seeders list not found.',
      );
    }

    final currentEntries = legacyMatch.group(1)?.trim() ?? '';
    final normalizedEntries = _normalizeSeederEntries(currentEntries);
    final newEntry = '    $seederName(),';

    final replacement = normalizedEntries.isEmpty
        ? 'runSeeders([\n$newEntry\n  ])'
        : 'runSeeders([\n$normalizedEntries\n$newEntry\n  ])';

    return content.replaceRange(
        legacyMatch.start, legacyMatch.end, replacement);
  }

  String _normalizeSeederEntries(String entries) {
    if (entries.isEmpty) return '';

    final parts = entries
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '';

    return parts
        .map((part) => part.endsWith(',') ? part : '$part,')
        .map((part) => '    $part')
        .join('\n');
  }
}
