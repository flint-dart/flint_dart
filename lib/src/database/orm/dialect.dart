// dialect.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flint_dart/schema.dart';
import 'package:flint_dart/src/database/db.dart';
import 'package:mysql_dart/exception.dart';

/// Base dialect interface
abstract class SQLDialect {
  String createTable(Table table);
  Future<Table?> getTableSchema(String tableName);
}

/// ---------------- MySQL ----------------
class MySQLDialect implements SQLDialect {
  @override
  String createTable(Table table) {
    final buffer = StringBuffer();
    buffer.write('CREATE TABLE `${table.name}` (\n');

    for (int i = 0; i < table.columns.length; i++) {
      final col = table.columns[i];
      buffer.write('  `${col.name}` ${col.sqlTypeMySQL()}');

      if (!col.isNullable) buffer.write(' NOT NULL');
      if (col.isAutoIncrement) buffer.write(' AUTO_INCREMENT');
      if (col.defaultValue != null) {
        buffer.write(' DEFAULT ${_formatDefault(col.defaultValue)}');
      }
      if (col.isPrimaryKey) buffer.write(' PRIMARY KEY');

      if (i < table.columns.length - 1 || table.foreignKeys.isNotEmpty) {
        buffer.write(',');
      }
      buffer.write('\n');
    }

    for (int i = 0; i < table.foreignKeys.length; i++) {
      final fk = table.foreignKeys[i];
      buffer.write(
          '  FOREIGN KEY (`${fk.column}`) REFERENCES `${fk.referenceTable}`(`${fk.referenceColumn}`)');
      buffer.write(' ON DELETE ${fk.onDelete}');
      buffer.write(' ON UPDATE ${fk.onUpdate}');
      if (i < table.foreignKeys.length - 1) buffer.write(',');
      buffer.write('\n');
    }

    buffer.write(');');
    return buffer.toString();
  }

  @override
  Future<Table?> getTableSchema(String tableName) async {
    try {
      if (!DB.isConnected) {
        await DB.tryAutoConnect();
      }
      final result = await DB.query('''
        SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, 
               COLUMN_KEY, EXTRA, CHARACTER_MAXIMUM_LENGTH
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = ? AND TABLE_SCHEMA = DATABASE()
        ORDER BY ORDINAL_POSITION
      ''', positionalParams: [tableName]);
      if (result.isEmpty) return null;

      final columns = <Column>[];
      for (final row in result) {
        final columnName = row['COLUMN_NAME'] as String;
        final dataType = parseMySQLType(row['DATA_TYPE']);
        final isNullable = (row['IS_NULLABLE'] as String) == 'YES';
        final defaultValue = row['COLUMN_DEFAULT'];
        final isPrimary =
            (row['COLUMN_KEY'] as String?)?.contains('PRI') ?? false;
        final isAutoIncrement =
            (row['EXTRA'] as String?)?.contains('auto_increment') ?? false;
        final maxLength = parseInt(row["CHARACTER_MAXIMUM_LENGTH"]);

        final columnType = _mysqlTypeToColumnType(dataType, maxLength);

        columns.add(Column(
          name: columnName,
          type: columnType,
          isNullable: isNullable,
          defaultValue: defaultValue,
          isPrimaryKey: isPrimary,
          isAutoIncrement: isAutoIncrement,
          length: maxLength ?? 0,
        ));
      }

      return Table(name: tableName, columns: columns);
    } on MySQLServerException catch (e) {
      if (e.message.contains("doesn't exist")) return null;
      rethrow;
    } catch (e) {
      print('Error fetching MySQL table schema: $e');
      return null;
    }
  }

  ColumnType _mysqlTypeToColumnType(String mysqlType, int? maxLength) {
    final type = mysqlType.toLowerCase();
    if (type.contains('int')) return ColumnType.integer;
    if (type.contains('varchar') || type.contains('text')) {
      return ColumnType.string;
    }
    if (type.contains('bool') || type == 'tinyint(1)') {
      return ColumnType.boolean;
    }
    if (type.contains('double') ||
        type.contains('float') ||
        type.contains('decimal')) {
      return ColumnType.double;
    }
    if (type.contains('datetime') ||
        type.contains('timestamp') ||
        type.contains('date')) {
      return ColumnType.datetime;
    }
    return ColumnType.string;
  }

