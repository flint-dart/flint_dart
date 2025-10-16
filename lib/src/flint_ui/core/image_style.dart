// lib/flint_ui/core/image_style.dart

class ImageStyle {
  final double? opacity;
  final String? filter;
  final ObjectFit fit;
  final String? title;
  final ImageDecoding? decoding;

  const ImageStyle({
    this.opacity,
    this.filter,
    this.fit = ObjectFit.contain,
    this.title,
    this.decoding,
  });

  ImageStyle copyWith({
    double? opacity,
    String? filter,
    ObjectFit? fit,
    String? title,
    ImageDecoding? decoding,
  }) {
    return ImageStyle(
      opacity: opacity ?? this.opacity,
      filter: filter ?? this.filter,
      fit: fit ?? this.fit,
      title: title ?? this.title,
      decoding: decoding ?? this.decoding,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (opacity != null) 'opacity': opacity,
      if (filter != null) 'filter': filter,
      'fit': fit.name,
      if (title != null) 'title': title,
      if (decoding != null) 'decoding': decoding?.name,
    };
  }
}

enum ObjectFit {
  fill('fill'),
  contain('contain'),
  cover('cover'),
  none('none'),
  scaleDown('scale-down');

  final String cssValue;
  const ObjectFit(this.cssValue);

  String toCss() => cssValue;
}

enum ImageDecoding {
  sync('sync'),
  async('async'),
  auto('auto');

  final String value;
  const ImageDecoding(this.value);
}
