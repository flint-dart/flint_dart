// File: lib/src/middleware.dart

import '../context.dart';

abstract class Middleware {
  Handler handle(Handler next);
}
