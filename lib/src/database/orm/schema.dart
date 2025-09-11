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
    required this.columns,
    this.indexes = const [],
    this.foreignKeys = const [],
  });
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

  /// Creates a new [Column] definition.
  Column({
    required this.name,
    required this.type,
    this.isPrimaryKey = false,
    this.isAutoIncrement = false,
    this.isNullable = false,
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
    );
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
