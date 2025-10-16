// lib/flint_ui/widgets/button.dart

import 'package:flint_dart/src/flint_ui/core/box_style.dart';
import 'package:flint_dart/src/flint_ui/core/button_style.dart';
import 'package:flint_dart/src/flint_ui/core/edge_insets.dart';
import 'package:flint_dart/src/flint_ui/core/framework.dart';
import 'package:flint_dart/src/flint_ui/core/style.dart';

class FlintButton extends FlintWidget {
  final String text;
  final String url;
  final ButtonStyle? style;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final BoxShadow shadow;
  final ButtonState state;
  final String? semanticLabel;
  final bool fullWidth;
  final ButtonSize size;
  final String? icon;

  FlintButton({
    required this.text,
    required this.url,
    this.style,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
    this.borderRadius = const BorderRadius.circular(6.0),
    this.shadow =
        const BoxShadow(offsetY: 2, blurRadius: 4, color: 'rgba(0, 0, 0, 0.1)'),
    this.state = ButtonState.enabled,
    this.semanticLabel,
    this.fullWidth = false,
    this.size = ButtonSize.medium,
    this.icon,
  });

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

  @override
  String toText() {
    if (state == ButtonState.disabled) {
      return icon != null ? '$icon $text' : text;
    }
    return icon != null ? '$icon $text: $url' : '$text: $url';
  }

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

    // Add role for accessibility
    attrs.add(' role="button"');

    // Email client specific
    attrs.add(' style="text-decoration: none;"');

    return attrs.join();
  }

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

  ButtonStyle _getStyleForState() {
    if (state == ButtonState.disabled) {
      return style!.copyWith(
        backgroundColor: style?.disabledColor ?? '#6c757d',
        textStyle: style!.textStyle.copyWith(color: '#ffffff'),
      );
    }
    return style!;
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Creates a copy of this button with updated properties
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

  @override
  FlintWidget buildTemplate() {
    // For images, we return self since we're a leaf widget
    return this;
  }
}
