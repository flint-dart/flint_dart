// lib/flint_ui/core/box.dart

import 'package:flint_dart/src/flint_ui/core/box_style.dart';
import 'package:flint_dart/src/flint_ui/core/edge_insets.dart';
import 'package:flint_dart/src/flint_ui/core/flint_widget.dart';

class Container extends FlintWidget {
  final BoxConstraints? constraints;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final String? backgroundColor;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final BoxShadow? shadow;
  final BoxAlignment alignment;
  final BoxDecoration? decoration;
  final List<FlintWidget> children;

  Container({
    required this.children,
    this.constraints,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.shadow,
    this.alignment = BoxAlignment.start,
    this.decoration,
    super.xData,
    super.xInit,
    super.xShow,
    super.xBind,
    super.xOn,
    super.xText,
    super.xHtml,
    super.xModel,
    super.xModelable,
    super.xFor,
    super.xTransition,
    super.xEffect,
    super.xIgnore,
    super.xRef,
    super.xCloak,
    super.xTeleport,
    super.xIf,
    super.xId,
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

    // Flint directives
    final dir = directives.entries
        .map((e) => e.value.isEmpty ? e.key : '${e.key}="${e.value}"')
        .join(' ');
    if (dir.isNotEmpty) attrs.add(dir);

    // Semantic label from decoration
    if (decoration?.semanticLabel != null) {
      attrs.add('aria-label="${_escapeHtml(decoration!.semanticLabel!)}"');
    }

    return attrs.isNotEmpty ? ' ${attrs.join(' ')}' : '';
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
