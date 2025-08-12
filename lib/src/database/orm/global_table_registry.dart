import 'dart:isolate';
import 'package:flint_dart/schema.dart';

/// Runs the table registry process inside a Dart isolate.
///
/// This function is typically called automatically by the Flint CLI when
/// running database synchronization commands (e.g., `flint db:sync`).
/// It compares the current database schema with the defined table schemas
/// and produces a list of SQL statements to create or modify tables.
///
/// ### Parameters
/// - [tables] (`List<Table>`):
///   A list of [`Table`](package:flint_dart/schema.dart) objects representing
///   the desired schema for each database table.
/// - [_] (`dynamic`, optional):
///   An unused positional parameter (reserved for isolate call compatibility).
/// - [sendPort] (`SendPort?`, optional):
///   A [`SendPort`](dart:isolate) used to send the computed schema differences
///   back to the main isolate. If `null`, the function will print an error
///   and exit.
///
/// ### Behavior
/// - If a table does not exist in the database, its `CREATE TABLE` SQL is added
///   to the diff list.
/// - If a table exists, the `compareWith` method is used to generate the
///   necessary `ALTER TABLE` statements.
/// - All differences are sent back to the main isolate via [sendPort].
///
/// ### Example
/// ```dart
/// // Inside table_registry.dart
/// runTableRegistry([
///   usersTable,
///   postsTable,
/// ], null, sendPort);
/// ```
///
/// Throws no exceptions directly — errors are logged and an empty list may be sent.
///
/// Used internally by the Flint Dart CLI.
void runTableRegistry(
  List<Table> tables, [
  dynamic _,
  SendPort? sendPort,
]) async {
  if (sendPort == null) {
    print(
        "❌ Error: runTableRegistry must be called via the Flint CLI isolate.");
    return;
  }

  final List<String> diffs = [];

  for (final table in tables) {
    final existingTable = await getTableSchema(table.name);
    if (existingTable == null) {
      diffs.add(table.toCreateSQL());
    } else {
      final diff = existingTable.compareWith(table);
      if (diff != null) {
        diffs.add(diff.toString());
      }
    }
  }

  print(diffs);
  sendPort.send(diffs);
}
