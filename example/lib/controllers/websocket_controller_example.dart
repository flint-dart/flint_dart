import 'package:flint_dart/flint_dart.dart';

class ChatSocketController extends Controller {
  void connect() {
    socket.emit('connected', {
      'clientId': socket.id,
    });

    socket.on('message', (payload) {
      socket.emit('message:ack', {
        'received': true,
        'payload': payload,
      });
    });
  }

  void joinRoom() {
    socket.on('room:join', (payload) {
      final room = (payload as Map?)?['room']?.toString();
      if (room == null || room.isEmpty) {
        socket.emit('error', {'message': 'room is required'});
        return;
      }

      socket.join(room);
      socket.emit('room:joined', {'room': room});
    });
  }
}

/*
Route usage:

app.websocket(
  '/chat',
  controllerAction(() => ChatSocketController(), (c) {
    c.connect();
    c.joinRoom();
  }),
);
*/
