import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Content section with optional heading, description, and actions.
class Section extends FlintElement {
  /// Creates a section around child content.
  Section({
    String? title,
    String? description,
    Object? actions,
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
           defaultStyle: const {
             'display': 'grid',
             'gap': '14px',
             'margin-bottom': '24px',
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           if (title != null || description != null || actions != null)
             _sectionHeader(title, description, actions),
           ...normalizeChildren(child, children),
         ],
       );

  static FlintElement _sectionHeader(
    String? title,
    String? description,
    Object? actions,
  ) {
    return FlintElement(
      'header',
      props: const {
        'style': {
          'display': 'flex',
          'align-items': 'flex-start',
          'justify-content': 'space-between',
          'gap': '12px',
        },
      },
      children: [
        FlintElement(
          'div',
          children: [
            if (title != null)
              FlintElement(
                'h2',
                props: const {
                  'style': {'margin': 0, 'font-size': '18px'},
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
}
