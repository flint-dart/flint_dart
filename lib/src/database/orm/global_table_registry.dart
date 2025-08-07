import 'dart:isolate';
import 'package:flint_dart/schema.dart';

/// Call this in your `table_registry.dart` to register tables via isolate.
void runTableRegistry(List<Table> tables, [_, SendPort? sendPort]) async {
  if (sendPort == null) {
    print(
        "❌ Error: runTableRegistry must be called via the Flint CLI isolate.");
    return;
  }

  final diffs = [];

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
  print(diffs.map((e) => e.toString()).toList());
  sendPort.send(diffs.map((e) => e.toString()).toList());
}
