// File: lib/src/middleware.dart
import 'dart:async';

import 'package:flint_dart/src/error/forbidden_exception.dart';
import 'package:flint_dart/src/request.dart';
import 'package:flint_dart/src/response.dart';
import 'package:flint_dart/src/validation/validator.dart';
import 'package:mysql_dart/exception.dart';
import 'package:postgres/postgres.dart';

import 'router.dart';

abstract class Middleware {
  Handler handle(Handler next);
}

class ExceptionMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Request req, Response res) async {
      try {
        return await next(req, res);
      } on ValidationException catch (e) {
        return res.json({"status": false, "errors": e.errors}, status: 400);
      } on FormatException catch (e) {
        return res.json(
          {
            "status": false,
            "message": e.message,
          },
          status: 500,
        );
      } on TimeoutException catch (e) {
        return res.json(
          {
            "status": false,
            "message": e.message,
          },
          status: 500,
        );
      } on ArgumentError catch (e) {
        return res.json(
          {
            "status": false,
            "message": e.message,
          },
          status: 500,
        );
      } on PgException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('does not exist') || msg.contains('42703')) {
          // Ignore silent internal checks
          print('ℹ️ Ignoring internal column check error: $msg');
          return await next(req, res);
        }
        return res.json(
          {
            "status": false,
            "message": e.message,
          },
          status: 500,
        );
      } on MySQLClientException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('unknown column') ||
            msg.contains('does not exist') ||
            msg.contains('42703')) {
          // Ignore silent internal checks
          print('ℹ️ Ignoring internal column check error: $msg');
          return await next(req, res);
        }
        return res.json(
          {
            "status": false,
            "message": e.message,
          },
          status: 500,
        );
      } on MySQLException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('unknown column') ||
            msg.contains('does not exist') ||
            msg.contains('42703')) {
          // Ignore silent internal checks
          print('ℹ️ Ignoring internal column check error: $msg');
          return await next(req, res);
        }
        return res.json(
          {
            "status": false,
            "message": e.message,
          },
          status: 500,
        );
      } on ForbiddenErorr catch (e) {
        return res.json(
          {
            "status": false,
            "message": e.message,
          },
          status: 500,
        );
      } on Exception catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('unknown column') ||
            msg.contains('does not exist') ||
            msg.contains('42703')) {
          // Ignore silent internal checks
          print('ℹ️ Ignoring internal column check error: $msg');
          return await next(req, res);
        }
        return res.json(
          {
            "status": false,
            "message":
                e.toString().replaceAll("Exception:", "").trim().toString(),
          },
          status: 500,
        );
      } catch (e, stack) {
        print('[Flint] Unhandled error: $e\n$stack');
        return res.json(
          {
            "status": false,
            "message": e.toString(),
          },
          status: 500,
        );
      }
    };
  }
}

class LoggerMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (req, res) async {
      print('[${req.method}] ${req.path}');
      return await next(req, res);
    };
  }
}
