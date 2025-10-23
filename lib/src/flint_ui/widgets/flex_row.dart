// lib/flint_ui/widgets/flex_row.dart

import 'package:flint_dart/src/flint_ui/core/box_style.dart';
import '../core/edge_insets.dart';
import '../core/flint_widget.dart';

/// A responsive horizontal layout widget that arranges its [children]
/// in a flexible row using CSS Flexbox.
///
/// The [FlintFlexRow] is part of the Flint UI framework and is designed
/// for generating responsive HTML layouts, especially in web or email contexts.
///
/// It automatically adjusts to smaller screens by stacking its children
/// vertically when [mobileStack] is enabled.
///
/// Example usage:
/// ```dart
/// FlintFlexRow(
///   gap: 12.0,
///   alignment: 'space-between',
///   backgroundColor: '#f8f9fa',
///   padding: EdgeInsets.all(16),
///   children: [
///     FlintText('Name'),
///     FlintText('Email'),
///     FlintText('Status'),
///   ],
/// )
/// ```
class FlintFlexRow extends FlintWidget {
  /// The child widgets arranged horizontally within the row.
  final List<FlintWidget> children;

  /// Optional list of column widths (percentages) for each child widget.
  ///
  /// Example: `[50, 25, 25]` means the first child takes 50% of the width,
  /// and the others take 25% each.
  ///
  /// If not provided, equal widths are automatically assigned.
  final List<int>? columnWidths;

  /// The horizontal space (in pixels) between child widgets.
  ///
  /// Defaults to `16.0`.
  final double gap;

  /// The inner padding of the row container.
  ///
  /// This adds space between the container’s content and its border.
  final EdgeInsets? padding;

  /// The outer margin of the row container.
  ///
  /// This adds space around the container relative to neighboring elements.
  final EdgeInsets? margin;

  /// The background color of the row container, represented as a CSS color string.
  ///
  /// Example: `'#ffffff'`, `'blue'`, `'rgba(0,0,0,0.1)'`, etc.
  final String? backgroundColor;

  /// The border of the row container.
  ///
  /// Use [BoxBorder] to define thickness, color, and style.
  final BoxBorder? border;

  /// The border radius of the row container, used for rounded corners.
  final BorderRadius? borderRadius;

  /// The alignment of children within the flex row.
  ///
  /// Controls both horizontal and vertical alignment using standard
  /// CSS flexbox values:
  ///
  /// - `'left'` → `justify-content: flex-start`
  /// - `'right'` → `justify-content: flex-end`
  /// - `'center'` → `justify-content: center`
  /// - `'space-between'` → `justify-content: space-between`
  /// - `'space-around'` → `justify-content: space-around`
  ///
  /// For vertical alignment:
  /// - `'top'` → `align-items: flex-start`
  /// - `'bottom'` → `align-items: flex-end`
  /// - `'stretch'` → `align-items: stretch`
  ///
  /// Defaults to `'center'`.
  final String alignment;

  /// Whether to automatically stack columns vertically on small screens.
  ///
  /// When `true`, each column becomes full width (100%) on screens smaller than 600px.
  ///
  /// Defaults to `true`.
  final bool mobileStack;

  /// Creates a [FlintFlexRow] layout widget.
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

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  /// Renders the row as an HTML `<div>` using CSS flexbox layout.
  ///
  /// Applies spacing, alignment, and responsive styling inline.
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

  /// Renders the row and its children as plain text.
  ///
  /// Each child’s text representation is separated by `" | "`.
  @override
  String toText() {
    final columnTexts = children.map((child) => child.toText()).toList();
    return columnTexts.join(' | ');
  }

  /// Converts this widget into a JSON-serializable structure.
  ///
  /// Useful for saving templates or rendering layouts dynamically.
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

  /// Returns this widget instance directly.
  ///
  /// Since [FlintFlexRow] is a final layout component, it doesn’t
  /// perform dynamic building.
  @override
  FlintWidget buildTemplate() => this;

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  /// Builds the inline CSS style for the row container.
  ///
  /// This includes flexbox properties, background, border, and spacing.
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

  /// Generates the HTML for each column in the row.
  ///
  /// Each column is wrapped in a `<div>` with its calculated width
  /// and responsive mobile behavior.
  String _buildColumnsHtml() {
    final columnWidths = _calculateColumnWidths();
    final columns = <String>[];

    for (int i = 0; i < children.length; i++) {
      final width = columnWidths[i];
      final childHtml = children[i].toHtml();

      final columnStyle = [
        'flex: 1 1 $width%;',
        'min-width: 0;', // Prevents content overflow
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

  /// Calculates each column's width percentage.
  ///
  /// If [columnWidths] are not provided, children are equally spaced.
  List<int> _calculateColumnWidths() {
    if (columnWidths != null && columnWidths!.length == children.length) {
      return columnWidths!;
    }

    final equalWidth = (100 / children.length).round();
    return List.filled(children.length, equalWidth);
  }

  /// Maps the [alignment] string to a CSS `justify-content` value.
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

  /// Maps the [alignment] string to a CSS `align-items` value.
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
