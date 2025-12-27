import 'dart:io';
import 'commands.dart';

class MakeIsolateCommand extends FlintCommand {
  MakeIsolateCommand() : super('make:isolate', 'Create a new isolate task');

  @override
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      print('❌ Usage: flint make:isolate <TaskName>');
      print('   Example: flint make:isolate send_email');
      return;
    }

    final rawName = args.first;

    if (!_isValidName(rawName)) {
      print('❌ Invalid name. Use letters, numbers, _ or -');
      return;
    }

    final className = '${_toPascalCase(rawName)}Task';
    final fileName = '${_toSnakeCase(rawName)}_task.dart';

    final dir = Directory('lib/isolate/tasks');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final file = File('${dir.path}/$fileName');

    if (file.existsSync()) {
      print('⚠️  Isolate task already exists.');
      return;
    }

    await file.writeAsString(_generateTask(className));

    print('✅ Created isolate task: ${file.path}');
  }

  String _generateTask(String className) {
    return '''
import 'package:flint_dart/isolate.dart';

class $className extends IsolateTask<void> {
  @override
  Future<void> perform() async {
    // Heavy or blocking logic here
    // Example: email sending, PDF generation, hashing, etc.

    print('$className running in isolate');
  }
}
''';
  }

  bool _isValidName(String input) =>
      RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(input);

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (m) => '${m[1]}_${m[2]}',
        )
        .replaceAll('-', '_')
        .toLowerCase();
  }

  String _toPascalCase(String input) {
    return input
        .split(RegExp(r'[_\-\s]'))
        .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
        .join();
  }
}
