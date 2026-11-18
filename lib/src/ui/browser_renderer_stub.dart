/// Server stub for the browser DOM root.
class FlintRoot {
  FlintRoot(Object? host);

  void render(Object? node) {
    throw UnsupportedError('FlintRoot is only available in the browser.');
  }
}

FlintRoot createRoot(String selector) {
  throw UnsupportedError('createRoot is only available in the browser.');
}

FlintRoot createRootForElement(Object? element) {
  throw UnsupportedError(
    'createRootForElement is only available in the browser.',
  );
}
