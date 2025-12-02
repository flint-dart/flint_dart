// import 'package:flint_dart/flint_dart.dart';
// import 'package:flint_dart/src/session/cookie.dart';

// final _cookiesExpando = Expando<Map<String, String>>('_RequestCookies');
// final _sessionExpando = Expando<Map<String, dynamic>>('_RequestSession');

// extension RequestCookieExt on Request {
//   Map<String, String> get cookies {
//     return _cookiesExpando[this] ??= <String, String>{};
//   }

//   set cookies(Map<String, String> value) {
//     _cookiesExpando[this] = value;
//   }

//   Map<String, dynamic> get session {
//     return _sessionExpando[this] ??= <String, dynamic>{};
//   }

//   set session(Map<String, dynamic> value) {
//     _sessionExpando[this] = value;
//   }

//   void parseCookies() {
//     final header = headers['cookie'] ?? '';
//     cookies = Cookie.parse(header);
//   }
// }
