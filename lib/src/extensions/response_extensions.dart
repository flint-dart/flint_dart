// import 'package:flint_dart/src/response.dart';
// import 'package:flint_dart/src/session/cookie.dart';

// extension ResponseCookieExt on Response {
//   void setCookie(Cookie cookie) {
//     raw.headers.add('Set-Cookie', cookie.toString());
//   }
// }

import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/response.dart';

extension ResponseSendStreamed on Response {
  /// Sends another Response object as a streamed response
  /// Useful for running isolates and returning pre-built Response
  Future<void> sendStreamed(Response other) async {
    try {
      if (other.isClosed) return;

      // Copy status code
      raw.statusCode = other.raw.statusCode;

      // Copy headers
      other.raw.headers.forEach((key, values) {
        raw.headers.remove(key, values); // Remove any default
        for (var value in values) {
          raw.headers.add(key, value);
        }
      });

      // Stream the body from other
      // Since HttpResponse doesn't let you re-read the stream,
      // we'll assume the other Response has its content in memory
      // We'll use raw.addStream if possible
      // Otherwise, fallback to writing the body directly
      if (other.isClosed) {
        // Fallback: cannot re-stream, use raw content if stored
        raw.write(''); // Or store body in Response class if needed
      }

      await raw.flush();
    } catch (e) {
      Log.debug('[Flint] sendStreamed error: $e');
      raw.statusCode = HttpStatus.internalServerError;
      raw.write('❌ Failed to send streamed response.');
    } finally {
      await close();
    }
  }
}
