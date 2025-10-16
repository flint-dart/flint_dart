// lib/flint_ui/widgets/row.dart

import 'package:flint_dart/src/flint_ui/core/core.dart';

class FlintRow extends FlintWidget {
  final List<FlintWidget> children;
  final List<int> columnWidths;
  final double gap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final String? backgroundColor;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final String alignment;

  FlintRow({
    required this.children,
    this.columnWidths = const [],
    this.gap = 16.0,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.alignment = 'center',
  });

  @override
  String toHtml() {
    final rowStyle = _buildRowStyle();
    final columnsHtml = _buildColumnsHtml();

    return '''
<div style="$rowStyle">
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
      'type': 'row',
      'children': children.map((child) => child.toJson()).toList(),
      'columnWidths': columnWidths,
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

  String _buildRowStyle() {
    final styles = <String>[
      'display: table;',
      'width: 100%;',
      'border-collapse: separate;',
      'border-spacing: ${gap}px;',
      if (padding != null) 'padding: ${padding!.toCss()};',
      if (margin != null) 'margin: ${margin!.toCss()};',
      if (backgroundColor != null) 'background-color: $backgroundColor;',
      if (border != null) 'border: ${border!.toCss()};',
      if (borderRadius != null) 'border-radius: ${borderRadius!.toCss()};',
    ];

    return styles.join(' ');
  }

  String _buildColumnsHtml() {
    final columnWidths = _calculateColumnWidths();
    final columns = <String>[];

    for (int i = 0; i < children.length; i++) {
      final width = columnWidths[i];
      final childHtml = children[i].toHtml();

      columns.add('''
<td style="
  display: table-cell; 
  width: $width%; 
  vertical-align: top;
  padding: 0;
">
  $childHtml
</td>
''');
    }

    return '''
<table style="width: 100%; border-collapse: collapse;">
  <tr>
    ${columns.join()}
  </tr>
</table>
''';
  }

  List<int> _calculateColumnWidths() {
    if (columnWidths.isNotEmpty && columnWidths.length == children.length) {
      return columnWidths;
    }

    // Calculate equal widths
    final equalWidth = (100 / children.length).round();
    return List.filled(children.length, equalWidth);
  }
}
