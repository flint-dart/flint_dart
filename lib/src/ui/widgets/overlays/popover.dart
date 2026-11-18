import '../../component.dart';
import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Inline popover with trigger content and floating dialog content.
class Popover extends StatelessComponent {
  /// Creates a popover controlled by [open].
  Popover({
    required this.trigger,
    this.child,
    this.children = const [],
    this.open = false,
    this.placement = 'bottom',
    this.className,
    this.props = const {},
    this.style = const {},
    this.dartStyle,
    this.panelClassName,
    this.panelStyle = const {},
    this.panelDartStyle,
  });

  final Object trigger;
  final Object? child;
  final List<Object?> children;
  final bool open;
  final String placement;
  final String? className;
  final String? panelClassName;
  @override
  final Map<String, Object?> props;
  final Map<String, Object?> style;
  final Map<String, Object?> panelStyle;
  final DartStyle? dartStyle;
  final DartStyle? panelDartStyle;

  @override
  View build() {
    return FlintElement(
      'span',
      props: mergeComponentProps(
        props,
        className: className,
        defaultStyle: const {'position': 'relative', 'display': 'inline-flex'},
        dartStyle: dartStyle,
        style: style,
      ),
      children: [
        toFlintNode(trigger),
        // Closed overlays must unmount instead of relying on `hidden`, so the
        // floating panel cannot keep stale geometry or interactive DOM around.
        if (open)
          FlintElement(
            'div',
            props: mergeComponentProps(
              {
                'role': 'dialog',
                'data-placement': placement,
              },
              className: panelClassName,
              defaultStyle: const {
                'position': 'absolute',
                'z-index': 30,
                'min-width': '220px',
                'padding': '12px',
                'border': '1px solid var(--color-surfaceBorder, #e4e7ec)',
                'border-radius': '8px',
                'background': 'var(--color-surface, #ffffff)',
                'color': 'var(--color-text, #0f172a)',
                'box-shadow': '0 12px 24px rgba(16, 24, 40, 0.14)',
              },
              dartStyle: panelDartStyle,
              style: panelStyle,
            ),
            children: normalizeChildren(child, children),
          ),
      ],
    );
  }
}
