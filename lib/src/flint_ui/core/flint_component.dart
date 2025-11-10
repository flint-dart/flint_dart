import 'package:flint_dart/flint_ui.dart';

import 'flint_widget.dart';
import 'flint_template.dart';

abstract class FlintComponent extends FlintTemplate {
  /// The reactive state of this component
  Map<String, dynamic> state();

  /// Build the UI using FlintWidgets
  FlintWidget render();

  @override
  FlintWidget buildTemplate() {
    // Serialize state() map to x-data
    final xData = _serializeState(state());
    return FlintBox(
      xData: xData,
      children: [render()],
    );
  }

  String _serializeState(Map<String, dynamic> state) {
    final entries = state.entries.map((e) {
      final value = e.value;
      if (value is String) {
        return "${e.key}: '${value.replaceAll("'", "\\'")}'";
      } else {
        return "${e.key}: $value";
      }
    }).join(', ');
    return "{ $entries }";
  }
}
