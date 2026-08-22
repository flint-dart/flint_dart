import 'dart:async';
import 'dart:js_interop';
import 'package:universal_web/web.dart' as web;

import '../../auth/auth_session.dart';
import '../../client/client_router.dart';
import '../../component.dart';
import '../../node.dart';
import '../../style.dart';
import 'controllers.dart';
import 'field_helpers.dart';
import 'validation.dart';

/// Semantic toolbar actions supported by the rich text editor.
enum RichTextToolbarItem {
  /// Toggle bold formatting on selection.
  bold,

  /// Toggle italic formatting on selection.
  italic,

  /// Toggle underline formatting on selection.
  underline,

  /// Toggle strikethrough formatting on selection.
  strikeThrough,

  /// Formats the block as a level 1 heading.
  heading1,

  /// Formats the block as a level 2 heading.
  heading2,

  /// Formats the block as a paragraph.
  paragraph,

  /// Inserts a bulleted list.
  bulletList,

  /// Inserts a numbered list.
  orderedList,

  /// Formats the block as a blockquote.
  blockquote,

  /// Formats the block as a preformatted code block.
  codeBlock,

  /// Inserts/modifies a hyperlink.
  link,

  /// Inserts an image from local file explorer.
  image,

  /// Removes all formatting from selection.
  removeFormat,

  /// Renders a vertical line separating toolbar groups.
  divider,
}

/// A rich text WYSIWYG editor with formatting toolbar and controller support.
class RichTextEditor extends StatefulComponent {
  /// Creates a rich text editor.
  RichTextEditor({
    String? label,
    this.name,
    this.controller,
    this.initialHtml,
    this.placeholder = 'Write something...',
    this.required = false,
    this.disabled = false,
    this.error,
    this.errors,
    this.helpText,
    this.className,
    this.props = const {},
    this.editorProps = const {},
    this.style = const {},
    this.editorStyle = const {},
    this.dartStyle,
    this.editorDartStyle,
    this.height = '300px',
    this.onUploadImage,
    this.onChanged,
    this.toolbarItems = const [
      RichTextToolbarItem.bold,
      RichTextToolbarItem.italic,
      RichTextToolbarItem.underline,
      RichTextToolbarItem.strikeThrough,
      RichTextToolbarItem.divider,
      RichTextToolbarItem.heading1,
      RichTextToolbarItem.heading2,
      RichTextToolbarItem.paragraph,
      RichTextToolbarItem.divider,
      RichTextToolbarItem.bulletList,
      RichTextToolbarItem.orderedList,
      RichTextToolbarItem.blockquote,
      RichTextToolbarItem.codeBlock,
      RichTextToolbarItem.divider,
      RichTextToolbarItem.link,
      RichTextToolbarItem.image,
      RichTextToolbarItem.removeFormat,
    ],
  }) {
    _id = fieldId('editor', name, props);
  }

  /// Optional field identifier.
  final String? name;

  /// Synchronized text editing controller.
  TextEditingController? controller;

  /// Initial HTML content if controller is not provided.
  final String? initialHtml;

  /// Input placeholder when empty.
  String placeholder;

  /// Whether this field is required.
  bool required;

  /// Whether editing is disabled.
  bool disabled;

  /// Explicit validation error.
  String? error;

  /// Form validation error collection.
  FormErrors? errors;

  /// Helpful message text shown below editor.
  String? helpText;

  /// Optional class name for the wrapper element.
  String? className;

  /// Extra HTML properties for the wrapper element.
  Map<String, Object?> props;

  /// Extra HTML properties for the contenteditable element.
  Map<String, Object?> editorProps;

  /// Extra CSS style for the wrapper element.
  Map<String, Object?> style;

  /// Extra CSS style for the contenteditable element.
  Map<String, Object?> editorStyle;

  /// Typed style for the wrapper element.
  DartStyle? dartStyle;

  /// Typed style for the contenteditable element.
  DartStyle? editorDartStyle;

  /// Editor element height (e.g. '300px').
  final String height;

