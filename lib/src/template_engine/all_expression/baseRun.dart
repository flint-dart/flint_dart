/// An interface (abstract class) for replacing placeholders in a template.
abstract class BaseExpression {
  /// Replaces the placeholders in [content] with data from [context].
  String run(String content, [Map<String, dynamic>? context]);
}
