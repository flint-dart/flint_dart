import 'package:universal_web/web.dart' as web;

import 'web_storage_backend.dart';

class LocalStorage extends WebStorageBackend {
  const LocalStorage();

  @override
  web.Storage get storage => web.window.localStorage;
}

const localStorage = LocalStorage();
