// lib/flint_ui/core/box.dart

import 'package:flint_dart/src/flint_ui/core/box_style.dart';
import 'package:flint_dart/src/flint_ui/core/edge_insets.dart';
import 'package:flint_dart/src/flint_ui/core/framework.dart';

class FlintBox extends FlintContainer {
  final BoxConstraints? constraints;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final String? backgroundColor;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final BoxShadow? shadow;
  final BoxAlignment alignment;
  final BoxDecoration? decoration;

  FlintBox({
    required super.children,
    this.constraints,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.shadow,
    this.alignment = BoxAlignment.start,
    this.decoration,
  });

  @override
  String toHtml() {
    final style = _buildBoxStyle();
    final attributes = _buildHtmlAttributes();

    return '''
<div$attributes style="$style">
  ${_renderChildren()}
</div>
''';
  }

  @override
  String toText() {
    final content = children.map((child) => child.toText()).join('\n');
    if (backgroundColor != null || border != null) {
      return '┌${'─' * 40}┐\n$content\n└${'─' * 40}┘';
    }
    return content;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'box',
        'children': children.map((child) => child.toJson()).toList(),
        'constraints': constraints?.toJson(),
        'padding': padding?.toJson(),
        'margin': margin?.toJson(),
        'backgroundColor': backgroundColor,
        'border': border?.toJson(),
        'borderRadius': borderRadius?.toJson(),
        'shadow': shadow?.toJson(),
        'alignment': alignment.name,
        'decoration': decoration?.toJson(),
      };

  String _buildBoxStyle() {
    final styles = <String>[];

    // Layout
    if (constraints != null) {
      if (constraints!.maxWidth != double.infinity) {
        styles.add('max-width: ${constraints!.maxWidth}px;');
      }
      if (constraints!.minWidth != null) {
        styles.add('min-width: ${constraints!.minWidth}px;');
      }
      if (constraints!.maxHeight != double.infinity) {
        styles.add('max-height: ${constraints!.maxHeight}px;');
      }
    }

    // Spacing
    if (padding != null) styles.add('padding: ${padding!.toCss()};');
    if (margin != null) styles.add('margin: ${margin!.toCss()};');

    // Background & Border
    if (backgroundColor != null) {
      styles.add('background-color: $backgroundColor;');
    }

    if (border != null) {
      styles.add('border: ${border!.toCss()};');
    }

    if (borderRadius != null) {
      styles.add('border-radius: ${borderRadius!.toCss()};');
    }

    // Shadow
    if (shadow != null) {
      styles.add('box-shadow: ${shadow!.toCss()};');
    }

    // Alignment
    styles.add('text-align: ${alignment.toCss()};');

    // Box model
    styles.addAll([
      'box-sizing: border-box;',
      'display: block;',
    ]);

    return styles.join(' ');
  }

  String _buildHtmlAttributes() {
    final attrs = <String>[];

    if (decoration?.semanticLabel != null) {
      attrs.add(' aria-label="${_escapeHtml(decoration!.semanticLabel!)}"');
    }

    return attrs.join();
  }

  String _renderChildren() {
    if (children.isEmpty) return '';

    final childContent = children.map((child) => child.toHtml()).join();

    // Apply alignment wrapper if needed
    if (alignment == BoxAlignment.center) {
      return '''
<div style="display: flex; justify-content: center; align-items: center;">
  $childContent
</div>
''';
    } else if (alignment == BoxAlignment.end) {
      return '''
<div style="display: flex; justify-content: flex-end; align-items: center;">
  $childContent
</div>
''';
    }

    return childContent;
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  @override
  FlintWidget buildTemplate() {
    // For images, we return self since we're a leaf widget
    return this;
  }
}
