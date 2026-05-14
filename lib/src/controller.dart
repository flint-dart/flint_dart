import 'dart:async';

import 'context.dart';
import 'request.dart';
import 'response.dart';
import 'websocket/websocket.dart';

typedef Socket = FlintWebSocket;
typedef ControllerFactory<T extends Controller> = T Function();
typedef ControllerCallback<T extends Controller> = FutureOr<Object?> Function(
  T controller,
);

/// Creates a route handler that instantiates, binds, and disposes a controller
/// per request. This keeps controller context request-scoped for HTTP and WS.
Handler controllerAction<T extends Controller>(
  ControllerFactory<T> factory,
  ControllerCallback<T> callback,
) {
  return (ctx) async {
    final controller = factory()..bind(ctx);
    try {
      return await callback(controller);
    } finally {
      controller.unbind();
    }
  };
}

/// Short alias for [controllerAction].
///
/// Example:
/// ```dart
/// app.get('/users', controller(UserController.new, (c) => c.index()));
/// ```
Handler controller<T extends Controller>(
  ControllerFactory<T> factory,
  ControllerCallback<T> callback,
) {
  return controllerAction(factory, callback);
}

/// Short alias for controller actions that do not return a value.
Handler controllerVoid<T extends Controller>(
  ControllerFactory<T> factory,
  void Function(T controller) action,
) {
  return controllerAction(factory, (controller) {
    action(controller);
    return null;
  });
}

class ControllerContextException implements Exception {
  final String message;

  ControllerContextException(this.message);

  @override
  String toString() => 'ControllerContextException: $message';
}

abstract class Controller {
  Context? _context;

  void bind(Context context) {
    _context = context;
    onBind(context);
  }

  void unbind() {
    _context = null;
  }

  /// Hook for subclasses to initialize request-scoped state.
  void onBind(Context context) {}

  bool get isBound => _context != null;
  bool get isHttp => context.isHttp;
  bool get isWebSocket => context.isWebSocket;

  Context get context {
    final ctx = _context;
    if (ctx == null) {
      throw ControllerContextException(
        'Controller is not bound to a Context. Call bind(context) before '
        'accessing req/res/socket or invoking controller actions.',
      );
    }
    return ctx;
  }

  Request get req => context.req;

  Response get res {
    final response = context.res;
    if (response == null) {
      throw ControllerContextException(
        'Response is unavailable in this controller action. This route is '
        'running in a WebSocket context.',
      );
    }
    return response;
  }

  Socket get socket {
    final ws = context.socket;
    if (ws == null) {
      throw ControllerContextException(
        'Socket is unavailable in this controller action. This route is '
        'running in an HTTP context.',
      );
    }
    return ws;
  }

  /// Extensible typed storage for future session/user injection.
  T? read<T>() => context.read<T>();

  /// Extensible typed storage for future session/user injection.
  void write<T>(T value) => context.write<T>(value);

  /// Keyed storage when type keys are not sufficient.
  T? getExtra<T>(Object key) => context.getExtra<T>(key);

  void setExtra(Object key, Object? value) => context.setExtra(key, value);
}

/// Convenience extension (typically used inside [RouteGroup] classes) to
/// reduce controllerAction boilerplate without requiring a mixin.
extension ControllerRouteExtension on Object {
  Handler useController<T extends Controller>(
    ControllerFactory<T> factory,
    ControllerCallback<T> action,
  ) {
    return controller(factory, action);
  }

  Handler useControllerVoid<T extends Controller>(
    ControllerFactory<T> factory,
    void Function(T controller) action,
  ) {
    return controllerVoid(factory, action);
  }
}
