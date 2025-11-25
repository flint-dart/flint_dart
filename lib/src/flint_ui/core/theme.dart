// lib/flint_ui/core/theme.dart

import 'package:flint_dart/src/flint_ui/core/colors.dart';

class FlintTheme {
  final String primaryColor;
  final String secondaryColor;
  final String backgroundColor;
  final String surfaceColor;
  final String errorColor;
  final String successColor;
  final String warningColor;
  final String infoColor;
  final String textColor;
  final String textSecondaryColor;
  final String borderColor;
  final String fontFamily;
  final double baseFontSize;
  final double borderRadius;

  const FlintTheme({
    this.primaryColor = Colors.primary,
    this.secondaryColor = Colors.secondary,
    this.backgroundColor = Colors.white,
    this.surfaceColor = Colors.gray50,
    this.errorColor = Colors.danger,
    this.successColor = Colors.success,
    this.warningColor = Colors.warning,
    this.infoColor = Colors.info,
    this.textColor = Colors.gray900,
    this.textSecondaryColor = Colors.gray600,
    this.borderColor = Colors.gray300,
    this.fontFamily =
        '-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif',
    this.baseFontSize = 16.0,
    this.borderRadius = 6.0,
  });

  // Predefined themes
  static const FlintTheme light = FlintTheme();

  static const FlintTheme dark = FlintTheme(
    primaryColor: Colors.primaryLight,
    secondaryColor: Colors.secondaryLight,
    backgroundColor: Colors.gray900,
    surfaceColor: Colors.gray800,
    textColor: Colors.white,
    textSecondaryColor: Colors.gray300,
    borderColor: Colors.gray700,
  );

  static const FlintTheme blue = FlintTheme(
    primaryColor: Colors.blue,
    secondaryColor: Colors.lightBlue,
  );

  static const FlintTheme green = FlintTheme(
    primaryColor: Colors.green,
    secondaryColor: Colors.lightGreen,
  );

  static const FlintTheme purple = FlintTheme(
    primaryColor: Colors.purple,
    secondaryColor: Colors.deepPurple,
  );

  // Copy with method
  FlintTheme copyWith({
    String? primaryColor,
    String? secondaryColor,
    String? backgroundColor,
    String? surfaceColor,
    String? errorColor,
    String? successColor,
    String? warningColor,
    String? infoColor,
    String? textColor,
    String? textSecondaryColor,
    String? borderColor,
    String? fontFamily,
    double? baseFontSize,
    double? borderRadius,
  }) {
    return FlintTheme(
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      errorColor: errorColor ?? this.errorColor,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      infoColor: infoColor ?? this.infoColor,
      textColor: textColor ?? this.textColor,
      textSecondaryColor: textSecondaryColor ?? this.textSecondaryColor,
      borderColor: borderColor ?? this.borderColor,
      fontFamily: fontFamily ?? this.fontFamily,
      baseFontSize: baseFontSize ?? this.baseFontSize,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}
