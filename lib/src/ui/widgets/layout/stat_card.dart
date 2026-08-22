import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../feedback/status_badge.dart';
import '../shared/theme.dart';

/// Metric card for dashboard statistics.
class StatCard extends FlintElement {
  /// Creates a stat card with label, value, and optional trend.
  StatCard({
    required String label,
    required Object value,
    String? trend,
    Tone tone = Tone.neutral,
    CardVariant variant = CardVariant.outline,
    Object? icon,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'article',
         props: mergeComponentProps(
           props,
           className: className,
           dartStyle: cardComponentStyle(
             variant: variant,
             tone: tone,
           ).merge(dartStyle),
           style: style,
         ),
         children: [
           FlintElement(
             'div',
             props: const {
               'style': {
                 'display': 'flex',
                 'align-items': 'center',
                 'justify-content': 'space-between',
                 'gap': '10px',
               },
             },
             children: [
               FlintElement(
                 'span',
                 props: const {
                   'style': {
                     'font-size': '13px',
                     'color': '#667085',
                     'font-weight': 600,
                   },
                 },
                 children: normalizeChildren(label, const []),
               ),
               if (icon != null) toFlintNode(icon),
             ],
           ),
           FlintElement(
             'strong',
             props: const {
               'style': {'font-size': '28px', 'line-height': 1.1},
             },
             children: normalizeChildren(value, const []),
           ),
           if (trend != null) StatusBadge(label: trend, tone: tone),
         ],
       );
}
