import 'package:flint_dart/flint_dart.dart';
import 'package:sample/seeders/demo_user_seeder.dart';

/// This registry is the canonical entry point for seeders in this sample.
class AppSeederRegistry extends SeederRegistry {
  const AppSeederRegistry();

  @override
  Iterable<Seeder> get seeders => [
        DemoUserSeeder(),
      ];
}

Future<void> main() => const AppSeederRegistry().registerAll();
