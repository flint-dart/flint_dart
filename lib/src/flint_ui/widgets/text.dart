// lib/flint_ui/core/text.dart

import 'package:flint_dart/src/flint_ui/core/framework.dart';
import 'package:flint_dart/src/flint_ui/core/style.dart';

class FlintText extends FlintWidget {
  final String data;
  final TextStyle? style;
  final TextAlign align;
  final int? maxLines;
  final TextOverflow? overflow;

  FlintText(
    this.data, {
    this.style,
    this.align = TextAlign.left,
    this.maxLines,
    this.overflow,
  });

  @override
  String toHtml() {
    final style = _buildStyle();
    final tag = _getHtmlTag();

    return '<$tag style="$style">${_escapeHtml(data)}</$tag>';
  }

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

  @override
  Map<String, dynamic> toJson() => {
        'type': 'text',
        'data': data,
        'style': style?.toJson(),
        'align': align.name,
        'maxLines': maxLines,
        'overflow': overflow?.name,
      };

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

  String _getHtmlTag() {
    if (style?.fontSize != null) {
      if (style!.fontSize! >= 24) return 'h1';
      if (style!.fontSize! >= 20) return 'h2';
      if (style!.fontSize! >= 18) return 'h3';
    }
    return 'span';
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  @override
  FlintWidget buildTemplate() {
    // For images, we return self since we're a leaf widget
    return this;
  }
}
