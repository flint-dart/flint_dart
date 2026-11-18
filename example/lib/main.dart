// import 'dart:convert';

import 'dart:convert';
import 'dart:io';
import 'package:flint_dart/flint_dart.dart';
import 'package:sample/middlewares/auth_middleware.dart';
import 'package:sample/routes/ai_routes.dart';
import 'package:sample/routes/auth_routes.dart';
import 'package:sample/routes/post_routes.dart';
import 'package:sample/routes/user_routes.dart';

void main(List<String> args) {
  final app = Flint(
    withDefaultMiddleware: true,
    enableSwaggerDocs: true,
    autoConnectDb: false,
    viewPath: 'lib/views',
  );

  app.use(LoggerMiddleware());
  app.static('/web', 'flint_ui/web');

  app.routes(AiRoutes());

  app.get('/', (Request req, Response res) async {
    return res.page(
      'Welcome',
      title: 'Welcome to Flint Dart',
      props: {
        'version': '1.0.4',
        'tagline': 'Build backend routes and browser UI with Dart.',
        'features': [
          {
            'title': 'Dart UI',
            'body': 'Write frontend pages with Flutter-style Flint widgets.',
          },
          {
            'title': 'Backend Bridge',
            'body': 'Return page names and props from normal Flint routes.',
          },
          {
            'title': 'One Toolchain',
            'body': 'Compile UI into web assets and serve them from Flint.',
          },
        ],
      },
    );
  });

  app.get('/counter', (Request req, Response res) async {
    return res.page(
      'Counter',
      title: 'Flint Dart Counter',
      props: {
        'title': 'Build a Flint UI page',
        'intro':
            'Use backend routes to choose pages, then render Dart UI components in the browser.',
        'steps': [
          {
            'label': 'Create UI source',
            'body': 'Place Dart frontend code in flint_ui/main.dart.',
            'code': 'class HomePage extends FlintComponent { ... }',
          },
          {
            'label': 'Register pages',
            'body': 'Map backend page names to Dart components.',
            'code':
                'createFlintApp("#app", pages: {"Home": (p) => HomePage(p)});',
          },
          {
            'label': 'Return a page',
            'body': 'Send the page name and props from any Flint route.',
            'code': 'return res.page("Home", props: {"name": "Ada"});',
          },
          {
            'label': 'Compile assets',
            'body': 'Compile flint_ui/main.dart into web/main.dart.js.',
            'code': 'flint web --build-only',
          },
        ],
      },
    );
  });

  app.get('/guide', (Request req, Response res) async {
    return res.page(
      'Guide',
      title: 'Flint Dart Guide',
      props: {
        'title': 'Build a Flint UI page',
        'intro':
            'Use backend routes to choose pages, then render Dart UI components in the browser.',
        'steps': [
          {
            'label': 'Create UI source',
            'body': 'Place Dart frontend code in flint_ui/main.dart.',
            'code': 'class HomePage extends FlintComponent { ... }',
          },
          {
            'label': 'Register pages',
            'body': 'Map backend page names to Dart components.',
            'code':
                'createFlintApp("#app", pages: {"Home": (p) => HomePage(p)});',
          },
          {
            'label': 'Return a page',
            'body': 'Send the page name and props from any Flint route.',
            'code': 'return res.page("Home", props: {"name": "Ada"});',
          },
          {
            'label': 'Compile assets',
            'body': 'Compile flint_ui/main.dart into web/main.dart.js.',
            'code': 'flint web --build-only',
          },
        ],
      },
    );
  });

  app.get('/login-ui', (Request req, Response res) async {
    return res.page(
      'Login',
      title: 'Flint Login UI',
      props: {
        'title': 'Welcome back',
        'subtitle':
            'A Tailwind-powered Flint UI page compiled without npm in the app.',
      },
    );
  });
  app.routes(PostRoutes());
  app.get('/preview/email', (Request req, Response res) async {
    final templates = _discoverEmailTemplates();
    if (templates.isEmpty) {
      return res.status(404).json({
        'message': 'No email templates found.',
        'hint': 'Create templates in lib/mail/views/*.flint.html'
      });
    }

    final links = templates.keys
        .map((name) => '<li><a href="/preview/email/$name">$name</a></li>')
        .join('\n');

    final html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Email Preview</title>
</head>
<body>
  <h2>Available Email Templates</h2>
  <p>Open any link to preview the rendered email template.</p>
  <ul>
    $links
  </ul>
</body>
</html>
''';

    return res.send(html, contentType: 'text/html');
  });

  app.get('/preview/email/:name', (Request req, Response res) async {
    final name = req.params['name'];
    if (name == null || name.trim().isEmpty) {
      return res.status(400).json({'message': 'Missing template name.'});
    }

    final templates = _discoverEmailTemplates();
    final templatePath = templates[name];
    if (templatePath == null) {
      return res.status(404).json({
        'message': 'Template "$name" not found.',
        'available': templates.keys.toList(),
      });
    }

    final previewData = <String, dynamic>{
      'subject': 'Preview: $name',
      'recipientName': req.queryParam('recipientName') ?? 'Preview User',
      'recipientEmail':
          req.queryParam('recipientEmail') ?? 'preview@example.com',
      'appName': 'Flint Example',
      'currentYear': DateTime.now().year,
      'preview': true,
    };

    final mailable = _EmailTemplatePreviewMail(
      subjectLine: 'Preview: $name',
      templateViewPath: templatePath,
      payload: previewData,
    );

    return res.renderEmail(mailable);
  });

  app.get('/login', (Request req, Response res) async {
    return res.oAuthRedirect("google", callback: "/api/auth/google/callback");
  });
  app.routes(UserRoutes());

  app.get('/profile', (Request req, Response res) async {
    return res.json({'msg': 'This is a protected route'});
  }).useMiddleware(AuthMiddleware());

  // Store active users and rooms
  final Map<String, String> userNames = {};
  final Map<String, Set<String>> userRooms = {};

  app.websocket('/chat', (Request req, FlintWebSocket socket) {
    Log.debug('👋 Client connected: ${socket.id}');

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
      Log.debug(
          '📨 Received from $userName: $data (type: ${data.runtimeType})');

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
          Log.debug('📝 Treating as raw text message');
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

        Log.debug('🚪 $userName joined room: $roomName');
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

        Log.debug('📝 $oldName changed name to $newName');
      }
    });

    // Handle disconnection
    socket.onClose(() {
      Log.debug('❌ $userName disconnected: ${socket.id}');

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
    //   Log.debug('❌ WebSocket error for $userName: $error');
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

  app.routes(AuthRoutes());
  final portArg = args.isNotEmpty ? int.tryParse(args.first) : null;
  app.listen(port: portArg, hotReload: true);
}

// Handle JSON messages from Flutter app
void _handleJsonMessage(
    FlintWebSocket socket, String userName, Map<String, dynamic> data) {
  final event = data['event'];
  final eventData = data['data'];

  Log.debug('🎯 JSON Event: $event from $userName');

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
      Log.debug('❓ Unknown JSON event: $event');
  }
}

// Handle raw text messages from web page
void _handleRawMessage(FlintWebSocket socket, String userName, String message) {
  Log.debug('📝 Raw message from $userName: $message');
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

  Log.debug('📤 Broadcast message from $userName to room $room: $message');
}

Map<String, String> _discoverEmailTemplates() {
  final roots = <String>[
    'lib/mail/views',
    'example/lib/mail/views',
  ];

  final templates = <String, String>{};

  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;

    for (final entry in dir.listSync(recursive: true)) {
      if (entry is! File) continue;

      final path = entry.path.replaceAll('\\', '/');
      final isEmailTemplate =
          path.endsWith('.flint.html') || path.endsWith('.html');
      if (!isEmailTemplate) continue;

      final fileName = path.split('/').last;
      var name = fileName;
      if (name.endsWith('.flint.html')) {
        name = name.substring(0, name.length - '.flint.html'.length);
      } else if (name.endsWith('.html')) {
        name = name.substring(0, name.length - '.html'.length);
      }

      templates.putIfAbsent(name, () => entry.path);
    }
  }

  final sortedKeys = templates.keys.toList()..sort();
  return {for (final key in sortedKeys) key: templates[key]!};
}

class _EmailTemplatePreviewMail extends ViewMailable {
  final String subjectLine;
  final String templateViewPath;
  final Map<String, dynamic> payload;

  _EmailTemplatePreviewMail({
    required this.subjectLine,
    required this.templateViewPath,
    required this.payload,
  });

  @override
  String get subject => subjectLine;

  @override
  String get view => templateViewPath;

  @override
  Map<String, dynamic> get data => payload;

  @override
  List<String> get to =>
      [payload['recipientEmail'] as String? ?? 'preview@example.com'];
}
