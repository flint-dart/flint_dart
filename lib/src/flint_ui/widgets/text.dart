// lib/flint_ui/core/text.dart

import 'package:flint_dart/src/flint_ui/core/framework.dart';
import 'package:flint_dart/src/flint_ui/core/style.dart';

/// {@template flint_text}
/// The [FlintText] widget is a lightweight text-rendering component used within
/// the Flint UI framework. It converts styled text into HTML or plain text,
/// making it suitable for rendering in emails, web UIs, or CLI environments.
///
/// Similar to Flutter's `Text` widget, [FlintText] supports styling via [TextStyle],
/// text alignment, overflow handling, and line limitation.
///
/// Example usage:
/// ```dart
/// FlintText(
///   'Welcome to Flint Dart!',
///   style: TextStyle(
///     fontSize: 18,
///     color: '#333333',
///     fontWeight: FontWeight.bold,
///   ),
///   align: TextAlign.center,
///   overflow: TextOverflow.ellipsis,
///   maxLines: 2,
/// );
/// ```
///
/// When rendered as HTML, large font sizes automatically convert to semantic
/// headings (`<h1>`, `<h2>`, `<h3>`) based on font size thresholds.
/// {@endtemplate}
class FlintText extends FlintWidget {
  /// The text string to display.
  final String data;

  /// Optional text styling such as font size, color, or weight.
  final TextStyle? style;

  /// Alignment of the text (e.g., left, right, center, justify).
  final TextAlign align;

  /// The maximum number of lines before truncation.
  final int? maxLines;

  /// Overflow behavior (e.g., [TextOverflow.ellipsis]).
  final TextOverflow? overflow;

  /// Creates a [FlintText] widget with optional style, alignment,
  /// line limit, and overflow behavior.
  FlintText(
    this.data, {
    this.style,
    this.align = TextAlign.left,
    this.maxLines,
    this.overflow,
  });

  /// Converts this text widget into an HTML-compatible string.
  ///
  /// Automatically escapes special characters like `<`, `>`, and `&`,
  /// and applies inline CSS styles derived from [TextStyle].
  @override
  String toHtml() {
    final style = _buildStyle();
    final tag = _getHtmlTag();

    return '<$tag style="$style">${_escapeHtml(data)}</$tag>';
  }

  /// Converts the widget into plain text output.
  ///
  /// Truncates content if [maxLines] is defined and appends an ellipsis
  /// if [overflow] is set to [TextOverflow.ellipsis].
  @override
  String toText() {
    var text = data;
    if (maxLines != null) {
      final lines = text.split('\n');
      if (lines.length > maxLines!) {
        text = lines.take(maxLines!).join('\n');
        if (overflow == TextOverflow.ellipsis) {
          text += '...';
        }
      }
    }
    return text;
  }

  /// Serializes this widget into a JSON representation.
  @override
  Map<String, dynamic> toJson() => {
        'type': 'text',
        'data': data,
        'style': style?.toJson(),
        'align': align.name,
        'maxLines': maxLines,
        'overflow': overflow?.name,
      };

  /// Builds the inline CSS style string for HTML rendering.
  String _buildStyle() {
    final styles = <String>[];

    if (style != null) {
      if (style!.fontSize != null) {
        styles.add('font-size: ${style!.fontSize}px;');
      }
      if (style!.color != null) {
        styles.add('color: ${style!.color};');
      }
      if (style!.fontWeight != null) {
        styles.add('font-weight: ${style!.fontWeight!.value};');
      }
      if (style!.fontFamily != null) {
        styles.add('font-family: ${style!.fontFamily};');
      }
      if (style!.backgroundColor != null) {
        styles.add('background-color: ${style!.backgroundColor};');
      }
      if (style!.decoration != null) {
        styles.add('text-decoration: ${style!.decoration!.toCss()};');
      }
    }

    styles.add('text-align: ${align.toCss()};');
    styles.add('line-height: 1.6;');

    return styles.join(' ');
  }

  /// Determines the appropriate HTML tag for rendering text semantically.
  ///
  /// - `h1` for font sizes ≥ 24px
  /// - `h2` for font sizes ≥ 20px
  /// - `h3` for font sizes ≥ 18px
  /// - otherwise `span`
  String _getHtmlTag() {
    if (style?.fontSize != null) {
      if (style!.fontSize! >= 24) return 'h1';
      if (style!.fontSize! >= 20) return 'h2';
      if (style!.fontSize! >= 18) return 'h3';
    }
    return 'span';
  }

  /// Escapes HTML-sensitive characters to prevent rendering issues or injection.
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Returns this instance since [FlintText] is a leaf widget.
  @override
  FlintWidget buildTemplate() => this;
}
