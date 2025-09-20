import 'package:flint_dart/schema.dart';
import 'package:flint_dart/src/database/db.dart';

String _buildAddColumnSQL(Column col) {
  final buffer = StringBuffer();
  buffer.write('ADD COLUMN `${col.name}` ${col.sqlTypeMySQL()}');

  if (!col.isNullable) buffer.write(' NOT NULL');
  if (col.defaultValue != null) {
    buffer.write(' DEFAULT ${_formatDefault(col.defaultValue)}');
  }
  if (col.isAutoIncrement) buffer.write(' AUTO_INCREMENT');

  return buffer.toString();
}

String _buildModifyColumnSQL(Column col) {
  final buffer = StringBuffer();
  buffer.write('MODIFY COLUMN `${col.name}` ${col.sqlTypeMySQL()}');

  if (!col.isNullable) buffer.write(' NOT NULL');
  if (col.defaultValue != null) {
    buffer.write(' DEFAULT ${_formatDefault(col.defaultValue)}');
  }
  if (col.isAutoIncrement) buffer.write(' AUTO_INCREMENT');

  return buffer.toString();
}

String _formatDefault(dynamic value) {
  if (value is String) return "'$value'";
  if (value == null) return 'NULL';
  return value.toString();
}

/// Extension for table comparison
extension TableComparison on Table {
  List<String>? compareWith(Table newTable) {
    final diffs = <String>[];
    final dialect = _dialectFor(DB.driver);

    // Compare columns
    for (final newColumn in newTable.columns) {
      final existingColumn = columns.firstWhere(
        (col) => col.name == newColumn.name,
        orElse: () => Column(name: '', type: ColumnType.string), // Dummy column
      );

      if (existingColumn.name.isEmpty) {
        // New column to add
        diffs.add(
            'ALTER TABLE "${name}" ADD COLUMN ${_buildColumnDefinition(newColumn, dialect)};');
      } else if (!_columnsEqual(existingColumn, newColumn)) {
        // Column modified
        diffs.add(
            'ALTER TABLE "${name}" MODIFY COLUMN ${_buildColumnDefinition(newColumn, dialect)};');
      }
    }

    // Check for removed columns
    for (final existingColumn in columns) {
      if (!newTable.columns.any((col) => col.name == existingColumn.name)) {
        diffs
            .add('ALTER TABLE "${name}" DROP COLUMN "${existingColumn.name}";');
      }
    }

    return diffs.isNotEmpty ? diffs : null;
  }

  bool _columnsEqual(Column a, Column b) {
    return a.name == b.name &&
        a.type == b.type &&
        a.isNullable == b.isNullable &&
        a.isPrimaryKey == b.isPrimaryKey &&
        a.isAutoIncrement == b.isAutoIncrement &&
        a.length == b.length &&
        a.defaultValue == b.defaultValue;
  }

  String _buildColumnDefinition(Column column, SQLDialect dialect) {
    final buffer = StringBuffer();
    buffer.write('"${column.name}" ${_getSqlType(column, dialect)}');

    if (!column.isNullable) buffer.write(' NOT NULL');
    if (column.isAutoIncrement && dialect is MySQLDialect)
      buffer.write(' AUTO_INCREMENT');
    if (column.defaultValue != null) {
      buffer.write(' DEFAULT ${_formatDefault(column.defaultValue, dialect)}');
    }

    return buffer.toString();
  }

  String _getSqlType(Column column, SQLDialect dialect) {
    if (dialect is MySQLDialect) return column.sqlTypeMySQL();
    if (dialect is PostgresDialect) return column.sqlTypePostgres();
    return column.sqlTypeMySQL(); // fallback
  }

  String _formatDefault(dynamic value, SQLDialect dialect) {
    if (value is String) return "'$value'";
    if (value is bool)
      return dialect is MySQLDialect
          ? (value ? 'TRUE' : 'FALSE')
          : (value ? 'true' : 'false');
    if (value is DateTime) return "'${value.toIso8601String()}'";
    return value.toString();
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
