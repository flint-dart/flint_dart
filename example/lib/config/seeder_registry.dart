import 'package:flint_dart/flint_dart.dart';
import '../seeders/user_modelhj_seeder.dart';

/// Run this sample seeder registry from the repository root with:
/// `dart run example/lib/config/seeder_registry.dart`
///
/// In a regular Flint app, run:
/// `flint --db-seed`
Future<void> main() async {
  await runSeeders([
    UserModelhjSeeder(),
  ]);
}
