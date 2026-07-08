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
  Map<String, RelationDefinition> get relations => {
        'posts': Relations.hasMany<Post>(
          'posts',
          Post.new,
          foreignKey: 'user_id',
        ),
      };

  @override
  List<String> get conceal => ['password'];
}

class Post extends Model<Post> {
  Post() : super(Post.new);

  @override
  Table get table => Table(
        name: 'posts',
        columns: [
          Column(name: 'user_id', type: ColumnType.string),
          Column(name: 'status', type: ColumnType.string),
        ],
      );

  @override
  Map<String, RelationDefinition> get relations => {
        'user': Relations.belongsTo<User>(
          'user',
          User.new,
          foreignKey: 'user_id',
        ),
      };
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

    test('relationQuery builds a hasMany query from relation metadata', () {
      final user = User()..setAttribute('id', 'user-1');

      final query = user.relationQuery(
        'posts',
        constrain: (query) => query.where('status', '=', 'active'),
      );

      expect(query.table, 'posts');
      expect(query.compileWhereSql(), contains('user_id ='));
      expect(query.compileWhereSql(), contains('status ='));
      expect(query.whereParams.values, containsAll(['user-1', 'active']));
    });

    test('relationQuery builds a belongsTo query from relation metadata', () {
      final post = Post()..setAttribute('user_id', 'user-2');

      final query = post.relationQuery('user');

      expect(query.table, 'users');
      expect(query.compileWhereSql(), contains('id ='));
      expect(query.whereParams.values, contains('user-2'));
    });

    test('relationQuery fails clearly when parent key is missing', () {
      final user = User();

      expect(
        () => user.relationQuery('posts'),
        throwsA(isA<StateError>()),
      );
    });

    test('relationCounts supports empty grouped count requests', () async {
      final user = User()..setAttribute('id', 'user-1');

      final counts = await user.relationCounts('posts', const {});

      expect(counts, isEmpty);
    });

    test('loadRelationCount fails before DB work when parent key is missing',
        () async {
      final user = User();

      expect(
        () => user.loadRelationCount('posts', as: 'postCount'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
