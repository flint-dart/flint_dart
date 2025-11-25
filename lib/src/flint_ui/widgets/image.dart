// lib/flint_ui/widgets/image.dart

import 'package:flint_dart/src/flint_ui/core/core.dart';

/// {@template flint_image}
/// A versatile image widget in **Flint UI**, designed for rendering images
/// in multiple formats including HTML (for emails and web) and plain text.
///
/// The [Image] class provides flexible styling options such as
/// margins, padding, borders, shadows, captions, and lazy-loading support.
///
/// It can optionally wrap the image inside a link or display a caption below
/// it, using semantic HTML elements like `<a>` and `<figure>`.
///
/// Example:
/// ```dart
/// Image(
///   src: 'https://flintdart.dev/logo.png',
///   alt: 'Flint Dart Logo',
///   width: 120,
///   caption: 'Powered by Flint Dart',
///   lazyLoading: true,
/// )
/// ```
///
/// This will render as an HTML image with a caption underneath and lazy loading enabled.
/// {@endtemplate}
class Image extends FlintWidget {
  /// The source URL or path of the image.
  final String src;

  /// The alternative text for the image, used for accessibility
  /// and when the image fails to load.
  final String? alt;

  /// The explicit width of the image in pixels.
  final double? width;

  /// The explicit height of the image in pixels.
  final double? height;

  /// The margin applied outside the image container.
  final EdgeInsets? margin;

  /// The padding applied inside the image container.
  final EdgeInsets? padding;

  /// The image alignment, represented as a string (e.g., `"left"`, `"center"`, `"right"`).
  final String? alignment;

  /// The border style of the image, defined using [BoxBorder].
  final BoxBorder? border;

  /// The radius of the image corners.
  final BorderRadius? borderRadius;

  /// The shadow applied to the image.
  final BoxShadow? shadow;

  /// Additional visual options for the image, defined via [ImageStyle].
  final ImageStyle style;

  /// A text caption displayed below the image.
  final String? caption;

  /// Whether to enable native browser lazy-loading for the image.
  ///
  /// When true, the image will only be loaded when it enters the viewport.
  final bool lazyLoading;

  /// An optional hyperlink URL that wraps the image.
  ///
  /// When set, the image becomes clickable, rendered inside an `<a>` tag.
  final String? linkUrl;

  /// Creates a [Image] widget.
  ///
  /// Most parameters are optional except [src].
  Image({
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

  /// Converts this image into an HTML representation.
  ///
  /// - Wraps the `<img>` tag with a `<figure>` if a caption is provided.
  /// - Wraps it with an `<a>` tag if [linkUrl] is set.
  /// - Otherwise, wraps it in a `<div>` container to apply styles.
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

  /// Converts this image into a plain-text description.
  ///
  /// The output includes the alt text, optional caption, and link URL if provided.
  /// Example:
  /// ```
  /// [Image: Flint Dart Logo - Powered by Flint Dart] (https://flintdart.dev)
  /// ```
  @override
  String toText() {
    final altText = alt ?? 'Image';
    final captionText = caption != null ? ' - $caption' : '';
    final linkText = linkUrl != null ? ' ($linkUrl)' : '';

    return '[Image: $altText$captionText]$linkText';
  }

  /// Serializes this image into a JSON-compatible map.
  ///
  /// Useful for UI serialization or exporting configurations.
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

  /// {@macro flint_widget.buildTemplate}
  ///
  /// Since [Image] is a leaf widget (it cannot contain child widgets),
  /// this method simply returns itself.
  @override
  FlintWidget buildTemplate() => this;

  /// Builds the core `<img>` HTML tag and its inline styles.
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

  /// Wraps the image with a clickable `<a>` tag when [linkUrl] is provided.
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

  /// Wraps the image in a `<figure>` element and adds a `<figcaption>` for captions.
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

  /// Wraps the image in a container `<div>` to apply margin, padding, and alignment styles.
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

  /// Escapes special characters for safe HTML rendering.
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Creates a copy of this image with updated properties.
  ///
  /// This allows you to modify certain fields without recreating the entire widget.
  Image copyWith({
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
    return Image(
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
