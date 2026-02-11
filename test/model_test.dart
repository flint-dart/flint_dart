import 'package:test/test.dart';
import 'package:flint_dart/flint_dart.dart';

class User extends Model<User> {
  User() : super(User.new);

  @override
  Table get table => Table(
        name: 'users',
        columns: [
          Column(name: 'name', type: ColumnType.string),
          Column(name: 'age', type: ColumnType.integer),
          Column(name: 'active', type: ColumnType.boolean),
          Column(name: 'created_at', type: ColumnType.datetime),
        ],
      );

  @override
  List<String> get conceal => ['password'];
}

void main() {
  group('Model', () {
    test('getAttribute coerces basic types', () {
      final user = User();
      user.setAttribute('age', '42');
      user.setAttribute('active', 'true');
      user.setAttribute('created_at', '2025-01-02T03:04:05Z');
      user.setAttribute('name', 123);

      expect(user.getAttribute<int>('age'), 42);
      expect(user.getAttribute<bool>('active'), isTrue);
      expect(user.getAttribute<DateTime>('created_at'),
          DateTime.parse('2025-01-02T03:04:05Z'));
      expect(user.getAttribute<String>('name'), '123');
    });

    test('toMap omits concealed fields', () {
      final user = User();
      user.setAttributes({
        'name': 'Ada',
        'password': 'secret',
      });

      final map = user.toMap();
      expect(map['name'], 'Ada');
      expect(map.containsKey('password'), isFalse);
    });

    test('fromMap populates attributes', () {
      final user = User().fromMap({'name': 'Tari', 'age': 30});
      expect(user.getAttribute<String>('name'), 'Tari');
      expect(user.getAttribute<int>('age'), 30);
    });

    test('load throws when relation is missing', () async {
      final user = User();
      expect(
        () => user.load('missing'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
