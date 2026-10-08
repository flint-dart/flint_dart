import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/src/database/db_wrapper.dart';
import 'package:flint_dart/src/database/mysql_connection.dart';
import 'package:flint_dart/src/database/pg_connection.dart';
import 'package:test/test.dart';

class _Hosting extends Model<_Hosting> {
  _Hosting() : super(_Hosting.new);

  @override
  Table get table => Table(
        name: 'hostings',
        columns: [
          Column(name: 'isCanceled', type: ColumnType.boolean),
          Column(name: 'cancellationReason', type: ColumnType.string),
          Column(name: 'cancelledAt', type: ColumnType.datetime),
          Column(name: 'metadata', type: ColumnType.json),
        ],
      );
}

mixin _RecordingUpdates implements DBWrapper {
  final row = <String, dynamic>{
    'id': 'hosting-1',
    'isCanceled': true,
    'cancellationReason': 'No longer needed',
    'cancelledAt': DateTime(2026, 10, 1),
    'metadata': {'pendingProviderCancellation': true},
  };
  final updates = <Map<String, dynamic>>[];

  @override
  bool get isConnected => true;

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async =>
      [Map.of(row)];

  @override
  Future<void> execute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    final columns = RegExp(r'`([^`]+)` = ')
        .allMatches(sql.split(' WHERE ').first)
        .map((match) => match.group(1)!)
        .toList();
    final update = <String, dynamic>{
      for (var index = 0; index < columns.length; index++)
        columns[index]: namedParams != null
            ? namedParams[columns[index]]
            : positionalParams![index],
    };
    updates.add(update);
    row.addAll(update);
  }

  @override
  Future<void> beginTransaction() async {}

  @override
  Future<void> commit() async {}

  @override
  Future<void> rollback() async {}

  @override
  Future<void> close() async {}
}

class _MySqlUpdates extends MySqlConnectionWrapper with _RecordingUpdates {}

class _PostgresUpdates extends PgConnectionWrapper with _RecordingUpdates {}

void main() {
  for (final driver in DBDriver.values) {
    group('$driver null updates', () {
      late _RecordingUpdates connection;

      setUp(() {
        connection =
            driver == DBDriver.mysql ? _MySqlUpdates() : _PostgresUpdates();
        DB.overrideConnection(connection);
      });
      tearDown(() async => DB.close());

      void expectCleared() {
        expect(connection.updates.single,
            containsPair('cancellationReason', null));
        expect(connection.updates.single, containsPair('cancelledAt', null));
        expect(connection.row['cancellationReason'], isNull);
        expect(connection.row['cancelledAt'], isNull);
        expect(
            connection.row['isCanceled'], driver == DBDriver.mysql ? 0 : false);
      }

      _Hosting revokedHosting() => _Hosting().fromMap(connection.row)
        ..setAttribute('isCanceled', false)
        ..setAttribute('cancellationReason', null)
        ..setAttribute('cancelledAt', null);

      test('save persists false and clears nullable attributes', () async {
        final saved = await revokedHosting().save();

        expectCleared();
        expect(saved!.getAttribute<bool>('isCanceled'), isFalse);
        expect(saved.getAttribute('cancellationReason'), isNull);
        expect(saved.getAttribute('cancelledAt'), isNull);
      });

      test('update without data preserves intentional nulls', () async {
        await revokedHosting().update();
        expectCleared();
      });

      test('update with empty data preserves intentional nulls', () async {
        await revokedHosting().update(data: {});
        expectCleared();
      });

      test('explicit update can clear all nullable fields including JSON',
          () async {
        await _Hosting().fromMap({'id': 'hosting-1'}).update(data: {
          'isCanceled': false,
          'cancellationReason': null,
          'cancelledAt': null,
          'metadata': null,
        });
        expectCleared();
        expect(connection.updates.single, containsPair('metadata', null));
      });

      test('partial model save does not clear omitted attributes', () async {
        final originalDate = connection.row['cancelledAt'];
        await _Hosting().fromMap({
          'id': 'hosting-1',
          'cancellationReason': null,
        }).save();

        expect(connection.updates.single, {'cancellationReason': null});
        expect(connection.row['cancelledAt'], originalDate);
        expect(connection.row['isCanceled'], isTrue);
      });

      test('where-based update also persists null attributes', () async {
        final hosting = _Hosting()
          ..setAttribute('cancellationReason', null)
          ..setAttribute('cancelledAt', null);
        await hosting.where('id', 'hosting-1').update();

        expect(connection.updates.single, {
          'cancellationReason': null,
          'cancelledAt': null,
        });
        expect(connection.row['cancellationReason'], isNull);
      });

      test(
          'datetime updates survive a save round trip without conversion drift',
          () async {
        final date = DateTime(2026, 11, 1, 12, 30);
        var hosting = await _Hosting().fromMap({'id': 'hosting-1'}).update(
          data: {'cancelledAt': date},
        );
        expect(connection.updates.single['cancelledAt'],
            driver == DBDriver.mysql ? date : date.toIso8601String());
        expect(hosting!.getAttribute<DateTime>('cancelledAt'), date);

        hosting = await hosting.save();
        expect(hosting!.getAttribute<DateTime>('cancelledAt'), date);
      });
    });
  }
}
