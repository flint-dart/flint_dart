import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Responsive `img` element with common loading and decoding attributes.
class Image extends FlintElement {
  /// Creates an image from [src] with accessibility and loading options.
  Image({
    required String src,
    String alt = '',
    Object? width,
    Object? height,
    String? srcSet,
    String? sizes,
    ImageLoading loading = ImageLoading.lazy,
    ImageDecoding decoding = ImageDecoding.async,
    String? fetchPriority,
    String? referrerPolicy,
    String? crossOrigin,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'img',
         props: mergeComponentProps(
           {
             ...props,
             'src': src,
             'alt': alt,
             if (width != null) 'width': cssValue(width),
             if (height != null) 'height': cssValue(height),
             if (srcSet != null) 'srcset': srcSet,
             if (sizes != null) 'sizes': sizes,
             'loading': loading.value,
             'decoding': decoding.value,
             if (fetchPriority != null) 'fetchpriority': fetchPriority,
             if (referrerPolicy != null) 'referrerpolicy': referrerPolicy,
             if (crossOrigin != null) 'crossorigin': crossOrigin,
           },
           className: className,
           defaultStyle: const {'display': 'block', 'max-width': '100%'},
           dartStyle: dartStyle,
           style: style,
         ),
       );
}

/// Semantic `figure` element with an image and optional caption.
class Figure extends FlintElement {
  /// Creates a figure from [image] and optional [caption].
  Figure({
    required Object image,
    Object? caption,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    DartStyle? captionStyle,
    Map<String, Object?> captionProps = const {},
  }) : super(
         'figure',
         props: mergeComponentProps(
           props,
           className: className,
           defaultStyle: const {'display': 'grid', 'gap': '8px', 'margin': '0'},
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           toFlintNode(image),
           if (caption != null)
             FlintElement(
               'figcaption',
               props: mergeComponentProps(
                 captionProps,
                 defaultStyle: const {
                   'color': '#667085',
                   'font-size': '14px',
                   'line-height': '1.5',
                 },
                 dartStyle: captionStyle,
               ),
               children: normalizeChildren(caption, const []),
             ),
         ],
       );
}

/// Browser image loading strategy.
enum ImageLoading {
  /// Load the image immediately.
  eager('eager'),

  /// Defer loading until the image is near the viewport.
  lazy('lazy');

  /// HTML `loading` attribute value.
  final String value;

  /// Creates an image loading option.
  const ImageLoading(this.value);
}

/// Browser image decoding strategy.
enum ImageDecoding {
  /// Decode the image asynchronously.
  async('async'),

  /// Let the browser choose the decoding strategy.
  auto('auto'),

  /// Decode the image synchronously.
  sync('sync');

  /// HTML `decoding` attribute value.
  final String value;

  /// Creates an image decoding option.
  const ImageDecoding(this.value);
}
