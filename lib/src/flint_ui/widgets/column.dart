// lib/flint_ui/widgets/column.dart

import '../core/core.dart';

class FlintColumn extends FlintWidget {
  final List<FlintWidget> children;
  final double gap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final String? backgroundColor;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final Alignment alignment;
  final bool reverse;

  FlintColumn({
    required this.children,
    this.gap = 8.0,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.alignment = Alignment.left,
    this.reverse = false,
  });

  @override
  String toHtml() {
    final columnStyle = _buildColumnStyle();
    final childrenHtml = _buildChildrenHtml();

    return '''
<div style="$columnStyle">
  $childrenHtml
</div>
''';
  }

  @override
  String toText() {
    final childrenText = children.map((child) => child.toText()).toList();
    if (reverse) {
      childrenText.reversed;
    }
    return childrenText.join('\n\n');
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'column',
      'children': children.map((child) => child.toJson()).toList(),
      'gap': gap,
      'padding': padding?.toJson(),
      'margin': margin?.toJson(),
      'backgroundColor': backgroundColor,
      'border': border?.toJson(),
      'borderRadius': borderRadius?.toJson(),
      'alignment':
          alignment.name, // Convert to string name instead of enum instance
      'reverse': reverse,
    };
  }

  @override
  FlintWidget buildTemplate() {
    return this;
  }

  String _buildColumnStyle() {
    final styles = <String>[
      'display: flex;',
      'flex-direction: column;',
      'gap: ${gap}px;',
      if (padding != null) 'padding: ${padding!.toCss()};',
      if (margin != null) 'margin: ${margin!.toCss()};',
      if (backgroundColor != null) 'background-color: $backgroundColor;',
      if (border != null) 'border: ${border!.toCss()};',
      if (borderRadius != null) 'border-radius: ${borderRadius!.toCss()};',
      'align-items: ${alignment.cssValue};', // Use the cssValue directly
    ];

    return styles.join(' ');
  }

  String _buildChildrenHtml() {
    final items = reverse ? children.reversed.toList() : children;
    return items.map((child) => child.toHtml()).join('');
  }
}

enum Alignment {
  left('flex-start'),
  right('flex-end'),
  center('center'),
  stretch('stretch');

  final String cssValue;
  const Alignment(this.cssValue);

  // Add name property for JSON serialization
  String get name {
    switch (this) {
      case Alignment.left:
        return 'left';
      case Alignment.right:
        return 'right';
      case Alignment.center:
        return 'center';
      case Alignment.stretch:
        return 'stretch';
    }
  }
}
