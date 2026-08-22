import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../shared/theme.dart';

/// Compact badge for status labels and optional icons.
class StatusBadge extends FlintElement {
  /// Creates a status badge.
  StatusBadge({
    required String label,
    Object? icon,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    BadgeVariant variant = BadgeVariant.soft,
    Tone tone = Tone.neutral,
    ComponentSize size = ComponentSize.sm,
  }) : super(
         'span',
         props: mergeComponentProps(
           props,
           className: className,
           dartStyle: badgeComponentStyle(
             variant: variant,
             tone: tone,
             size: size,
           ).merge(dartStyle),
           style: style,
         ),
         children: [if (icon != null) toFlintNode(icon), FlintText(label)],
       );
}
