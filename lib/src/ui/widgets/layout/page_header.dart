import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Page header with title, optional description, breadcrumbs, and actions.
class PageHeader extends FlintElement {
  /// Creates a page header for a top-level screen.
  PageHeader({
    required String title,
    String? description,
    Object? breadcrumbs,
    Object? actions,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'header',
         props: mergeComponentProps(
           props,
           className: className,
           defaultStyle: const {
             'display': 'flex',
             'align-items': 'flex-start',
             'justify-content': 'space-between',
             'gap': '16px',
             'margin-bottom': '20px',
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           FlintElement(
             'div',
             props: const {
               'style': {'display': 'grid', 'gap': '6px'},
             },
             children: [
               if (breadcrumbs != null) toFlintNode(breadcrumbs),
               FlintElement(
                 'h1',
                 props: const {
                   'style': {
                     'margin': 0,
                     'font-size': '28px',
                     'line-height': 1.2,
                   },
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
           if (actions != null) toFlintNode(actions),
         ],
       );
}
