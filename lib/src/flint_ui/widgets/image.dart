// lib/flint_ui/widgets/image.dart

import 'package:flint_dart/src/flint_ui/core/core.dart';

class FlintImage extends FlintWidget {
  final String src;
  final String? alt;
  final double? width;
  final double? height;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final String? alignment;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final BoxShadow? shadow;
  final ImageStyle style;
  final String? caption;
  final bool lazyLoading;
  final String? linkUrl;

  FlintImage({
    required this.src,
    this.alt,
    this.width,
    this.height,
    this.margin,
    this.padding,
    this.alignment,
    this.border,
    this.borderRadius,
    this.shadow,
    this.style = const ImageStyle(),
    this.caption,
    this.lazyLoading = false,
    this.linkUrl,
  });

  @override
  String toHtml() {
    final imageHtml = _buildImageHtml();

    if (linkUrl != null) {
      return _buildImageWithLink(imageHtml);
    }

    if (caption != null) {
      return _buildImageWithCaption(imageHtml);
    }

    return _wrapWithContainer(imageHtml);
  }

  @override
  String toText() {
    final altText = alt ?? 'Image';
    final captionText = caption != null ? ' - $caption' : '';
    final linkText = linkUrl != null ? ' ($linkUrl)' : '';

    return '[Image: $altText$captionText]$linkText';
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'image',
      'src': src,
      'alt': alt,
      'width': width,
      'height': height,
      'margin': margin?.toJson(),
      'padding': padding?.toJson(),
      'alignment': alignment,
      'border': border?.toJson(),
      'borderRadius': borderRadius?.toJson(),
      'shadow': shadow?.toJson(),
      'style': style.toJson(),
      'caption': caption,
      'lazyLoading': lazyLoading,
      'linkUrl': linkUrl,
    };
  }

  @override
  FlintWidget buildTemplate() {
    // For images, we return self since we're a leaf widget
    return this;
  }

  String _buildImageHtml() {
    final styles = <String>[
      if (width != null) 'width: ${width}px;',
      if (height != null) 'height: ${height}px;',
      'max-width: 100%;',
      'height: auto;',
      'display: block;',
      if (border != null) 'border: ${border!.toCss()};',
      if (borderRadius != null) 'border-radius: ${borderRadius!.toCss()};',
      if (shadow != null) 'box-shadow: ${shadow!.toCss()};',
      if (style.opacity != null) 'opacity: ${style.opacity};',
      if (style.filter != null) 'filter: ${style.filter};',
      'object-fit: ${style.fit.toCss()};',
    ];

    final attributes = <String>[
      'src="$src"',
      if (alt != null) 'alt="${_escapeHtml(alt!)}"',
      if (style.title != null) 'title="${_escapeHtml(style.title!)}"',
      'style="${styles.join(' ')}"',
      if (lazyLoading) 'loading="lazy"',
      if (style.decoding != null) 'decoding="${style.decoding!.value}"',
    ];

    return '<img ${attributes.join(' ')} />';
  }

  String _buildImageWithLink(String imageHtml) {
    final linkStyles = <String>[
      'display: inline-block;',
      'text-decoration: none;',
      if (border != null) 'border: ${border!.toCss()};',
      if (borderRadius != null) 'border-radius: ${borderRadius!.toCss()};',
    ];

    return '''
<a href="$linkUrl" style="${linkStyles.join(' ')}" target="_blank">
  $imageHtml
</a>
''';
  }

  String _buildImageWithCaption(String imageHtml) {
    final captionStyles = <String>[
      'font-size: 14px;',
      'color: #666666;',
      'text-align: ${alignment ?? 'center'};',
      'margin-top: 8px;',
      'font-style: italic;',
    ];

    return '''
<figure style="margin: 0; display: inline-block;">
  $imageHtml
  <figcaption style="${captionStyles.join(' ')}">
    ${_escapeHtml(caption!)}
  </figcaption>
</figure>
''';
  }

  String _wrapWithContainer(String content) {
    final containerStyles = <String>[
      'display: inline-block;',
      if (margin != null) 'margin: ${margin!.toCss()};',
      if (padding != null) 'padding: ${padding!.toCss()};',
      if (alignment != null) 'text-align: $alignment;',
      if (width != null) 'max-width: ${width}px;',
    ];

    if (containerStyles.isEmpty) {
      return content;
    }

    return '''
<div style="${containerStyles.join(' ')}">
  $content
</div>
''';
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Creates a copy with updated properties
  FlintImage copyWith({
    String? src,
    String? alt,
    double? width,
    double? height,
    EdgeInsets? margin,
    EdgeInsets? padding,
    String? alignment,
    BoxBorder? border,
    BorderRadius? borderRadius,
    BoxShadow? shadow,
    ImageStyle? style,
    String? caption,
    bool? lazyLoading,
    String? linkUrl,
  }) {
    return FlintImage(
      src: src ?? this.src,
      alt: alt ?? this.alt,
      width: width ?? this.width,
      height: height ?? this.height,
      margin: margin ?? this.margin,
      padding: padding ?? this.padding,
      alignment: alignment ?? this.alignment,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      shadow: shadow ?? this.shadow,
      style: style ?? this.style,
      caption: caption ?? this.caption,
      lazyLoading: lazyLoading ?? this.lazyLoading,
      linkUrl: linkUrl ?? this.linkUrl,
    );
  }
}
