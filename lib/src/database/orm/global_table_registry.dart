import 'dart:isolate';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/schema.dart';

/// Runs the table registry process inside a Dart isolate.
///
/// The migrate command expects canonical table definitions, not precomputed
/// ALTER statements. It compares the live database schema against these CREATE
/// TABLE definitions and then applies the necessary add/modify/drop work.
void runTableRegistry(
  List<Table> tables, [
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
      });
    }
  } catch (e, st) {
    Log.debug('Error in table registry: $e\n$st');
  }

  sendPort.send(registeredTables.isEmpty ? sqlDefinitions : registeredTables);
  Isolate.exit();
}
