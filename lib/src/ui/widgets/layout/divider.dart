import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Horizontal or vertical separator.
class Divider extends FlintElement {
  /// Creates a divider with separator semantics.
  Divider({
    bool vertical = false,
    String color = '#e4e7ec',
    Object thickness = 1,
    Object? length,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'div',
         props: mergeComponentProps(
           {
             ...props,
             'role': props['role'] ?? 'separator',
             'aria-orientation': vertical ? 'vertical' : 'horizontal',
           },
           className: className,
           defaultStyle: vertical
               ? {
                   'width': cssValue(thickness),
                   'height': length == null ? 'auto' : cssValue(length),
                   'background': color,
                   'align-self': 'stretch',
                 }
               : {
                   'height': cssValue(thickness),
                   'width': length == null ? '100%' : cssValue(length),
                   'background': color,
                 },
           dartStyle: dartStyle,
           style: style,
         ),
       );
}