  /// Optional custom image upload handler.
  ///
  /// When omitted, images are automatically uploaded via [clientRouter] to
  /// `/api/content-media/upload`. If upload fails, the preview is removed.
  final Future<String> Function(web.File file)? onUploadImage;

  /// Optional content change callback.
  void Function(String html)? onChanged;

  /// Toolbar configuration list.
  final List<RichTextToolbarItem> toolbarItems;

  late final String _id;
  String get _editorId => '$_id-content';

  bool _isSyncingFromEditor = false;
  int _imgCounter = 0;

  @override
  void updateFrom(covariant RichTextEditor next) {
    placeholder = next.placeholder;
    required = next.required;
    disabled = next.disabled;
    error = next.error;
    errors = next.errors;
    helpText = next.helpText;
    className = next.className;
    props = next.props;
    editorProps = next.editorProps;
    style = next.style;
    editorStyle = next.editorStyle;
    dartStyle = next.dartStyle;
    editorDartStyle = next.editorDartStyle;
    onChanged = next.onChanged;

    if (controller != next.controller) {
      controller?.removeListener(_onControllerChanged);
      controller = next.controller;
      controller?.addListener(_onControllerChanged);
      _syncFromController();
    }
  }

  @override
  void didMount() {
    controller?.addListener(_onControllerChanged);
    _syncFromController();
    _setupListeners();
  }

  @override
  void willUnmount() {
    controller?.removeListener(_onControllerChanged);
  }

  @override
  void didUpdate() {
    final el = web.document.getElementById(_editorId) as web.HTMLElement?;
    if (el != null) {
      if (disabled) {
        el.setAttribute('contenteditable', 'false');
      } else {
        el.setAttribute('contenteditable', 'true');
      }
    }
  }

  void _syncFromController() {
    final el = web.document.getElementById(_editorId) as web.HTMLElement?;
    if (el == null) return;

    final html = controller?.text ?? initialHtml ?? '';
    if ((el.innerHTML as JSString).toDart != html) {
      el.innerHTML = html.toJS;
    }
  }

  void _syncToController() {
    final el = web.document.getElementById(_editorId) as web.HTMLElement?;
    if (el == null) return;

    final html = (el.innerHTML as JSString).toDart;
    if (controller != null && controller!.text != html) {
      _isSyncingFromEditor = true;
      try {
        controller!.text = html;
      } finally {
        _isSyncingFromEditor = false;
      }
    }
    onChanged?.call(html);
  }

  void _handleEditorInput(Object event) {
    _syncToController();
  }

  void _onControllerChanged() {
    if (_isSyncingFromEditor) return;
    _syncFromController();
  }

  void _setupListeners() {
    final el = web.document.getElementById(_editorId) as web.HTMLElement?;
    if (el == null) return;

    el.addEventListener(
      'input',
      ((web.Event event) {
        _syncToController();
      }).toJS,
    );

    el.addEventListener(
      'dragover',
      ((web.Event event) {
        event.preventDefault();
      }).toJS,
    );

    el.addEventListener(
      'drop',
      ((web.Event event) {
        final dragEvent = event as web.DragEvent;
        final files = dragEvent.dataTransfer?.files;
        if (files != null && files.length > 0) {
          dragEvent.preventDefault();
          for (var i = 0; i < files.length; i++) {
            final file = files.item(i);
            if (file != null && file.type.startsWith('image/')) {
              _processImageFile(file);
            }
          }
        }
      }).toJS,
    );

    el.addEventListener(
      'paste',
      ((web.Event event) {
        final pasteEvent = event as web.ClipboardEvent;
        final items = pasteEvent.clipboardData?.items;
        if (items != null) {
          for (var i = 0; i < items.length; i++) {
            final item = items[i];
            if (item.type.startsWith('image/')) {
              final file = item.getAsFile();
              if (file != null) {
                pasteEvent.preventDefault();
                _processImageFile(file);
              }
            }
          }
        }
      }).toJS,
    );
  }

