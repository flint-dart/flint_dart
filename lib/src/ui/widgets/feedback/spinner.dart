import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../shared/theme.dart';

/// Accessible loading spinner.
class Spinner extends FlintElement {
  /// Creates a spinner with optional status label.
  Spinner({
    String? label,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    ComponentSize size = ComponentSize.md,
    Tone tone = Tone.primary,
  }) : super(
         'span',
         props: mergeComponentProps(
           {
             ...props,
             'role': 'status',
             if (label == null) 'aria-label': 'Loading',
           },
           className: className,
           defaultStyle: {
             'display': 'inline-block',
             'width': spinnerSize(size),
             'height': spinnerSize(size),
             'border': '2px solid ${toneSoft(tone)}',
             'border-top-color': toneSolid(tone),
             'border-radius': '999px',
             'animation': cssValue(StyleAnimation.spin()),
             'will-change': cssValue(WillChange.transform),
             'flex-shrink': 0,
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: label == null
             ? const []
             : normalizeChildren(label, const []),
       );
}
