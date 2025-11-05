import 'dart:math' as math;

import 'package:flint_dart/db.dart';
import 'package:flint_dart/flint_dart.dart';

/// Represents a database table schema, including its columns, indexes, and foreign keys.
class Table {
  /// The name of the table.
  final String name;

  /// The list of columns in the table.
  final List<Column> columns;

  /// Optional list of indexes on the table.
  final List<Index> indexes;

  /// Optional list of foreign keys defined in the table.
  final List<ForeignKey> foreignKeys;

  /// Creates a new [Table] definition.
  Table({
    required this.name,
    required List<Column> columns,
    this.indexes = const [],
    this.foreignKeys = const [],
  }) : columns = _ensureIdColumn(columns);

  /// Ensures every table has an `id` column by default (UUID-based).
  static List<Column> _ensureIdColumn(List<Column> columns) {
    final hasPrimary = columns.any((c) => c.isPrimaryKey);
    if (!hasPrimary) {
      return [
        Column(
          name: 'id',
          type: ColumnType.string,
          isPrimaryKey: true,
          isNullable: false,
          defaultValue: Default.uuid(), // Generate automatically if needed
        ),
        ...columns,
      ];
    }
    return columns;
  }
}

/// Describes a column in a database table.
class Column {
  /// The name of the column.
  final String name;

  /// The data type of the column.
  final ColumnType type;

  /// The length of the column (for applicable types like string).
  final int length;

  /// Indicates whether the column is a primary key.
  final bool isPrimaryKey;

  /// Indicates whether the column is auto-incremented.
  final bool isAutoIncrement;

  /// Indicates whether the column can be null.
  final bool isNullable;

  /// The default value for the column, if any.
  final dynamic defaultValue;
  final bool isUnique;

  /// Creates a new [Column] definition.
  Column({
    required this.name,
    required this.type,
    this.isPrimaryKey = false,
    this.isAutoIncrement = false,
    this.isNullable = false,
    this.isUnique = false,
    this.length = 255,
    this.defaultValue,
  });

  /// Returns a new [Column] with updated values while keeping immutability.
  Column copyWith({
    String? name,
    ColumnType? type,
    int? length,
    bool? isPrimaryKey,
    bool? isAutoIncrement,
    bool? isNullable,
    bool? isUnique,
    dynamic defaultValue,
  }) {
    return Column(
        name: name ?? this.name,
        type: type ?? this.type,
        length: length ?? this.length,
        isPrimaryKey: isPrimaryKey ?? this.isPrimaryKey,
        isAutoIncrement: isAutoIncrement ?? this.isAutoIncrement,
        isNullable: isNullable ?? this.isNullable,
        defaultValue: defaultValue ?? this.defaultValue,
        isUnique: isUnique ?? this.isUnique);
  }
}

/// Enum representing supported column types for a table schema.
enum ColumnType {
  /// Integer type (e.g., INT)
  integer,

  /// String type with length limit (e.g., VARCHAR)
  string,

  /// Long text type (e.g., TEXT)
  text,

  /// Boolean type (e.g., TRUE/FALSE)
  boolean,

  /// Double/float type (e.g., FLOAT/DOUBLE)
  double,

  /// Date and time (e.g., DATETIME)
  datetime,

  /// Timestamp (e.g., TIMESTAMP)
  timestamp,

  ///
  // json
}

/// Represents an index on one or more columns in a table.
class Index {
  /// The name of the index.
  final String name;

  /// The columns included in the index.
  final List<String> columns;

  /// Whether the index enforces uniqueness.
  final bool isUnique;

  /// Creates a new [Index] definition.
  Index({
    required this.name,
    required this.columns,
    this.isUnique = false,
  });
}

/// Represents a foreign key constraint between tables.
class ForeignKey {
  /// The column in the current table.
  final String column;

  /// The referenced table name.
  final String referenceTable;

  /// The referenced column name in the foreign table.
  final String referenceColumn;

  /// Behavior when the referenced record is deleted. Default is 'RESTRICT'.
  final String onDelete;

  /// Behavior when the referenced record is updated. Default is 'RESTRICT'.
  final String onUpdate;

  /// Creates a new [ForeignKey] constraint.
  ForeignKey({
    required this.column,
    required this.referenceTable,
    required this.referenceColumn,
    this.onDelete = 'RESTRICT',
    this.onUpdate = 'RESTRICT',
  });
}

// --- COMMON SQL DEFAULTS ---
class Default {
  // Current timestamp functions
  static DateTime now() => DateTime.now();
  static String currentTimestamp() => 'CURRENT_TIMESTAMP';
  static String currentDate() => 'CURRENT_DATE';
  static String currentTime() => 'CURRENT_TIME';

  // UUID functions
  static String uuid() {
    var driver = DB.driver;
    if (driver == DBDriver.mysql) {
      return 'UUID()';
    } else if (driver == DBDriver.postgres) {
      return 'gen_random_uuid()';
    } else {
      return FlintEnv.get("DB_CONNECTION", '') == "mysql"
          ? 'UUID()'
          : 'gen_random_uuid()';
    }
  } // PostgreSQL

  // Math constants
  static double pi() => math.pi;
  static double e() => math.e;

  // String defaults
  static String emptyString() => '';
  static String space() => ' ';

  // JSON defaults
  static Map<String, dynamic> emptyJson() => {};
  static List<dynamic> emptyArray() => [];

  // User context (useful for audit columns)
  static String currentUser() => 'CURRENT_USER';
  static String sessionUser() => 'SESSION_USER';

  // Versioning
  static int version1() => 1;
  static int zero() => 0;
  static int one() => 1;
}
