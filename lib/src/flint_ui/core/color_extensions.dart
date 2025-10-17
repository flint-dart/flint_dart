// lib/flint_ui/core/color_extensions.dart
import 'package:flint_dart/src/flint_ui/core/colors.dart';

extension FlintColorExtensions on String {
  /// Convert hex color to rgba with opacity
  String withOpacity(double opacity) {
    return FlintColors.withOpacity(this, opacity);
  }

  /// Check if color is light
  bool get isLightColor {
    if (startsWith('#')) {
      final hex = substring(1);
      final r = int.parse(hex.substring(0, 2), radix: 16);
      final g = int.parse(hex.substring(2, 4), radix: 16);
      final b = int.parse(hex.substring(4, 6), radix: 16);

      // Calculate relative luminance
      final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
      return luminance > 0.5;
    }
    return true; // Default to light for non-hex colors
  }

  /// Get contrasting text color (black or white)
  String get contrastingColor {
    return isLightColor ? FlintColors.black : FlintColors.white;
  }
}
