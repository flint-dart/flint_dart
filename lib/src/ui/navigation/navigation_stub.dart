class BrowserNavigation {
  const BrowserNavigation();

  String get currentUrl => '';
  String get currentPath => '';
  String get currentQuery => '';
  String get currentHash => '';
  Uri get currentUri => Uri();

  void navigate(String url, {Object? state}) {}
  void replace(String url, {Object? state}) {}
  void assign(String url) {}
  void redirect(String url) {}
  void back() {}
  void forward() {}
  void go(int delta) {}
  void reload() {}
}

const navigation = BrowserNavigation();

String get currentUrl => navigation.currentUrl;
String get currentPath => navigation.currentPath;
String get currentQuery => navigation.currentQuery;
String get currentHash => navigation.currentHash;
Uri get currentUri => navigation.currentUri;

void navigate(String url, {Object? state}) {
  navigation.navigate(url, state: state);
}

void replace(String url, {Object? state}) {
  navigation.replace(url, state: state);
}

void back() {
  navigation.back();
}

void forward() {
  navigation.forward();
}

void go(int delta) {
  navigation.go(delta);
}

void reload() {
  navigation.reload();
}
