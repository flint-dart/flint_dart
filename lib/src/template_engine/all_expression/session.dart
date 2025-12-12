import 'package:flint_dart/src/template_engine/all_expression/baseRun.dart';
import 'package:flint_dart/src/template_engine/template_engine.dart';

class SessionProcessor implements BaseExpression {
  @override
  String run(String content, [Map<String, dynamic>? context]) {
    final hasSessionPattern = RegExp(
      r"hasSession\(\s*'([^']*)'\s*\)",
      dotAll: true,
    );

    content = content.replaceAllMapped(hasSessionPattern, (match) {
      final sessionKey = match.group(1);
      return TemplateEngine().sessions.containsKey(sessionKey).toString();
    });

    final sessionPattern = RegExp(
      r"\{{\s*session\(\s*'([^']*)'\s*\)\s*}}",
      dotAll: true,
    );

    content = content.replaceAllMapped(sessionPattern, (math) {
      final sessionKey = math.group(1);
      return TemplateEngine().sessions[sessionKey] ?? '';
    });

    return content;
  }
}
