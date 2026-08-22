import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../shared/theme.dart';

/// Toast notification surface with optional message and action content.
class Toast extends FlintElement {
  /// Creates a toast notification.
  Toast({
    required String title,
    String? message,
    Tone tone = Tone.info,
    Object? action,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'div',
         props: mergeComponentProps(
           {...props, 'role': props['role'] ?? 'status'},
           className: className,
           defaultStyle: {
             'display': 'grid',
             'gap': '6px',
             'min-width': '280px',
             'border': '1px solid ${toneBorder(tone)}',
             'border-radius': '8px',
             'padding': '12px',
             'background': '#ffffff',
             'color': toneText(tone),
             'box-shadow': '0 12px 24px rgba(16, 24, 40, 0.14)',
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           FlintElement('strong', children: normalizeChildren(title, const [])),
           if (message != null)
             FlintElement('p', children: normalizeChildren(message, const [])),
           if (action != null) toFlintNode(action),
         ],
       );
}
