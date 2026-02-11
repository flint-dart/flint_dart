import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/logs.dart';

class LoggerMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (ctx) async {
      final req = ctx.req;
      Log.debug('[${req.method}] ${req.path}');
      Log.debug("${req.cookies}");
      Log.debug(req.ipAddress);
      Log.debug("is isAuthenticated ${req.isAuthenticated}");
      return await next(ctx);
    };
  }
}