  void _processImageFile(web.File file) {
    if (disabled) return;
    final el = web.document.getElementById(_editorId) as web.HTMLElement?;
    if (el == null) return;

    el.focus();

    final tempUrl = web.URL.createObjectURL(file);
    final imgId =
        'upload-${DateTime.now().millisecondsSinceEpoch}-${_imgCounter++}';

    final selection = web.window.getSelection();
    if (selection != null && selection.rangeCount > 0) {
      final range = selection.getRangeAt(0);
      range.deleteContents();

      final img = web.document.createElement('img') as web.HTMLImageElement;
      img.src = tempUrl;
      img.id = imgId;
      img.setAttribute('data-loading', 'true');
      img.setAttribute(
        'style',
        'max-width: 100%; height: auto; border-radius: 6px; opacity: 0.5; filter: blur(1px); transition: all 0.3s;',
      );

      range.insertNode(img);

      range.setStartAfter(img);
      range.setEndAfter(img);
      selection.removeAllRanges();
      selection.addRange(range);
    } else {
      final img = web.document.createElement('img') as web.HTMLImageElement;
      img.src = tempUrl;
      img.id = imgId;
      img.setAttribute('data-loading', 'true');
      img.setAttribute(
        'style',
        'max-width: 100%; height: auto; border-radius: 6px; opacity: 0.5; filter: blur(1px); transition: all 0.3s;',
      );
      el.appendChild(img);
    }

    _syncToController();

    Future<String> performUpload() async {
      if (onUploadImage != null) {
        return onUploadImage!(file);
      }

      final completer = Completer<String>();
      final reader = web.FileReader();
      reader.readAsDataURL(file);
      reader.onload = ((web.Event event) {
        completer.complete((reader.result as JSString).toDart);
      }).toJS;
      reader.onerror = ((web.Event event) {
        completer.completeError('Failed to read local image file');
      }).toJS;

      final base64DataUrl = await completer.future;
      final parts = base64DataUrl.split(',');
      final base64Content = parts.length > 1 ? parts[1] : parts[0];

      final token = authSession.token;
      final res = await clientRouter.post<Map<String, dynamic>>(
        '/api/content-media/upload',
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
        body: {
          'filename': file.name,
          'mime_type': file.type,
          'base64': base64Content,
          'type': 'image',
        },
      );

      final data = res.data;
      if (data == null || (data['status'] != true && data['success'] != true)) {
        throw Exception(data?['message'] ?? 'Image upload server error');
      }
      final asset = data['asset'];
      if (asset is Map) {
        return asset['url']?.toString() ?? '';
      }
      return data['url']?.toString() ?? '';
    }

    performUpload()
        .then((remoteUrl) {
          final img =
              web.document.getElementById(imgId) as web.HTMLImageElement?;
          if (img != null) {
            img.src = remoteUrl;
            img.removeAttribute('data-loading');
            img.setAttribute(
              'style',
              'max-width: 100%; height: auto; border-radius: 6px; transition: all 0.3s;',
            );
            _syncToController();
          }
          web.URL.revokeObjectURL(tempUrl);
        })
        .catchError((error) {
          final img =
              web.document.getElementById(imgId) as web.HTMLImageElement?;
          img?.remove();
          _syncToController();
          web.URL.revokeObjectURL(tempUrl);
          web.window.alert('Failed to upload image to server: $error');
        });
  }

  void _selectAndUploadImage() {
    if (disabled) return;

    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = 'image/*';

    input.addEventListener(
      'change',
      ((web.Event event) {
        final files = input.files;
        if (files != null && files.length > 0) {
          final file = files.item(0);
          if (file != null) {
            _processImageFile(file);
          }
        }
      }).toJS,
    );

    input.click();
  }

  void _execCommand(String command, [String? value]) {
    if (disabled) return;
    final el = web.document.getElementById(_editorId) as web.HTMLElement?;
    if (el == null) return;

    el.focus();
    web.document.execCommand(command, false, value ?? '');
    _syncToController();
  }

  void _insertLink() {
    if (disabled) return;
    final url = web.window.prompt(
      'Enter link URL (e.g. https://example.com):',
      'https://',
    );
    if (url != null && url.isNotEmpty) {
      _execCommand('createLink', url);
    }
  }

