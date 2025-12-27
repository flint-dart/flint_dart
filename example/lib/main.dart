// import 'dart:convert';

import 'dart:convert';
import 'package:flint_dart/flint_dart.dart';
import 'package:sample/src/middlewares/auth_middleware.dart';
import 'package:sample/src/routes/auth_routes.dart';
import 'package:sample/src/routes/post_routes.dart';
import 'package:sample/src/routes/user_routes.dart';
import 'package:sample/src/views/welcome.dart';

void main() {
  final app = Flint(
    withDefaultMiddleware: true,
    enableSwaggerDocs: true,
    autoConnectDb: true,
    viewPath: 'lib/views',
  );

  app.use(LoggerMiddleware());

  app.get('/', (req, res) async {
    return res.render(Welcome());
  });
  app.mount("/post", postRoute);
// In your preview server routes
  // app.get('/preview/email/:type', (req, res) async {
  //   final type = req.params['type'];

  //   Mailable mail;

  //   switch (type) {
  //     case 'welcome':
  //       mail = WelcomeMail(
  //         recipientName: 'Preview User',
  //         recipientEmail: 'preview@example.com',
  //         verificationUrl: 'https://example.com/verify/preview',
  //         loginUrl: 'https://example.com/login',
  //       );
  //       break;

  //     case 'password-reset':
  //       mail = PasswordResetMail(
  //         recipientName: 'Preview User',
  //         recipientEmail: 'preview@example.com',
  //         resetUrl: 'https://example.com/reset/preview',
  //       );
  //       break;

  //     case 'order-confirmation':
  //       mail = OrderConfirmationMail(
  //         recipientName: 'Preview User',
  //         recipientEmail: 'preview@example.com',
  //         orderNumber: 'PREVIEW-123',
  //         orderDate: DateTime.now(),
  //         orderTotal: 99.99,
  //         items: [
  //           OrderItem(name: 'Preview Product', quantity: 1, price: 99.99),
  //         ],
  //       );
  //       break;

  //     default:
  //       return res.status(404).json({'error': 'Template not found'});
  //   }

  //   return res.renderEmail(mail);
  // });
  app.get('/login', (req, res) async {
    return res.oAuthRedirect("google", callback: "/api/auth/google/callback");
  });
  app.mount("/users", registerUserRoutes);

  app.get('/profile', (req, res) async {
    return res.json({'msg': 'This is a protected route'});
  }).useMiddleware(AuthMiddleware());

  // Store active users and rooms
  final Map<String, String> userNames = {};
  final Map<String, Set<String>> userRooms = {};

  app.websocket('/chat', (socket, params) {
    print('👋 Client connected: ${socket.id}');

    // Assign a random username
    final userName = 'User${socket.id.substring(0, 6)}';
    userNames[socket.id] = userName;
    userRooms[socket.id] = {'general'};

    // Send connection confirmation
    socket.emit('connected', {
      'userId': socket.id,
      'userName': userName,
      'message': 'Successfully connected to chat server',
      'timestamp': DateTime.now().toIso8601String()
    });

    // Join general room by default
    socket.join('general');

    // Broadcast user joined to general chat
    socket.emitToRoom('general', 'user_joined', {
      'userId': socket.id,
      'userName': userName,
      'timestamp': DateTime.now().toIso8601String(),
      'onlineUsers': userRooms.length
    });

    // Handle incoming messages - BOTH raw text and JSON
    socket.onMessage((data) {
      print('📨 Received from $userName: $data (type: ${data.runtimeType})');

      // Try to parse as JSON first
      if (data is String) {
        try {
          final parsed = json.decode(data);
          if (parsed is Map<String, dynamic>) {
            _handleJsonMessage(socket, userName, parsed);
            return;
          }
        } catch (e) {
          // If not JSON, treat as raw text message
          print('📝 Treating as raw text message');
          _handleRawMessage(socket, userName, data);
          return;
        }
      }

      // Handle other data types
      _handleRawMessage(socket, userName, data.toString());
    });

    // Handle typing events
    socket.on('typing_start', (data) {
      final room = data is Map ? data['room'] ?? 'general' : 'general';
      socket.emitToRoom(room, 'user_typing',
          {'userId': socket.id, 'userName': userName, 'isTyping': true});
    });

    socket.on('typing_stop', (data) {
      final room = data is Map ? data['room'] ?? 'general' : 'general';
      socket.emitToRoom(room, 'user_typing',
          {'userId': socket.id, 'userName': userName, 'isTyping': false});
    });

    // Handle joining specific rooms
    socket.on('join_room', (data) {
      if (data is String || (data is Map && data['room'] is String)) {
        final roomName = data is String ? data : data['room'] as String;

        // Leave previous rooms (except general)
        socket.rooms.where((room) => room != 'general').forEach((room) {
          socket.leave(room);
          userRooms[socket.id]?.remove(room);
        });

        // Join new room
        socket.join(roomName);
        userRooms[socket.id]?.add(roomName);

        // Notify user
        socket.emit('room_joined', {
          'room': roomName,
          'message': 'Joined room: $roomName',
          'usersInRoom': userRooms[socket.id]?.length ?? 0
        });

        // Notify room
        socket.emitToRoom(roomName, 'user_joined_room', {
          'userId': socket.id,
          'userName': userName,
          'room': roomName,
          'timestamp': DateTime.now().toIso8601String()
        });

        print('🚪 $userName joined room: $roomName');
      }
    });

    // Handle user name changes
    socket.on('update_username', (data) {
      if (data is String || (data is Map && data['username'] is String)) {
        final newName = data is String ? data : data['username'] as String;
        final oldName = userNames[socket.id];
        userNames[socket.id] = newName;

        // Broadcast name change
        socket.emitToRoom('general', 'username_changed', {
          'userId': socket.id,
          'oldName': oldName,
          'newName': newName,
          'timestamp': DateTime.now().toIso8601String()
        });

        socket.emit(
            'username_updated', {'newName': newName, 'status': 'success'});

        print('📝 $oldName changed name to $newName');
      }
    });

    // Handle disconnection
    socket.onClose(() {
      print('❌ $userName disconnected: ${socket.id}');

      // Remove from tracking
      userNames.remove(socket.id);
      userRooms.remove(socket.id);

      // Broadcast user left to all rooms
      for (var room in socket.rooms) {
        socket.emitToRoom(room, 'user_left', {
          'userId': socket.id,
          'userName': userName,
          'timestamp': DateTime.now().toIso8601String(),
          'onlineUsers': userRooms.length
        });
      }
    });

    // Handle errors
    // socket.onError((error) {
    //   print('❌ WebSocket error for $userName: $error');
    //   socket.emit('error', {
    //     'message': 'Connection error: $error',
    //     'timestamp': DateTime.now().toIso8601String()
    //   });
    // });

    // Send welcome event
    socket.emit('welcome', {
      'message': 'Welcome to the chat!',
      'id': socket.id,
      'userName': userName
    });
  });

  // REST API for chat history (optional)
  app.get('/api/chat/history', (req, res) async {
    return res.json({
      'messages': [
        {
          'id': '1',
          'userName': 'System',
          'message': 'Welcome to the chat!',
          'timestamp': DateTime.now().toIso8601String()
        }
      ]
    });
  });

  app.mount("/auth", authRoutes);
  app.listen(3001, hotReload: true);
}

