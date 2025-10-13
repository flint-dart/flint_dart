import 'dart:convert';

import 'package:flint_dart/schema.dart';
import 'package:flint_dart/src/database/db.dart';

extension ColumnSQL on Column {
  String mysqlType() {
    switch (type) {
      case ColumnType.string:
        return 'VARCHAR($length)';
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

  String pgSqlType() {
    switch (type) {
      case ColumnType.string:
        return 'VARCHAR($length)';
      case ColumnType.text:
        return 'TEXT';
      case ColumnType.integer:
        return 'INTEGER';
      case ColumnType.double:
        return 'DOUBLE PRECISION';
      case ColumnType.boolean:
        return 'BOOLEAN';
      case ColumnType.datetime:
        return 'TIMESTAMP'; // no DATETIME in PG
      case ColumnType.timestamp:
        return 'TIMESTAMP WITH TIME ZONE';
    }
  }
}

extension TableSQL on Table {
  String? compareWith(Table updated) {
    switch (DB.driver) {
      case DBDriver.mysql:
        return _compareWithMySQL(updated);
      case DBDriver.postgres:
        return _compareWithPostgres(updated);
    }
  }

  // --- MYSQL ---
  String? _compareWithMySQL(Table updated) {
    final oldCols = {for (var c in columns) c.name: c};
    final newCols = {for (var c in updated.columns) c.name: c};
    final changes = <String>[];

    for (var name in newCols.keys) {
      final newCol = newCols[name]!;

      if (!oldCols.containsKey(name)) {
        changes.add(_buildAddColumnSQL(newCol));
      } else {
        final oldCol = oldCols[name]!;
        if (oldCol != newCol) {
          changes.add(_buildModifyColumnSQL(newCol));
        }
      }
    }

    for (var name in oldCols.keys) {
      if (!newCols.containsKey(name)) {
        changes.add('DROP COLUMN `$name`');
      }
    }

    if (changes.isEmpty) return null;

    return 'ALTER TABLE `$name`\n  ${changes.join(",\n  ")};';
  }

  String _buildAddColumnSQL(Column col) {
    if (!col.isNullable && col.defaultValue == null && !col.isAutoIncrement) {
      throw ArgumentError(
          'Column ${col.name} is NOT NULL but has no default value. '
          'Either make it nullable or provide a default value.');
    }

    final buffer = StringBuffer();
    buffer.write('ADD COLUMN `${col.name}` ${col.mysqlType()}');

    if (!col.isNullable) buffer.write(' NOT NULL');
    if (col.defaultValue != null) {
      buffer.write(' DEFAULT ${_formatDefault(col.defaultValue)}');
    }
    if (col.isAutoIncrement) buffer.write(' AUTO_INCREMENT');
    if (col.isUnique) buffer.write(' UNIQUE');

    return buffer.toString();
  }

  String _buildModifyColumnSQL(Column col) {
    final buffer = StringBuffer();
    buffer.write('MODIFY COLUMN `${col.name}` ${col.mysqlType()}');

    if (!col.isNullable) buffer.write(' NOT NULL');
    if (col.defaultValue != null) {
      buffer.write(' DEFAULT ${_formatDefault(col.defaultValue)}');
    }
    if (col.isAutoIncrement) buffer.write(' AUTO_INCREMENT');
    if (col.isUnique) buffer.write(' UNIQUE');

    return buffer.toString();
  }

  // --- POSTGRES ---
  String? _compareWithPostgres(Table updated) {
    final oldCols = {for (var c in columns) c.name: c};
    final newCols = {for (var c in updated.columns) c.name: c};
    final changes = <String>[];

    for (var name in newCols.keys) {
      final newCol = newCols[name]!;
      if (!oldCols.containsKey(name)) {
        changes.add(_buildAddColumnPostgres(newCol));
      } else {
        final oldCol = oldCols[name]!;
        if (oldCol != newCol) {
          changes
              .addAll(_buildAlterColumnPostgres(updated.name, oldCol, newCol));
        }
      }
    }

    for (var name in oldCols.keys) {
      if (!newCols.containsKey(name)) {
        changes.add('DROP COLUMN "$name"');
      }
    }

    if (changes.isEmpty) return null;
    return 'ALTER TABLE "$name"\n  ${changes.join(",\n  ")};';
  }
}

// --- POSTGRES HELPERS ---
String _buildAddColumnPostgres(Column col) {
  final buffer = StringBuffer('ADD COLUMN "${col.name}" ');

  if (col.isPrimaryKey && col.isAutoIncrement) {
    buffer.write('SERIAL PRIMARY KEY');
    return buffer.toString();
  }

  buffer.write(col.pgSqlType());
  if (!col.isNullable) buffer.write(' NOT NULL');
  if (col.defaultValue != null) {
    buffer.write(' DEFAULT ${_formatDefault(col.defaultValue)}');
  }
  if (col.isUnique) buffer.write(' UNIQUE');

  return buffer.toString();
}

List<String> _buildAlterColumnPostgres(
    String tableName, Column oldCol, Column newCol) {
  final changes = <String>[];

  // --- Type change ---
  if (oldCol.type != newCol.type) {
    if (newCol.isPrimaryKey && newCol.isAutoIncrement) {
      // Upgrade SERIAL → BIGSERIAL or similar
      changes.add(
          'ALTER COLUMN "${newCol.name}" TYPE ${newCol.pgSqlType()} USING "${newCol.name}"::${newCol.pgSqlType()}');
    } else {
      changes.add('ALTER COLUMN "${newCol.name}" TYPE ${newCol.pgSqlType()}');
    }
  }

  // --- Nullability change ---
  if (oldCol.isNullable != newCol.isNullable) {
    changes.add(newCol.isNullable
        ? 'ALTER COLUMN "${newCol.name}" DROP NOT NULL'
        : 'ALTER COLUMN "${newCol.name}" SET NOT NULL');
  }

  // --- Default change ---
  if (oldCol.defaultValue != newCol.defaultValue &&
      !(newCol.isPrimaryKey && newCol.isAutoIncrement)) {
    if (newCol.defaultValue == null) {
      changes.add('ALTER COLUMN "${newCol.name}" DROP DEFAULT');
    } else {
      changes.add(
          'ALTER COLUMN "${newCol.name}" SET DEFAULT ${_formatDefault(newCol.defaultValue)}');
    }
  }

  // --- Primary key change ---
  if (oldCol.isPrimaryKey != newCol.isPrimaryKey) {
    if (newCol.isPrimaryKey) {
      changes.add('ADD PRIMARY KEY ("${newCol.name}")');
    } else {
      changes.add('DROP CONSTRAINT "${tableName}_pkey"');
    }
  }

  // --- Unique constraint change (always check) ---
  if (oldCol.isUnique != newCol.isUnique) {
    if (newCol.isUnique) {
      changes.add(
          'ADD CONSTRAINT "${newCol.name}_unique" UNIQUE ("${newCol.name}")');
    } else {
      changes.add('DROP CONSTRAINT IF EXISTS "${newCol.name}_unique"');
    }
  }

  return changes;
}

// --- UTILITIES ---
String _formatDefault(dynamic value, {String dialect = 'postgres'}) {
  // Handle null
  if (value == null) return 'NULL';

  // Handle strings
  if (value is String) {
    if (_isSqlFunction(value)) {
      return value; // Return SQL functions as-is
    }
    return "'$value'";
  }

  // Handle booleans
  if (value is bool) return value ? 'TRUE' : 'FALSE';

  // Handle DateTime
  if (value is DateTime) {
    final formatted = value.toIso8601String().replaceFirst('T', ' ');
    return "'$formatted'";
  }

  // Handle numbers
  if (value is num) return value.toString();

  // Handle SQL function calls
  if (value is Function) {
    final result = value();
    return _formatDefault(result, dialect: dialect);
  }

  // Handle enums
  if (value is Enum) return "'${value.name}'";

  // Handle lists (for array types)
  if (value is List) {
    return _formatArray(value, dialect: dialect);
  }

  // Handle maps (for JSON types)
  if (value is Map) {
    return "'${jsonEncode(value)}'";
  }

  // Fallback: quote other types
  return "'${value.toString()}'";
}

// --- HELPER FUNCTIONS ---
bool _isSqlFunction(String value) {
  final functions = [
    'CURRENT_TIMESTAMP',
    'CURRENT_DATE',
    'CURRENT_TIME',
    'NOW()',
    'UUID()',
    'GEN_RANDOM_UUID()',
    'CURRENT_USER',
    'SESSION_USER',
    'VERSION()'
  ];

  return functions.any((func) => value.toUpperCase().contains(func));
}

String _formatArray(List<dynamic> array, {String dialect = 'postgres'}) {
  final formattedItems =
      array.map((item) => _formatDefault(item, dialect: dialect)).toList();

  if (dialect == 'postgres') {
    return 'ARRAY[${formattedItems.join(', ')}]';
  } else {
    return "'${jsonEncode(array)}'"; // JSON array for other dialects
  }
}
