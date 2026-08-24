/// Browser entrypoint APIs for building Flint UI applications.
///
/// Import this from Dart files that mount a browser UI with `createFlintApp`.
/// It includes the core component/widget APIs plus browser rendering, page
/// registry, and stylesheet registration helpers.
library;

export 'flint_ui_core.dart';
export 'src/ui/browser_renderer_stub.dart'
    if (dart.library.js_interop) 'src/ui/browser_renderer.dart';
export 'src/ui/pages_stub.dart'
    if (dart.library.js_interop) 'src/ui/pages.dart';
export 'src/ui/style_browser_stub.dart'
    if (dart.library.js_interop) 'src/ui/style_browser.dart';
