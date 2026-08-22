import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Generic `div` wrapper for grouping and styling content.
class Container extends FlintElement {
  /// Creates a container with optional child content and styles.
  Container({
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
           dartStyle: dartStyle,
           style: style,
         ),
         children: normalizeChildren(child, children),
       );
}
