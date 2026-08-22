import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// CSS grid container with strongly typed template and alignment controls.
class Grid extends FlintElement {
  /// Creates a grid around child content.
  ///
  /// - [columns] sets the CSS `grid-template-columns`. Accepts integer column counts
  ///   (e.g. `3`), [GridTemplateColumns] instances (e.g. `GridCols.fit(250)`),
  ///   or CSS string values.
  /// - [sm], [md], [lg], [xl] define responsive breakpoint overrides (accepts
  ///   integers like `1`, `2`, `3` or [GridTemplateColumns]).
  /// - [rows] sets the CSS `grid-template-rows` template.
  /// - [gap] sets the CSS `gap` spacing between grid items (accepts numbers like `20` or `'20px'`).
  /// - [alignItems] sets the CSS `align-items` grid container alignment.
  /// - [justifyItems] sets the CSS `justify-items` grid container alignment.
  Grid({
    Object? child,
    List<Object?> children = const [],
    Object? columns,
    Object? sm,
    Object? md,
    Object? lg,
    Object? xl,
    Object? rows,
    Object? gap,
    String? alignItems,
    String? justifyItems,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'div',
         props: mergeComponentProps(
           props,
           className: className,
           defaultStyle: {
             'display': 'grid',
             if (columns != null)
               'grid-template-columns': _coerceGridColumns(columns),
             if (rows != null) 'grid-template-rows': cssValue(rows),
             if (gap != null) 'gap': cssValue(gap),
             if (alignItems != null) 'align-items': alignItems,
             if (justifyItems != null) 'justify-items': justifyItems,
           },
           dartStyle: DartStyle(
             sm: sm == null
                 ? null
                 : DartStyle(gridTemplateColumns: _coerceGridColumns(sm)),
             md: md == null
                 ? null
                 : DartStyle(gridTemplateColumns: _coerceGridColumns(md)),
             lg: lg == null
                 ? null
                 : DartStyle(gridTemplateColumns: _coerceGridColumns(lg)),
             xl: xl == null
                 ? null
                 : DartStyle(gridTemplateColumns: _coerceGridColumns(xl)),
           ).merge(dartStyle),
           style: style,
         ),
         children: normalizeChildren(child, children),
       );

  /// Creates an equal-column grid (e.g. `Grid.count(3, sm: 1, md: 2, gap: 20, children: [...])`).
  factory Grid.count(
    int count, {
    Object? child,
    List<Object?> children = const [],
    Object? sm,
    Object? md,
    Object? lg,
    Object? xl,
    Object? gap,
    String? alignItems,
    String? justifyItems,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) {
    return Grid(
      child: child,
      children: children,
      columns: GridCols.count(count),
      sm: sm,
      md: md,
      lg: lg,
      xl: xl,
      gap: gap,
      alignItems: alignItems,
      justifyItems: justifyItems,
      className: className,
      props: props,
      style: style,
      dartStyle: dartStyle,
    );
  }

  /// Creates a responsive auto-fitting grid (e.g. `Grid.fit(250, gap: 20, children: [...])`).
  factory Grid.fit(
    Object minWidth, {
    Object? child,
    List<Object?> children = const [],
    Object? sm,
    Object? md,
    Object? lg,
    Object? xl,
    Object? gap,
    String? alignItems,
    String? justifyItems,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) {
    return Grid(
      child: child,
      children: children,
      columns: GridCols.fit(minWidth),
      sm: sm,
      md: md,
      lg: lg,
      xl: xl,
      gap: gap,
      alignItems: alignItems,
      justifyItems: justifyItems,
      className: className,
      props: props,
      style: style,
      dartStyle: dartStyle,
    );
  }

  /// Creates a responsive auto-filling grid (e.g. `Grid.fill(200, gap: 16, children: [...])`).
  factory Grid.fill(
    Object minWidth, {
    Object? child,
    List<Object?> children = const [],
    Object? sm,
    Object? md,
    Object? lg,
    Object? xl,
    Object? gap,
    String? alignItems,
    String? justifyItems,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) {
    return Grid(
      child: child,
      children: children,
      columns: GridCols.fill(minWidth),
      sm: sm,
      md: md,
      lg: lg,
      xl: xl,
      gap: gap,
      alignItems: alignItems,
      justifyItems: justifyItems,
      className: className,
      props: props,
      style: style,
      dartStyle: dartStyle,
    );
  }

  /// Creates a proportional column grid (e.g. `Grid.ratios([1, 2, 1], gap: 20, children: [...])`).
  factory Grid.ratios(
    List<num> fractions, {
    Object? child,
    List<Object?> children = const [],
    Object? sm,
    Object? md,
    Object? lg,
    Object? xl,
    Object? gap,
    String? alignItems,
    String? justifyItems,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) {
    return Grid(
      child: child,
      children: children,
      columns: GridCols.ratios(fractions),
      sm: sm,
      md: md,
      lg: lg,
      xl: xl,
      gap: gap,
      alignItems: alignItems,
      justifyItems: justifyItems,
      className: className,
      props: props,
      style: style,
      dartStyle: dartStyle,
    );
  }

  /// Creates a sidebar + fluid main content grid (e.g. `Grid.sidebar(248, gap: 20, children: [...])`).
  factory Grid.sidebar(
    Object sidebarWidth, {
    Object? child,
    List<Object?> children = const [],
    Object? gap,
    String? alignItems,
    String? justifyItems,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) {
    return Grid(
      child: child,
      children: children,
      columns: GridCols.sidebar(sidebarWidth),
      gap: gap,
      alignItems: alignItems,
      justifyItems: justifyItems,
      className: className,
      props: props,
      style: style,
      dartStyle: dartStyle,
    );
  }
}

String? _coerceGridColumns(Object? value) {
  if (value == null) return null;
  if (value is int) {
    return 'repeat($value, minmax(0, 1fr))';
  }
  if (value is GridTemplateColumns) {
    return value.value;
  }
  return cssValue(value);
}
