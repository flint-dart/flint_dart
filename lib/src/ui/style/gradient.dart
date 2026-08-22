part of '../style.dart';

/// CSS gradient value for typed backgrounds.
class Gradient {
  /// CSS gradient string.
  final String value;

  /// Creates a gradient from a raw CSS [value].
  const Gradient(this.value);

  /// Creates a `linear-gradient(...)` from [angle] and color stops.
  factory Gradient.linear(num angle, List<Object> stops) {
    return Gradient(
      'linear-gradient(${angle}deg, ${stops.map(_gradientStopValue).join(', ')})',
    );
  }

  /// Creates a directional `linear-gradient(to ..., ...)`.
  factory Gradient.linearTo(Object direction, List<Object> stops) {
    return Gradient(
      'linear-gradient(to ${cssValue(direction, unitlessNumber: true)}, ${stops.map(_gradientStopValue).join(', ')})',
    );
  }

  /// Creates an evenly distributed linear gradient from colors.
  factory Gradient.linearColors(num angle, List<Object> colors) {
    if (colors.isEmpty) {
      throw ArgumentError.value(colors, 'colors', 'Must not be empty.');
    }
    final lastIndex = colors.length - 1;
    final stops = [
      for (var index = 0; index < colors.length; index++)
        GradientStop(
          colors[index],
          lastIndex == 0 ? 0 : (index / lastIndex) * 100,
        ),
    ];

    return Gradient.linear(angle, stops);
  }

  /// Creates a `radial-gradient(...)` from [shape] and color stops.
  factory Gradient.radial(String shape, List<Object> stops) {
    return Gradient(
      'radial-gradient($shape, ${stops.map(_gradientStopValue).join(', ')})',
    );
  }

  /// Creates a circular radial gradient.
  factory Gradient.radialCircle({Object? at, required List<Object> stops}) {
    final shape = at == null ? 'circle' : 'circle at ${cssValue(at)}';
    return Gradient.radial(shape, stops);
  }

  /// Returns the CSS gradient string.
  @override
  String toString() => value;
}

/// Direction keyword for directional linear gradients.
class GradientDirection {
  /// CSS direction string without the leading `to`.
  final String value;

  /// Creates a direction from a raw CSS [value].
  const GradientDirection(this.value);

  static const top = GradientDirection('top');
  static const right = GradientDirection('right');
  static const bottom = GradientDirection('bottom');
  static const left = GradientDirection('left');
  static const topLeft = GradientDirection('top left');
  static const topRight = GradientDirection('top right');
  static const bottomLeft = GradientDirection('bottom left');
  static const bottomRight = GradientDirection('bottom right');

  /// Returns the CSS direction string.
  @override
  String toString() => value;
}

/// CSS background value that can combine multiple layers.
class Background {
  /// CSS background string.
  final String value;

  /// Creates a background from a raw CSS [value].
  const Background(this.value);

  /// Creates a comma-separated layered background.
  factory Background.layers(List<Object> layers) {
    if (layers.isEmpty) {
      throw ArgumentError.value(layers, 'layers', 'Must not be empty.');
    }
    return Background(layers.map(cssValue).join(', '));
  }

  /// Returns the CSS background string.
  @override
  String toString() => value;
}

/// Position value used by radial gradients.
class GradientPosition {
  /// CSS position string.
  final String value;

  /// Creates a gradient position from a raw CSS [value].
  const GradientPosition(this.value);

  /// Creates a percentage-based gradient position.
  const GradientPosition.percent(num x, num y) : value = '$x% $y%';

  /// Top-left gradient position.
  static const topLeft = GradientPosition('top left');

  /// Top-right gradient position.
  static const topRight = GradientPosition('top right');

  /// Bottom-left gradient position.
  static const bottomLeft = GradientPosition('bottom left');

  /// Bottom-right gradient position.
  static const bottomRight = GradientPosition('bottom right');

  /// Center gradient position.
  static const center = GradientPosition('center');

  /// Returns the CSS position string.
  @override
  String toString() => value;
}

/// Typed CSS `flex` shorthand value.
class FlexValue {
  /// CSS `flex-grow` component.
  final Object grow;

  /// CSS `flex-shrink` component.
  final Object shrink;

  /// CSS `flex-basis` component.
  final Object basis;

  /// Creates a custom flex shorthand value.
  const FlexValue(this.grow, this.shrink, this.basis);

  /// Creates `1 1 0%` by default.
  const FlexValue.grow([this.grow = 1]) : shrink = 1, basis = '0%';

  /// Creates `1 1 auto`.
  const FlexValue.auto() : grow = 1, shrink = 1, basis = 'auto';

  /// Creates `0 0 auto`.
  const FlexValue.none() : grow = 0, shrink = 0, basis = 'auto';

  /// Creates `1 1 auto`.
  const FlexValue.fill() : grow = 1, shrink = 1, basis = 'auto';

  /// Converts this shorthand to a CSS `flex` value.
  String toCss() {
    return [
      cssValue(grow, unitlessNumber: true),
      cssValue(shrink, unitlessNumber: true),
      cssValue(basis),
    ].join(' ');
  }

  /// Returns the CSS `flex` value.
  @override
  String toString() => toCss();
}

/// Color stop used in typed gradient factories.
class GradientStop {
  /// Stop color.
  final Object color;

  /// Optional stop position.
  final Object? position;

  /// Creates a gradient stop from a [color] and optional [position].
  const GradientStop(this.color, [this.position]);

  /// Converts this stop to a CSS gradient stop.
  String toCss() {
    final colorValue = cssValue(color);
    if (position == null) return colorValue;
    return '$colorValue ${_gradientPositionValue(position)}';
  }
}

String _gradientStopValue(Object stop) {
  if (stop is GradientStop) return stop.toCss();
  return cssValue(stop);
}

String _gradientPositionValue(Object? position) {
  if (position is num) {
    final value = position % 1 == 0 ? position.toInt() : position;
    return '$value%';
  }
  return cssValue(position);
}

/// Built-in gradients for Flint UI examples and components.
class Gradients {
  /// Prevents creating a gradient token container.
  const Gradients._();

  /// Blue ocean linear gradient.
  static const ocean = Gradient(
    'linear-gradient(135deg, #0ea5e9 0%, #2563eb 58%, #1d4ed8 100%)',
  );

  /// Blue-to-sky linear gradient.
  static const sky = Gradient(
    'linear-gradient(135deg, #2563eb 0%, #0ea5e9 100%)',
  );

  /// Layered soft panel background gradient.
  static const softPanel = Gradient(
    'radial-gradient(circle at top left, rgba(56, 189, 248, 0.22), transparent 34%), '
    'radial-gradient(circle at bottom right, rgba(37, 99, 235, 0.18), transparent 32%), '
    'linear-gradient(135deg, #f8fbff 0%, #eef6ff 44%, #ffffff 100%)',
  );
}
