import 'package:flint_dart/db.dart';
import 'package:flint_dart/src/database/pg_connection.dart';
import 'package:test/test.dart';

void main() {
  group('SeederRunner', () {
    test('runs seeders in order and closes the database connection', () async {
      final connection = _FakePgConnectionWrapper();
      DB.overrideConnection(connection);

      final calls = <String>[];
      await runSeeders([
        _TestSeeder('first', calls),
        _TestSeeder('second', calls),
      ]);

      expect(calls, ['first', 'second']);
      expect(connection.closed, isTrue);
      expect(DB.isConnected, isFalse);
    });

    test('closes the database connection even when a seeder fails', () async {
      final connection = _FakePgConnectionWrapper();
      DB.overrideConnection(connection);

      await expectLater(
        () => runSeeders([
          _ThrowingSeeder(),
        ]),
        throwsA(isA<StateError>()),
      );

      expect(connection.closed, isTrue);
      expect(DB.isConnected, isFalse);
    });
  });
}

class _TestSeeder extends Seeder {
  final String value;
  final List<String> calls;

  _TestSeeder(this.value, this.calls);

  @override
  Future<void> run() async {
    calls.add(value);
  }
}

class _ThrowingSeeder extends Seeder {
  @override
  Future<void> run() async {
    throw StateError('failed seeder');
  }
}

class _FakePgConnectionWrapper extends PgConnectionWrapper {
  bool closed = false;

  @override
  bool get isConnected => !closed;

  @override
  Future<void> close() async {
    closed = true;
  }
}
