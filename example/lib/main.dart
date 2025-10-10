import 'package:flint_dart/flint_dart.dart';
import 'package:sample/src/middlewares/auth_middleware.dart';
import 'package:sample/src/routes/auth_routes.dart';
import 'package:sample/src/routes/user_routes.dart';

void main() {
  final app = Flint(
    withDefaultMiddleware: true,
    enableSwaggerDocs: true,
    autoConnectDb: true,
    viewPath: 'lib/src/views',
  );

  app.get('/', (req, res) async {
    return res.view("test_ws");
  });

  app.get('/login', (req, res) async {
    return res.oAuthRedirect("google", callback: "/api/auth/google/callback");
  });
  app.mount("/users", registerUserRoutes);

  app.get('/profile', (req, res) async {
    return res.json({'msg': 'This is a protected route'});
  }).useMiddleware(AuthMiddleware());

  app.websocket('/chat', (socket, params) {
    print('👋 Client connected: ${socket.id}');

    // Store handler references for potential removal
    void Function(dynamic) messageHandler;
    void Function(dynamic) chatMessageHandler;

    // Listen for raw messages
    messageHandler = (data) {
      print('💬 ${socket.id} says: $data');
      socket.broadcast('User ${socket.id}: $data');
    };
    socket.onMessage(messageHandler);

    // Listen for specific chat events
    chatMessageHandler = (data) {
      print('📨 ${socket.id} sent message: $data');
      socket.emitToRoom('chat', 'new_message', {
        'from': socket.id,
        'message': data,
        'timestamp': DateTime.now().toIso8601String()
      });
    };
    socket.on('chat_message', chatMessageHandler);

    socket.on('join_room', (data) {
      if (data is String) {
        socket.join(data);
        socket.emit('room_joined', data);
        socket
            .emitToRoom(data, 'user_joined', {'user': socket.id, 'room': data});
      }
    });

    // Example: Remove specific handler after 5 minutes
    Future.delayed(Duration(minutes: 5), () {
      socket.off('chat_message', chatMessageHandler);
      print('Removed chat_message handler for ${socket.id}');
    });

    socket.onClose(() {
      print('❌ Client disconnected: ${socket.id}');
      socket.emitToRoom('chat', 'user_left',
          {'user': socket.id, 'timestamp': DateTime.now().toIso8601String()});
    });

    socket.join("chat");

    // Send welcome event
    socket.emit('welcome', {
      'message': 'Welcome to the chat!',
      'id': socket.id,
    });
  });

  // app.mount("/auth", authRoutes);
  app.listen(3000);
}
