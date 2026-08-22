import 'dart:async';
import '../../component.dart';
import '../../style.dart';
import '../actions/button.dart';
import '../icons/icons.dart';
import '../primitives/container.dart';
import '../primitives/row.dart';
import '../shared/theme.dart';

/// A premium, interactive carousel slider widget.
class Slider extends StatefulComponent {
  /// Creates a slider.
  Slider({
    required this.slides,
    this.height = '480px',
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 5),
    this.transitionDuration = const Duration(milliseconds: 800),
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : _className = className,
       _props = props,
       _style = style,
       _dartStyle = dartStyle;

  /// The list of slide views to cycle through.
  final List<View> slides;

  /// The height of the slider.
  final String height;

  /// Whether the slider cycles slides automatically.
  final bool autoPlay;

  /// The time interval between automated transitions.
  final Duration autoPlayInterval;

  /// The duration of the slide crossfade animation.
  final Duration transitionDuration;

  final String? _className;
  final Map<String, Object?> _props;
  final Map<String, Object?> _style;
  final DartStyle? _dartStyle;

  int _currentIndex = 0;
  Timer? _timer;

  @override
  void didMount() {
    super.didMount();
    _startTimer();
  }

  @override
  void willUnmount() {
    _timer?.cancel();
    super.willUnmount();
  }

  void _startTimer() {
    _timer?.cancel();
    if (autoPlay && slides.length > 1) {
      _timer = Timer.periodic(autoPlayInterval, (timer) {
        nextSlide();
      });
    }
  }

  @override
  void updateFrom(covariant Slider next) {
    // Keep slides list fresh
    if (next.slides.length != slides.length) {
      _currentIndex = 0;
    }
    // If autoPlay parameters changed, restart timer
    if (next.autoPlay != autoPlay ||
        next.autoPlayInterval != autoPlayInterval) {
      _startTimer();
    }
  }

  /// Cycles to the next slide.
  void nextSlide() {
    setState(() {
      if (slides.isNotEmpty) {
        _currentIndex = (_currentIndex + 1) % slides.length;
      }
    });
    _startTimer();
  }

  /// Cycles to the previous slide.
  void prevSlide() {
    setState(() {
      if (slides.isNotEmpty) {
        _currentIndex = (_currentIndex - 1 + slides.length) % slides.length;
      }
    });
    _startTimer();
  }

  /// Manually selects a slide.
  void selectSlide(int index) {
    setState(() {
      _currentIndex = index;
    });
    _startTimer();
  }

  @override
  View build() {
    if (slides.isEmpty) {
      return Container(
        className: _className,
        props: _props,
        style: _style,
        dartStyle: _dartStyle,
        children: const [],
      );
    }

    return Container(
      className: _className,
      props: {..._props, 'role': 'region', 'aria-roledescription': 'carousel'},
      style: _style,
      dartStyle: DartStyle(
        position: Position.relative,
        width: '100%',
        height: height,
        overflow: Overflow.hidden,
        radius: '24px',
        background: '#0f172a',
      ).merge(_dartStyle),
      children: [
        // Slides Stack Container with crossfade animation
        Container(
          dartStyle: const DartStyle(
            position: Position.absolute,
            width: '100%',
            height: '100%',
            left: '0px',
            top: '0px',
          ),
          children: [
            for (int i = 0; i < slides.length; i++)
              Container(
                dartStyle: DartStyle(
                  position: Position.absolute,
                  width: '100%',
                  height: '100%',
                  left: '0px',
                  top: '0px',
                  opacity: _currentIndex == i ? 1.0 : 0.0,
                ),
                style: {
                  'pointer-events': _currentIndex == i ? 'auto' : 'none',
                  'transition':
                      'opacity ${transitionDuration.inMilliseconds}ms ease-in-out',
                },
                children: [slides[i]],
              ),
          ],
        ),

        // Left Navigation Arrow Button
        Button(
          variant: ButtonVariant.ghost,
          onPressed: (_) => prevSlide(),
          dartStyle: const DartStyle(
            position: Position.absolute,
            left: '16px',
            top: '50%',
            transform: 'translateY(-50%)',
            width: '40px',
            height: '40px',
            radius: '20px',
            background: 'rgba(255, 255, 255, 0.25)',
            color: Colors.white,
            display: Display.flex,
            alignItems: AlignItems.center,
            justifyContent: JustifyContent.center,
            padding: EdgeInsets.all(0),
          ),
          style: const {
            'hover': {'background': 'rgba(255, 255, 255, 0.4)'},
            'z-index': '10',
          },
          child: Icon(Icons.chevronLeft, size: 24),
        ),

        // Right Navigation Arrow Button
        Button(
          variant: ButtonVariant.ghost,
          onPressed: (_) => nextSlide(),
          dartStyle: const DartStyle(
            position: Position.absolute,
            right: '16px',
            top: '50%',
            transform: 'translateY(-50%)',
            width: '40px',
            height: '40px',
            radius: '20px',
            background: 'rgba(255, 255, 255, 0.25)',
            color: Colors.white,
            display: Display.flex,
            alignItems: AlignItems.center,
            justifyContent: JustifyContent.center,
            padding: EdgeInsets.all(0),
          ),
          style: const {
            'hover': {'background': 'rgba(255, 255, 255, 0.4)'},
            'z-index': '10',
          },
          child: Icon(Icons.chevronRight, size: 24),
        ),

        // Dots Pagination Indicators
        Row(
          dartStyle: const DartStyle(
            position: Position.absolute,
            bottom: '16px',
            left: '50%',
            transform: 'translateX(-50%)',
            gap: '8px',
            alignItems: AlignItems.center,
          ),
          style: const {'z-index': '10'},
          children: [
            for (int i = 0; i < slides.length; i++)
              Button(
                variant: ButtonVariant.ghost,
                onPressed: (_) => selectSlide(i),
                dartStyle: DartStyle(
                  width: '8px',
                  height: '8px',
                  radius: '4px',
                  background: _currentIndex == i
                      ? '#ffffff'
                      : 'rgba(255, 255, 255, 0.4)',
                  padding: EdgeInsets.all(0),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
