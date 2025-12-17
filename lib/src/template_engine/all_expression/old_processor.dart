import 'package:flint_dart/src/template_engine/template_engine.dart';

import 'base_run.dart';

class OldProcessor extends BaseExpression {
  @override
  String run(String content, [Map<String, dynamic>? context]) {
    final oldPattern = RegExp(
      r"\{{\s*old\(\s*'([^']*)'\s*\)\s*}}",
      dotAll: true,
    );

    content = content.replaceAllMapped(oldPattern, (oldMatch) {
      final oldKey = oldMatch.group(1);
      return TemplateEngine().formData[oldKey] ?? '';
    });

    return content;
  }
}
