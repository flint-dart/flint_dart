// File: lib/src/middleware.dart

import '../routing/router.dart';

abstract class Middleware {
  Handler handle(Handler next);
}
