import '../../component.dart';
import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Modal dialog overlay with optional header, close action, and footer actions.
class Modal extends StatelessComponent {
  /// Creates a modal dialog controlled by [open].
  Modal({
    required this.open,
    this.title,
    this.child,
    this.children = const [],
    this.actions,
    this.size = 'md',
    this.className,
    this.props = const {},
    this.style = const {},
    this.dartStyle,
    this.onClose,
    this.closeOnBackdrop = true,
  });

  final bool open;
  final String? title;
  final Object? child;
  final List<Object?> children;
  final Object? actions;
  final String size;
  final String? className;
  final Map<String, Object?> props;
  final Map<String, Object?> style;
  final DartStyle? dartStyle;
  final void Function(Object event)? onClose;
  final bool closeOnBackdrop;

  @override
  View build() {
    // Closed overlays must unmount instead of relying on the HTML `hidden`
    // attribute. Inline layout styles such as display:grid can fight hidden in
    // browsers, and a mounted backdrop can still trap clicks/focus.
    if (!open) return const FlintFragment([]);

    return FlintElement(
      'div',
      props: mergeComponentProps(
        {
          ...props,
          'role': 'dialog',
          'aria-modal': 'true',
          if (title != null) 'aria-label': title,
          if (onClose != null && closeOnBackdrop) 'onClick': onClose,
        },
        className: className,
        defaultStyle: const {
          'position': 'fixed',
          'inset': 0,
          'z-index': 1000,
          'display': 'grid',
          'place-items': 'center',
          'padding': '20px',
          'background': 'rgba(2, 6, 23, 0.62)',
          'backdrop-filter': 'blur(8px)',
        },
        dartStyle: dartStyle,
        style: style,
      ),
      children: [
        FlintElement(
          'section',
          props: {
            if (onClose != null && closeOnBackdrop) 'onClick': _stopPropagation,
            'style': {
              'width': '100%',
              'max-width': _modalWidth(size),
              'border-radius': '8px',
              'border':
                  '1px solid var(--flint-color-line, var(--flint-color-surfaceBorder, #e4e7ec))',
              'background':
                  'var(--flint-color-panel, var(--flint-color-surface, #ffffff))',
              'color':
                  'var(--flint-color-ink, var(--flint-color-text, #0f172a))',
              'box-shadow': '0 24px 56px rgba(0, 0, 0, 0.28)',
              'overflow': 'hidden',
            },
          },
          children: [
            if (title != null || onClose != null)
              FlintElement(
                'header',
                props: const {
                  'style': {
                    'display': 'flex',
                    'align-items': 'center',
                    'justify-content': 'space-between',
                    'gap': '12px',
                    'padding': '16px',
                    'border-bottom':
                        '1px solid var(--flint-color-line, var(--flint-color-surfaceBorder, #e4e7ec))',
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
                        'style': {
                          'width': '32px',
                          'height': '32px',
                          'border-radius': '8px',
                          'border':
                              '1px solid var(--flint-color-line, var(--flint-color-surfaceBorder, #e4e7ec))',
                          'background':
                              'var(--flint-color-panelMuted, var(--flint-color-surfaceMuted, #f8fafc))',
                          'color':
                              'var(--flint-color-ink, var(--flint-color-text, #0f172a))',
                          'cursor': 'pointer',
                        },
                      },
                      children: const [FlintText('x')],
                    ),
                ],
              ),
            FlintElement(
              'div',
              props: const {
                'style': {'padding': '16px'},
              },
              children: normalizeChildren(child, children),
            ),
            if (actions != null)
              FlintElement(
                'footer',
                props: const {
                  'style': {
                    'display': 'flex',
                    'justify-content': 'flex-end',
                    'gap': '8px',
                    'padding': '16px',
                    'border-top':
                        '1px solid var(--flint-color-line, var(--flint-color-surfaceBorder, #e4e7ec))',
                  },
                },
                children: [toFlintNode(actions)],
              ),
          ],
        ),
      ],
    );
  }
}

String _modalWidth(String size) {
  return switch (size) {
    'sm' => '360px',
    'lg' => '720px',
    'xl' => '960px',
    _ => '520px',
  };
}

void _stopPropagation(Object event) {
  try {
    (event as dynamic).stopPropagation();
  } catch (_) {
    // Non-browser renderers do not expose DOM event helpers.
  }
}
