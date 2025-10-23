import 'package:flint_dart/src/flint_ui/core/flint_widget.dart';
import 'package:flint_dart/src/flint_ui/core/style.dart';

/// A widget that allows rendering of rich, styled inline text spans.
///
/// Similar to Flutter's [RichText], but built for Flint UI’s multi-render system
/// (HTML, text, and JSON). This widget is useful for composing formatted
/// text blocks with mixed styles, links, or emphasis in email templates,
/// web components, and text-based outputs.
class FlintRichText extends FlintWidget {
  /// A list of text spans that define the formatted content.
  final List<FlintTextSpan> children;

  /// The horizontal alignment of the entire text block.
  final TextAlign align;

  /// Creates a rich text widget with one or more [FlintTextSpan]s.
  ///
  /// Example:
  /// ```dart
  /// FlintRichText(
  ///   align: TextAlign.center,
  ///   children: [
  ///     FlintTextSpan("Welcome to ", style: TextStyle(fontSize: 16)),
  ///     FlintTextSpan("Flint Dart", style: TextStyle(fontWeight: FontWeight.bold)),
  ///   ],
  /// )
  /// ```
  FlintRichText({
    required this.children,
    this.align = TextAlign.left,
  });

  /// Converts the rich text and all its spans into an HTML representation.
  ///
  /// Each [FlintTextSpan] is rendered as a `<span>` or `<a>` tag depending
  /// on whether it has a link (`onTap` property). The alignment is applied
  /// via inline CSS.
  @override
  String toHtml() {
    final style =
        'text-align: ${align.toCss()}; line-height: 1.6; display: block;';
    return '''
<div style="$style">
  ${children.map((span) => span.toHtml()).join()}
</div>
''';
  }

  /// Converts the rich text to a plain text version for environments that
  /// do not support HTML (e.g., console output or text-only emails).
  ///
  /// Links are appended in parentheses.
  @override
  String toText() => children.map((span) => span.toText()).join();

  /// Serializes the rich text widget into a JSON-compatible map, useful
  /// for dynamic rendering or API output.
  @override
  Map<String, dynamic> toJson() => {
        'type': 'rich_text',
        'children': children.map((child) => child.toJson()).toList(),
        'align': align.name,
      };

  /// For rich text, returns the current widget since it's a leaf renderer.
  @override
  FlintWidget buildTemplate() => this;
}

/// Represents a single inline text segment within [FlintRichText].
///
/// A span can have its own text style and optional link action ([onTap]).
class FlintTextSpan {
  /// The raw text content for this span.
  final String text;

  /// The text style applied to this span (color, weight, decoration, etc.).
  final TextStyle? style;

  /// Optional link or callback target. If set, the span renders as an `<a>` tag.
  final String? onTap;

  /// Creates a styled span of text with optional link handling.
  ///
  /// Example:
  /// ```dart
  /// FlintTextSpan(
  ///   "Click here",
  ///   onTap: "https://flintdart.eulogia.net",
  ///   style: TextStyle(color: "#007BFF", decoration: TextDecoration.underline),
  /// )
  /// ```
  FlintTextSpan(this.text, {this.style, this.onTap});

  /// Converts the span to HTML. If [onTap] is set, wraps text in an `<a>` tag.
  ///
  /// Example:
  /// ```html
  /// <a href="https://example.com" style="color: #007BFF;">Click here</a>
  /// ```
  String toHtml() {
    final styleAttr = _buildStyle();
    if (onTap != null) {
      return '<a href="$onTap" style="$styleAttr">${_escapeHtml(text)}</a>';
    }
    return '<span style="$styleAttr">${_escapeHtml(text)}</span>';
  }

  /// Converts the span to plain text format.
  ///
  /// Links are shown as text followed by the URL:
  /// `"Click here (https://example.com)"`
  String toText() => onTap != null ? '$text ($onTap)' : text;

  /// Converts the span and its properties into a serializable JSON map.
  Map<String, dynamic> toJson() => {
        'text': text,
        'style': style?.toJson(),
        'onTap': onTap,
      };

  /// Builds the inline CSS style string from [TextStyle] and link properties.
  String _buildStyle() {
    final styles = <String>[];

    if (style != null) {
      if (style!.fontSize != null) {
        styles.add('font-size: ${style!.fontSize}px;');
      }
      if (style!.color != null) styles.add('color: ${style!.color};');
      if (style!.fontWeight != null) {
        styles.add('font-weight: ${style!.fontWeight!.value};');
      }
      if (style!.decoration != null) {
        styles.add('text-decoration: ${style!.decoration!.toCss()};');
      }
      if (style!.backgroundColor != null) {
        styles.add('background-color: ${style!.backgroundColor};');
      }
    }

    if (onTap != null) {
      styles.add('cursor: pointer;');
      styles.add('color: #007BFF; text-decoration: underline;');
    }

    return styles.join(' ');
  }

  /// Escapes HTML special characters to ensure text renders safely in browsers.
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Creates a copy of this [FlintTextSpan] with optional property overrides.
  FlintTextSpan copyWith({String? text, TextStyle? style, String? onTap}) {
    return FlintTextSpan(
      text ?? this.text,
      style: style ?? this.style,
      onTap: onTap ?? this.onTap,
    );
  }
}
