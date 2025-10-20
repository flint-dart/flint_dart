// lib/flint_ui/core/button_style.dart

import 'package:flint_dart/src/flint_ui/core/box_style.dart';
import 'package:flint_dart/src/flint_ui/core/style.dart';

/// {@template button_style}
/// The [ButtonStyle] class defines the visual appearance and behavior of buttons
/// in the Flint UI framework.
///
/// It specifies attributes like [backgroundColor], [textStyle], [border],
/// and [hoverColor], allowing for consistent and reusable button designs
/// across multiple UI components.
///
/// Predefined styles such as [ButtonStyle.primary], [ButtonStyle.success],
/// and [ButtonStyle.outline] provide quick access to commonly used button types.
///
/// Example:
/// ```dart
/// final primary = ButtonStyle.primary();
///
/// final custom = ButtonStyle(
///   backgroundColor: '#1d72b8',
///   textStyle: TextStyle(
///     color: '#ffffff',
///     fontWeight: FontWeight.w600,
///     fontSize: 16,
///   ),
///   hoverColor: '#155d8a',
/// );
/// ```
/// {@endtemplate}
class ButtonStyle {
  /// The main background color of the button.
  ///
  /// Accepts a valid CSS color string (e.g., `#007cba`, `rgb(255, 0, 0)`, or `transparent`).
  final String backgroundColor;

  /// The background color of the button when it is disabled.
  ///
  /// If `null`, the button will typically appear faded or reduced in opacity.
  final String? disabledColor;

  /// The text style applied to the button's label.
  ///
  /// Includes color, font size, and weight via the [TextStyle] class.
  final TextStyle textStyle;

  /// The border surrounding the button, if any.
  ///
  /// Represented by [BoxBorder], which can define color and width.
  final BoxBorder? border;

  /// The background color of the button when hovered (on web or interactive UI).
  ///
  /// Defaults to a slightly darker shade of the [backgroundColor].
  final String hoverColor;

  /// Creates a custom [ButtonStyle].
  ///
  /// You can use this constructor for fully custom button designs.
  const ButtonStyle({
    required this.backgroundColor,
    this.disabledColor,
    this.textStyle = const TextStyle(),
    this.border,
    this.hoverColor = '#0056b3',
  });

  /// A predefined **primary button style**.
  ///
  /// Renders a bold blue button with white text and a darker blue hover color.
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

  /// A predefined **secondary button style**.
  ///
  /// Uses a neutral gray color with white text.
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

  /// A predefined **success button style**.
  ///
  /// Renders a green button, typically used for positive actions.
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

  /// A predefined **danger button style**.
  ///
  /// Displays a red button, used for destructive or irreversible actions.
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

  /// A predefined **warning button style**.
  ///
  /// Displays a yellow/orange button with dark text for alerts or warnings.
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

  /// A predefined **outline button style**.
  ///
  /// Displays a transparent button with a visible border and colored text.
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

  /// A predefined **ghost button style**.
  ///
  /// Minimal design—no border, transparent background, and colored text.
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

  /// Returns a new [ButtonStyle] instance with selectively updated properties.
  ///
  /// Example:
  /// ```dart
  /// final updated = primary.copyWith(
  ///   backgroundColor: '#004a99',
  ///   hoverColor: '#003366',
  /// );
  /// ```
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

  /// Converts this style into a serializable JSON representation.
  ///
  /// Example output:
  /// ```json
  /// {
  ///   "backgroundColor": "#007cba",
  ///   "textStyle": {
  ///     "color": "#ffffff",
  ///     "fontWeight": "w600",
  ///     "fontSize": 16.0
  ///   },
  ///   "hoverColor": "#0056b3"
  /// }
  /// ```
  Map<String, dynamic> toJson() => {
        'backgroundColor': backgroundColor,
        'disabledColor': disabledColor,
        'textStyle': textStyle.toJson(),
        'border': border?.toJson(),
        'hoverColor': hoverColor,
      };
}

/// {@template button_size}
/// Defines available button size categories in Flint UI.
///
/// Used to determine consistent padding, font size, and layout proportions
/// for button widgets.
/// {@endtemplate}
enum ButtonSize {
  /// Small button — typically compact, for tight spaces.
  small,

  /// Medium button — standard size for most use cases.
  medium,

  /// Large button — slightly bigger for emphasis.
  large,

  /// Extra-large button — ideal for call-to-action elements.
  xlarge,
}

/// {@template button_state}
/// Represents the current interactive state of a button in Flint UI.
///
/// This helps in rendering dynamic UI states like disabled or loading buttons.
/// {@endtemplate}
enum ButtonState {
  /// The button is active and clickable.
  enabled,

  /// The button is inactive or visually dimmed.
  disabled,

  /// The button is temporarily busy, e.g., showing a spinner or progress.
  loading,
}
