import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Search form with accessible input and submit handling.
class SearchBox extends FlintElement {
  /// Creates a search box.
  SearchBox({
    String? value,
    String placeholder = 'Search',
    String? label,
    String? name,
    bool disabled = false,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> inputProps = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    void Function(Object event)? onChanged,
    void Function(Object event)? onSubmit,
  }) : super(
         'form',
         props: mergeComponentProps(
           {
             ...props,
             'role': props['role'] ?? 'search',
             if (onSubmit != null) 'onSubmit': onSubmit,
           },
           className: className,
           defaultStyle: const {
             'display': 'flex',
             'align-items': 'center',
             'gap': '8px',
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           if (label != null)
             FlintElement(
               'label',
               props: const {
                 'style': {
                   'font-size': '14px',
                   'font-weight': 600,
                   'color': '#344054',
                 },
               },
               children: normalizeChildren(label, const []),
             ),
           FlintElement(
             'input',
             props: mergeComponentProps(
               {
                 ...inputProps,
                 'type': 'search',
                 if (name != null) 'name': name,
                 if (value != null) 'value': value,
                 'placeholder': placeholder,
                 if (label == null) 'aria-label': placeholder,
                 if (disabled) 'disabled': true,
                 if (onChanged != null) 'onInput': onChanged,
               },
               defaultStyle: const {
                 'min-height': '38px',
                 'min-width': '220px',
                 'border': '1px solid #d0d5dd',
                 'border-radius': '8px',
                 'padding': '0 10px',
                 'font': 'inherit',
               },
             ),
           ),
         ],
       );
}
