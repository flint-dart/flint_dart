import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/src/session/cookie_service.dart';
import 'package:flint_dart/src/session/session_service.dart';

/// ================= Middleware Example =================
class CookieSessionMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (
      Request req,
      Response res,
    ) async {
      CookieService.init(req, res);
      SessionService.init(req, res);
      return await next(req, res);
    };
  }
}
