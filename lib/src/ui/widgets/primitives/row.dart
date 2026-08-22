import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Horizontal flex container.
class Row extends FlintElement {
  /// Creates a row with optional child content and styles.
  Row({
    Object? child,
    List<Object?> children = const [],
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'div',
         props: mergeComponentProps(
           props,
           className: className,
           defaultStyle: const {'display': 'flex', 'flex-direction': 'row'},
           dartStyle: DartStyle(
             display: (dartStyle?.display == Display.grid)
                 ? Display.flex
                 : (dartStyle?.display ?? Display.flex),
             flexDirection: FlexDirection.row,
             flexWrap: dartStyle?.flexWrap,
             alignItems: dartStyle?.alignItems,
             justifyContent: dartStyle?.justifyContent,
             gap: dartStyle?.gap,
             padding: dartStyle?.padding,
             margin: dartStyle?.margin,
             width: dartStyle?.width,
             height: dartStyle?.height,
             minWidth: dartStyle?.minWidth,
             maxWidth: dartStyle?.maxWidth,
             minHeight: dartStyle?.minHeight,
             background: dartStyle?.background,
             color: dartStyle?.color,
             fontSize: dartStyle?.fontSize,
             fontWeight: dartStyle?.fontWeight,
             radius: dartStyle?.radius,
             border: dartStyle?.border,
             shadow: dartStyle?.shadow,
             position: dartStyle?.position,
             top: dartStyle?.top,
             right: dartStyle?.right,
             bottom: dartStyle?.bottom,
             left: dartStyle?.left,
             zIndex: dartStyle?.zIndex,
             overflow: dartStyle?.overflow,
             textAlign: dartStyle?.textAlign,
             cursor: dartStyle?.cursor,
             opacity: dartStyle?.opacity,
             transform: dartStyle?.transform,
             transition: dartStyle?.transition,
             backdropFilter: dartStyle?.backdropFilter,
             sm: dartStyle?.sm,
             md: dartStyle?.md,
             lg: dartStyle?.lg,
             xl: dartStyle?.xl,
           ),
           style: style,
         ),
         children: normalizeChildren(child, children),
       );
}
