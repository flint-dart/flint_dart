import '../../node.dart';
import '../../style.dart';
import 'field_helpers.dart';
import 'validation.dart';

/// Checkbox field with label, help text, and validation message support.
class Checkbox extends FlintElement {
  /// Creates a checkbox field.
  Checkbox({
    String? label,
    String? name,
    bool checked = false,
    bool disabled = false,
    bool indeterminate = false,
    String? error,
    FormErrors? errors,
    String? helpText,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> inputProps = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    void Function(Object event)? onChanged,
  }) : super(
         'div',
         props: fieldWrapperProps(
           props: props,
           className: className,
           dartStyle: dartStyle,
           style: style,
         ),
         children: _children(
           label: label,
           name: name,
           checked: checked,
           disabled: disabled,
           indeterminate: indeterminate,
           error: resolveFieldError(name: name, error: error, errors: errors),
           helpText: helpText,
           inputProps: inputProps,
           onChanged: onChanged,
         ),
       );

  static List<FlintNode> _children({
    required String? label,
    required String? name,
    required bool checked,
    required bool disabled,
    required bool indeterminate,
    required String? error,
    required String? helpText,
    required Map<String, Object?> inputProps,
    required void Function(Object event)? onChanged,
  }) {
    final id = fieldId('checkbox', name, inputProps);
    final ariaDescribedBy = describedBy(
      id: id,
      helpText: helpText,
      error: error,
      describedBy: inputProps['aria-describedby']?.toString(),
    );

    return [
      FlintElement(
        'label',
        props: {'for': id, 'style': choiceRowStyle},
        children: [
          FlintElement(
            'input',
            props: {
              ...controlProps(
                props: inputProps,
                id: id,
                name: name,
                required: false,
                disabled: disabled,
                error: error,
                describedBy: ariaDescribedBy,
              ),
              'type': 'checkbox',
              if (checked) 'checked': true,
              if (indeterminate) 'aria-checked': 'mixed',
              if (onChanged != null) 'onChange': onChanged,
            },
          ),
          if (label != null) FlintText(label),
        ],
      ),
      ...fieldMessages(id: id, helpText: helpText, error: error),
    ];
  }
}
