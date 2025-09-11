// dialect.dart
import 'package:flint_dart/schema.dart';
import 'package:flint_dart/src/database/connection.dart';
import 'package:flint_dart/src/database/db_wrapper.dart';
import 'package:flint_dart/src/extensions/table_extension.dart';
import 'package:mysql_dart/exception.dart';

/// Base dialect interface
abstract class SQLDialect {
  String createTable(Table table);
  String? alterTable(Table oldTable, Table newTable);
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
  String? alterTable(Table oldTable, Table newTable) =>
      oldTable.compareWith(newTable);

  @override
  Future<Table?> getTableSchema(String tableName) async {
    DBWrapper? conn;
    try {
      conn = await DB.mysql;
      final resultSet = await conn.query("SHOW COLUMNS FROM `$tableName`");
      if (resultSet.isEmpty) return null;
      return TableMySQL.fromMySQL(tableName, resultSet);
    } on MySQLServerException catch (e) {
      if (e.message.contains("doesn't exist")) return null;
      rethrow;
    } finally {
      await conn?.close();
    }
  }

  String _formatDefault(dynamic value) {
    if (value is String) return "'$value'";
    if (value is bool) return value ? 'TRUE' : 'FALSE';
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
      buffer.write('  "${col.name}" ${col.sqlTypePostgres()}');
      if (!col.isNullable) buffer.write(' NOT NULL');
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
  String? alterTable(Table oldTable, Table newTable) =>
      oldTable.compareWith(newTable);

  @override
  Future<Table?> getTableSchema(String tableName) async {
    final conn = DB.instance;
    final result = await conn.query('''
      SELECT
        column_name,
        data_type,
        character_maximum_length,
        is_nullable,
        column_default
      FROM information_schema.columns
      WHERE table_name = @table
    ''', namedParams: {'table': tableName});

    if (result.isEmpty) return null;

    final columns = result.map((row) {
      return Column(
        name: row['column_name'] as String,
        type: _inferPgType(row['data_type'] as String),
        length: (row['character_maximum_length'] as int?) ?? 0,
        isPrimaryKey:
            (row['is_primary'] as bool?) ?? false, // ✅ set at creation
        isAutoIncrement:
            (row['column_default'] as String?)?.contains('nextval') ?? false,
        isNullable: (row['is_nullable'] as String).toUpperCase() == 'YES',
        defaultValue: row['column_default'],
      );
    }).toList();

    final pkResult = await conn.query('''
      SELECT a.attname
      FROM pg_index i
      JOIN pg_attribute a ON a.attrelid = i.indrelid
                         AND a.attnum = ANY(i.indkey)
      WHERE i.indrelid = @table::regclass
        AND i.indisprimary
    ''', namedParams: {'table': tableName});

    final pkCols = pkResult.map((row) => row['attname'] as String).toSet();

    for (var col in columns) {
      if (pkCols.contains(col.name)) col.copyWith(isPrimaryKey: true);
    }

    return Table(name: tableName, columns: columns);
  }

  String _formatDefault(dynamic value) {
    if (value is String) return "'$value'";
    if (value is bool) return value ? 'true' : 'false';
    return value.toString();
  }
}

/// ---------------- Dispatcher ----------------
extension TableSQL on Table {
  String toCreateSQL() => _dialectFor(DB.driver).createTable(this);
  String? toAlterSQL(Table updated) =>
      _dialectFor(DB.driver).alterTable(this, updated);
  Future<Table?> fetchSchema() => _dialectFor(DB.driver).getTableSchema(name);

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

/// ---------------- Type inference ----------------
ColumnType _inferPgType(String type) {
  final t = type.toLowerCase();
  if (t.contains('int')) return ColumnType.integer;
  if (t.contains('char') || t.contains('text')) return ColumnType.string;
  if (t.contains('bool')) return ColumnType.boolean;
  if (t.contains('double') || t.contains('numeric') || t.contains('real')) {
    return ColumnType.double;
  }
  if (t.contains('timestamp')) return ColumnType.timestamp;
  if (t.contains('date') || t.contains('time')) return ColumnType.datetime;
  return ColumnType.string;
}

/// ---------------- MySQL schema adapter ----------------
extension TableMySQL on Table {
  static Table fromMySQL(String tableName, List<Map<String, dynamic>> rows) {
    final columns = rows.map((data) {
      return Column(
        name: data['Field'] as String,
        type: _inferMySQLType(data['Type'] as String),
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

  static ColumnType _inferMySQLType(String mysqlType) {
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
        type.contains('date')) return ColumnType.datetime;
    return ColumnType.string;
  }

  static int? _extractLength(String mysqlType) {
    final match = RegExp(r'\((\d+)\)').firstMatch(mysqlType);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }
}

Future<Table?> getTableSchema(String tableName) async {
  DBDriver? driver = DB.driver;
  switch (driver) {
    case DBDriver.mysql:
      return MySQLDialect().getTableSchema(tableName);
    case DBDriver.postgres:
      return PostgresDialect().getTableSchema(tableName);
  }
}
