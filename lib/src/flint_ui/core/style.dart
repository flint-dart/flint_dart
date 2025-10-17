// lib/flint_ui/core/style.dart

class TextStyle {
  final double? fontSize;
  final String? color;
  final FontWeight? fontWeight;
  final String? fontFamily;
  final String? backgroundColor;
  final TextDecoration? decoration;
  final double? letterSpacing;
  final double? wordSpacing;
  final double? lineHeight;

  const TextStyle({
    this.fontSize,
    this.color,
    this.fontWeight,
    this.fontFamily,
    this.backgroundColor,
    this.decoration,
    this.letterSpacing,
    this.wordSpacing,
    this.lineHeight,
  });

  TextStyle copyWith({
    double? fontSize,
    String? color,
    FontWeight? fontWeight,
    String? fontFamily,
    String? backgroundColor,
    TextDecoration? decoration,
    double? letterSpacing,
    double? wordSpacing,
    double? lineHeight,
  }) {
    return TextStyle(
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      fontWeight: fontWeight ?? this.fontWeight,
      fontFamily: fontFamily ?? this.fontFamily,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      decoration: decoration ?? this.decoration,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }

  Map<String, dynamic> toJson() => {
        if (fontSize != null) 'fontSize': fontSize,
        if (color != null) 'color': color,
        if (fontWeight != null) 'fontWeight': fontWeight!.name,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        if (decoration != null) 'decoration': decoration!.name,
        if (letterSpacing != null) 'letterSpacing': letterSpacing,
        if (wordSpacing != null) 'wordSpacing': wordSpacing,
        if (lineHeight != null) 'lineHeight': lineHeight,
      };
}

enum FontWeight {
  w100(100),
  w200(200),
  w300(300),
  w400(400),
  w500(500),
  w600(600),
  w700(700),
  w800(800),
  w900(900),
  normal(400),
  bold(700);

  final int value;
  const FontWeight(this.value);
}

enum TextDecoration {
  none('none'),
  underline('underline'),
  overline('overline'),
  lineThrough('line-through');

  final String cssValue;
  const TextDecoration(this.cssValue);

  String toCss() => cssValue;
}

enum TextAlign {
  left('left'),
  center('center'),
  right('right'),
  justify('justify'),
  start('start'),
  end('end');

  final String cssValue;
  const TextAlign(this.cssValue);

  String toCss() => cssValue;
}

enum TextOverflow {
  clip,
  ellipsis,
  fade,
}
