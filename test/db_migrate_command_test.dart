import 'package:flint_dart/src/cli/db_commands.dart';
import 'package:test/test.dart';

void main() {
  group('DBMigrateCommand', () {
    test('has expected command metadata', () {
      final cmd = DBMigrateCommand();
      expect(cmd.name, 'migrate');
      expect(cmd.description, 'Runs database migrations');
    });
  });

  group('migrate SQL helpers', () {
    test('extracts table name from CREATE TABLE statement', () {
      final sql = 'CREATE TABLE `users` (`id` INT PRIMARY KEY);';
      expect(dbMigrateExtractTableName(sql), 'users');
    });

    test('extracts table name from ALTER TABLE statement', () {
      final sql = 'ALTER TABLE "accounts" ADD COLUMN "name" VARCHAR(255);';
      expect(dbMigrateExtractTableName(sql), 'accounts');
    });

    test('returns null when SQL is not CREATE/ALTER TABLE', () {
      final sql = 'SELECT * FROM users;';
      expect(dbMigrateExtractTableName(sql), isNull);
    });

    test('normalizes MySQL DDL to PostgreSQL-friendly SQL', () {
      final sql = '''
CREATE TABLE `users` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
''';

      final normalized = dbMigrateNormalizeSqlForPostgres(sql);
      expect(normalized, contains('"users"'));
      expect(normalized, contains('TIMESTAMP DEFAULT CURRENT_TIMESTAMP'));
      expect(normalized, contains('GENERATED ALWAYS AS IDENTITY'));
      expect(normalized, isNot(contains('ON UPDATE CURRENT_TIMESTAMP')));
      expect(normalized, isNot(contains('`')));
    });

    test('extracts column definitions and skips constraints', () {
      final sql = '''
CREATE TABLE "users" (
  "id" INT PRIMARY KEY,
  "email" VARCHAR(255) NOT NULL,
  "age" INT DEFAULT 18,
  UNIQUE ("email")
);
''';

      final columns = dbMigrateExtractColumns(sql);
      expect(columns.length, 3);
      expect(columns[0]['name'], 'id');
      expect(columns[1]['name'], 'email');
      expect(columns[1]['nullable'], isFalse);
      expect(columns[2]['default'], '18');
    });

    test('handles commas inside type declarations when parsing columns', () {
      final sql = '''
CREATE TABLE `events` (
  `id` INT PRIMARY KEY,
  `location` DECIMAL(10,2) NOT NULL,
  `title` VARCHAR(120)
);
''';

      final columns = dbMigrateExtractColumns(sql);
      expect(columns.length, 3);
      expect(columns[1]['name'], 'location');
      expect(columns[1]['type'], contains('DECIMAL(10,2)'));
    });
  });
}