  String _formatDefault(dynamic value) {
    if (value is String) return "'$value'";
    if (value is bool) return value ? 'TRUE' : 'FALSE';
    if (value is DateTime) return "'${value.toIso8601String()}'";
    return value.toString();
  }
}

/// ---------------- Postgres ----------------
class PostgresDialect implements SQLDialect {
  @override
  String createTable(Table table) {
    final buffer = StringBuffer();
    buffer.write('CREATE TABLE "${table.name}" (\n');

    for (int i = 0; i < table.columns.length; i++) {
      final col = table.columns[i];

      buffer.write('  "${col.name}" ');

      if (col.isPrimaryKey && col.isAutoIncrement) {
        buffer.write('SERIAL PRIMARY KEY');
      } else {
        buffer.write(col.sqlTypePostgres());

        if (!col.isNullable) buffer.write(' NOT NULL');

        if (col.defaultValue != null) {
          buffer.write(
              ' DEFAULT ${_formatDefault(col.defaultValue, col.sqlTypePostgres())}');
        }

        if (col.isUnique) buffer.write(' UNIQUE');
        if (col.isPrimaryKey) buffer.write(' PRIMARY KEY');
      }

      if (i < table.columns.length - 1 || table.foreignKeys.isNotEmpty) {
        buffer.write(',');
      }
      buffer.write('\n');
    }

    for (int i = 0; i < table.foreignKeys.length; i++) {
      final fk = table.foreignKeys[i];
      buffer.write(
          '  FOREIGN KEY ("${fk.column}") REFERENCES "${fk.referenceTable}"("${fk.referenceColumn}")');
      buffer.write(' ON DELETE ${fk.onDelete}');
      buffer.write(' ON UPDATE ${fk.onUpdate}');
      if (i < table.foreignKeys.length - 1) buffer.write(',');
      buffer.write('\n');
    }

    buffer.write(');');
    return buffer.toString();
  }

  @override
  Future<Table?> getTableSchema(String tableName) async {
    try {
      if (!DB.isConnected) {
        await DB.tryAutoConnect();
      }

      final result = await DB.query('''
        SELECT column_name, data_type, is_nullable, column_default, 
               character_maximum_length
        FROM information_schema.columns 
        WHERE table_name = :table_name
        ORDER BY ordinal_position
      ''', namedParams: {'table_name': tableName});

      if (result.isEmpty) return null;

      final columns = <Column>[];
      for (final row in result) {
        final columnName = row['column_name'] as String;
        final dataType = row['data_type'] as String;
        final isNullable = (row['is_nullable'] as String) == 'YES';
        final defaultValue = row['column_default'];
        final maxLength = row['character_maximum_length'] as int?;

        final columnType = _postgresTypeToColumnType(dataType, maxLength);
        final isPrimary = await _isPostgresPrimaryKey(tableName, columnName);

        columns.add(Column(
          name: columnName,
          type: columnType,
          isNullable: isNullable,
          defaultValue: defaultValue,
          isPrimaryKey: isPrimary,
          isAutoIncrement:
              defaultValue?.toString().contains('nextval') ?? false,
          length: maxLength ?? 0,
        ));
      }

      return Table(name: tableName, columns: columns);
    } catch (e) {
      print('Error fetching PostgreSQL table schema: $e');
      return null;
    }
  }

  Future<bool> _isPostgresPrimaryKey(
      String tableName, String columnName) async {
    try {
      final result = await DB.query('''
  SELECT a.attname
  FROM pg_index i
  JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
  WHERE i.indrelid = to_regclass(:table_name) AND i.indisprimary
''', namedParams: {'table_name': tableName});

      final primaryKeys =
          result.map((row) => row['attname'] as String).toList();
      return primaryKeys.contains(columnName);
    } catch (e) {
      print('Error checking primary key: $e');
      return false;
    }
  }

