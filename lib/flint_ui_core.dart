/// Core component, node, style, storage, navigation, and widget APIs.
///
/// Import this from tests, shared component packages, and lower-level code that
/// should use Flint UI primitives without directly depending on app mounting
/// helpers.
library;

export 'src/ui/auth/auth_session.dart';
export 'src/ui/browser/document_stub.dart'
    if (dart.library.js_interop) 'src/ui/browser/document.dart';
export 'src/ui/browser/events_stub.dart'
    if (dart.library.js_interop) 'src/ui/browser/events.dart';
export 'src/ui/browser/geolocation_stub.dart'
    if (dart.library.js_interop) 'src/ui/browser/geolocation.dart';
export 'src/ui/browser/media_capture_stub.dart'
    if (dart.library.js_interop) 'src/ui/browser/media_capture.dart';
export 'src/ui/browser/media_devices_stub.dart'
    if (dart.library.js_interop) 'src/ui/browser/media_devices.dart';
export 'src/ui/client/client_router.dart';
export 'src/ui/component.dart';
export 'src/ui/component_props.dart' hide toFlintNode;
export 'src/ui/component_registry.dart';
export 'src/ui/config/environment_config_stub.dart'
    if (dart.library.js_interop) 'src/ui/config/environment_config.dart';
export 'src/ui/data/resource.dart';
export 'src/ui/head.dart';
export 'src/ui/html.dart';
export 'src/ui/navigation/navigation_stub.dart'
    if (dart.library.js_interop) 'src/ui/navigation/navigation.dart';
export 'src/ui/navigation/query_params_stub.dart'
    if (dart.library.js_interop) 'src/ui/navigation/query_params.dart';
export 'src/ui/node.dart';
export 'src/ui/state/state_signal.dart';
export 'src/ui/storage/browser_storage.dart';
export 'src/ui/storage/cookies.dart';
export 'src/ui/storage/local_storage.dart';
export 'src/ui/storage/session_storage.dart';
export 'src/ui/style.dart';
export 'src/ui/widgets.dart';
