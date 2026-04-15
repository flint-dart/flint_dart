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
  });
}
