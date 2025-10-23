// lib/flint_ui/core/flint_template.dart
import 'flint_widget.dart';
import 'flint_element.dart';
import 'flint_state.dart';
import 'flint_render_object.dart';

/// Stateless builder for Flint templates (no state).
abstract class FlintTemplate extends FlintWidget {
  FlintTemplate({super.id, super.script});

  @override
  FlintWidget buildTemplate();

  FlintElement createElement() {
    return FlintStatelessElement(this, (widget) {
      final built = buildTemplate();
      return BasicRenderObject(built);
    });
  }

  @override
  String toHtml() {
    final element = createElement();
    element.mount();
    return element.toHtml();
  }

  @override
  String toText() => buildTemplate().toText();

  @override
  Map<String, dynamic> toJson() => buildTemplate().toJson();
}

/// A template that holds mutable state (like StatefulWidget).
abstract class FlintStatefulTemplate<T> extends FlintStatefulWidget {
  final T initialState;
  late T state;

  FlintStatefulTemplate({required this.initialState, super.id, super.script});

  @override
  FlintState<FlintStatefulTemplate<T>> createState() =>
      _FlintTemplateState<T>();

  void setState(T newState) {}
}

/// Internal auto state manager for FlintStatefulTemplate
class _FlintTemplateState<T> extends FlintState<FlintStatefulTemplate<T>> {
  @override
  FlintRenderObject createRenderObject() {
    return BasicRenderObject(widget.buildTemplate());
  }

  @override
  FlintWidget build() {
    return widget.buildTemplate();
  }
}
