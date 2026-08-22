import 'package:flint_dart/db_api.dart';
import 'package:test/test.dart';

void main() {
  test('configuration defaults are deny-first and bounded', () {
    final config = FlintDatabaseApiConfig();

    expect(config.defaultDeny, isTrue);
    expect(config.basePath, '/db/v1');
    expect(config.maxPageSize, 100);
    expect(config.authorizer, isNull);
  });
}
