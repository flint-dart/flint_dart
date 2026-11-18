import 'dart:convert';

import 'package:flint_dart/flint_dart.dart';
import 'package:test/test.dart';

void main() {
  test('query contracts round-trip through JSON', () {
    final query = FlintDbQuery(
      select: const ['id', 'status', 'total'],
      filter: FlintDbLogicalFilter(
        FlintDbLogicalOperator.and,
        const [
          FlintDbComparison('status', FlintDbOperator.eq, 'Ready'),
          FlintDbComparison('total', FlintDbOperator.gte, 1000),
        ],
      ),
      order: const [FlintDbOrder('created_at', descending: true)],
      limit: 20,
    );

    final encoded = jsonDecode(jsonEncode(query.toJson()));
    final decoded = FlintDbQuery.fromJson(
      Map<String, dynamic>.from(encoded as Map),
    );

    expect(decoded.toJson(), query.toJson());
  });

  test('unknown operators are rejected', () {
    expect(
      () => FlintDbQuery.fromJson({
        'filter': {
          'field': 'status',
          'operator': 'rawSql',
          'value': '1 = 1',
        },
      }),
      throwsFormatException,
    );
  });

  test('result contracts preserve structured errors', () {
    const result = FlintDbResult<List<Object?>>.failure(
      FlintDbError(
        code: FlintDbErrorCode.permissionDenied,
        message: 'Denied.',
      ),
      FlintDbMeta(requestId: 'req_1'),
    );

    final decoded = FlintDbResult<List<Object?>>.fromJson(
      result.toJson((data) => data),
      (data) => List<Object?>.from(data as List? ?? const []),
    );

    expect(decoded.isSuccess, isFalse);
    expect(decoded.error?.code, FlintDbErrorCode.permissionDenied);
    expect(decoded.meta.requestId, 'req_1');
  });
}
