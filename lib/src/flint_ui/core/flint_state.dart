// lib/flint_ui/core/flint_state.dart
import 'flint_script.dart';
import 'flint_widget.dart';
import 'flint_render_object.dart';
import 'flint_element.dart';

/// Base for widgets that hold mutable state. Similar to Flutter's StatefulWidget.
abstract class FlintStatefulWidget extends FlintWidget {
  FlintStatefulWidget({String? id, FlintScript? script})
      : super(id: id, script: script);

  FlintState createState();
}

/// State object paired to a [FlintStatefulWidget].
abstract class FlintState<T extends FlintStatefulWidget> {
  late T widget;
  late FlintStatefulElement element;

  /// Called once to create the RenderObject for this state (mount time).
  FlintRenderObject createRenderObject();

  /// Build returns the child widget tree representing the current state.
  FlintWidget build();

  /// setState: mutate internal state then ask element to rebuild.
  void setState(void Function() fn) {
    fn();
    // trigger a rebuild on the element (which will call state.build())
    element.rebuild();
  }
}
