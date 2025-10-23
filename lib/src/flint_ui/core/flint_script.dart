import 'package:flint_dart/src/flint_ui/core/flint_action.dart';

class FlintScript {
  final FlintAction? onClick;
  final FlintAction? onLoad;
  final FlintAction? onSuccess;
  final FlintAction? onError;
  final String? customJs;

  const FlintScript({
    this.onClick,
    this.onLoad,
    this.onSuccess,
    this.onError,
    this.customJs,
  });

  /// Create a script directly from raw JavaScript
  const FlintScript.custom(this.customJs)
      : onClick = null,
        onLoad = null,
        onSuccess = null,
        onError = null;

  /// Generates the final <script> HTML for a given target element
  String toHtml(String targetId) {
    final handlers = <String, String>{};

    if (onClick != null) {
      handlers['click'] = onClick!.toJs();
    } else if (customJs != null) {
      handlers['click'] = customJs!;
    }

    if (onLoad != null) {
      handlers['load'] = onLoad!.toJs();
    }

    final eventScripts = handlers.entries.map((entry) {
      return "document.querySelector('#$targetId')?.addEventListener('${entry.key}', () => { ${entry.value.trim()} });";
    }).join('\n');

    return '''
<script>
document.addEventListener('DOMContentLoaded', () => {
  $eventScripts
});
</script>
''';
  }

  Map<String, dynamic> toJson() => {
        if (onClick != null) 'onClick': onClick!.toJson(),
        if (onLoad != null) 'onLoad': onLoad!.toJson(),
        if (onSuccess != null) 'onSuccess': onSuccess!.toJson(),
        if (onError != null) 'onError': onError!.toJson(),
        if (customJs != null) 'custom': customJs,
      };
}
