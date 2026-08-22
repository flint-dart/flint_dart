import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Two-column application shell with sidebar, optional brand, and topbar.
class AppShell extends FlintElement {
  /// Creates an app shell around sidebar and main page content.
  AppShell({
    Object? brand,
    Object? sidebar,
    Object? topbar,
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
           defaultStyle: const {
             'display': 'grid',
             'grid-template-columns': '280px minmax(0, 1fr)',
             'min-height': '100vh',
             'background': '#f8fafc',
             'color': '#101828',
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           if (sidebar != null)
             FlintElement(
               'aside',
               props: const {
                 'style': {
                   'border-right': '1px solid #e4e7ec',
                   'background': '#ffffff',
                 },
               },
               children: [
                 if (brand != null)
                   FlintElement(
                     'div',
                     props: const {
                       'style': {
                         'padding': '20px',
                         'border-bottom': '1px solid #e4e7ec',
                         'font-weight': 700,
                       },
                     },
                     children: normalizeChildren(brand, const []),
                   ),
                 toFlintNode(sidebar),
               ],
             ),
           FlintElement(
             'div',
             props: const {
               'style': {
                 'min-width': 0,
                 'display': 'grid',
                 'grid-template-rows': 'auto minmax(0, 1fr)',
               },
             },
             children: [
               if (topbar != null) toFlintNode(topbar),
               FlintElement(
                 'main',
                 props: const {
                   'style': {'min-width': 0, 'padding': '24px'},
                 },
                 children: normalizeChildren(child, children),
               ),
             ],
           ),
         ],
       );
}
