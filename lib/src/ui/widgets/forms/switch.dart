import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import 'field_helpers.dart';
import 'validation.dart';

/// Toggle switch field with native checkbox behavior and ARIA switch semantics.
class Switch extends FlintElement {
  /// Creates a switch field.
  Switch({
    String? label,
    String? name,
    bool checked = false,
    bool disabled = false,
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
    required String? error,
    required String? helpText,
    required Map<String, Object?> inputProps,
    required void Function(Object event)? onChanged,
  }) {
    final id = fieldId('switch', name, inputProps);
    final ariaDescribedBy = describedBy(
      id: id,
      helpText: helpText,
      error: error,
      describedBy: inputProps['aria-describedby']?.toString(),
    );

    return [
      FlintElement(
        'label',
        props: mergeComponentProps(
          {'for': id},
          defaultStyle: switchRowStyle,
          style: disabled ? switchDisabledStyle : const {},
        ),
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
              'role': 'switch',
              'aria-checked': checked.toString(),
              'style': switchInputStyle,
              if (checked) 'checked': true,
              if (onChanged != null) 'onChange': onChanged,
            },
          ),
          FlintElement(
            'span',
            props: {
              'aria-hidden': 'true',
              'style': checked ? switchTrackOnStyle : switchTrackOffStyle,
            },
            children: [
              FlintElement(
                'span',
                props: {
                  'style': checked ? switchThumbOnStyle : switchThumbOffStyle,
                },
              ),
            ],
          ),
          if (label != null) FlintText(label),
        ],
      ),
      ...fieldMessages(id: id, helpText: helpText, error: error),
    ];
  }
}

/// Default inline row style for switch controls.
const switchRowStyle = {
  'display': 'inline-flex',
  'align-items': 'center',
  'gap': '10px',
  'font-size': '14px',
  'font-weight': 600,
  'color': '#344054',
  'cursor': 'pointer',
  'user-select': 'none',
};

/// Disabled switch row treatment.
const switchDisabledStyle = {'opacity': 0.6, 'cursor': 'not-allowed'};

/// Visually hides the native checkbox while keeping it interactive.
const switchInputStyle = {
  'position': 'absolute',
  'width': '1px',
  'height': '1px',
  'margin': 0,
  'opacity': 0,
  'pointer-events': 'none',
};

const _trackBaseStyle = {
  'position': 'relative',
  'display': 'inline-flex',
  'align-items': 'center',
  'width': '42px',
  'height': '24px',
  'padding': '2px',
  'border-radius': '999px',
  'transition': 'background 160ms ease, box-shadow 160ms ease',
  'box-sizing': 'border-box',
  'flex': '0 0 auto',
};

/// Track style for enabled switches.
const switchTrackOnStyle = {
  ..._trackBaseStyle,
  'background': '#111827',
  'box-shadow': '0 8px 18px -12px rgba(17, 24, 39, 0.75)',
};

/// Track style for disabled/off switches.
const switchTrackOffStyle = {
  ..._trackBaseStyle,
  'background': '#e5e7eb',
  'box-shadow': 'inset 0 0 0 1px rgba(15, 23, 42, 0.08)',
};

const _thumbBaseStyle = {
  'display': 'block',
  'width': '20px',
  'height': '20px',
  'border-radius': '999px',
  'background': '#ffffff',
  'box-shadow': '0 3px 8px rgba(15, 23, 42, 0.22)',
  'transition': 'transform 160ms ease',
};

/// Thumb style for enabled switches.
const switchThumbOnStyle = {
  ..._thumbBaseStyle,
  'transform': 'translateX(18px)',
};

/// Thumb style for disabled/off switches.
const switchThumbOffStyle = {..._thumbBaseStyle, 'transform': 'translateX(0)'};
