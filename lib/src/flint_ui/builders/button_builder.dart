// lib/flint_ui/builders/button_builder.dart

import 'package:flint_dart/src/flint_ui/core/box_style.dart';
import 'package:flint_dart/src/flint_ui/core/button_style.dart';
import 'package:flint_dart/src/flint_ui/core/edge_insets.dart';
import 'package:flint_dart/src/flint_ui/core/style.dart';
import 'package:flint_dart/src/flint_ui/themes/button_themes.dart';
import 'package:flint_dart/src/flint_ui/widgets/flint_button.dart';

class FlintButtonBuilder {
  /// Create a prominent call-to-action button
  static FlintButton callToAction({
    required String text,
    required String url,
    ButtonSize size = ButtonSize.large,
    bool prominent = true,
    String? icon,
  }) {
    return FlintButton(
      text: text,
      url: url,
      style: ButtonStyle.primary().copyWith(
        backgroundColor: prominent ? '#007cba' : '#6c757d',
        textStyle: TextStyle(
          color: '#ffffff',
          fontWeight: FontWeight.w700,
          fontSize: _getFontSizeForButtonSize(size),
        ),
      ),
      padding: _getPaddingForSize(size),
      borderRadius: BorderRadius.circular(8.0),
      shadow: prominent
          ? BoxShadow(
              offsetY: 4, blurRadius: 12, color: 'rgba(0, 124, 186, 0.3)')
          : BoxShadow(offsetY: 2, blurRadius: 6, color: 'rgba(0, 0, 0, 0.1)'),
      fullWidth: size == ButtonSize.xlarge,
      size: size,
      icon: icon,
    );
  }

  /// Create an email confirmation button
  static FlintButton emailConfirmation({
    required String url,
    String text = 'Confirm Email Address',
  }) {
    return FlintButton(
      text: text,
      url: url,
      style: ButtonStyle.success(),
      padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
      borderRadius: BorderRadius.circular(6.0),
      shadow:
          BoxShadow(offsetY: 3, blurRadius: 8, color: 'rgba(40, 167, 69, 0.3)'),
      fullWidth: true,
      size: ButtonSize.large,
      icon: FlintButtonThemes.checkmark,
    );
  }

  /// Create a download button
  static FlintButton download({
    required String url,
    required String fileName,
    String text = 'Download',
  }) {
    return FlintButton(
      text: '$text $fileName',
      url: url,
      style: ButtonStyle.primary(),
      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      borderRadius: BorderRadius.circular(6.0),
      size: ButtonSize.medium,
      icon: FlintButtonThemes.download,
    );
  }

  /// Create a disabled button with tooltip
  static FlintButton disabled({
    required String text,
    String? tooltip,
    String? icon,
  }) {
    return FlintButton(
      text: text,
      url: '#',
      style: ButtonStyle.primary().copyWith(
        backgroundColor: '#6c757d',
        disabledColor: '#6c757d',
      ),
      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      state: ButtonState.disabled,
      semanticLabel: tooltip,
      icon: icon,
    );
  }

  /// Create a button with loading state
  static FlintButton loading({
    String text = 'Loading...',
    String? icon,
  }) {
    return FlintButton(
      text: text,
      url: '#',
      style: ButtonStyle.secondary(),
      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      state: ButtonState.disabled,
      icon: icon ?? '⏳',
    );
  }

  static double _getFontSizeForButtonSize(ButtonSize size) {
    switch (size) {
      case ButtonSize.small:
        return 14.0;
      case ButtonSize.medium:
        return 16.0;
      case ButtonSize.large:
        return 18.0;
      case ButtonSize.xlarge:
        return 20.0;
    }
  }

  static EdgeInsets _getPaddingForSize(ButtonSize size) {
    switch (size) {
      case ButtonSize.small:
        return EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);
      case ButtonSize.medium:
        return EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0);
      case ButtonSize.large:
        return EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0);
      case ButtonSize.xlarge:
        return EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0);
    }
  }
}
