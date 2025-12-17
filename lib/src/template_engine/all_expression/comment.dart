import 'base_run.dart';

class CommentProcessor implements BaseExpression {
  @override
  String run(String content, [Map<String, dynamic>? context]) {
    final commentPattern = RegExp(r"\{{\#.*?\#\}}", dotAll: true);
    return content.replaceAllMapped(commentPattern, (_) {
      return '';
    });
  }
}
