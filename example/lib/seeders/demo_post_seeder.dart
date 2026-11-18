import 'package:flint_dart/flint_dart.dart';
import 'package:sample/models/post_model.dart';

class DemoPostSeeder extends Seeder {
  @override
  Future<void> run() async {
    await PostModel().upsert(
      where: {'title': 'Welcome to Flint AI'},
      data: {
        'title': 'Welcome to Flint AI',
        'subTitle': 'A seeded post created by the framework seeder runner.',
      },
    );

    await PostModel().upsert(
      where: {'title': 'Framework-level Seeding'},
      data: {
        'title': 'Framework-level Seeding',
        'subTitle':
            'Seeders run sequentially through Flint and close the DB connection afterward.',
      },
    );

    Log.info('Seeded demo posts');
  }
}
