import 'text_field.dart';

/// File picker field with label, help text, and validation message support.
class FileInput extends TextField {
  /// Creates a file input field.
  FileInput({
    super.label,
    super.name,
    String? accept,
    bool multiple = false,
    super.required = false,
    super.disabled = false,
    super.error,
    super.errors,
    super.helpText,
    super.className,
    super.props = const {},
    Map<String, Object?> inputProps = const {},
    super.style = const {},
    super.inputStyle = const {},
    super.dartStyle,
    super.onChanged,
  }) : super(
          type: 'file',
          inputProps: {
            ...inputProps,
            if (accept != null) 'accept': accept,
            if (multiple) 'multiple': true,
          },
        );
}
