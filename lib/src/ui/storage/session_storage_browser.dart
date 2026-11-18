import 'package:universal_web/web.dart' as web;

import 'web_storage_backend.dart';

class SessionStorage extends WebStorageBackend {
  const SessionStorage();

  @override
  web.Storage get storage => web.window.sessionStorage;
}

const sessionStorage = SessionStorage();
