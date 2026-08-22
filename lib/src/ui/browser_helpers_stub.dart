/// A selected browser file normalized for Flint UI app code.
class FlintSelectedFile {
  const FlintSelectedFile({
    required this.name,
    required this.mimeType,
    required this.size,
    required this.base64,
  });

  /// File name reported by the browser.
  final String name;

  /// Browser-reported MIME type.
  final String mimeType;

  /// File size in bytes.
  final int size;

  /// Base64 file contents without a data URL prefix.
  final String base64;

  /// Whether the selected file is an image.
  bool get isImage => mimeType.toLowerCase().startsWith('image/');

  /// Whether the selected file is a video.
  bool get isVideo => mimeType.toLowerCase().startsWith('video/');
}

/// Browser event helpers used by Flint UI apps.
class FlintEvent {
  const FlintEvent._();

  /// Returns the value from an input/select-like event target.
  static String value(Object? event) => '';

  /// Returns checked state from a checkbox-like event target.
  static bool checked(Object? event) => false;

  /// Returns HTML content from a contenteditable-like event target.
  static String html(Object? event) => '';

  /// Stops the default browser action when running in the browser.
  static void preventDefault(Object? event) {}

  /// Stops event propagation when running in the browser.
  static void stopPropagation(Object? event) {}

  /// Returns selected files from a file input event.
  static Future<List<FlintSelectedFile>> files(Object? event) async => const [];
}

/// Rich text editing helpers for contenteditable areas.
class FlintRichText {
  const FlintRichText._();

  /// Executes a browser rich text command.
  static bool command(String command, [String value = '']) => false;

  /// Applies a block format such as h2, p, or blockquote.
  static bool formatBlock(String value) => false;

  /// Inserts trusted HTML at the current browser selection.
  static bool insertHtml(String html) => false;
}
