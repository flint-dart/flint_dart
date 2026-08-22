import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Relative-positioned container for layered content.
class Stack extends FlintElement {
  /// Creates a stack around child content.
  Stack({
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
           defaultStyle: const {'position': 'relative'},
           dartStyle: dartStyle,
           style: style,
         ),
         children: normalizeChildren(child, children),
       );
}
