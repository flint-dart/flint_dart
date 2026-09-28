import 'package:flint_dart/flint_dart.dart';

class LoggerMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (ctx) async {
      final req = ctx.req;
      final stopwatch = Stopwatch()..start();

      try {
        return await next(ctx);
      } finally {
        stopwatch.stop();
        final status = ctx.res?.statusCode.toString() ?? 'socket';
        Log.info(
          '${req.method} ${req.path} status=$status '
          'duration=${stopwatch.elapsedMilliseconds}ms '
          'ip=${req.clientIpAddress}',
          tag: 'request',
        );
      }
    };
  }
}
