import 'package:flint_dart/flint_dart.dart';
import 'package:test/test.dart';

class _User extends Model<_User> {
  _User() : super(_User.new);

  @override
  Table get table => Table(
        name: 'users',
        columns: [
          Column(name: 'name', type: ColumnType.string),
          Column(name: 'email', type: ColumnType.string),
          Column(name: 'password_hash', type: ColumnType.string),
        ],
      );

  @override
  List<String> get conceal => const ['password_hash'];
}

class _RecordingExecutor implements DbExecutor {
  _RecordingExecutor(this.rows);

  final List<Map<String, dynamic>> rows;
  String? sql;
  List<dynamic>? positionalParams;
  Map<String, dynamic>? namedParams;

  @override
  DBDriver get driver => DBDriver.postgres;

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    this.sql = sql;
    this.positionalParams = positionalParams;
    this.namedParams = namedParams;
    return rows.map(Map<String, dynamic>.from).toList(growable: false);
  }

  @override
  Future<void> execute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {}

  @override
  Future<dynamic> getLastInsertId(String tableName, String primaryKey) async =>
      null;
}

void main() {
  FlintDbResource userResource() => FlintDbResource.fromModel(
        _User.new,
        operations: const {FlintDbOperation.select},
        hiddenFields: const {'email'},
      );

  test('registered read query is bounded, parameterized, and concealed',
      () async {
    final executor = _RecordingExecutor([
      {
        'id': 'u1',
        'name': 'Ada',
        'email': 'private@example.com',
        'password_hash': 'secret',
      },
    ]);
    final api = FlintDatabaseApi(resources: [userResource()]);

    final rows = await api.select(
      'users',
      const FlintDbQuery(
        filter: FlintDbComparison('name', FlintDbOperator.eq, 'Ada'),
      ),
      executor: executor,
    );

    expect(executor.sql, contains('SELECT id, name FROM users'));
    expect(executor.sql, contains('name = :p1'));
    expect(executor.sql, contains('LIMIT 100'));
    expect(executor.sql, isNot(contains('Ada')));
    expect(executor.namedParams, containsPair('p1', 'Ada'));
    expect(rows.single, {'id': 'u1', 'name': 'Ada'});
  });

  test('server-enforced filter is combined with the requested filter',
      () async {
    final executor = _RecordingExecutor(const []);
    final api = FlintDatabaseApi(resources: [userResource()]);

    await api.select(
      'users',
      const FlintDbQuery(
        filter: FlintDbComparison('name', FlintDbOperator.eq, 'Ada'),
      ),
      enforcedFilter: const FlintDbComparison(
        'id',
        FlintDbOperator.eq,
        'authenticated-user',
      ),
      executor: executor,
    );

    expect(executor.sql, contains('name = :p1 AND id = :p2'));
    expect(executor.namedParams, {
      'p1': 'Ada',
      'p2': 'authenticated-user',
    });
  });

  test('unknown resources are denied', () {
    final api = FlintDatabaseApi(resources: [userResource()]);

    expect(
      () => api.registry.resolve('orders'),
      throwsA(
        isA<FlintDbApiException>().having(
          (error) => error.code,
          'code',
          FlintDbErrorCode.resourceNotFound,
        ),
      ),
    );
  });

  test('concealed fields cannot be selected or filtered', () {
    final compiler = FlintDbQueryCompiler(FlintDatabaseApiConfig());

    for (final query in [
      const FlintDbQuery(select: ['password_hash']),
      const FlintDbQuery(
        filter: FlintDbComparison(
          'email',
          FlintDbOperator.eq,
          'private@example.com',
        ),
      ),
    ]) {
      expect(
        () => compiler.compile(userResource(), query),
        throwsA(
          isA<FlintDbApiException>().having(
            (error) => error.code,
            'code',
            FlintDbErrorCode.permissionDenied,
          ),
        ),
      );
    }
  });

  test('page size and unsupported logical filters are rejected', () {
    final compiler = FlintDbQueryCompiler(
      FlintDatabaseApiConfig(maxPageSize: 10),
    );

    expect(
      () => compiler.compile(userResource(), const FlintDbQuery(limit: 11)),
      throwsA(isA<FlintDbApiException>()),
    );
    expect(
      () => compiler.compile(
        userResource(),
        const FlintDbQuery(
          filter: FlintDbLogicalFilter(
            FlintDbLogicalOperator.or,
            [
              FlintDbComparison('name', FlintDbOperator.eq, 'Ada'),
              FlintDbComparison('name', FlintDbOperator.eq, 'Grace'),
            ],
          ),
        ),
      ),
      throwsA(isA<FlintDbApiException>()),
    );
  });

  test('resources default to no allowed operations', () {
    final resource = FlintDbResource.fromModel(_User.new);
    final compiler = FlintDbQueryCompiler(FlintDatabaseApiConfig());

    expect(
      () => compiler.compile(resource, const FlintDbQuery()),
      throwsA(
        isA<FlintDbApiException>().having(
          (error) => error.code,
          'code',
          FlintDbErrorCode.permissionDenied,
        ),
      ),
    );
  });

  test('owned CRUD convention fails closed without an owner field', () {
    expect(
      () => FlintDbResource.ownedCrud(_User.new),
      throwsArgumentError,
    );
  });
}