// Handle JSON messages from Flutter app
void _handleJsonMessage(
    FlintWebSocket socket, String userName, Map<String, dynamic> data) {
  final event = data['event'];
  final eventData = data['data'];

  print('🎯 JSON Event: $event from $userName');

  switch (event) {
    case 'send_message':
      final message =
          eventData is Map ? eventData['message'] : eventData.toString();
      final room =
          eventData is Map ? eventData['room'] ?? 'general' : 'general';

      _broadcastMessage(socket, userName, message, room);
      break;

    case 'typing_start':
    case 'typing_stop':
    case 'join_room':
    case 'update_username':
      // These are handled by specific event listeners above
      break;

    default:
      print('❓ Unknown JSON event: $event');
  }
}

// Handle raw text messages from web page
void _handleRawMessage(FlintWebSocket socket, String userName, String message) {
  print('📝 Raw message from $userName: $message');
  _broadcastMessage(socket, userName, message, 'general');
}

// Broadcast message to room
void _broadcastMessage(
    FlintWebSocket socket, String userName, String message, String room) {
  final messageData = {
    'id': DateTime.now().millisecondsSinceEpoch.toString(),
    'userId': socket.id,
    'userName': userName,
    'message': message,
    'timestamp': DateTime.now().toIso8601String(),
    'room': room
  };

  // Broadcast to room as JSON event - MAKE SURE IT'S PROPERLY FORMATTED
  socket.emitToRoom(room, 'new_message', messageData);

  print('📤 Broadcast message from $userName to room $room: $message');
}
