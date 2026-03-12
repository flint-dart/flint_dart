import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/database/db.dart';

/// Base contract for framework-level database seeders.
abstract class Seeder {
  /// Human-readable seeder name used in logs.
  String get name => runtimeType.toString();

  /// Executes the seeder logic.
  Future<void> run();
}

/// Runs a list of seeders sequentially and closes the database connection.
class SeederRunner {
  /// Executes [seeders] in order.
  static Future<void> run(
    List<Seeder> seeders, {
    bool closeConnection = true,
  }) async {
    try {
      for (final seeder in seeders) {
        Log.info('Running seeder: ${seeder.name}');
        await seeder.run();
        Log.success('Seeder completed: ${seeder.name}');
      }
    } finally {
      if (closeConnection && DB.isConnected) {
        await DB.close();
        Log.debug('[DB] SeederRunner closed database connection');
      }
    }
  }
}

/// Convenience helper for running framework seeders.
Future<void> runSeeders(
  List<Seeder> seeders, {
  bool closeConnection = true,
}) {
  return SeederRunner.run(
    seeders,
    closeConnection: closeConnection,
  );
}
