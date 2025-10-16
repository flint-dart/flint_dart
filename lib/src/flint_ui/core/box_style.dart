// lib/flint_ui/core/box_style.dart

class BoxConstraints {
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;

  const BoxConstraints({
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
  });

  static BoxConstraints tightFor({
    double? width,
    double? height,
  }) =>
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        minHeight: height,
        maxHeight: height,
      );

  static const BoxConstraints expand = BoxConstraints(
    minWidth: double.infinity,
    minHeight: double.infinity,
  );

  Map<String, dynamic> toJson() => {
        if (minWidth != null) 'minWidth': minWidth,
        if (maxWidth != null) 'maxWidth': maxWidth,
        if (minHeight != null) 'minHeight': minHeight,
        if (maxHeight != null) 'maxHeight': maxHeight,
      };
}

class BoxBorder {
  final double width;
  final String color;
  final BorderStyle style;

  const BoxBorder({
    this.width = 1.0,
    this.color = '#000000',
    this.style = BorderStyle.solid,
  });

  const BoxBorder.none() : this(width: 0.0);

  String toCss() =>
      style == BorderStyle.none ? 'none' : '${width}px $style $color';

  Map<String, dynamic> toJson() => {
        'width': width,
        'color': color,
        'style': style.name,
      };

  static all({
    required String color,
    double? width,
  }) {}
}

enum BorderStyle {
  none('none'),
  solid('solid'),
  dashed('dashed'),
  dotted('dotted');

  final String cssValue;
  const BorderStyle(this.cssValue);
}

class BorderRadius {
  final double topLeft;
  final double topRight;
  final double bottomRight;
  final double bottomLeft;

  const BorderRadius.all(double radius)
      : topLeft = radius,
        topRight = radius,
        bottomRight = radius,
        bottomLeft = radius;

  const BorderRadius.only({
    this.topLeft = 0,
    this.topRight = 0,
    this.bottomRight = 0,
    this.bottomLeft = 0,
  });

  const BorderRadius.circular(double radius) : this.all(radius);

  static const BorderRadius zero = BorderRadius.all(0);

  String toCss() => '${topLeft}px $topRight\px $bottomRight\px $bottomLeft\px';

  Map<String, dynamic> toJson() => {
        'topLeft': topLeft,
        'topRight': topRight,
        'bottomRight': bottomRight,
        'bottomLeft': bottomLeft,
      };
}

class BoxShadow {
  final double offsetX;
  final double offsetY;
  final double blurRadius;
  final double spreadRadius;
  final String color;
  final ShadowPosition position;

  const BoxShadow({
    this.offsetX = 0,
    this.offsetY = 2,
    this.blurRadius = 4,
    this.spreadRadius = 0,
    this.color = 'rgba(0, 0, 0, 0.1)',
    this.position = ShadowPosition.outer,
  });

  String toCss() =>
      '${offsetX}px $offsetY\px $blurRadius\px $spreadRadius\px $color';

  Map<String, dynamic> toJson() => {
        'offsetX': offsetX,
        'offsetY': offsetY,
        'blurRadius': blurRadius,
        'spreadRadius': spreadRadius,
        'color': color,
        'position': position.name,
      };
}

enum ShadowPosition {
  outer,
  inner,
}

enum BoxAlignment {
  start('left'),
  center('center'),
  end('right'),
  stretch('stretch');

  final String cssValue;
  const BoxAlignment(this.cssValue);

  String toCss() => cssValue;
}

class BoxDecoration {
  final String? semanticLabel;
  final Gradient? gradient;
  final String? backgroundImage;

  const BoxDecoration({
    this.semanticLabel,
    this.gradient,
    this.backgroundImage,
  });

  Map<String, dynamic> toJson() => {
        if (semanticLabel != null) 'semanticLabel': semanticLabel,
        if (gradient != null) 'gradient': gradient!.toJson(),
        if (backgroundImage != null) 'backgroundImage': backgroundImage,
      };
}

class Gradient {
  final List<ColorStop> stops;
  final GradientDirection direction;

  const Gradient.linear({
    required this.stops,
    this.direction = GradientDirection.toBottom,
  });

  String toCss() {
    final stopColors = stops.map((stop) => stop.toCss()).join(', ');
    return 'linear-gradient(${direction.cssValue}, $stopColors)';
  }

  Map<String, dynamic> toJson() => {
        'stops': stops.map((stop) => stop.toJson()).toList(),
        'direction': direction.name,
      };
}

class ColorStop {
  final String color;
  final double stop;

  const ColorStop(this.color, this.stop);

  String toCss() => '$color ${stop * 100}%';

  Map<String, dynamic> toJson() => {
        'color': color,
        'stop': stop,
      };
}

enum GradientDirection {
  toBottom('to bottom'),
  toTop('to top'),
  toRight('to right'),
  toLeft('to left'),
  toBottomRight('to bottom right');

  final String cssValue;
  const GradientDirection(this.cssValue);
}
