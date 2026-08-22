import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Box that applies min/max size constraints.
class ConstrainedBox extends FlintElement {
  /// Creates a constrained wrapper around child content.
  ConstrainedBox({
    Object? child,
    List<Object?> children = const [],
    Object? minWidth,
    Object? maxWidth,
    Object? minHeight,
    Object? maxHeight,
    bool center = false,
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
             width: SizeValue.full,
             minWidth: minWidth,
             maxWidth: maxWidth,
             minHeight: minHeight,
             maxHeight: maxHeight,
             margin: center
                 ? const EdgeInsets.symmetric(horizontal: SizeValue.auto)
                 : null,
           ).merge(dartStyle),
           style: style,
         ),
         children: normalizeChildren(child, children),
       );
}
