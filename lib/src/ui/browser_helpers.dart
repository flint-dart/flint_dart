import 'dart:async';
import 'dart:js_interop';

import 'package:universal_web/web.dart' as web;

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
  static String value(Object? event) {
    final target = _target(event);
    if (target is web.HTMLInputElement) return target.value;
    if (target is web.HTMLSelectElement) return target.value;
    if (target is web.HTMLTextAreaElement) return target.value;
    return '';
  }

  /// Returns checked state from a checkbox-like event target.
  static bool checked(Object? event) {
    final target = _target(event);
    if (target is web.HTMLInputElement) return target.checked;
    return false;
  }

  /// Returns HTML content from a contenteditable-like event target.
  static String html(Object? event) {
    final target = _target(event);
    if (target is web.Element) return (target.innerHTML as JSString).toDart;
    return '';
  }

  /// Stops the default browser action when running in the browser.
  static void preventDefault(Object? event) {
    if (event is web.Event) event.preventDefault();
  }

  /// Stops event propagation when running in the browser.
  static void stopPropagation(Object? event) {
    if (event is web.Event) event.stopPropagation();
  }

  /// Returns selected files from a file input event.
  static Future<List<FlintSelectedFile>> files(Object? event) async {
    final target = _target(event);
    final fileList = target is web.HTMLInputElement ? target.files : null;
    if (fileList == null || fileList.length == 0) return const [];

    final selected = <FlintSelectedFile>[];
    for (var i = 0; i < fileList.length; i += 1) {
      final file = fileList.item(i);
      if (file == null) continue;
      selected.add(
        FlintSelectedFile(
          name: file.name,
          mimeType: file.type,
          size: file.size,
          base64: await _readBase64(file),
        ),
      );
    }
    return selected;
  }

  static Object? _target(Object? event) {
    if (event is web.Event) return event.target;
    return null;
  }
}

/// Rich text editing helpers for contenteditable areas.
class FlintRichText {
  const FlintRichText._();

  /// Executes a browser rich text command.
  static bool command(String command, [String value = '']) {
    return web.document.execCommand(command, false, value);
  }

  /// Applies a block format such as h2, p, or blockquote.
  static bool formatBlock(String value) {
    return command('formatBlock', value);
  }

  /// Inserts trusted HTML at the current browser selection.
  static bool insertHtml(String html) {
    return command('insertHTML', html);
  }
}

Future<String> _readBase64(web.File file) {
  final completer = Completer<String>();
  final reader = web.FileReader();

  reader.addEventListener(
    'loadend',
    ((web.Event _) {
      final result = reader.result;
      if (result == null) {
        completer.complete('');
        return;
      }

      final dataUrl = (result as JSString).toDart;
      final comma = dataUrl.indexOf(',');
      completer.complete(comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl);
    }).toJS,
  );
  reader.addEventListener(
    'error',
    ((web.Event _) {
      completer.completeError(reader.error ?? StateError('File read failed'));
    }).toJS,
  );
  reader.readAsDataURL(file);

  return completer.future;
}
