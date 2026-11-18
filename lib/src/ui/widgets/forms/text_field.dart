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
    Object? prefix,
    Object? suffix,
    void Function(Object event)? onPrefixTap,
    void Function(Object event)? onSuffixTap,
    DartStyle? prefixDartStyle,
    DartStyle? suffixDartStyle,
    bool togglePassword = false,
    Object? passwordShowIcon,
    Object? passwordHideIcon,
    String? Function(String? value)? validator,
    AutovalidateMode autovalidateMode = AutovalidateMode.onUserInteraction,
    Map<String, Object?> props = const {},
    Map<String, Object?> inputProps = const {},
    Map<String, Object?> style = const {},
    Map<String, Object?> labelStyle = const {},
    Map<String, Object?> inputStyle = const {},
    DartStyle? dartStyle,
    DartStyle? labelDartStyle,
    DartStyle? inputDartStyle,
    void Function(Object event)? onChanged,
    void Function(Object event)? onBlur,
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
            error: resolveFieldError(
              name: name,
              error: error,
              errors: errors,
              validator: validator,
              value: (controller?.text ?? value)?.toString(),
              autovalidateMode: autovalidateMode,
            ),
            helpText: helpText,
            prefix: prefix,
            suffix: suffix,
            onPrefixTap: onPrefixTap,
            onSuffixTap: onSuffixTap,
            prefixDartStyle: prefixDartStyle,
            suffixDartStyle: suffixDartStyle,
            togglePassword: togglePassword,
            passwordShowIcon: passwordShowIcon,
            passwordHideIcon: passwordHideIcon,
            validator: validator,
            autovalidateMode: autovalidateMode,
            inputProps: inputProps,
            labelStyle: labelStyle,
            inputStyle: inputStyle,
            labelDartStyle: labelDartStyle,
            inputDartStyle: inputDartStyle,
            controller: controller,
            onChanged: onChanged,
            onBlur: onBlur,
            onSubmitted: onSubmitted,
          ),
        ) {
    if (controller != null && validator != null) {
      controller.validator ??= validator;
    }
  }

  static void _updateDomError({
    required web.HTMLInputElement input,
    required String id,
    required String? errorMsg,
  }) {
    final hasError = errorMsg != null && errorMsg.isNotEmpty;
    final errorId = '$id-error';

    if (hasError) {
      input.setAttribute('aria-invalid', 'true');
      final currentDescribedBy = input.getAttribute('aria-describedby') ?? '';
      if (!currentDescribedBy.contains(errorId)) {
        input.setAttribute(
          'aria-describedby',
          currentDescribedBy.isEmpty ? errorId : '$currentDescribedBy $errorId',
        );
      }
      input.style.borderColor = '#d92d20';
    } else {
      input.removeAttribute('aria-invalid');
      final currentDescribedBy = input.getAttribute('aria-describedby') ?? '';
      final updatedDescribedBy = currentDescribedBy
          .replaceAll(errorId, '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (updatedDescribedBy.isEmpty) {
        input.removeAttribute('aria-describedby');
      } else {
        input.setAttribute('aria-describedby', updatedDescribedBy);
      }
      input.style.borderColor = '';
    }

    final doc = web.document;
    final errorEl = doc.getElementById(errorId);

    if (hasError) {
      if (errorEl != null) {
        errorEl.textContent = errorMsg;
        if (errorEl is web.HTMLElement) {
          errorEl.style.display = 'block';
        }
      } else {
        final wrapper = input.closest('.flint-input-wrapper') ?? input;
        final container = wrapper.parentElement ?? input.parentElement;
        if (container != null) {
          final newError = doc.createElement('p');
          newError.id = errorId;
          newError.textContent = errorMsg;
          newError.setAttribute(
            'style',
            'margin: 0; font-size: 13px; line-height: 1.45; color: #b42318;',
          );
          newError.className = 'flint-field-error';
          container.appendChild(newError);
        }
      }
    } else {
      if (errorEl != null) {
        errorEl.remove();
      }
    }
  }

  static void Function(Object event) _controlledOnChanged({
    TextEditingController? controller,
    void Function(Object event)? onChanged,
    String? Function(String? value)? validator,
    AutovalidateMode autovalidateMode = AutovalidateMode.onUserInteraction,
    required String id,
  }) {
    return (event) {
      final target = event is web.Event ? event.target : null;
      if (target is web.HTMLInputElement) {
        controller?.text = target.value;
        if (validator != null &&
            (autovalidateMode == AutovalidateMode.always ||
                target.getAttribute('aria-invalid') == 'true')) {
          final validationResult = validator(target.value);
          _updateDomError(
            input: target,
            id: id,
            errorMsg: validationResult,
          );
        }
      }
      onChanged?.call(event);
    };
  }

  static void Function(Object event)? _validationBlurHandler({
    void Function(Object event)? onBlur,
    String? Function(String? value)? validator,
    AutovalidateMode autovalidateMode = AutovalidateMode.onUserInteraction,
    required String id,
  }) {
    if (validator == null && onBlur == null) return null;

    return (event) {
      final target = event is web.Event ? event.target : null;
      if (target is web.HTMLInputElement &&
          validator != null &&
          autovalidateMode != AutovalidateMode.disabled) {
        final validationResult = validator(target.value);
        _updateDomError(
          input: target,
          id: id,
          errorMsg: validationResult,
        );
      }
      onBlur?.call(event);
    };
  }

  static void Function(Object event) _passwordToggleHandler({
    void Function(Object event)? onSuffixTap,
  }) {
    return (Object event) {
      if (event is web.MouseEvent) {
        final current = event.currentTarget ?? event.target;
        if (current is web.Element) {
          final wrapper =
              current.closest('.flint-input-wrapper') ?? current.parentElement;
          final input = wrapper?.querySelector('input');
          if (input is web.HTMLInputElement) {
            final isPassword = input.type == 'password';
            input.type = isPassword ? 'text' : 'password';
            final showEl = current.querySelector('.flint-password-show-icon');
            final hideEl = current.querySelector('.flint-password-hide-icon');
            if (showEl is web.HTMLElement && hideEl is web.HTMLElement) {
              showEl.style.display = isPassword ? 'none' : 'inline-flex';
              hideEl.style.display = isPassword ? 'inline-flex' : 'none';
            } else {
              final iconSpan =
                  current.querySelector('.flint-password-icon') ?? current;
              iconSpan.textContent = isPassword ? '🙈' : '👁️';
            }
          }
        }
      }
      onSuffixTap?.call(event);
    };
  }

  static FlintNode _toNode(Object value) {
    return value is FlintNode ? value : FlintText(value.toString());
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
    required Object? prefix,
    required Object? suffix,
    required void Function(Object event)? onPrefixTap,
    required void Function(Object event)? onSuffixTap,
    required DartStyle? prefixDartStyle,
    required DartStyle? suffixDartStyle,
    required bool togglePassword,
    required Object? passwordShowIcon,
    required Object? passwordHideIcon,
    required String? Function(String? value)? validator,
    required AutovalidateMode autovalidateMode,
    required Map<String, Object?> inputProps,
    required Map<String, Object?> labelStyle,
    required Map<String, Object?> inputStyle,
    required DartStyle? labelDartStyle,
    required DartStyle? inputDartStyle,
    required TextEditingController? controller,
    required void Function(Object event)? onChanged,
    required void Function(Object event)? onBlur,
    required void Function(String value)? onSubmitted,
  }) {
    final id = fieldId('field', name, inputProps);
    final ariaDescribedBy = describedBy(
      id: id,
      helpText: helpText,
      error: error,
      describedBy: inputProps['aria-describedby']?.toString(),
    );

    final isPasswordToggle = togglePassword && type == 'password';
    final effectiveSuffix = suffix ??
        (isPasswordToggle
            ? FlintElement(
                'span',
                props: const {
                  'class': 'flint-password-icon',
                  'title': 'Toggle password visibility',
                  'style': {
                    'display': 'inline-flex',
                    'align-items': 'center',
                  },
                },
                children: [
                  FlintElement(
                    'span',
                    props: const {
                      'class': 'flint-password-show-icon',
                      'style': {
                        'display': 'inline-flex',
                        'align-items': 'center',
                      },
                    },
                    children: [_toNode(passwordShowIcon ?? '👁️')],
                  ),
                  FlintElement(
                    'span',
                    props: const {
                      'class': 'flint-password-hide-icon',
                      'style': {
                        'display': 'none',
                        'align-items': 'center',
                      },
                    },
                    children: [_toNode(passwordHideIcon ?? '🙈')],
                  ),
                ],
              )
            : null);
    final effectiveOnSuffixTap = isPasswordToggle
        ? _passwordToggleHandler(onSuffixTap: onSuffixTap)
        : onSuffixTap;

    final hasPrefix = prefix != null;
    final hasSuffix = effectiveSuffix != null;

    final effectiveOnBlur = _validationBlurHandler(
      onBlur: onBlur ?? (inputProps['onBlur'] as void Function(Object)?),
      validator: validator,
      autovalidateMode: autovalidateMode,
      id: id,
    );

    final inputElement = FlintElement(
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
          'onInput': _controlledOnChanged(
            controller: controller,
            onChanged: onChanged,
            validator: validator,
            autovalidateMode: autovalidateMode,
            id: id,
          ),
          if (effectiveOnBlur != null) 'onBlur': effectiveOnBlur,
          if (onSubmitted != null)
            'onKeyDown': (Object event) {
              if (event is web.KeyboardEvent && event.key == 'Enter') {
                event.preventDefault();
                onSubmitted((event.target as web.HTMLInputElement).value);
              }
            },
        },
        defaultStyle: const {'outline': 'none'},
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
            .merge(
              (hasPrefix || hasSuffix)
                  ? DartStyle(
                      padding: EdgeInsets.only(
                        left: hasPrefix ? 38 : 10,
                        right: hasSuffix ? 38 : 10,
                      ),
                    )
                  : null,
            )
            .merge(inputDartStyle),
        style: inputStyle,
      ),
    );

    final FlintNode controlNode;
    if (hasPrefix || hasSuffix) {
      controlNode = FlintElement(
        'div',
        props: const {
          'class': 'flint-input-wrapper',
          'style': {
            'position': 'relative',
            'display': 'flex',
            'align-items': 'center',
            'width': '100%',
          },
        },
        children: [
          if (hasPrefix)
            FlintElement(
              'span',
              props: mergeComponentProps(
                {
                  'class': 'flint-input-prefix',
                  if (onPrefixTap != null) 'onClick': onPrefixTap,
                  'style': {
                    if (onPrefixTap == null) 'pointer-events': 'none',
                    'user-select': 'none',
                  },
                },
                dartStyle: DartStyle(
                  position: Position.absolute,
                  left: 12,
                  display: Display.inlineFlex,
                  alignItems: AlignItems.center,
                  justifyContent: JustifyContent.center,
                  color: ThemeToken.color('mutedText', fallback: '#667085').toCss(),
                  fontSize: 14,
                  zIndex: 2,
                ).merge(prefixDartStyle),
              ),
              children: [
                if (prefix is FlintNode) prefix else FlintText(prefix.toString()),
              ],
            ),
          inputElement,
          if (hasSuffix)
            FlintElement(
              'span',
              props: mergeComponentProps(
                {
                  'class': 'flint-input-suffix',
                  if (effectiveOnSuffixTap != null) 'onClick': effectiveOnSuffixTap,
                  'style': {
                    'user-select': 'none',
                  },
                },
                dartStyle: DartStyle(
                  position: Position.absolute,
                  right: 12,
                  display: Display.inlineFlex,
                  alignItems: AlignItems.center,
                  justifyContent: JustifyContent.center,
                  cursor: effectiveOnSuffixTap != null ? Cursor.pointer : null,
                  color: ThemeToken.color('mutedText', fallback: '#667085').toCss(),
                  fontSize: 14,
                  zIndex: 2,
                ).merge(suffixDartStyle),
              ),
              children: [
                if (effectiveSuffix is FlintNode)
                  effectiveSuffix
                else
                  FlintText(effectiveSuffix.toString()),
              ],
            ),
        ],
      );
    } else {
      controlNode = inputElement;
    }

    return [
      if (label != null)
        fieldLabel(
          id: id,
          label: label,
          required: required,
          dartStyle: labelDartStyle,
          style: labelStyle,
        ),
      controlNode,
      ...fieldMessages(id: id, helpText: helpText, error: error),
    ];
  }
}
