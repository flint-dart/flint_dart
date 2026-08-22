import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../shared/theme.dart';
import 'controllers.dart';
import 'field_helpers.dart';
import 'validation.dart';
import 'package:universal_web/web.dart' as web;

/// Multiline text input with label, help text, validation, and controller support.
class TextArea extends FlintElement {
  /// Creates a multiline text field.
  TextArea({
    String? label,
    String? name,
    TextEditingController? controller,
    Object? value,
    String? placeholder,
    int rows = 4,
    bool required = false,
    bool disabled = false,
    InputVariant variant = InputVariant.outline,
    ComponentSize size = ComponentSize.md,
    String? error,
    FormErrors? errors,
    String? helpText,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> textareaProps = const {},
    Map<String, Object?> style = const {},
    Map<String, Object?> textareaStyle = const {},
    DartStyle? dartStyle,
    DartStyle? textareaDartStyle,
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
           value: controller?.text ?? value,
           placeholder: placeholder,
           rows: rows,
           required: required,
           disabled: disabled,
           variant: variant,
           size: size,
           error: resolveFieldError(name: name, error: error, errors: errors),
           helpText: helpText,
           textareaProps: textareaProps,
           textareaStyle: textareaStyle,
           textareaDartStyle: textareaDartStyle,
           onChanged: _controlledOnChanged(controller, onChanged),
         ),
       );

  static void Function(Object event)? _controlledOnChanged(
    TextEditingController? controller,
    void Function(Object event)? onChanged,
  ) {
    if (controller == null) return onChanged;

    return (event) {
      final target = event is web.Event ? event.target : null;
      if (target is web.HTMLTextAreaElement) {
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
    required int rows,
    required bool required,
    required bool disabled,
    required InputVariant variant,
    required ComponentSize size,
    required String? error,
    required String? helpText,
    required Map<String, Object?> textareaProps,
    required Map<String, Object?> textareaStyle,
    required DartStyle? textareaDartStyle,
    required void Function(Object event)? onChanged,
  }) {
    final id = fieldId('textarea', name, textareaProps);
    final ariaDescribedBy = describedBy(
      id: id,
      helpText: helpText,
      error: error,
      describedBy: textareaProps['aria-describedby']?.toString(),
    );

    return [
      if (label != null) fieldLabel(id: id, label: label, required: required),
      FlintElement(
        'textarea',
        props: mergeComponentProps(
          {
            ...controlProps(
              props: textareaProps,
              id: id,
              name: name,
              required: required,
              disabled: disabled,
              error: error,
              describedBy: ariaDescribedBy,
            ),
            'rows': rows,
            if (value != null) 'value': value,
            if (placeholder != null) 'placeholder': placeholder,
            if (onChanged != null) 'onInput': onChanged,
          },
          dartStyle:
              inputComponentStyle(
                    variant: variant,
                    size: size,
                    disabled: disabled,
                    invalid: error != null && error.isNotEmpty,
                  )
                  .merge(
                    const DartStyle(minHeight: 96, resize: Resize.vertical),
                  )
                  .merge(textareaDartStyle),
          style: textareaStyle,
        ),
      ),
      ...fieldMessages(id: id, helpText: helpText, error: error),
    ];
  }
}
