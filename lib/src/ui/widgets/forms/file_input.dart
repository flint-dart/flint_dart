import '../../style.dart';
import 'text_field.dart';
import 'validation.dart';

/// File picker field with label, help text, and validation message support.
class FileInput extends TextField {
  /// Creates a file input field.
  FileInput({
    String? label,
    String? name,
    String? accept,
    bool multiple = false,
    bool required = false,
    bool disabled = false,
    String? error,
    FormErrors? errors,
    String? helpText,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> inputProps = const {},
    Map<String, Object?> style = const {},
    Map<String, Object?> inputStyle = const {},
    DartStyle? dartStyle,
    void Function(Object event)? onChanged,
  }) : super(
         label: label,
         name: name,
         type: 'file',
         required: required,
         disabled: disabled,
         error: error,
         errors: errors,
         helpText: helpText,
         className: className,
         props: props,
         inputProps: {
           ...inputProps,
           if (accept != null) 'accept': accept,
           if (multiple) 'multiple': true,
         },
         style: style,
         inputStyle: inputStyle,
         dartStyle: dartStyle,
         onChanged: onChanged,
       );
}
