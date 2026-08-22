import 'package:universal_web/web.dart' as web;

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

  /// Inserts an image.
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
  final Future<String> Function(web.File file)? onUploadImage;

  /// Optional content change callback.
  void Function(String html)? onChanged;

  /// Toolbar configuration list.
  final List<RichTextToolbarItem> toolbarItems;

  late final String _id;

  @override
  void updateFrom(covariant RichTextEditor next) {}

  @override
  View build() {
    final resolvedError = resolveFieldError(
      name: name,
      error: error,
      errors: errors,
    );
    final editorHtml = controller?.text ?? initialHtml ?? '';

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
        toolbarNodes.add(
          FlintElement(
            'button',
            props: {
              'type': 'button',
              'className': 'flint-rich-text-editor-btn',
            },
            children: [FlintText(item.name)],
          ),
        );
      }
    }

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
          props: {'className': 'flint-rich-text-editor-container'},
          children: [
            FlintElement(
              'div',
              props: {'className': 'flint-rich-text-editor-toolbar'},
              children: toolbarNodes,
            ),
            FlintElement(
              'div',
              props: {
                'id': '$_id-content',
                'contenteditable': disabled ? 'false' : 'true',
                'placeholder': placeholder,
                'className': 'flint-rich-text-editor-content',
                'onInput': (_) {},
                'onBlur': (_) {},
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
}
