import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../feedback/spinner.dart';
import '../shared/theme.dart';

/// Semantic button with Flint UI variants, tones, sizes, and loading state.
class Button extends FlintElement {
  /// Creates a button with optional child content and click handling.
  Button({
    Object? child,
    String? label,
    List<Object?> children = const [],
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    ButtonVariant variant = ButtonVariant.solid,
    Tone tone = Tone.primary,
    ComponentSize size = ComponentSize.md,
    bool loading = false,
    bool disabled = false,
    void Function(Object event)? onPressed,
    Function? onClick,
  }) : super(
          'button',
          props: mergeComponentProps(
            {
              ...props,
              'type': props['type'] ?? 'button',
              if (disabled || loading) 'disabled': true,
              if (loading) 'aria-busy': 'true',
              if ((onPressed != null || onClick != null) &&
                  !disabled &&
                  !loading)
                'onClick': onPressed ?? _normalizeClickHandler(onClick),
            },
            className: className,
            dartStyle: buttonComponentStyle(
              variant: variant,
              tone: tone,
              size: size,
              disabled: disabled,
              loading: loading,
            ).merge(dartStyle),
            style: style,
          ),
          children: [
            if (loading) Spinner(size: ComponentSize.xs, tone: tone),
            ...normalizeChildren(child ?? label, children),
          ],
        );
}

void Function(Object event)? _normalizeClickHandler(Function? handler) {
  if (handler == null) return null;
  if (handler is void Function(Object)) return handler;
  return (event) {
    if (handler is void Function()) {
      handler();
    } else {
      (handler as dynamic)(event);
    }
  };
}
