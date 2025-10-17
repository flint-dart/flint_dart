// lib/flint_ui/widgets/flex_row.dart

import 'package:flint_dart/src/flint_ui/core/box_style.dart';

import '../core/edge_insets.dart';
import '../core/framework.dart';

class FlintFlexRow extends FlintWidget {
  final List<FlintWidget> children;
  final List<int>? columnWidths;
  final double gap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final String? backgroundColor;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final String alignment;
  final bool mobileStack;

  FlintFlexRow({
    required this.children,
    this.columnWidths,
    this.gap = 16.0,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.alignment = 'center',
    this.mobileStack = true,
  });

  @override
  String toHtml() {
    final containerStyle = _buildContainerStyle();
    final columnsHtml = _buildColumnsHtml();

    return '''
<div style="$containerStyle">
  $columnsHtml
</div>
''';
  }

  @override
  String toText() {
    final columnTexts = children.map((child) => child.toText()).toList();
    return columnTexts.join(' | ');
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'flex_row',
      'children': children.map((child) => child.toJson()).toList(),
      'columnWidths': columnWidths,
      'gap': gap,
      'padding': padding?.toJson(),
      'margin': margin?.toJson(),
      'backgroundColor': backgroundColor,
      'border': border?.toJson(),
      'borderRadius': borderRadius?.toJson(),
      'alignment': alignment,
      'mobileStack': mobileStack,
    };
  }

  @override
  FlintWidget buildTemplate() {
    return this;
  }

  String _buildContainerStyle() {
    final styles = <String>[
      'display: flex;',
      'flex-wrap: ${mobileStack ? 'wrap' : 'nowrap'};',
      'gap: ${gap}px;',
      if (padding != null) 'padding: ${padding!.toCss()};',
      if (margin != null) 'margin: ${margin!.toCss()};',
      if (backgroundColor != null) 'background-color: $backgroundColor;',
      if (border != null) 'border: ${border!.toCss()};',
      if (borderRadius != null) 'border-radius: ${borderRadius!.toCss()};',
      'justify-content: ${_getJustifyContent()};',
      'align-items: ${_getAlignItems()};',
    ];

    return styles.join(' ');
  }

  String _buildColumnsHtml() {
    final columnWidths = _calculateColumnWidths();
    final columns = <String>[];

    for (int i = 0; i < children.length; i++) {
      final width = columnWidths[i];
      final childHtml = children[i].toHtml();

      final columnStyle = [
        'flex: 1 1 $width%;',
        'min-width: 0;', // Prevent overflow
        if (mobileStack)
          '''
          @media (max-width: 600px) {
            flex: 1 1 100% !important;
            margin-bottom: ${gap}px;
          }
        ''',
      ].join(' ');

      columns.add('''
<div style="$columnStyle">
  $childHtml
</div>
''');
    }

    return columns.join();
  }

  List<int> _calculateColumnWidths() {
    if (columnWidths != null && columnWidths!.length == children.length) {
      return columnWidths!;
    }

    // Calculate equal widths
    final equalWidth = (100 / children.length).round();
    return List.filled(children.length, equalWidth);
  }

  String _getJustifyContent() {
    switch (alignment) {
      case 'left':
        return 'flex-start';
      case 'right':
        return 'flex-end';
      case 'space-between':
        return 'space-between';
      case 'space-around':
        return 'space-around';
      default:
        return 'center';
    }
  }

  String _getAlignItems() {
    switch (alignment) {
      case 'top':
        return 'flex-start';
      case 'bottom':
        return 'flex-end';
      case 'stretch':
        return 'stretch';
      default:
        return 'center';
    }
  }
}