  @override
  View build() {
    final resolvedError = resolveFieldError(
      name: name,
      error: error,
      errors: errors,
    );
    final hasError = resolvedError != null && resolvedError.isNotEmpty;

    final toolbarNodes = <FlintNode>[];
    for (final item in toolbarItems) {
      if (item == RichTextToolbarItem.divider) {
        toolbarNodes.add(
          FlintElement(
            'div',
            props: {'className': 'flint-rich-text-editor-btn-divider'},
          ),
        );
      } else {
        toolbarNodes.add(_buildToolbarButton(item));
      }
    }

    final editorHtml = controller?.text ?? initialHtml ?? '';
    final containerClass = [
      'flint-rich-text-editor-container',
      if (hasError) 'invalid',
      if (disabled) 'disabled',
    ].join(' ');

    return FlintElement(
      'div',
      props: fieldWrapperProps(
        props: props,
        className: className,
        dartStyle: dartStyle,
        style: style,
      ),
      children: [
        if (name != null) fieldLabel(id: _id, label: name!, required: required),
        FlintElement(
          'div',
          props: {'_flintStyleCss': _cssStyles, 'className': containerClass},
          children: [
            FlintElement(
              'div',
              props: {'className': 'flint-rich-text-editor-toolbar'},
              children: toolbarNodes,
            ),
            FlintElement(
              'div',
              props: {
                ...controlProps(
                  props: editorProps,
                  id: _editorId,
                  name: name,
                  required: required,
                  disabled: disabled,
                  error: resolvedError,
                  describedBy: null,
                ),
                'contenteditable': disabled ? 'false' : 'true',
                'placeholder': placeholder,
                'className': 'flint-rich-text-editor-content',
                'onInput': _handleEditorInput,
                'onBlur': _handleEditorInput,
                'style': {
                  'height': height,
                  'min-height': '150px',
                  ...editorStyle,
                },
              },
              children: [if (editorHtml.isNotEmpty) FlintRawHtml(editorHtml)],
            ),
          ],
        ),
        ...fieldMessages(id: _id, helpText: helpText, error: resolvedError),
      ],
    );
  }

  FlintNode _buildToolbarButton(RichTextToolbarItem item) {
    final (label, action, title) = switch (item) {
      RichTextToolbarItem.bold => ('B', () => _execCommand('bold'), 'Bold'),
      RichTextToolbarItem.italic => (
        'I',
        () => _execCommand('italic'),
        'Italic',
      ),
      RichTextToolbarItem.underline => (
        'U',
        () => _execCommand('underline'),
        'Underline',
      ),
      RichTextToolbarItem.strikeThrough => (
        'S',
        () => _execCommand('strikeThrough'),
        'Strikethrough',
      ),
      RichTextToolbarItem.heading1 => (
        'H1',
        () => _execCommand('formatBlock', '<h1>'),
        'Heading 1',
      ),
      RichTextToolbarItem.heading2 => (
        'H2',
        () => _execCommand('formatBlock', '<h2>'),
        'Heading 2',
      ),
      RichTextToolbarItem.paragraph => (
        'P',
        () => _execCommand('formatBlock', '<p>'),
        'Paragraph',
      ),
      RichTextToolbarItem.bulletList => (
        '• List',
        () => _execCommand('insertUnorderedList'),
        'Unordered List',
      ),
      RichTextToolbarItem.orderedList => (
        '1. List',
        () => _execCommand('insertOrderedList'),
        'Ordered List',
      ),
      RichTextToolbarItem.blockquote => (
        '“ Quote',
        () => _execCommand('formatBlock', '<blockquote>'),
        'Blockquote',
      ),
      RichTextToolbarItem.codeBlock => (
        '{ } Code',
        () => _execCommand('formatBlock', '<pre>'),
        'Code Block',
      ),
      RichTextToolbarItem.link => ('Link', () => _insertLink(), 'Insert Link'),
      RichTextToolbarItem.image => (
        'Image',
        () => _selectAndUploadImage(),
        'Insert Image',
      ),
      RichTextToolbarItem.removeFormat => (
        'Clear',
        () => _execCommand('removeFormat'),
        'Clear Formatting',
      ),
      _ => ('', () {}, ''),
    };

    final isTextStyled =
        item == RichTextToolbarItem.bold ||
        item == RichTextToolbarItem.italic ||
        item == RichTextToolbarItem.underline ||
        item == RichTextToolbarItem.strikeThrough;

    final buttonStyle = switch (item) {
      RichTextToolbarItem.bold => 'font-weight: bold;',
      RichTextToolbarItem.italic => 'font-style: italic;',
      RichTextToolbarItem.underline => 'text-decoration: underline;',
      RichTextToolbarItem.strikeThrough => 'text-decoration: line-through;',
      _ => '',
    };

    return FlintElement(
      'button',
      props: {
        'type': 'button',
        'title': title,
        'className': 'flint-rich-text-editor-btn',
        'onMousedown': (web.Event event) {
          event.preventDefault();
        },
        'onClick': (web.Event event) {
          action();
        },
      },
      children: [
        if (isTextStyled)
          FlintElement(
            'span',
            props: {'style': buttonStyle},
            children: [FlintText(label)],
          )
        else
          FlintText(label),
      ],
    );
  }

