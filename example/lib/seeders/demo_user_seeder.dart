import 'package:flint_dart/flint_dart.dart';
import 'package:sample/models/user_model.dart';

class DemoUserSeeder extends Seeder {
  @override
  Future<void> run() async {
    await User().upsert(
      where: {'email': 'ada@example.com'},
      data: {
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
        'password': 'password123',
        'profilePicUrl': 'https://example.com/avatars/ada.png',
      },
    );

    await User().upsert(
      where: {'email': 'grace@example.com'},
      data: {
        'name': 'Grace Hopper',
        'email': 'grace@example.com',
        'password': 'password123',
        'profilePicUrl': 'https://example.com/avatars/grace.png',
      },
    );

    Log.info('Seeded demo users');
  }
}
