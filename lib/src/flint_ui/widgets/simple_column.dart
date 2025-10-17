// lib/flint_ui/widgets/simple_column.dart

import '../core/core.dart';

class FlintSimpleColumn extends FlintWidget {
  final List<FlintWidget> children;
  final double gap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final String? backgroundColor;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final String alignment;

  FlintSimpleColumn({
    required this.children,
    this.gap = 16.0,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.alignment = 'left',
  });

  @override
  String toHtml() {
    final containerStyle = _buildContainerStyle();
    final childrenHtml = _buildChildrenHtml();

    return '''
<div style="$containerStyle">
  $childrenHtml
</div>
''';
  }

  @override
  String toText() {
    return children.map((child) => child.toText()).join('\n\n');
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'simple_column',
      'children': children.map((child) => child.toJson()).toList(),
      'gap': gap,
      'padding': padding?.toJson(),
      'margin': margin?.toJson(),
      'backgroundColor': backgroundColor,
      'border': border?.toJson(),
      'borderRadius': borderRadius?.toJson(),
      'alignment': alignment,
    };
  }

  @override
  FlintWidget buildTemplate() {
    return this;
  }

  String _buildContainerStyle() {
    final styles = <String>[
      'display: block;',
      if (padding != null) 'padding: ${padding!.toCss()};',
      if (margin != null) 'margin: ${margin!.toCss()};',
      if (backgroundColor != null) 'background-color: $backgroundColor;',
      if (border != null) 'border: ${border!.toCss()};',
      if (borderRadius != null) 'border-radius: ${borderRadius!.toCss()};',
      'text-align: ${_getTextAlign()};',
    ];

    return styles.join(' ');
  }

  String _buildChildrenHtml() {
    final childrenHtml = children.map((child) {
      final childHtml = child.toHtml();
      return '''
<div style="margin-bottom: ${gap}px;">
  $childHtml
</div>
''';
    }).toList();

    // Remove margin from last child
    if (childrenHtml.isNotEmpty) {
      final lastIndex = childrenHtml.length - 1;
      childrenHtml[lastIndex] = childrenHtml[lastIndex]
          .replaceAll('margin-bottom: ${gap}px;', 'margin-bottom: 0;');
    }

    return childrenHtml.join('');
  }

  String _getTextAlign() {
    switch (alignment) {
      case 'left':
        return 'left';
      case 'right':
        return 'right';
      case 'center':
        return 'center';
      default:
        return 'left';
    }
  }
}
