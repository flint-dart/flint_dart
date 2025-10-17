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
    this.primaryColor = FlintColors.primary,
    this.secondaryColor = FlintColors.secondary,
    this.backgroundColor = FlintColors.white,
    this.surfaceColor = FlintColors.gray50,
    this.errorColor = FlintColors.danger,
    this.successColor = FlintColors.success,
    this.warningColor = FlintColors.warning,
    this.infoColor = FlintColors.info,
    this.textColor = FlintColors.gray900,
    this.textSecondaryColor = FlintColors.gray600,
    this.borderColor = FlintColors.gray300,
    this.fontFamily =
        '-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif',
    this.baseFontSize = 16.0,
    this.borderRadius = 6.0,
  });

  // Predefined themes
  static const FlintTheme light = FlintTheme();

  static const FlintTheme dark = FlintTheme(
    primaryColor: FlintColors.primaryLight,
    secondaryColor: FlintColors.secondaryLight,
    backgroundColor: FlintColors.gray900,
    surfaceColor: FlintColors.gray800,
    textColor: FlintColors.white,
    textSecondaryColor: FlintColors.gray300,
    borderColor: FlintColors.gray700,
  );

  static const FlintTheme blue = FlintTheme(
    primaryColor: FlintColors.blue,
    secondaryColor: FlintColors.lightBlue,
  );

  static const FlintTheme green = FlintTheme(
    primaryColor: FlintColors.green,
    secondaryColor: FlintColors.lightGreen,
  );

  static const FlintTheme purple = FlintTheme(
    primaryColor: FlintColors.purple,
    secondaryColor: FlintColors.deepPurple,
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
