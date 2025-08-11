import 'package:flint_dart/schema.dart';
import 'package:mysql_dart/mysql_dart.dart';

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

extension TableSQL on Table {
  String toSQL() {
    final buffer = StringBuffer();
    buffer.write('CREATE TABLE `$name` (\n');

    for (int i = 0; i < columns.length; i++) {
      final col = columns[i];
      buffer.write('  `${col.name}` ${_columnTypeToSQL(col)}');

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

  List<String> compareWith(Table updated) {
    final oldCols = {for (var c in columns) c.name: c};
    final newCols = {for (var c in updated.columns) c.name: c};
    final changes = <String>[];

    for (var name in newCols.keys) {
      if (!oldCols.containsKey(name)) {
        final c = newCols[name]!;
        changes.add(
            'ADD COLUMN `${c.name}` ${ColumnSQL(c).sqlType()} ${c.isNullable ? "" : "NOT NULL"}');
      } else if (oldCols[name] != newCols[name]) {
        final c = newCols[name]!;
        changes.add(
            'MODIFY COLUMN `${c.name}` ${ColumnSQL(c).sqlType()} ${c.isNullable ? "" : "NOT NULL"}');
      }
    }

    for (var name in oldCols.keys) {
      if (!newCols.containsKey(name)) {
        changes.add('DROP COLUMN `$name`');
      }
    }

    return changes;
  }

  static Table fromMySQL(String tableName, List<ResultSetRow> rows) {
    final List<Column> columns = [];

    for (final row in rows) {
      final data = row.assoc(); // ✅ Safely extract fields
      final String colName = data['Field'] as String;
      final String typeStr = data['Type'] as String;
      final String nullStr = data['Null'] as String;
      final String key = data['Key'] as String;
      final dynamic defaultValue = data['Default'];
      final String extra = data['Extra'] as String? ?? '';

      columns.add(Column(
        name: colName,
        type: _inferColumnType(typeStr),
        length: _extractLength(typeStr),
        isPrimaryKey: key == 'PRI',
        isAutoIncrement: extra.contains('auto_increment'),
        isNullable: nullStr.toUpperCase() == 'YES',
        defaultValue: defaultValue,
      ));
    }

    return Table(
      name: tableName,
      columns: columns,
    );
  }

  static String _columnTypeToSQL(Column col) {
    switch (col.type) {
      case ColumnType.integer:
        return 'INT';
      case ColumnType.string:
        return 'VARCHAR(${col.length})';
      case ColumnType.text:
        return 'TEXT';
      case ColumnType.boolean:
        return 'BOOLEAN';
      case ColumnType.double:
        return 'DOUBLE';
      case ColumnType.datetime:
        return 'DATETIME';
      case ColumnType.timestamp:
        return 'TIMESTAMP';
    }
  }

  static String _formatDefaultValue(dynamic value) {
    if (value is String) return "'$value'";
    if (value is bool) return value ? 'TRUE' : 'FALSE';
    return value.toString();
  }

  static ColumnType _inferColumnType(String typeStr) {
    final lower = typeStr.toLowerCase();
    if (lower.startsWith('int')) return ColumnType.integer;
    if (lower.startsWith('varchar') || lower.startsWith('char')) {
      return ColumnType.string;
    }
    if (lower.startsWith('text')) return ColumnType.text;
    if (lower.startsWith('bool')) return ColumnType.boolean;
    if (lower.startsWith('double') || lower.startsWith('float')) {
      return ColumnType.double;
    }
    if (lower.contains('datetime')) return ColumnType.datetime;
    if (lower.contains('timestamp')) return ColumnType.timestamp;
    return ColumnType.string;
  }

  static int _extractLength(String typeStr) {
    final regExp = RegExp(r'\((\d+)\)');
    final match = regExp.firstMatch(typeStr);
    return match != null ? int.parse(match.group(1)!) : 255;
  }
}
