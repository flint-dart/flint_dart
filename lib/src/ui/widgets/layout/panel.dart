import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import 'section.dart';

/// Bordered content panel with optional section heading.
class Panel extends FlintElement {
  /// Creates a panel around child content.
  Panel({
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
             'border': '1px solid #e4e7ec',
             'border-radius': '8px',
             'padding': '16px',
             'background': '#ffffff',
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           if (title != null || description != null || actions != null)
             Section(title: title, description: description, actions: actions),
           ...normalizeChildren(child, children),
         ],
       );
}
