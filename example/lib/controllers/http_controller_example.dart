import 'package:flint_dart/flint_dart.dart';

class HttpUserController extends Controller {
  Future<Response> create() async {
    final body = await req.json();

    return res.json({
      'message': 'User created successfully',
      'data': body,
      'transport': isWebSocket ? 'websocket' : 'http',
    });
  }

  Future<Response> showProfile() async {
    final userId = req.params['id'];

    return res.json({
      'id': userId,
      'message': 'Profile loaded',
    });
  }
}

/*
Route usage:

app.post(
  '/users',
  controllerAction(() => HttpUserController(), (c) => c.create()),
);
*/
