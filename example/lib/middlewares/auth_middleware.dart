import 'package:flint_dart/flint_dart.dart';

class AuthMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final res = ctx.res;
      if (res == null) {
        return await next(ctx);
      }

      final token = ctx.req.bearerToken;
      if (token == null || token != "expected_token") {
        return res.status(401).send("Unauthorized");
      }

      return await next(ctx);
    };
  }
}
