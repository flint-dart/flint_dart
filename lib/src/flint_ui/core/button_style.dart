// lib/flint_ui/core/button_style.dart

import 'package:flint_dart/src/flint_ui/core/box_style.dart';
import 'package:flint_dart/src/flint_ui/core/style.dart';

class ButtonStyle {
  final String backgroundColor;
  final String? disabledColor;
  final TextStyle textStyle;
  final BoxBorder? border;
  final String hoverColor;

  const ButtonStyle({
    required this.backgroundColor,
    this.disabledColor,
    this.textStyle = const TextStyle(),
    this.border,
    this.hoverColor = '#0056b3',
  });

  // Primary button style
  ButtonStyle.primary()
      : this(
          backgroundColor: '#007cba',
          textStyle: TextStyle(
            color: '#ffffff',
            fontWeight: FontWeight.w600,
            fontSize: 16.0,
          ),
          hoverColor: '#0056b3',
        );

  // Secondary button style
  ButtonStyle.secondary()
      : this(
          backgroundColor: '#6c757d',
          textStyle: TextStyle(
            color: '#ffffff',
            fontWeight: FontWeight.w600,
            fontSize: 16.0,
          ),
          hoverColor: '#545b62',
        );

  // Success button style
  ButtonStyle.success()
      : this(
          backgroundColor: '#28a745',
          textStyle: TextStyle(
            color: '#ffffff',
            fontWeight: FontWeight.w600,
            fontSize: 16.0,
          ),
          hoverColor: '#1e7e34',
        );

  // Danger button style
  ButtonStyle.danger()
      : this(
          backgroundColor: '#dc3545',
          textStyle: TextStyle(
            color: '#ffffff',
            fontWeight: FontWeight.w600,
            fontSize: 16.0,
          ),
          hoverColor: '#bd2130',
        );

  // Warning button style
  ButtonStyle.warning()
      : this(
          backgroundColor: '#ffc107',
          textStyle: TextStyle(
            color: '#212529',
            fontWeight: FontWeight.w600,
            fontSize: 16.0,
          ),
          hoverColor: '#e0a800',
        );

  // Outline button style
  ButtonStyle.outline()
      : this(
          backgroundColor: 'transparent',
          textStyle: TextStyle(
            color: '#007cba',
            fontWeight: FontWeight.w600,
            fontSize: 16.0,
          ),
          border: BoxBorder(
            color: '#007cba',
            width: 2.0,
          ),
          hoverColor: '#007cba',
        );

  // Ghost button style (minimal)
  ButtonStyle.ghost()
      : this(
          backgroundColor: 'transparent',
          textStyle: TextStyle(
            color: '#007cba',
            fontWeight: FontWeight.w600,
            fontSize: 16.0,
          ),
          border: BoxBorder.none(),
          hoverColor: '#0056b3',
        );

  ButtonStyle copyWith({
    String? backgroundColor,
    String? disabledColor,
    TextStyle? textStyle,
    BoxBorder? border,
    String? hoverColor,
  }) {
    return ButtonStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      disabledColor: disabledColor ?? this.disabledColor,
      textStyle: textStyle ?? this.textStyle,
      border: border ?? this.border,
      hoverColor: hoverColor ?? this.hoverColor,
    );
  }

  Map<String, dynamic> toJson() => {
        'backgroundColor': backgroundColor,
        'disabledColor': disabledColor,
        'textStyle': textStyle.toJson(),
        'border': border?.toJson(),
        'hoverColor': hoverColor,
      };
}

enum ButtonSize {
  small,
  medium,
  large,
  xlarge,
}

enum ButtonState {
  enabled,
  disabled,
  loading,
}
