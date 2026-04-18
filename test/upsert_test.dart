import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/src/database/mysql_connection.dart';
import 'package:test/test.dart';

class _FakeMySqlConnection extends MySqlConnectionWrapper {
  @override
  bool get isConnected => true;

  @override
  Future<void> close() async {}
}

class _SpyState {
  Map<String, dynamic>? existingRow;
  Map<String, dynamic>? persistedRow;
  Map<String, dynamic>? searchedWhere;
  Map<String, dynamic>? createdData;
  Map<String, dynamic>? updatedData;
}

class _FakeQueryBuilder extends QueryBuilder {
  final Map<String, dynamic> capturedWhere = {};

  _FakeQueryBuilder(String table) : super(table: table);

  @override
  QueryBuilder where(String field, String operator, dynamic value) {
    capturedWhere[field] = value;
    return this;
  }
}

class _SpyUser extends Model<_SpyUser> {
  final _SpyState state;
  late _FakeQueryBuilder _builder;

  _SpyUser([_SpyState? state])
      : state = state ?? _SpyState(),
        super(() => _SpyUser(state)) {
    _builder = _FakeQueryBuilder('users');
  }

  @override
  Table get table => Table(
        name: 'users',
        columns: [
          Column(
            name: 'id',
            type: ColumnType.string,
            isPrimaryKey: true,
          ),
          Column(name: 'email', type: ColumnType.string),
          Column(name: 'name', type: ColumnType.string),
          Column(name: 'password', type: ColumnType.string),
        ],
      );

  @override
  QueryBuilder get qb => _builder;

  @override
  _SpyUser resetQuery() {
    _builder = _FakeQueryBuilder(table.name);
    return this;
  }

  @override
  Future<_SpyUser?> first() async {
    state.searchedWhere = Map<String, dynamic>.from(_builder.capturedWhere);

    if (state.existingRow == null) {
      return null;
    }

    state.persistedRow = Map<String, dynamic>.from(state.existingRow!);
    return fromMap(state.persistedRow!);
  }

  @override
  Future<List<Map<String, dynamic>>> runQuery(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    final normalizedSql = sql.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (normalizedSql.startsWith('INSERT INTO users')) {
      final payload = _extractInsertPayload(
        sql,
        positionalParams: positionalParams,
        namedParams: namedParams,
      );
      state.createdData = payload;
      state.persistedRow = Map<String, dynamic>.from(payload);
      return [];
    }

    if (normalizedSql.startsWith('SELECT * FROM users WHERE id =')) {
      return [Map<String, dynamic>.from(state.persistedRow ?? const {})];
    }

    throw UnsupportedError('Unexpected query: $normalizedSql');
  }

  @override
  Future<void> runExecute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    final normalizedSql = sql.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (normalizedSql.startsWith('UPDATE `users` SET ')) {
      final payload = _extractUpdatePayload(
        normalizedSql,
        positionalParams: positionalParams,
        namedParams: namedParams,
      );
      state.updatedData = Map<String, dynamic>.from(payload)..remove('id');
      state.persistedRow = {
        ...?state.persistedRow,
        ...?state.existingRow,
        ...state.updatedData!,
        if (payload['id'] != null)
          'id': payload['id']
        else if (state.persistedRow?['id'] != null)
          'id': state.persistedRow!['id']
        else if (state.existingRow?['id'] != null)
          'id': state.existingRow!['id'],
      };
      return;
    }

    throw UnsupportedError('Unexpected execute: $normalizedSql');
  }

}

Map<String, dynamic> _extractInsertPayload(
  String sql, {
  List<dynamic>? positionalParams,
  Map<String, dynamic>? namedParams,
}) {
  final normalizedSql = sql.replaceAll(RegExp(r'\s+'), ' ').trim();
  final fieldsStart = normalizedSql.indexOf('(');
  final fieldsEnd = normalizedSql.indexOf(')', fieldsStart);
  final fields = normalizedSql
      .substring(fieldsStart + 1, fieldsEnd)
      .split(',')
      .map((field) => field.trim())
      .toList();

  if (namedParams != null && namedParams.isNotEmpty) {
    return {
      for (final field in fields) field: namedParams[field],
    };
  }

  final values = positionalParams ?? const <dynamic>[];
  return {
    for (var i = 0; i < fields.length; i++) fields[i]: values[i],
  };
}

Map<String, dynamic> _extractUpdatePayload(
  String sql, {
  List<dynamic>? positionalParams,
  Map<String, dynamic>? namedParams,
}) {
  if (namedParams != null && namedParams.isNotEmpty) {
    return Map<String, dynamic>.from(namedParams);
  }

  final setStart = sql.indexOf(' SET ') + 5;
  final whereStart = sql.indexOf(' WHERE ');
  final assignments = sql.substring(setStart, whereStart).split(', ');
  final fields = assignments
      .map(
        (assignment) => RegExp(r'`([^`]+)`').firstMatch(assignment)!.group(1)!,
      )
      .toList();
  final values = positionalParams ?? const <dynamic>[];
  final payload = <String, dynamic>{};

  for (var i = 0; i < fields.length; i++) {
    payload[fields[i]] = values[i];
  }

  if (values.length > fields.length) {
    payload['id'] = values.last;
  }

  return payload;
}

void main() {
  group('upsert', () {
    setUp(() {
      DB.overrideConnection(_FakeMySqlConnection());
    });

    tearDown(() async {
      await DB.close();
    });

    test('excludeUpdatedData removes fields from the legacy update payload',
        () async {
      final state = _SpyState()
        ..existingRow = {
          'id': 'user-1',
          'email': 'ada@example.com',
          'name': 'Old Name',
          'password': 'old-secret',
        };

      await _SpyUser(state).upsert(
        where: {'email': 'ada@example.com'},
        data: {
          'email': 'ada@example.com',
          'name': 'Ada Lovelace',
          'password': 'new-secret',
        },
        excludeUpdatedData: ['password'],
      );

      expect(state.searchedWhere, {'email': 'ada@example.com'});
      expect(state.updatedData, {
        'email': 'ada@example.com',
        'name': 'Ada Lovelace',
      });
      expect(state.updatedData, isNot(contains('password')));
      expect(state.createdData, isNull);
    });

    test('createData and updateData use the explicit update payload', () async {
      final state = _SpyState()
        ..existingRow = {
          'id': 'user-2',
          'email': 'grace@example.com',
          'name': 'Grace Hopper',
        };

      await _SpyUser(state).upsert(
        uniqueBy: ['email'],
        createData: {
          'name': 'Create Only Name',
          'password': 'create-secret',
        },
        updateData: {
          'email': 'grace@example.com',
          'name': 'Updated Grace',
        },
      );

      expect(state.searchedWhere, {'email': 'grace@example.com'});
      expect(state.updatedData, {
        'email': 'grace@example.com',
        'name': 'Updated Grace',
      });
      expect(state.createdData, isNull);
    });

    test('createData is used for insert when no existing record is found',
        () async {
      final state = _SpyState();

      final created = await _SpyUser(state).upsert(
        where: {'email': 'new@example.com'},
        createData: {
          'name': 'New User',
          'password': 'create-secret',
        },
        updateData: {
          'name': 'Should Not Be Used',
        },
      );

      expect(state.searchedWhere, {'email': 'new@example.com'});
      expect(state.createdData, containsPair('email', 'new@example.com'));
      expect(state.createdData, containsPair('name', 'New User'));
      expect(state.createdData, containsPair('password', 'create-secret'));
      expect(state.updatedData, isNull);
      expect(created?.getAttribute<String>('name'), 'New User');
    });
  });
}
