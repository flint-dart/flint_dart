import 'package:flint_dart/flint_dart.dart';
import 'package:sample/src/middlewares/auth_middleware.dart';
import 'package:sample/src/routes/auth_routes.dart';
import 'package:sample/src/routes/user_routes.dart';

void main() {
  final app = Flint(
    withDefaultMiddleware: true,
    enableSwaggerDocs: true,
    autoConnectDb: true,
    viewPath: 'lib/src/views', // 👈 point here
  );

  app.get('/', (req, res) async {
    return res.view("test_ws");
  });
  app.mount(
    "/users",
    registerUserRoutes,
  );

  app.get('/profile', (req, res) async {
    return res.json({'msg': 'This is a protected route'});
  }).useMiddleware(AuthMiddleware());
  app.websocket('/chat', (socket, params) {
    print('👋 Client connected: ${socket.id}');

    socket.onMessage((data) {
      print('💬 ${socket.id} says: $data');
      socket.broadcast('User ${socket.id}: $data');
    });

    socket.onClose(() {
      print('❌ Client disconnected: ${socket.id}');
    });

    socket.join("chat");
  });

  app.mount("/auth", authRoutes);
  app.listen(3000);
}
