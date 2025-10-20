import 'package:flint_dart/src/flint_ui/core/core.dart';

/// {@template flint_button}
/// A customizable and responsive button widget for **Flint UI**, designed to be
/// rendered as both HTML (for web/emails) and text (for CLI or plain text outputs).
///
/// The [FlintButton] class provides a consistent styling system through the
/// [ButtonStyle], [EdgeInsets], [BorderRadius], and [BoxShadow] classes.
/// It supports icons, semantic labels for accessibility, and multiple button states.
///
/// Example usage:
/// ```dart
/// FlintButton(
///   text: 'Get Started',
///   url: 'https://flintdart.dev',
///   style: ButtonStyle.primary(),
///   icon: '🚀',
/// )
/// ```
///
/// This button will render as an HTML `<a>` tag (or `<span>` if disabled)
/// with full inline CSS styling for compatibility across browsers and email clients.
/// {@endtemplate}
class FlintButton extends FlintWidget {
  /// The text displayed inside the button.
  final String text;

  /// The URL or target destination the button links to.
  /// When the button is disabled, this attribute is ignored.
  final String url;

  /// The button's visual appearance, defined by a [ButtonStyle].
  final ButtonStyle? style;

  /// The internal padding around the button content.
  final EdgeInsets padding;

  /// The border radius that determines the button's corner roundness.
  final BorderRadius borderRadius;

  /// The shadow applied to the button for depth and elevation.
  final BoxShadow shadow;

  /// The interactive state of the button, such as enabled or disabled.
  final ButtonState state;

  /// An accessibility label that describes the button's action or purpose.
  /// This will be rendered as an `aria-label` attribute in HTML.
  final String? semanticLabel;

  /// Whether the button should take the full width of its container.
  final bool fullWidth;

  /// The general size variant of the button (e.g., small, medium, large).
  final ButtonSize size;

  /// An optional icon or emoji to display before the button text.
  final String? icon;

  /// Creates a new [FlintButton].
  ///
  /// All parameters are optional except [text] and [url].
  /// Use [state] to disable the button, preventing user interaction.
  FlintButton({
    required this.text,
    required this.url,
    this.style,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
    this.borderRadius = const BorderRadius.circular(6.0),
    this.shadow = const BoxShadow(
      offsetY: 2,
      blurRadius: 4,
      color: 'rgba(0, 0, 0, 0.1)',
    ),
    this.state = ButtonState.enabled,
    this.semanticLabel,
    this.fullWidth = false,
    this.size = ButtonSize.medium,
    this.icon,
  });

  /// Converts this button into an HTML representation.
  ///
  /// - Uses `<a>` tag when enabled.
  /// - Uses `<span>` tag when disabled.
  /// - Includes full inline CSS for consistent rendering in emails.
  @override
  String toHtml() {
    final buttonStyle = _buildButtonStyle();
    final attributes = _buildButtonAttributes();
    final content = _buildButtonContent();

    if (state == ButtonState.disabled) {
      return '''
<span$attributes style="$buttonStyle">
  $content
</span>
''';
    }

    return '''
<a$attributes style="$buttonStyle">
  $content
</a>
''';
  }

  /// Converts this button into a plain-text representation.
  ///
  /// This is useful for CLI output or fallback text-based rendering.
  /// Example output:
  /// ```
  /// 🚀 Get Started: https://flintdart.dev
  /// ```
  @override
  String toText() {
    if (state == ButtonState.disabled) {
      return icon != null ? '$icon $text' : text;
    }
    return icon != null ? '$icon $text: $url' : '$text: $url';
  }

  /// Serializes this button into a JSON-compatible map.
  ///
  /// Useful for dynamic UI generation or exporting widget configurations.
  @override
  Map<String, dynamic> toJson() => {
        'type': 'button',
        'text': text,
        'url': url,
        'style': style?.toJson(),
        'padding': padding.toJson(),
        'borderRadius': borderRadius.toJson(),
        'shadow': shadow.toJson(),
        'state': state.name,
        'semanticLabel': semanticLabel,
        'fullWidth': fullWidth,
        'size': size.name,
        'icon': icon,
      };

