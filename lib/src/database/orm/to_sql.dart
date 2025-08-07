import 'dart:async';
import 'dart:convert';
import 'package:flint_dart/schema.dart';
import 'package:flint_dart/src/database/connection.dart';
import 'package:mysql_dart/exception.dart';
import 'package:mysql_dart/mysql_dart.dart';

extension TableSQL on Table {
  String toCreateSQL() {
    final buffer = StringBuffer();
    buffer.write('CREATE TABLE `$name` (\n');

    for (int i = 0; i < columns.length; i++) {
      final col = columns[i];
      buffer.write('  `${col.name}` ${col.sqlType()}');

      if (!col.isNullable) buffer.write(' NOT NULL');
      if (col.isAutoIncrement) buffer.write(' AUTO_INCREMENT');
      if (col.defaultValue != null) {
        buffer.write(' DEFAULT ${_formatDefaultValue(col.defaultValue)}');
      }
      if (col.isPrimaryKey) buffer.write(' PRIMARY KEY');

      if (i < columns.length - 1 || foreignKeys.isNotEmpty) buffer.write(',');
      buffer.write('\n');
    }

    for (int i = 0; i < foreignKeys.length; i++) {
      final fk = foreignKeys[i];
      buffer.write(
          '  FOREIGN KEY (`${fk.column}`) REFERENCES `${fk.referenceTable}`(`${fk.referenceColumn}`)');
      buffer.write(' ON DELETE ${fk.onDelete}');
      buffer.write(' ON UPDATE ${fk.onUpdate}');

      if (i < foreignKeys.length - 1) buffer.write(',');
      buffer.write('\n');
    }

    buffer.write(');');
    return buffer.toString();
  }

  String _formatDefaultValue(dynamic value) {
    if (value is String) return "'$value'";
    if (value is bool) return value ? 'TRUE' : 'FALSE';
    return value.toString();
  }
}

extension TableMigration on Table {
  /// Returns a single ALTER TABLE SQL statement, or null if no changes
  String? compareWith(Table updated) {
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
    final buffer = StringBuffer();
    buffer.write('ADD COLUMN `${col.name}` ${col.sqlType()}');

    if (!col.isNullable) buffer.write(' NOT NULL');
    if (col.defaultValue != null)
      buffer.write(' DEFAULT ${_formatDefault(col.defaultValue)}');
    if (col.isAutoIncrement) buffer.write(' AUTO_INCREMENT');

    return buffer.toString();
  }

  String _buildModifyColumnSQL(Column col) {
    final buffer = StringBuffer();
    buffer.write('MODIFY COLUMN `${col.name}` ${col.sqlType()}');

    if (!col.isNullable) buffer.write(' NOT NULL');
    if (col.defaultValue != null)
      buffer.write(' DEFAULT ${_formatDefault(col.defaultValue)}');
    if (col.isAutoIncrement) buffer.write(' AUTO_INCREMENT');

    return buffer.toString();
  }

  String _formatDefault(dynamic value) {
    if (value is String) return "'$value'";
    if (value == null) return 'NULL';
    return value.toString();
  }
}

extension ColumnSQL on Column {
  String sqlType() {
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
}

extension TableMySQL on Table {
  static Table fromMySQL(String tableName, List<ResultSetRow> rows) {
    final columns = rows.map((row) {
      final data = decodeAssoc(row.assoc());

      return Column(
        name: data['Field'] as String,
        type: _inferColumnType(data['Type'] as String),
        length: _extractLength(data['Type'] as String) ?? 0,
        isPrimaryKey: data['Key'] == 'PRI',
        isAutoIncrement:
            (data['Extra'] as String?)?.contains('auto_increment') ?? false,
        isNullable: (data['Null'] as String).toUpperCase() == 'YES',
        defaultValue: data['Default'],
      );
    }).toList();

    return Table(name: tableName, columns: columns);
  }

  /// Extracts the base type (e.g. "int", "varchar") from column definition
  static ColumnType _inferColumnType(String mysqlType) {
    final type = mysqlType.toLowerCase();
    if (type.contains('int')) return ColumnType.integer;
    if (type.contains('varchar') || type.contains('text'))
      return ColumnType.string;
    if (type.contains('bool') || type == 'tinyint(1)')
      return ColumnType.boolean;
    if (type.contains('double') ||
        type.contains('float') ||
        type.contains('decimal')) return ColumnType.double;
    if (type.contains('datetime') ||
        type.contains('timestamp') ||
        type.contains('date')) return ColumnType.string;
    return ColumnType.string; // fallback
  }

  /// Extracts number from varchar(255), int(11), etc.
  static int? _extractLength(String mysqlType) {
    final match = RegExp(r'\((\d+)\)').firstMatch(mysqlType);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }
}

Future<Table?> getTableSchema(String tableName) async {
  MySQLConnection? conn;

  try {
    conn = await DB.autoConnect();
    final resultSet = await conn.execute("SHOW COLUMNS FROM `$tableName`");
    if (resultSet.rows.isEmpty) return null;

    return TableMySQL.fromMySQL(tableName, resultSet.rows.toList());
  } on MySQLServerException catch (e) {
    if (e.message.contains("doesn't exist")) {
      return null; // ✅ table does not exist
    }
    return null; // ✅ table does not exist
  } finally {
    await conn?.close();
  }
}

/// Decodes all List<int> (UTF-8 bytes) in a MySQL assoc() row to Strings.
Map<String, dynamic> decodeAssoc(Map<String, dynamic> row) {
  return row.map((key, value) {
    if (value is List<int>) {
      try {
        return MapEntry(key, utf8.decode(value));
      } catch (_) {
        // Return original value if decoding fails
        return MapEntry(key, value);
      }
    }
    return MapEntry(key, value);
  });
}
