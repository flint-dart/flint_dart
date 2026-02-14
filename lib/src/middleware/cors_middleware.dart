import 'package:flint_dart/flint_dart.dart';

class CorsMiddleware extends Middleware {
  final List<String> allowedOrigins;
  final List<String> allowedMethods;
  final List<String> allowedHeaders;

  CorsMiddleware({
    this.allowedOrigins = const ['*'],
    this.allowedMethods = const [
      'GET',
      'POST',
      'PUT',
      'DELETE',
      'OPTIONS',
      'PATCH'
    ],
    this.allowedHeaders = const ['Content-Type', 'Authorization'],
  });

  @override
  Handler handle(Handler next) {
    return (ctx) async {
      final res = ctx.res;
      if (res == null) {
        return await next(ctx);
      }

      final requestOrigin = ctx.req.raw.headers.value('origin');
      String? allowOrigin;

      if (allowedOrigins.contains('*')) {
        // CORS requires a single origin value, not a comma-separated list.
        allowOrigin = requestOrigin ?? '*';
      } else if (requestOrigin != null &&
          allowedOrigins.contains(requestOrigin)) {
        allowOrigin = requestOrigin;
      }

      if (allowOrigin != null) {
        res.raw.headers.add('Access-Control-Allow-Origin', allowOrigin);
        res.raw.headers.add('Vary', 'Origin');
      }

      res.raw.headers
          .add('Access-Control-Allow-Methods', allowedMethods.join(','));
      res.raw.headers
          .add('Access-Control-Allow-Headers', allowedHeaders.join(','));
      res.raw.headers.add('Access-Control-Allow-Credentials', 'true');

      // Respond to OPTIONS preflight requests immediately
      if (ctx.req.method == 'OPTIONS') {
        res.raw.statusCode = 204;
        await res.close();
        return null;
      }

      return await next(ctx);
    };
  }
}
