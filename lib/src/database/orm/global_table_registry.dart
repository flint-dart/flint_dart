import 'dart:isolate';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/schema.dart';

/// Runs the table registry process inside a Dart isolate.
///
/// The migrate command expects canonical table definitions, not precomputed
/// ALTER statements. It compares the live database schema against these CREATE
/// TABLE definitions and then applies the necessary add/modify/drop work.
void registerTableRegistry(
  Iterable<Table> tables, [
  dynamic _,
  SendPort? sendPort,
]) async {
  if (sendPort == null) {
    Log.debug(
      'Error: runTableRegistry must be called via the Flint CLI isolate.',
    );
    Isolate.exit();
  }

  final sqlDefinitions = <String>[];
  final registeredTables = <Map<String, Object?>>[];

  try {
    for (final table in tables) {
      final createSql = table.toCreateSQL();
      sqlDefinitions.add(createSql);
      registeredTables.add({
        'tableName': table.name,
        'createSql': createSql,
        'indexes': table.indexes
            .map((index) => {
                  'name': index.name,
                  'columns': index.columns,
                  'isUnique': index.isUnique,
                })
            .toList(),
        'columns': table.columns
            .map((column) => {
                  'name': column.name,
                  'comment': column.comment,
                  'after': column.after,
                  'renamedFrom': column.renamedFrom,
                })
            .toList(),
      });
    }
  } catch (e, st) {
    Log.debug('Error in table registry: $e\n$st');
  }

  sendPort.send(registeredTables.isEmpty ? sqlDefinitions : registeredTables);
  Isolate.exit();
}

/// Registry contract for application tables.
///
/// Use this in `lib/config/table_registry.dart` so tables follow the same
/// shape as seeders and jobs.
abstract class TableRegistry {
  const TableRegistry();

  Iterable<Table> get tables;

  void registerTables([
    dynamic data,
    SendPort? sendPort,
  ]) {
    registerTableRegistry(tables, data, sendPort);
  }

  void registerAll([
    dynamic data,
    SendPort? sendPort,
  ]) {
    registerTables(data, sendPort);
  }
}

/// Backwards-compatible alias for older table registry files.
void runTableRegistry(
  List<Table> tables, [
  dynamic _,
  SendPort? sendPort,
]) {
  registerTableRegistry(tables, _, sendPort);
}
