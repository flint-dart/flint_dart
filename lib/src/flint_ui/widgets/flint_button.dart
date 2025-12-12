import 'dart:math';
import 'package:flint_dart/src/flint_ui/core/core.dart';

/// {{template flint_button}
/// A customizable and responsive button widget for **Flint UI**, designed to
/// render as HTML, text, or JSON — and now supports client-side actions via
/// [FlintScript] or [FlintAction].
///
/// Each [Button] automatically generates a unique [id] that can be used
/// for DOM updates or targeting via scripts. Developers can override the [id]
/// manually if desired.
///
/// Example usage:
/// ```dart
/// Button(
///   text: 'Save',
///   onClick: FlintAction.api('/api/user/update', {'id': 1, 'name': 'Hybiekay'}),
/// )
/// ```
///
/// Or a static inline script:
/// ```dart
/// Button(
///   text: 'Alert',
///   onClick: FlintScript.custom("alert('Hello Flint!');"),
/// )
/// ```
/// {{endtemplate}
class Button extends FlintWidget {
  /// Unique identifier for this widget instance.
  /// Automatically generated unless overridden by user.
  @override
  // ignore: overridden_fields
  final String id;

  /// The text displayed inside the button.
  final String text;

  /// The URL or target destination the button links to (if applicable).
  final String? url;

  /// Optional visual appearance configuration.
  final ButtonStyle? style;

  /// Padding around content.
  final EdgeInsets padding;

  /// Border radius for rounded corners.
  final BorderRadius borderRadius;

  /// Drop shadow for elevation effect.
  final BoxShadow shadow;

  /// Whether the button is clickable or disabled.
  final ButtonState state;

  /// Accessibility label.
  final String? semanticLabel;

  /// Whether the button should expand to full width.
  final bool fullWidth;

  /// Visual size variant (small, medium, large).
  final ButtonSize size;

  /// Optional icon (emoji or symbol).
  final String? icon;

  /// Optional script to run when clicked.
  final dynamic onClick; // can be FlintAction or FlintScript

  /// Creates a new [Button].
  Button({
    String? id,
    required this.text,
    this.url,
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
    this.onClick,
    super.xData,
    super.xInit,
    super.xShow,
    super.xBind,
    super.xOn,
    super.xText,
    super.xHtml,
    super.xModel,
    super.xModelable,
    super.xFor,
    super.xTransition,
    super.xEffect,
    super.xIgnore,
    super.xRef,
    super.xCloak,
    super.xTeleport,
    super.xIf,
    super.xId,
  }) : id = id ?? _generateId();

  /// Generates a random unique element ID like `flint-btn-7f3a9`.
  static String _generateId() {
    final random = Random();
    final hex =
        List.generate(5, (_) => random.nextInt(16).toRadixString(16)).join();
    return 'flint-btn-$hex';
  }

  // ---------------------------------------------------------------------------
  // 🧱 RENDER METHODS
  // ---------------------------------------------------------------------------

  @override
  @override
  String toHtml() {
    final buttonStyle = _buildButtonStyle();
    final attributes = _buildButtonAttributes();
    final content = _buildButtonContent();

    final scriptHtml = _buildScriptHtml();

    final tag = state == ButtonState.disabled ? 'span' : 'button';

    return '''
<$tag$attributes style="$buttonStyle">
  $content
</$tag>
$scriptHtml
''';
  }

  String _buildScriptHtml() {
    if (onClick == null) return '';

    // Handle FlintScript directly
    if (onClick is FlintScript) {
      return (onClick as FlintScript).toHtml(id);
    }

    // Handle FlintAction
    if (onClick is FlintAction) {
      final js = (onClick as FlintAction).toJs();
      return '''
<script>
document.querySelector('#$id')?.addEventListener('click', () => {
  $js
});
</script>
''';
    }

    // Unsupported type
    return '';
  }

  @override
  String toText() {
    if (state == ButtonState.disabled) {
      return icon != null ? '$icon $text' : text;
    }
    return icon != null ? '$icon $text: ${url ?? ''}' : '$text: ${url ?? ''}';
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'button',
        'id': id,
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
        'onClick': onClick?.toJson(),
      };

  // ---------------------------------------------------------------------------
  // 🎨 STYLE + ATTRIBUTES HELPERS
  // ---------------------------------------------------------------------------

  String _buildButtonStyle() {
    final currentStyle = _getStyleForState();
    final styles = <String>[
      'display: ${fullWidth ? 'block' : 'inline-block'};',
      if (fullWidth) 'width: 100%;',
      'text-align: center;',
      'box-sizing: border-box;',
      'font-family: ${currentStyle.textStyle.fontFamily ?? 'inherit'};',
      'font-size: ${currentStyle.textStyle.fontSize ?? 16}px;',
      'font-weight: ${currentStyle.textStyle.fontWeight?.value ?? 500};',
      'color: ${currentStyle.textStyle.color ?? '#fff'};',
      'background-color: ${currentStyle.backgroundColor};',
      if (currentStyle.border != null)
        'border: ${currentStyle.border!.toCss()};',
      'padding: ${padding.toCss()};',
      'border-radius: ${borderRadius.toCss()};',
      if (shadow.offsetY != 0) 'box-shadow: ${shadow.toCss()};',
      'cursor: ${state == ButtonState.disabled ? 'not-allowed' : 'pointer'};',
      'opacity: ${state == ButtonState.disabled ? '0.6' : '1.0'};',
      'transition: all 0.2s ease;',
    ];
    return styles.join(' ');
  }

  String _buildButtonAttributes() {
    final attrs = <String>[];
    attrs.add(' id="$id"');
    attrs.add(' role="button"');
    if (semanticLabel != null) {
      attrs.add(' aria-label="${_escapeHtml(semanticLabel!)}"');
    }

    final dir = directives.entries
        .map((e) => e.value.isEmpty ? e.key : '${e.key}="${e.value}"')
        .join(' ');
    if (dir.isNotEmpty) attrs.add(dir);
    if (url != null && state != ButtonState.disabled) {
      attrs.add(' data-url="$url"');
    }
    return attrs.join();
  }

  String _buildButtonContent() {
    final content = _escapeHtml(text);
    if (icon != null) {
      return '''
<span style="margin-right: 6px;">$icon</span> $content
''';
    }
    return content;
  }

  ButtonStyle _getStyleForState() {
    if (state == ButtonState.disabled && style != null) {
      return style!.copyWith(
        backgroundColor: style?.disabledColor ?? '#999',
        textStyle: style!.textStyle.copyWith(color: '#fff'),
      );
    }
    return style ?? ButtonStyle.primary();
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  @override
  FlintWidget buildTemplate() => this;
}
