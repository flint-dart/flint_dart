import 'package:flint_dart/src/flint_ui/core/core.dart';

/// A layout widget that arranges its [children] horizontally in a flexible row.
///
/// The [FlintRow] widget is inspired by Flutter’s `Row`, but it generates
/// HTML table-based layouts optimized for consistent email and web rendering.
///
/// It automatically divides space equally among children (unless custom
/// [columnWidths] are provided), supports padding, margin, gaps, borders,
/// and background colors.
///
/// Example:
/// ```dart
/// FlintRow(
///   gap: 12,
///   backgroundColor: "#f9f9f9",
///   padding: EdgeInsets.all(16),
///   children: [
///     FlintText("Name"),
///     FlintText("Email"),
///     FlintText("Phone"),
///   ],
/// );
/// ```
class FlintRow extends FlintWidget {
  /// The list of widgets to display horizontally.
  ///
  /// Each widget is rendered in a separate `<td>` element.
  final List<FlintWidget> children;

  /// Specifies the width (in percentage) of each column.
  ///
  /// If not provided or if the number of entries doesn’t match [children.length],
  /// all columns are evenly divided.
  ///
  /// Example: `[40, 30, 30]` makes three columns with 40%, 30%, and 30% widths.
  final List<int> columnWidths;

  /// The space (in pixels) between each column.
  final double gap;

  /// The internal padding around the entire row container.
  final EdgeInsets? padding;

  /// The external margin around the entire row container.
  final EdgeInsets? margin;

  /// The background color of the row container.
  final String? backgroundColor;

  /// Optional border around the row container.
  final BoxBorder? border;

  /// Optional border radius applied to the container.
  final BorderRadius? borderRadius;

  /// The vertical alignment of the content inside each cell.
  ///
  /// Accepts values such as `'top'`, `'center'`, or `'bottom'`.
  final String alignment;

  /// Creates a new [FlintRow] widget for horizontal layout.
  ///
  /// By default, children share equal widths, and spacing between them
  /// is controlled via [gap].
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

  /// Converts this row and its children into HTML.
  ///
  /// Uses `<div>` and `<table>` tags to ensure consistent rendering
  /// across email clients and browsers.
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

  /// Converts the row to a plain text representation.
  ///
  /// Each child is separated by a vertical bar `" | "`.
  @override
  String toText() {
    final columnTexts = children.map((child) => child.toText()).toList();
    return columnTexts.join(' | ');
  }

  /// Converts the row and its layout properties to a JSON map.
  ///
  /// Useful for serializing Flint UI widgets into APIs or visual editors.
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

  /// Returns the same instance since [FlintRow] is not composed dynamically.
  @override
  FlintWidget buildTemplate() => this;

  /// Builds inline CSS styles for the outer `<div>` row container.
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

  /// Builds the inner HTML structure for each column in the row.
  ///
  /// Uses a table layout to ensure equal width alignment and cross-client
  /// email compatibility.
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
  vertical-align: $alignment;
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

  /// Calculates column widths based on [columnWidths] or divides equally.
  ///
  /// If custom widths are not provided or invalid, all columns get equal share.
  List<int> _calculateColumnWidths() {
    if (columnWidths.isNotEmpty && columnWidths.length == children.length) {
      return columnWidths;
    }

    // Calculate equal widths
    final equalWidth = (100 / children.length).round();
    return List.filled(children.length, equalWidth);
  }
}
