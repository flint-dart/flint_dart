// lib/flint_ui/core/flint_element.dart
import 'flint_widget.dart';
import 'flint_render_object.dart';
import 'flint_state.dart';

/// Element: bridges Widget -> RenderObject and manages lifecycle.
abstract class FlintElement {
  FlintWidget widget;
  late FlintRenderObject renderObject;

  FlintElement(this.widget);

  /// Called once when the element is inserted into the tree.
  void mount();

  /// Called when widget configuration changes.
  void update(FlintWidget newWidget) {
    widget = newWidget;
    rebuild();
  }

  /// Rebuilds (re-sync renderObject from widget).
  void rebuild() {
    renderObject.updateFromWidget(widget);
  }

  /// Serialize current DOM/HTML for server-side rendering
  String toHtml() => renderObject.toHtml();
}

/// A basic stateless element implementation.
class FlintStatelessElement extends FlintElement {
  final FlintRenderObject Function(FlintWidget widget) createRender;

  FlintStatelessElement(super.widget, this.createRender);

  @override
  void mount() {
    renderObject = createRender(widget);
  }
}

/// A stateful element holds a [FlintState] instance (if widget is stateful).
class FlintStatefulElement extends FlintElement {
  final FlintState state;

  FlintStatefulElement(super.widget, this.state) {
    state.element = this;
  }

  @override
  void mount() {
    renderObject = state.createRenderObject();
    // ensure renderObject has initial widget values
    renderObject.updateFromWidget(widget);
  }

  @override
  void rebuild() {
    // ask state to build a widget tree representation (optional)
    final newWidget = state.build();
    if (newWidget != widget) {
      update(newWidget);
    } else {
      renderObject.updateFromWidget(widget);
    }
  }
}
