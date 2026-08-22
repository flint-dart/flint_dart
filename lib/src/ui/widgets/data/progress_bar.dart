import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../shared/theme.dart';

/// Accessible progress indicator with tone-colored fill.
class ProgressBar extends FlintElement {
  /// Creates a progress bar for [value] out of [max].
  ProgressBar({
    required num value,
    num max = 100,
    String? label,
    Tone tone = Tone.primary,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'div',
         props: mergeComponentProps(
           {
             ...props,
             'role': 'progressbar',
             'aria-valuenow': value,
             'aria-valuemin': 0,
             'aria-valuemax': max,
             if (label != null) 'aria-label': label,
           },
           className: className,
           defaultStyle: const {'display': 'grid', 'gap': '6px'},
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           if (label != null) FlintText(label),
           FlintElement(
             'div',
             props: const {
               'style': {
                 'height': '8px',
                 'border-radius': '999px',
                 'background': '#eaecf0',
                 'overflow': 'hidden',
               },
             },
             children: [
               FlintElement(
                 'span',
                 props: {
                   'style': {
                     'display': 'block',
                     'height': '100%',
                     'width': '${_percent(value, max)}%',
                     'background': toneSolid(tone),
                   },
                 },
               ),
             ],
           ),
         ],
       );
}

num _percent(num value, num max) {
  if (max <= 0) return 0;
  final percent = (value / max) * 100;
  return percent.clamp(0, 100);
}
