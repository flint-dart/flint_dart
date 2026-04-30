import 'package:flint_dart/db.dart';
import 'package:flint_dart/schema.dart';
import 'package:flint_dart/src/extensions/table_extension.dart';
import 'package:test/test.dart';

void main() {
  group('Column equality', () {
    test('compares columns by value', () {
      final a = Column(
        name: 'email',
        type: ColumnType.string,
        length: 255,
        isNullable: false,
        defaultValue: 'x@example.com',
      );
      final b = Column(
        name: 'email',
        type: ColumnType.string,
        length: 255,
        isNullable: false,
        defaultValue: 'x@example.com',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('dbSchemaCompareTables', () {
    test('returns null when schemas match on mysql', () {
      final existing = Table(
        name: 'users',
        columns: [
          Column(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
            isAutoIncrement: true,
          ),
          Column(name: 'email', type: ColumnType.string, length: 255),
        ],
      );
      final updated = Table(
        name: 'users',
        columns: [
          Column(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
            isAutoIncrement: true,
          ),
          Column(name: 'email', type: ColumnType.string, length: 255),
        ],
      );

      expect(
        dbSchemaCompareTables(existing, updated, DBDriver.mysql),
        isNull,
      );
    });

    test('emits postgres alter when varchar length changes', () {
      final existing = Table(
        name: 'users',
        columns: [
          Column(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
            isAutoIncrement: true,
          ),
          Column(name: 'email', type: ColumnType.string, length: 255),
        ],
      );
      final updated = Table(
        name: 'users',
        columns: [
          Column(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
            isAutoIncrement: true,
          ),
          Column(name: 'email', type: ColumnType.string, length: 100),
        ],
      );

      final sql = dbSchemaCompareTables(existing, updated, DBDriver.postgres);
      expect(sql, isNotNull);
      expect(sql, contains('ALTER COLUMN "email" TYPE VARCHAR(100)'));
    });

    test('emits mysql comment and after clause for new columns', () {
      final existing = Table(
        name: 'users',
        columns: [
          Column(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
            isAutoIncrement: true,
          ),
          Column(name: 'email', type: ColumnType.string, length: 255),
        ],
      );
      final updated = Table(
        name: 'users',
        columns: [
          Column(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
            isAutoIncrement: true,
          ),
          Column(name: 'email', type: ColumnType.string, length: 255),
          Column(
            name: 'nickname',
            type: ColumnType.string,
            length: 120,
            isNullable: true,
            comment: 'Public profile name',
            after: 'email',
          ),
        ],
      );

      final sql = dbSchemaCompareTables(existing, updated, DBDriver.mysql);
      expect(sql, isNotNull);
      expect(
        sql,
        contains(
          "ADD COLUMN `nickname` VARCHAR(120) COMMENT 'Public profile name' AFTER `email`",
        ),
      );
    });

    test('emits mysql rename instead of drop and add when renamedFrom is set',
        () {
      final existing = Table(
        name: 'users',
        columns: [
          Column(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
            isAutoIncrement: true,
          ),
          Column(name: 'Nickname', type: ColumnType.string, length: 255),
        ],
      );
      final updated = Table(
        name: 'users',
        columns: [
          Column(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
            isAutoIncrement: true,
          ),
          Column(
            name: 'nickname',
            type: ColumnType.string,
            length: 255,
            renamedFrom: 'Nickname',
          ),
        ],
      );

      final sql = dbSchemaCompareTables(existing, updated, DBDriver.mysql);
      expect(sql, contains('RENAME COLUMN `Nickname` TO `nickname`'));
      expect(sql, isNot(contains('DROP COLUMN `Nickname`')));
      expect(sql, isNot(contains('ADD COLUMN `nickname`')));
    });
  });
}
