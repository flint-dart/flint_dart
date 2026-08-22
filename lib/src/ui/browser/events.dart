import 'dart:async';
import 'dart:js_interop';

import 'package:universal_web/web.dart' as web;

typedef FlintBrowserEvent = web.Event;

@JS('document.execCommand')
external bool _documentExecCommand(
  JSString command,
  JSBoolean showUi,
  JSString value,
);

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
/// App code can use this class from `package:flint_ui/flint_ui.dart` instead
/// of importing `universal_web/web.dart` to read values or stop events.
class FlintEvent {
  const FlintEvent._();

  static bool isBrowserEvent(Object? event) => event is web.Event;

  static void preventDefault(Object? event) {
    if (event is web.Event) event.preventDefault();
  }

  static void stopPropagation(Object? event) {
    if (event is web.Event) event.stopPropagation();
  }

  static Object? target(Object? event) {
    if (event is web.Event) return event.target;
    return null;
  }

  static String value(Object? event) {
    final target = FlintEvent.target(event);
    if (target is web.HTMLInputElement) return target.value;
    if (target is web.HTMLTextAreaElement) return target.value;
    if (target is web.HTMLSelectElement) return target.value;
    return '';
  }

  static String html(Object? event) {
    final target = FlintEvent.target(event);
    if (target is web.Element) return (target.innerHTML as JSString).toDart;
    return '';
  }

  static String text(Object? event) {
    final target = FlintEvent.target(event);
    if (target is web.Element) return target.textContent ?? '';
    return value(event);
  }

  static bool checked(Object? event) {
    final target = FlintEvent.target(event);
    if (target is web.HTMLInputElement) return target.checked;
    return false;
  }

  static Future<List<FlintSelectedFile>> files(Object? event) async {
    final target = FlintEvent.target(event);
    if (target is! web.HTMLInputElement || target.files == null) {
      return const [];
    }

    final selected = <FlintSelectedFile>[];
    final files = target.files!;
    for (var i = 0; i < files.length; i++) {
      final file = files.item(i);
      if (file == null) continue;
      final dataUrl = await _readFileAsDataUrl(file);
      final commaIndex = dataUrl.indexOf(',');
      selected.add(
        FlintSelectedFile(
          name: file.name,
          mimeType: file.type,
          size: file.size,
          dataUrl: dataUrl,
          base64: commaIndex >= 0 ? dataUrl.substring(commaIndex + 1) : dataUrl,
        ),
      );
    }
    return selected;
  }

  static Future<FlintSelectedFile?> firstFile(Object? event) async {
    final selected = await files(event);
    return selected.isEmpty ? null : selected.first;
  }

  static Future<String> _readFileAsDataUrl(web.File file) {
    final completer = Completer<String>();
    final reader = web.FileReader();
    reader.onload = ((web.Event _) {
      final result = reader.result;
      completer.complete(result == null ? '' : (result as JSString).toDart);
    }).toJS;
    reader.onerror = ((web.Event _) {
      completer.completeError(StateError('Unable to read selected file.'));
    }).toJS;
    reader.readAsDataURL(file);
    return completer.future;
  }
}

/// Browser rich text helpers for contenteditable editors.
class FlintRichText {
  const FlintRichText._();

  static bool command(String command, [String value = '']) {
    return _documentExecCommand(command.toJS, false.toJS, value.toJS);
  }

  static bool insertHtml(String html) => command('insertHTML', html);

  static bool formatBlock(String tagName) => command('formatBlock', tagName);
}

bool isFlintBrowserEvent(Object? event) => event is web.Event;

void flintPreventDefault(Object? event) {
  FlintEvent.preventDefault(event);
}

void flintStopPropagation(Object? event) {
  FlintEvent.stopPropagation(event);
}

Object? flintEventTarget(Object? event) {
  return FlintEvent.target(event);
}

String flintEventTargetValue(Object? event) {
  return FlintEvent.value(event);
}

bool flintEventTargetChecked(Object? event) {
  return FlintEvent.checked(event);
}
