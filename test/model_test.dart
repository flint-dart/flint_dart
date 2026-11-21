import 'package:test/test.dart';
import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/src/database/mysql_connection.dart';

class _CapturingMySqlConnection extends MySqlConnectionWrapper {
  _CapturingMySqlConnection(this.queuedResults);

  final List<List<Map<String, dynamic>>> queuedResults;
  final queries = <String>[];
  final params = <List<dynamic>?>[];

  @override
  bool get isConnected => true;

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    queries.add(sql);
    params.add(
      positionalParams == null ? null : List<dynamic>.from(positionalParams),
    );

    if (queuedResults.isEmpty) return const [];
    return queuedResults
        .removeAt(0)
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  @override
  Future<void> execute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {}

  @override
  Future<void> beginTransaction() async {}

  @override
  Future<void> commit() async {}

  @override
  Future<void> rollback() async {}

  @override
  Future<void> close() async {}
}

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
        'posts':
            Relations.hasMany<Post>('posts', Post.new, foreignKey: 'user_id'),
      };

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

class Hosting extends Model<Hosting> {
  Hosting() : super(Hosting.new);

  @override
  Map<String, RelationDefinition> get relations => {
        'user':
            Relations.belongsTo<User>('user', User.new, foreignKey: 'userId'),
      };

  @override
  Table get table => Table(
        name: 'hostings',
        columns: [
          Column(name: 'domain', type: ColumnType.string),
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
      expect(
        user.getAttribute<DateTime>('created_at'),
        DateTime.parse('2025-01-02T03:04:05Z'),
      );
      expect(user.getAttribute<String>('name'), '123');
    });

    test('toMap omits concealed fields', () {
      final user = User();
      user.setAttributes({'name': 'Ada', 'password': 'secret'});

      final map = user.toMap();
      expect(map['name'], 'Ada');
      expect(map.containsKey('password'), isFalse);
    });

    test('fromMap populates attributes', () {
      final user = User().fromMap({'name': 'Tari', 'age': 30});
      expect(user.getAttribute<String>('name'), 'Tari');
      expect(user.getAttribute<int>('age'), 30);
    });

    test('create hydrates both the source and returned model', () async {
      final connection = _CapturingMySqlConnection([
        const [],
        [
          {
            'id': 'user-1',
            'name': 'Ada',
            'age': 30,
            'active': 1,
          },
        ],
      ]);
      DB.overrideConnection(connection);
      final user = User();

      final created = await user.create({'name': 'Ada', 'age': 30});

      expect(created, isNotNull);
      expect(created!.id, 'user-1');
      expect(user.id, 'user-1');
      expect(user.getAttribute<String>('name'), 'Ada');
      expect(user.getAttribute<bool>('active'), isTrue);
    });

