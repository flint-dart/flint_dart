// lib/flint_ui/themes/text_themes.dart

import 'package:flint_dart/src/flint_ui/core/style.dart';

class FlintTextStyles {
  /// Headline styles
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: '#1a1a1a',
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: '#1a1a1a',
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: '#1a1a1a',
  );

  /// Body styles
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    color: '#333333',
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    color: '#333333',
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    color: '#666666',
  );

  /// Caption styles
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: '#999999',
  );

  /// Button styles
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: '#ffffff',
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: '#ffffff',
  );

  /// Link styles
  static const TextStyle link = TextStyle(
    fontSize: 16,
    color: '#007cba',
    decoration: TextDecoration.underline,
  );
}
