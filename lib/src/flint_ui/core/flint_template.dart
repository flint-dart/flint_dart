// lib/flint_ui/core/flint_template.dart
import 'flint_widget.dart';

/// Stateless builder for Flint templates (no state).
abstract class FlintTemplate extends FlintWidget {
  FlintTemplate({super.id, super.script});

  @override
  FlintWidget buildTemplate();

  @override
  String toHtml() => buildTemplate().toHtml();

  @override
  String toText() => buildTemplate().toText();

  @override
  Map<String, dynamic> toJson() => buildTemplate().toJson();
}
