import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Empty flex/grid spacer element.
class Spacer extends FlintElement {
  /// Creates a spacer with optional flex and fixed size.
  Spacer({
    int flex = 1,
    Object? size,
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
             'flex': flex,
             if (size != null) 'width': cssValue(size),
             if (size != null) 'height': cssValue(size),
           },
           dartStyle: dartStyle,
           style: style,
         ),
       );
}
