import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/src/database/mysql_connection.dart';
import 'package:test/test.dart';

class _RecordingConnection extends MySqlConnectionWrapper {
  _RecordingConnection({this.rows = const []});

  final List<Map<String, dynamic>> rows;
  final queries = <String>[];
  final executions = <String>[];
  bool began = false;
  bool committed = false;
  bool rolledBack = false;

  @override
  bool get isConnected => true;

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    queries.add(sql);
    return rows.map(Map<String, dynamic>.from).toList(growable: false);
  }

  @override
  Future<void> execute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    executions.add(sql);
  }

  @override
  Future<void> beginTransaction() async => began = true;

  @override
  Future<void> commit() async => committed = true;

  @override
  Future<void> rollback() async => rolledBack = true;

  @override
  Future<void> close() async {}
}

class _TransactionUser extends Model<_TransactionUser> {
  _TransactionUser() : super(_TransactionUser.new);

  @override
  Table get table => Table(
        name: 'transaction_users',
        columns: [Column(name: 'name', type: ColumnType.string)],
      );
}

void main() {
  test('QueryBuilder uses its supplied executor', () async {
    final global = _RecordingConnection();
    final transactional = _RecordingConnection(rows: const [
      {'id': 'user-1', 'name': 'Ada'},
    ]);
    DB.overrideConnection(global);

    final rows = await QueryBuilder(
      table: 'transaction_users',
      executor: DBTransaction(transactional),
    ).where('id', '=', 'user-1').get();

    expect(rows.single['name'], 'Ada');
    expect(transactional.queries, hasLength(1));
    expect(global.queries, isEmpty);
  });

  test('Model useTransaction propagates to its QueryBuilder', () async {
    final global = _RecordingConnection();
    final transactional = _RecordingConnection(rows: const [
      {'id': 'user-1', 'name': 'Ada'},
    ]);
    DB.overrideConnection(global);

    final users = await _TransactionUser()
        .useTransaction(DBTransaction(transactional))
        .where('name', 'Ada')
        .get();

    expect(users.single.getAttribute<String>('name'), 'Ada');
    expect(transactional.queries, hasLength(1));
    expect(global.queries, isEmpty);
  });

  test('entering a transaction replaces an existing global query builder',
      () async {
    final global = _RecordingConnection();
    final transactional = _RecordingConnection(rows: const [
      {'id': 'user-1', 'name': 'Ada'},
    ]);
    DB.overrideConnection(global);

    final model = _TransactionUser()..where('name', 'before-transaction');
    final users = await model
        .useTransaction(DBTransaction(transactional))
        .where('name', 'Ada')
        .get();

    expect(users, hasLength(1));
    expect(transactional.queries.single, contains('name = ?'));
    expect(global.queries, isEmpty);
  });
}
