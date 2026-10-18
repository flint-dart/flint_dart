// lib/cli/make_model_command.dart
import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';

class MakeModelCommand extends FlintCommand {
  MakeModelCommand() : super('--make-model', 'Creates a new model class');

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
  $className() : super($className.new);

  static const colId = ColumnField<String>(
    'id',
    type: ColumnType.string,
    isPrimaryKey: true,
  );
  static const colName = ColumnField<String>(
    'name',
    type: ColumnType.string,
  );

  String? get name => getField(colName);
  set name(String? value) => setField(colName, value ?? '');

  @override
  String get tableName => '${fileName.split('.').first}s';

  @override
  List<ColumnField> get fields => [
    colId,
    colName,
  ];
}
''';
  }

  Future<void> _registerTable(String className, String fileName) async {
    final registryFile = File('lib/config/table_registry.dart');

    if (!await registryFile.exists()) {
      Log.debug('⚠️ table_registry.dart not found, skipping auto registration');
      return;
    }

    final packageName = await _getPackageName();
    var content = await registryFile.readAsString();
    final importLine = "import 'package:$packageName/models/$fileName.dart';";

    if (!content.contains(importLine)) {
      final importPattern = RegExp(r'^import .+?;\s*$', multiLine: true);
      final imports = importPattern.allMatches(content);

      if (imports.isNotEmpty) {
        final lastImport = imports.last;
        final insertPosition = lastImport.end;
        content =
            '${content.substring(0, insertPosition)}\n$importLine${content.substring(insertPosition)}';
      } else {
        content = '$importLine\n$content';
      }
    }

    final tableEntry = '$className().table';
    if (content.contains(tableEntry)) {
      Log.debug('ℹ️ $className already registered in table_registry.dart');
      return;
    }

    // Support both modern `List<Table> get tables => [...]` and legacy `runTableRegistry([...])`
    final tablesGetterPattern = RegExp(
      r'List<Table>\s+get\s+tables\s*=>\s*\[(.*?)\];',
      dotAll: true,
    );
    final getterMatch = tablesGetterPattern.firstMatch(content);
    if (getterMatch != null) {
      final insideBrackets = getterMatch.group(1)?.trim() ?? '';
      final String newInsideBrackets;
      if (insideBrackets.isEmpty) {
        newInsideBrackets = '\n    $tableEntry,\n  ';
      } else {
        final cleaned = insideBrackets.trim();
        newInsideBrackets = cleaned.endsWith(',')
            ? '\n    $cleaned\n    $tableEntry,\n  '
            : '\n    $cleaned,\n    $tableEntry,\n  ';
      }
      final openBracket = getterMatch.start + getterMatch.group(0)!.indexOf('[') + 1;
      final closeBracket = getterMatch.start + getterMatch.group(0)!.lastIndexOf(']');
      content =
          content.substring(0, openBracket) +
          newInsideBrackets +
          content.substring(closeBracket);
      await registryFile.writeAsString(content);
      Log.debug('✅ $className registered in table_registry.dart');
      return;
    }

    final registryPattern = RegExp(
      r'runTableRegistry\s*\(\s*\[(.*?)\]\s*(?:,\s*_\s*,\s*sendPort\s*)?\)',
      dotAll: true,
    );
    final match = registryPattern.firstMatch(content);
    if (match == null) {
      Log.debug('⚠️ Table list not found in table_registry.dart');
      return;
    }

    final insideBrackets = match.group(1)?.trim() ?? '';
    final String newInsideBrackets;
    if (insideBrackets.isEmpty) {
      newInsideBrackets = '\n    $tableEntry,';
    } else {
      final cleaned = insideBrackets.trim();
      newInsideBrackets = cleaned.endsWith(',')
          ? '$cleaned\n    $tableEntry,'
          : '$cleaned,\n    $tableEntry,';
    }

    final before =
        content.substring(0, match.start + match.group(0)!.indexOf('[') + 1);
    final after = content.substring(match.start + match.group(0)!.indexOf(']'));
    content = before + newInsideBrackets + after;

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
