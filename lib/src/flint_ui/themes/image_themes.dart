// lib/flint_ui/themes/image_themes.dart

import 'package:flint_dart/src/flint_ui/core/core.dart';
import 'package:flint_dart/src/flint_ui/widgets/image.dart';

class ImageStyles {
  // Common image aspect ratios
  static const Size square = Size.square(1);
  static const Size landscape = Size(16, 9);
  static const Size portrait = Size(4, 5);
  // static const Size banner = Size(3, 1);

  // Predefined image styles
  static const ImageStyle rounded = ImageStyle();

  static const ImageStyle circular = ImageStyle(
    fit: ObjectFit.cover,
  );

  // static const ImageStyle thumbnail = ImageStyle(
  //   fit: ObjectFit.cover,
  // );

  static const ImageStyle hero = ImageStyle(
    fit: ObjectFit.cover,
  );

  static const ImageStyle faded = ImageStyle(
    opacity: 0.7,
    filter: 'grayscale(20%)',
  );

  // Factory methods for common image types
  static Image logo({
    required String src,
    String? alt,
    double size = 120,
  }) {
    return Image(
      src: src,
      alt: alt ?? 'Logo',
      width: size,
      height: size,
      style: const ImageStyle(),
      alignment: 'center',
    );
  }

  static Image avatar({
    required String src,
    required String alt,
    double size = 64,
  }) {
    return Image(
      src: src,
      alt: alt,
      width: size,
      height: size,
      style: const ImageStyle(fit: ObjectFit.cover),
      borderRadius: BorderRadius.circular(size / 2),
      border: BoxBorder.all(color: '#e0e0e0', width: 2),
    );
  }

  static Image heroImage({
    required String src,
    required String alt,
    double? width,
    double height = 300,
  }) {
    return Image(
      src: src,
      alt: alt,
      width: width,
      height: height,
      style: const ImageStyle(fit: ObjectFit.cover),
      margin: EdgeInsets.only(bottom: 20),
    );
  }

  static Image thumbnail({
    required String src,
    required String alt,
    double size = 100,
  }) {
    return Image(
      src: src,
      alt: alt,
      width: size,
      height: size,
      style: const ImageStyle(fit: ObjectFit.cover),
      borderRadius: BorderRadius.circular(8),
      border: BoxBorder.all(color: '#e0e0e0'),
    );
  }

  static Image banner({
    required String src,
    required String alt,
    double width = 600,
    double height = 200,
  }) {
    return Image(
      src: src,
      alt: alt,
      width: width,
      height: height,
      style: const ImageStyle(fit: ObjectFit.cover),
      borderRadius: BorderRadius.circular(8),
    );
  }
}
