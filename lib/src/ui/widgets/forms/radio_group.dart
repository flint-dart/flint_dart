import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import 'field_helpers.dart';
import 'validation.dart';

/// Option rendered inside a [RadioGroup].
class RadioOption {
  /// Visible option label.
  final String label;

  /// Submitted option value.
  final Object value;

  /// Whether this option should be unavailable.
  final bool disabled;

  /// Creates a radio option.
  const RadioOption({
    required this.label,
    required this.value,
    this.disabled = false,
  });
}

/// Fieldset of mutually exclusive radio options.
class RadioGroup extends FlintElement {
  /// Creates a radio group field.
  RadioGroup({
    String? label,
    String? name,
    Object? value,
    List<RadioOption> options = const [],
    bool required = false,
    bool disabled = false,
    String? error,
    FormErrors? errors,
    String? helpText,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    void Function(Object event)? onChanged,
  }) : super(
         'fieldset',
         props: mergeComponentProps(
           {
             ...props,
             if (disabled) 'disabled': true,
             if (resolveFieldError(name: name, error: error, errors: errors) !=
                 null)
               'aria-invalid': 'true',
           },
           className: className,
           defaultStyle: fieldWrapperStyle,
           dartStyle: dartStyle,
           style: style,
         ),
         children: _children(
           label: label,
           name: name,
           value: value,
           options: options,
           required: required,
           disabled: disabled,
           error: resolveFieldError(name: name, error: error, errors: errors),
           helpText: helpText,
           onChanged: onChanged,
         ),
       );

  static List<FlintNode> _children({
    required String? label,
    required String? name,
    required Object? value,
    required List<RadioOption> options,
    required bool required,
    required bool disabled,
    required String? error,
    required String? helpText,
    required void Function(Object event)? onChanged,
  }) {
    final groupId = fieldId('radio', name, const {});

    return [
      if (label != null)
        FlintElement(
          'legend',
          props: {'style': fieldLabelStyle},
          children: normalizeChildren(required ? '$label *' : label, const []),
        ),
      FlintElement(
        'div',
        props: const {
          'style': {'display': 'grid', 'gap': '8px'},
        },
        children: [
          for (var i = 0; i < options.length; i++)
            _radioOption(
              id: '$groupId-$i',
              name: name,
              option: options[i],
              selectedValue: value,
              required: required,
              disabled: disabled || options[i].disabled,
              onChanged: onChanged,
            ),
        ],
      ),
      ...fieldMessages(id: groupId, helpText: helpText, error: error),
    ];
  }

  static FlintElement _radioOption({
    required String id,
    required String? name,
    required RadioOption option,
    required Object? selectedValue,
    required bool required,
    required bool disabled,
    required void Function(Object event)? onChanged,
  }) {
    return FlintElement(
      'label',
      props: {'for': id, 'style': choiceRowStyle},
      children: [
        FlintElement(
          'input',
          props: {
            'id': id,
            if (name != null) 'name': name,
            'type': 'radio',
            'value': option.value,
            if (selectedValue == option.value) 'checked': true,
            if (required) 'required': true,
            if (disabled) 'disabled': true,
            if (onChanged != null) 'onChange': onChanged,
          },
        ),
        FlintText(option.label),
      ],
    );
  }
}
