import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../shared/theme.dart';
import 'controllers.dart';
import 'field_helpers.dart';
import 'validation.dart';
import 'package:universal_web/web.dart' as web;

/// Text input field with label, help text, validation, and controller support.
class TextField extends FlintElement {
  /// Creates a text input field.
  TextField({
    String? label,
    String? name,
    TextEditingController? controller,
    Object? value,
    String? placeholder,
    String type = 'text',
    bool required = false,
    bool disabled = false,
    bool readonly = false,
    InputVariant variant = InputVariant.outline,
    ComponentSize size = ComponentSize.md,
    String? error,
    FormErrors? errors,
    String? helpText,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> inputProps = const {},
    Map<String, Object?> style = const {},
    Map<String, Object?> inputStyle = const {},
    DartStyle? dartStyle,
    DartStyle? inputDartStyle,
    void Function(Object event)? onChanged,
    void Function(String value)? onSubmitted,
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
            value: controller?.text ?? value,
            placeholder: placeholder,
            type: type,
            required: required,
            disabled: disabled,
            readonly: readonly,
            variant: variant,
            size: size,
            error: resolveFieldError(name: name, error: error, errors: errors),
            helpText: helpText,
            inputProps: inputProps,
            inputStyle: inputStyle,
            inputDartStyle: inputDartStyle,
            onChanged: _controlledOnChanged(controller, onChanged),
            onSubmitted: onSubmitted,
          ),
        );

  static void Function(Object event)? _controlledOnChanged(
    TextEditingController? controller,
    void Function(Object event)? onChanged,
  ) {
    if (controller == null) return onChanged;

    return (event) {
      final target = event is web.Event ? event.target : null;
      if (target is web.HTMLInputElement) {
        controller.text = target.value;
      }
      onChanged?.call(event);
    };
  }

  static List<FlintNode> _children({
    required String? label,
    required String? name,
    required Object? value,
    required String? placeholder,
    required String type,
    required bool required,
    required bool disabled,
    required bool readonly,
    required InputVariant variant,
    required ComponentSize size,
    required String? error,
    required String? helpText,
    required Map<String, Object?> inputProps,
    required Map<String, Object?> inputStyle,
    required DartStyle? inputDartStyle,
    required void Function(Object event)? onChanged,
    required void Function(String value)? onSubmitted,
  }) {
    final id = fieldId('field', name, inputProps);
    final ariaDescribedBy = describedBy(
      id: id,
      helpText: helpText,
      error: error,
      describedBy: inputProps['aria-describedby']?.toString(),
    );

    return [
      if (label != null) fieldLabel(id: id, label: label, required: required),
      FlintElement(
        'input',
        props: mergeComponentProps(
          {
            ...controlProps(
              props: inputProps,
              id: id,
              name: name,
              required: required,
              disabled: disabled,
              error: error,
              describedBy: ariaDescribedBy,
            ),
            if (readonly) 'readonly': true,
            'type': type,
            if (value != null) 'value': value,
            if (placeholder != null) 'placeholder': placeholder,
            if (onChanged != null) 'onInput': onChanged,
            if (onSubmitted != null)
              'onKeyDown': (Object event) {
                if (event is web.KeyboardEvent && event.key == 'Enter') {
                  event.preventDefault();
                  onSubmitted((event.target as web.HTMLInputElement).value);
                }
              },
          },
          dartStyle: inputComponentStyle(
            variant: variant,
            size: size,
            disabled: disabled,
            invalid: error != null && error.isNotEmpty,
          )
              .merge(
                readonly
                    ? DartStyle(
                        background: ThemeToken.color(
                          'disabledSurface',
                          fallback: '#f3f4f6',
                        ).toCss(),
                        cursor: Cursor.defaultCursor,
                      )
                    : null,
              )
              .merge(inputDartStyle),
          style: inputStyle,
        ),
      ),
      ...fieldMessages(id: id, helpText: helpText, error: error),
    ];
  }
}
