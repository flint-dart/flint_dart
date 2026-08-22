import 'package:universal_web/web.dart' as web;

import 'browser_storage.dart';

abstract class WebStorageBackend extends BrowserStorage {
  const WebStorageBackend();

  web.Storage get storage;

  @override
  String? read(String key) => storage.getItem(key);

  @override
  void write(String key, String value) {
    storage.setItem(key, value);
  }

  @override
  String? remove(String key) {
    final value = read(key);
    storage.removeItem(key);
    return value;
  }

  @override
  void clear() {
    storage.clear();
  }
}
