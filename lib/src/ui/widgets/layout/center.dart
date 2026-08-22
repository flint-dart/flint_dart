import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Flex container that centers child content on both axes.
class Center extends FlintElement {
  /// Creates a centering container.
  Center({
    Object? child,
    List<Object?> children = const [],
    bool inline = false,
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
             'display': inline ? 'inline-flex' : 'flex',
             'align-items': 'center',
             'justify-content': 'center',
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: normalizeChildren(child, children),
       );
}
