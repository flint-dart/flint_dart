import 'package:flint_dart/flint_dart.dart';
import 'package:sample/controllers/http_controller_example.dart';
import 'package:sample/controllers/websocket_controller_example.dart';

class UserRoutes extends RouteGroup {
  @override
  String get prefix => '/users';

  @override
  void register(Flint app) {
    app.post(
      '/',
      useController(HttpUserController.new, (c) => c.create()),
    );

    app.get(
      '/:id',
      useController(HttpUserController.new, (c) => c.showProfile()),
    );
  }
}

class ChatRoutes extends RouteGroup {
  @override
  String get prefix => '/ws';

  @override
  void register(Flint app) {
    app.websocket(
      '/chat',
      useControllerVoid(ChatSocketController.new, (c) {
        c.connect();
        c.joinRoom();
      }),
    );
  }
}

void registerGroupedControllerRoutes(Flint app) {
  app.routes(UserRoutes());
  app.routes(ChatRoutes());
}
