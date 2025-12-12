// File: lib/src/middleware.dart

import 'dart:async';

import 'package:flint_dart/src/error/forbidden_exception.dart';
import 'package:flint_dart/src/request.dart';
import 'package:flint_dart/src/response.dart';
import 'package:flint_dart/src/validation/validator.dart';
import 'package:mysql_dart/exception.dart';
import 'package:postgres/postgres.dart';

import '../router.dart';

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
        return res.json({"status": false, "message": e.message}, status: 500);
      } on TimeoutException catch (e) {
        return res.json({"status": false, "message": e.message}, status: 500);
      } on ArgumentError catch (e) {
        return res.json({"status": false, "message": e.message}, status: 500);
      } on PgException catch (e) {
        final msg = e.message.toLowerCase();

        if (msg.contains('does not exist') || msg.contains('42703')) {
          print('ℹ️ Ignoring internal column check error: $msg');
          return await next(req, res);
        }

        return res.json({"status": false, "message": e.message}, status: 500);
      } on MySQLClientException catch (e) {
        final msg = e.message.toLowerCase();

        if (msg.contains('unknown column') ||
            msg.contains('does not exist') ||
            msg.contains('42703')) {
          print('ℹ️ Ignoring internal column check error: $msg');
          return await next(req, res);
        }

        return res.json({"status": false, "message": e.message}, status: 500);
      } on MySQLException catch (e) {
        final msg = e.message.toLowerCase();

        if (msg.contains('unknown column') ||
            msg.contains('does not exist') ||
            msg.contains('42703')) {
          print('ℹ️ Ignoring internal column check error: $msg');
          return await next(req, res);
        }

        return res.json({"status": false, "message": e.message}, status: 500);
      } on ForbiddenErorr catch (e) {
        return res.json({"status": false, "message": e.message}, status: 500);
      } on Exception catch (e) {
        final msg = e.toString().toLowerCase();

        if (msg.contains('unknown column') ||
            msg.contains('does not exist') ||
            msg.contains('42703')) {
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
        return res
            .json({"status": false, "message": e.toString()}, status: 500);
      }
    };
  }
}

class LoggerMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (req, res) async {
      print('[${req.method}] ${req.path}');
      print(req.cookies);
      print(req.ipAddress);
      print("is isAuthenticated ${req.isAuthenticated}");
      return await next(req, res);
    };
  }
}

///
/// 🍪 Cookie Middleware (Cleaner)
///
/// - NO cookie parsing logic here
/// - Request already has built-in cookie parser
/// - This middleware is only useful if you want future features
///
class CookieMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Request req, Response res) async {
      // Built-in cookie parsing already done in Request
      // req.cookies is already ready to use
      return await next(req, res);
    };
  }
}

///
/// 🟦 Session Middleware (Fixed + Clean)
///
/// Uses built-in:
///    - req.cookies
///    - res.setCookie()
///    - req.session
///    - sessionStore
///import 'dart:async';

// class FlintSessionMiddleware extends Middleware {
//   String _generateSessionId() {
//     final rand = Random.secure();
//     final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
//     return base64UrlEncode(bytes);
//   }

//   @override
//   Handler handle(Handler next) {
//     return (Request req, Response res) async {
//       // 1. Get existing session ID from cookie
//       String? sessionId = req.sessionId;

//       // 2. If no valid session exists, create one
//       if (sessionId == null || !_sessionStore.containsKey(sessionId)) {
//         sessionId = _generateSessionId();

//         // Set cookie
//         res.raw.cookies.add(
//           Cookie('FLINTSESSID', sessionId)
//             ..path = '/'
//             ..httpOnly = true
//             ..secure = false, // change to true in production
//         );

//         // Create session
//         _sessionStore[sessionId] = {};
//       }

//       // 3. Attach session to request
//       req.session = _sessionStore[sessionId];

//       // 4. Execute the handler (routes / controllers)
//       final result = await next(req, res);

//       // 5. Save any updated session values
//       if (req.session != null) {
//         _sessionStore[sessionId] = req.session!;
//       }

//       return result;
//     };
//   }
// }
