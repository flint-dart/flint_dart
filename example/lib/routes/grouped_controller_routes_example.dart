import 'package:flint_dart/flint_dart.dart';
import 'package:sample/controllers/http_controller_example.dart';
import 'package:sample/controllers/websocket_controller_example.dart';

class UserRoutes extends RouteGroup {
  @override
  String get prefix => '/users';

  @override
  void register(Flint app) {
    final users = app.controller(HttpUserController.new);

    users.post('/', (c) => c.create());
    users.get('/:id', (c) => c.showProfile());
  }
}

class ChatRoutes extends RouteGroup {
  @override
  String get prefix => '/ws';

  @override
  String get tag => 'WebSocket';

  @override
  void register(Flint app) {
    final chat = app.controller(ChatSocketController.new);

    /// @summary Chat websocket handshake
    /// @response 101 Switching Protocols
    chat.websocket('/chat', (c) {
      c.connect();
      c.joinRoom();
    });
  }
}

void registerGroupedControllerRoutes(Flint app) {
  app.routes(UserRoutes());
  app.routes(ChatRoutes());
}
