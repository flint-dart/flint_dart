import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Responsive grid that uses auto-fit columns by default.
class ResponsiveGrid extends FlintElement {
  /// Creates a responsive grid with optional breakpoint column overrides.
  ResponsiveGrid({
    Object? child,
    List<Object?> children = const [],
    int minItemWidth = 240,
    Object? gap,
    Object? rowGap,
    Object? columnGap,
    Object? columns,
    Object? sm,
    Object? md,
    Object? lg,
    Object? xl,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'div',
         props: mergeComponentProps(
           props,
           className: className,
           dartStyle: DartStyle(
             display: Display.grid,
             gap: gap,
             gridTemplateColumns:
                 columns ?? GridTemplateColumns.autoFit(minItemWidth),
             sm: sm == null ? null : DartStyle(gridTemplateColumns: sm),
             md: md == null ? null : DartStyle(gridTemplateColumns: md),
             lg: lg == null ? null : DartStyle(gridTemplateColumns: lg),
             xl: xl == null ? null : DartStyle(gridTemplateColumns: xl),
           ).merge(dartStyle),
           style: {
             if (rowGap != null) 'row-gap': cssValue(rowGap),
             if (columnGap != null) 'column-gap': cssValue(columnGap),
             ...style,
           },
         ),
         children: normalizeChildren(child, children),
       );
}
