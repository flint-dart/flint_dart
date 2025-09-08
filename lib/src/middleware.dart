// File: lib/src/middleware.dart
import 'package:flint_dart/src/request.dart';
import 'package:flint_dart/src/response.dart';
import 'package:flint_dart/src/validation/validator.dart';

import 'router.dart';

abstract class Middleware {
  Handler handle(Handler next);
}

class ExceptionMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Request req, Response res) async {
      try {
        return await next(req, res);
      } on ValidationException catch (e) {
        return res.json({"status": false, "errors": e.errors}, status: 400);
      } catch (e, stack) {
        print('[Flint] Unhandled error: $e\n$stack');
        return res.json(
          {"status": false, "message": e.toString()},
          status: 500,
        );
      }
    };
  }
}

class LoggerMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (req, res) async {
      print('[${req.method}] ${req.path}');
      return await next(req, res);
    };
  }
}
