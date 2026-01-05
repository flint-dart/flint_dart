// lib/cli/make_model_command.dart
import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';

class MakeModelCommand extends FlintCommand {
  MakeModelCommand() : super('make:model', 'Creates a new model class');

  @override
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      Log.debug('❌ Please provide a model name.');
      return;
    }

    final name = args[0];
    final className = _capitalize(name);
    final fileName = _toSnakeCase(name);

    final content = _generateModelTemplate(className, fileName);

    final dir = Directory('lib/models');
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('${dir.path}/$fileName.dart');
    if (await file.exists()) {
      Log.debug('⚠️ Model $fileName.dart already exists.');
      return;
    }

    await file.writeAsString(content);
    Log.debug('✅ Model created: lib/models/$fileName.dart');
    await _registerTable(className, fileName);
  }

  String _capitalize(String str) =>
      str.isEmpty ? str : '${str[0].toUpperCase()}${str.substring(1)}';

  String _toSnakeCase(String input) =>
      input.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) {
        return '${match.group(1)}_${match.group(2)}';
      }).toLowerCase();

  String _generateModelTemplate(String className, String fileName) {
    return '''
import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

class $className extends Model<$className> {
  $className() : super(() => $className());

  // Define your fields here
  String? get name => getAttribute("name");

  @override
  Table get table => Table(
    name: '${fileName.split('.').first}s',
    columns: [
      Column(name: 'name', type: ColumnType.string),
    ],
  );

}
''';
  }

  Future<void> _registerTable(String className, String fileName) async {
    final registryFile = File('lib/config/table_registry.dart');

    if (!await registryFile.exists()) {
      Log.debug('⚠️ table_registry.dart not found, skipping auto registration');
      return;
    }

    // 1️⃣ Get the package name from pubspec.yaml
    final packageName = await _getPackageName();

    // 2️⃣ Read current content
    var content = await registryFile.readAsString();

    // 3️⃣ Add import if missing
    final importLine = "import 'package:$packageName/models/$fileName.dart';";

    // Check if import already exists
    if (!content.contains(importLine)) {
      // Find the last import statement
      final importPattern = RegExp(r'^import .+?;\s*$', multiLine: true);
      final imports = importPattern.allMatches(content);

      if (imports.isNotEmpty) {
        // Insert after the last import
        final lastImport = imports.last;
        final insertPosition = lastImport.end;
        content = content.substring(0, insertPosition) +
            '\n$importLine' +
            content.substring(insertPosition);
      } else {
        // No imports found, add at the beginning
        content = '$importLine\n$content';
      }
    }

    // 4️⃣ Find and update runTableRegistry - updated pattern to match your format
    // Pattern looks for: runTableRegistry([...], _, sendPort)
    final registryPattern = RegExp(
      r'runTableRegistry\s*\(\s*\[(.*?)\]\s*,\s*_\s*,\s*sendPort\s*\)',
      dotAll: true,
    );

    final match = registryPattern.firstMatch(content);

    if (match == null) {
      // Try alternative pattern without sendPort parameter
      final altPattern = RegExp(
        r'runTableRegistry\s*\(\s*\[(.*?)\]\s*\)',
        dotAll: true,
      );

      final altMatch = altPattern.firstMatch(content);

      if (altMatch == null) {
        Log.debug('⚠️ runTableRegistry not found in table_registry.dart');
        return;
      } else {
        // Use the alternative match
        final insideBrackets = altMatch.group(1)?.trim() ?? '';
        final tableEntry = '$className().table';

        // Check if already registered
        if (insideBrackets.contains(tableEntry)) {
          Log.debug('ℹ️ $className already registered in table_registry.dart');
          return;
        }

        // Build new inside brackets content
        String newInsideBrackets;
        if (insideBrackets.isEmpty) {
          newInsideBrackets = '\n    $tableEntry,';
        } else {
          // Remove trailing comma if present and add new entry
          final cleaned = insideBrackets.trim();
          if (cleaned.endsWith(',')) {
            newInsideBrackets = '$cleaned\n    $tableEntry,';
          } else {
            newInsideBrackets = '$cleaned,\n    $tableEntry,';
          }
        }

        // Replace the content
        final before = content.substring(
            0, altMatch.start + altMatch.group(0)!.indexOf('[') + 1);
        final after =
            content.substring(altMatch.start + altMatch.group(0)!.indexOf(']'));

        content = before + newInsideBrackets + after;
      }
    } else {
      // Original pattern matched
      final insideBrackets = match.group(1)?.trim() ?? '';
      final tableEntry = '$className().table';

      // Check if already registered
      if (insideBrackets.contains(tableEntry)) {
        Log.debug('ℹ️ $className already registered in table_registry.dart');
        return;
      }

      // Build new inside brackets content
      String newInsideBrackets;
      if (insideBrackets.isEmpty) {
        newInsideBrackets = '\n    $tableEntry,';
      } else {
        // Remove trailing comma if present and add new entry
        final cleaned = insideBrackets.trim();
        if (cleaned.endsWith(',')) {
          newInsideBrackets = '$cleaned\n    $tableEntry,';
        } else {
          newInsideBrackets = '$cleaned,\n    $tableEntry,';
        }
      }

      // Replace the content
      final before =
          content.substring(0, match.start + match.group(0)!.indexOf('[') + 1);
      final after =
          content.substring(match.start + match.group(0)!.indexOf(']'));

      content = before + newInsideBrackets + after;
    }

    // 6️⃣ Write back
    await registryFile.writeAsString(content);
    Log.debug('✅ $className registered in table_registry.dart');
  }

  /// Helper: get package name from pubspec.yaml
  Future<String> _getPackageName() async {
    final pubspec = File('pubspec.yaml');
    if (!await pubspec.exists()) {
      throw Exception('pubspec.yaml not found');
    }

    final lines = await pubspec.readAsLines();
    final nameLine =
        lines.firstWhere((l) => l.startsWith('name:'), orElse: () => '');

    if (nameLine.isEmpty) {
      throw Exception('Could not find package name in pubspec.yaml');
    }

    return nameLine.replaceFirst('name:', '').trim();
  }
}
