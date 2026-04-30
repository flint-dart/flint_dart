import 'package:flint_dart/flint_dart.dart';

String storagePath(String file) => 'storage/$file';

String publicPath(String file) => 'public/$file';

String url(String path) => '${env('APP_URL')}/$path';

String assets(String src) => url(src);

dynamic env(String key, [dynamic defaultValue]) =>
    FlintEnv.get(key, defaultValue);

// String trans(String key, {Map<String, dynamic>? args, String? locale}) =>
//     Localization().trans(key, args, locale);
// void setLocale(String locale) => Localization().setLocale(locale);
// bool isLocale(String locale) => Localization().isLocale(locale);

void abort(int code, String message) {
  // throw HttpResponseException(message: message, code: code);
}

Future<void> setSession(String key, dynamic value) async {}

Future<dynamic> getSession(String key) async {
  return;
}

Future<Map<String, dynamic>?> allSessions() async {
  return null;
}

Future<void> deleteSession(String key) async {}

Future<void> destroyAllSessions() async {}
