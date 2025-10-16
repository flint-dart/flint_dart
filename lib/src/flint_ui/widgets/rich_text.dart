// lib/flint_ui/widgets/rich_text.dart

import 'package:flint_dart/src/flint_ui/core/framework.dart';
import 'package:flint_dart/src/flint_ui/core/style.dart';

class FlintRichText extends FlintWidget {
  final List<FlintTextSpan> children;
  final TextAlign align;

  FlintRichText({required this.children, this.align = TextAlign.left});

  @override
  String toHtml() {
    final style = 'text-align: ${align.toCss()}; line-height: 1.6;';
    return '''
<div style="$style">
  ${children.map((span) => span.toHtml()).join()}
</div>
''';
  }

  @override
  String toText() => children.map((span) => span.toText()).join();

  @override
  Map<String, dynamic> toJson() => {
        'type': 'rich_text',
        'children': children.map((child) => child.toJson()).toList(),
        'align': align.name,
      };

  @override
  FlintWidget buildTemplate() {
    // For images, we return self since we're a leaf widget
    return this;
  }
}

class FlintTextSpan {
  final String text;
  final TextStyle? style;
  final String? onTap;

  FlintTextSpan(this.text, {this.style, this.onTap});

  String toHtml() {
    final style = _buildStyle();
    final tag = onTap != null ? 'a href="$onTap"' : 'span';
    return '<$tag style="$style">${_escapeHtml(text)}</${tag.split(' ').first}>';
  }

  String toText() => onTap != null ? '$text ($onTap)' : text;

  Map<String, dynamic> toJson() => {
        'text': text,
        'style': style?.toJson(),
        'onTap': onTap,
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
      if (style!.decoration != null) {
        styles.add('text-decoration: ${style!.decoration!.toCss()};');
      }
      if (style!.backgroundColor != null) {
        styles.add('background-color: ${style!.backgroundColor};');
      }
    }

    if (onTap != null) {
      styles.add('cursor: pointer;');
    }

    return styles.join(' ');
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