  ColumnType _postgresTypeToColumnType(String pgType, int? maxLength) {
    final type = pgType.toLowerCase();
    if (type.contains('int')) return ColumnType.integer;
    if (type.contains('char') || type.contains('text')) {
      return ColumnType.string;
    }
    if (type.contains('bool')) return ColumnType.boolean;
    if (type.contains('double') ||
        type.contains('numeric') ||
        type.contains('real')) {
      return ColumnType.double;
    }
    if (type.contains('timestamp')) return ColumnType.timestamp;
    if (type.contains('date') || type.contains('time')) {
      return ColumnType.datetime;
    }
    return ColumnType.string;
  }

  String _formatDefault(dynamic value, String sqlType) {
    if (value == null) return '';

    final type = sqlType.toLowerCase();

    // Handle function references from Default class
    if (value is String Function()) {
      value = value(); // call it once to get the literal
    }

    if (value is num || value is bool) {
      return value.toString();
    }

    if (value is String) {
      final upper = value.toUpperCase().trim();

      final isDateOrTime = type.contains('timestamp') ||
          type.contains('date') ||
          type.contains('time');
      final isUuid = type.contains('uuid');

      // ✅ Handle PostgreSQL function defaults (no quotes)
      if ((isDateOrTime &&
              (upper == 'CURRENT_TIMESTAMP' ||
                  upper == 'CURRENT_DATE' ||
                  upper == 'CURRENT_TIME' ||
                  upper == 'NOW()')) ||
          (isUuid && upper.contains('GEN_RANDOM_UUID')) ||
          upper == 'CURRENT_USER' ||
          upper == 'SESSION_USER') {
        return value; // leave as-is (function, not string)
      }

      // ✅ Normal string defaults
      return "'$value'";
    }

    // ✅ Handle collections (store as JSON text)
    if (value is Map || value is List) {
      return "'${value.toString()}'";
    }

    return value.toString();
  }
}

/// ---------------- Dispatcher ----------------
extension TableSQL on Table {
  String toCreateSQL() {
    return _dialectFor(DB.driver).createTable(this);
  }

  Future<Table?> fetchSchema() {
    return _dialectFor(DB.driver).getTableSchema(name);
  }

  SQLDialect _dialectFor(DBDriver driver) {
    switch (driver) {
      case DBDriver.mysql:
        return MySQLDialect();
      case DBDriver.postgres:
        return PostgresDialect();
    }
  }
}

/// ---------------- Column helpers ----------------
extension ColumnSQL on Column {
  String sqlTypeMySQL() {
    switch (type) {
      case ColumnType.string:
        return length > 0 ? 'VARCHAR($length)' : 'TEXT';
      case ColumnType.text:
        return 'TEXT';
      case ColumnType.integer:
        return 'INT';
      case ColumnType.double:
        return 'DOUBLE';
      case ColumnType.boolean:
        return 'BOOLEAN';
      case ColumnType.datetime:
        return 'DATETIME';
      case ColumnType.timestamp:
        return 'TIMESTAMP';
    }
  }

  String sqlTypePostgres() {
    switch (type) {
      case ColumnType.string:
        return length > 0 ? 'VARCHAR($length)' : 'TEXT';
      case ColumnType.text:
        return 'TEXT';
      case ColumnType.integer:
        return 'INTEGER';
      case ColumnType.double:
        return 'DOUBLE PRECISION';
      case ColumnType.boolean:
        return 'BOOLEAN';
      case ColumnType.datetime:
        return 'TIMESTAMP';
      case ColumnType.timestamp:
        return 'TIMESTAMPTZ';
    }
  }
}

/// Helper function to get table schema
Future<Table?> getTableSchema(String tableName) async {
  try {
    if (!DB.isConnected) {
      await DB.tryAutoConnect();
    }

    final driver = DB.driver;
    switch (driver) {
      case DBDriver.mysql:
        return MySQLDialect().getTableSchema(tableName);
      case DBDriver.postgres:
        return PostgresDialect().getTableSchema(tableName);
    }
  } catch (e) {
    print('Error in getTableSchema: $e');
    return null;
  }
}

// Add this extension for firstWhereOrNull
extension FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

String parseMySQLType(dynamic rawType) {
  if (rawType is Uint8List) {
    return utf8.decode(rawType);
  } else if (rawType is String) {
    return rawType;
  } else {
    return rawType.toString();
  }
}

int? parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