  /// Builds the inline CSS string for this button.
  ///
  /// This method generates styles dynamically based on the button's
  /// [ButtonStyle], [EdgeInsets], [BorderRadius], [BoxShadow], and [ButtonState].
  String _buildButtonStyle() {
    final currentStyle = _getStyleForState();
    final styles = <String>[
      // Layout
      'display: ${fullWidth ? 'block' : 'inline-block'};',
      if (fullWidth) 'width: 100%;',
      'text-align: center;',
      'box-sizing: border-box;',

      // Typography
      'font-family: ${currentStyle.textStyle.fontFamily ?? '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif'};',
      'font-size: ${currentStyle.textStyle.fontSize ?? 16}px;',
      'font-weight: ${currentStyle.textStyle.fontWeight?.value ?? FontWeight.w600.value};',
      'color: ${currentStyle.textStyle.color ?? '#ffffff'};',
      'text-decoration: none;',
      'line-height: 1.5;',
      'white-space: nowrap;',

      // Background & Border
      'background-color: ${currentStyle.backgroundColor};',
      if (currentStyle.border != null)
        'border: ${currentStyle.border!.toCss()};',

      // Spacing
      'padding: ${padding.toCss()};',
      'border-radius: ${borderRadius.toCss()};',

      // Effects
      if (shadow.offsetX != 0 || shadow.offsetY != 0)
        'box-shadow: ${shadow.toCss()};',

      // Interactive states
      'transition: all 0.2s ease-in-out;',
      'cursor: ${state == ButtonState.disabled ? 'not-allowed' : 'pointer'};',
      'opacity: ${state == ButtonState.disabled ? '0.6' : '1.0'};',

      // Email client specific
      '-webkit-text-size-adjust: none;',
      'mso-hide: all;',
    ];

    return styles.join(' ');
  }

  /// Builds the HTML attributes for the button.
  ///
  /// Adds accessibility (`aria-*`) attributes, role definitions,
  /// and ensures proper behavior when the button is disabled.
  String _buildButtonAttributes() {
    final attrs = <String>[];

    if (semanticLabel != null) {
      attrs.add(' aria-label="${_escapeHtml(semanticLabel!)}"');
    }

    if (state != ButtonState.disabled) {
      attrs.add(' href="$url" target="_blank"');
    } else {
      attrs.add(' aria-disabled="true"');
    }

    attrs.add(' role="button"');
    attrs.add(' style="text-decoration: none;"');

    return attrs.join();
  }

  /// Builds the inner HTML content of the button.
  ///
  /// When [icon] is provided, it appears before the text.
  String _buildButtonContent() {
    final content = _escapeHtml(text);
    if (icon != null) {
      return '''
<span style="display: inline-block; vertical-align: middle; margin-right: 8px; font-size: ${(style?.textStyle.fontSize ?? 16) - 2}px;">
  $icon
</span>
<span style="display: inline-block; vertical-align: middle;">
  $content
</span>
''';
    }
    return content;
  }

  /// Determines the appropriate [ButtonStyle] based on the current [state].
  ///
  /// For example, when disabled, the background and text colors are adjusted.
  ButtonStyle _getStyleForState() {
    if (state == ButtonState.disabled) {
      return style!.copyWith(
        backgroundColor: style?.disabledColor ?? '#6c757d',
        textStyle: style!.textStyle.copyWith(color: '#ffffff'),
      );
    }
    return style!;
  }

  /// Escapes HTML special characters in [text] for safe rendering.
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Returns a new [FlintButton] with updated properties while keeping
  /// unspecified values the same.
  FlintButton copyWith({
    String? text,
    String? url,
    ButtonStyle? style,
    EdgeInsets? padding,
    BorderRadius? borderRadius,
    BoxShadow? shadow,
    ButtonState? state,
    String? semanticLabel,
    bool? fullWidth,
    ButtonSize? size,
    String? icon,
  }) {
    return FlintButton(
      text: text ?? this.text,
      url: url ?? this.url,
      style: style ?? this.style,
      padding: padding ?? this.padding,
      borderRadius: borderRadius ?? this.borderRadius,
      shadow: shadow ?? this.shadow,
      state: state ?? this.state,
      semanticLabel: semanticLabel ?? this.semanticLabel,
      fullWidth: fullWidth ?? this.fullWidth,
      size: size ?? this.size,
      icon: icon ?? this.icon,
    );
  }

  /// {@macro flint_widget.buildTemplate}
  ///
  /// Since [FlintButton] is a leaf widget (it cannot have children),
  /// this simply returns itself.
  @override
  FlintWidget buildTemplate() => this;
}
