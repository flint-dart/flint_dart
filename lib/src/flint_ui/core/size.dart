// lib/flint_ui/core/size.dart

import 'dart:math' as math;

class Size {
  final double width;
  final double height;

  const Size(this.width, this.height);

  const Size.square(double dimension) : this(dimension, dimension);

  static const Size zero = Size(0.0, 0.0);

  static const Size infinite = Size(double.infinity, double.infinity);

  /// Whether this size has non-negative width and height.
  bool get isNonNegative => width >= 0.0 && height >= 0.0;

  /// The aspect ratio of this size (width / height).
  double get aspectRatio {
    if (height != 0.0) return width / height;
    if (width > 0.0) return double.infinity;
    if (width < 0.0) return double.negativeInfinity;
    return 0.0;
  }

  /// Whether this size has finite width and height.
  bool get isFinite => width.isFinite && height.isFinite;

  /// Whether this size has infinite width or height.
  bool get isInfinite => !isFinite;

  /// Returns a new size with the width and height scaled by the given factor.
  Size scale(double factor) {
    return Size(width * factor, height * factor);
  }

  /// Returns a new size with the width and height scaled by the given factors.
  Size scaleSize(double widthFactor, double heightFactor) {
    return Size(width * widthFactor, height * heightFactor);
  }

  /// Returns a new size with the given width and the same height.
  Size withWidth(double newWidth) {
    return Size(newWidth, height);
  }

  /// Returns a new size with the given height and the same width.
  Size withHeight(double newHeight) {
    return Size(width, newHeight);
  }

  /// Returns the size that is the combination of this size and the given other size.
  Size combine(Size other) {
    return Size(width + other.width, height + other.height);
  }

  /// Returns the size that is the difference between this size and the given other size.
  Size subtract(Size other) {
    return Size(width - other.width, height - other.height);
  }

  /// Returns the size that is the component-wise minimum of this size and the given other size.
  Size min(Size other) {
    return Size(
      math.min(width, other.width),
      math.min(height, other.height),
    );
  }

  /// Returns the size that is the component-wise maximum of this size and the given other size.
  Size max(Size other) {
    return Size(
      math.max(width, other.width),
      math.max(height, other.height),
    );
  }

  /// Linearly interpolate between two sizes.
  static Size? lerp(Size? a, Size? b, double t) {
    if (a == null && b == null) return null;
    if (a == null) return b! * t;
    if (b == null) return a * (1.0 - t);

    return Size(
      _lerpDouble(a.width, b.width, t),
      _lerpDouble(a.height, b.height, t),
    );
  }

  static double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
    };
  }

  /// Create Size from JSON
  factory Size.fromJson(Map<String, dynamic> json) {
    return Size(
      json['width'] ?? 0.0,
      json['height'] ?? 0.0,
    );
  }

  /// Convert to CSS string for HTML output
  String toCss() {
    if (width == double.infinity && height == double.infinity) {
      return '100% 100%';
    }
    if (width == double.infinity) {
      return '100% ${height}px';
    }
    if (height == double.infinity) {
      return '${width}px 100%';
    }
    return '${width}px ${height}px';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Size &&
            runtimeType == other.runtimeType &&
            width == other.width &&
            height == other.height;
  }

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() {
    if (width == double.infinity && height == double.infinity) {
      return 'Size.infinite';
    }
    if (width == 0.0 && height == 0.0) {
      return 'Size.zero';
    }
    return 'Size($width, $height)';
  }
}

// Operator overloads for Size
extension SizeOperators on Size {
  Size operator *(double factor) => scale(factor);

  Size operator /(double factor) => scale(1.0 / factor);

  Size operator +(Size other) => combine(other);

  Size operator -(Size other) => subtract(other);

  bool operator <(Size other) => width < other.width && height < other.height;

  bool operator >(Size other) => width > other.width && height > other.height;

  bool operator <=(Size other) =>
      width <= other.width && height <= other.height;

  bool operator >=(Size other) =>
      width >= other.width && height >= other.height;
}
