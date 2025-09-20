// import 'package:flint_dart/schema.dart';

// /// ---------------- Column helpers ----------------
// extension ColumnSQL on Column {
//   String sqlTypeMySQL() {
//     switch (type) {
//       case ColumnType.string:
//         return length > 0 ? 'VARCHAR($length)' : 'TEXT';
//       case ColumnType.text:
//         return 'TEXT';
//       case ColumnType.integer:
//         return 'INT';
//       case ColumnType.double:
//         return 'DOUBLE';
//       case ColumnType.boolean:
//         return 'BOOLEAN';
//       case ColumnType.datetime:
//         return 'DATETIME';
//       case ColumnType.timestamp:
//         return 'TIMESTAMP';
//     }
//   }

//   String sqlTypePostgres() {
//     switch (type) {
//       case ColumnType.string:
//         return length > 0 ? 'VARCHAR($length)' : 'TEXT';
//       case ColumnType.text:
//         return 'TEXT';
//       case ColumnType.integer:
//         return 'INTEGER';
//       case ColumnType.double:
//         return 'DOUBLE PRECISION';
//       case ColumnType.boolean:
//         return 'BOOLEAN';
//       case ColumnType.datetime:
//         return 'TIMESTAMP';
//       case ColumnType.timestamp:
//         return 'TIMESTAMPTZ';
//     }
//   }
// }
