// lib/flint_ui/widgets/column.dart

import '../core/core.dart';

/// A layout widget that arranges its [children] vertically,
/// similar to Flutter's `Column` widget.
///
/// The [Column] is part of the Flint UI framework and is designed
/// to render flexible vertical layouts for HTML emails, web views,
/// or text-based rendering.
///
/// It supports visual spacing ([gap]), layout padding and margin,
/// background styling, border customization, and child alignment.
///
/// Example usage:
/// ```dart
/// Column(
///   padding: EdgeInsets.all(12),
///   backgroundColor: '#f5f5f5',
///   alignment: Alignment.center,
///   children: [
///     FlintText('Welcome to Flint!'),
///     FlintButton(label: 'Get Started'),
///   ],
/// )
/// ```
class Column extends FlintWidget {
  /// The widgets arranged vertically inside this column.
  final List<FlintWidget> children;

  /// The vertical space (in pixels) between child widgets.
  ///
  /// Defaults to `8.0`.
  final double gap;

  /// The internal padding of the column container.
  ///
  /// This adds space between the container's border and its content.
  final EdgeInsets? padding;

  /// The external margin of the column container.
  ///
  /// This adds space outside the container relative to neighboring elements.
  final EdgeInsets? margin;

  /// The background color of the column, represented as a CSS color string.
  ///
  /// Example: `'#ffffff'`, `'red'`, or `'rgba(0,0,0,0.1)'`.
  final String? backgroundColor;

  /// The border of the column container.
  ///
  /// Use [BoxBorder] to define border width, color, and style.
  final BoxBorder? border;

  /// The border radius (corner roundness) of the column container.
  final BorderRadius? borderRadius;

  /// The horizontal alignment of the children within the column.
  ///
  /// Maps to CSS `align-items`:
  /// - [Alignment.left] → `flex-start`
  /// - [Alignment.right] → `flex-end`
  /// - [Alignment.center] → `center`
  /// - [Alignment.stretch] → `stretch`
  final Alignment alignment;

  /// Whether to render the children in reverse order.
  ///
  /// When `true`, the last child appears first.
  final bool reverse;

  /// Creates a new [Column] widget.
  ///
  /// The [children] parameter must not be null.
  Column({
    required this.children,
    this.gap = 5.0,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.alignment = Alignment.left,
    this.reverse = false,
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

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  /// Renders the column and its children as an HTML `<div>` element.
  ///
  /// Styles are applied inline using CSS flexbox layout.
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

  /// Renders the column and its children as plain text.
  ///
  /// Each child is separated by two newlines (`\n\n`).
  @override
  String toText() {
    final childrenText = children.map((child) => child.toText()).toList();
    if (reverse) {
      childrenText.reversed;
    }
    return childrenText.join('\n\n');
  }

  /// Serializes this widget to a JSON representation.
  ///
  /// Useful for saving templates or transmitting layout definitions.
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
      'alignment': alignment.name,
      'reverse': reverse,
    };
  }

  /// Returns this column widget as the final build result.
  ///
  /// Since [Column] has no dynamic build logic, this simply returns `this`.
  @override
  FlintWidget buildTemplate() => this;

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Builds the inline CSS style for the column container.
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
      'align-items: ${alignment.cssValue};',
    ];
    return styles.join(' ');
  }

  /// Builds the combined HTML output for all children.
  String _buildChildrenHtml() {
    final items = reverse ? children.reversed.toList() : children;
    return items.map((child) => child.toHtml()).join('');
  }
}

/// Defines how child elements are horizontally aligned
/// within a [Column].
///
/// Maps directly to CSS `align-items`.
enum Alignment {
  /// Aligns children to the left (CSS: `flex-start`).
  left('flex-start'),

  /// Aligns children to the right (CSS: `flex-end`).
  right('flex-end'),

  /// Centers children horizontally (CSS: `center`).
  center('center'),

  /// Stretches children to fill available horizontal space (CSS: `stretch`).
  stretch('stretch');

  /// The corresponding CSS value for this alignment.
  final String cssValue;

  const Alignment(this.cssValue);

  /// The string name used for JSON serialization.
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
