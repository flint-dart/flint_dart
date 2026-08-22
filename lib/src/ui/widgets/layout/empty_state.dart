import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Empty-state surface with title, message, icon, and action slots.
class EmptyState extends FlintElement {
  /// Creates an empty-state message.
  EmptyState({
    required String title,
    String? message,
    Object? action,
    Object? icon,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'div',
         props: mergeComponentProps(
           props,
           className: className,
           defaultStyle: const {
             'display': 'grid',
             'justify-items': 'center',
             'gap': '10px',
             'padding': '32px 20px',
             'text-align': 'center',
             'border': '1px dashed #d0d5dd',
             'border-radius': '8px',
             'background': '#ffffff',
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           if (icon != null) toFlintNode(icon),
           FlintElement(
             'h2',
             props: const {
               'style': {'margin': 0, 'font-size': '18px'},
             },
             children: normalizeChildren(title, const []),
           ),
           if (message != null)
             FlintElement(
               'p',
               props: const {
                 'style': {'margin': 0, 'color': '#667085'},
               },
               children: normalizeChildren(message, const []),
             ),
           if (action != null) toFlintNode(action),
         ],
       );
}
