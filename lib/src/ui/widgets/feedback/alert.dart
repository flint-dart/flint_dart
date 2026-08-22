import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../shared/theme.dart';

/// Tone-aware alert surface for important status messages.
class Alert extends FlintElement {
  /// Creates an alert with optional title, message, content, and actions.
  Alert({
    String? title,
    String? message,
    Object? child,
    List<Object?> children = const [],
    Object? actions,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    Tone tone = Tone.info,
  }) : super(
         'div',
         props: mergeComponentProps(
           {...props, 'role': props['role'] ?? 'alert'},
           className: className,
           defaultStyle: {
             'display': 'grid',
             'gap': '6px',
             'border': '1px solid ${toneBorder(tone)}',
             'border-radius': '8px',
             'padding': '12px 14px',
             'background': toneSoft(tone),
             'color': toneText(tone),
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           if (title != null)
             FlintElement(
               'strong',
               props: const {
                 'style': {'font-weight': 700},
               },
               children: normalizeChildren(title, const []),
             ),
           if (message != null)
             FlintElement(
               'p',
               props: const {
                 'style': {'margin': 0},
               },
               children: normalizeChildren(message, const []),
             ),
           ...normalizeChildren(child, children),
           if (actions != null) toFlintNode(actions),
         ],
       );
}
