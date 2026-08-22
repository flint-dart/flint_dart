import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Item rendered inside [Breadcrumbs].
class BreadcrumbItem {
  /// Visible breadcrumb label.
  final String label;

  /// Optional destination URL.
  final String? href;

  /// Whether this item represents the current page.
  final bool current;

  /// Creates a breadcrumb item.
  const BreadcrumbItem({required this.label, this.href, this.current = false});
}

/// Breadcrumb navigation trail for hierarchical pages.
class Breadcrumbs extends FlintElement {
  /// Creates breadcrumbs from [items].
  Breadcrumbs({
    List<BreadcrumbItem> items = const [],
    String separator = '/',
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'nav',
         props: mergeComponentProps(
           {...props, 'aria-label': props['aria-label'] ?? 'Breadcrumb'},
           className: className,
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           FlintElement(
             'ol',
             props: const {
               'style': {
                 'display': 'flex',
                 'align-items': 'center',
                 'gap': '8px',
                 'list-style': 'none',
                 'padding': 0,
                 'margin': 0,
               },
             },
             children: [
               for (var i = 0; i < items.length; i++) ...[
                 if (i > 0)
                   FlintElement(
                     'li',
                     props: const {
                       'aria-hidden': 'true',
                       'style': {'color': '#98a2b3'},
                     },
                     children: normalizeChildren(separator, const []),
                   ),
                 _item(items[i]),
               ],
             ],
           ),
         ],
       );

  static FlintElement _item(BreadcrumbItem item) {
    final current = item.current || item.href == null;
    return FlintElement(
      'li',
      children: [
        if (current)
          FlintElement(
            'span',
            props: const {
              'aria-current': 'page',
              'style': {'color': '#344054', 'font-weight': 600},
            },
            children: normalizeChildren(item.label, const []),
          )
        else
          FlintElement(
            'a',
            props: {
              'href': item.href,
              'style': const {
                'color': '#175cd3',
                'text-decoration': 'none',
                'font-weight': 600,
              },
            },
            children: normalizeChildren(item.label, const []),
          ),
      ],
    );
  }
}
