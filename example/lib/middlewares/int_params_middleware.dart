import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/logs.dart';

class IntParamsMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (ctx) async {
      // Add your middleware logic here
      Log.debug('IntParamsMiddleware executed');

      // Call the next middleware/handler
      return await next(ctx);
    };
  }
}
