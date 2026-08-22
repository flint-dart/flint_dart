import 'dart:async';

import 'package:flint_dart/flint_dart.dart';

import '../auth/flint_db_auth.dart';

typedef FlintDbRequestAuthorizer = FutureOr<bool> Function(Context context);

class FlintDatabaseApiConfig {
  FlintDatabaseApiConfig({
    this.basePath = '/db/v1',
    this.defaultDeny = true,
    this.maxPageSize = 100,
    this.maxSelectedFields = 50,
    this.maxFilterComparisons = 25,
    this.maxLogicalDepth = 5,
    this.authorizer,
    this.auth = const FlintDbAuth.disabled(),
  })  : assert(basePath.startsWith('/')),
        assert(maxPageSize > 0),
        assert(maxSelectedFields > 0),
        assert(maxFilterComparisons > 0),
        assert(maxLogicalDepth > 0);

  final String basePath;
  final bool defaultDeny;
  final int maxPageSize;
  final int maxSelectedFields;
  final int maxFilterComparisons;
  final int maxLogicalDepth;

  /// Authorizes DB API routes. A missing authorizer denies access.
  final FlintDbRequestAuthorizer? authorizer;
  final FlintDbAuth auth;
}
