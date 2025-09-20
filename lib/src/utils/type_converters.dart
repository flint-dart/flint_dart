// import 'package:flint_dart/schema.dart';
// import 'package:flint_dart/src/database/db.dart';

// /// Helper functions for type conversion
// ColumnType mysqlTypeToColumnType(String mysqlType, int? maxLength) {
//   switch (mysqlType.toLowerCase()) {
//     case 'varchar':
//     case 'char':
//     case 'text':
//     case 'longtext':
//     case 'mediumtext':
//       return maxLength != null && maxLength > 255
//           ? ColumnType.text
//           : ColumnType.string;
//     case 'int':
//     case 'integer':
//     case 'bigint':
//     case 'mediumint':
//     case 'smallint':
//     case 'tinyint':
//       return ColumnType.integer;
//     case 'double':
//     case 'float':
//     case 'decimal':
//       return ColumnType.double;
//     case 'boolean':
//     case 'bool':
//       return ColumnType.boolean;
//     case 'datetime':
//       return ColumnType.datetime;
//     case 'timestamp':
//       return ColumnType.timestamp;
//     default:
//       return ColumnType.string;
//   }
// }

// ColumnType postgresTypeToColumnType(String pgType, int? maxLength) {
//   switch (pgType.toLowerCase()) {
//     case 'varchar':
//     case 'character varying':
//     case 'text':
//     case 'char':
//       return maxLength != null && maxLength > 255
//           ? ColumnType.text
//           : ColumnType.string;
//     case 'integer':
//     case 'int':
//     case 'bigint':
//     case 'smallint':
//       return ColumnType.integer;
//     case 'double precision':
//     case 'real':
//     case 'numeric':
//     case 'decimal':
//       return ColumnType.double;
//     case 'boolean':
//     case 'bool':
//       return ColumnType.boolean;
//     case 'timestamp':
//     case 'timestamp without time zone':
//       return ColumnType.datetime;
//     case 'timestamptz':
//     case 'timestamp with time zone':
//       return ColumnType.timestamp;
//     default:
//       return ColumnType.string;
//   }
// }

// Future<bool> isPostgresPrimaryKey(String tableName, String columnName) async {
//   try {
//     final result = await DB.query('''
//       SELECT COUNT(*) as count
//       FROM information_schema.table_constraints tc
//       JOIN information_schema.key_column_usage kcu
//         ON tc.constraint_name = kcu.constraint_name
//         AND tc.table_schema = kcu.table_schema
//       WHERE tc.constraint_type = 'PRIMARY KEY'
//         AND tc.table_name = \$1
//         AND kcu.column_name = \$2
//     ''', [tableName, columnName]);

//     return (result.first['count'] as int) > 0;
//   } catch (e) {
//     return false;
//   }
// }
