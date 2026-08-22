import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../shared/theme.dart';
import 'field_helpers.dart';
import 'validation.dart';

/// Option rendered inside a [Select] field.
class SelectOption {
  /// Visible option label.
  final String label;

  /// Submitted option value.
  final Object value;

  /// Whether this option should be unavailable.
  final bool disabled;

  /// Creates a select option.
  const SelectOption({
    required this.label,
    required this.value,
    this.disabled = false,
  });
}

/// Select field with options, placeholder, help text, and validation support.
class Select extends FlintElement {
  /// Creates a select field.
  Select({
    String? label,
    String? name,
    Object? value,
    String? placeholder,
    List<SelectOption> options = const [],
    bool required = false,
    bool disabled = false,
    InputVariant variant = InputVariant.outline,
    ComponentSize size = ComponentSize.md,
    String? error,
    FormErrors? errors,
    String? helpText,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> selectProps = const {},
    Map<String, Object?> style = const {},
    Map<String, Object?> selectStyle = const {},
    DartStyle? dartStyle,
    DartStyle? selectDartStyle,
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
           value: value,
           placeholder: placeholder,
           options: options,
           required: required,
           disabled: disabled,
           variant: variant,
           size: size,
           error: resolveFieldError(name: name, error: error, errors: errors),
           helpText: helpText,
           selectProps: selectProps,
           selectStyle: selectStyle,
           selectDartStyle: selectDartStyle,
           onChanged: onChanged,
         ),
       );

  static List<FlintNode> _children({
    required String? label,
    required String? name,
    required Object? value,
    required String? placeholder,
    required List<SelectOption> options,
    required bool required,
    required bool disabled,
    required InputVariant variant,
    required ComponentSize size,
    required String? error,
    required String? helpText,
    required Map<String, Object?> selectProps,
    required Map<String, Object?> selectStyle,
    required DartStyle? selectDartStyle,
    required void Function(Object event)? onChanged,
  }) {
    final id = fieldId('select', name, selectProps);
    final ariaDescribedBy = describedBy(
      id: id,
      helpText: helpText,
      error: error,
      describedBy: selectProps['aria-describedby']?.toString(),
    );

    return [
      if (label != null) fieldLabel(id: id, label: label, required: required),
      FlintElement(
        'select',
        props: mergeComponentProps(
          {
            ...controlProps(
              props: selectProps,
              id: id,
              name: name,
              required: required,
              disabled: disabled,
              error: error,
              describedBy: ariaDescribedBy,
            ),
            if (onChanged != null) 'onChange': onChanged,
          },
          dartStyle: inputComponentStyle(
            variant: variant,
            size: size,
            disabled: disabled,
            invalid: error != null && error.isNotEmpty,
          ).merge(selectDartStyle),
          style: selectStyle,
        ),
        children: [
          if (placeholder != null)
            FlintElement(
              'option',
              props: {
                'value': '',
                if (value == null) 'selected': true,
                if (required) 'disabled': true,
              },
              children: normalizeChildren(placeholder, const []),
            ),
          for (final option in options)
            FlintElement(
              'option',
              props: {
                'value': option.value,
                if (value == option.value) 'selected': true,
                if (option.disabled) 'disabled': true,
              },
              children: normalizeChildren(option.label, const []),
            ),
        ],
      ),
      ...fieldMessages(id: id, helpText: helpText, error: error),
    ];
  }
}
