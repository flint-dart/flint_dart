// lib/flint_ui/core/flint_render_object.dart
import 'flint_widget.dart';

/// Responsible for generating the actual HTML output.
abstract class FlintRenderObject {
  late FlintWidget widget;

  FlintRenderObject(this.widget);

  /// Called when the widget changes — should refresh computed output.
  void updateFromWidget(FlintWidget newWidget) {
    widget = newWidget;
  }

  /// Returns the rendered HTML string.
  String toHtml();
}

/// Basic render object for stateless widgets that just wrap HTML output.
class BasicRenderObject extends FlintRenderObject {
  BasicRenderObject(super.widget);

  @override
  String toHtml() => widget.toHtml();
}
