import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../shared/theme.dart';

/// Anchor element with optional button-style variants.
class Link extends FlintElement {
  /// Creates a link to [href] with optional content and styles.
  Link({
    required String href,
    Object? child,
    List<Object?> children = const [],
    String? target,
    String? rel,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    ButtonVariant? variant,
    Tone tone = Tone.primary,
    ComponentSize size = ComponentSize.md,
    bool disabled = false,
  }) : super(
         'a',
         props: mergeComponentProps(
           {
             ...props,
             'href': href,
             if (target != null) 'target': target,
             if (rel != null) 'rel': rel,
             if (disabled) 'aria-disabled': 'true',
           },
           className: className,
           dartStyle: variant == null
               ? dartStyle
               : buttonComponentStyle(
                   variant: variant,
                   tone: tone,
                   size: size,
                   disabled: disabled,
                   loading: false,
                 ).merge(dartStyle),
           style: style,
         ),
         children: normalizeChildren(child, children),
       );
}
