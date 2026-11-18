import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Direction for slide-in animation.
enum SlideDirection { top, bottom, left, right }

/// AnimatedContainer automatically transitions style changes (background, padding, radius, width, height, opacity).
class AnimatedContainer extends FlintElement {
  /// Creates an animated container with custom duration and curve.
  AnimatedContainer({
    Object? child,
    List<Object?> children = const [],
    Duration duration = const Duration(milliseconds: 300),
    String curve = 'cubic-bezier(0.16, 1, 0.3, 1)',
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
          'div',
          props: mergeComponentProps(
            props,
            className: className,
            defaultStyle: {
              'transition': 'all ${duration.inMilliseconds}ms $curve',
            },
            dartStyle: dartStyle,
            style: style,
          ),
          children: normalizeChildren(child, children),
        );
}

/// FadeIn smoothly transitions opacity from 0 to 1 on mount.
class FadeIn extends FlintElement {
  /// Creates a fade-in animation widget.
  FadeIn({
    Object? child,
    List<Object?> children = const [],
    Duration duration = const Duration(milliseconds: 400),
    Duration delay = Duration.zero,
    String curve = 'ease-out',
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
          'div',
          props: mergeComponentProps(
            props,
            className: className,
            defaultStyle: {
              'animation':
                  'flint-fade-in ${duration.inMilliseconds}ms $curve ${delay.inMilliseconds}ms both',
            },
            dartStyle: dartStyle,
            style: style,
          ),
          children: normalizeChildren(child, children),
        );
}

/// SlideIn slides and fades content from a given direction on mount.
class SlideIn extends FlintElement {
  /// Creates a slide-in animation widget.
  SlideIn({
    Object? child,
    List<Object?> children = const [],
    SlideDirection direction = SlideDirection.bottom,
    Duration duration = const Duration(milliseconds: 400),
    Duration delay = Duration.zero,
    String curve = 'cubic-bezier(0.16, 1, 0.3, 1)',
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
          'div',
          props: mergeComponentProps(
            props,
            className: className,
            defaultStyle: {
              'animation':
                  '${_animName(direction)} ${duration.inMilliseconds}ms $curve ${delay.inMilliseconds}ms both',
            },
            dartStyle: dartStyle,
            style: style,
          ),
          children: normalizeChildren(child, children),
        );

  static String _animName(SlideDirection dir) {
    switch (dir) {
      case SlideDirection.top:
        return 'flint-slide-down';
      case SlideDirection.bottom:
        return 'flint-slide-up';
      case SlideDirection.left:
        return 'flint-fade-in';
      case SlideDirection.right:
        return 'flint-fade-in';
    }
  }
}

/// ScaleIn smoothly scales content from 0.95 to 1 on mount.
class ScaleIn extends FlintElement {
  /// Creates a scale-in animation widget.
  ScaleIn({
    Object? child,
    List<Object?> children = const [],
    Duration duration = const Duration(milliseconds: 300),
    Duration delay = Duration.zero,
    String curve = 'cubic-bezier(0.16, 1, 0.3, 1)',
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
          'div',
          props: mergeComponentProps(
            props,
            className: className,
            defaultStyle: {
              'animation':
                  'flint-scale-in ${duration.inMilliseconds}ms $curve ${delay.inMilliseconds}ms both',
            },
            dartStyle: dartStyle,
            style: style,
          ),
          children: normalizeChildren(child, children),
        );
}
