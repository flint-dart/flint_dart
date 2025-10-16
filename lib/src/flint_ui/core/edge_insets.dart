// lib/flint_ui/core/edge_insets.dart

import 'package:flint_dart/src/flint_ui/core/size.dart';

class EdgeInsets {
  final double top;
  final double right;
  final double bottom;
  final double left;

  const EdgeInsets.fromLTRB(this.left, this.top, this.right, this.bottom)
      : assert(left >= 0.0),
        assert(top >= 0.0),
        assert(right >= 0.0),
        assert(bottom >= 0.0);

  const EdgeInsets.all(double value)
      : this.fromLTRB(value, value, value, value);

  const EdgeInsets.symmetric({
    double vertical = 0.0,
    double horizontal = 0.0,
  }) : this.fromLTRB(horizontal, vertical, horizontal, vertical);

  const EdgeInsets.only({
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
  });

  const EdgeInsets.zero()
      : top = 0.0,
        right = 0.0,
        bottom = 0.0,
        left = 0.0;

  /// Creates insets where all the offsets are `value`.
  ///
  ///
  /// ```dart
  /// const EdgeInsets(10.0) // 10px on all sides
  /// ```
  const EdgeInsets(double value) : this.fromLTRB(value, value, value, value);

  /// Vertical insets
  factory EdgeInsets.vertical(double vertical, {double horizontal = 0.0}) {
    return EdgeInsets.symmetric(vertical: vertical, horizontal: horizontal);
  }

  /// Horizontal insets
  factory EdgeInsets.horizontal(double horizontal, {double vertical = 0.0}) {
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  /// Top only
  const EdgeInsets.top(double value) : this.only(top: value);

  /// Right only
  const EdgeInsets.right(double value) : this.only(right: value);

  /// Bottom only
  const EdgeInsets.bottom(double value) : this.only(bottom: value);

  /// Left only
  const EdgeInsets.left(double value) : this.only(left: value);

  /// Top and bottom
  const EdgeInsets.verticalTopBottom(double top, double bottom)
      : this.only(top: top, bottom: bottom);

  /// Left and right
  const EdgeInsets.horizontalLeftRight(double left, double right)
      : this.only(left: left, right: right);

  /// Convert to CSS string for HTML output
  String toCss() {
    return '${top}px ${right}px ${bottom}px ${left}px';
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'top': top,
      'right': right,
      'bottom': bottom,
      'left': left,
    };
  }

  /// Create EdgeInsets from JSON
  factory EdgeInsets.fromJson(Map<String, dynamic> json) {
    return EdgeInsets.only(
      top: json['top'] ?? 0.0,
      right: json['right'] ?? 0.0,
      bottom: json['bottom'] ?? 0.0,
      left: json['left'] ?? 0.0,
    );
  }

  /// Returns a new EdgeInsets with the dimensions scaled by the given factor.
  EdgeInsets scale(double factor) {
    return EdgeInsets.fromLTRB(
      left * factor,
      top * factor,
      right * factor,
      bottom * factor,
    );
  }

  /// Returns the total offset along the horizontal axis.
  double get horizontal => left + right;

  /// Returns the total offset along the vertical axis.
  double get vertical => top + bottom;

  /// Returns the total offset in both axes as a Size.
  Size get size => Size(horizontal, vertical);

  /// Whether every dimension is non-negative.
  bool get isNonNegative =>
      top >= 0.0 && right >= 0.0 && bottom >= 0.0 && left >= 0.0;

  /// Returns the insets with the given offsets added to the corresponding directions.
  EdgeInsets add(EdgeInsets other) {
    return EdgeInsets.fromLTRB(
      left + other.left,
      top + other.top,
      right + other.right,
      bottom + other.bottom,
    );
  }

  /// Returns the insets with the given offsets subtracted from the corresponding directions.
  EdgeInsets subtract(EdgeInsets other) {
    return EdgeInsets.fromLTRB(
      left - other.left,
      top - other.top,
      right - other.right,
      bottom - other.bottom,
    );
  }

  /// Returns the difference between two EdgeInstes
  EdgeInsets difference(EdgeInsets other) {
    return EdgeInsets.fromLTRB(
      (left - other.left).abs(),
      (top - other.top).abs(),
      (right - other.right).abs(),
      (bottom - other.bottom).abs(),
    );
  }

  /// Linearly interpolate between two EdgeInstes
  static EdgeInsets? lerp(EdgeInsets? a, EdgeInsets? b, double t) {
    if (a == null && b == null) return null;
    if (a == null) return b! * t;
    if (b == null) return a * (1.0 - t);

    return EdgeInsets.fromLTRB(
      _lerpDouble(a.left, b.left, t),
      _lerpDouble(a.top, b.top, t),
      _lerpDouble(a.right, b.right, t),
      _lerpDouble(a.bottom, b.bottom, t),
    );
  }

  static double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EdgeInsets &&
            runtimeType == other.runtimeType &&
            top == other.top &&
            right == other.right &&
            bottom == other.bottom &&
            left == other.left;
  }

  @override
  int get hashCode => Object.hash(top, right, bottom, left);

  @override
  String toString() {
    if (left == 0.0 && right == 0.0 && top == 0.0 && bottom == 0.0) {
      return 'EdgeInsets.zero';
    }
    if (left == right && right == top && top == bottom) {
      return 'EdgeInsets.all($left)';
    }
    if (left == right && top == bottom) {
      if (left == 0.0) return 'EdgeInsets.symmetric(vertical: $top)';
      if (top == 0.0) return 'EdgeInsets.symmetric(horizontal: $left)';
      return 'EdgeInsets.symmetric(horizontal: $left, vertical: $top)';
    }
    return 'EdgeInsets($top, $right, $bottom, $left)';
  }
}

// Operator overload for multiplication
extension EdgeInsetsOperators on EdgeInsets {
  EdgeInsets operator *(double factor) {
    return scale(factor);
  }

  EdgeInsets operator +(EdgeInsets other) {
    return add(other);
  }

  EdgeInsets operator -(EdgeInsets other) {
    return subtract(other);
  }
}
