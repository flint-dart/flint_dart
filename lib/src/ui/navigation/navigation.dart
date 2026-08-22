import 'dart:js_interop';

import 'package:universal_web/web.dart' as web;

/// Wraps browser location and history navigation for Flint UI apps.
class BrowserNavigation {
  /// Creates a browser navigation helper.
  const BrowserNavigation();

  /// The full current browser URL.
  String get currentUrl => web.window.location.href;

  /// The current browser path without query string or hash.
  String get currentPath => web.window.location.pathname;

  /// The current browser query string, including the leading `?`.
  String get currentQuery => web.window.location.search;

  /// The current browser hash, including the leading `#`.
  String get currentHash => web.window.location.hash;

  /// The current browser URL parsed as a [Uri].
  Uri get currentUri => Uri.parse(currentUrl);

  /// Pushes a new browser history entry without reloading the page.
  void navigate(String url, {Object? state}) {
    web.window.history.pushState(_toJsState(state), '', url);
    _dispatchFlintNavigation();
  }

  /// Replaces the current browser history entry without reloading the page.
  void replace(String url, {Object? state}) {
    web.window.history.replaceState(_toJsState(state), '', url);
    _dispatchFlintNavigation();
  }

  /// Loads [url] through `window.location.assign`.
  void assign(String url) {
    web.window.location.assign(url);
  }

  /// Replaces the current page with [url] through `window.location.replace`.
  void redirect(String url) {
    web.window.location.replace(url);
  }

  /// Moves one entry back in browser history.
  void back() {
    web.window.history.back();
  }

  /// Moves one entry forward in browser history.
  void forward() {
    web.window.history.forward();
  }

  /// Moves by [delta] entries in browser history.
  void go(int delta) {
    web.window.history.go(delta);
  }

  /// Reloads the current browser page.
  void reload() {
    web.window.location.reload();
  }

  JSAny? _toJsState(Object? state) {
    return state == null ? null : state.jsify();
  }

  void _dispatchFlintNavigation() {
    web.window.dispatchEvent(web.Event('flint:navigate'));
  }
}

/// Shared browser navigation helper for Flint UI apps.
const navigation = BrowserNavigation();

/// The full current browser URL.
String get currentUrl => navigation.currentUrl;

/// The current browser path without query string or hash.
String get currentPath => navigation.currentPath;

/// The current browser query string, including the leading `?`.
String get currentQuery => navigation.currentQuery;

/// The current browser hash, including the leading `#`.
String get currentHash => navigation.currentHash;

/// The current browser URL parsed as a [Uri].
Uri get currentUri => navigation.currentUri;

/// Pushes a new browser history entry without reloading the page.
void navigate(String url, {Object? state}) {
  navigation.navigate(url, state: state);
}

/// Replaces the current browser history entry without reloading the page.
void replace(String url, {Object? state}) {
  navigation.replace(url, state: state);
}

/// Moves one entry back in browser history.
void back() {
  navigation.back();
}

/// Moves one entry forward in browser history.
void forward() {
  navigation.forward();
}

/// Moves by [delta] entries in browser history.
void go(int delta) {
  navigation.go(delta);
}

/// Reloads the current browser page.
void reload() {
  navigation.reload();
}
