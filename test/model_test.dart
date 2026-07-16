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

class Post extends Model<Post> {
  Post() : super(Post.new);

  @override
  Map<String, RelationDefinition> get relations => {
        'user':
            Relations.belongsTo<User>('user', User.new, foreignKey: 'userId'),
      };

  @override
  Table get table => Table(
        name: 'posts',
        columns: [
          Column(name: 'title', type: ColumnType.string),
          Column(name: 'userId', type: ColumnType.string),
        ],
      );
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

    test('fromMap hydrates belongsTo relation maps', () {
      final post = Post().fromMap({
        'title': 'Hello',
        'userId': 'user-1',
        'user': {'id': 'user-1', 'name': 'Tari', 'age': '30'},
      });

      final user = post.getRelation<User>('user');

      expect(user, isNotNull);
      expect(user!.id, 'user-1');
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