  static const String _cssStyles = '''
    .flint-rich-text-editor-container {
      display: flex;
      flex-direction: column;
      border: 1px solid #d0d5dd;
      border-radius: 8px;
      background: #ffffff;
      overflow: hidden;
      transition: border-color 0.15s ease, box-shadow 0.15s ease;
    }
    .flint-rich-text-editor-container:focus-within {
      border-color: #0b6f69;
      box-shadow: 0 0 0 3px rgba(11, 111, 105, 0.2);
    }
    .flint-rich-text-editor-container.invalid {
      border-color: #d92d20;
      box-shadow: 0 0 0 3px rgba(217, 45, 32, 0.2);
    }
    .flint-rich-text-editor-container.disabled {
      background: #f3f4f6;
      cursor: not-allowed;
    }
    .flint-rich-text-editor-toolbar {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 6px;
      padding: 6px 10px;
      background: #f9fafb;
      border-bottom: 1px solid #e4e7ec;
      user-select: none;
    }
    .flint-rich-text-editor-btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 2px 6px;
      height: 28px;
      border: 1px solid transparent;
      border-radius: 4px;
      background: transparent;
      color: #475569;
      font-size: 13px;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.1s ease;
    }
    .flint-rich-text-editor-btn:hover {
      background: #f1f5f9;
      color: #0f172a;
    }
    .flint-rich-text-editor-btn:active {
      background: #e2e8f0;
      color: #0f172a;
    }
    .flint-rich-text-editor-btn-divider {
      width: 1px;
      height: 18px;
      background: #cbd5e1;
      margin: 0 4px;
    }
    .flint-rich-text-editor-content {
      padding: 12px;
      outline: none;
      overflow-y: auto;
      font-family: inherit;
      font-size: 14px;
      line-height: 1.6;
      color: #101828;
    }
    .flint-rich-text-editor-content[contenteditable="true"]:empty::before {
      content: attr(placeholder);
      color: #9ca3af;
      pointer-events: none;
      display: block;
    }
    .flint-rich-text-editor-content p {
      margin: 0 0 1em 0;
    }
    .flint-rich-text-editor-content blockquote {
      border-left: 4px solid #cbd5e1;
      padding-left: 12px;
      margin: 0 0 1em 0;
      color: #475569;
      font-style: italic;
    }
    .flint-rich-text-editor-content pre {
      background: #f1f5f9;
      padding: 8px 12px;
      border-radius: 6px;
      font-family: monospace;
      margin: 0 0 1em 0;
      overflow-x: auto;
    }
    .flint-rich-text-editor-content img {
      max-width: 100%;
      height: auto;
      border-radius: 6px;
      margin: 8px 0;
      display: block;
    }
  ''';
}
