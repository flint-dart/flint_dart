// lib/flint_ui/themes/button_themes.dart

import 'package:flint_dart/src/flint_ui/core/button_style.dart';
import 'package:flint_dart/src/flint_ui/core/edge_insets.dart';
import 'package:flint_dart/src/flint_ui/widgets/flint_button.dart';

class ButtonThemes {
  // Size presets
  static const EdgeInsets small =
      EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);
  static const EdgeInsets medium =
      EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0);
  static const EdgeInsets large =
      EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0);
  static const EdgeInsets xlarge =
      EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0);

  // Common icons
  static const String arrowRight = '→';
  static const String download = '📥';
  static const String externalLink = '🔗';
  static const String calendar = '📅';
  static const String checkmark = '✅';
  static const String star = '⭐';
  static const String heart = '❤️';
  static const String rocket = '🚀';
  static const String shoppingCart = '🛒';
  static const String play = '▶️';

  // Factory methods for common button types
  static Button primary({
    required String text,
    required String url,
    ButtonSize size = ButtonSize.medium,
    bool fullWidth = false,
    String? icon,
  }) {
    return Button(
      text: text,
      url: url,
      style: ButtonStyle.primary(),
      padding: _getPaddingForSize(size),
      fullWidth: fullWidth,
      size: size,
      icon: icon,
    );
  }

  static Button secondary({
    required String text,
    required String url,
    ButtonSize size = ButtonSize.medium,
    bool fullWidth = false,
    String? icon,
  }) {
    return Button(
      text: text,
      url: url,
      style: ButtonStyle.secondary(),
      padding: _getPaddingForSize(size),
      fullWidth: fullWidth,
      size: size,
      icon: icon,
    );
  }

  static Button outline({
    required String text,
    required String url,
    ButtonSize size = ButtonSize.medium,
    bool fullWidth = false,
    String? icon,
  }) {
    return Button(
      text: text,
      url: url,
      style: ButtonStyle.outline(),
      padding: _getPaddingForSize(size),
      fullWidth: fullWidth,
      size: size,
      icon: icon,
    );
  }

  static Button ghost({
    required String text,
    required String url,
    ButtonSize size = ButtonSize.medium,
    String? icon,
  }) {
    return Button(
      text: text,
      url: url,
      style: ButtonStyle.ghost(),
      padding: _getPaddingForSize(size),
      size: size,
      icon: icon,
    );
  }

  static Button success({
    required String text,
    required String url,
    ButtonSize size = ButtonSize.medium,
    bool fullWidth = false,
    String? icon,
  }) {
    return Button(
      text: text,
      url: url,
      style: ButtonStyle.success(),
      padding: _getPaddingForSize(size),
      fullWidth: fullWidth,
      size: size,
      icon: icon,
    );
  }

  static EdgeInsets _getPaddingForSize(ButtonSize size) {
    switch (size) {
      case ButtonSize.small:
        return small;
      case ButtonSize.medium:
        return medium;
      case ButtonSize.large:
        return large;
      case ButtonSize.xlarge:
        return xlarge;
    }
  }
}