    test('fromMap hydrates belongsTo relation maps', () {
      final post = Post().fromMap({
        'status': 'published',
        'user_id': 'user-1',
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
      expect(() => user.load('missing'), throwsA(isA<Exception>()));
    });

    test(
      'withRelation hydrates belongsTo models with selected columns',
      () async {
        final connection = _CapturingMySqlConnection([
          [
            {'id': 'hosting-1', 'domain': 'site.test', 'userId': 'user-1'},
          ],
          [
            {
              'id': 'user-1',
              'firstName': 'Ada',
              'lastName': 'Lovelace',
              'email': 'ada@example.com',
            },
          ],
        ]);
        DB.overrideConnection(connection);

        final hostings = await Hosting().withRelation('user',
            columns: ['firstName', 'lastName', 'email']).get();

        expect(connection.queries, [
          'SELECT * FROM hostings',
          'SELECT firstName, lastName, email, id FROM users WHERE id IN (?)',
        ]);
        expect(connection.params.last, ['user-1']);
        expect(hostings, hasLength(1));

        final user = hostings.single.getRelation<User>('user');
        expect(user, isNotNull);
        expect(user!.id, 'user-1');
        expect(user.getAttribute<String>('firstName'), 'Ada');
        expect(user.getAttribute<String>('email'), 'ada@example.com');
      },
    );

    test('nested eager loading via dot notation hydrates deep relation graphs',
        () async {
      final connection = _CapturingMySqlConnection([
        [
          {'id': 'hosting-1', 'domain': 'site.test', 'userId': 'user-1'},
        ],
        [
          {
            'id': 'user-1',
            'name': 'Ada Lovelace',
          },
        ],
        [
          {
            'id': 'post-1',
            'title': 'First Algorithm',
            'user_id': 'user-1',
          },
          {
            'id': 'post-2',
            'title': 'Analytical Engine Notes',
            'user_id': 'user-1',
          },
        ],
      ]);
      DB.overrideConnection(connection);

      final hostings =
          await Hosting().withRelations(['user.posts']).get();

      expect(hostings, hasLength(1));
      final hosting = hostings.first;
      final user = hosting.getRelation<User>('user');
      expect(user, isNotNull);
      expect(user!.getAttribute<String>('name'), 'Ada Lovelace');

      final posts = user.getAttribute<List<dynamic>>('posts');
      expect(posts, isNotNull);
      expect(posts, hasLength(2));
      expect((posts!.first as Post).getAttribute<String>('title'),
          'First Algorithm');
      expect((posts.last as Post).getAttribute<String>('title'),
          'Analytical Engine Notes');
    });

    test('load() with dot notation hydrates nested relation on single instance',
        () async {
      final connection = _CapturingMySqlConnection([
        [
          {
            'id': 'user-1',
            'name': 'Ada Lovelace',
          },
        ],
        [
          {
            'id': 'post-1',
            'title': 'First Algorithm',
            'user_id': 'user-1',
          },
        ],
      ]);
      DB.overrideConnection(connection);

      final hosting = Hosting()..setAttribute('userId', 'user-1');
      await hosting.load('user.posts');

      final user = hosting.getRelation<User>('user');
      expect(user, isNotNull);
      final posts = user!.getAttribute<List<dynamic>>('posts');
      expect(posts, hasLength(1));
      expect((posts!.first as Post).getAttribute<String>('title'),
          'First Algorithm');
    });

    test('fluent where methods generate proper conditions without SQL operator strings',
        () async {
      final connection = _CapturingMySqlConnection([
        [
          {'id': 'user-1', 'name': 'Ada', 'age': 30, 'active': true},
        ],
      ]);
      DB.overrideConnection(connection);

      final users = await User()
          .whereEqual('status', 'active')
          .whereTrue('is_verified')
          .whereGreaterThan('age', 18)
          .whereNotEqual('role', 'banned')
          .get();

      expect(users, hasLength(1));
      expect(connection.queries.single,
          'SELECT * FROM users WHERE status = ? AND is_verified = ? AND age > ? AND role != ?');
      // In MySQL, boolean true is normalized to 1 in query bindings
      expect(connection.params.single, ['active', 1, 18, 'banned']);
    });

    test('filter() with named arguments supports clean autocomplete queries',
        () async {
      final connection = _CapturingMySqlConnection([
        [
          {'id': 'user-1', 'name': 'Ada', 'age': 30},
        ],
      ]);
      DB.overrideConnection(connection);

      final users = await User()
          .filter('role', equals: 'admin')
          .filter('age', greaterThan: 18, lessThan: 65)
          .filter('status', notEquals: 'banned')
          .get();

      expect(users, hasLength(1));
      expect(connection.queries.single,
          'SELECT * FROM users WHERE role = ? AND age > ? AND age < ? AND status != ?');
      expect(connection.params.single, ['admin', 18, 65, 'banned']);
    });

    test('where() accepts typed matcher helpers like Op.equals() and Op.greaterThan()',
        () async {
      final connection = _CapturingMySqlConnection([
        [
          {'id': 'user-1', 'name': 'Ada', 'age': 30},
        ],
      ]);
      DB.overrideConnection(connection);

      final users = await User()
          .where('role', Op.equals('admin'))
          .where('age', Op.greaterThan(18))
          .where('status', Op.notEquals('banned'))
          .get();

      expect(users, hasLength(1));
      expect(connection.queries.single,
          'SELECT * FROM users WHERE role = ? AND age > ? AND status != ?');
      expect(connection.params.single, ['admin', 18, 'banned']);
    });

    test('legacy positional where() API continues to work 100% without deprecation',
        () async {
      final connection = _CapturingMySqlConnection([
        [
          {'id': 'user-1', 'name': 'Ada', 'age': 30},
        ],
      ]);
      DB.overrideConnection(connection);

      // Old 2-arg and 3-arg positional syntax
      final users = await User()
          .where('status', 'active')
          .where('age', '>=', 18)
          .where('role', '=', 'admin')
          .get();

      expect(users, hasLength(1));
      expect(connection.queries.single,
          'SELECT * FROM users WHERE status = ? AND age >= ? AND role = ?');
      expect(connection.params.single, ['active', 18, 'admin']);
    });
  });
}
