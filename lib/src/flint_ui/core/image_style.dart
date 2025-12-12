// lib/flint_ui/core/image_style.dart

/// {{template image_style}
/// The [ImageStyle] class defines visual and behavioral properties for images
/// within the Flint UI framework.
///
/// It provides attributes such as [opacity], [filter], [fit], [title], and
/// [decoding] to control how images are displayed and optimized during rendering.
///
/// This class is commonly used with widgets like `FlintImage` to provide fine-grained
/// image customization and consistent visual rendering across multiple output formats
/// (HTML, email, CLI, etc.).
///
/// Example:
/// ```dart
/// ImageStyle(
///   opacity: 0.9,
///   filter: 'grayscale(50%)',
///   fit: ObjectFit.cover,
///   title: 'Company Logo',
///   decoding: ImageDecoding.auto,
/// );
/// ```
/// {{endtemplate}
class ImageStyle {
  /// Adjusts the image's transparency level, between `0.0` (fully transparent)
  /// and `1.0` (fully opaque).
  final double? opacity;

  /// Applies a CSS-compatible visual filter to the image (e.g., `"blur(4px)"`,
  /// `"grayscale(50%)"`, or `"brightness(120%)"`).
  final String? filter;

  /// Defines how the image should fit within its container.
  ///
  /// Defaults to [ObjectFit.contain].
  final ObjectFit fit;

  /// Provides an optional title or tooltip for the image.
  ///
  /// This may be rendered as an HTML `title` attribute or used in accessibility
  /// contexts (e.g., screen readers).
  final String? title;

  /// Specifies how the image should be decoded by the browser or renderer.
  ///
  /// Can be [ImageDecoding.sync], [ImageDecoding.async], or [ImageDecoding.auto].
  final ImageDecoding? decoding;

  /// Creates a new [ImageStyle] instance.
  ///
  /// All parameters are optional and can be combined as needed for custom styling.
  const ImageStyle({
    this.opacity,
    this.filter,
    this.fit = ObjectFit.contain,
    this.title,
    this.decoding,
  });

  /// Returns a new [ImageStyle] object with modified properties.
  ///
  /// Only the specified parameters will override the current values.
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

  /// Converts this style configuration into a serializable JSON object.
  ///
  /// Example output:
  /// ```json
  /// {
  ///   "opacity": 0.9,
  ///   "filter": "grayscale(50%)",
  ///   "fit": "cover",
  ///   "title": "Company Logo",
  ///   "decoding": "auto"
  /// }
  /// ```
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

/// {{template object_fit}
/// Describes how an image should be resized to fit its container.
///
/// Mirrors the CSS `object-fit` property.
///
/// Commonly used in [ImageStyle] to ensure consistent rendering
/// in both HTML and email output contexts.
/// {{endtemplate}
enum ObjectFit {
  /// The image is stretched to fill the element’s content box.
  fill('fill'),

  /// The image is scaled to maintain its aspect ratio while fitting
  /// completely inside the container.
  contain('contain'),

  /// The image is scaled to maintain its aspect ratio while covering
  /// the entire container.
  cover('cover'),

  /// The image is not resized.
  none('none'),

  /// The image is scaled down to fit within the container if larger,
  /// otherwise rendered at its original size.
  scaleDown('scale-down');

  /// The CSS-compatible value of this fit mode.
  final String cssValue;

  /// Creates a constant [ObjectFit] value.
  const ObjectFit(this.cssValue);

  /// Converts this value to its CSS representation.
  String toCss() => cssValue;
}

/// {{template image_decoding}
/// Defines how images are decoded by the renderer or browser.
///
/// Mirrors the HTML `decoding` attribute used in `<img>` tags.
/// {{endtemplate}
enum ImageDecoding {
  /// Decode the image synchronously.
  sync('sync'),

  /// Decode the image asynchronously to avoid blocking rendering.
  async('async'),

  /// Let the browser or renderer choose the best decoding strategy automatically.
  auto('auto');

  /// The string representation of this decoding mode.
  final String value;

  /// Creates a constant [ImageDecoding] value.
  const ImageDecoding(this.value);
}
