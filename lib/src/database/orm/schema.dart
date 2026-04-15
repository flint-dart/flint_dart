import 'dart:math' as math;

import 'package:flint_dart/db.dart';
import 'package:flint_dart/flint_dart.dart';

enum ForeignKeyAction { cascade, restrict, setNull, noAction, setDefault }

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

  /// Indicates whether the column must be unique.
  final bool isUnique;

  /// A list of allowed values (used for ENUM columns).
  final List<String>? options;

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
    this.options,
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
    List<String>? options,
  }) {
    return Column(
      name: name ?? this.name,
      type: type ?? this.type,
      length: length ?? this.length,
      isPrimaryKey: isPrimaryKey ?? this.isPrimaryKey,
      isAutoIncrement: isAutoIncrement ?? this.isAutoIncrement,
      isNullable: isNullable ?? this.isNullable,
      isUnique: isUnique ?? this.isUnique,
      defaultValue: defaultValue ?? this.defaultValue,
      options: options ?? this.options,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Column &&
        other.name == name &&
        other.type == type &&
        other.length == length &&
        other.isPrimaryKey == isPrimaryKey &&
        other.isAutoIncrement == isAutoIncrement &&
        other.isNullable == isNullable &&
        other.isUnique == isUnique &&
        _valuesEqual(other.defaultValue, defaultValue) &&
        _listEquals(other.options, options);
  }

  @override
  int get hashCode => Object.hash(
        name,
        type,
        length,
        isPrimaryKey,
        isAutoIncrement,
        isNullable,
        isUnique,
        _valueHash(defaultValue),
        Object.hashAll(options ?? const <String>[]),
      );

  static bool _listEquals(List<String>? a, List<String>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _valuesEqual(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_valuesEqual(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_valuesEqual(a[key], b[key])) {
          return false;
        }
      }
      return true;
    }
    return a == b;
  }

  static int _valueHash(dynamic value) {
    if (value is List) {
      return Object.hashAll(value.map(_valueHash));
    }
    if (value is Map) {
      final entries = value.entries
          .map((entry) => Object.hash(entry.key, _valueHash(entry.value)));
      return Object.hashAll(entries);
    }
    return value.hashCode;
  }
}

/// Enum representing supported column types for a table schema.
/// Enum representing supported column types for a table schema.
enum ColumnType {
  /// Integer type (e.g., INT)
  integer,

  /// String type with length limit (e.g., VARCHAR)
  string,

  /// Long text type (e.g., TEXT)
  text,

  /// Boolean type (e.g., TRUE/FALSE, 1/0)
  boolean,

  /// Double/float type (e.g., FLOAT/DOUBLE)
  double,

  /// Date and time (e.g., DATETIME)
  datetime,

  /// Timestamp (e.g., TIMESTAMP)
  timestamp,

  /// Enum type (e.g., ENUM('draft', 'published'))
  enumeration,

  /// JSON type (e.g., JSON)
  json,
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

class ForeignKey {
  final String column;
  final String referenceTable;
  final String referenceColumn;
  final String onDelete;
  final String onUpdate;

  ForeignKey({
    required this.column,
    required this.referenceTable,
    required this.referenceColumn,
    required ForeignKeyAction onDelete,
    required ForeignKeyAction onUpdate,
  })  : onDelete = _actionToSQL(onDelete),
        onUpdate = _actionToSQL(onUpdate);

  static String _actionToSQL(ForeignKeyAction action) {
    switch (action) {
      case ForeignKeyAction.cascade:
        return 'CASCADE';
      case ForeignKeyAction.restrict:
        return 'RESTRICT';
      case ForeignKeyAction.setNull:
        return 'SET NULL';
      case ForeignKeyAction.noAction:
        return 'NO ACTION';
      case ForeignKeyAction.setDefault:
        return 'SET DEFAULT';
    }
  }
}

class Default {
  // --- CURRENT TIMESTAMP / DATE / TIME ---
  /// Returns a Dart DateTime object for runtime use
  static DateTime now() => DateTime.now();

  /// Returns SQL for current timestamp depending on driver
  static String currentTimestamp() {
    if (DB.driver == DBDriver.mysql) {
      return 'CURRENT_TIMESTAMP';
    } else if (DB.driver == DBDriver.postgres) {
      return 'NOW()';
    } else {
      // fallback: detect via env
      return FlintEnv.get("DB_CONNECTION", '') == "mysql"
          ? 'CURRENT_TIMESTAMP'
          : 'NOW()';
    }
  }

  /// Returns SQL for current date depending on driver
  static String currentDate() {
    if (DB.driver == DBDriver.mysql) {
      return 'CURRENT_DATE';
    } else if (DB.driver == DBDriver.postgres) {
      return 'CURRENT_DATE';
    }
    return 'CURRENT_DATE';
  }

  /// Returns SQL for current time depending on driver
  static String currentTime() {
    if (DB.driver == DBDriver.mysql) {
      return 'CURRENT_TIME';
    } else if (DB.driver == DBDriver.postgres) {
      return 'CURRENT_TIME';
    }
    return 'CURRENT_TIME';
  }

  // --- UUID ---
  static String uuid() {
    if (DB.driver == DBDriver.mysql) {
      return 'UUID()';
    } else if (DB.driver == DBDriver.postgres) {
      return 'gen_random_uuid()';
    } else {
      return FlintEnv.get("DB_CONNECTION", '') == "mysql"
          ? 'UUID()'
          : 'gen_random_uuid()';
    }
  }

  // --- MATH CONSTANTS ---
  static double pi() => math.pi;
  static double e() => math.e;

  // --- STRING DEFAULTS ---
  static String emptyString() => '';
  static String space() => ' ';

  // --- JSON DEFAULTS ---
  static Map<String, dynamic> emptyJson() => {};
  static List<dynamic> emptyArray() => [];

  // --- USER CONTEXT (AUDIT) ---
  static String currentUser() => 'CURRENT_USER';
  static String sessionUser() => 'SESSION_USER';

  // --- VERSIONING / NUMERIC DEFAULTS ---
  static int version1() => 1;
  static int zero() => 0;
  static int one() => 1;
}
