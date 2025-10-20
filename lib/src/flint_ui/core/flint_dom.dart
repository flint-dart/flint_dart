// // lib/flint_ui/core/flint_dom.dart

// import 'package:flint_dart/src/flint_ui/core/core.dart';

// class FlintDOM {
//   /// Select an element by selector (mimics querySelector)
//   static FlintWidget select(String selector) {
//     return FlintWidget(selector);
//   }

//   /// Select multiple elements (mimics querySelectorAll)
//   static FlintWidgetList selectAll(String selector) {
//     return FlintWidgetList(selector);
//   }

//   /// Window alert
//   static void alert(String message) {
//     // This will be converted to window.alert in JS
//     _addToRuntime('window.alert("${_escapeString(message)}");');
//   }

//   /// Console log
//   static void log(String message) {
//     _addToRuntime('console.log("${_escapeString(message)}");');
//   }

//   /// Set document title
//   static void setTitle(String title) {
//     _addToRuntime('document.title = "${_escapeString(title)}";');
//   }

//   /// Add event listener to window
//   static void onWindowLoad(void Function() callback) {
//     final callbackName = _generateCallbackName();
//     _registerCallback(callbackName, callback);
//     _addToRuntime('window.addEventListener("load", $callbackName);');
//   }

//   /// Add event listener to document
//   static void onDocumentReady(void Function() callback) {
//     final callbackName = _generateCallbackName();
//     _registerCallback(callbackName, callback);
//     _addToRuntime('''
//       if (document.readyState === 'loading') {
//         document.addEventListener('DOMContentLoaded', $callbackName);
//       } else {
//         $callbackName();
//       }
//     ''');
//   }

//   // Internal runtime management
//   static final List<String> _runtimeCode = [];
//   static final Map<String, DartFunction> _callbacks = {};

//   static String _escapeString(String input) {
//     return input.replaceAll('"', '\\"').replaceAll('\n', '\\n');
//   }

//   static String _generateCallbackName() {
//     return '__flint_callback_${_callbacks.length}';
//   }

//   static void _registerCallback(String name, void Function() callback) {
//     // Convert Dart callback to JS function
//     _callbacks[name] = DartFunction('''
//       // Dart callback implementation
//       ${callback.toString().replaceAll('() {', '').replaceAll('}', '')}
//     ''');
//   }

//   static void _addToRuntime(String code) {
//     _runtimeCode.add(code);
//   }

//   /// Get the compiled JavaScript runtime
//   static String getRuntimeJS() {
//     final callbackDefinitions = _callbacks.entries
//         .map((entry) => 'const ${entry.key} = ${entry.value.jsCode};')
//         .join('\n');

//     return '''
// // FlintDOM Runtime
// (function() {
//   $callbackDefinitions

//   ${_runtimeCode.join('\n  ')}
// })();
// ''';
//   }

//   /// Clear runtime (for multiple widgets)
//   static void clearRuntime() {
//     _runtimeCode.clear();
//     _callbacks.clear();
//   }
// }
