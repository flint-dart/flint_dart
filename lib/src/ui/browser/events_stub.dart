typedef FlintBrowserEvent = Object;

/// A browser file selected from a Flint UI file input.
class FlintSelectedFile {
  const FlintSelectedFile({
    required this.name,
    required this.mimeType,
    required this.size,
    required this.dataUrl,
    required this.base64,
  });

  final String name;
  final String mimeType;
  final int size;
  final String dataUrl;
  final String base64;

  bool get isImage => mimeType.toLowerCase().startsWith('image/');

  bool get isVideo => mimeType.toLowerCase().startsWith('video/');
}

/// Browser event helpers exposed by Flint UI.
///
/// The VM/server stub keeps shared UI code analyzable without requiring browser
/// DOM types.
class FlintEvent {
  const FlintEvent._();

  static bool isBrowserEvent(Object? event) => false;

  static void preventDefault(Object? event) {}

  static void stopPropagation(Object? event) {}

  static Object? target(Object? event) => null;

  static String value(Object? event) => '';

  static String html(Object? event) => '';

  static String text(Object? event) => '';

  static bool checked(Object? event) => false;

  static Future<List<FlintSelectedFile>> files(Object? event) async => const [];

  static Future<FlintSelectedFile?> firstFile(Object? event) async => null;
}

/// Browser rich text helpers for contenteditable editors.
class FlintRichText {
  const FlintRichText._();

  static bool command(String command, [String value = '']) => false;

  static bool insertHtml(String html) => false;

  static bool formatBlock(String tagName) => false;
}

bool isFlintBrowserEvent(Object? event) => false;

void flintPreventDefault(Object? event) {
  FlintEvent.preventDefault(event);
}

void flintStopPropagation(Object? event) {
  FlintEvent.stopPropagation(event);
}

Object? flintEventTarget(Object? event) => FlintEvent.target(event);

String flintEventTargetValue(Object? event) => FlintEvent.value(event);

bool flintEventTargetChecked(Object? event) => FlintEvent.checked(event);
