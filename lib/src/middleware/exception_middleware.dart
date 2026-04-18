import 'package:flint_dart/flint_dart.dart';

import 'package:mysql_dart/exception.dart';
import 'package:postgres/postgres.dart';
import 'dart:async';

class ExceptionMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (ctx) async {
      final res = ctx.res;
      try {
        return await next(ctx);
      } on ValidationException catch (e) {
        if (res == null) rethrow;
        return res.json({"status": false, "errors": e.errors}, status: e.code);
      } on FormatException catch (e) {
        if (res == null) rethrow;
        return res.json({"status": false, "message": e.message}, status: 500);
      } on TimeoutException catch (e) {
        if (res == null) rethrow;
        return res.json({"status": false, "message": e.message}, status: 500);
      } on ArgumentError catch (e) {
        if (res == null) rethrow;
        return res.json({"status": false, "message": e.message}, status: 500);
      } on PgException catch (e) {
        final msg = e.message.toLowerCase();

        if (msg.contains('does not exist') || msg.contains('42703')) {
          Log.debug('ℹ️ Ignoring internal column check error: $msg');
          return await next(ctx);
        }

        if (res == null) rethrow;
        return res.json({"status": false, "message": e.message}, status: 500);
      } on MySQLClientException catch (e) {
        final msg = e.message.toLowerCase();

        if (msg.contains('unknown column') ||
            msg.contains('does not exist') ||
            msg.contains('42703')) {
          Log.debug('ℹ️ Ignoring internal column check error: $msg');
          return await next(ctx);
        }

        if (res == null) rethrow;
        return res.json({"status": false, "message": e.message}, status: 500);
      } on MySQLException catch (e) {
        final msg = e.message.toLowerCase();

        if (msg.contains('unknown column') ||
            msg.contains('does not exist') ||
            msg.contains('42703')) {
          Log.debug('ℹ️ Ignoring internal column check error: $msg');
          return await next(ctx);
        }

        if (res == null) rethrow;
        return res.json({"status": false, "message": e.message}, status: 500);
      } on ForbiddenException catch (e) {
        if (res == null) rethrow;
        return res.json({"status": false, "message": e.message}, status: 500);
      } on AuthException catch (e) {
        if (res == null) rethrow;
        return res.json(
          {
            "status": false,
            "error": "Unauthorized",
            "message": e.message,
          },
          status: 401,
        );
      } on BaseException catch (e) {
        if (res == null) rethrow;
        return res.json(
          {
            "status": false,
            "message": e.message,
          },
          status: e.code,
        );
      } on Exception catch (e) {
        final msg = e.toString().toLowerCase();

        if (msg.contains('unknown column') ||
            msg.contains('does not exist') ||
            msg.contains('42703')) {
          Log.debug('ℹ️ Ignoring internal column check error: $msg');
          return await next(ctx);
        }

        if (res == null) rethrow;
        return res.json(
          {
            "status": false,
            "message":
                e.toString().replaceAll("Exception:", "").trim().toString(),
          },
          status: 500,
        );
      } catch (e, stack) {
        Log.debug('[Flint] Unhandled error: $e\n$stack');
        if (res == null) rethrow;
        return res
            .json({"status": false, "message": e.toString()}, status: 500);
      }
    };
  }
}
