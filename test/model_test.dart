import 'package:test/test.dart';
import 'package:flint_dart/db.dart';
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
  Map<String, RelationDefinition> get relations => {
    'user': Relations.belongsTo<User>('user', User.new, foreignKey: 'userId'),
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
    'user': Relations.belongsTo<User>('user', User.new, foreignKey: 'userId'),
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

        final hostings = await Hosting()
            .withRelation('user', columns: ['firstName', 'lastName', 'email'])
            .get();

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
  });
}
