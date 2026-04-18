import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/src/database/mysql_connection.dart';
import 'package:test/test.dart';

class _CapturingMySqlConnection extends MySqlConnectionWrapper {
  String? lastQuerySql;
  List<dynamic>? lastQueryParams;
  String? lastExecuteSql;
  List<dynamic>? lastExecuteParams;
  List<Map<String, dynamic>> nextQueryResult = const [];

  @override
  bool get isConnected => true;

  @override
  Future<void> close() async {}

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    lastQuerySql = sql;
    lastQueryParams =
        positionalParams == null ? null : List<dynamic>.from(positionalParams);
    return nextQueryResult
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  @override
  Future<void> execute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    lastExecuteSql = sql;
    lastExecuteParams =
        positionalParams == null ? null : List<dynamic>.from(positionalParams);
  }
}

class _User extends Model<_User> {
  _User() : super(_User.new);

  @override
  Table get table => Table(
        name: 'users',
        columns: [
          Column(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
          Column(name: 'email', type: ColumnType.string),
          Column(name: 'name', type: ColumnType.string),
          Column(name: 'active', type: ColumnType.boolean),
        ],
      );
}

void main() {
  group('orWhere', () {
    tearDown(() async {
      await DB.close();
    });

    test('compileWhereSql includes grouped OR clauses', () {
      final qb = QueryBuilder(table: 'users')
        ..where('active', '=', 1)
        ..orWhere('email', '=', 'ada@example.com')
        ..orWhere('name', '=', 'Ada');

      expect(qb.hasWhereClause, isTrue);
      expect(
        qb.compileWhereSql(),
        'WHERE active = ? AND (email = ? OR name = ?)',
      );
      expect(qb.whereParams, {
        'p1': 1,
        'p2': 'ada@example.com',
        'p3': 'Ada',
      });
    });

    test('model first uses orWhere clauses in the generated query', () async {
      final connection = _CapturingMySqlConnection()
        ..nextQueryResult = [
          {
            'id': 1,
            'email': 'ada@example.com',
            'name': 'Ada',
            'active': 1,
          },
        ];
      DB.overrideConnection(connection);

      final user = await _User().orWhere('email', 'ada@example.com').first();

      expect(
        connection.lastQuerySql,
        'SELECT * FROM users WHERE (email = ?) LIMIT 1',
      );
      expect(connection.lastQueryParams, ['ada@example.com']);
      expect(user?.getAttribute<String>('name'), 'Ada');
    });

    test('model all respects chained where clauses', () async {
      final connection = _CapturingMySqlConnection()
        ..nextQueryResult = [
          {
            'id': 1,
            'email': 'ada@example.com',
            'name': 'Ada',
            'active': 1,
          },
        ];
      DB.overrideConnection(connection);

      final users = await _User().where('email', 'ada@example.com').all();

      expect(
        connection.lastQuerySql,
        'SELECT * FROM users WHERE email = ?',
      );
      expect(connection.lastQueryParams, ['ada@example.com']);
      expect(users, hasLength(1));
      expect(users.first.getAttribute<String>('name'), 'Ada');
    });

    test('model update accepts orWhere-only filters', () async {
      final connection = _CapturingMySqlConnection();
      DB.overrideConnection(connection);

      await _User().orWhere('email', 'ada@example.com').update(
        data: {'name': 'Ada Lovelace'},
      );

      expect(
        connection.lastExecuteSql,
        'UPDATE `users` SET `name` = ? WHERE (email = ?)',
      );
      expect(connection.lastExecuteParams, ['Ada Lovelace', 'ada@example.com']);
    });
  });
}
