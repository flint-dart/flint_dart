import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Top navigation bar with title, leading content, actions, and user slot.
class Topbar extends FlintElement {
  /// Creates a topbar for app shells and dashboards.
  Topbar({
    String? title,
    String? subtitle,
    Object? leading,
    Object? actions,
    Object? user,
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
             'align-items': 'center',
             'justify-content': 'space-between',
             'gap': '16px',
             'min-height': '64px',
             'padding': '0 24px',
             'border-bottom': '1px solid #e4e7ec',
             'background': '#ffffff',
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           FlintElement(
             'div',
             props: const {
               'style': {
                 'display': 'flex',
                 'align-items': 'center',
                 'gap': '12px',
                 'min-width': 0,
               },
             },
             children: [
               if (leading != null) toFlintNode(leading),
               if (title != null || subtitle != null)
                 FlintElement(
                   'div',
                   props: const {
                     'style': {'min-width': 0},
                   },
                   children: [
                     if (title != null)
                       FlintElement(
                         'h1',
                         props: const {
                           'style': {
                             'margin': 0,
                             'font-size': '18px',
                             'line-height': 1.3,
                           },
                         },
                         children: normalizeChildren(title, const []),
                       ),
                     if (subtitle != null)
                       FlintElement(
                         'p',
                         props: const {
                           'style': {
                             'margin': 0,
                             'color': '#667085',
                             'font-size': '13px',
                           },
                         },
                         children: normalizeChildren(subtitle, const []),
                       ),
                   ],
                 ),
             ],
           ),
           FlintElement(
             'div',
             props: const {
               'style': {
                 'display': 'flex',
                 'align-items': 'center',
                 'gap': '10px',
               },
             },
             children: [
               if (actions != null) toFlintNode(actions),
               if (user != null) toFlintNode(user),
             ],
           ),
         ],
       );
}
