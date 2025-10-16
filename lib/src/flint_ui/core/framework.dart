// lib/flint_ui/core/framework.dart

/// Base widget that can render to multiple output formats
abstract class FlintWidget {
  /// Render to HTML (for emails, web)
  String toHtml();

  /// Render to plain text (fallback, CLI, etc.)
  String toText();

  /// Render to intermediate JSON (for APIs, mobile apps, etc.)
  Map<String, dynamic> toJson();

  /// Build the widget template - MUST be implemented by subclasses
  FlintWidget buildTemplate();

  /// Future: Render to PDF, Flutter widgets, etc.
  // Future<Uint8List> toPdf();
  // Widget toFlutter();
}

/// Base class for all template widgets - ensures consistency
abstract class FlintTemplate extends FlintWidget {
  /// Default implementation that delegates to buildTemplate()
  @override
  String toHtml() {
    return buildTemplate().toHtml();
  }

  @override
  String toText() {
    return buildTemplate().toText();
  }

  @override
  Map<String, dynamic> toJson() {
    return buildTemplate().toJson();
  }

  /// MUST be implemented by all template classes
  @override
  FlintWidget buildTemplate();
}

/// Base container with layout capabilities
abstract class FlintContainer extends FlintWidget {
  final List<FlintWidget> children;

  FlintContainer({
    required this.children,
  });
}

/// Theme and styling system
class FlintTheme {
  final String primaryColor;
  final String fontFamily;
  final double baseFontSize;

  const FlintTheme({
    this.primaryColor = '#007cba',
    this.fontFamily =
        '-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif',
    this.baseFontSize = 16.0,
  });
}
