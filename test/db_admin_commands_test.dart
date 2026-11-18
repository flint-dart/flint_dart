import 'package:flint_dart/src/cli/db_admin_commands.dart';
import 'package:test/test.dart';

void main() {
  group('db admin command metadata', () {
    test('--db-export has expected metadata', () {
      final cmd = DBExportCommand();
      expect(cmd.name, '--db-export');
    });

    test('--db-table-export has expected metadata', () {
      final cmd = DBTableExportCommand();
      expect(cmd.name, '--db-table-export');
    });
  });
}
