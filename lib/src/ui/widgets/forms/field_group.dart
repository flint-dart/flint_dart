import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Groups related form fields under an optional title and description.
class FieldGroup extends FlintElement {
  /// Creates a form field group.
  FieldGroup({
    String? title,
    String? description,
    Object? child,
    List<Object?> children = const [],
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'section',
         props: mergeComponentProps(
           props,
           className: className,
           defaultStyle: const {'display': 'grid', 'gap': '12px'},
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           if (title != null || description != null)
             FlintElement(
               'header',
               props: const {
                 'style': {'display': 'grid', 'gap': '4px'},
               },
               children: [
                 if (title != null)
                   FlintElement(
                     'h3',
                     props: const {
                       'style': {'margin': 0, 'font-size': '16px'},
                     },
                     children: normalizeChildren(title, const []),
                   ),
                 if (description != null)
                   FlintElement(
                     'p',
                     props: const {
                       'style': {'margin': 0, 'color': '#667085'},
                     },
                     children: normalizeChildren(description, const []),
                   ),
               ],
             ),
           ...normalizeChildren(child, children),
         ],
       );
}
