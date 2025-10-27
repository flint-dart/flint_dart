import 'package:flint_dart/flint_dart.dart';

class IntParamsMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Request req, Response res) async {
      // Add your middleware logic here
      print('IntParamsMiddleware executed');

      // Call the next middleware/handler
      return await next(req, res);
    };
  }
}
