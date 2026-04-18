import 'package:flint_dart/flint_dart.dart';

/// ================= Middleware Example =================
class CookieSessionMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (ctx) async {
      final res = ctx.res;
      if (res != null) {
        CookieService.init(ctx.req, res);
        SessionService.init(ctx.req, res);
      }
      return await next(ctx);
    };
  }
}
