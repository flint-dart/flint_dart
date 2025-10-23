import 'dart:convert';

typedef FlintCallback = void Function(Map<String, dynamic> event);

class FlintAction {
  final String type;
  final dynamic data;
  final FlintCallback? onComplete;

  const FlintAction._(this.type, [this.data, this.onComplete]);

  // 🔹 Run JavaScript inline
  factory FlintAction.script(String js, {FlintCallback? onComplete}) =>
      FlintAction._('script', js, onComplete);

  // 🔹 Call an API endpoint
  factory FlintAction.api(String url,
      {Map<String, dynamic>? body, FlintCallback? onComplete}) {
    return FlintAction._('api', {'url': url, 'body': body}, onComplete);
  }

  // 🔹 Update text/value of an element
  factory FlintAction.update(String selector, String value,
      {FlintCallback? onComplete}) {
    return FlintAction._(
        'update', {'selector': selector, 'value': value}, onComplete);
  }

  // 🔹 Update widget state (reactive)
  factory FlintAction.setState(String key, dynamic value,
      {FlintCallback? onComplete}) {
    return FlintAction._('state', {'key': key, 'value': value}, onComplete);
  }

  // 🔹 Log to console
  factory FlintAction.log(String message, {FlintCallback? onComplete}) =>
      FlintAction._('log', message, onComplete);

  // 🔹 Show alert
  factory FlintAction.alert(String message, {FlintCallback? onComplete}) =>
      FlintAction._('alert', message, onComplete);

  // 🔹 Run multiple actions in sequence
  factory FlintAction.sequence(List<FlintAction> actions) =>
      FlintAction._('sequence', actions.map((a) => a.toJson()).toList());

  // 🔹 🔥 NEW: Call a Dart function or method directly
  factory FlintAction.call(FlintCallback function,
      {Map<String, dynamic>? args}) {
    return FlintAction._('call', {'args': args ?? {}}, function);
  }

  // Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
        'type': type,
        'data': data,
      };

  // ✅ Convert to executable JS
  String toJs() {
    switch (type) {
      case 'api':
        final url = data['url'];
        final body = data['body'] ?? {};
        final jsonBody =
            body.isNotEmpty ? 'body: JSON.stringify(${_encodeJs(body)}),' : '';
        return '''
fetch("$url", {
  method: "POST",
  headers: {"Content-Type": "application/json"},
  $jsonBody
}).then(res => res.json())
  .then(data => console.log("✅ API Success:", data))
  .catch(err => console.error("❌ API Error:", err));
''';

      case 'alert':
        return "alert('${_escape(data.toString())}');";

      case 'update':
        final selector = data['selector'];
        final value = _escape(data['value']);
        return "document.querySelector('$selector').innerText = '$value';";

      case 'state':
        final key = _escape(data['key']);
        final value = jsonEncode(data['value']);
        return '''
window.__flintState = window.__flintState || {};
window.__flintState['$key'] = $value;
document.dispatchEvent(new CustomEvent('flintStateUpdate', {detail: {key: '$key', value: $value}}));
''';

      case 'log':
        return "console.log('${_escape(data.toString())}');";

      case 'sequence':
        final actions = (data as List)
            .map((a) => FlintAction._(a['type'], a['data']).toJs())
            .join('\n');
        return actions;

      case 'script':
        return data.toString();

      case 'call':
        // purely Dart-side action — nothing to run on JS
        return '';

      default:
        return '';
    }
  }

  // 🔧 Escape for JS
  String _escape(String value) =>
      value.replaceAll("'", "\\'").replaceAll('\n', '\\n').replaceAll('\r', '');

  // 🔧 Encode Dart map to JS object
  String _encodeJs(Map<String, dynamic> map) {
    final entries = map.entries
        .map((e) =>
            "'${e.key}': ${e.value is String ? "'${_escape(e.value)}'" : e.value}")
        .join(', ');
    return '{ $entries }';
  }

  // ✅ Execute callback for Dart actions
  void triggerCallback([Map<String, dynamic>? event]) {
    if (onComplete != null) {
      onComplete!(event ?? {});
    }
  }

  // ✅ Execute call actions directly
  void execute() {
    if (type == 'call' && onComplete != null) {
      onComplete!(data['args'] ?? {});
    }
  }
}
