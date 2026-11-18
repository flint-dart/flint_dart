import 'package:universal_web/web.dart' as web;

/// Dart-friendly access to the browser document used by Flint UI apps.
///
/// This keeps common document/root reads in Flint UI code instead of requiring
/// app code to import `universal_web` for small browser tasks.
class FlintDocument {
  const FlintDocument();

  /// The underlying browser `document`.
  web.Document get raw => web.document;

  /// The browser document root, equivalent to JavaScript
  /// `document.documentElement`.
  web.Element? get documentElement => web.document.documentElement;

  /// The document `<head>` element.
  web.HTMLHeadElement? get head => web.document.head;

  /// The document `<body>` element.
  web.HTMLElement? get body => web.document.body;

  /// The current document title.
  String get title => web.document.title;

  set title(String value) {
    web.document.title = value;
  }

  /// Finds the first element matching [selector].
  web.Element? querySelector(String selector) {
    return web.document.querySelector(selector);
  }

  /// Finds an element by id.
  web.Element? getElementById(String id) {
    return web.document.getElementById(id);
  }

  /// Root scroll width, equivalent to
  /// `document.documentElement.scrollWidth`.
  int get scrollWidth => documentElement?.scrollWidth ?? 0;

  /// Root scroll height, equivalent to
  /// `document.documentElement.scrollHeight`.
  int get scrollHeight => documentElement?.scrollHeight ?? 0;

  /// Root client width, equivalent to
  /// `document.documentElement.clientWidth`.
  int get clientWidth => documentElement?.clientWidth ?? 0;

  /// Root client height, equivalent to
  /// `document.documentElement.clientHeight`.
  int get clientHeight => documentElement?.clientHeight ?? 0;

  /// Whether the document root is horizontally wider than its viewport box.
  bool get hasHorizontalOverflow => scrollWidth > clientWidth;
}

/// Shared browser document helper for Flint UI apps.
const flintDocument = FlintDocument();
