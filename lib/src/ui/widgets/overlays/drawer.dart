import '../../component.dart';
import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Slide-out dialog panel anchored to the left or right side.
class Drawer extends StatelessComponent {
  /// Creates a drawer controlled by [open].
  Drawer({
    required this.open,
    this.title,
    this.child,
    this.children = const [],
    this.side = 'right',
    this.className,
    this.props = const {},
    this.style = const {},
    this.dartStyle,
    this.onClose,
  });

  final bool open;
  final String? title;
  final Object? child;
  final List<Object?> children;
  final String side;
  final String? className;
  final Map<String, Object?> props;
  final Map<String, Object?> style;
  final DartStyle? dartStyle;
  final void Function(Object event)? onClose;

  @override
  View build() {
    // Closed overlays must unmount instead of relying on `hidden`, so they
    // cannot keep focus, trap clicks, or survive browser display quirks.
    if (!open) return const FlintFragment([]);

    return FlintElement(
      'aside',
      props: mergeComponentProps(
        {
          ...props,
          'role': 'dialog',
          'aria-modal': 'true',
          if (title != null) 'aria-label': title,
        },
        className: className,
        defaultStyle: {
          'position': 'fixed',
          'top': 0,
          'bottom': 0,
          side == 'left' ? 'left' : 'right': 0,
          'z-index': 1000,
          'width': '380px',
          'max-width': '100%',
          'background': '#ffffff',
          'box-shadow': '0 20px 40px rgba(16, 24, 40, 0.18)',
          'display': 'grid',
          'grid-template-rows': 'auto minmax(0, 1fr)',
        },
        dartStyle: dartStyle,
        style: style,
      ),
      children: [
        if (title != null || onClose != null)
          FlintElement(
            'header',
            props: const {
              'style': {
                'padding': '16px',
                'border-bottom': '1px solid #e4e7ec',
              },
            },
            children: [
              if (title != null) FlintText(title!),
              if (onClose != null)
                FlintElement(
                  'button',
                  props: {
                    'type': 'button',
                    'aria-label': 'Close',
                    'onClick': onClose,
                  },
                  children: const [FlintText('x')],
                ),
            ],
          ),
        FlintElement(
          'div',
          props: const {
            'style': {'padding': '16px', 'overflow': 'auto'},
          },
          children: normalizeChildren(child, children),
        ),
      ],
    );
  }
}
