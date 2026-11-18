import 'dart:io';

import 'package:flint_dart/src/context.dart';
import 'package:flint_dart/src/response.dart';

import 'middleware.dart';

enum CacheScope { public, private, noStore, revalidate }

class CacheMiddleware extends Middleware {
  CacheMiddleware({
    required this.scope,
    this.maxAge,
    this.sharedMaxAge,
    this.immutable = false,
    this.mustRevalidate = false,
  });

  factory CacheMiddleware.public(
    Duration maxAge, {
    Duration? sharedMaxAge,
    bool immutable = false,
    bool mustRevalidate = false,
  }) {
    return CacheMiddleware(
      scope: CacheScope.public,
      maxAge: maxAge,
      sharedMaxAge: sharedMaxAge,
      immutable: immutable,
      mustRevalidate: mustRevalidate,
    );
  }

  factory CacheMiddleware.private(
    Duration maxAge, {
    bool mustRevalidate = false,
  }) {
    return CacheMiddleware(
      scope: CacheScope.private,
      maxAge: maxAge,
      mustRevalidate: mustRevalidate,
    );
  }

  factory CacheMiddleware.noStore() {
    return CacheMiddleware(scope: CacheScope.noStore);
  }

  factory CacheMiddleware.revalidate() {
    return CacheMiddleware(scope: CacheScope.revalidate);
  }

  final CacheScope scope;
  final Duration? maxAge;
  final Duration? sharedMaxAge;
  final bool immutable;
  final bool mustRevalidate;

  @override
  Handler handle(Handler next) {
    return (ctx) async {
      final res = ctx.res;
      if (res != null && _supportsCacheHeaders(ctx.req.method)) {
        apply(res);
      }
      return await next(ctx);
    };
  }

  void apply(Response res) {
    switch (scope) {
      case CacheScope.public:
        res.cachePublic(
          maxAge ?? Duration.zero,
          sharedMaxAge: sharedMaxAge,
          immutable: immutable,
          mustRevalidate: mustRevalidate,
        );
        break;
      case CacheScope.private:
        res.cachePrivate(
          maxAge ?? Duration.zero,
          mustRevalidate: mustRevalidate,
        );
        break;
      case CacheScope.noStore:
        res.noStore();
        break;
      case CacheScope.revalidate:
        res.revalidate();
        break;
    }
  }

  static bool _supportsCacheHeaders(String method) {
    final normalized = method.toUpperCase();
    return normalized == 'GET' || normalized == 'HEAD' || normalized == 'QUERY';
  }
}

class ETagMiddleware extends Middleware {
  ETagMiddleware(this.value, {this.weak = false});

  final String Function(Context ctx) value;
  final bool weak;

  @override
  Handler handle(Handler next) {
    return (ctx) async {
      final res = ctx.res;
      if (res != null &&
          CacheMiddleware._supportsCacheHeaders(ctx.req.method)) {
        final tag = value(ctx);
        res.etag(tag, weak: weak);
        final ifNoneMatch =
            ctx.req.raw.headers.value(HttpHeaders.ifNoneMatchHeader);
        if (ifNoneMatch == res.raw.headers.value(HttpHeaders.etagHeader)) {
          res.raw.statusCode = HttpStatus.notModified;
          return res;
        }
      }
      return await next(ctx);
    };
  }
}
