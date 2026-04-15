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
      expect(columns[1]['unique'], isFalse);
      expect(columns[0]['primaryKey'], isTrue);
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

    test('captures inline unique column metadata', () {
      final sql = '''
CREATE TABLE `users` (
  `id` VARCHAR(255) NOT NULL PRIMARY KEY,
  `email` VARCHAR(255) NOT NULL UNIQUE,
  `affiliateCode` VARCHAR(255) UNIQUE
);
''';

      final columns = dbMigrateExtractColumns(sql);
      expect(columns[1]['unique'], isTrue);
      expect(columns[2]['unique'], isTrue);
      expect(columns[0]['primaryKey'], isTrue);
    });

    test('extracts bare types without swallowing NOT NULL keywords', () {
      final sql = '''
CREATE TABLE `settings` (
  `walletBalance` DOUBLE NOT NULL DEFAULT 0.0,
  `emailVerified` BOOLEAN NOT NULL DEFAULT FALSE,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
''';

      final columns = dbMigrateExtractColumns(sql);
      expect(columns[0]['type'], 'DOUBLE');
      expect(columns[1]['type'], 'BOOLEAN');
      expect(columns[2]['type'], 'TIMESTAMP');
      expect(columns[2]['default'], 'CURRENT_TIMESTAMP');
    });

    test('builds desired indexes from inline unique and declared indexes', () {
      final sql = '''
CREATE TABLE `audit_logs` (
  `id` VARCHAR(255) NOT NULL PRIMARY KEY,
  `requestId` VARCHAR(255) UNIQUE,
  `actorUserId` VARCHAR(255) NOT NULL,
  `entityId` VARCHAR(255) NOT NULL
);
''';

      final indexes = dbMigrateBuildDesiredIndexes(sql, [
        {
          'name': 'audit_logs_actor_entity_idx',
          'columns': ['actorUserId', 'entityId'],
          'isUnique': false,
        },
      ]);

      expect(
        indexes.any((index) =>
            index['columns'] is List &&
            List<String>.from(index['columns'] as List).join(',') ==
                'requestId' &&
            index['unique'] == true),
        isTrue,
      );
      expect(
        indexes.any((index) =>
            index['name'] == 'audit_logs_actor_entity_idx' &&
            index['columns'] is List &&
            List<String>.from(index['columns'] as List).join(',') ==
                'actorUserId,entityId' &&
            index['unique'] == false),
        isTrue,
      );
    });

    test('normalizes equivalent default values for comparison', () {
      expect(dbMigrateNormalizeDefaultValue("'FALSE'"), '0');
      expect(dbMigrateNormalizeDefaultValue('false'), '0');
      expect(dbMigrateNormalizeDefaultValue('TRUE'), '1');
      expect(dbMigrateNormalizeDefaultValue('0.0'), '0');
      expect(dbMigrateNormalizeDefaultValue('25.0'), '25');
      expect(
        dbMigrateNormalizeDefaultValue('CURRENT_TIMESTAMP()'),
        'current_timestamp',
      );
      expect(
        dbMigrateNormalizeDefaultValue('CURRENT_TIMESTAMP'),
        'current_timestamp',
      );
    });
  });
}
