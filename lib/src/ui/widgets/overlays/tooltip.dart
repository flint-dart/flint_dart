import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Tooltip content attached to an inline child.
class Tooltip extends FlintElement {
  /// Creates a tooltip for [child].
  Tooltip({
    required String content,
    required Object child,
    String placement = 'top',
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'span',
         props: mergeComponentProps(
           props,
           className: className,
           defaultStyle: const {
             'position': 'relative',
             'display': 'inline-flex',
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           toFlintNode(child),
           FlintElement(
             'span',
             props: {
               'role': 'tooltip',
               'data-placement': placement,
               'style': const {
                 'position': 'absolute',
                 'z-index': 20,
                 'padding': '4px 8px',
                 'border-radius': '6px',
                 'background': '#101828',
                 'color': '#ffffff',
                 'font-size': '12px',
               },
             },
             children: normalizeChildren(content, const []),
           ),
         ],
       );
}
