import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../shared/theme.dart';
import 'progress_bar.dart';

/// Usage summary paired with a progress bar.
class UsageMeter extends FlintElement {
  /// Creates a usage meter for [used] out of [limit].
  UsageMeter({
    required String label,
    required num used,
    required num limit,
    String unit = '',
    Tone tone = Tone.primary,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'div',
         props: mergeComponentProps(
           props,
           className: className,
           defaultStyle: const {'display': 'grid', 'gap': '8px'},
           dartStyle: dartStyle,
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
                 'gap': '12px',
               },
             },
             children: [FlintText(label), FlintText('$used / $limit$unit')],
           ),
           ProgressBar(value: used, max: limit, tone: tone),
         ],
       );
}
